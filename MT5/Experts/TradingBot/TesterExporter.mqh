string ExportPrefix() { return "TradingBot_"+RunId+"_"+_Symbol; }
void InitExports() {
 if(!ExportResearchData || !MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return;
 eventFile=FileOpen(ExportPrefix()+"_events.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
 equityFile=FileOpen(ExportPrefix()+"_equity.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
 if(eventFile!=INVALID_HANDLE) FileWrite(eventFile,"time","level","setup_id","message");
 if(equityFile!=INVALID_HANDLE) FileWrite(equityFile,"time","balance","equity");
 riskFile=FileOpen(ExportPrefix()+"_risks.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
 if(riskFile!=INVALID_HANDLE) FileWrite(riskFile,"deal_id","position_id","initial_risk_amount","entry","original_sl","volume");
 if(ExportBarData) {
  barFile=FileOpen(ExportPrefix()+"_bars.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
  if(barFile!=INVALID_HANDLE) FileWrite(barFile,"timeframe","time","open","high","low","close","available_at");
 }
}
void ExportEntryRisk(ulong deal) {
 if(riskFile==INVALID_HANDLE || !HistoryDealSelect(deal) || HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN || HistoryDealGetInteger(deal,DEAL_MAGIC)!=(long)MagicNumber) return;
 double entry=HistoryDealGetDouble(deal,DEAL_PRICE),volume=HistoryDealGetDouble(deal,DEAL_VOLUME),loss=0;
 if(setup.sl<=0 || !OrderCalcProfit(setup.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,entry,setup.sl,loss)) return;
 FileWrite(riskFile,(string)deal,(string)HistoryDealGetInteger(deal,DEAL_POSITION_ID),DoubleToString(MathAbs(loss),8),DoubleToString(entry,_Digits),DoubleToString(setup.sl,_Digits),DoubleToString(volume,8)); FileFlush(riskFile);
}
void ExportBars() {
 if(barFile==INVALID_HANDLE) return;
 static datetime lastHigher=0,lastLower=0;
 ENUM_TIMEFRAMES frames[2]; frames[0]=HigherTimeframe; frames[1]=EntryTimeframe;
 for(int i=0;i<2;i++) {
  MqlRates r[]; ArraySetAsSeries(r,true); int need=(i==0 && lastHigher==0)?FractalLookback:3;
  int n=CopyRates(_Symbol,frames[i],0,need,r); if(n<2) continue;
  datetime last=i==0?lastHigher:lastLower;
  for(int j=n-1;j>=1;j--) if(r[j].time>last) FileWrite(barFile,EnumToString(frames[i]),TimeToString(r[j].time,TIME_DATE|TIME_SECONDS),DoubleToString(r[j].open,_Digits),DoubleToString(r[j].high,_Digits),DoubleToString(r[j].low,_Digits),DoubleToString(r[j].close,_Digits),TimeToString(r[j-1].time,TIME_DATE|TIME_SECONDS));
  if(i==0) lastHigher=r[1].time; else lastLower=r[1].time;
 }
}
void ExportEquity() {
 static double previous=-1; static datetime previousTime=0;
 double eq=AccountInfoDouble(ACCOUNT_EQUITY);
 if(equityFile!=INVALID_HANDLE && (eq!=previous || TimeCurrent()-previousTime>=60)) {
  FileWrite(equityFile,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),8),DoubleToString(eq,8));
  previous=eq; previousTime=TimeCurrent();
 }
}
void ExportEnvironment() {
 if(!ExportResearchData || MQLInfoInteger(MQL_OPTIMIZATION)) return;
 int h=FileOpen(ExportPrefix()+"_environment.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,','); if(h==INVALID_HANDLE) return;
 FileWrite(h,"property","value");
 FileWrite(h,"server",AccountInfoString(ACCOUNT_SERVER)); FileWrite(h,"currency",AccountInfoString(ACCOUNT_CURRENCY));
 FileWrite(h,"account_mode",EnumToString((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)));
 FileWrite(h,"symbol",_Symbol); FileWrite(h,"contract_size",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE));
 FileWrite(h,"tick_size",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)); FileWrite(h,"tick_value",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE));
 FileWrite(h,"volume_min",SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)); FileWrite(h,"volume_max",SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
 FileWrite(h,"volume_step",SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)); FileWrite(h,"stops_points",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL));
 FileWrite(h,"freeze_points",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)); FileWrite(h,"chart_mode",SymbolInfoInteger(_Symbol,SYMBOL_CHART_MODE));
 FileWrite(h,"higher_tf",EnumToString(HigherTimeframe)); FileWrite(h,"entry_tf",EnumToString(EntryTimeframe));
 FileWrite(h,"rr",RiskRewardRatio); FileWrite(h,"fractal_period",FractalPeriod); FileWrite(h,"commission_reserve_per_lot",CommissionReservePerLot);
 FileWrite(h,"point",_Point); FileWrite(h,"digits",_Digits);
 FileWrite(h,"swap_mode",SymbolInfoInteger(_Symbol,SYMBOL_SWAP_MODE));
 FileWrite(h,"swap_long",SymbolInfoDouble(_Symbol,SYMBOL_SWAP_LONG)); FileWrite(h,"swap_short",SymbolInfoDouble(_Symbol,SYMBOL_SWAP_SHORT));
 FileWrite(h,"swap_triple_day",SymbolInfoInteger(_Symbol,SYMBOL_SWAP_ROLLOVER3DAYS));
 MqlCommission commissions[]; ResetLastError(); int rules=SymbolInfoCommissions(_Symbol,commissions);
 FileWrite(h,"commission_rule_count",rules); FileWrite(h,"commission_query_error",GetLastError());
 for(int i=0;i<rules;i++) {
  string key="commission_"+IntegerToString(i)+"_";
  FileWrite(h,key+"currency",commissions[i].currency); FileWrite(h,key+"charge_mode",(int)commissions[i].mode_charge);
  FileWrite(h,key+"entry_mode",(int)commissions[i].mode_entry);
  for(int j=0;j<ArraySize(commissions[i].tiers);j++) {
   string tier=key+"tier_"+IntegerToString(j)+"_";
   FileWrite(h,tier+"mode",(int)commissions[i].tiers[j].mode); FileWrite(h,tier+"volume_type",(int)commissions[i].tiers[j].volume_type);
   FileWrite(h,tier+"value",commissions[i].tiers[j].value); FileWrite(h,tier+"minimum",commissions[i].tiers[j].min_value); FileWrite(h,tier+"maximum",commissions[i].tiers[j].max_value);
  }
 }
 ENUM_TIMEFRAMES tf[]={PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_M30,PERIOD_H1,PERIOD_H4,PERIOD_D1};
 for(int i=0;i<ArraySize(tf);i++) {
  MqlRates r[]; int n=CopyRates(_Symbol,tf[i],0,2,r);
  FileWrite(h,EnumToString(tf[i])+"_bars",Bars(_Symbol,tf[i]));
  FileWrite(h,EnumToString(tf[i])+"_first",TimeToString((datetime)SeriesInfoInteger(_Symbol,tf[i],SERIES_FIRSTDATE),TIME_DATE|TIME_MINUTES));
  FileWrite(h,EnumToString(tf[i])+"_synchronized",n==2 && (bool)SeriesInfoInteger(_Symbol,tf[i],SERIES_SYNCHRONIZED));
 }
 for(int d=0;d<7;d++) for(uint i=0;i<20;i++) { datetime a,b; if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)d,i,a,b)) break; FileWrite(h,"session_"+IntegerToString(d)+"_"+(string)i,(string)(long)a+"-"+(string)(long)b); }
 FileClose(h);
}
void ExportDeals() {
 if(!ExportResearchData || MQLInfoInteger(MQL_OPTIMIZATION)) return;
 if(!HistorySelect(0,TimeCurrent())) return;
 int h=FileOpen(ExportPrefix()+"_deals.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,','); if(h==INVALID_HANDLE) return;
 FileWrite(h,"deal_id","order_id","position_id","time","symbol","entry","type","volume","price","profit","commission","swap","fee","magic");
 for(int i=0;i<HistoryDealsTotal();i++) {
  ulong d=HistoryDealGetTicket(i);
  if(HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)MagicNumber) continue;
  FileWrite(h,(string)d,(string)HistoryDealGetInteger(d,DEAL_ORDER),(string)HistoryDealGetInteger(d,DEAL_POSITION_ID),TimeToString((datetime)HistoryDealGetInteger(d,DEAL_TIME),TIME_DATE|TIME_SECONDS),HistoryDealGetString(d,DEAL_SYMBOL),HistoryDealGetInteger(d,DEAL_ENTRY),HistoryDealGetInteger(d,DEAL_TYPE),DoubleToString(HistoryDealGetDouble(d,DEAL_VOLUME),8),DoubleToString(HistoryDealGetDouble(d,DEAL_PRICE),_Digits),DoubleToString(HistoryDealGetDouble(d,DEAL_PROFIT),8),DoubleToString(HistoryDealGetDouble(d,DEAL_COMMISSION),8),DoubleToString(HistoryDealGetDouble(d,DEAL_SWAP),8),DoubleToString(HistoryDealGetDouble(d,DEAL_FEE),8),(string)MagicNumber);
 }
 FileClose(h);
}
double TesterResult() {
 ExportDeals(); ExportEquity();
 if(equityFile!=INVALID_HANDLE) FileFlush(equityFile);
 double n=TesterStatistics(STAT_TRADES),dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR);
 double profit=TesterStatistics(STAT_PROFIT),score=(n<100 || dd>20 || pf<1.1)?-1:profit/MathMax(1,TesterStatistics(STAT_EQUITY_DD));
 if(MQLInfoInteger(MQL_OPTIMIZATION)) {
  double data[10]; data[0]=RiskRewardRatio; data[1]=FractalPeriod; data[2]=n; data[3]=profit; data[4]=pf; data[5]=dd;
  data[6]=TesterStatistics(STAT_SHARPE_RATIO); data[7]=TesterStatistics(STAT_EXPECTED_PAYOFF); data[8]=TesterStatistics(STAT_RECOVERY_FACTOR); data[9]=TesterStatistics(STAT_EQUITY_DD);
  if(!FrameAdd("TradingBot",0,score,data)) Print("TB ERROR optimization frame failed ",GetLastError());
 } else if(ExportResearchData) {
  int h=FileOpen(ExportPrefix()+"_tester_statistics.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
  if(h!=INVALID_HANDLE) {
   FileWrite(h,"total_trades","net_profit","profit_factor","maximum_drawdown_pct","sharpe","expectancy","recovery_factor","maximum_drawdown");
   FileWrite(h,n,profit,pf,dd,TesterStatistics(STAT_SHARPE_RATIO),TesterStatistics(STAT_EXPECTED_PAYOFF),TesterStatistics(STAT_RECOVERY_FACTOR),TesterStatistics(STAT_EQUITY_DD)); FileClose(h);
  }
  if(HistorySelect(0,TimeCurrent())) {
   h=FileOpen(ExportPrefix()+"_orders.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h!=INVALID_HANDLE) {
    FileWrite(h,"order_id","position_id","type","state","setup_time","done_time","expiration","entry","sl","tp","initial_volume","remaining_volume","comment");
    for(int i=0;i<HistoryOrdersTotal();i++) {
     ulong ticket=HistoryOrderGetTicket(i); if(HistoryOrderGetInteger(ticket,ORDER_MAGIC)!=(long)MagicNumber) continue;
     FileWrite(h,(string)ticket,(string)HistoryOrderGetInteger(ticket,ORDER_POSITION_ID),HistoryOrderGetInteger(ticket,ORDER_TYPE),HistoryOrderGetInteger(ticket,ORDER_STATE),TimeToString((datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_SETUP),TIME_DATE|TIME_SECONDS),TimeToString((datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_DONE),TIME_DATE|TIME_SECONDS),TimeToString((datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_EXPIRATION),TIME_DATE|TIME_SECONDS),DoubleToString(HistoryOrderGetDouble(ticket,ORDER_PRICE_OPEN),_Digits),DoubleToString(HistoryOrderGetDouble(ticket,ORDER_SL),_Digits),DoubleToString(HistoryOrderGetDouble(ticket,ORDER_TP),_Digits),HistoryOrderGetDouble(ticket,ORDER_VOLUME_INITIAL),HistoryOrderGetDouble(ticket,ORDER_VOLUME_CURRENT),HistoryOrderGetString(ticket,ORDER_COMMENT));
    }
    FileClose(h);
   }
  }
 }
 return score;
}
int optimizationFile=INVALID_HANDLE;
void StartOptimizationExport() {
 optimizationFile=FileOpen(ExportPrefix()+"_optimization.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
 if(optimizationFile!=INVALID_HANDLE) FileWrite(optimizationFile,"config_id","symbol","rr","fractal_period","total_trades","net_profit","profit_factor","maximum_drawdown_pct","sharpe","expectancy","recovery_factor","maximum_drawdown","criterion");
}
void DrainOptimizationFrames() {
 ulong pass; string name; long id; double score,data[];
 while(FrameNext(pass,name,id,score,data)) {
  if(name!="TradingBot" || ArraySize(data)!=10 || optimizationFile==INVALID_HANDLE) continue;
  FileWrite(optimizationFile,(string)pass,_Symbol,data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7],data[8],data[9],score); FileFlush(optimizationFile);
 }
}
