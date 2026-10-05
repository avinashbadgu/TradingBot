bool ValidateNews() {
 if(!EnableNewsFilter) return true;
 Log("ERROR","News filter unavailable: requires validated calendar provider and historical cache. Initialization blocked; no silent bypass.");
 return false;
}
