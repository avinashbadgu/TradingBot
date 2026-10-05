bool IsFractal(MqlRates &r[],int i,int k,bool high) {
 for(int j=1;j<=k;j++) {
  if(high && (r[i].high<=r[i-j].high || r[i].high<=r[i+j].high)) return false;
  if(!high && (r[i].low>=r[i-j].low || r[i].low>=r[i+j].low)) return false;
 }
 return true;
}
bool FindReferences(datetime sweepOpen) {
 MqlRates r[]; ArraySetAsSeries(r,true);
 int n=CopyRates(_Symbol,HigherTimeframe,0,FractalLookback,r),k=(FractalPeriod-1)/2;
 if(n<FractalPeriod+2) return false;
 bool hi=false,lo=false;
 // i-k is the latest right-side confirmation candle. Its next bar must
 // have opened no later than the sweep candle. No bar 0 participates.
 for(int i=k+2;i<n-k;i++) {
  if(r[i-k-1].time>sweepOpen) continue;
  if(!hi && IsFractal(r,i,k,true)) {
   if(refHighTime!=r[i].time) Log("DEBUG","Fractal high confirmed: "+TimeToString(r[i].time));
   refHigh=r[i].high; refHighTime=r[i].time; hi=true;
   for(int j=i-k-1;j>=2;j--) if(r[j].high>refHigh && (ConsumeLevelOnFirstBreach || r[j].close<refHigh)) { usedHigh=refHighTime; break; }
  }
  if(!lo && IsFractal(r,i,k,false)) {
   if(refLowTime!=r[i].time) Log("DEBUG","Fractal low confirmed: "+TimeToString(r[i].time));
   refLow=r[i].low; refLowTime=r[i].time; lo=true;
   for(int j=i-k-1;j>=2;j--) if(r[j].low<refLow && (ConsumeLevelOnFirstBreach || r[j].close>refLow)) { usedLow=refLowTime; break; }
  }
  if(hi && lo) break;
 }
 if(!hi) { refHigh=0; refHighTime=0; }
 if(!lo) { refLow=0; refLowTime=0; }
 return true;
}
