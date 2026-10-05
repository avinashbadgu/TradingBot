void Log(string level,string message) {
 if(level=="DEBUG" && !EnableDebugLogs) return;
 Print("TB|",level,"|",_Symbol,"|",setup.id,"|",message);
 if(eventFile!=INVALID_HANDLE) { FileWrite(eventFile,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),level,setup.id,message); FileFlush(eventFile); }
}
void Notify(string message) {
 if(MQLInfoInteger(MQL_TESTER)) return;
 if(EnableNotifications) Alert(message);
 if(EnablePushNotifications && !SendNotification(message)) Log("ERROR","Push failed "+IntegerToString(GetLastError()));
 if(EnableEmailAlerts && !SendMail("TradingBot",message)) Log("ERROR","Email failed "+IntegerToString(GetLastError()));
}
bool Accepted(MqlTradeResult &r,string operation) {
 bool ok=(r.retcode==TRADE_RETCODE_DONE || r.retcode==TRADE_RETCODE_PLACED || r.retcode==TRADE_RETCODE_DONE_PARTIAL);
 Log(ok?"INFO":"ERROR",StringFormat("%s retcode=%u order=%I64u deal=%I64u comment=%s lastError=%d",operation,r.retcode,r.order,r.deal,r.comment,GetLastError()));
 return ok;
}
