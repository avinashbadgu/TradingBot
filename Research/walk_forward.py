import pandas as pd


def plan_windows(start, end, training_months=12, forward_months=3, holdout_fraction=.30):
    start, end = pd.Timestamp(start), pd.Timestamp(end)
    if start >= end or training_months < 1 or forward_months < 1 or not 0 < holdout_fraction < 1:
        raise ValueError('Invalid chronology/windows')
    holdout_start = start + (end-start)*(1-holdout_fraction)
    holdout_start = holdout_start.normalize()
    rows, cursor = [], start
    while True:
        split = cursor + pd.DateOffset(months=training_months)
        finish = split + pd.DateOffset(months=forward_months)
        if finish > holdout_start:
            break
        rows.append(dict(fold=len(rows), train_start=cursor, train_end=split,
                         forward_start=split, forward_end=finish))
        cursor += pd.DateOffset(months=forward_months)
    return pd.DataFrame(rows), {'start': str(holdout_start), 'end': str(end),
        'policy': 'Untouched final holdout. Flat starts and forced closure at each test boundary.'}


def select_training(training, minimum_trades=100, maximum_drawdown=20, minimum_pf=1.1):
    """Consumes training rows ONLY. Forward/OOS columns are forbidden."""
    if any('oos' in c.lower() or 'forward' in c.lower() for c in training.columns):
        raise ValueError('Forward information supplied to training selector')
    eligible = training[(training.total_trades >= minimum_trades) &
                        (training.maximum_drawdown_pct <= maximum_drawdown) &
                        (training.profit_factor >= minimum_pf)]
    if eligible.empty:
        return None
    return eligible.sort_values(['recovery_factor','expectancy','config_id'],
        ascending=[False,False,True], na_position='last').iloc[0].config_id


def evaluate_walk_forward(training, forward):
    rows = []
    for fold, train in training.groupby('fold', sort=True):
        selected = select_training(train.drop(columns=['fold']))
        if selected is None:
            rows.append(dict(fold=fold, config_id=None, status='no_training_candidate'))
            continue
        match = forward[(forward.fold == fold) & (forward.config_id == selected)]
        if len(match) != 1:
            raise ValueError(f'Fold {fold} requires exactly one independent forward export for {selected}')
        row = dict(fold=fold, config_id=selected, status='evaluated')
        selected_train = train[train.config_id == selected].iloc[0]
        for metric in ['profit_factor','maximum_drawdown_pct','expectancy','total_trades','net_profit']:
            row['train_'+metric] = selected_train[metric]
            row['forward_'+metric] = match.iloc[0][metric]
        rows.append(row)
    return pd.DataFrame(rows)
