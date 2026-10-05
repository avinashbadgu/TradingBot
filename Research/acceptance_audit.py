"""Check observed tester scenarios; do not infer untested broker behavior."""
import argparse
import json
import re
from pathlib import Path
import numpy as np
from .data import read_csv, dates


def audit(project):
    project=Path(project); backtests=project/'Backtests'; rows=[]
    jobs=json.loads((backtests/'acceptance_jobs.json').read_text())
    for job in jobs:
        run=job['run']
        if not run.startswith('qa_'): continue
        prefix=backtests/(run+'_exports')/('TradingBot_'+run+'_EURUSD')
        if job.get('integration'):
            path=Path(str(prefix)+'_checks.csv')
            if not path.is_file():
                rows.append(dict(run=run,status='missing',checks=[]));continue
            native=read_csv(path)
            checks=[dict(check=row.check,passed=str(row.passed).lower()=='true') for row in native.itertuples()]
            completed=native.check.eq('weekend market schedule exercised').any()
            rows.append(dict(run=run,status='passed' if completed and checks and all(c['passed'] for c in checks) else 'failed',checks=checks))
            continue
        if not Path(str(prefix)+'_deals.csv').is_file():
            rows.append(dict(run=run,status='missing',checks=[])); continue
        deals=read_csv(str(prefix)+'_deals.csv');orders=read_csv(str(prefix)+'_orders.csv')
        events=read_csv(str(prefix)+'_events.csv'); entries=deals[deals.entry.eq(0)]
        pending=orders[orders.type.isin([2,3])]; checks=[]
        def check(condition,name):checks.append(dict(check=name,passed=bool(condition)))
        def logged(text):return events.message.str.contains(text,regex=False).any()
        if run=='qa_fixed_lot':
            check(len(pending)>0 and np.isclose(pending.initial_volume,.07).all(),'all pending volumes equal requested 0.07 lots')
        elif run=='qa_fixed_usd':
            per_lot=(abs(pending.entry-pending.sl)+.0001)*100000+10
            expected=np.floor(25/per_lot/.01+1e-9)*.01
            check(len(pending)>0 and np.isclose(expected,pending.initial_volume).all(),'all USD25 risk volumes match independent EURUSD/USD calculation')
            check((pending.initial_volume*per_lot<=25+1e-6).all(),'reserved initial risk stays within USD25')
        elif run=='qa_daily_count':
            times=dates(entries.time)
            count=entries.assign(day=times.dt.date).groupby('day').position_id.nunique()
            check(len(count)>0 and count.max()<=1,'at most one new position per broker day')
            check(logged('Daily trade limit'),'daily trade limit exercised')
        elif run=='qa_london':
            times=dates(pending.setup_time)
            check(len(pending)>0 and ((times.dt.hour>=8)&(times.dt.hour<17)).all(),'all placements inside 08:00-17:00 broker-time window')
            check(logged('Outside session'),'session rejection exercised')
        elif run=='qa_management':
            for text in ['SL modification breakeven retcode=10009','SL modification trailing retcode=10009','Partial close retcode=10009']:
                check(logged(text),text)
            partial_orders=orders[orders.comment.fillna('').str.contains('TB partial',regex=False)].order_id
            partial=deals[deals.order_id.isin(partial_orders)]
            check(len(partial)>0 and not partial.position_id.duplicated().any(),'partial close occurred at most once per position')
            entry_volume=entries.groupby('position_id').volume.sum()
            expected=np.floor(entry_volume.reindex(partial.position_id).to_numpy()*.5/.01+1e-9)*.01
            check(len(partial)>0 and np.isclose(partial.volume,expected).all(),'partial volumes equal 50 percent rounded down to broker step')
            evidence=json.loads((backtests/(run+'_log_evidence.json')).read_text())
            stops={};violations=[];observed=0
            for line in evidence['evidence']:
                match=re.search(r'position modified \[#(\d+) (buy|sell) .*? sl: ([\d.]+)',line)
                if not match: continue
                ticket,side,value=match.groups();value=float(value);direction=1 if side=='buy' else -1
                if ticket in stops and direction*(value-stops[ticket])<-.000001:violations.append(ticket)
                stops[ticket]=value;observed+=1
            check(observed>0 and not violations,'observed successive stop modifications never worsen stops')
        else:
            expected={'qa_spread':'Spread limit','qa_minimum_volume':'Risk budget below minimum volume',
                      'qa_margin':'Insufficient or unknown margin','qa_daily_budget':'Trade and reserved risk exceed remaining protection budget'}[run]
            check(entries.empty and pending.empty,'no orders or fills under blocking condition')
            check(logged(expected),expected+' exercised')
        rows.append(dict(run=run,status='passed' if checks and all(c['passed'] for c in checks) else 'failed',
                         orders=len(pending),entry_fills=len(entries),checks=checks))
    result=dict(status='passed' if rows and all(r['status']=='passed' for r in rows) else 'incomplete_or_failed',runs=rows,
        scope='Actual EURUSD/USD tester scenarios. Does not establish crash recovery, disconnected expiry, foreign ownership, non-USD account conversion, or all broker rejection/freeze conditions.')
    out=project/'Reports'/'acceptance';out.mkdir(parents=True,exist_ok=True)
    (out/'acceptance.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--project',default='.');a=p.parse_args();print(json.dumps(audit(a.project),indent=2))
