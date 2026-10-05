# Frozen research protocol — 28 September 2026

Declared after baseline behavior verification, before viewing these training,
forward or holdout results. Baseline January–March 2025 is development data;
it is not represented as unseen OOS data.

Native complete grid: RR {2,2.5,3,3.5,4} x fractal period {3,5,7,9} (20 passes).
All other inputs remain the safe baseline values. Initial capital 10,000 USD,
0.25% equity risk, native broker spread/swap, broker commission rules, 100 ms
tester delay. MetaQuotes-Demo reports no EURUSD commission rules; zero charged
commission is a broker-demo property, not a claim about a future real broker.
Additional commissions will be evaluated as labeled sensitivity assumptions.

| Fold | Training (end exclusive) | Forward (end exclusive) |
|---|---|---|
| 0 | 2024-04-01 to 2025-04-01 | 2025-04-01 to 2025-07-01 |
| 1 | 2024-07-01 to 2025-07-01 | 2025-07-01 to 2025-10-01 |
| 2 | 2024-10-01 to 2025-10-01 | 2025-10-01 to 2026-01-01 |

Training eligibility stays at >=100 trades, PF>=1.1, equity DD<=20%. Selection:
highest recovery factor, then expectancy, then configuration ID. A fold with no
eligible configuration remains flat; thresholds are not relaxed to force a trade.
Default-parameter forward runs are diagnostic comparisons, not selected-system
performance. Native optimization is independent for each fold.

Final untouched diagnostic holdout: 2026-01-01 to 2026-09-01, with the ORIGINAL
default configuration (RR3, fractal5) fixed now. This explicit holdout is about
28% of the April 2024–September 2026 research span. It is not used for selection.
No post-holdout retuning is part of this protocol.

Cross-symbol diagnostics use the original default configuration over baseline
2025-01-01 to 2025-04-01 on the eight requested symbols, with actual broker
names. Identical 30-point spread cap is intentionally retained for this first
comparison; a symbol with no allowed entries is reported, not silently retuned.
No sum of independently capitalized runs is called a portfolio return.

Missing real-tick coverage invalidates the affected research run. Records of
download/synchronization warnings are retained. Testing infrastructure uses only
local agents; cloud agents are disabled. Failed filters and unavailable data are
reported as results rather than filled with invented numbers.

## Data-availability addendum (before supplemental gold results)

The completed XAUUSD January–March 2025 run reports **no real ticks for the
entire requested period**. It is excluded from complete real-tick evidence.
One fixed-default supplemental gold diagnostic is therefore declared for
2026-06-01 through 2026-09-01, using the available downloaded archive. No inputs
are retuned. This date change is a data-availability fallback, not part of the
original same-period comparison or a selected walk-forward candidate.
