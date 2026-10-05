import json
from pathlib import Path
import numpy as np
import pandas as pd
import pytest
from Research.data import load_deals, load_equity
from Research.statistics import statistics, drawdown
from Research.monte_carlo import monte_carlo
from Research.parameter_stability import parameter_stability
from Research.optimizer_analysis import candidates_table
from Research.walk_forward import plan_windows, select_training, evaluate_walk_forward
from Research.robustness import overfitting_indicator
from Research.report_generator import generate
from Research.suite_report import resolve_run_name


def exports(tmp_path):
    # Explicitly synthetic: one trade with two partial exits and costs on entry/exit.
    rows=[(1,10,'2025.01.02 10:00:00',0,1,0,-2,0,0),
          (2,10,'2025.01.02 11:00:00',1,.4,40,-1,0,0),
          (3,10,'2025.01.02 12:00:00',1,.6,-20,-1,-1,0)]
    d=pd.DataFrame(rows,columns=['deal_id','position_id','time','entry','volume','profit','commission','swap','fee'])
    d['symbol']='EURUSD';d.to_csv(tmp_path/'deals.csv',index=False)
    e=pd.DataFrame({'time':['2025.01.02 09:00:00','2025.01.02 10:00:00','2025.01.02 11:00:00','2025.01.02 12:00:00'],
                    'balance':[1000,998,1037,1015],'equity':[1000,970,1050,1015]})
    e.to_csv(tmp_path/'equity.csv',index=False)
    return tmp_path/'deals.csv',tmp_path/'equity.csv'


def test_partial_deals_aggregate_costs_once(tmp_path):
    d,e=exports(tmp_path);t=load_deals(d)
    assert len(t)==1 and t.pnl.iloc[0]==15 and t.volume.iloc[0]==1


def test_incomplete_trade_rejected(tmp_path):
    d,e=exports(tmp_path);pd.read_csv(d).iloc[:-1].to_csv(d,index=False)
    with pytest.raises(ValueError,match='incomplete'):load_deals(d)


def test_duplicate_deal_rejected(tmp_path):
    d,e=exports(tmp_path);df=pd.read_csv(d);pd.concat([df,df.iloc[:1]]).to_csv(d,index=False)
    with pytest.raises(ValueError,match='Duplicate'):load_deals(d)


def test_intrasecond_drawdown_preserved(tmp_path):
    p=tmp_path/'equity.csv'
    pd.DataFrame({'time':['2025.01.01 00:00:00']*3,'balance':[100]*3,'equity':[100,120,90]}).to_csv(p,index=False)
    df=load_equity(p);amount,pct=drawdown(df.equity)
    assert len(df)==3 and amount.max()==30 and pct.max()==25


def test_statistics_use_equity_not_just_closed_trades(tmp_path):
    d,e=exports(tmp_path);s,m,a=statistics(load_deals(d),load_equity(e))
    assert s['net_profit']==15 and s['maximum_drawdown']==35
    assert s['profit_factor'] is None and s['sharpe'] is None and s['average_rr'] is None
    assert not len(a)


def test_permutation_preserves_terminal_return():
    p=np.tile([10,-5,2,-9],20)
    mc=monte_carlo(p,1000,iterations=100,method='permutation')
    q=mc['percentiles']['return_pct']
    assert q['p05']==q['p50']==q['p95']


def test_monte_carlo_reproducible_and_cost_sensitive():
    p=np.tile([10,-5,2,-9],20)
    a=monte_carlo(p,1000,iterations=100)
    b=monte_carlo(p,1000,iterations=100)
    assert a==b
    c=monte_carlo(p,1000,iterations=100,extra_cost_mean=2)
    assert c['percentiles']['return_pct']['p50'] < a['percentiles']['return_pct']['p50']
    assert monte_carlo([1,2],100)['status']=='insufficient_trades'


def test_stability_compares_only_one_parameter_same_symbol():
    df=pd.DataFrame({'config_id':['a','b','c','d'],'symbol':['EURUSD']*3+['XAUUSD'],
        'rr':[2,3,4,3],'fractal':[5]*4,'expectancy':[2,10,-2,1000]})
    result=parameter_stability(df,['rr','fractal']).set_index('config_id')
    assert result.loc['b','neighbor_count']==2
    assert result.loc['b','neighbor_median']==0
    assert result.loc['d','neighbor_count']==0


def test_missing_oos_fails_candidate_filter():
    df=pd.DataFrame([dict(config_id='a',total_trades=200,maximum_drawdown_pct=5,profit_factor=2,expectancy=10)])
    result=candidates_table(df)
    assert not result.eligible.iloc[0] and 'oos_trades: missing' in result.rejection_reasons.iloc[0]


def test_walk_forward_chronology_and_holdout():
    windows,holdout=plan_windows('2020-01-01','2026-01-01')
    assert (windows.train_end==windows.forward_start).all()
    assert windows.forward_end.max()<=pd.Timestamp(holdout['start'])
    assert (windows.forward_start.iloc[1:].to_numpy()>=windows.forward_end.iloc[:-1].to_numpy()).all()


def test_training_cannot_consume_forward_metrics():
    with pytest.raises(ValueError,match='Forward information'):
        select_training(pd.DataFrame({'oos_profit_factor':[2]}))


def test_forward_does_not_change_training_selection():
    train=pd.DataFrame([dict(fold=0,config_id='a',total_trades=120,maximum_drawdown_pct=5,
        profit_factor=1.3,recovery_factor=2,expectancy=10,net_profit=1200),
        dict(fold=0,config_id='b',total_trades=120,maximum_drawdown_pct=8,
        profit_factor=1.2,recovery_factor=1,expectancy=8,net_profit=960)])
    forward=train.copy();forward.loc[0,'net_profit']=-1000;forward.loc[1,'net_profit']=100000
    result=evaluate_walk_forward(train,forward)
    assert result.config_id.iloc[0]=='a' and result.forward_net_profit.iloc[0]==-1000


def test_missing_evidence_never_becomes_low_overfit_score(tmp_path):
    d,e=exports(tmp_path);r=overfitting_indicator(load_deals(d))
    assert r['score'] is None and r['status']=='provisional' and r['flags']['low_trade_count']


def test_report_pipeline(tmp_path):
    d,e=exports(tmp_path)
    meta=tmp_path/'metadata.json';meta.write_text(json.dumps({'synthetic_fixture':True}))
    result=generate(d,e,tmp_path/'report',meta)
    assert result['statistics']['net_profit']==15
    assert (tmp_path/'report'/'equity_drawdown.png').exists()
    assert 'SYNTHETIC TEST FIXTURE' in (tmp_path/'report'/'index.html').read_text(encoding='utf-8')
    assert (tmp_path/'report'/'statistics.csv').read_bytes().startswith(b'\xef\xbb\xbf')


def test_legacy_gold_study_name_resolves_to_existing_export_run():
    assert resolve_run_name('gold_available_2026') == 'gold_2026_ytd_20260929'
    assert resolve_run_name('gold_2026_ytd_20260929') == 'gold_2026_ytd_20260929'


def test_reconciliation_failure_blocks_report(tmp_path):
    d,e=exports(tmp_path);df=pd.read_csv(e);df.loc[3,'balance']=2000;df.to_csv(e,index=False)
    with pytest.raises(ValueError,match='reconciliation'):generate(d,e,tmp_path/'bad')
