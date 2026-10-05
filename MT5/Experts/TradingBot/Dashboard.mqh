void DrawDashboard() {
 if(!EnableDashboard) return;
 MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return;
 double rr=setup.initialRisk>0?setup.direction*((setup.direction>0?t.bid:t.ask)-setup.entry)/setup.initialRisk:0;
 Comment(StringFormat("TradingBot | %s | %s\nBalance %.2f | Equity %.2f | Floating %.2f\nRisk %.2f (%.2f%%) | Lots %.4f | Spread %.1f points\nSession %s | Positions %d | Pending %d\nToday trades %d | Realized %.2f | Daily DD %.2f%% | Overall DD %.2f%%\nConsecutive losses %d | Risk baseline %s | Setup %s\nEntry %.*f | SL %.*f | TP %.*f | R %.2f",_Symbol,EnumToString(setup.state),AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY),AccountInfoDouble(ACCOUNT_PROFIT),lastRisk,RiskPercentage,lastLot,(t.ask-t.bid)/_Point,SessionAllowed(TimeCurrent())?"OPEN":"CLOSED",PositionsTotal(),OrdersTotal(),dailyTrades,realized,dailyDD,overallDD,consecutiveLosses,baselineKnown?"KNOWN":"UNAVAILABLE",setup.id,_Digits,setup.entry,_Digits,setup.sl,_Digits,setup.tp,rr));
}
