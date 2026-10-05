string StateFile() { return namespaceKey+".state.csv"; }
bool SaveState() {
 if(MQLInfoInteger(MQL_TESTER)) return true;
 int h=FileOpen(StateFile()+".tmp",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
 if(h==INVALID_HANDLE) { persistenceOK=false; Log("ERROR","Cannot persist execution intent"); return false; }
 FileWrite(h,"TB1",(int)setup.state,setup.direction,(long)setup.sweep,(long)setup.confirmed,(long)setup.engulf,(long)setup.expires,
  DoubleToString(setup.entry,16),DoubleToString(setup.sl,16),DoubleToString(setup.tp,16),DoubleToString(setup.volume,8),DoubleToString(setup.initialRisk,16),
  (string)setup.order,(string)setup.position,(int)setup.partialDone,DoubleToString(setup.partialBefore,8),setup.bars,setup.id,
  (long)usedHigh,(long)usedLow,(long)lastHTF,(long)lastEntry);
 FileFlush(h); FileClose(h);
 if(!FileMove(StateFile()+".tmp",0,StateFile(),FILE_REWRITE)) { persistenceOK=false; Log("ERROR","Atomic state replacement failed"); return false; }
 return true;
}
bool LoadState() {
 if(MQLInfoInteger(MQL_TESTER) || !FileIsExist(StateFile())) return false;
 int h=FileOpen(StateFile(),FILE_READ|FILE_CSV|FILE_ANSI,',');
 if(h==INVALID_HANDLE) return false;
 if(FileReadString(h)!="TB1") { FileClose(h); persistenceOK=false; return false; }
 setup.state=(SetupState)StringToInteger(FileReadString(h)); setup.direction=(int)StringToInteger(FileReadString(h));
 setup.sweep=(datetime)StringToInteger(FileReadString(h)); setup.confirmed=(datetime)StringToInteger(FileReadString(h));
 setup.engulf=(datetime)StringToInteger(FileReadString(h)); setup.expires=(datetime)StringToInteger(FileReadString(h));
 setup.entry=StringToDouble(FileReadString(h)); setup.sl=StringToDouble(FileReadString(h)); setup.tp=StringToDouble(FileReadString(h));
 setup.volume=StringToDouble(FileReadString(h)); setup.initialRisk=StringToDouble(FileReadString(h));
 setup.order=(ulong)StringToInteger(FileReadString(h)); setup.position=(ulong)StringToInteger(FileReadString(h));
 setup.partialDone=(bool)StringToInteger(FileReadString(h)); setup.partialBefore=StringToDouble(FileReadString(h));
 setup.bars=(int)StringToInteger(FileReadString(h)); setup.id=FileReadString(h);
 usedHigh=(datetime)StringToInteger(FileReadString(h)); usedLow=(datetime)StringToInteger(FileReadString(h));
 lastHTF=(datetime)StringToInteger(FileReadString(h)); lastEntry=(datetime)StringToInteger(FileReadString(h));
 FileClose(h); return true;
}
