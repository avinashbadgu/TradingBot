# Verification status — 29 September 2026

This is an installed and tested research build, **not a production-certified EA**.
Published summaries are in [recorded results](RESULTS.md). Full historical
reports remain local in `Reports/study_20260928/` and are excluded from Git.
No profitable configuration has qualified for selection.

## Verified locally

* TradingBot and LogicTests compile with **0 errors, 0 warnings**.
* Compiled source/binary installed into the uniquely identified MT5 data folder.
* Strategy Tester actually loaded and executed TradingBot; this is verified by
  completed tests and exports, independently of Navigator appearance.
* Native mathematical test suite: **16 checks passed**, zero failures.
* Python research regression suite: **24 passed**, exit code 0 (publication check, 5 October 2026).
* Native recovery integration run: lost-ticket recovery, no-duplicate, and cleanup assertions passed; **36/37** checks passed overall. The weekend-timer assertion did not fire in that tester run and remains unverified.
* EURUSD baseline, January–March 2025: **50 trades, -278.55 USD, PF 0.5571**.
* Independent baseline audit: **100 sweeps, 62 engulfings, 60 pending orders,
  50 fills passed**. Actual exported bullish and bearish candle charts reviewed.
* Frozen default EURUSD holdout, January–August 2026: **182 trades, -119.56 USD,
  PF 0.9394**. Independent audit: **281 sweeps, 217 engulfings, 212 orders,
  182 fills passed**.
* Native training: 20 RR/fractal combinations per window, three windows,
  **60 completed passes; every pass lost money**. No qualifying candidate;
  chronological selection stays flat. These are overlapping experiments.
* Actual Monte Carlo and immediate-neighbor parameter-stability reports generated.
  Fixed-default forward tests are separate from selected-system performance.

## Data and statistical limitations

MT5 reported **599 missing real-tick minutes on 2025-05-27** and substituted
generated ticks. The April–June 2025 forward diagnostic and training folds 1/2
include that gap and are not accepted as complete real-tick evidence. Per-run
`Backtests/*_log_evidence.json` preserves completion, warnings, and coverage scope.
The baseline and final holdout had no reported missing-tick warnings.

XAUUSD January–March 2025 had **no real ticks at all**. Its native output is a
generated-tick diagnostic only. A separately declared June–August 2026 gold
run uses unchanged settings on available history; see its own coverage status.

The baseline broker reported zero EURUSD commission rules; spread is embedded
in fills and actual swap is charged. Zero demo commission is not a future live
broker assumption. Reports include labeled additional-cost sensitivity.
Sizing reserves are not transaction fees.

Python baseline tick-equity DD is 4.4046%; native tester DD is 4.3667%.
Both are retained; the exact measurement discrepancy is unresolved. Python
Sharpe/Sortino use daily equity returns and are not native MT5 ratios.

Independent symbol runs have separate USD10,000 starting capital. They are not
a coordinated portfolio. Cross-symbol results and each run's data quality are
listed in the research report. Short positive runs are not robustness evidence.

## Behavioral acceptance matrix

| Case | Evidence / remaining limitation |
|---|---|
| Bullish/bearish sweep and engulfing | Independent closed-bar audit of baseline and holdout; native primitive checks |
| Duplicate sweep/order | No duplicate observed IDs/orders in audited runs; tester-only lost-ticket recovery, no-duplicate, and cleanup assertions passed; process-crash fault injection pending |
| Multiple symbols | Independent native test jobs; no multi-symbol portfolio-execution claim |
| Percentage risk, entry/SL/TP | Independent actual-order geometry and EURUSD/USD sizing audits passed |
| Pending expiration | Actual specified expiry and fill timing audited; offline/disconnected execution not tested |
| Fixed lot/USD, spread, daily trade count, minimum volume, margin, daily budget, London session | Dedicated scenarios and checks in `Reports/acceptance/acceptance.json`; consult their explicit status |
| Partial TP, breakeven, trailing | Dedicated combined-management tester scenario; consult acceptance report; netting/freeze/rejection variants remain untested |
| Session boundaries | Native inclusive/exclusive and overnight tests passed; historical broker DST schedule not supplied |
| Maximum volume and non-USD account conversion | Implemented; isolated broker boundary/reference tests still required |
| Existing foreign position/order | Ownership/capacity guards implemented; fault-injection test pending |
| Invalid stops / market closed | Preflight guards implemented; deliberate broker rejection scenarios pending |
| Restart and uncertain execution | Persistence/reconciliation implemented; tester-only lost-ticket recovery passed without restarting the process; real restart/crash and partial-submit tests pending |
| Daily/overall equity locks after downtime | Conservative blocking implemented; offline equity peaks cannot be reconstructed exactly |
| News | Explicitly unavailable; enabling the input fails initialization |
| Strategy Tester / native visual UI | Actual automated tests complete; exported signal charts reviewed; native visual UI and Navigator appearance not visually verified |

No live AutoTrading was enabled and no existing account positions/orders were
managed. All automatic executions used Strategy Tester. Real-account execution
is blocked in code. Initial defaults remain tester-only with notifications off.

## Reproduce the study

The frozen protocol is `RESEARCH_PLAN_20260928.md`. Native grid, selected-flat
record, tester configurations, exports, log evidence and code hashes are retained
under local `Backtests/`, excluded from Git. With those original artifacts present,
run `Research.suite_report` from project root to regenerate
HTML/CSV/JSON and plots. Acceptance checks use `Research.acceptance_audit`.
Do not change missing-evidence flags to force candidate acceptance.
