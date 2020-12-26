using dom::Win
using concurrent::Actor

@Js class DomJaxErrHandler {
	private Log		log		:= DomJax#.pod.log
	private	Func?	onOpenErrDialogFn
	private	Func?	onClientErrFn

	const	Str		clientErrTitle
	const	Str		clientErrMsg
	const	Str		serverErrTitle
	const	Str		serverErrMsg
	const	Str		opErrTitle
	const	Str		opErrMsg
	const	Str		netErrTitle
	const	Str		netErrMsg

	new make(|This|? fn := null) {
		clientErrTitle	= Actor.locals["afDomJax.clientErrTitle"] ?: "" 
		clientErrMsg	= Actor.locals["afDomJax.clientErrMsg"	] ?: "" 
		serverErrTitle	= Actor.locals["afDomJax.serverErrTitle"] ?: ""
		serverErrMsg	= Actor.locals["afDomJax.serverErrMsg"	] ?: ""
		opErrTitle		= Actor.locals["afDomJax.opErrTitle"	] ?: ""
		opErrMsg		= Actor.locals["afDomJax.opErrMsg"		] ?: ""
		netErrTitle		= Actor.locals["afDomJax.netErrTitle"	] ?: ""
		netErrMsg		= Actor.locals["afDomJax.netErrMsg"		] ?: ""

		fn?.call(this)

		if (clientErrTitle	.isEmpty)	clientErrTitle	= "Shazbot! The computer reported an error!"
		if (clientErrMsg	.isEmpty)	clientErrMsg	= "Don't worry, it's not your fault - it's ours!\n\nRefresh the page and try again".replace("\n", "<br>")
		if (serverErrTitle	.isEmpty)	serverErrTitle	= "Shazbot! The mainframe reported an error!"
		if (serverErrMsg	.isEmpty)	serverErrMsg	= "Don't worry, it's not your fault - it's ours!\n\nRefresh the page and try again".replace("\n", "<br>")
		if (opErrTitle		.isEmpty)	opErrTitle		= "Shazbot!"
		if (opErrMsg		.isEmpty)	opErrMsg		= "Misson Control couldn't complete your request, they say:\n\n<b><center>{err-msg-here}</center></b>\nContact us if this doesn't sound right.".replace("\n", "<br>")
		if (netErrTitle		.isEmpty)	netErrTitle		= "Could not connect to server"
		if (netErrMsg		.isEmpty)	netErrMsg		= "Try again and I'll attempt to re-establish a connection.\n\nIf you see this error regularly, it may indicate poor network quality or a connection issue.".replace("\n", "<br>")

		onClientErr		(Actor.locals["afDomJax.onClientErr"])
		onOpenErrDialog	(Actor.locals["afDomJax.onOpenErrDialog"])
		
		if (this.onClientErrFn		== null) this.onClientErrFn		|err|			{ doClientErr(err) }
		if (this.onOpenErrDialogFn	== null) this.onOpenErrDialog	|title, msg|	{ doOpenErrDialog(title, msg) }
	}
	
	Void onDomJaxErr(DomJaxErr err) {
		// HTTP Errs *should* be transient, e.g. 503
		if (err.isHttpErr) {
			if (err.toErr.errCode == "0") {
				log.err(err.errTitle + "\n" + err.errMsg)
				callOpenErrDialog(netErrTitle, netErrMsg)
				return 
			}
			callOpenErrDialog(err.errTitle, err.errMsg)
			return
		}

		// Server Op Errs should be auto-reported - make OpErrs pod agnostic
		if (err.isServerErr && err.errType.endsWith("::OpErr")) {
			log.err(err.errCode)
			callOpenErrDialog(opErrTitle, opErrMsg.replace("{err-msg-here}", err.errMsg))
			return
		}

		// Server Errs should be auto-reported
		if (err.isServerErr) {
			log.err(err.errCode)
			callOpenErrDialog(serverErrTitle, serverErrMsg)
			return
		}

		// else do the normal err reporting
		callClientErr(err.cause ?: Err("Unknown DomJaxErr: $err.errType - $err.errMsg"))
	}
	
	This onOpenErrDialog(|Str title, Str msg|? fn) {
		this.onOpenErrDialogFn = fn
		return this
	}
	
	This onClientErr(|Err?|? fn) {
		this.onClientErrFn = fn
		return this
	}
	
	private Void callClientErr(Err? cause := null) {
		onClientErrFn?.call(cause)
	}
	
	private Void callOpenErrDialog(Str title, Str msg) {
		onOpenErrDialogFn?.call(title, msg)
	}

	private Void doClientErr(Err? cause := null) {
		log.err("As caught by DomJax", cause)
		callOpenErrDialog(clientErrTitle, clientErrMsg)
		if (cause != null)
			throw cause
	}
	
	private Void doOpenErrDialog(Str title, Str msg) {
		Win.cur.alert("${title}\n\n${msg}")
	}
}
