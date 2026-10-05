import argparse
import html
import json
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from .data import load_deals, load_equity, read_csv, sha256
from .statistics import statistics, drawdown
from .monte_carlo import monte_carlo
from .robustness import overfitting_indicator


def write_csv(frame, path):
    frame.to_csv(path, index=False, encoding='utf-8-sig', lineterminator='\r\n')


def clean_json(value):
    if isinstance(value, dict):
        return {str(k): clean_json(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [clean_json(v) for v in value]
    if isinstance(value, (np.integer, np.floating, np.bool_)):
        value = value.item()
    if isinstance(value, float) and not np.isfinite(value):
        return None
    return value


def charts(equity, monthly, mc, output):
    plt.style.use('seaborn-v0_8-whitegrid')
    fig, axes = plt.subplots(2, 1, figsize=(11, 7), sharex=True)
    axes[0].plot(equity.time, equity.equity, color='#136f63', label='Equity')
    axes[0].plot(equity.time, equity.balance, color='#79919e', alpha=.7, label='Balance')
    axes[0].legend(); axes[0].set_ylabel('Account currency')
    _, dd = drawdown(equity.equity)
    axes[1].fill_between(equity.time, -dd, color='#bb4430', alpha=.7)
    axes[1].set_ylabel('Drawdown (%)')
    fig.suptitle('MT5 exported equity and drawdown'); fig.tight_layout()
    fig.savefig(output/'equity_drawdown.png', dpi=160); plt.close(fig)
    if len(monthly):
        fig, ax = plt.subplots(figsize=(11, 4))
        ax.bar(monthly.index.strftime('%Y-%m'), monthly.values*100,
               color=['#136f63' if x>=0 else '#bb4430' for x in monthly])
        ax.tick_params(axis='x', labelrotation=45); ax.set_ylabel('Return (%)')
        ax.set_title('Monthly equity returns (boundary months may be partial)')
        fig.tight_layout(); fig.savefig(output/'monthly_returns.png', dpi=160); plt.close(fig)
    if len(monthly) >= 12:
        table = pd.DataFrame({'year':monthly.index.year,'month':monthly.index.month,'return':monthly.values*100}).pivot(index='year',columns='month',values='return').reindex(columns=range(1,13))
        fig, ax = plt.subplots(figsize=(11, max(3,len(table)*.5)))
        scale=max(1, np.nanmax(np.abs(table.values)))
        image=ax.imshow(table.values,cmap='RdYlGn',vmin=-scale,vmax=scale,aspect='auto')
        ax.set_xticks(range(12),range(1,13)); ax.set_yticks(range(len(table)),table.index)
        fig.colorbar(image,ax=ax,label='Return (%)'); fig.tight_layout()
        fig.savefig(output/'monthly_heatmap.png',dpi=160); plt.close(fig)
    if mc['status']=='computed':
        p=np.asarray(mc['equity_percentiles']); fig,ax=plt.subplots(figsize=(11,4))
        ax.fill_between(range(p.shape[1]),p[0],p[2],alpha=.25,label='5th–95th pointwise percentiles')
        ax.plot(p[1],label='Median'); ax.legend(); ax.set_xlabel('Trade count')
        ax.set_ylabel('Simulated account currency'); ax.set_title('Conditional Monte Carlo scenarios')
        fig.tight_layout(); fig.savefig(output/'monte_carlo.png',dpi=160); plt.close(fig)


def generate(deals_path, equity_path, output, metadata_path=None, risks_path=None):
    output=Path(output); output.mkdir(parents=True,exist_ok=True)
    trades, equity=load_deals(deals_path),load_equity(equity_path)
    metadata=json.loads(Path(metadata_path).read_text(encoding='utf-8-sig')) if metadata_path else {}
    if risks_path:
        risks=read_csv(risks_path)
        if (risks.initial_risk_amount<=0).any() or ('deal_id' in risks and risks.deal_id.duplicated().any()):
            raise ValueError('Invalid original risk ledger')
        risks=risks.groupby('position_id',as_index=False).initial_risk_amount.sum()
        trades=trades.merge(risks[['position_id','initial_risk_amount']],on='position_id',how='left',validate='one_to_one')
        trades['r_multiple']=trades.pnl/trades.initial_risk_amount
    if len(trades) and (trades.entry_time.min()<equity.time.min() or trades.exit_time.max()>equity.time.max()):
        raise ValueError('Trade timestamps exceed equity coverage')
    difference=float(equity.balance.iloc[-1]-equity.balance.iloc[0]-trades.pnl.sum())
    if abs(difference)>.02:
        raise ValueError(f'Trade/equity reconciliation difference {difference:.6f}; inspect fees, cash flows, or incomplete exports')
    stats,monthly,annual=statistics(trades,equity)
    mc=monte_carlo(trades.pnl,float(equity.balance.iloc[0]))
    flags=overfitting_indicator(trades)
    warnings=[]
    if not metadata.get('real_tick_coverage_verified'):
        warnings.append('Real tick coverage has not been verified; results are provisional.')
    if not metadata.get('costs_verified'):
        warnings.append('Spread/commission/swap assumptions have not been verified.')
    if not metadata.get('behavior_verified'):
        warnings.append('Representative signal and execution behavior has not been verified.')
    if metadata.get('synthetic_fixture'):
        warnings.append('SYNTHETIC TEST FIXTURE — not historical strategy performance.')
    if len(trades)<100:
        warnings.append('Fewer than 100 completed trades; evidence is limited.')
    warnings.append('No OOS, walk-forward, or parameter-stability evidence is inferred from one run.')
    report=dict(status='provisional' if len(warnings)>1 else 'baseline_only', statistics=stats,
        monte_carlo=mc,overfitting=flags,metadata=metadata,warnings=warnings,
        provenance={'deals_sha256':sha256(deals_path),'equity_sha256':sha256(equity_path)},
        reconciliation_difference=difference)
    write_csv(trades,output/'trades.csv'); write_csv(pd.DataFrame([stats]),output/'statistics.csv')
    write_csv(monthly.rename('return').reset_index(),output/'monthly_returns.csv')
    write_csv(annual.rename('return').reset_index(),output/'annual_returns.csv')
    (output/'report.json').write_text(json.dumps(clean_json(report),indent=2,allow_nan=False),encoding='utf-8')
    charts(equity,monthly,mc,output)
    notices=''.join('<li>'+html.escape(w)+'</li>' for w in warnings)
    images=''.join(f'<figure><img src="{p.name}" alt="{html.escape(p.stem)}"></figure>' for p in sorted(output.glob('*.png')))
    mc_table=pd.DataFrame(mc['percentiles']).T.to_html(float_format=lambda x:f'{x:.3f}',escape=True) if mc['status']=='computed' else '<p>Insufficient completed trades for the declared Monte Carlo threshold.</p>'
    flag_table=pd.DataFrame(flags['flags'].items(),columns=['Heuristic flag','Observed value (blank = unavailable)']).to_html(index=False,escape=True)
    body=f'''<!doctype html><html lang="en"><meta charset="utf-8"><title>TradingBot research</title>
<style>body{{font:16px system-ui;max-width:1100px;margin:40px auto;padding:0 24px;color:#17313b}}table{{border-collapse:collapse}}td,th{{border:1px solid #ccd7db;padding:8px;text-align:left}}img{{max-width:100%}}.notice{{background:#fff3db;padding:16px}}</style>
<h1>TradingBot research report</h1><div class="notice"><ul>{notices}</ul></div>
<h2>Statistics</h2>{pd.DataFrame(stats.items(),columns=['Metric','Value']).to_html(index=False,escape=True)}
<h2>Conditional Monte Carlo</h2>{mc_table}<p>5th, 50th and 95th percentiles from the declared block-bootstrap experiment; these are scenarios, not forecasts. Additive completed-trade P/L omits intratrade drawdown and adaptive sizing.</p>
<h2>Overfitting checks</h2>{flag_table}<p>Unavailable evidence remains unknown. These flags are not a probability of overfitting.</p>
<h2>Research limitations</h2><p>Observed historical results are not a guarantee. Missing metrics remain unavailable. Costs are counted once; spread is embedded in broker fills. Monte Carlo uses additive net trade outcomes and cannot reconstruct intratrade risk.</p>
{images}<h2>Provenance and assumptions</h2><pre>{html.escape(json.dumps(clean_json(report['provenance'] | metadata),indent=2))}</pre></html>'''
    (output/'index.html').write_text(body,encoding='utf-8')
    return report


def main():
    p=argparse.ArgumentParser(description='Analyze actual MT5 exports; no trade execution')
    p.add_argument('--deals',required=True);p.add_argument('--equity',required=True);p.add_argument('--output',required=True)
    p.add_argument('--metadata');p.add_argument('--risks')
    a=p.parse_args(); result=generate(a.deals,a.equity,a.output,a.metadata,a.risks)
    print(json.dumps({'status':result['status'],'trades':result['statistics']['total_trades'],'report':str(Path(a.output)/'index.html')}))


if __name__=='__main__':
    main()
