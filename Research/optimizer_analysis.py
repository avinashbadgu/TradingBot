from dataclasses import dataclass
import pandas as pd
import xml.etree.ElementTree as ET


@dataclass
class ResearchFilters:
    minimum_trades: int = 100
    maximum_drawdown: float = 20
    minimum_profit_factor: float = 1.1
    minimum_oos_trades: int = 30
    minimum_oos_profit_factor: float = 1.0
    maximum_parameter_sensitivity: float = 1.0


def candidates_table(frame, filters=None):
    f = filters or ResearchFilters()
    rules = {'total_trades': ('ge', f.minimum_trades),
             'maximum_drawdown_pct': ('le', f.maximum_drawdown),
             'profit_factor': ('ge', f.minimum_profit_factor),
             'oos_trades': ('ge', f.minimum_oos_trades),
             'oos_profit_factor': ('ge', f.minimum_oos_profit_factor),
             'parameter_sensitivity': ('le', f.maximum_parameter_sensitivity)}
    result = frame.copy()
    for column in ['higher_tf','entry_tf','rr','fractal_period','session','engulfing_filter',
                   'sharpe','walk_forward_performance','monte_carlo_drawdown',
                   'parameter_stability','overfitting_risk']:
        if column not in result:
            result[column] = None
    reasons = []
    for _, row in result.iterrows():
        failed = []
        for column, (op, threshold) in rules.items():
            value = row.get(column)
            if value is None or pd.isna(value):
                failed.append(column + ': missing')
            elif not (value >= threshold if op == 'ge' else value <= threshold):
                failed.append(column + ': failed')
        reasons.append('; '.join(failed))
    result['rejection_reasons'] = reasons
    result['eligible'] = result.rejection_reasons.eq('')
    # Transparent lexicographic order; does not name a universal best setting.
    columns = [c for c in ['eligible','oos_profit_factor','expectancy','maximum_drawdown_pct'] if c in result]
    return result.sort_values(columns, ascending=[c == 'maximum_drawdown_pct' for c in columns], kind='stable')


def read_optimization_xml(path):
    """Read MT5's exported SpreadsheetML table, preserving parameter columns."""
    root=ET.parse(path).getroot()
    ns={'s':'urn:schemas-microsoft-com:office:spreadsheet'}
    tables=root.findall('.//s:Table',ns)
    if not tables:
        raise ValueError('Not an MT5 SpreadsheetML export')
    rows=[]
    for row in tables[0].findall('s:Row',ns):
        values=[]
        for cell in row.findall('s:Cell',ns):
            index=int(cell.get('{'+ns['s']+'}Index',len(values)+1))
            values.extend([None]*max(0,index-1-len(values)))
            data=cell.find('s:Data',ns)
            values.append(data.text if data is not None else None)
        rows.append(values)
    header=next((i for i,r in enumerate(rows) if 'Pass' in r and 'Profit' in r),None)
    if header is None: raise ValueError('Optimization header not found')
    columns=rows[header]
    frame=pd.DataFrame([r+[None]*(len(columns)-len(r)) for r in rows[header+1:] if len(r)<=len(columns)],columns=columns)
    mapping={'Pass':'config_id','Profit':'net_profit','Profit Factor':'profit_factor',
             'Expected Payoff':'expectancy','Recovery Factor':'recovery_factor',
             'Sharpe Ratio':'sharpe','Equity DD %':'maximum_drawdown_pct','Trades':'total_trades',
             'RiskRewardRatio':'rr','FractalPeriod':'fractal_period',
             'HigherTimeframe':'higher_tf','EntryTimeframe':'entry_tf'}
    frame=frame.rename(columns=mapping)
    for column in frame.columns:
        if column!='config_id':
            converted=pd.to_numeric(frame[column],errors='coerce')
            if converted.notna().sum()==frame[column].notna().sum():frame[column]=converted
    return frame
