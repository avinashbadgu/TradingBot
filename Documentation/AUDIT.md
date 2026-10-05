# Approved audit and implementation decisions

The user approved audit-first development on 28 September 2026. The baseline
sequence remains confirmed H1 fractal -> closed H1 sweep -> subsequent closed
M5 engulfing -> 50% body limit entry with buffered candle stop and 3R target.

Resolved ambiguities: five-bar means two neighbors on each side; strict fractal
comparisons; reference available by sweep opening; first penetration consumes
liquidity; simultaneous opposite sweeps skipped; active setup retained; entry
candle opens at/after confirmation; previous engulf candle may precede it;
inclusive body containment; previous doji excluded; first engulf consumes setup;
finite hard pending lifetime; risk percentages explicitly defined; current equity
is percentage-sizing base; all sessions when both session switches are off.

Additional parameters expose body boundaries, previous-candle timing, reference
consumption, penetration/reclaim filters, execution reserves, historical UTC
schedule, configured offset, server-expiry requirement and management retry delay.
Dual-sweep policy and active-setup precedence are fixed documented rules in this
version. A future change to either constitutes a new research hypothesis/version.

Impossible guarantees explicitly rejected: exact unseen midnight equity/peaks;
preventing a broker fill during cancellation races; guaranteed SL cash loss;
client expiry while disconnected; native calendar access in Strategy Tester;
perfect fill simulation from trade-level Monte Carlo. Unknown data blocks the
dependent feature or remains marked missing; it is not fabricated.

Architecture separates deterministic signals, execution, position management,
account risk snapshots, chart/log/export concerns and Python-only research.
The initial build remains restricted to tester/demo, with real-account denial.

Primary platform references used for implementation:

* https://www.mql5.com/en/docs/trading/ordercalcprofit
* https://www.mql5.com/en/docs/trading/ordersend
* https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
* https://www.mql5.com/en/docs/constants/structures/mqltraderequest
* https://www.mql5.com/en/docs/dateandtime/timegmt
* https://www.mql5.com/en/book/advanced/calendar/calendar_trading
* https://www.metatrader5.com/en/terminal/help/start_advanced/start
* https://www.metatrader5.com/en/terminal/help/algotrading/testing
