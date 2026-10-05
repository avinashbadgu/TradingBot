# Deterministic strategy contract

Version 1 implements the approved audit. No performance is implied.

FractalPeriod is the odd TOTAL candle count. A strict high/low must exceed/be
below all k=(N-1)/2 neighbors on each side. Confirmation is the close of the
last right neighbor. Only references confirmed at or before sweep OPEN are
eligible. The most recent qualifying reference is frozen for that sweep.
Equal highs/lows disqualify a fractal. First penetration retires a level by
default, including a penetration without reclaim. Dual sweeps are skipped.
Existing setups have priority; new sweeps are consumed without being queued.

A bullish sweep has low < reference and close > reference; bearish reverses
the comparisons. The entry candle must OPEN at/after sweep confirmation.
Its closed body contains the previous closed body, inclusive by default,
with current direction and opposite previous direction. Previous dojis are
excluded. Optional filters are in SYMBOL_POINT units, not pips.

Entry is body midpoint; buy rounds down/sell up to tick size. Stop is below
engulfing low / above high with buffer, rounded outward. Target uses the
rounded entry and stop and rounds outward. Broker-invalid geometry rejects
the setup; it never becomes a market order or an assumed historical fill.
First valid engulfing consumes the setup even when risk/execution rejects it.

Setup bars count actual closed eligible entry bars. The last permitted bar
is evaluated before bar expiry. Minute expiry blocks submission at equality.
Pending lifetime is min(configured expiration, mandatory hard lifetime).
Server-side specified expiration is required by default. Disabling that
requirement allows a documented best-effort client cancellation fallback.

Initial R uses actual filled entry and original SL and never changes after
breakeven/trailing. A partial-close attempt is persisted before submission;
an uncertain result is never automatically retried. All stops only improve.

Single symbol per instance, one setup and position per symbol. Demo mode uses
one account coordinator per terminal to prevent competing EA instances.
Multi-symbol research uses separate tester runs; this is NOT yet a coordinated
multi-symbol execution portfolio. Unrelated exposure is never managed.

First attach starts observing now, without replaying old sweeps. Restart
expires unfilled signal searches, reconciles known orders/positions, and blocks
unknown ownership. Failed or missing persistence prevents new entries.

News filtering intentionally fails initialization if enabled: no reliable
historical calendar provider is bundled. Real-account execution is prohibited.
