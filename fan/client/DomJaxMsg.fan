using afJson

** Non-Const classes not are not allowed const fields - mostly, I believe, because of laziness. 
** See `https://fantom.org/forum/topic/2758`
** todo - write my own serialisation framework.
@Serializable
@Js class DomJaxMsg {
	
	const Bool isOkay
	const Bool isFormErrs
	const Bool isRedirect
	const Bool isErr
	@Transient
		  Obj?	_payloadCache
		  Type? _payloadType
		  Str?  _payload

	@Transient
	Obj? payload {
		get {
			if (_payloadCache == null)
				_payloadCache = Json().withSerializableMode.fromJson(_payload, _payloadType ?: Obj?#)
			return _payloadCache
		}
		set { _payload = Json().withSerializableMode.toJson(it); _payloadType = it?.typeof ?: Obj?# }
	}
	
	new make(|This|? f := null) { f?.call(this) }

	static new makeOkay() {
		DomJaxMsg { it.isOkay = true }
	}

	static new makeFormErrs([Str:Str]? formMsgs, Str? errMsg := null, [Str:Obj?]? payload := null) {
		DomJaxFormErrs {
			it.isFormErrs	= true
			it.formMsgs		= formMsgs	?: emptyMap
			it.errMsg		= errMsg	?: ""
			it.payload		= payload
			if (it.errMsg.isEmpty && it.formMsgs.size == 1)
				it.errMsg	= it.formMsgs.vals.first
			if (it.errMsg.isEmpty)
				it.errMsg	= "Check the details below"
		}
	}

	static new makeRedirect(Uri location, Str? method := null, [Str:Str]? form := null) {
		DomJaxRedirect {
			it.isRedirect	= true
			it.location		= location
			it.method		= method ?: "GET"
			it.form			= form	 ?: emptyMap
		}
	}

	static new makeServerErr(Str code, Str msg, Err? cause := null) {
		DomJaxErr {
			it.isErr		= true
			it.errTitle		= "Server Error"
			it.errCode		= code
			it.errMsg		= msg
			// don't show server side stack traces to the client!
			it.errType		= cause?.typeof?.qname
		}
	}

	static new makeClientErr(Str title, Str msg, Err? cause := null) {
		DomJaxErr {
			it.isErr		= true
			it.errTitle		= title
			it.errCode		= ""
			it.errMsg		= msg
			it.errType		= cause?.typeof?.qname
			it.cause		= cause
		}
	}
	
	[Str:Obj?]? payloadMap() { payload }
	
	@NoDoc	DomJaxFormErrs	toFormErrs()	{ this }
	@NoDoc	DomJaxRedirect	toRedirect()	{ this }
	@NoDoc	DomJaxErr		toErr()			{ this }
	
	private static const Str:Str emptyMap	:= Str:Str[:].toImmutable
	
	override Str toStr() {
		"DomJax Okay"
	}
}


@NoDoc
@Js class DomJaxFormErrs : DomJaxMsg {
	const Str		errMsg
	const Str:Str	formMsgs
	
	new make(|This| f) : super(f) { }

	override Str toStr() {
		"DomJax FormErrs: ${errMsg} ${formMsgs}"
	}
}


@NoDoc
@Js class DomJaxRedirect : DomJaxMsg {
	const Uri 		location
	const Str 		method
	const Str:Str	form
	
	new make(|This| f) : super(f) { }

	override Str toStr() {
		"DomJax Redirect: ${location}"
	}
}


@NoDoc
@Js class DomJaxErr : DomJaxMsg {
	const Str		errTitle
	const Str		errCode
	const Str		errMsg
	const Str?		errType
	@Transient
	const Err?		cause
	
	new make(|This| f) : super(f) { }

	override Str toStr() {
		"DomJax Err: ${errType} - ${errMsg}"
	}
}
