# Installation and safety

`scripts/deploy.ps1` discovers terminal data directories using `origin.txt`,
requires exactly one target (or explicit `-DataPath`), compiles EA and native
logic tests using that installation's MetaEditor, verifies zero errors and
warnings, and optionally copies files to `MQL5/Experts/TradingBot`.
An existing TradingBot folder is backed up to this project's Backtests folder.
The preset is copied to `MQL5/Profiles/Tester`. No other EA is overwritten.
The deployment manifest records binary SHA256 and actual paths.

Installation does not attach an EA or enable AutoTrading. `ExecutionMode=0`
is tester-only; `ExecutionMode=1` permits demo only. Real accounts always fail
initialization. The native LogicTests EA is tester-only and has no order code.

To verify manually: Navigator -> Expert Advisors -> Refresh -> TradingBot.
Select `TradingBot/TradingBot.ex5` in Strategy Tester (Ctrl+R). Do not attach it
to a chart to run a backtest. Compile success does not prove Navigator UI was
visually checked; the manifest records those separately.

`run_tester.ps1` refuses to close a running terminal. When MT5 is closed it
launches the identified installation with an alternate tester-only INI and
AutoTrading disabled. Existing server positions are not modified. The terminal
may restore its existing charts, but this workflow never adds an EA to them.

The local MT5 MCP endpoint may require authorization. A 401 response is a
connection restriction, not permission to bypass it. The included diagnostic
bridge only lists tools. Desktop helper aborts input when MT5 lacks focus.

## Python

Python 3.12 was available locally. A project virtual environment uses the
existing numpy/pandas/pytest installation and an installed matplotlib package.
For a clean environment:

```powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.txt
.venv/Scripts/python.exe -m pytest -q
```

If the Windows sandbox blocks pytest's private temporary-directory ACLs,
run tests in an ordinary local PowerShell. Do not interpret cleanup or
permission failures as test assertion failures or as successful test exit.
