"""Analyze the requested current-year gold run using actual MT5 exports."""
import argparse
import html
import json
from pathlib import Path
import pandas as pd
from .data import read_csv,load_deals
from .signal_audit import audit as signal_audit
from .execution_audit import audit as execution_audit
from .report_generator import generate,clean_json,write_csv
from .monte_carlo import monte_carlo


def build(project,run):
    project=Path(project);backtests=project/'Backtests';out=project/'Reports'/run
    prefix=backtests/(run+'_exports')/('TradingBot_'+run+'_XAUUSD')
    env=read_csv(str(prefix)+'_environment.csv').set_index('property').value.to_dict()
    evidence=json.loads((backtests/(run+'_log_evidence.json')).read_text())
    launch=json.loads((backtests/(run+'_launch.json')).read_text(encoding='utf-8-sig'))
    native=read_csv(str(prefix)+'_tester_statistics.csv').iloc[0].to_dict()
    signals=signal_audit(str(prefix)+'_bars.csv',str(prefix)+'_events.csv',out/'signal_audit',
        point=float(env['point']),tick_size=float(env['tick_size']))
    execution=execution_audit(prefix,out/'signal_audit/audited_setups.csv',out/'execution_audit')
    metadata=dict(run=run,symbol='XAUUSD',start=launch['from'],end_exclusive=launch['to'],
        code_sha256=launch['binary_sha256'],initial_capital=10000,currency='USD',
        real_tick_coverage_verified=evidence['real_tick_coverage_verified'],
        costs_verified=int(env.get('commission_query_error',-1))==0,
        behavior_verified=signals['status']=='passed' and execution['status']=='passed',
        environment=env,native_tester_statistics=native,tick_coverage=evidence,
        risk='0.25% equity, 10 symbol-point adverse reserve and USD10 per lot commission reserve; reserves are sizing allowances, not charged fees.',
        settings='H1/M5, confirmed 5-bar fractal, RR3, spread cap 30 symbol points, 100ms execution delay, no optional trade management.',
        research_role='User-requested current-year diagnostic; not optimized or claimed untouched OOS.',
        costs='Broker tester spread/fills, commission and swap. Historical changes in the broker swap schedule are not independently reconstructed.',
        risk_valuation='Linear USD contract calculation independently matched against every native original-risk ledger row; the tick_value field is retained but not used as a sizing shortcut.',
        limitations='Native and exported tick-equity drawdown differ; exact reporting discrepancy unresolved. Restart/crash and disconnected execution are not certified.')
    metadata_path=backtests/(run+'_metadata.json');metadata_path.write_text(json.dumps(clean_json(metadata),indent=2),encoding='utf-8')
    result=generate(str(prefix)+'_deals.csv',str(prefix)+'_equity.csv',out,metadata_path,str(prefix)+'_risks.csv')
    trades=load_deals(str(prefix)+'_deals.csv');events=read_csv(str(prefix)+'_events.csv')
    rejected=events[events.level.isin(['WARNING','ERROR'])].groupby('message').size().rename('count').reset_index().sort_values('count',ascending=False)
    write_csv(rejected,out/'rejections.csv')
    deals=read_csv(str(prefix)+'_deals.csv');entries=deals[deals.entry.eq(0)][['position_id','type']].drop_duplicates('position_id')
    directions=trades.merge(entries,on='position_id',validate='one_to_one')
    directions['direction']=directions.type.map({0:'buy',1:'sell'})
    by_side=directions.groupby('direction').agg(trades=('pnl','size'),net_profit=('pnl','sum'),wins=('pnl',lambda s:int((s>0).sum())))
    write_csv(by_side.reset_index(),out/'direction_results.csv')
    tick_cost=float(env['contract_size'])*float(env['point'])
    scenarios=[]
    for label,extra_per_lot in [('observed_demo_costs',0),('assumed_extra_USD7_commission_plus_2_points_each_side',7+4*tick_cost)]:
        pnl=trades.pnl-trades.volume*extra_per_lot
        mc=monte_carlo(pnl,10000)
        scenarios.append(dict(scenario=label,extra_cost_per_lot=extra_per_lot,net_profit=float(pnl.sum()),
            status=mc['status'],percentiles=mc.get('percentiles')))
    summary=dict(run=run,start=launch['from'],end_exclusive=launch['to'],statistics=result['statistics'],
        coverage=evidence['status'],coverage_warnings=evidence['warnings'],signals=signals,execution=execution,
        costs=dict(commission=float(trades.commission.sum()),swap=float(trades.swap.sum()),fees=float(trades.fee.sum())),
        rejections=rejected.to_dict('records'),cost_scenarios=scenarios,
        conclusion='No profitable edge established by this diagnostic alone.')
    (out/'gold_summary.json').write_text(json.dumps(clean_json(summary),indent=2,allow_nan=False),encoding='utf-8')
    details=f'<h2>Gold-specific checks</h2><p>Period: {launch["from"]} through {launch["to"]} exclusive. Coverage: {html.escape(evidence["status"])}. Signal audit: {signals["status"]}; execution audit: {execution["status"]}.</p><p>All source metadata and coverage warnings are retained below. The 30-point spread cap equals {30*float(env["point"]):.2f} in gold price units.</p>{by_side.to_html()}<h3>Rejected entries and warnings</h3>{rejected.to_html(index=False,escape=True)}<h3>Extra-cost sensitivity (assumptions)</h3>{pd.DataFrame([{k:v for k,v in s.items() if k!="percentiles"} for s in scenarios]).to_html(index=False,escape=True)}<p><a href="gold_summary.json">Gold summary and stress distributions</a> · <a href="signal_audit/buy_signal.png">Buy example</a> · <a href="signal_audit/sell_signal.png">Sell example</a></p>'
    page=(out/'index.html').read_text(encoding='utf-8').replace('<h2>Statistics</h2>',details+'<h2>Statistics</h2>')
    page=page.replace('TradingBot research report','XAUUSD 2026 year-to-date backtest')
    (out/'index.html').write_text(page,encoding='utf-8')
    return summary


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--project',default='.');p.add_argument('--run',default='gold_2026_ytd_20260929');a=p.parse_args()
    result=build(a.project,a.run)
    print(json.dumps(clean_json({k:result[k] for k in ['run','statistics','coverage','signals','execution','costs']}),indent=2))
