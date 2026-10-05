import numpy as np
import pandas as pd


def streak(values, positive):
    maximum = current = 0
    for x in values:
        current = current + 1 if (x > 0 if positive else x < 0) else 0
        maximum = max(maximum, current)
    return maximum


def drawdown(equity):
    values = np.asarray(equity, dtype=float)
    if not len(values):
        return np.array([]), np.array([])
    peaks = np.maximum.accumulate(values)
    amounts = peaks - values
    percent = np.divide(amounts * 100, peaks, out=np.full_like(values, np.nan), where=peaks > 0)
    return amounts, percent


def statistics(trades, equity, initial_balance=None, risk_free_annual=0.0,
               annualization_days=252, minimum_return_observations=60):
    """No cash flows allowed in tester equity. Ratios use net daily equity returns."""
    t = trades.sort_values('exit_time') if len(trades) else trades
    pnl = t.pnl.to_numpy(dtype=float)
    start = float(initial_balance if initial_balance is not None else equity.balance.iloc[0])
    if start <= 0:
        raise ValueError('Initial capital must be positive')
    wins, losses = pnl[pnl > 0], pnl[pnl < 0]
    gross_profit, gross_loss = float(wins.sum()), float(-losses.sum())
    amounts, percent = drawdown(np.r_[start, equity.equity.to_numpy(dtype=float)])
    series = equity.set_index('time').equity
    daily = series.resample('D').last().ffill()
    # Restrict annualization to business-day observations for these FX/CFD studies.
    daily = daily[daily.index.dayofweek < 5]
    returns = daily.pct_change().dropna()
    sharpe = sortino = None
    if len(returns) >= minimum_return_observations and (daily > 0).all():
        excess = returns - ((1 + risk_free_annual) ** (1 / annualization_days) - 1)
        sd = excess.std(ddof=1)
        downside = np.sqrt(np.mean(np.minimum(excess, 0) ** 2))
        sharpe = float(excess.mean() / sd * np.sqrt(annualization_days)) if sd > 0 else None
        sortino = float(excess.mean() / downside * np.sqrt(annualization_days)) if downside > 0 else None
    monthly_values = series.resample('ME').last()
    monthly = monthly_values / monthly_values.shift(1, fill_value=start) - 1
    annual_values = series.resample('YE').last()
    annual = annual_values / annual_values.shift(1, fill_value=start) - 1
    days = max((equity.time.iloc[-1] - equity.time.iloc[0]).total_seconds() / 86400, 1 / 86400)
    maxdd = float(amounts.max())
    total = float(pnl.sum())
    result = dict(total_trades=len(pnl), winning_trades=len(wins), losing_trades=len(losses),
        breakeven_trades=int((pnl == 0).sum()), win_rate=float(len(wins) / len(pnl)) if len(pnl) else None,
        gross_profit=gross_profit, gross_loss=gross_loss, net_profit=total,
        average_win=float(wins.mean()) if len(wins) else None,
        average_loss=float(losses.mean()) if len(losses) else None,
        average_trade=float(pnl.mean()) if len(pnl) else None,
        expectancy=float(pnl.mean()) if len(pnl) else None,
        profit_factor=gross_profit / gross_loss if gross_loss > 0 else None,
        profit_factor_note='undefined without losing trades' if gross_loss == 0 else None,
        maximum_drawdown=maxdd, maximum_drawdown_pct=float(np.nanmax(percent)),
        recovery_factor=total / maxdd if maxdd > 0 else None,
        return_drawdown=(total / start) / (float(np.nanmax(percent)) / 100) if np.nanmax(percent) > 0 else None,
        sharpe=sharpe, sortino=sortino, daily_return_observations=len(returns),
        maximum_consecutive_wins=streak(pnl, True), maximum_consecutive_losses=streak(pnl, False),
        trades_per_30_days=len(pnl) * 30 / days,
        average_rr=float(t.r_multiple.mean()) if 'r_multiple' in t and t.r_multiple.notna().all() and len(t) else None,
        annualized_return=(float(equity.equity.iloc[-1]) / start) ** (365.25 / days) - 1 if days >= 365 and equity.equity.iloc[-1] > 0 else None,
        observed_calendar_days=days)
    return result, monthly, annual if days >= 365 else annual.iloc[:0]
