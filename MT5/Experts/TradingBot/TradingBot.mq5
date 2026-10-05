#property strict
#property version "1.00"
#property description "Confirmed fractal sweep / engulfing research EA. Real-account execution prohibited."
#include "Inputs.mqh"
#include "Logger.mqh"
#include "Persistence.mqh"
#include "FractalDetector.mqh"
#include "EngulfingDetector.mqh"
#include "SessionFilter.mqh"
#include "NewsFilter.mqh"
#include "ChartManager.mqh"
#include "TradeStatistics.mqh"
#include "RiskManager.mqh"
#include "OrderManager.mqh"
#include "PositionManager.mqh"
#include "SweepDetector.mqh"
#include "StrategyEngine.mqh"
#include "Dashboard.mqh"
#include "TesterExporter.mqh"
int accountLockHandle=INVALID_HANDLE;
bool ValidateInputs() {
 if(PeriodSeconds(EntryTimeframe)<=0 || PeriodSeconds(HigherTimeframe)<=PeriodSeconds(EntryTimeframe) || PeriodSeconds(HigherTimeframe)%PeriodSeconds(EntryTimeframe)!=0) return false;
 if(FractalPeriod<3 || FractalPeriod%2==0 || FractalLookback<FractalPeriod+3 || RiskRewardRatio<=0 || SLBufferPoints<0) return false;
 if(UseFixedLot!=(RiskMode==RISK_FIXED_LOT) || FixedLotSize<=0 || RiskAmountUSD<=0 || RiskPercentage<=0 || RiskPercentage>100) return false;
 if(MaximumActiveTrades<1 || MaximumTradesPerSymbol!=1 || MaximumDailyTrades<1 || MaximumDailyLoss<0 || MaximumOverallDrawdown<0) return false;
 if(MaximumSpreadAllowed<=0 || Slippage<0 || CommissionReservePerLot<0 || AdverseExecutionReservePoints<0) return false;
 if(EngulfingMinimumBodyPoints<0 || EngulfingMaximumBodyPoints<0 || (EngulfingMaximumBodyPoints>0 && EngulfingMaximumBodyPoints<EngulfingMinimumBodyPoints)) return false;
 if(SweepMinimumPenetrationPoints<0 || SweepMinimumReclaimPoints<0 || MaximumMinutesAfterSweep<0 || MaximumBarsAfterSweep<0) return false;
 if(EnableSetupExpiration && MaximumBarsAfterSweep==0 && MaximumMinutesAfterSweep==0) return false;
 if(HardPendingLifetimeMinutes<1 || (EnablePendingOrderExpiration && PendingOrderExpirationMinutes<1)) return false;
 if(ManagementRetrySeconds<1) return false;
 if(BreakevenTriggerRR<=0 || BreakevenOffsetPoints<0 || PartialTPTriggerRR<=0 || PartialClosePercentage<=0 || PartialClosePercentage>=100 || TrailingStopDistance<=0 || TrailingStopActivationRR<=0) return false;
 if(ParseMinute(LondonSessionStart)<0 || ParseMinute(LondonSessionEnd)<0 || ParseMinute(NewYorkSessionStart)<0 || ParseMinute(NewYorkSessionEnd)<0) return false;
 if(LondonSessionStart==LondonSessionEnd || NewYorkSessionStart==NewYorkSessionEnd) return false;
 if(StringFind(RunId,"/")>=0 || StringFind(RunId,"\\")>=0 || StringFind(RunId,":")>=0) return false;
 return SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)>0 && SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)>0;
}
int OnInit() {
 bool tester=(bool)MQLInfoInteger(MQL_TESTER);
 if(!tester && (ExecutionMode!=DEMO_ONLY || AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)) { Print("TB ERROR: execution allowed only in tester or explicitly selected demo mode. Real accounts blocked."); return INIT_FAILED; }
 namespaceKey="TB1_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+(string)MagicNumber+"_"+_Symbol;
 objectPrefix="TB_"+(string)MagicNumber+"_";
 if(!tester) {
  // One coordinator per account in this terminal prevents risk snapshot races.
  // Independent symbols can be researched in isolated Strategy Tester runs.
  accountLockHandle=FileOpen("TB_account_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+".lock",FILE_READ|FILE_WRITE|FILE_BIN);
  if(accountLockHandle==INVALID_HANDLE) { Log("ERROR","Another TradingBot instance owns this account coordinator"); return INIT_FAILED; }
 }
 InitExports();
 if(!ValidateInputs()) { Log("ERROR","Invalid inputs: inspect documented bounds / fixed-lot consistency / one trade per symbol"); return INIT_PARAMETERS_INCORRECT; }
 if(!ValidateNews() || !LoadOffsets()) return INIT_PARAMETERS_INCORRECT;
 if(!LoadState()) { ZeroMemory(setup); setup.state=WAITING_FOR_SWEEP; }
 else {
  if(setup.state==WAITING_FOR_ENGULFING) setup.state=EXPIRED;
  // Never replay signals accumulated while offline.
  lastHTF=0; lastEntry=0;
 }
 InitStats(); ExportEnvironment(); Reconcile(); ExportEquity();
 for(int i=0;i<PositionsTotal();i++) { ulong t=PositionGetTicket(i); if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==(long)MagicNumber && !OwnedPosition(t)) { persistenceOK=false; Log("ERROR","Unreconciled existing position: no adoption"); } }
 for(int i=0;i<OrdersTotal();i++) { ulong t=OrderGetTicket(i); if(OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==(long)MagicNumber && !OwnedOrder(t)) { persistenceOK=false; Log("ERROR","Unreconciled existing pending order: no adoption"); } }
 if(!tester || MQLInfoInteger(MQL_VISUAL_MODE)) EventSetTimer(1);
 Log("INFO","Initialized: real execution blocked; native MQL5 execution"); return INIT_SUCCEEDED;
}
void OnTick() { UpdateStats(); Reconcile(); ManagePositions(); ProcessSignals(); ExportEquity(); ExportBars(); }
void OnTimer() { UpdateStats(); Reconcile(); DrawDashboard(); if(!MQLInfoInteger(MQL_TESTER)) SaveStats(); }
void OnTradeTransaction(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,const MqlTradeResult &result) {
 if(transaction.type==TRADE_TRANSACTION_DEAL_ADD) {
  Log("INFO","Deal transaction "+(string)transaction.deal);
  if(transaction.order==setup.order && HistoryDealSelect(transaction.deal)) setup.position=(ulong)HistoryDealGetInteger(transaction.deal,DEAL_POSITION_ID);
  ExportEntryRisk(transaction.deal); UpdateStats(true); ExportEquity();
 }
 Reconcile(); SaveState();
}
double OnTester() { return TesterResult(); }
void OnTesterInit() { StartOptimizationExport(); }
void OnTesterPass() { DrainOptimizationFrames(); }
void OnTesterDeinit() { DrainOptimizationFrames(); if(optimizationFile!=INVALID_HANDLE) FileClose(optimizationFile); }
void OnDeinit(const int reason) {
 EventKillTimer();
 if(reason!=REASON_INITFAILED) { SaveState(); SaveStats(); }
 if(eventFile!=INVALID_HANDLE) FileClose(eventFile);
 if(equityFile!=INVALID_HANDLE) FileClose(equityFile);
 if(riskFile!=INVALID_HANDLE) FileClose(riskFile);
 if(barFile!=INVALID_HANDLE) FileClose(barFile);
 if(accountLockHandle!=INVALID_HANDLE) FileClose(accountLockHandle);
 if(CleanupChartObjects && objectPrefix!="") ObjectsDeleteAll(0,objectPrefix);
 if(EnableDashboard && objectPrefix!="") Comment("");
}
