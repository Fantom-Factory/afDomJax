
// FIXME kill me or move me
@Js const class JsUtil {
	
	** Returns a new DateTime in the user's time zone.
	** Note the date is correct, but the TimeZone is not - we just adjust the time.
	static DateTime toLocalTs(DateTime dateTime) {
		dateTime.toUtc.minus(utcOffset)
	}

	static Duration utcOffset() {
		1min * (Env.cur.runtime == "js" ? getTimezoneOffset : (TimeZone.cur.offset(Date.today.year) + TimeZone.cur.dstOffset(Date.today.year)).toMin)
	}

	** Returns the offset in minutes.
	private native static Int getTimezoneOffset()
}
