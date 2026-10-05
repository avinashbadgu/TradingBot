"""Local MT5 research bridge with an explicit no-trading allowlist."""
import argparse
import json
import urllib.request
from pathlib import Path

URL='http://127.0.0.1:22346/mcp'


def request(method,params=None,session=None):
    headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}
    if session:headers['Mcp-Session-Id']=session
    body={'jsonrpc':'2.0','id':1,'method':method,'params':params or {}}
    req=urllib.request.Request(URL,json.dumps(body).encode(),headers)
    with urllib.request.urlopen(req,timeout=45) as response:
        raw=response.read().decode()
        if raw.startswith('event:') or raw.startswith('data:'):
            data=[line[5:].strip() for line in raw.splitlines() if line.startswith('data:')]
            result=json.loads(data[-1])
        else:result=json.loads(raw)
        return result,response.headers.get('Mcp-Session-Id',session)


def main():
    p=argparse.ArgumentParser();p.add_argument('--list',action='store_true');p.add_argument('--output',required=True)
    a=p.parse_args()
    init,session=request('initialize',{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'TradingBot research','version':'1.0'}})
    if 'error' in init:raise RuntimeError(init['error'])
    result,_=request('tools/list',{},session)
    Path(a.output).write_text(json.dumps(result,indent=2),encoding='utf-8')
    tools=result.get('result',{}).get('tools',[])
    print(json.dumps([{'name':t['name'],'description':t.get('description','')[:140]} for t in tools],indent=2))


if __name__=='__main__':main()
