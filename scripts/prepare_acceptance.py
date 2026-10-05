"""Create tester-only behavioral scenarios; not performance optimization."""
import json
from pathlib import Path

project = Path(__file__).resolve().parents[1]
baseline = (project/'MT5/Config/TradingBot_Default.set').read_text(encoding='utf-16')
scenarios = {
    'qa_management': {'EnableBreakeven':'true','EnablePartialTakeProfit':'true','EnableTrailingStop':'true','TrailingStopDistance':'30'},
    'qa_fixed_lot': {'RiskMode':'0','UseFixedLot':'true','FixedLotSize':'0.07'},
    'qa_fixed_usd': {'RiskMode':'1','RiskAmountUSD':'25'},
    'qa_spread': {'MaximumSpreadAllowed':'0.1'},
    'qa_daily_count': {'MaximumDailyTrades':'1'},
    'qa_minimum_volume': {'RiskMode':'1','RiskAmountUSD':'0.01'},
    'qa_margin': {'RiskMode':'0','UseFixedLot':'true','FixedLotSize':'500','MaximumDailyLoss':'0','MaximumOverallDrawdown':'0'},
    'qa_daily_budget': {'MaximumDailyLoss':'0.01'},
    'qa_london': {'EnableLondonSession':'true'},
}
jobs = [{'run':'train0_default_evidence','symbol':'EURUSD','from':'2024.04.01','to':'2025.04.01'}]
for run, changes in scenarios.items():
    lines = []
    for line in baseline.splitlines():
        key = line.split('=',1)[0]
        lines.append(key+'='+changes[key] if key in changes else line)
    preset = project/'MT5/Config'/(run+'.set')
    preset.write_text('\n'.join(lines)+'\n', encoding='utf-16')
    jobs.append({'run':run,'symbol':'EURUSD','from':'2025.01.01','to':'2025.04.01','preset':str(preset)})
(project/'Backtests/acceptance_jobs.json').write_text(json.dumps(jobs,indent=2),encoding='utf-8')
integration=project/'MT5/Config/qa_integration.set'
settings={'EnableLondonSession':'true','SessionTimeMode':'1','EnableNewsFilter':'true','BrokerUTCOffsetFile':'QA_missing_file.csv'}
integration.write_text('\n'.join(line.split('=',1)[0]+'='+settings[line.split('=',1)[0]] if line.split('=',1)[0] in settings else line for line in baseline.splitlines())+'\n',encoding='utf-16')
jobs.append({'run':'qa_integration','symbol':'EURUSD','from':'2025.01.06','to':'2025.01.14','preset':str(integration),'integration':True})
jobs.append({'run':'final_default_smoke','symbol':'EURUSD','from':'2025.01.03','to':'2025.01.04'})
(project/'Backtests/acceptance_jobs.json').write_text(json.dumps(jobs,indent=2),encoding='utf-8')
print('Created',len(jobs),'tester-only scenarios. These are acceptance checks, not candidate selection.')
