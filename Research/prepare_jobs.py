"""Create reviewable MT5 test jobs. Never starts terminals or submits orders."""
import argparse
import itertools
import json
from pathlib import Path
from .walk_forward import plan_windows


def prepare(settings_path, output):
    source=Path(settings_path);settings=json.loads(source.read_text(encoding='utf-8-sig'))
    evidence=settings.get('baseline_evidence',{})
    required=['compilation_passed','behavior_verified','real_tick_coverage_verified','costs_verified']
    missing=[k for k in required if evidence.get(k) is not True]
    if missing:raise ValueError('Optimization blocked until baseline evidence exists: '+', '.join(missing))
    for key in ['compiler_log','tester_report','signal_review']:
        if not evidence.get(key) or not (source.parent/evidence[key]).is_file():
            raise ValueError('Missing evidence file: '+key)
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    grid=settings['grid'];keys=list(grid)
    if len(keys)>4:raise ValueError('More than four parameters requires a separately reviewed research design')
    windows,holdout=plan_windows(settings['start'],settings['end'],settings.get('training_months',12),settings.get('forward_months',3))
    if windows.empty:raise ValueError('Insufficient history for requested windows and reserved holdout')
    jobs=[]
    for index,values in enumerate(itertools.product(*(grid[k] for k in keys))):
        config_id=f'c{index:04d}'
        params=settings.get('fixed_inputs',{}) | dict(zip(keys,values))
        params['ExecutionMode']=0
        for logical,symbol in settings['symbols'].items():
            for row in windows.to_dict('records'):
                run=f'{logical}_fold{row["fold"]}_{config_id}_train'
                preset=output/(run+'.set')
                text='\n'.join(f'{k}={str(v).lower() if isinstance(v,bool) else v}' for k,v in params.items())
                preset.write_text(text+'\nRunId='+run+'\n',encoding='utf-16')
                jobs.append(dict(run=run,config_id=config_id,symbol=symbol,fold=row['fold'],phase='train',
                    start=str(row['train_start'].date()),end=str(row['train_end'].date()),preset=str(preset.resolve())))
    (output/'training_jobs.json').write_text(json.dumps(jobs,indent=2),encoding='utf-8')
    (output/'holdout.json').write_text(json.dumps(holdout,indent=2),encoding='utf-8')
    (output/'FORWARD_POLICY.txt').write_text('Select a configuration from each completed training fold using Research.walk_forward.select_training. Only then generate and execute its forward job. Keep final holdout untouched until research choices are frozen.\n',encoding='utf-8')
    return jobs


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('settings');p.add_argument('--output',required=True)
    a=p.parse_args();print(f'Prepared {len(prepare(a.settings,a.output))} training jobs')
