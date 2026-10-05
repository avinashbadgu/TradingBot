double TickRound(double p,int direction) {
 double t=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
 return NormalizeDouble((direction<0?MathFloor(p/t+1e-9):MathCeil(p/t-1e-9))*t,_Digits);
}
double VolumeFloor(double v) {
 double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
 return step>0?NormalizeDouble(MathFloor(v/step+1e-9)*step,8):0;
}
bool USDConversion(double &rate) {
 string currency=AccountInfoString(ACCOUNT_CURRENCY); rate=1;
 if(currency=="USD") return true;
 for(int i=0;i<SymbolsTotal(false);i++) {
  string s=SymbolName(i,false),base=SymbolInfoString(s,SYMBOL_CURRENCY_BASE),quote=SymbolInfoString(s,SYMBOL_CURRENCY_PROFIT);
  if(!((base=="USD" && quote==currency) || (base==currency && quote=="USD"))) continue;
  if(!SymbolSelect(s,true)) continue;
  MqlTick t; if(!SymbolInfoTick(s,t) || t.bid<=0 || t.ask<=0 || MathAbs((double)(TimeCurrent()-t.time))>120) continue;
  rate=base=="USD"?t.bid:1.0/t.ask; return true;
 }
 return false;
}
bool CalculateVolume(int direction,double entry,double sl,double &volume) {
 double ref=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),loss=0;
 if(ref<=0 || !OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,ref,entry,sl,loss) || loss>=0) { Log("ERROR","Stop monetary value unavailable"); return false; }
 double adverse=sl-direction*AdverseExecutionReservePoints*_Point,stress=0;
 if(!OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,ref,entry,adverse,stress)) return false;
 double perLot=MathAbs(stress)/ref+CommissionReservePerLot,budget=0;
 if(RiskMode==RISK_PERCENT) budget=AccountInfoDouble(ACCOUNT_EQUITY)*RiskPercentage/100;
 if(RiskMode==RISK_USD) { double rate; if(!USDConversion(rate)) { Log("ERROR","USD conversion unavailable"); return false; } budget=RiskAmountUSD*rate; }
 volume=RiskMode==RISK_FIXED_LOT?FixedLotSize:budget/perLot;
 volume=VolumeFloor(MathMin(volume,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)));
 if(volume<ref) { Log("WARNING","Risk budget below minimum volume"); return false; }
 lastRisk=volume*perLot; lastLot=volume;
 if(RiskMode!=RISK_FIXED_LOT && lastRisk>budget+1e-6) return false;
 double reserved=0;
 for(int i=0;i<PositionsTotal();i++) {
  if(PositionGetTicket(i)==0) continue;
  string s=PositionGetString(POSITION_SYMBOL); double stop=PositionGetDouble(POSITION_SL),p=0;
  long kind=PositionGetInteger(POSITION_TYPE); MqlTick quote;
  if(stop<=0 || !SymbolInfoTick(s,quote) || !OrderCalcProfit(kind==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL,s,PositionGetDouble(POSITION_VOLUME),kind==POSITION_TYPE_BUY?quote.bid:quote.ask,stop,p)) { Log("WARNING","Existing exposure risk unknown"); return false; }
  reserved+=MathMax(0,-p)+PositionGetDouble(POSITION_VOLUME)*CommissionReservePerLot;
 }
 for(int i=0;i<OrdersTotal();i++) {
  if(OrderGetTicket(i)==0) continue;
  long kind=OrderGetInteger(ORDER_TYPE); double p=0,stop=OrderGetDouble(ORDER_SL);
  if(kind!=ORDER_TYPE_BUY_LIMIT && kind!=ORDER_TYPE_SELL_LIMIT) { Log("WARNING","Unsupported external pending exposure"); return false; }
  if(stop<=0 || !OrderCalcProfit(kind==ORDER_TYPE_BUY_LIMIT?ORDER_TYPE_BUY:ORDER_TYPE_SELL,OrderGetString(ORDER_SYMBOL),OrderGetDouble(ORDER_VOLUME_CURRENT),OrderGetDouble(ORDER_PRICE_OPEN),stop,p)) return false;
  reserved+=MathMax(0,-p)+OrderGetDouble(ORDER_VOLUME_CURRENT)*CommissionReservePerLot;
 }
 double dailyBudget=dayEquity*MaximumDailyLoss/100-MathMax(0,dayEquity+dayCashflow-AccountInfoDouble(ACCOUNT_EQUITY));
 double totalBudget=equityPeak*MaximumOverallDrawdown/100-(equityPeak-AccountInfoDouble(ACCOUNT_EQUITY));
 if((MaximumDailyLoss>0 && lastRisk+reserved>dailyBudget) || (MaximumOverallDrawdown>0 && lastRisk+reserved>totalBudget)) { Log("WARNING","Trade and reserved risk exceed remaining protection budget"); return false; }
 double margin=0;
 if(!OrderCalcMargin(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,entry,margin) || margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) { Log("WARNING","Insufficient or unknown margin"); return false; }
 return true;
}
bool MarketSessionOpen() {
 MqlDateTime d; TimeToStruct(TimeCurrent(),d); int seconds=d.hour*3600+d.min*60+d.sec;
 for(uint i=0;i<20;i++) {
  datetime a,b; if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)d.day_of_week,i,a,b)) break;
  int from=(int)((long)a%86400),to=(int)((long)b%86400);
  if(from==to || (from<to && seconds>=from && seconds<to) || (from>to && (seconds>=from || seconds<to))) return true;
 }
 return false;
}
bool EntryAllowed(string &reason) {
 if(!RiskUnlocked()) { reason="Risk baseline unavailable or protection locked"; return false; }
 if(dailyTrades>=MaximumDailyTrades) { reason="Daily trade limit"; return false; }
 if(!SessionAllowed(TimeCurrent())) { reason="Outside session or timezone coverage"; return false; }
 if(!MarketSessionOpen()) { reason="Market closed / schedule unavailable"; return false; }
 if(!MQLInfoInteger(MQL_TESTER) && (!MQLInfoInteger(MQL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))) { reason="Trading permission disabled"; return false; }
 MqlTick t; if(!SymbolInfoTick(_Symbol,t) || t.ask<=0 || t.bid<=0 || TimeCurrent()-t.time>30) { reason="Stale quote"; return false; }
 if((t.ask-t.bid)/_Point>MaximumSpreadAllowed) { reason="Spread limit"; return false; }
 // Conservative capacity includes unrelated account exposure, which is never managed.
 if(PositionsTotal()+OrdersTotal()>=MaximumActiveTrades) { reason="Account exposure capacity"; return false; }
 for(int i=0;i<PositionsTotal();i++) if(PositionGetTicket(i)>0 && PositionGetString(POSITION_SYMBOL)==_Symbol) { reason="Existing symbol position"; return false; }
 for(int i=0;i<OrdersTotal();i++) if(OrderGetTicket(i)>0 && OrderGetString(ORDER_SYMBOL)==_Symbol) { reason="Existing symbol order"; return false; }
 return true;
}
