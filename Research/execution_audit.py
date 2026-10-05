"""Audit baseline order geometry, sizing, fills, and expiry against raw exports."""
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd
from .data import read_csv, dates


def audit(prefix, signals_path, output):
    prefix=str(prefix)
    orders=read_csv(prefix+'_orders.csv');deals=read_csv(prefix+'_deals.csv')
    equity=read_csv(prefix+'_equity.csv');events=read_csv(prefix+'_events.csv')
    environment=read_csv(prefix+'_environment.csv').set_index('property').value.to_dict()
    signals=read_csv(signals_path).set_index('setup_id')
    for df,columns in [(orders,['setup_time','done_time','expiration']),(deals,['time']),(equity,['time']),(events,['time'])]:
        for column in columns:df[column]=dates(df[column])
    if environment['symbol'] not in ['EURUSD','XAUUSD'] or environment['currency']!='USD':
        raise ValueError('This independent sizing audit supports EURUSD or XAUUSD on a USD account only')
    tick=float(environment['tick_size']);point=float(environment['point']);step=float(environment['volume_step'])
    contract=float(environment['contract_size']);reserve=float(environment['commission_reserve_per_lot'])
    risks=read_csv(prefix+'_risks.csv')
    expected_native_risk=abs(risks.entry-risks.original_sl)*risks.volume*contract
    if not np.isclose(expected_native_risk,risks.initial_risk_amount,atol=1e-5,rtol=1e-7).all():
        raise ValueError('Native monetary risk does not match the independently assumed USD linear-contract valuation')
    pending=orders[orders.type.isin([2,3])];failures=[];checked=[]
    placements=events[events.message.str.startswith('Place limit retcode=10009')].copy()
    placements['order_id']=placements.message.str.extract(r'order=(\d+)').astype(int)
    if placements.setup_id.duplicated().any():failures.append('Duplicate order placements from one setup')
    for order in pending.itertuples():
        try:
            matches=placements[placements.order_id==order.order_id]
            if len(matches)!=1:raise ValueError('Missing or duplicated placement event')
            signal=signals.loc[matches.iloc[0].setup_id]
            for name in ['entry','sl','tp']:
                if abs(getattr(order,name)-signal[name])>tick/10:raise ValueError(name+' differs from deterministic candle geometry')
            timestamp=matches.iloc[0].time
            if order.setup_time<pd.Timestamp(signal.signal_time):raise ValueError('Order predates engulfing confirmation')
            capital=equity[equity.time<=timestamp].equity.iloc[-1]
            budget=capital*.0025
            per_lot=abs(order.entry-order.sl)*contract+10*point*contract+reserve
            expected=np.floor((budget/per_lot)/step+1e-9)*step
            if abs(order.initial_volume-expected)>step/10:raise ValueError(f'Volume {order.initial_volume} differs from independent budget calculation {expected}')
            if order.initial_volume*per_lot>budget+1e-6:raise ValueError('Initial reserved risk exceeds budget')
            if (order.expiration-order.setup_time).total_seconds()>3600 or order.expiration<=order.setup_time:raise ValueError('Invalid pending lifetime')
            fills=deals[(deals.order_id==order.order_id)&deals.entry.eq(0)]
            if (fills.time<order.setup_time).any():raise ValueError('Fill predates submission')
            if (fills.time>order.expiration).any():raise ValueError('Fill after expiration')
            if order.type==2 and (fills.price>order.entry+tick/10).any():raise ValueError('Buy limit filled worse than limit')
            if order.type==3 and (fills.price<order.entry-tick/10).any():raise ValueError('Sell limit filled worse than limit')
            checked.append({'order_id':int(order.order_id),'setup_id':matches.iloc[0].setup_id,'volume':order.initial_volume,'reserved_risk':order.initial_volume*per_lot,'budget':budget,'filled':len(fills)>0})
        except (ValueError,IndexError,KeyError) as exc:failures.append(f'Order {order.order_id}: {exc}')
    result={'status':'failed' if failures else 'passed','orders_checked':len(checked),'fills_checked':int(deals.entry.eq(0).sum()),'failures':failures,
            'scope':f'{environment["symbol"]} USD account, default 0.25% equity sizing, 10 point adverse reserve, server expiration, no management modifiers. Linear contract valuation cross-checked against every exported native initial risk. Does not prove unobserved broker conditions.'}
    out=Path(output);out.mkdir(parents=True,exist_ok=True)
    (out/'execution_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    pd.DataFrame(checked).to_csv(out/'audited_orders.csv',index=False,encoding='utf-8-sig')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--prefix',required=True);p.add_argument('--signals',required=True);p.add_argument('--output',required=True)
    a=p.parse_args();print(json.dumps(audit(a.prefix,a.signals,a.output),indent=2))
