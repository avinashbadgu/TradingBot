# TradingBot — MT5 strategy and robustness research

A modular MQL5 Expert Advisor for confirmed fractal sweeps, closed-candle
engulfing signals, and midpoint limit entries. Python analyzes MT5 exports;
trade execution stays in MetaTrader 5.

The current research focus is **XAUUSD (gold)**. This is a research build:
real-account execution is blocked, and no configuration has qualified as a
robust trading strategy in the completed study.

## Strategy defaults

| Setting | Default |
| --- | --- |
| Higher / entry timeframe | H1 / M5 |
| Fractal | Five bars total; two closed bars on each side |
| Trigger | Confirmed sweep followed by a closed engulfing candle |
| Entry | Buy/sell limit at the engulfing body midpoint |
| Target | 3R, with a buffered stop beyond the engulfing candle |
| Risk | 0.25% of equity, with execution-cost sizing reserves |
| Spread cap | 30 symbol points |
| Execution | Strategy Tester only by default; real accounts rejected |
| Optional management | Breakeven, partial TP and trailing disabled by default |

See [deterministic strategy rules](Documentation/STRATEGY.md) and
[input and risk accounting](Documentation/INPUTS.md). News filtering is
explicitly unavailable; enabling it rejects initialization.

## Recorded results

The XAUUSD run for **1 January–28 September 2026** recorded **132 trades,
-$316.78 net profit, 0.861 profit factor, and 6.156% native MT5 equity drawdown**
on a $10,000 simulated account. These are native tester metrics; the separate
gold report audit is not presented as completed here.

The earlier EURUSD training study tested 20 RR/fractal combinations in each
of three overlapping windows. None of the 60 passes qualified. Known tick
gaps invalidate affected windows for complete real-tick claims.

Read the [results and data limitations](Documentation/RESULTS.md),
[verification matrix](Documentation/VERIFICATION.md), and
[gold test plan](Documentation/GOLD_2026_PLAN.md).
Raw broker history, exports, generated reports, and machine-specific deployment
files stay local and are not included in this repository.

## Set up

MT5 compilation and testing require Windows and an installed MetaTrader 5
terminal. The Python research layer can run independently on Python 3.12.

```powershell
git clone https://github.com/avinashbadgu/TradingBot.git
cd TradingBot
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider
```

The local research regression suite passed **24 tests** before publication.
Python tests include synthetic fixtures; they do not establish profitability.

## Compile and backtest gold

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy.ps1 -Install
# Close MT5 normally first; the runner does not close an existing terminal.
powershell -ExecutionPolicy Bypass -File scripts/run_tester.ps1 -Symbol XAUUSD -From 2026.01.01 -To 2026.09.29 -Run gold_2026
# Wait for Strategy Tester to finish before collecting its files.
powershell -ExecutionPolicy Bypass -File scripts/collect_exports.ps1 -Run gold_2026
.\.venv\Scripts\python.exe -m Research.report_generator --deals Backtests/gold_2026_exports/TradingBot_gold_2026_XAUUSD_deals.csv --equity Backtests/gold_2026_exports/TradingBot_gold_2026_XAUUSD_equity.csv --risks Backtests/gold_2026_exports/TradingBot_gold_2026_XAUUSD_risks.csv --output Reports/gold_2026
```

Dates use broker-server time; `-To` is exclusive. Symbol names depend on the
broker. Review tester coverage and cost evidence before marking a report
verified. The generic report remains provisional without supplied metadata.

Deployment discovers the terminal and compiles the EA and native checks.
The runner disables live AutoTrading and uses local tester agents.
See [installation](Documentation/INSTALLATION.md) and
[backtesting](Documentation/BACKTESTING.md) for the full workflow.

## Project layout

| Directory | Purpose |
| --- | --- |
| `MT5/Experts/TradingBot/` | EA, signal detectors, risk, orders, persistence and native checks |
| `MT5/Config/` | Default preset and the limited training grid |
| `Research/` | Metrics, signal/order audits, walk-forward selection, Monte Carlo and reports |
| `scripts/` | Compile, install, run tests, collect exports and prepare scenarios |
| `tests/` | Python regression tests |
| `Documentation/` | Rules, inputs, protocols and verification limitations |
| `Backtests/`, `Reports/` | Local generated artifacts; ignored except directory placeholders |

[Optimization guidance](Documentation/OPTIMIZATION.md) explains chronological
selection and missing-evidence handling. The archived `suite_report` workflow
requires the original local study exports and manifests; a fresh clone does
not contain those datasets.

One EA manages one symbol/setup, with one demo coordinator per account and
terminal. Independent symbol tests are not a portfolio simulation. Real
process-crash recovery, disconnected execution, and some broker rejection
conditions still need operational validation.
