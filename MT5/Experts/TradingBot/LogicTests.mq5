#property strict
#property version "1.00"
#include "Inputs.mqh"
#include "Logger.mqh"
#include "FractalDetector.mqh"
#include "EngulfingDetector.mqh"
#include "SessionFilter.mqh"
int failures=0,checks=0;
void Check(bool condition,string name) { checks++; if(!condition) { failures++; Print("QA_FAIL ",name); } else Print("QA_PASS ",name); }
int OnInit() { if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED; return INIT_SUCCEEDED; }
void OnTick() {}
double OnTester() {
 MqlRates r[]; ArrayResize(r,5);
 for(int i=0;i<5;i++) { r[i].high=2; r[i].low=1; }
 r[2].high=3; r[2].low=0;
 Check(IsFractal(r,2,2,true),"strict high"); Check(IsFractal(r,2,2,false),"strict low");
 r[4].high=3; Check(!IsFractal(r,2,2,true),"high tie rejected");
 r[0].low=0; Check(!IsFractal(r,2,2,false),"low tie rejected");
 MqlRates p={},c={}; p.open=2; p.close=1; c.open=1; c.close=2;
 Check(IsEngulfing(c,p,1),"bullish engulf inclusive");
 Check(!IsEngulfing(c,p,-1),"opposite direction rejected");
 c.open=1.1; Check(!IsEngulfing(c,p,1),"incomplete engulf rejected");
 p.open=1; p.close=2; c.open=2; c.close=1;
 Check(IsEngulfing(c,p,-1),"bearish engulf");
 p.open=2; p.close=2; Check(!IsEngulfing(c,p,-1),"previous doji rejected");
 Check(ParseMinute("08:00")==480,"session parse"); Check(ParseMinute("25:00")==-1,"invalid hour");
 Check(ParseMinute("aa:00")==-1,"invalid digits");
 Check(InWindow(480,480,1020),"inclusive start"); Check(!InWindow(1020,480,1020),"exclusive end");
 Check(InWindow(30,1320,120),"overnight window"); Check(!InWindow(600,1320,120),"outside overnight window");
 PrintFormat("QA_RESULT checks=%d failures=%d",checks,failures);
 return failures==0?checks:-failures;
}
