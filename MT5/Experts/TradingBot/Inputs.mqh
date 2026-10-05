#ifndef TB_INPUTS
#define TB_INPUTS
enum RiskChoice { RISK_FIXED_LOT=0, RISK_USD=1, RISK_PERCENT=2 };
enum ExecutionChoice { TESTER_ONLY=0, DEMO_ONLY=1 };
enum ClockChoice { BROKER_TIME=0, UTC_TIME=1, CONFIGURED_TIME=2 };
input group "Safety and execution"
input ExecutionChoice ExecutionMode=TESTER_ONLY;
input ulong MagicNumber=26092801;
input string TradeComment="TradingBot";
input int Slippage=10;
input double MaximumSpreadAllowed=30;
input bool RequireServerExpiration=true;
input bool CancelPendingOutsideSession=true;
input group "Strategy"
input ENUM_TIMEFRAMES HigherTimeframe=PERIOD_H1;
input ENUM_TIMEFRAMES EntryTimeframe=PERIOD_M5;
input int FractalPeriod=5;
input int FractalLookback=500;
input bool ConsumeLevelOnFirstBreach=true;
input bool RequireBothCandlesAfterSweep=false;
input bool StrictEngulfingBoundaries=false;
input bool RequirePreviousCandleOppositeColor=true;
input bool ExcludePreviousDoji=true;
input double EngulfingMinimumBodyPoints=0;
input double EngulfingMaximumBodyPoints=0;
input double SweepMinimumPenetrationPoints=0;
input double SweepMinimumReclaimPoints=0;
input double SLBufferPoints=10;
input double RiskRewardRatio=3;
input bool EnableBuyTrades=true;
input bool EnableSellTrades=true;
input bool EnableSetupExpiration=true;
input int MaximumBarsAfterSweep=12;
input int MaximumMinutesAfterSweep=60;
input group "Risk (loss and drawdown limits in percent)"
input RiskChoice RiskMode=RISK_PERCENT;
input bool UseFixedLot=false;
input double FixedLotSize=0.01;
input double RiskAmountUSD=25;
input double RiskPercentage=0.25;
input double CommissionReservePerLot=10;
input double AdverseExecutionReservePoints=10;
input int MaximumActiveTrades=1;
input int MaximumTradesPerSymbol=1;
input int MaximumDailyTrades=3;
input double MaximumDailyLoss=2;
input double MaximumOverallDrawdown=10;
input group "Sessions (HH:MM, start inclusive/end exclusive)"
input bool EnableLondonSession=false;
input string LondonSessionStart="08:00";
input string LondonSessionEnd="17:00";
input bool EnableNewYorkSession=false;
input string NewYorkSessionStart="13:00";
input string NewYorkSessionEnd="22:00";
input ClockChoice SessionTimeMode=BROKER_TIME;
input string BrokerUTCOffsetFile="broker_offsets.csv";
input int ConfiguredUTCOffsetMinutes=0;
input group "Pending orders"
input bool EnablePendingOrderExpiration=true;
input int PendingOrderExpirationMinutes=60;
input int HardPendingLifetimeMinutes=1440;
input group "Position management"
input bool EnableBreakeven=false;
input double BreakevenTriggerRR=1;
input double BreakevenOffsetPoints=0;
input bool EnablePartialTakeProfit=false;
input double PartialClosePercentage=50;
input double PartialTPTriggerRR=1.5;
input bool EnableTrailingStop=false;
input double TrailingStopDistance=100;
input double TrailingStopActivationRR=2;
input int ManagementRetrySeconds=5;
input group "News (unsupported until a validated calendar provider is installed)"
input bool EnableNewsFilter=false;
input bool HighImpactOnly=true;
input int NewsMinutesBefore=30;
input int NewsMinutesAfter=30;
input group "Display and exports"
input bool EnableDashboard=true;
input bool EnableChartObjects=true;
input bool CleanupChartObjects=true;
input bool EnableNotifications=false;
input bool EnablePushNotifications=false;
input bool EnableEmailAlerts=false;
input bool EnableDebugLogs=false;
input bool ExportResearchData=true;
input string RunId="baseline";
input bool ExportBarData=true;
enum SetupState { WAITING_FOR_SWEEP=0, WAITING_FOR_ENGULFING=1, SUBMISSION_PENDING=2, PENDING_ORDER=3, TRADE_ACTIVE=4, COMPLETED=5, EXPIRED=6, REJECTED=7, RECONCILING=8 };
struct Setup {
 SetupState state; int direction; datetime sweep,confirmed,engulf,expires;
 double entry,sl,tp,volume,initialRisk; ulong order,position;
 bool partialDone; double partialBefore; int bars; string id;
};
Setup setup;
double refHigh=0,refLow=0,lastLot=0,lastRisk=0;
datetime refHighTime=0,refLowTime=0,usedHigh=0,usedLow=0,lastHTF=0,lastEntry=0;
string namespaceKey,objectPrefix,instanceLock;
bool persistenceOK=true,instanceOwned=false;
int eventFile=INVALID_HANDLE,equityFile=INVALID_HANDLE;
int riskFile=INVALID_HANDLE,barFile=INVALID_HANDLE;
#endif
