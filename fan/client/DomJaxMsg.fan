
@Serializable
@Js const class DomJaxMsg {
	
	const Bool isOkay
	const Bool isFormErrs
	const Bool isRedirect
	const Bool isErr
	const Obj? payload		// there's no reason for DomJaxMsg to be const if I need to pass mutable objects
	
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
	
	@NoDoc	DomJaxFormErrs	toFormErrs()	{ this }
	@NoDoc	DomJaxRedirect	toRedirect()	{ this }
	@NoDoc	DomJaxErr		toErr()			{ this }
	
	private static const Str:Str emptyMap	:= Str:Str[:].toImmutable
}


@NoDoc
@Js const class DomJaxFormErrs : DomJaxMsg {
	const Str		errMsg
	const Str:Str	formMsgs
	
	new make(|This| f) : super(f) { }
}



@NoDoc
@Js const class DomJaxRedirect : DomJaxMsg {
	const Uri 		location
	const Str 		method
	const Str:Str	form
	
	new make(|This| f) : super(f) { }
}


@NoDoc
@Js const class DomJaxErr : DomJaxMsg {
	const Str		errTitle
	const Str		errCode
	const Str		errMsg
	const Str?		errType
	@Transient
	const Err?		cause
	
	new make(|This| f) : super(f) { }
}
