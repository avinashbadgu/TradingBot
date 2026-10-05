bool IsEngulfing(MqlRates &c,MqlRates &p,int direction) {
 if(direction*(c.close-c.open)<=0) return false;
 if(ExcludePreviousDoji && p.open==p.close) return false;
 if(RequirePreviousCandleOppositeColor && direction*(p.close-p.open)>=0) return false;
 double body=MathAbs(c.close-c.open)/_Point;
 if(body<EngulfingMinimumBodyPoints || (EngulfingMaximumBodyPoints>0 && body>EngulfingMaximumBodyPoints)) return false;
 if(StrictEngulfingBoundaries) return MathMin(c.open,c.close)<MathMin(p.open,p.close) && MathMax(c.open,c.close)>MathMax(p.open,p.close);
 return MathMin(c.open,c.close)<=MathMin(p.open,p.close) && MathMax(c.open,c.close)>=MathMax(p.open,p.close);
}
