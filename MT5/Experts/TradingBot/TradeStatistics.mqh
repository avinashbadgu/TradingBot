datetime statsDay=0,statsUpdated=0;
double dayBalance=0,dayEquity=0,equityPeak=0,dayCashflow=0,realized=0,dailyDD=0,overallDD=0;
double baselineCashflow=0;
bool baselineKnown=false,dailyLocked=false,overallLocked=false;
int dailyTrades=0,consecutiveLosses=0;
void RebuildCompletedStatistics() {
 if(!HistorySelect(0,TimeCurrent())) { baselineKnown=false; return; }
 ulong ids[]; double net[],entered[],exited[]; datetime first[],last[];
 for(int i=0;i<HistoryDealsTotal();i++) {
  ulong d=HistoryDealGetTicket(i);
  if(HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)MagicNumber) continue;
  ulong id=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID); if(id==0) continue;
  int index=-1;
  for(int j=0;j<ArraySize(ids);j++) if(ids[j]==id) { index=j; break; }
  if(index<0) {
   index=ArraySize(ids); ArrayResize(ids,index+1); ArrayResize(net,index+1); ArrayResize(entered,index+1); ArrayResize(exited,index+1); ArrayResize(first,index+1); ArrayResize(last,index+1);
   ids[index]=id; net[index]=0; entered[index]=0; exited[index]=0; first[index]=0; last[index]=0;
  }
  net[index]+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
  datetime time=(datetime)HistoryDealGetInteger(d,DEAL_TIME); long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
  if(entry==DEAL_ENTRY_IN) { entered[index]+=HistoryDealGetDouble(d,DEAL_VOLUME); if(first[index]==0) first[index]=time; }
  else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY) { exited[index]+=HistoryDealGetDouble(d,DEAL_VOLUME); last[index]=time; }
 }
 dailyTrades=0; consecutiveLosses=0;
 for(int i=0;i<ArraySize(ids);i++) if(first[i]>=statsDay) dailyTrades++;
 datetime cursor=TimeCurrent()+1; int previousIndex=ArraySize(ids);
 for(int count=0;count<ArraySize(ids);count++) {
  int latest=-1;
  for(int i=0;i<ArraySize(ids);i++) if(entered[i]>0 && MathAbs(entered[i]-exited[i])<1e-8 && last[i]>0 && (last[i]<cursor || (last[i]==cursor && i<previousIndex)) && (latest<0 || last[i]>last[latest] || (last[i]==last[latest] && i>latest))) latest=i;
  if(latest<0 || net[latest]>=0) break;
  consecutiveLosses++; cursor=last[latest]; previousIndex=latest;
 }
}
string StatsKey(string key) { return "TB.account."+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"."+key; }
datetime DayStart(datetime t) { MqlDateTime d; TimeToStruct(t,d); d.hour=0; d.min=0; d.sec=0; return StructToTime(d); }
double CashflowsSince(datetime from) {
 double total=0;
 if(!HistorySelect(from,TimeCurrent())) return 0;
 for(int i=0;i<HistoryDealsTotal();i++) {
  ulong d=HistoryDealGetTicket(i); long type=HistoryDealGetInteger(d,DEAL_TYPE);
  if(type==DEAL_TYPE_BALANCE || type==DEAL_TYPE_CREDIT) total+=HistoryDealGetDouble(d,DEAL_PROFIT);
 }
 return total;
}
void SaveStats() {
 if(MQLInfoInteger(MQL_TESTER)) return;
 GlobalVariableSet(StatsKey("day"),(double)statsDay); GlobalVariableSet(StatsKey("balance"),dayBalance);
 GlobalVariableSet(StatsKey("equity"),dayEquity); GlobalVariableSet(StatsKey("peak"),equityPeak);
 GlobalVariableSet(StatsKey("known"),baselineKnown?1:0); GlobalVariableSet(StatsKey("dailylock"),dailyLocked?1:0);
 GlobalVariableSet(StatsKey("overalllock"),overallLocked?1:0); GlobalVariableSet(StatsKey("seen"),(double)TimeCurrent());
 GlobalVariableSet(StatsKey("dd"),dailyDD); GlobalVariableSet(StatsKey("cash"),dayCashflow);
 GlobalVariableSet(StatsKey("basecash"),baselineCashflow); GlobalVariablesFlush();
}
void InitStats() {
 bool tester=(bool)MQLInfoInteger(MQL_TESTER);
 statsDay=DayStart(TimeCurrent()); dayBalance=AccountInfoDouble(ACCOUNT_BALANCE); dayEquity=AccountInfoDouble(ACCOUNT_EQUITY); equityPeak=dayEquity;
 baselineCashflow=CashflowsSince(statsDay);
 baselineKnown=tester;
 if(!tester && GlobalVariableCheck(StatsKey("day"))) {
  equityPeak=GlobalVariableGet(StatsKey("peak")); overallLocked=GlobalVariableGet(StatsKey("overalllock"))>0;
  if((datetime)GlobalVariableGet(StatsKey("day"))==statsDay) {
   dayBalance=GlobalVariableGet(StatsKey("balance")); dayEquity=GlobalVariableGet(StatsKey("equity"));
   baselineKnown=GlobalVariableGet(StatsKey("known"))>0; dailyLocked=GlobalVariableGet(StatsKey("dailylock"))>0;
   dailyDD=GlobalVariableGet(StatsKey("dd")); dayCashflow=GlobalVariableGet(StatsKey("cash"));
   baselineCashflow=GlobalVariableGet(StatsKey("basecash"));
   // Unobserved equity peaks may exist if positions were held during downtime.
   if(PositionsTotal()>0 && TimeCurrent()-(datetime)GlobalVariableGet(StatsKey("seen"))>60) baselineKnown=false;
  }
 }
 RebuildCompletedStatistics(); SaveStats();
}
void UpdateStats(bool force=false) {
 datetime now=TimeCurrent(),day=DayStart(now);
 double eq=AccountInfoDouble(ACCOUNT_EQUITY);
 if(day!=statsDay) {
  // A baseline is exact when no exposure straddles the boundary, or the
  // terminal observed a tick at the boundary. Otherwise block this day.
  baselineKnown=(PositionsTotal()==0 || now-day<=1);
  statsDay=day; dayBalance=AccountInfoDouble(ACCOUNT_BALANCE); dayEquity=eq; dayCashflow=0;
  baselineCashflow=CashflowsSince(day);
  equityPeak+=baselineCashflow;
  dailyLocked=false; dailyDD=0; statsUpdated=0; RebuildCompletedStatistics(); SaveStats();
 }
 if(force || now-statsUpdated>=5) {
  statsUpdated=now; double oldCash=dayCashflow; dayCashflow=0; realized=0;
  ulong ids[];
  if(!HistorySelect(day,now)) { baselineKnown=false; return; }
  for(int i=0;i<HistoryDealsTotal();i++) {
   ulong d=HistoryDealGetTicket(i); long type=HistoryDealGetInteger(d,DEAL_TYPE);
   if(type==DEAL_TYPE_BALANCE || type==DEAL_TYPE_CREDIT) { dayCashflow+=HistoryDealGetDouble(d,DEAL_PROFIT); continue; }
   realized+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
   if(HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)MagicNumber || HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
   ulong id=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID); bool seen=false;
   for(int j=0;j<ArraySize(ids);j++) if(ids[j]==id) seen=true;
   if(!seen) { int n=ArraySize(ids); ArrayResize(ids,n+1); ids[n]=id; }
  }
  dayCashflow-=baselineCashflow;
  equityPeak+=dayCashflow-oldCash;
  if(force) RebuildCompletedStatistics();
 }
 equityPeak=MathMax(equityPeak,eq);
 double loss=dayEquity>0?100*MathMax(0,dayEquity+dayCashflow-eq)/dayEquity:100;
 dailyDD=MathMax(dailyDD,loss); overallDD=equityPeak>0?100*(equityPeak-eq)/equityPeak:100;
 if(MaximumDailyLoss>0 && loss>=MaximumDailyLoss && !dailyLocked) { dailyLocked=true; Log("WARNING","Daily loss lockout"); SaveStats(); }
 if(MaximumOverallDrawdown>0 && overallDD>=MaximumOverallDrawdown && !overallLocked) { overallLocked=true; Log("WARNING","Overall drawdown lockout"); SaveStats(); }
}
bool RiskUnlocked() { return baselineKnown && !dailyLocked && !overallLocked && persistenceOK; }
