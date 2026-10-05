import pandas as pd
import pytest
from Research.execution_audit import audit


def fixture(tmp_path,native_risk=20):
    prefix=tmp_path/'gold'
    def save(kind,rows):pd.DataFrame(rows).to_csv(str(prefix)+'_'+kind+'.csv',index=False)
    save('environment',[{'property':k,'value':v} for k,v in dict(symbol='XAUUSD',currency='USD',tick_size=.01,point=.01,
        volume_step=.01,contract_size=100,commission_reserve_per_lot=10,tick_value=.1).items()])
    save('orders',[dict(order_id=1,type=2,setup_time='2026-01-05 08:05:00',done_time='2026-01-05 08:06:00',
        expiration='2026-01-05 09:05:00',entry=2000,sl=1995,tp=2015,initial_volume=.04)])
    save('deals',[dict(order_id=1,entry=0,time='2026-01-05 08:06:00',price=2000)])
    save('equity',[dict(time='2026-01-05 08:05:00',equity=10000)])
    save('events',[dict(time='2026-01-05 08:05:00',setup_id='gold1',message='Place limit retcode=10009 order=1')])
    save('risks',[dict(entry=2000,original_sl=1995,volume=.04,initial_risk_amount=native_risk)])
    signals=tmp_path/'signals.csv'
    pd.DataFrame([dict(setup_id='gold1',entry=2000,sl=1995,tp=2015,signal_time='2026-01-05 08:05:00')]).to_csv(signals,index=False)
    return prefix,signals


def test_gold_uses_verified_native_risk_not_inconsistent_tick_value(tmp_path):
    prefix,signals=fixture(tmp_path)
    result=audit(prefix,signals,tmp_path/'audit')
    assert result['status']=='passed' and result['orders_checked']==1


def test_gold_refuses_incompatible_contract_valuation(tmp_path):
    prefix,signals=fixture(tmp_path,native_risk=2)
    with pytest.raises(ValueError,match='Native monetary risk'):
        audit(prefix,signals,tmp_path/'audit')
