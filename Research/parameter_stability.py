import numpy as np
import pandas as pd


def parameter_stability(candidates, parameters, metric='expectancy'):
    """Immediate grid neighbors differ in exactly one parameter; same symbol/fold."""
    records = []
    keys = [x for x in ['symbol', 'fold', 'phase'] if x in candidates]
    groups = candidates.groupby(keys, dropna=False) if keys else [(None, candidates)]
    for _, group in groups:
        grids = {p: sorted(group[p].dropna().unique()) for p in parameters}
        for _, row in group.iterrows():
            neighbors = []
            for p in parameters:
                grid = grids[p]
                index = grid.index(row[p])
                for ni in [index-1, index+1]:
                    if ni < 0 or ni >= len(grid):
                        continue
                    mask = group[p].eq(grid[ni])
                    for other in parameters:
                        if other != p:
                            mask &= group[other].eq(row[other])
                    neighbors.extend(group.loc[mask, metric].dropna().tolist())
            center = row[metric]
            scale = max(abs(center), 1e-9) if pd.notna(center) else np.nan
            sensitivity = max(abs(x-center)/scale for x in neighbors) if neighbors else np.nan
            record = {k: row[k] for k in ['config_id'] + keys}
            record.update(neighbor_count=len(neighbors), parameter_sensitivity=sensitivity,
                neighbor_nonpositive_fraction=float(np.mean(np.asarray(neighbors)<=0)) if neighbors else np.nan,
                neighbor_median=float(np.median(neighbors)) if neighbors else np.nan)
            records.append(record)
    return pd.DataFrame(records)
