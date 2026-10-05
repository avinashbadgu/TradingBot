void ProcessSignals() {
 MqlRates h[],e[]; ArraySetAsSeries(h,true); ArraySetAsSeries(e,true);
 if(CopyRates(_Symbol,HigherTimeframe,0,3,h)!=3 || CopyRates(_Symbol,EntryTimeframe,0,3,e)!=3) return;
 if(lastHTF==0) { lastHTF=h[0].time; lastEntry=e[0].time; FindReferences(h[1].time); SaveState(); return; }
 if(h[0].time!=lastHTF) {
  // Gaps/restarts do not replay intermediate historical setups.
  lastHTF=h[0].time; DetectSweep(h[1],h[0].time); SaveState();
 }
 if(setup.state==WAITING_FOR_ENGULFING && EnableSetupExpiration && MaximumMinutesAfterSweep>0 && TimeCurrent()>=setup.confirmed+MaximumMinutesAfterSweep*60) { setup.state=EXPIRED; Log("INFO","Setup minute expiration"); SaveState(); }
 if(e[0].time==lastEntry) return;
 lastEntry=e[0].time;
 if(setup.state!=WAITING_FOR_ENGULFING || e[1].time<setup.confirmed) { SaveState(); return; }
 setup.bars++;
 if((!RequireBothCandlesAfterSweep || e[2].time>=setup.confirmed) && IsEngulfing(e[1],e[2],setup.direction)) {
  setup.engulf=e[1].time; setup.entry=TickRound((e[1].open+e[1].close)/2,-setup.direction);
  setup.sl=TickRound(setup.direction>0?e[1].low-SLBufferPoints*_Point:e[1].high+SLBufferPoints*_Point,-setup.direction);
  double distance=setup.direction*(setup.entry-setup.sl);
  if(distance<=0) { setup.state=REJECTED; SaveState(); return; }
  setup.tp=TickRound(setup.entry+setup.direction*distance*RiskRewardRatio,setup.direction); setup.initialRisk=distance;
  Log("INFO","Engulfing confirmed"); Mark("engulf_"+setup.id,e[1].time,setup.entry,clrViolet);
  if(!SubmitLimit() && setup.state==WAITING_FOR_ENGULFING) setup.state=REJECTED;
 } else if(EnableSetupExpiration && MaximumBarsAfterSweep>0 && setup.bars>=MaximumBarsAfterSweep) { setup.state=EXPIRED; Log("INFO","Setup bar expiration"); }
 SaveState();
}
