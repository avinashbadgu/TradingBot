from pathlib import Path
import hashlib
import numpy as np
import pandas as pd


def read_csv(path):
    path = Path(path)
    raw = path.read_bytes()
    encoding = 'utf-16' if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else 'utf-8-sig'
    return pd.read_csv(path, encoding=encoding)


def require(frame, columns):
    missing = set(columns) - set(frame.columns)
    if missing:
        raise ValueError(f'Missing columns: {sorted(missing)}')


def dates(series):
    return pd.to_datetime(series, format='mixed', errors='raise')


def load_deals(path):
    df = read_csv(path)
    require(df, ['deal_id', 'position_id', 'time', 'symbol', 'entry', 'volume',
                 'profit', 'commission', 'swap', 'fee'])
    if df.deal_id.duplicated().any():
        raise ValueError('Duplicate deal IDs')
    df['time'] = dates(df.time)
    numeric = ['volume', 'profit', 'commission', 'swap', 'fee']
    if not np.isfinite(df[numeric].to_numpy(dtype=float)).all():
        raise ValueError('Non-finite deal values')
    if (df.volume <= 0).any() or not df.entry.isin([0, 1, 3]).all():
        raise ValueError('Unsupported reversal/non-trade deal or invalid volume')
    df['net'] = df[['profit', 'commission', 'swap', 'fee']].sum(axis=1)
    rows = []
    for pid, group in df.sort_values(['time', 'deal_id']).groupby('position_id'):
        entries = group[group.entry == 0]
        exits = group[group.entry.isin([1, 3])]
        if entries.empty:
            raise ValueError(f'Position {pid} has exits without entry history')
        if group.symbol.nunique() != 1:
            raise ValueError(f'Mixed symbols in position {pid}')
        if exits.empty or abs(entries.volume.sum() - exits.volume.sum()) > 1e-7:
            raise ValueError(f'Position {pid} is open or volume history is incomplete')
        if exits.time.min() < entries.time.min():
            raise ValueError('Exit predates entry')
        rows.append(dict(position_id=pid, symbol=group.symbol.iloc[0],
                         entry_time=entries.time.min(), exit_time=exits.time.max(),
                         volume=entries.volume.sum(), pnl=group.net.sum(),
                         commission=group.commission.sum(), swap=group.swap.sum(),
                         fee=group.fee.sum()))
    return pd.DataFrame(rows, columns=['position_id', 'symbol', 'entry_time',
        'exit_time', 'volume', 'pnl', 'commission', 'swap', 'fee'])


def load_equity(path):
    df = read_csv(path)
    require(df, ['time', 'balance', 'equity'])
    df['time'] = dates(df.time)
    if df.empty or not df.time.is_monotonic_increasing:
        raise ValueError('Equity must be nonempty and chronological')
    if not np.isfinite(df[['balance', 'equity']].to_numpy(dtype=float)).all():
        raise ValueError('Non-finite equity')
    # Preserve duplicate-second ticks: removing them can remove drawdown peaks.
    return df


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
