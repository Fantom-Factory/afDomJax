
fan.afMarsApp.JsUtilPeer = fan.sys.Obj.$extend(fan.sys.Obj);

fan.afMarsApp.JsUtilPeer.prototype.$ctor = function(self) {}

// this method does work, it's just that the offset solution seems easier!
//fan.afMarsApp.JsUtil.toLocalDateTime = function(date) {
//	var utc		= date.toUtc();	
//	var local	= new Date(Date.UTC(utc.year(), utc.month().ordinal(), utc.day(), utc.hour(), utc.min(), utc.sec()));
//	return fan.sys.DateTime.make(local.getFullYear(), fan.sys.Month.m_vals.get(local.getMonth()), local.getDate(), local.getHours(), local.getMinutes(), local.getSeconds());
//}

fan.afMarsApp.JsUtilPeer.getTimezoneOffset = function() {
	return new Date().getTimezoneOffset();
}
