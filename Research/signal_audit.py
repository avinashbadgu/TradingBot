"""Independently audit exported closed-bar signals and plot actual examples."""
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from .data import read_csv, dates


def candles(ax, frame):
    for i, row in enumerate(frame.itertuples()):
        color='#17866b' if row.close>=row.open else '#c24b40'
        ax.plot([i,i],[row.low,row.high],color=color,linewidth=1)
        height=max(abs(row.close-row.open),1e-8)
        ax.add_patch(Rectangle((i-.32,min(row.open,row.close)),.64,height,color=color,alpha=.8))
    stride=max(1,len(frame)//8)
    ax.set_xticks(range(0,len(frame),stride),frame.time.iloc[::stride].dt.strftime('%m-%d %H:%M'),rotation=30,ha='right')
    ax.autoscale_view();ax.grid(alpha=.2)


def audit(bars_path, events_path, output, fractal_period=5, point=.00001,
          tick_size=.00001, sl_buffer=10, rr=3):
    out=Path(output);out.mkdir(parents=True,exist_ok=True)
    bars=read_csv(bars_path);events=read_csv(events_path)
    bars['time']=dates(bars.time);bars['available_at']=dates(bars.available_at)
    events['time']=dates(events.time)
    higher=bars[bars.timeframe=='PERIOD_H1'].sort_values('time').drop_duplicates('time').reset_index(drop=True)
    lower=bars[bars.timeframe=='PERIOD_M5'].sort_values('time').drop_duplicates('time').reset_index(drop=True)
    if higher.empty or lower.empty:raise ValueError('This baseline audit requires actual H1 and M5 exports')
    k=(fractal_period-1)//2
    if fractal_period<3 or fractal_period%2!=1:raise ValueError('Invalid fractal period')
    references={1:[],-1:[]}
    for i in range(k,len(higher)-k):
        neighbors=list(range(i-k,i))+list(range(i+1,i+k+1))
        for direction,field,compare in [(1,'low',np.less),(-1,'high',np.greater)]:
            value=higher.loc[i,field]
            if compare(value,higher.loc[neighbors,field].values).all():
                references[direction].append((higher.loc[i,'time'],higher.loc[i+k,'available_at'],value))
    failures=[];records=[];plotted=set()
    sweeps=events[events.message.eq('Sweep confirmed; setup created')]
    if sweeps.setup_id.duplicated().any():failures.append('Duplicate setup IDs in sweep events')
    for row in sweeps.itertuples():
        try:
            _,htf,ltf,direction,fractal,sweep=row.setup_id.rsplit('_',5)
            direction=int(direction);fractal=pd.Timestamp(int(fractal),unit='s');sweep=pd.Timestamp(int(sweep),unit='s')
            if htf!='16385' or ltf!='5':raise ValueError('Audit only supports baseline H1/M5')
            candidates=[r for r in references[direction] if r[1]<=sweep]
            if not candidates or candidates[-1][0]!=fractal:raise ValueError('Reference was not latest confirmed at sweep opening')
            reference=candidates[-1]
            sweep_bar=higher[higher.time==sweep].iloc[0]
            if row.time<sweep_bar.available_at:raise ValueError('Sweep event predates candle availability')
            value=reference[2]
            if direction==1 and not(sweep_bar.low<value<sweep_bar.close):raise ValueError('Invalid bullish sweep')
            if direction==-1 and not(sweep_bar.high>value>sweep_bar.close):raise ValueError('Invalid bearish sweep')
            prior=higher[(higher.time>=reference[1])&(higher.time<sweep)]
            if (prior.low<value).any() if direction==1 else (prior.high>value).any():raise ValueError('Previously penetrated reference reused')
            engulf=events[(events.setup_id==row.setup_id)&events.message.eq('Engulfing confirmed')]
            if len(engulf)>1:raise ValueError('Multiple engulfing signals for one setup')
            record={'setup_id':row.setup_id,'direction':direction,'fractal_time':str(fractal),
                    'fractal_available':str(reference[1]),'sweep_time':str(sweep),
                    'sweep_confirmed':str(row.time),'engulfing':False,'status':'pass'}
            if len(engulf):
                event=engulf.iloc[0]
                # OHLC bar-open timestamps are rounded to the period boundary.
                # The first tick can arrive seconds later; require the entry
                # candle to start at the H1 close boundary and finish AFTER
                # the actual observed sweep event, never before it.
                eligible=lower[(lower.available_at<=event.time)&(lower.time>=sweep_bar.available_at)&(lower.available_at>row.time)]
                if eligible.empty:raise ValueError('No eligible post-sweep closed entry candle')
                current=eligible.iloc[-1];index=int(current.name)
                if index<1:raise ValueError('Missing previous candle')
                previous=lower.iloc[index-1]
                if not(direction*(current.close-current.open)>0 and direction*(previous.close-previous.open)<0):raise ValueError('Wrong engulfing colors')
                if not(min(current.open,current.close)<=min(previous.open,previous.close) and max(current.open,current.close)>=max(previous.open,previous.close)):
                    raise ValueError('Body does not engulf previous body')
                rounded=lambda price,d: (np.floor(price/tick_size+1e-9) if d<0 else np.ceil(price/tick_size-1e-9))*tick_size
                entry=rounded((current.open+current.close)/2,-direction)
                stop=rounded(current.low-sl_buffer*point if direction==1 else current.high+sl_buffer*point,-direction)
                target=rounded(entry+direction*abs(entry-stop)*rr,direction)
                record.update(engulfing=True,engulf_time=str(current.time),signal_time=str(event.time),entry=float(entry),sl=float(stop),tp=float(target))
                if direction not in plotted:
                    fig,axes=plt.subplots(2,1,figsize=(12,8))
                    h=higher[(higher.time>=fractal-pd.Timedelta(hours=4))&(higher.time<=sweep+pd.Timedelta(hours=2))].reset_index(drop=True)
                    l=lower.iloc[max(0,index-8):index+13].reset_index(drop=True)
                    candles(axes[0],h);candles(axes[1],l)
                    axes[0].axhline(value,color='#c79419',label='Confirmed fractal reference')
                    axes[0].set_title(f'H1: center {fractal}, available {reference[1]}, sweep confirmed {row.time}')
                    for price,label,color in [(entry,'Expected limit entry','#287ab4'),(stop,'Original SL','#c24b40'),(target,'Target','#17866b')]:
                        axes[1].axhline(price,label=label,color=color,linestyle='--')
                    axes[1].set_title(f'M5: engulfing {current.time}, actionable {event.time}; OHLC cannot prove fills')
                    for ax in axes:ax.legend(loc='best')
                    fig.suptitle(('Bullish' if direction==1 else 'Bearish')+' actual exported signal example')
                    fig.tight_layout();fig.savefig(out/('buy_signal.png' if direction==1 else 'sell_signal.png'),dpi=150);plt.close(fig)
                    plotted.add(direction)
            records.append(record)
        except (ValueError,IndexError,KeyError) as exc:
            failures.append(f'{row.setup_id}: {exc}')
    result={'status':'failed' if failures else ('passed' if len(records) else 'no_signals'),
            'sweeps_checked':len(records),'engulfings_checked':sum(r['engulfing'] for r in records),
            'directions_plotted':sorted(plotted),'failures':failures,
            'scope':'Baseline H1/M5, strict 5-bar fractals, first penetration consumed, inclusive opposite-color engulfing. Validates observed signals, not missed signals, fills, or all broker behavior.'}
    (out/'signal_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    pd.DataFrame(records).to_csv(out/'audited_setups.csv',index=False,encoding='utf-8-sig')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--bars',required=True);p.add_argument('--events',required=True);p.add_argument('--output',required=True)
    a=p.parse_args();print(json.dumps(audit(a.bars,a.events,a.output),indent=2))
