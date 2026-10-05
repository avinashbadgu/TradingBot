bool OwnedOrder(ulong ticket) { return OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==(long)MagicNumber && ticket==setup.order; }
bool OwnedPosition(ulong ticket) { return PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==(long)MagicNumber && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==setup.position; }
void CancelOrder(string why) {
 static datetime lastCancelAttempt=0;
 if(!OwnedOrder(setup.order)) return;
 if(TimeCurrent()-lastCancelAttempt<ManagementRetrySeconds) return;
 lastCancelAttempt=TimeCurrent();
 MqlTradeRequest q={}; MqlTradeResult r={}; q.action=TRADE_ACTION_REMOVE; q.order=setup.order; q.symbol=_Symbol; q.magic=MagicNumber;
 ResetLastError(); bool sent=OrderSend(q,r); Accepted(r,"Cancel "+why);
 if(!sent) Log("ERROR","Cancellation transport failure");
}
bool SubmitLimit() {
 string reason;
 UpdateStats(true);
 if(!EntryAllowed(reason)) { Log("WARNING","Entry rejected: "+reason); return false; }
 long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
 if(mode==SYMBOL_TRADE_MODE_DISABLED || mode==SYMBOL_TRADE_MODE_CLOSEONLY || (setup.direction>0 && mode==SYMBOL_TRADE_MODE_SHORTONLY) || (setup.direction<0 && mode==SYMBOL_TRADE_MODE_LONGONLY)) { Log("WARNING","Symbol direction disabled"); return false; }
 long flags=SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
 if((flags&SYMBOL_ORDER_LIMIT)==0 || (flags&SYMBOL_ORDER_SL)==0 || (flags&SYMBOL_ORDER_TP)==0) { Log("ERROR","Required order type unsupported"); return false; }
 MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return false;
 double minDistance=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
 if(setup.direction>0 && (setup.entry>=t.ask || t.ask-setup.entry<minDistance || setup.entry-setup.sl<minDistance || setup.tp-setup.entry<minDistance)) { Log("WARNING","Buy limit / stops invalid at submission"); return false; }
 if(setup.direction<0 && (setup.entry<=t.bid || setup.entry-t.bid<minDistance || setup.sl-setup.entry<minDistance || setup.entry-setup.tp<minDistance)) { Log("WARNING","Sell limit / stops invalid at submission"); return false; }
 if(!CalculateVolume(setup.direction,setup.entry,setup.sl,setup.volume)) return false;
 double limit=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
 if(limit>0 && setup.volume>limit) { Log("WARNING","Symbol volume limit"); return false; }
 int lifetime=HardPendingLifetimeMinutes;
 if(EnablePendingOrderExpiration) lifetime=MathMin(lifetime,PendingOrderExpirationMinutes);
 setup.expires=TimeCurrent()+lifetime*60;
 MqlTradeRequest q={}; MqlTradeResult r={}; MqlTradeCheckResult check={};
 q.action=TRADE_ACTION_PENDING; q.symbol=_Symbol; q.magic=MagicNumber; q.volume=setup.volume;
 q.type=setup.direction>0?ORDER_TYPE_BUY_LIMIT:ORDER_TYPE_SELL_LIMIT;
 q.price=setup.entry; q.sl=setup.sl; q.tp=setup.tp; q.deviation=Slippage; q.type_filling=ORDER_FILLING_RETURN;
 long expiry=SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
 if((expiry&SYMBOL_EXPIRATION_SPECIFIED)!=0) { q.type_time=ORDER_TIME_SPECIFIED; q.expiration=setup.expires; }
 else if(RequireServerExpiration) { Log("ERROR","Broker does not support specified server expiration"); return false; }
 else if((expiry&SYMBOL_EXPIRATION_GTC)!=0) q.type_time=ORDER_TIME_GTC;
 else { Log("ERROR","No supported expiration mode"); return false; }
 q.comment=StringSubstr("TB:"+IntegerToString((long)setup.sweep)+":"+(setup.direction>0?"B":"S")+":"+TradeComment,0,31);
 if(!OrderCheck(q,check)) { Log("ERROR",StringFormat("OrderCheck %u %s error=%d",check.retcode,check.comment,GetLastError())); return false; }
 setup.state=SUBMISSION_PENDING;
 if(!SaveState()) { setup.state=RECONCILING; return false; }
 ResetLastError(); bool sent=OrderSend(q,r); bool accepted=Accepted(r,"Place limit");
 if(!sent || !accepted) {
  // A timeout/connection error is not proof that nothing reached the server.
  if(r.retcode==TRADE_RETCODE_TIMEOUT || r.retcode==TRADE_RETCODE_CONNECTION || r.retcode==0) setup.state=RECONCILING;
  else setup.state=REJECTED;
  SaveState(); return false;
 }
 setup.order=r.order; setup.state=r.order>0?PENDING_ORDER:RECONCILING; SaveState();
 Line("entry",setup.entry,clrDodgerBlue); Line("sl",setup.sl,clrRed); Line("tp",setup.tp,clrGreen);
 Mark("pending_"+setup.id,TimeCurrent(),setup.entry,clrDodgerBlue); Notify("TradingBot pending "+_Symbol);
 return true;
}
void Reconcile() {
 if(setup.state==SUBMISSION_PENDING || setup.state==RECONCILING) {
  // Discover an accepted pending request after interruption by its exact intent.
  for(int i=0;i<OrdersTotal();i++) {
   ulong t=OrderGetTicket(i);
   if(OrderGetInteger(ORDER_MAGIC)==(long)MagicNumber && OrderGetString(ORDER_SYMBOL)==_Symbol && StringFind(OrderGetString(ORDER_COMMENT),"TB:"+IntegerToString((long)setup.sweep)+":")==0) {
    setup.order=t; setup.state=PENDING_ORDER; SaveState(); break;
   }
  }
 }
 if(setup.order>0 && OrderSelect(setup.order)) {
  ulong id=(ulong)OrderGetInteger(ORDER_POSITION_ID);
  if(id>0) setup.position=id;
 }
 if(setup.order>0 && HistoryOrderSelect(setup.order)) {
  ulong id=(ulong)HistoryOrderGetInteger(setup.order,ORDER_POSITION_ID);
  if(id>0) setup.position=id;
 }
 bool active=false;
 for(int i=0;i<PositionsTotal();i++) {
  ulong t=PositionGetTicket(i);
  if(!OwnedPosition(t)) continue;
  active=true;
  setup.entry=PositionGetDouble(POSITION_PRICE_OPEN); setup.initialRisk=MathAbs(setup.entry-setup.sl);
  if(setup.state!=TRADE_ACTIVE) {
   setup.state=TRADE_ACTIVE; Log("INFO","Order fill reconciled"); Mark("fill_"+setup.id,TimeCurrent(),setup.entry,clrLime); SaveState();
  }
 }
 bool pending=OwnedOrder(setup.order);
 if(pending && (TimeCurrent()>=setup.expires || !RiskUnlocked() || (CancelPendingOutsideSession && !SessionAllowed(TimeCurrent())))) CancelOrder("expiry / risk / session");
 if(!active && !pending && (setup.state==TRADE_ACTIVE || setup.state==PENDING_ORDER)) { setup.state=COMPLETED; Log("INFO","Setup completed or pending expired"); SaveState(); }
}
