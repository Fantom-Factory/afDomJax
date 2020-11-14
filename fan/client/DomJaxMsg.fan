
@Serializable
@Js class DomJaxMsg {
		const	Bool	isOkay
		const	Bool	isFormErrs
		const	Bool	isRedirect
		const	Bool	isErr
		[Str:Obj?]?		payload
	
	new make(|This|? f := null) { f?.call(this) }

	static new makeOkay([Str:Obj?]? payload := null) {
		DomJaxMsg { it.isOkay = true; it.payload = payload }
	}

	static new makeFormErrs([Str:Str]? formMsgs, Str? errMsg := null, [Str:Obj?]? payload := null) {
		DomJaxFormErrs {
			it.isFormErrs	= true
			it.formMsgs		= formMsgs	?: emptyMap
			it.errMsg		= errMsg
			it.payload		= payload
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

	static new makeServerErr(Str code, Str msg, Err? cause := null, Str? detail := null) {
		DomJaxErr {
			it.isErr		= true
			it.errTitle		= "Server Error"
			it.errCode		= code
			it.errMsg		= msg
			// don't show server side stack traces to the client!
			it.errType		= cause?.typeof?.qname
			it.errDetail	= detail
			it.isServerErr	= true
		}
	}

	static new makeHttpErr(Int code, Uri url) {
		DomJaxErr {
			it.isErr		= true
			it.errTitle		= "HTTP Error: ${code}"
			it.errCode		= code.toStr
			it.errMsg		= "When contacting: ${url}"
			it.isHttpErr	= true
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
			it.isClientErr	= true
		}
	}
	
	DomJaxFormErrs	toFormErrs()	{ this }
	DomJaxRedirect	toRedirect()	{ this }
	DomJaxErr		toErr()			{ this }
	
	@Operator
	Obj? get(Str key, Obj? def := null) {
		payload == null ? def : payload.get(key, def)
	}
	
	private static const Str:Str emptyMap	:= Str:Str[:].toImmutable
	
	override Str toStr() {
		"DomJax Okay"
	}
}


@Js class DomJaxFormErrs : DomJaxMsg {
	const Str?		errMsg
	const Str:Str	formMsgs
	
	new make(|This| f) : super(f) { }

	** Returns a non-null error msg to display in forms.
	Str formErr() {
		// this should be client logic, but it exists to ease backwards compatibility with a non-null errMsg...
		errMsg := this.errMsg ?: ""
		if (errMsg.isEmpty && formMsgs.size == 1)
			errMsg	= formMsgs.vals.first
		if (errMsg.isEmpty)
			errMsg	= "Check the details below"
		return errMsg
	}

	@NoDoc @Deprecated { msg="Use formErr() instead" }
	Str formMsg() { formErr }

	override Str toStr() {
		"DomJax FormErrs: ${errMsg} ${formMsgs}"
	}
}


@Js class DomJaxRedirect : DomJaxMsg {
	const Uri 		location
	const Str 		method
	const Str:Str	form
	
	new make(|This| f) : super(f) { }

	override Str toStr() {
		"DomJax Redirect: ${location}"
	}
}


@Js class DomJaxErr : DomJaxMsg {
	const Str		errTitle
	const Str		errCode
	const Str		errMsg
	const Str?		errType
	const Str?		errDetail	// it may be useful to display an OpErr's details in the browser
	const Bool		isServerErr
	const Bool		isHttpErr
	const Bool		isClientErr
	@Transient
	const Err?		cause
	
	new make(|This| f) : super(f) { }

	override Str toStr() {
		"DomJax Err: ${errType} - ${errMsg}"
	}
}
