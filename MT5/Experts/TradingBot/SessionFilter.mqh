int ParseMinute(string s) {
 if(StringLen(s)!=5 || StringSubstr(s,2,1)!=":") return -1;
 for(int i=0;i<5;i++) if(i!=2 && (StringGetCharacter(s,i)<'0' || StringGetCharacter(s,i)>'9')) return -1;
 int h=(int)StringToInteger(StringSubstr(s,0,2)),m=(int)StringToInteger(StringSubstr(s,3,2));
 return (h<24 && m<60)?h*60+m:-1;
}
bool InWindow(int m,int start,int end) { return start<end?(m>=start && m<end):(m>=start || m<end); }
datetime offsetsFrom[],offsetsUntil[]; int offsetsMinutes[];
bool ParseOffsetMinutes(string value,int &minutes) {
 StringTrimLeft(value);StringTrimRight(value);
 int n=StringLen(value),start=0;
 if(n==0) return false;
 if(StringGetCharacter(value,0)=='+' || StringGetCharacter(value,0)=='-') start=1;
 if(start==n || n-start>4) return false;
 for(int i=start;i<n;i++) if(StringGetCharacter(value,i)<'0' || StringGetCharacter(value,i)>'9') return false;
 minutes=(int)StringToInteger(value);return MathAbs(minutes)<=840;
}
bool LoadOffsets() {
 if(SessionTimeMode==BROKER_TIME || (!EnableLondonSession && !EnableNewYorkSession)) return true;
 int h=FileOpen(BrokerUTCOffsetFile,FILE_READ|FILE_CSV|FILE_ANSI,',');
 if(h==INVALID_HANDLE) { Log("ERROR","Missing historical broker offset file"); return false; }
 while(!FileIsEnding(h)) {
  string a=FileReadString(h),b=FileReadString(h),offset=FileReadString(h);int m=0;
  if(a=="server_from") continue;
  datetime from=StringToTime(a),until=StringToTime(b); int n=ArraySize(offsetsFrom);
  if(!ParseOffsetMinutes(offset,m) || from<=0 || until<=from || TimeToString(from,TIME_DATE|TIME_SECONDS)!=a || TimeToString(until,TIME_DATE|TIME_SECONDS)!=b || (n>0 && from<offsetsUntil[n-1])) { FileClose(h); return false; }
  ArrayResize(offsetsFrom,n+1); ArrayResize(offsetsUntil,n+1); ArrayResize(offsetsMinutes,n+1);
  offsetsFrom[n]=from; offsetsUntil[n]=until; offsetsMinutes[n]=m;
 }
 FileClose(h); return ArraySize(offsetsFrom)>0;
}
bool SessionAllowed(datetime server) {
 if(!EnableLondonSession && !EnableNewYorkSession) return true;
 datetime t=server;
 if(SessionTimeMode!=BROKER_TIME) {
  bool found=false;
  for(int i=0;i<ArraySize(offsetsFrom);i++) if(server>=offsetsFrom[i] && server<offsetsUntil[i]) { t=server-offsetsMinutes[i]*60; found=true; break; }
  if(!found) return false;
  if(SessionTimeMode==CONFIGURED_TIME) t+=ConfiguredUTCOffsetMinutes*60;
 }
 MqlDateTime d; TimeToStruct(t,d); int m=d.hour*60+d.min;
 return (EnableLondonSession && InWindow(m,ParseMinute(LondonSessionStart),ParseMinute(LondonSessionEnd))) || (EnableNewYorkSession && InWindow(m,ParseMinute(NewYorkSessionStart),ParseMinute(NewYorkSessionEnd)));
}
