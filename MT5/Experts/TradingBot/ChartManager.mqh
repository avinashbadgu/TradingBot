void Mark(string suffix,datetime time,double price,color c) {
 if(!EnableChartObjects) return;
 string name=objectPrefix+suffix;
 if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,time,price);
 ObjectSetInteger(0,name,OBJPROP_ARROWCODE,159); ObjectSetInteger(0,name,OBJPROP_COLOR,c);
}
void Line(string suffix,double price,color c) {
 if(!EnableChartObjects) return;
 string name=objectPrefix+suffix;
 if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
 ObjectSetDouble(0,name,OBJPROP_PRICE,price); ObjectSetInteger(0,name,OBJPROP_COLOR,c);
}
