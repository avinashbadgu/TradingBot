import csv
import re
from pathlib import Path

root=Path(__file__).resolve().parents[1]
text=(root/'MT5/Experts/TradingBot/Inputs.mqh').read_text()
rows=[]
for kind,name,value in re.findall(r'^input\s+(\w+)\s+(\w+)\s*=([^;]+);',text,re.M):
    rows.append({'name':name,'type':kind,'default':value.strip()})
with (root/'Documentation/INPUT_REFERENCE.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=['name','type','default']);writer.writeheader();writer.writerows(rows)
print(f'{len(rows)} inputs documented')
enums={'TESTER_ONLY':'0','RISK_PERCENT':'2','BROKER_TIME':'0','PERIOD_H1':'16385','PERIOD_M5':'5'}
settings=[]
for row in rows:
    value=enums.get(row['default'],row['default']).strip('"')
    settings.append(f"{row['name']}={value}")
(root/'MT5/Config/TradingBot_Default.set').write_text('\n'.join(settings)+'\n',encoding='utf-16')
