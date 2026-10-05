# Recorded research results

These figures summarize local MetaQuotes-Demo Strategy Tester exports, not
forecasts. Each run starts with USD10,000, default H1/M5 signals, five-bar
fractals, RR3, and 0.25% equity risk. Dates below include the final tested day.
Drawdown in this table is the **native MT5 equity drawdown percentage**.

| Symbol / run | Period | Trades | Net P/L (USD) | Profit factor | Native DD |
| --- | --- | ---: | ---: | ---: | ---: |
| XAUUSD requested YTD diagnostic | 2026-01-01–2026-09-28 | 132 | -316.78 | 0.8608 | 6.1556% |
| EURUSD baseline | 2025-01-01–2025-03-31 | 50 | -278.55 | 0.5571 | 4.3667% |
| EURUSD fixed-default holdout | 2026-01-01–2026-08-31 | 182 | -119.56 | 0.9394 | 4.3225% |

The gold YTD tester log reported completed real-tick execution without missing
tick warnings. Its standalone Python signal/order audit and report were
prepared but are not claimed completed in this publication. Historical tester
logs and raw exports remain local, outside Git.

The 60 EURUSD native training passes varied only RR and fractal period over
three overlapping windows. Every pass lost money and none passed the fixed
selection filters. The selected walk-forward policy consequently stayed flat;
default forward runs were separate diagnostics.

## Limitations

- EURUSD had 599 missing real-tick minutes on 2025-05-27. Affected training
  and forward windows contain generated ticks and are not accepted as complete
  real-tick evidence.
- XAUUSD January–March 2025 had no real ticks available at all. That earlier
  generated-tick result is excluded from the table above.
- Spread is embedded in fills. Broker tester commission and swap are retained;
  zero demo commission is not a future broker assumption. Sizing reserves are
  allowances, not actual fees.
- Python exported-equity drawdown differs from native MT5 drawdown. For the
  EURUSD baseline it is 4.4046%, versus native 4.3667%; the exact discrepancy
  remains unresolved. The metrics are not interchangeable.
- The YTD gold diagnostic was requested after prior research. It is not an
  untouched out-of-sample selection experiment.
- No configuration is represented as production-certified or profitable across
  markets. See [verification](VERIFICATION.md) for outstanding scenarios.
