ENUM_ORDER_TYPE_FILLING MarketFilling() {
 long flags=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
 if((flags&SYMBOL_FILLING_FOK)!=0) return ORDER_FILLING_FOK;
 if((flags&SYMBOL_FILLING_IOC)!=0) return ORDER_FILLING_IOC;
 return ORDER_FILLING_RETURN;
}
void ManagePositions() {
 static datetime lastModificationAttempt=0;
 if(setup.state!=TRADE_ACTIVE || setup.initialRisk<=0) return;
 for(int i=PositionsTotal()-1;i>=0;i--) {
  ulong ticket=PositionGetTicket(i); if(!OwnedPosition(ticket)) continue;
  MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) continue;
  double entry=PositionGetDouble(POSITION_PRICE_OPEN),oldSL=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP),volume=PositionGetDouble(POSITION_VOLUME);
  double price=setup.direction>0?tick.bid:tick.ask,rr=setup.direction*(price-entry)/setup.initialRisk;
  if(EnablePartialTakeProfit && !setup.partialDone && rr>=PartialTPTriggerRR) {
   double closeVolume=VolumeFloor(volume*PartialClosePercentage/100),minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   // Record intent first: never repeat a partial close after an uncertain result.
   setup.partialDone=true; setup.partialBefore=volume;
   if(!SaveState()) return;
   if(closeVolume>=minimum && VolumeFloor(volume-closeVolume)>=minimum) {
    MqlTradeRequest q={}; MqlTradeResult r={}; q.action=TRADE_ACTION_DEAL; q.symbol=_Symbol; q.position=ticket;
    q.magic=MagicNumber; q.volume=closeVolume; q.type=setup.direction>0?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
    q.price=price; q.deviation=Slippage; q.type_filling=MarketFilling(); q.comment="TB partial";
    ResetLastError(); bool sent=OrderSend(q,r); bool accepted=Accepted(r,"Partial close");
    if(sent && accepted) Mark("partial_"+setup.id,TimeCurrent(),price,clrOrange);
   } else Log("WARNING","Partial close skipped: invalid closed or remaining volume");
  }
  double candidate=oldSL; string why="";
  if(EnableBreakeven && rr>=BreakevenTriggerRR) {
   double be=entry+setup.direction*BreakevenOffsetPoints*_Point;
   if(candidate==0 || setup.direction*(be-candidate)>0) { candidate=be; why="breakeven"; }
  }
  if(EnableTrailingStop && rr>=TrailingStopActivationRR) {
   double trail=price-setup.direction*TrailingStopDistance*_Point;
   if(candidate==0 || setup.direction*(trail-candidate)>0) { candidate=trail; why="trailing"; }
  }
  if(why=="") continue;
  if(TimeCurrent()-lastModificationAttempt<ManagementRetrySeconds) continue;
  candidate=TickRound(candidate,-setup.direction);
  double dist=MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
  if(setup.direction*(candidate-oldSL)<=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)/2 || setup.direction*(price-candidate)<=dist) continue;
  MqlTradeRequest q={}; MqlTradeResult r={}; q.action=TRADE_ACTION_SLTP; q.symbol=_Symbol; q.position=ticket; q.magic=MagicNumber; q.sl=candidate; q.tp=tp;
  lastModificationAttempt=TimeCurrent();
  ResetLastError(); bool sent=OrderSend(q,r); bool accepted=Accepted(r,"SL modification "+why);
  if(sent && accepted) { Line("sl",candidate,clrOrange); Mark(why+"_"+setup.id,TimeCurrent(),candidate,clrOrange); }
 }
}
