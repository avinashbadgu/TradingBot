void DetectSweep(MqlRates &bar,datetime confirmed) {
 if(!FindReferences(bar.time)) return;
 if(refHighTime>0) Mark("fh_"+IntegerToString(refHighTime),refHighTime,refHigh,clrTomato);
 if(refLowTime>0) Mark("fl_"+IntegerToString(refLowTime),refLowTime,refLow,clrAqua);
 bool lowBreach=refLow>0 && usedLow!=refLowTime && bar.low<refLow;
 bool highBreach=refHigh>0 && usedHigh!=refHighTime && bar.high>refHigh;
 bool buy=lowBreach && bar.close>refLow && refLow-bar.low>=SweepMinimumPenetrationPoints*_Point && bar.close-refLow>=SweepMinimumReclaimPoints*_Point;
 bool sell=highBreach && bar.close<refHigh && bar.high-refHigh>=SweepMinimumPenetrationPoints*_Point && refHigh-bar.close>=SweepMinimumReclaimPoints*_Point;
 if(lowBreach && (ConsumeLevelOnFirstBreach || buy)) usedLow=refLowTime;
 if(highBreach && (ConsumeLevelOnFirstBreach || sell)) usedHigh=refHighTime;
 bool busy=setup.state==WAITING_FOR_ENGULFING || setup.state==SUBMISSION_PENDING || setup.state==PENDING_ORDER || setup.state==TRADE_ACTIVE || setup.state==RECONCILING;
 if(busy || (buy && sell)) { if(buy && sell) Log("INFO","Dual sweep skipped"); return; }
 if((buy && EnableBuyTrades) || (sell && EnableSellTrades)) {
  ZeroMemory(setup); setup.state=WAITING_FOR_ENGULFING; setup.direction=buy?1:-1; setup.sweep=bar.time; setup.confirmed=confirmed;
  setup.id=StringFormat("v1_%s_%d_%d_%d_%I64d_%I64d",_Symbol,(int)HigherTimeframe,(int)EntryTimeframe,setup.direction,(long)(buy?refLowTime:refHighTime),(long)bar.time);
  Log("INFO","Sweep confirmed; setup created"); Mark("sweep_"+setup.id,bar.time,buy?bar.low:bar.high,clrGold); SaveState();
 }
}
