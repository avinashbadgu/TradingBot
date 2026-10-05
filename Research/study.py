"""Analyze independently exported runs described by a study manifest."""
import argparse
import json
from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from .data import load_deals, load_equity
from .statistics import statistics
from .walk_forward import evaluate_walk_forward, plan_windows
from .parameter_stability import parameter_stability
from .optimizer_analysis import ResearchFilters, candidates_table
from .report_generator import write_csv
from .monte_carlo import monte_carlo
from .robustness import overfitting_indicator


def analyze(manifest_path, output):
    source=Path(manifest_path); manifest=json.loads(source.read_text(encoding='utf-8-sig'))
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    rows=[]
    for run in manifest['runs']:
        if run['phase'] not in ('train','forward','holdout'):
            raise ValueError('Invalid study phase')
        equity=load_equity(source.parent/run['equity']); trades=load_deals(source.parent/run['deals'])
        start,end=pd.Timestamp(run['start']),pd.Timestamp(run['end'])
        if start>=end or equity.time.min()<start or equity.time.max()>end:
            raise ValueError('Run outside declared window')
        if len(trades) and (trades.entry_time.min()<start or trades.exit_time.max()>end):
            raise ValueError('Trades cross flat-start run boundaries')
        if abs(equity.balance.iloc[-1]-equity.balance.iloc[0]-trades.pnl.sum())>.02:
            raise ValueError('Run P/L does not reconcile')
        stats,_,_=statistics(trades,equity)
        mc=monte_carlo(trades.pnl,float(equity.balance.iloc[0]))
        stats['monte_carlo_drawdown']=mc.get('percentiles',{}).get('drawdown_pct',{}).get('p95')
        risk=overfitting_indicator(trades,optimized_parameter_count=len(manifest['parameters']))
        stats['overfitting_risk']=f"provisional {risk['flagged']}/{risk['evaluated']} flags"
        rows.append(stats | {k:v for k,v in run.items() if k not in ('deals','equity')})
    frame=pd.DataFrame(rows)
    if frame.duplicated(['fold','phase','config_id','symbol']).any():
        raise ValueError('Duplicate study run')
    # Scope a manifest to one symbol, preserving independent capital and chronology.
    if frame.symbol.nunique()!=1:
        raise ValueError('Use one symbol per study; portfolio simulation requires coordinated MT5 execution')
    training=frame[frame.phase=='train']; forward=frame[frame.phase=='forward']
    for fold,group in training.groupby('fold'):
        if group.start.nunique()!=1 or group.end.nunique()!=1:
            raise ValueError('Training candidates must share dates')
        f=forward[forward.fold==fold]
        if len(f) and (pd.to_datetime(f.start)<pd.Timestamp(group.end.iloc[0])).any():
            raise ValueError('Training/forward leakage')
    holdout=frame[frame.phase=='holdout']
    if len(holdout) and len(frame[frame.phase!='holdout']) and pd.to_datetime(holdout.start).min()<pd.to_datetime(frame[frame.phase!='holdout'].end).max():
        raise ValueError('Holdout overlaps development periods')
    stability=parameter_stability(training,manifest['parameters'])
    joined=training.merge(stability,on=['config_id','symbol','fold','phase'],validate='one_to_one')
    wf=evaluate_walk_forward(training.drop(columns=['phase']),forward)
    if len(wf) and 'forward_expectancy' in wf:
        joined=joined.merge(wf[['fold','config_id','forward_expectancy']].rename(columns={'forward_expectancy':'walk_forward_performance'}),on=['fold','config_id'],how='left',validate='one_to_one')
    # OOS eligibility only when actual matching forward data exists.
    oos=forward[['fold','config_id','symbol','total_trades','profit_factor']].rename(columns={'total_trades':'oos_trades','profit_factor':'oos_profit_factor'})
    joined=joined.merge(oos,on=['fold','config_id','symbol'],how='left',validate='one_to_one')
    candidates=candidates_table(joined,ResearchFilters(**manifest.get('filters',{})))
    write_csv(frame,output/'runs.csv');write_csv(stability,output/'parameter_stability.csv')
    write_csv(wf,output/'walk_forward.csv');write_csv(candidates,output/'candidates.csv');write_csv(holdout,output/'holdout.csv')
    for parameter in manifest['parameters']:
        fig,ax=plt.subplots(figsize=(9,4))
        for fold,group in training.groupby('fold'):
            grouped=group.groupby(parameter).expectancy.median()
            ax.plot(grouped.index.astype(str),grouped.values,marker='o',label=f'Fold {fold}')
        ax.axhline(0,color='black',linewidth=.5);ax.set_xlabel(parameter);ax.set_ylabel('Median net expectancy')
        ax.legend();fig.tight_layout();fig.savefig(output/f'stability_{parameter}.png',dpi=150);plt.close(fig)
    body='<html><meta charset="utf-8"><title>TradingBot study</title><h1>Study candidates</h1><p>Eligibility uses declared criteria. No configuration is universally best. Missing evidence fails eligibility.</p>'+candidates.to_html(index=False)+'<h2>Walk forward</h2>'+wf.to_html(index=False)+'</html>'
    (output/'study.html').write_text(body,encoding='utf-8')
    return candidates


def main():
    p=argparse.ArgumentParser();sub=p.add_subparsers(dest='command',required=True)
    a=sub.add_parser('analyze');a.add_argument('manifest');a.add_argument('--output',required=True)
    w=sub.add_parser('plan');w.add_argument('--start',required=True);w.add_argument('--end',required=True)
    w.add_argument('--training-months',type=int,default=12);w.add_argument('--forward-months',type=int,default=3);w.add_argument('--output',required=True)
    args=p.parse_args()
    if args.command=='analyze': analyze(args.manifest,args.output)
    else:
        out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
        windows,holdout=plan_windows(args.start,args.end,args.training_months,args.forward_months)
        write_csv(windows,out/'windows.csv');(out/'holdout.json').write_text(json.dumps(holdout,indent=2),encoding='utf-8')


if __name__=='__main__': main()
