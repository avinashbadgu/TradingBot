import numpy as np


def overfitting_indicator(trades, in_sample=None, out_of_sample=None, stability=None,
                         optimized_parameter_count=None, minimum_trades=100):
    flags = {'low_trade_count': len(trades) < minimum_trades}
    wins = trades.pnl[trades.pnl > 0].sort_values(ascending=False)
    flags['few_winners_dominate'] = bool(wins.head(5).sum()/wins.sum() > .5) if len(trades) >= 50 and len(wins) else None
    flags['oos_degradation'] = None
    if in_sample and out_of_sample:
        a, b = in_sample.get('expectancy'), out_of_sample.get('expectancy')
        if a is not None and b is not None and a > 0:
            flags['oos_degradation'] = bool(b <= 0 or b < .5*a)
    flags['parameter_cliff'] = None
    if stability and stability.get('neighbor_count', 0) >= 2:
        value = stability.get('neighbor_nonpositive_fraction')
        if value is not None and np.isfinite(value):
            flags['parameter_cliff'] = bool(value > .5)
    quarters = trades.groupby(trades.exit_time.dt.to_period('Q')).pnl.sum() if len(trades) else None
    flags['period_concentration'] = None
    if quarters is not None and len(quarters) >= 4 and quarters[quarters > 0].sum() > 0:
        flags['period_concentration'] = bool(quarters.max()/quarters[quarters > 0].sum() > .5)
    symbols = trades.groupby('symbol').pnl.sum() if len(trades) else None
    flags['symbol_concentration'] = None
    if symbols is not None and len(symbols) >= 3 and symbols[symbols > 0].sum() > 0:
        flags['symbol_concentration'] = bool(symbols.max()/symbols[symbols > 0].sum() > .5)
    flags['too_many_parameters'] = optimized_parameter_count > 4 if optimized_parameter_count is not None else None
    evaluated = [bool(v) for v in flags.values() if v is not None]
    return dict(flags=flags, evaluated=len(evaluated), flagged=sum(evaluated),
                score=100*sum(evaluated)/7 if len(evaluated) == 7 else None,
                status='complete' if len(evaluated) == 7 else 'provisional',
                interpretation='Declared heuristic flags, not a probability or universal scientific score.')
