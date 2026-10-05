# Robustness research workflow

Optimization is gated by a compiled, behavior-verified baseline with verified
tick coverage and costs. The example research settings deliberately leave
these flags false. Do not flip them merely to bypass the gate.

1. Copy `Research/research_settings.example.json`, map actual broker symbols,
   choose available dates and register evidence paths. Freeze criteria first.
2. Start with RR x fractal period. Other management/session dimensions require
   separate hypotheses. More than four dimensions is rejected by job planning.
3. Generate training presets and run jobs:

```powershell
.venv/Scripts/python.exe -m Research.prepare_jobs Research/research_settings.json --output Backtests/study_jobs
.venv/Scripts/python.exe -m Research.study plan --start 2020-01-01 --end 2026-01-01 --output Backtests/windows
```

Each preset can be passed to `scripts/run_tester.ps1 -PresetPath ... -Symbol ...
-From ... -To ... -Run ...`. Dates/outputs must identify the actual run.
For native MT5 optimization, enable only the planned parameter rows in the
Inputs tab, use complete slow optimization for the small grid, and export the
optimization table as XML. `optimizer_analysis.read_optimization_xml` imports
SpreadsheetML. Detailed files are disabled during optimization; rerun selected
configurations individually to get trades/equity.

## Walk forward and holdout

Default windows: 12 calendar months training, 3 months forward, roll 3 months.
Reserve final 30% chronological span as a holdout. A window that does not fit
before the holdout is omitted, never shortened silently. All periods are
independent MT5 runs starting flat; inspect end-of-test closure.

Training selection sees training metrics only: minimum 100 trades, PF >=1.1,
equity DD <=20%, then recovery factor, expectancy, deterministic config ID tie
break. Configurations are frozen before their forward run. OOS data cannot be
passed to the training selector. Failed training eligibility means no selection,
not relaxed criteria. Final holdout remains untouched until design is frozen.

Study manifest `runs` records `config_id`, `symbol`, `fold`, `phase` (train,
forward, holdout), `start`, `end`, relative `deals`/`equity` paths and parameters.
Top-level `parameters` lists stability dimensions. One symbol per manifest:

```json
{"parameters":["rr","fractal_period"],"runs":[],"filters":{
 "minimum_trades":100,"maximum_drawdown":20,"minimum_profit_factor":1.1,
 "minimum_oos_trades":30,"minimum_oos_profit_factor":1.0,
 "maximum_parameter_sensitivity":1.0}}
```

Populate only with actual exports, then:

```powershell
.venv/Scripts/python.exe -m Research.study analyze Backtests/study.json --output Reports/study
```

Reports include training and matching forward metrics, holdout rows, stability
plots, and candidate eligibility/rejection reasons. Missing OOS/stability
evidence fails eligibility. Single-symbol run profits must not be summed into
a claimed portfolio return: that requires common-capital execution simulation.

## Metrics and simulation assumptions

Trade = complete position including partial exits and every explicit deal cost.
Zero-P/L trades are separate from wins/losses. PF is unavailable with no losing
trades. Sharpe/Sortino use business-day equity returns, 252 observations/year,
zero risk-free assumption unless supplied, and at least 60 return observations.
Sortino denominator is root mean squared negative excess returns over all
observations. Short-period annualized returns are withheld. Boundary-month
returns are labeled potentially partial. Money-weighted deposits are not
accepted as strategy return; tester balance must reconcile with net deals.

Monte Carlo defaults to 2,000 seeded circular block-bootstrap paths with block
length 5 and at least 50 trades. Permutation isolates sequence risk and preserves
additive terminal P/L. Additional account-currency cost scenarios are explicitly
parameterized. Neither method simulates intratrade fills, leverage feedback,
percentage-risk resizing, or guaranteed future outcomes. Report 5/50/95
percentiles for DD, return and loss streak, pointwise equity bands, and fraction
of paths reaching nonpositive equity.

Parameter neighbors change exactly one grid coordinate within the same
symbol/fold/phase. Sensitivity is max absolute neighbor-minus-center expectancy
divided by max(abs(center),1e-9); near-zero centers are deliberately unstable.
Marginal stability charts show medians across other parameters, not proof that
every combination is stable. Neighborhood counts and nonpositive fraction
must accompany the chart.

OverfittingRiskIndicator uses the seven flags approved in the audit. It outputs
100*flagged/7 only when all seven are evaluable. Otherwise it reports a
provisional flagged/evaluated count and missing evidence. Concentration in
quarters requires four observed quarters; symbol concentration requires three
symbols; top-five winner concentration requires 50 trades. The current single-
run/study tables expose provisional indicators; no missing evidence is treated
as a reassuring zero. No configuration is labeled universally best.
