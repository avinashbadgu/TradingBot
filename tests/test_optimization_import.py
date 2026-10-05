import json
import pytest
from Research.optimizer_analysis import read_optimization_xml
from Research.prepare_jobs import prepare


def test_spreadsheetml_optimization_import(tmp_path):
    path=tmp_path/'optimization.xml'
    path.write_text('''<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"><Worksheet><Table>
    <Row><Cell><Data>Pass</Data></Cell><Cell><Data>Profit</Data></Cell><Cell><Data>Trades</Data></Cell><Cell><Data>RiskRewardRatio</Data></Cell></Row>
    <Row><Cell><Data>7</Data></Cell><Cell><Data>120.5</Data></Cell><Cell><Data>100</Data></Cell><Cell><Data>3</Data></Cell></Row>
    </Table></Worksheet></Workbook>''')
    result=read_optimization_xml(path)
    assert result.config_id.iloc[0]=='7' and result.net_profit.iloc[0]==120.5
    assert result.total_trades.iloc[0]==100 and result.rr.iloc[0]==3


def test_no_optimization_without_baseline_evidence(tmp_path):
    path=tmp_path/'settings.json';path.write_text(json.dumps({'baseline_evidence':{}}))
    with pytest.raises(ValueError,match='Optimization blocked'):prepare(path,tmp_path/'jobs')
