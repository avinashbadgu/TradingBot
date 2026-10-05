# XAUUSD current-year backtest — 29 September 2026

Requested focus: gold, current year. Test 2026-01-01 through 2026-09-29
exclusive, using broker-server dates (last completed day: 28 September).
Use the unchanged default H1/M5 strategy, confirmed five-bar fractals, 3R
target, 0.25% equity risk, USD10,000 initial capital, 30-symbol-point spread
cap, native broker costs, and 100 ms execution delay. Optional breakeven,
partial TP and trailing remain off. No optimization is part of this run.

Use MT5 model 4 (real ticks), inspect native coverage warnings, reconcile
deals with equity, and independently audit gold signal timing and geometry.
Any missing real ticks invalidate a complete real-tick claim. Report broker
point/tick/contract specifications and rejected entries, especially the spread
cap, without silently changing inputs after seeing performance.

This is a requested YTD diagnostic, not an untouched OOS selection experiment.
Live AutoTrading remains disabled; only Strategy Tester executes orders.
