"""Reproducible report for the frozen September 2026 native MT5 study."""
import argparse
import html
import json
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from .data import read_csv, load_deals, sha256
from .report_generator import generate, clean_json, write_csv

LEGACY_RUN_ALIASES = {'gold_available_2026': 'gold_2026_ytd_20260929'}


def resolve_run_name(run_name):
    return LEGACY_RUN_ALIASES.get(run_name, run_name)
from .parameter_stability import parameter_stability
from .walk_forward import select_training
from .monte_carlo import monte_carlo
from .optimizer_analysis import candidates_table


def build(project):
    project = Path(project); backtests = project/'Backtests'; output = project/'Reports'/'study_20260928'
    output.mkdir(parents=True, exist_ok=True)
    training = []
    decisions = []
    for fold in range(3):
        path = backtests/f'TradingBot_train_fold{fold}_EURUSD_optimization.csv'
        frame = read_csv(path)
        expected = {(rr, n) for rr in [2, 2.5, 3, 3.5, 4] for n in [3, 5, 7, 9]}
        if len(frame) != 20 or set(zip(frame.rr, frame.fractal_period)) != expected:
            raise ValueError(f'Incomplete or duplicated optimization grid in fold {fold}')
        chosen = select_training(frame)
        decisions.append(dict(fold=fold, selected_config=chosen, action='flat' if chosen is None else 'forward_required',
            passes=len(frame), profitable_passes=int((frame.net_profit > 0).sum()), best_profit_factor=float(frame.profit_factor.max()),
            coverage='per-pass tick coverage unverified' if fold == 0 else 'invalid: includes known 2025-05-27 missing real ticks',
            source_sha256=sha256(path)))
        frame['fold'] = fold; frame['phase'] = 'train'; training.append(frame)
    training = pd.concat(training, ignore_index=True)
    stable = parameter_stability(training, ['rr', 'fractal_period'])
    candidates=training.merge(stable,on=['config_id','symbol','fold','phase'],validate='one_to_one')
    candidates['higher_tf']='H1';candidates['entry_tf']='M5';candidates['session']='all broker sessions'
    candidates['engulfing_filter']='opposite color, inclusive body, dojis excluded'
    candidates['oos_trades']=None;candidates['oos_profit_factor']=None
    candidates['parameter_stability']=candidates.neighbor_nonpositive_fraction
    candidates['overfitting_risk']='incomplete evidence; all neighboring expectancies nonpositive'
    candidates=candidates_table(candidates)
    candidates['coverage']=candidates.fold.map({d['fold']:d['coverage'] for d in decisions})
    write_csv(candidates,output/'candidate_selection.csv')
    write_csv(training, output/'training_grid.csv'); write_csv(stable, output/'parameter_stability.csv')
    write_csv(pd.DataFrame(decisions), output/'walk_forward_decisions.csv')
    fig, axes = plt.subplots(1, 3, figsize=(13, 4), sharey=True)
    for fold, ax in enumerate(axes):
        table = training[training.fold.eq(fold)].pivot(index='fractal_period', columns='rr', values='profit_factor')
        ax.imshow(table, cmap='RdYlGn', vmin=0, vmax=2, aspect='auto')
        ax.set_xticks(range(len(table.columns)), table.columns); ax.set_yticks(range(len(table.index)), table.index.astype(int))
        for y in range(len(table)):
            for x in range(len(table.columns)):
                ax.text(x, y, f'{table.iloc[y, x]:.2f}', ha='center', va='center')
        ax.set_title(f'Fold {fold}: native profit factor'); ax.set_xlabel('RR')
    axes[0].set_ylabel('Fractal period'); fig.suptitle('All tested neighborhoods lose; data limitations apply')
    fig.tight_layout(); fig.savefig(output/'training_stability.png', dpi=160); plt.close(fig)

    jobs = [dict(run='baseline_v2', symbol='EURUSD', **{'from':'2025.01.01','to':'2025.04.01'})]
    jobs += json.loads((backtests/'diagnostic_jobs.json').read_text(encoding='utf-8-sig'))
    supplemental=backtests/'supplemental_jobs.json'
    if supplemental.is_file():
        jobs += [dict(j, run=resolve_run_name(j['run'])) for j in json.loads(supplemental.read_text())
                 if resolve_run_name(j['run']) == 'gold_2026_ytd_20260929']
    summaries = []; missing = []; cost_scenarios = []
    deployment = json.loads((project/'deployment.json').read_text(encoding='utf-8-sig'))
    study_provenance=json.loads((backtests/'study_provenance.json').read_text())
    for job in jobs:
        run, symbol = job['run'], job['symbol']
        prefix = backtests/(run+'_exports')/f'TradingBot_{run}_{symbol}'
        paths = {kind: Path(str(prefix)+'_'+kind+'.csv') for kind in ['deals','equity','risks','environment','tester_statistics']}
        if not all(p.is_file() for p in paths.values()):
            missing.append(run); continue
        evidence_path = backtests/(run+'_log_evidence.json')
        evidence = json.loads(evidence_path.read_text()) if evidence_path.is_file() else {}
        env = read_csv(paths['environment']).set_index('property').value.to_dict()
        native = read_csv(paths['tester_statistics']).iloc[0].to_dict()
        launch=json.loads((backtests/(run+'_launch.json')).read_text(encoding='utf-8-sig'))
        metadata = dict(run=run, symbol=symbol, start=job['from'], end_exclusive=job['to'],
            initial_capital=10000, currency='USD', tester_model=4, execution_delay_ms=100,
            code_sha256=launch.get('binary_sha256',study_provenance['binary_sha256']), code_revision_note=study_provenance['revision_note'], environment=env, native_tester_statistics=native,
            real_tick_coverage_verified=evidence.get('real_tick_coverage_verified',False),
            tick_coverage=evidence, costs_verified=int(env.get('commission_query_error',-1)) == 0,
            behavior_verified=run in ['baseline_v2','default_holdout'],
            behavior_scope='Baseline and holdout have independent signal and execution audits; other runs are diagnostics.',
            drawdown_note='Native tester drawdown and exported tick-equity drawdown are retained separately; reporting conventions may differ and the exact discrepancy is unresolved.',
            selection_role='fixed default diagnostic; not an optimized selected configuration',
            cost_note='Spread embedded in fills, actual swap/commission charged once. Sizing reserves are not fees. Demo commission schedule is not a real broker quote.')
        metadata_path = backtests/(run+'_metadata.json')
        metadata_path.write_text(json.dumps(clean_json(metadata),indent=2),encoding='utf-8')
        report = generate(paths['deals'],paths['equity'],project/'Reports'/run,metadata_path,paths['risks'])
        summary = dict(run=run,symbol=symbol,start=job['from'],end_exclusive=job['to'],
            coverage=evidence.get('status','unverified'), **report['statistics'],
            native_drawdown_pct=native['maximum_drawdown_pct'], monte_carlo_status=report['monte_carlo']['status'])
        summaries.append(summary)
        if symbol == 'EURUSD':
            trades = load_deals(paths['deals'])
            # Explicit assumed additional costs, not claimed broker charges.
            # EURUSD/USD: 100,000 contract * 0.00001 point = USD1 per point per lot.
            for label, cost_per_lot in [('observed_demo_costs',0),('extra_USD7_roundturn_commission_plus_2_points_each_side',11)]:
                pnl = trades.pnl - trades.volume*cost_per_lot
                for method in ['permutation','block_bootstrap']:
                    mc = monte_carlo(pnl,10000,method=method)
                    cost_scenarios.append(dict(run=run, scenario=label, method=method, trades=len(trades),
                        net_profit=float(pnl.sum()), status=mc['status'],
                        assumptions=mc.get('assumptions'), percentiles=mc.get('percentiles')))
            if len(trades):
                average_lots=float(trades.volume.mean())
                mc=monte_carlo(trades.pnl-7*trades.volume,10000,
                    extra_cost_mean=4*average_lots,extra_cost_sd=2*average_lots)
                cost_scenarios.append(dict(run=run,
                    scenario='extra_USD7_roundturn_commission_plus_random_adverse_slippage',
                    method='block_bootstrap',trades=len(trades),status=mc['status'],
                    slippage_assumption='Per simulated trade: nonnegative normal cost with 4-point round-trip mean and 2-point SD, valued at the observed mean lot size. An average-exposure approximation, not a fill replay.',
                    assumptions=mc.get('assumptions'),percentiles=mc.get('percentiles')))
    write_csv(pd.DataFrame(summaries),output/'run_comparison.csv')
    result = dict(status='incomplete' if missing else 'completed_with_data_and_validation_limits',
        conclusion='No supported configuration selected. All 60 training passes lost money; known real-tick gaps invalidate two training windows. Flat selection is a no-deployment decision, not proof of a profitable trading system.',
        decisions=decisions, missing_runs=missing, runs=summaries, cost_scenarios=cost_scenarios,
        limitations=[
            'Native optimization has 20 passes per fold, but full tick coverage for every pass is not independently verified.',
            'EURUSD 2025-05-27 lacks 599 real-tick minutes. The first forward window and training folds 1 and 2 are invalid for a complete real-tick claim.',
            'XAUUSD January-March 2025 has no real ticks; the native run is generated-tick-only and excluded. Supplemental June-August 2026 gold uses unchanged settings on a separately declared available window.',
            'Training windows overlap: 60 passes are not 60 independent experiments.',
            'No qualifying training candidate exists; all selected walk-forward windows stay flat. Selected-system PF, Sharpe and degradation are undefined.',
            'Default forward and holdout diagnostics keep RR3 and fractal5 fixed. The holdout is not used to retune.',
            'Cross-symbol runs each start with USD10,000 and are not a portfolio simulation.',
            'Monte Carlo conditions on additive realized P/L; it omits intratrade excursions, compounded sizing and new execution paths.',
            'Native and exported-equity drawdowns differ; comparisons label their source.',
            'News filter is unavailable. Restart/fault injection, broker rejection paths and optional management features need further execution validation.',
            'Independent plotted buy/sell examples were reviewed; native visual tester and Navigator appearance have not been visually verified.',
            'No unified robustness score or best live configuration is assigned where required evidence is missing.'
        ])
    (output/'study.json').write_text(json.dumps(clean_json(result),indent=2,allow_nan=False),encoding='utf-8')
    columns=['run','symbol','total_trades','net_profit','profit_factor','maximum_drawdown_pct','native_drawdown_pct','coverage']
    table=pd.DataFrame(summaries)[columns].to_html(index=False,float_format=lambda x:f'{x:.3f}',escape=True) if summaries else '<p>No completed exports.</p>'
    links=''.join(f'<li><a href="../{html.escape(r["run"])}/index.html">{html.escape(r["run"])}</a></li>' for r in summaries)
    notes=''.join('<li>'+html.escape(x)+'</li>' for x in result['limitations'])
    body=f'''<!doctype html><html lang="en"><meta charset="utf-8"><title>TradingBot actual research results</title>
<style>body{{font:16px system-ui;max-width:1350px;margin:36px auto;padding:0 24px;color:#20343a}}table{{border-collapse:collapse;font-size:14px}}td,th{{padding:8px;border:1px solid #ccc}}img{{max-width:100%}}.notice{{padding:20px;background:#fff0d5}}</style>
<h1>TradingBot: actual MT5 research results</h1><p class="notice">{html.escape(result['conclusion'])}</p>
<p>Frozen protocol: 28 September 2026. Fixed H1/M5, RR3, fractal5, 0.25% equity risk for diagnostics; native training varies only RR and fractal period. Amounts in USD.</p>
<h2>Completed runs</h2>{table}<p>Drawdown columns are percent: Python exported tick equity, then native MT5. Invalid coverage results are retained as diagnostics, not accepted evidence.</p>
<h2>Training and chronological selection</h2>{pd.DataFrame(decisions).drop(columns=['source_sha256']).to_html(index=False,escape=True)}
<img src="training_stability.png" alt="Profit factor grids for all three training windows">
<h2>Monte Carlo and cost sensitivity</h2><p>Each eligible run has 2,000 seeded block-bootstrap scenarios in its report. study.json also contains permutation results and a separately labeled EURUSD stress assumption: USD7 round-turn commission per lot plus two extra adverse points on each side. Fewer than 50 trades yields no Monte Carlo estimate.</p>
<h2>Evidence and limitations</h2><ul>{notes}</ul><h2>Individual reports</h2><ul>{links}</ul>
<p>Machine-readable downloads: <a href="run_comparison.csv">comparison</a>, <a href="training_grid.csv">native grid</a>, <a href="candidate_selection.csv">candidate rejection table</a>, <a href="parameter_stability.csv">neighbor stability</a>, <a href="walk_forward_decisions.csv">selection</a>, <a href="study.json">full study including Monte Carlo</a>.</p></html>'''
    (output/'index.html').write_text(body,encoding='utf-8')
    return dict(status=result['status'],completed=len(summaries),missing=missing,report=str(output/'index.html'))


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('--project',default='.');a=p.parse_args()
    print(json.dumps(build(a.project),indent=2))
