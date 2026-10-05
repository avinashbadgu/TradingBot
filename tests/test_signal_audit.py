import pandas as pd
from Research.signal_audit import audit


def fixture(tmp_path, signal_time='2025.01.02 06:05:02'):
    hours=pd.date_range('2025-01-02',periods=8,freq='h')
    higher=pd.DataFrame({'timeframe':'PERIOD_H1','time':hours,'open':1.02,'high':1.03,
        'low':[1.01,1.0,.99,1.0,1.01,.98,1.01,1.0],'close':1.02,'available_at':hours+pd.Timedelta(hours=1)})
    minutes=pd.to_datetime(['2025-01-02 05:55','2025-01-02 06:00','2025-01-02 06:05'])
    lower=pd.DataFrame({'timeframe':'PERIOD_M5','time':minutes,'open':[1.005,1.,1.006],
        'high':[1.006,1.007,1.008],'low':[.999,.999,1.004],'close':[1.,1.006,1.005],
        'available_at':minutes+pd.Timedelta(minutes=5)})
    pd.concat([higher,lower]).to_csv(tmp_path/'bars.csv',index=False)
    sid=f'v1_EURUSD_16385_5_1_{int(hours[2].timestamp())}_{int(hours[5].timestamp())}'
    pd.DataFrame({'time':['2025.01.02 06:00:05',signal_time],'setup_id':[sid,sid],
        'message':['Sweep confirmed; setup created','Engulfing confirmed']}).to_csv(tmp_path/'events.csv',index=False)


def test_delayed_first_tick_does_not_change_bar_boundary(tmp_path):
    fixture(tmp_path)
    result=audit(tmp_path/'bars.csv',tmp_path/'events.csv',tmp_path/'audit')
    assert result['status']=='passed' and result['engulfings_checked']==1


def test_signal_before_entry_bar_close_is_rejected(tmp_path):
    fixture(tmp_path,'2025.01.02 06:04:59')
    result=audit(tmp_path/'bars.csv',tmp_path/'events.csv',tmp_path/'audit')
    assert result['status']=='failed' and result['failures']
