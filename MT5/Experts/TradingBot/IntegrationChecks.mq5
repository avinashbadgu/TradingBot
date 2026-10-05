#property strict
#property version "1.00"
#property description "Tester-only native acceptance checks; never attaches to an account."
#include "Inputs.mqh"
#include "Logger.mqh"
#include "Persistence.mqh"
#include "SessionFilter.mqh"
#include "NewsFilter.mqh"
#include "ChartManager.mqh"
#include "TradeStatistics.mqh"
#include "RiskManager.mqh"
#include "OrderManager.mqh"
#include "PositionManager.mqh"
int checks=0,failures=0,output=INVALID_HANDLE;
bool exercised=false,weekendChecked=false;
void Check(bool ok,string name) {
 checks++; if(!ok) failures++;
 Print(ok?"QA_PASS ":"QA_FAIL ",name);
 if(output!=INVALID_HANDLE) { FileWrite(output,name,ok); FileFlush(output); }
}
MqlTradeRequest Request(ENUM_ORDER_TYPE kind,double volume,ulong magic) {
 MqlTick t; SymbolInfoTick(_Symbol,t); MqlTradeRequest q={};
 q.action=TRADE_ACTION_DEAL; q.symbol=_Symbol; q.type=kind; q.volume=volume;
 q.price=kind==ORDER_TYPE_BUY?t.ask:t.bid; q.magic=magic;
 q.deviation=Slippage; q.type_filling=MarketFilling(); return q;
}
int OnInit() {
 if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
 if(_Symbol!="EURUSD" || SessionTimeMode!=UTC_TIME || !EnableLondonSession || !EnableNewsFilter) return INIT_PARAMETERS_INCORRECT;
 output=FileOpen("TradingBot_"+RunId+"_"+_Symbol+"_checks.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
 if(output==INVALID_HANDLE) return INIT_FAILED;
 FileWrite(output,"check","passed"); objectPrefix="TB_TEST_ONLY_"; namespaceKey="TB_TEST_ONLY_";
 InitStats();
 Check(!ValidateNews(),"unsupported enabled news filter fails explicitly");
 Check(!LoadOffsets(),"missing historical timezone file rejected");
 int parsed=0;
 Check(!ParseOffsetMinutes("not_a_number",parsed),"malformed timezone offset cannot silently become UTC");
 Check(!ParseOffsetMinutes("",parsed) && !ParseOffsetMinutes("+",parsed),"empty or sign-only timezone offset rejected");
 Check(!ParseOffsetMinutes("841",parsed),"timezone offset outside supported bound rejected");
 Check(ParseOffsetMinutes("0",parsed) && parsed==0,"explicit zero timezone offset accepted");
 Check(ParseOffsetMinutes("-330",parsed) && parsed==-330,"negative timezone offset parsed");
 Check(ParseOffsetMinutes("+120",parsed) && parsed==120,"positive signed timezone offset parsed");
 ArrayResize(offsetsFrom,2);ArrayResize(offsetsUntil,2);ArrayResize(offsetsMinutes,2);
 offsetsFrom[0]=D'2025.01.01';offsetsUntil[0]=D'2025.03.30';offsetsMinutes[0]=120;
 offsetsFrom[1]=D'2025.03.30';offsetsUntil[1]=D'2026.01.01';offsetsMinutes[1]=180;
 Check(!SessionAllowed(D'2025.01.06 09:59'),"synthetic UTC offset before London start");
 Check(SessionAllowed(D'2025.01.06 10:00'),"synthetic UTC offset inclusive start");
 Check(!SessionAllowed(D'2025.01.06 19:00'),"synthetic UTC offset exclusive end");
 Check(SessionAllowed(D'2025.04.01 11:00'),"dated offset interval changes conversion");
 Check(!SessionAllowed(D'2026.01.01 12:00'),"uncovered timezone interval blocks entry");
 // Use a declared synthetic zero offset for isolated execution checks.
 offsetsMinutes[0]=0;offsetsMinutes[1]=0;
 EventSetTimer(3600); return INIT_SUCCEEDED;
}
void OnTick() {
 if(exercised) return;
 string reason; UpdateStats(true); if(!EntryAllowed(reason)) return;
 exercised=true;
 MqlTick t; SymbolInfoTick(_Symbol,t);
 double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
 Check(MathAbs(VolumeFloor(minimum+step*.9)-minimum)<1e-8,"lot step rounds down");
 MqlTradeRequest q=Request(ORDER_TYPE_BUY,minimum,MagicNumber+77); MqlTradeCheckResult c={}; MqlTradeResult r={};
 q.volume=minimum/2;
 Check(!OrderCheck(q,c) && c.retcode==TRADE_RETCODE_INVALID_VOLUME,"native minimum volume rejection");
 q.volume=maximum+step;
 Check(!OrderCheck(q,c) && c.retcode==TRADE_RETCODE_INVALID_VOLUME,"native maximum volume rejection");
 q.volume=minimum+step/2;
 Check(!OrderCheck(q,c) && c.retcode==TRADE_RETCODE_INVALID_VOLUME,"native fractional volume-step rejection");
 q.volume=maximum;
 Check(!OrderCheck(q,c) && c.retcode==TRADE_RETCODE_NO_MONEY,"native insufficient margin rejection");
 setup.direction=1;setup.entry=TickRound(t.bid-.001,-1);setup.sl=setup.entry+.001;setup.tp=setup.entry+.003;
 Check(!SubmitLimit() && OrdersTotal()==0,"invalid buy stop rejected before order creation");
 setup.sl=setup.entry-.001;setup.tp=setup.entry-.003;
 Check(!SubmitLimit() && OrdersTotal()==0,"invalid buy target rejected before order creation");
 q=Request(ORDER_TYPE_BUY,minimum,MagicNumber+77);
 bool sent=OrderSend(q,r);Check(sent && r.retcode==TRADE_RETCODE_DONE,"create isolated foreign-magic tester position");
 ulong position=0;
 for(int i=0;i<PositionsTotal();i++) {
  ulong ticket=PositionGetTicket(i);
  if(PositionGetInteger(POSITION_MAGIC)==(long)(MagicNumber+77)) {position=ticket;break;}
 }
 if(position>0) {
  setup.position=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
  Check(!OwnedPosition(position),"foreign-magic position is not owned");
  Check(!EntryAllowed(reason) && reason=="Account exposure capacity","existing tester position blocks new entry");
  q=Request(ORDER_TYPE_SELL,minimum,MagicNumber+77);q.position=position;
  sent=OrderSend(q,r);Check(sent && r.retcode==TRADE_RETCODE_DONE,"close only the position created by this tester check");
 } else Check(false,"foreign test position available");
 q=Request(ORDER_TYPE_BUY_LIMIT,minimum,MagicNumber+77);q.action=TRADE_ACTION_PENDING;
 q.price=TickRound(t.bid-.01,-1);q.type_filling=ORDER_FILLING_RETURN;q.type_time=ORDER_TIME_SPECIFIED;q.expiration=TimeCurrent()+3600;
 sent=OrderSend(q,r);Check(sent && r.retcode==TRADE_RETCODE_DONE,"create isolated foreign-magic tester pending order");
 if(sent && r.order>0) {
  ulong pending=r.order;setup.order=pending;
  Check(!OwnedOrder(pending),"foreign-magic pending order is not owned");
  Check(!EntryAllowed(reason) && reason=="Account exposure capacity","existing tester pending order blocks entry");
  ZeroMemory(q);q.action=TRADE_ACTION_REMOVE;q.order=pending;
  sent=OrderSend(q,r);Check(sent && r.retcode==TRADE_RETCODE_DONE,"cancel only pending order created by this tester check");
 }
 setup.sweep=TimeCurrent()-60;setup.state=SUBMISSION_PENDING;setup.order=0;setup.expires=TimeCurrent()+3600;
 ZeroMemory(q);q.action=TRADE_ACTION_PENDING;q.symbol=_Symbol;q.magic=MagicNumber;q.volume=minimum;
 q.type=ORDER_TYPE_BUY_LIMIT;q.price=TickRound(t.bid-.01,-1);q.sl=q.price-.001;q.tp=q.price+.003;
 q.type_filling=ORDER_FILLING_RETURN;q.type_time=ORDER_TIME_SPECIFIED;q.expiration=TimeCurrent()+3600;
 q.comment="TB:"+IntegerToString((long)setup.sweep)+":B:Recovery";
 sent=OrderSend(q,r);bool recoveryOrderCreated=sent && r.retcode==TRADE_RETCODE_DONE && r.order>0;
 Check(recoveryOrderCreated,"create owned pending order for lost-ticket reconciliation");
 if(recoveryOrderCreated) {
  ulong originalOrder=r.order;setup.order=0;Reconcile();
  Check(setup.order==originalOrder && setup.state==PENDING_ORDER,"reconcile recovers the existing pending order after its ticket is lost");
  Check(OrdersTotal()==1,"lost-ticket reconciliation does not create a duplicate order");
  ZeroMemory(q);q.action=TRADE_ACTION_REMOVE;q.order=originalOrder;q.symbol=_Symbol;q.magic=MagicNumber;
  sent=OrderSend(q,r);Check(sent && r.retcode==TRADE_RETCODE_DONE,"remove pending order created for recovery check");
 }
 setup.order=0;setup.state=WAITING_FOR_SWEEP;
 Check(PositionsTotal()==0 && OrdersTotal()==0,"isolated execution checks leave tester flat");
 // Inject explicit tester-only equity baselines to exercise protection transitions.
 double equity=AccountInfoDouble(ACCOUNT_EQUITY);
 dayEquity=equity*1.05;dailyLocked=false;UpdateStats(true);
 Check(dailyLocked && !RiskUnlocked(),"daily loss lock from injected tester equity baseline");
 dailyLocked=false;dayEquity=equity;dailyDD=0;equityPeak=equity/0.89;overallLocked=false;UpdateStats(true);
 Check(overallLocked && !RiskUnlocked(),"overall drawdown lock from injected tester equity peak");
 dailyLocked=false;overallLocked=false;dailyDD=0;overallDD=0;InitStats();
}
void OnTimer() {
 MqlDateTime d;TimeToStruct(TimeCurrent(),d);
 if(!weekendChecked && (d.day_of_week==0 || d.day_of_week==6)) {
  weekendChecked=true;Check(!MarketSessionOpen(),"market closed on broker weekend schedule");
 }
}
double OnTester() {
 Check(exercised,"native execution scenarios exercised");Check(weekendChecked,"weekend market schedule exercised");
 PrintFormat("QA_RESULT checks=%d failures=%d",checks,failures);return failures==0?checks:-failures;
}
void OnDeinit(const int reason) { EventKillTimer();if(output!=INVALID_HANDLE)FileClose(output);if(objectPrefix!="")ObjectsDeleteAll(0,objectPrefix); }
