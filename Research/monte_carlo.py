import numpy as np
from .statistics import drawdown, streak


def monte_carlo(pnl, capital, iterations=2000, seed=260928, method='block_bootstrap',
                block_size=5, minimum_trades=50, extra_cost_mean=0., extra_cost_sd=0.):
    """Additive net P/L scenarios; extra costs are account currency per trade.

    These are conditional scenarios, not a fill simulator or guarantees.
    Compounding and intratrade excursions cannot be inferred from trade P/L.
    """
    p = np.asarray(pnl, dtype=float)
    if len(p) < minimum_trades:
        return {'status': 'insufficient_trades', 'required': minimum_trades, 'observed': len(p)}
    if capital <= 0 or iterations < 100 or block_size < 1 or extra_cost_mean < 0 or extra_cost_sd < 0 or not np.isfinite(p).all():
        raise ValueError('Invalid Monte Carlo settings')
    rng = np.random.default_rng(seed)
    paths = np.empty((iterations, len(p) + 1))
    metrics = np.empty((iterations, 4))
    for i in range(iterations):
        if method == 'permutation':
            sample = rng.permutation(p)
        elif method == 'block_bootstrap':
            starts = rng.integers(0, len(p), size=int(np.ceil(len(p) / block_size)))
            sample = p[((starts[:, None] + np.arange(block_size)) % len(p)).ravel()[:len(p)]]
        else:
            raise ValueError('Unknown resampling method')
        costs = np.maximum(0, rng.normal(extra_cost_mean, extra_cost_sd, len(p)))
        sample = sample - costs
        path = np.r_[capital, capital + np.cumsum(sample)]
        paths[i] = path
        dd, dd_pct = drawdown(path)
        metrics[i] = [dd.max(), np.nanmax(dd_pct), (path[-1] / capital - 1) * 100, streak(sample, False)]
    quantiles = np.percentile(metrics, [5, 50, 95], axis=0)
    return dict(status='computed', method=method, seed=seed, iterations=iterations,
        assumptions=dict(capital=capital, block_size=block_size, extra_cost_mean=extra_cost_mean,
                         extra_cost_sd=extra_cost_sd, capital_model='additive fixed trade P/L'),
        percentiles={name: dict(zip(['p05','p50','p95'], quantiles[:, j].tolist())) for j, name in enumerate(['drawdown','drawdown_pct','return_pct','loss_streak'])},
        equity_percentiles=np.percentile(paths, [5, 50, 95], axis=0).tolist(),
        nonpositive_equity_fraction=float(np.mean((paths <= 0).any(axis=1))))
