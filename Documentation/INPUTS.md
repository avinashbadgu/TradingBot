# Inputs and risk accounting

All inputs are defined in `MT5/Experts/TradingBot/Inputs.mqh`. The generated
`INPUT_REFERENCE.csv` lists their types and exact compiled defaults.

## Strategy

HigherTimeframe must exceed and be divisible by EntryTimeframe. FractalPeriod
is odd and at least 3. FractalLookback bounds history search. Strict comparison
and timing rules are in STRATEGY.md. Body, SL buffer, spread, trailing distance,
and execution-reserve distances use symbol points. Orders normalize to tick
size. Maximum body zero disables the upper bound. Direction switches do not
change protection on existing owned positions.

## Risk

RiskMode: 0=fixed lot, 1=fixed USD, 2=percentage of current equity.
UseFixedLot must agree with RiskMode; ambiguous combinations fail initialization.
USD risk converts via a fresh direct/inverse broker conversion symbol. Missing
conversion blocks an order. OrderCalcProfit evaluates reference-volume stop
loss in account currency, including symbol contract calculation rules. Add
CommissionReservePerLot (account currency per lot, full-trade allowance) and
AdverseExecutionReservePoints to the sizing reserve. These reserves do not
magically charge costs in Strategy Tester: actual costs must be verified there.

Volume rounds down to volume step, caps at maximum and fails below minimum.
Fixed lots still pass the remaining daily/overall risk budget checks. Pending
orders count toward capacity. Existing positions/pending orders reserve stop
risk; unknown or unsupported external exposure blocks additional entries.
Account equity protections include unrelated account performance but never
modify unrelated trades. Limits cannot prevent gap losses or broker fill races.

MaximumDailyLoss and MaximumOverallDrawdown are percentages, zero disables
the respective threshold. Daily loss is decline from day-start equity adjusted
for cash flows. Overall drawdown is decline from observed adjusted equity peak.
Daily loss locks until next valid day baseline; overall lock persists. Daily
trade count groups entries by position ID and first fill date. Streaks group
completed position P/L including entry/exit costs.

Demo attachment midway through a day without an existing valid snapshot blocks
entries until a valid new-day baseline. An unobserved boundary with exposure
blocks that day's entries. Exact equity peaks during downtime cannot be inferred
from deals. Original SL, setup/order identity and partial-close intent persist
in the MQL5 Files sandbox. Account risk snapshots persist as terminal globals.
Do not manually delete state files to evade risk locks.

MaximumTradesPerSymbol currently must be 1. MaximumActiveTrades includes all
account orders/positions, not just this EA. The demo coordinator deliberately
allows one EA per account within a terminal; separate terminals or unrelated
EAs cannot share an atomic risk reservation with this implementation.

## Sessions

Both sessions disabled = all sessions. Enabled windows are combined by OR.
Time format HH:MM; start inclusive/end exclusive; overnight windows supported.
Equal endpoints are rejected. SessionTimeMode: 0=server, 1=UTC, 2=configured
fixed UTC offset. UTC conversion requires `broker_offsets.csv` in MQL5/Files:

```csv
server_from,server_until,offset_minutes
```

Supply verified dated intervals in chronological nonoverlapping order, using
server timestamps (`YYYY.MM.DD HH:MM:SS`). No timezone rows are fabricated.
UTC = server - applicable historical offset; configured time adds
ConfiguredUTCOffsetMinutes. Missing interval blocks entries. London/NY labels
are configured windows, not automatic civil-time/DST timezone databases.

## Execution and management

RequireServerExpiration defaults true. If the broker does not support exact
pending expiry, the order is rejected. Disabling it explicitly accepts client
best-effort cancellation while the EA is connected. HardPendingLifetimeMinutes
always remains finite, even when normal expiration is disabled.

Breakeven, partial TP and trailing are independently optional and disabled in
the baseline. R uses actual entry and original SL. Breakeven offset is a price
offset, not guaranteed net cost recovery. Partial-close attempts are persisted
before sending and never repeated after uncertain outcomes. Both closed and
remaining volumes must be valid. Netting reductions use an opposite deal
targeted to an exclusively owned position; mixed ownership is unsupported.

News filter is unavailable and fails initialization if enabled. Notifications
default off. Push/email use terminal-configured destinations only when enabled.
RunId identifies exports and must be unique per run; sequential reruns with the
same ID overwrite their agent's export files. Optimization suppresses detailed
files to prevent output collisions; rerun candidates individually for research.
