# Baseline and behavioral verification

1. Connect MT5 to a working demo server and synchronize broker symbols.
2. Compile/install using `scripts/deploy.ps1 -Install`.
3. Run LogicTests in the tester's Mathematical calculations mode. It checks
   native fractal, engulfing, and session primitives and must log zero failures.
   It is not a market backtest and does not establish execution correctness.
4. Run TradingBot with the default preset, EURUSD (actual broker name), M5,
   Every tick based on real ticks, 10,000 USD, 1:100 leverage, 100 ms simulated
   execution delay. The initial attempted period is 2025-01-01 to 2025-04-01.
   These are research assumptions, not recommendations or known data coverage.
5. Inspect tester journal for missing/generated/replaced ticks, synchronization
   failures, symbol restrictions and rejected requests. Record the actual
   commission/swap model; commission sizing reserves are NOT tester fees.
6. Verify the baseline has complete exports and reconciles before optimization.
7. Use visual mode and exported bars/events to inspect at least one buy and
   one sell from fractal confirmation through entry and exit, plus rejections.

Native tester settings: real ticks Model=4; Optimization=0. Do not use modeled
OHLC or zero costs as a silent fallback. Historical spread is embedded in
bid/ask execution and must not be deducted again in Python.

Data availability for M1/M5/M15/M30/H1/H4/D1 is exported with the environment.
Having a folder or an initial synchronized series does not establish complete
date-range coverage. Inspect tester logs, tick coverage and missing periods.
Historical UTC sessions require an actual broker offset schedule. No news
backtest is represented as supported without a historical provider.

## Export contract

Each individual run writes into the local testing agent's MQL5/Files:

* `TradingBot_<RunId>_<symbol>_deals.csv`: raw deals with all explicit costs.
* `_equity.csv`: initial equity, changed tick equity and periodic flat samples.
  Preserve duplicate-second rows; they may contain different drawdown extrema.
* `_risks.csv`: each entry deal's original monetary stop risk, aggregated by
  position for realized R-multiples.
* `_events.csv`: timestamped strategy/execution events with setup identifiers.
* `_bars.csv`: closed entry/higher timeframe OHLC and availability timestamps.
* `_environment.csv`: broker/account type (no credentials), specifications,
  commission/swap rules and timeframe availability.
* `_orders.csv`: native order history including pending lifetime and geometry.
* `_tester_statistics.csv`: native MT5 statistics, kept separate from Python ratios.
* `_optimization.csv`: host-collected native optimization frames for the planned grid.

`collect_exports.ps1` copies matching files into this project and refuses
ambiguous duplicate names from multiple agents. Retain original tester report,
journals, compile log, preset, code hash and launch configuration with each run.

Run the report generator from project root as shown in README. Optional metadata:

```json
{"real_tick_coverage_verified":false,"costs_verified":false,"behavior_verified":false,
 "commission_model":"unverified","swap_model":"unverified","delay_ms":100}
```

Only change flags after inspecting the supporting evidence. Reports remain
provisional when required evidence is missing. A complete baseline still does
not establish profitability across markets or robustness.
