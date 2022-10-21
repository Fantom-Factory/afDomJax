using dom::Elem
using dom::HttpReq
using dom::HttpRes
using dom::Win
using dom::DomFile
using concurrent::Actor
using afPickle::Pickle

@Js class DomJax {
	private Log		log		:= DomJax#.pod.log
	private	Func?	onResponseFn
	private	Func?	onMsgFn
	private	Func?	onFormErrsFn
	private	Func?	onRedirectFn
	private	Func?	onErrFn

	** Number of request retries on short-lived connection errors.
			Int		maxRetries  := 3 {
				set { if (it < 0) throw ArgErr("maxRetries must be > 0: $it"); &maxRetries = it }
			}
	
	@NoDoc
		// Firefox XHR requests time out after 6 secs, Chrome in 2 secs (or less)!
		// It's fine to keep trying, we just need to respond to the user after a reasonable amount of time
		Duration	maxResponseTime	:= 3sec

	new make() {
		onResponse	(Actor.locals["afDomJax.onResponse"	])
		onFormErrs	(Actor.locals["afDomJax.onFormErrs"	])
		onRedirect	(Actor.locals["afDomJax.onRedirect"	])
		onMsg		(Actor.locals["afDomJax.onMsg"		])
		onErr		(Actor.locals["afDomJax.onErr"		])
		
		if (this.onRedirectFn	== null)	this.onRedirect		{ doRedirect(it) }
		if (this.onErrFn 		== null)	this.onErr |err|	{ doErr(err) }
	}

	** Turns HTTP Request / Response debugging on and off.
	Bool debug {
		get { log.isDebug }
		set { log.level = it ? LogLevel.debug : LogLevel.info }
	}
	
	@NoDoc
	Str? csrfToken {
		get { Actor.locals["afDomJax.csrfToken"] }
		set { Actor.locals["afDomJax.csrfToken"] = it }
	}

	DomJaxReq getReq(Uri url) {
		DomJaxReq(url, this)
	}
	
	DomJaxReq postReq(Uri url) {
		DomJaxReq(url, this) { it.method = "POST" }
	}
	
	Void get(Uri url, |DomJaxMsg|? onOkayFn := null) {
		getReq(url).send(onOkayFn)
	}

	Void post(Uri url, |DomJaxMsg|? onOkayFn := null) {
		postReq(url).send(onOkayFn)
	}

	Void postForm(Uri url, Str:Obj form, |DomJaxMsg|? onOkayFn := null) {
		postReq(url) {
			it.form = form
			it.headers["Content-Type"] = "application/x-www-form-urlencoded"
		}.send(onOkayFn)
	}

	Void send(DomJaxReq req, |DomJaxMsg|? onOkayFn := null) {
		req._prepare(csrfToken)

		url := req.url
		if (log.isDebug) {
			reqUrl := url.scheme == null ? "" : url.scheme + "://"
			reqUrl += url.auth ?: ""
			reqUrl = reqUrl.size > 0 ? " to: $reqUrl" : ":"
			log.debug("\n\nDomJax HTTP Request$reqUrl\n\n${req.dumpToStr}\n")
		}

		_doSend(req.method, url, req.headers, req.form) { processRes(url, it, onOkayFn) }
	}

	Void goto(Uri url) {
		_doGoto(url)
	}

	This onResponse(|HttpRes|? fn) {
		this.onResponseFn = fn
		return this
	}
	
	** Called whenever *any* message is received, regardless of type. 
	This onMsg(|DomJaxMsg|? fn) {
		this.onMsgFn = fn
		return this
	}
	
	This onFormErrs(|DomJaxFormErrs|? fn) {
		this.onFormErrsFn = fn
		return this
	}
	
	This onRedirect(|DomJaxRedirect|? fn) {
		this.onRedirectFn = fn
		return this
	}
	
	This onErr(|DomJaxErr|? fn) {
		this.onErrFn = fn
		return this
	}
	
	This callErrFn(DomJaxErr err) {
		onErrFn?.call(err)
		return this
	}
	
	// ----------------------------------------
	
	private Void processRes(Uri url, HttpRes res, |DomJaxMsg|? onOkayFn) {

		// more than likely this is due to a timed out CSRF token
		// lets not make a big deal out of it - just refresh the page
		// and let the user continue with their life!
		if (res.status == 403) {
			_doReload()
			return
		}
		
		try {
			// keep us updated!
			if (res.headers.containsKey("X-csrfToken"))
				csrfToken = res.headers["X-csrfToken"]

			onResponseFn?.call(res)

			if (res.headers["Content-Type"] != "text/fog") {
				// if it's not a fog, it's probably a server error, or a 404, or summut...
				if (res.status == 500)
					return callErrFn(DomJaxMsg.makeServerErr("Server Error: ${res.status}", "When contacting: ${url}"))

				if (res.status != 200)
					// status is 0 if DomJax could NOT connect to server
					return callErrFn(DomJaxMsg.makeHttpErr(res.status, url))

				// nope - it's genuinely a content error! Mimic a HttpErr
				return callErrFn(DomJaxErr {
					it.isErr		= true
					it.errTitle		= "HTTP Content Error"
					it.errCode		= res.status.toStr
					it.errMsg		= "Unsupported Content-Type " + res.headers["Content-Type"] + " at ${url}"
					it.isHttpErr	= true
				})
			}

			// Damn you Brian! - https://fantom.org/forum/topic/2758
			msg := (DomJaxMsg) Pickle.readObj(res.content)

			// always call this
			onMsgFn?.call(msg)

			if (msg.isFormErrs) {
				onFormErrsFn?.call(msg.toFormErrs)
				return
			}

			if (msg.isRedirect) {
				onRedirectFn?.call(msg.toRedirect)
				return
			}

			if (msg.isErr) {
				callErrFn(msg.toErr)
				return
			}

			if (res.status != 200) {
				callErrFn(DomJaxMsg.makeHttpErr(res.status, url))
				return
			}

			onOkayFn?.call(msg)

		} catch (Err err) {
			// don't pass fn() to be called again if it just failed the first time round!
			callErrFn(DomJaxMsg.makeClientErr("Client Error", "When processing server response", err))
		}
	}
	
	** Public so it may be invoked manually
	static Void doRedirect(DomJaxRedirect redirect) {
		if (redirect.method == "GET") {
			win		:= Win.cur
			oldUrl	:= win.uri
			Win.cur.hyperlink(redirect.location)

			// some URIs, like those for the same page but with an extra #frag, do NOT trigger a page reload
			// so if we're still here, hanging around, FORCE a page reload to the new URL
			newUrl		:= redirect.location
			sameAuth	:= oldUrl.auth == newUrl.auth
			samePath	:= oldUrl.pathOnly == newUrl.pathOnly

			// the auth on re-directs (for the same site) is usually null
			if (oldUrl.auth == null || newUrl.auth == null)
				sameAuth = true

			if (sameAuth && samePath)
				// we need to set a timeout, else browsers BLOCK the initial redirect / hyperlink 
				Win.cur.setTimeout(10ms) {
					typeof.pod.log.info("Still around after redirect - forcing a page reload")
					Win.cur.reload(true)
				}
			return
		}

		form := Elem("form") {
			it.id = "jsRedirectForm"
			it.setAttr("method", "POST")
			it.setAttr("action", redirect.location.encode)
		}
		redirect.form.each |val, key| {
			form.add(Elem("input") {
				it.setAttr("type", "hidden")
				it.setAttr("name", key)
				it.setAttr("value", val)
			})
		}
		Win.cur.doc.body.add(form)
		Win.eval("document.getElementById('jsRedirectForm').submit();")
		return
	}
	
	private Void doErr(DomJaxErr err) {
		DomJaxErrHandler().onDomJaxErr(err)
	}

	** Override hook for server-side testing.
	@NoDoc
	virtual Void _doSend(Str method, Uri url, Str:Str headers, [Str:Obj]? form, |HttpRes| resFn) {
		DomJaxMiniReq(maxRetries, maxResponseTime, method, url, headers, form, resFn).send
	}

	** Override hook for server-side testing.
	@NoDoc
	virtual Void _doGoto(Uri url) {
		Win.cur.hyperlink(url)
	}

	** Override hook for server-side testing.
	@NoDoc
	virtual Void _doReload() {
		Win.cur.reload
	}
}

@Js class DomJaxReq {
	private DomJax?	domjax

	Uri			_url
	Str			method		:= "GET"
	Str:Str		headers		:= Str:Str[:] { it.caseInsensitive = true }
	Obj?[]?		context
	[Str:Str]?	query
	[Str:Obj]?	form
	
	new make(Uri url) {
		this._url	= url
	}
	
	internal new _makeWith(Uri url, DomJax? domjax := null) {
		this._url	= url
		this.domjax	= domjax
	}

	Uri url() {
		url := this._url
		if (this.context != null) {
			// replace "*" in URL with context segments
			context := this.context.dup
			if (url.pathStr.contains("*")) {
				path := url.path.map {
					// maybe we should be doing some value encoding here?
					it == "*" ? (context.removeAt(0) ?: "null"): it	// how does BedSheet decode nulls?
				}
				url = _newPath(url, path)
			}
		}
		if (query != null)
			url = url.plusQuery(query)
		return url
	}
	
	private static Uri _newPath(Uri url, Str[] path) {
		str := ""
		if (url.scheme != null)
			str += url.scheme + ":"
		if (url.auth != null)
			str += "//" + url.auth + "/"
		uri := str.toUri
		if (url.isPathAbs)
			uri = uri.plusSlash
		path.each |p, i| { uri = (i == 0) ? uri.plusName(p) : uri.plusSlash.plusName(p) }
		if (url.queryStr != null)
			uri = uri.plusQuery(url.query)
		if (url.frag != null)
			uri = (uri.toStr + "#" + url.frag).toUri
		return uri
	}

	Void send(|DomJaxMsg|? onOkayFn := null) {
		domjax.send(this, onOkayFn)
	}

	Void sendVia(DomJax domjax, |DomJaxMsg|? onOkayFn := null) {
		domjax.send(this, onOkayFn)
	}

	** Navigate to the page.
	Void goto() {
		if (method != "GET")
			throw Err("Can only 'goto' GET requests")
		domjax._doGoto(this.url)
	}

	** Navigate to the page.
	Void gotoVia(DomJax domjax) {
		if (method != "GET")
			throw Err("Can only 'goto' GET requests")
		domjax._doGoto(this.url)
	}
	
	** Dumps a debug string that in some way resembles the HTTP request.
	This dump() {
		echo(dumpToStr)
		return this
	}
	
	** Returns a debug string that in some way resembles the HTTP request.
	Str dumpToStr() {
		out := "${method} ${url.relToAuth.encode} HTTP/1.1\n"
		headers.each |v, k| { out += "${k}: ${v}\n" }
		out += "\n"
		if (form != null) {
			out += Uri.encodeQuery(form.map { it.toStr })
			out += "\n"
		}
		return out
	}
	
	internal Void _prepare(Str? csrfToken) {
		if (form != null) {
			if (csrfToken != null)
				form = form.rw["_csrfToken"] = csrfToken
			
			// file uploads MUST be sent via multipart but guaranteed...
			// I'm gonna forget to set the Form's enctype!  
			if (form.any { it is DomFile })
				// JS adds the all-important "boundry" param to the MimeType
				form["Content-Type"] = "multipart/form-data"
		}

		headers["X-Requested-With"] = "XMLHttpRequest"
		headers["X-Requested-By"]	= DomJax#.pod.name
		return this
	}
}

@Js internal class DomJaxMiniReq {
	private Log			log				:= DomJax#.pod.log
	private Duration	maxResponseTime
	private Int			maxRetries
	private	Str			method
	private	Uri			url
	private	Str:Str		headers
	private	[Str:Obj]?	form
	private	|HttpRes|	resFn
	private Duration[]	startTimes
	private	Bool		isMultipart
	
	new make(Int maxRetries, Duration maxResponseTime, Str method, Uri url, Str:Str headers, [Str:Obj]? form, |HttpRes| resFn) {
		this.maxRetries			= maxRetries
		this.maxResponseTime	= maxResponseTime
		this.method				= method
		this.url				= url
		this.headers			= headers
		this.form				= form
		this.resFn				= resFn
		this.startTimes			= Duration[,]
		this.isMultipart		= headers["Content-Type"]?.lower == "multipart/form-data"
		if (this.isMultipart)
			// the JS FormData adds its own Content-Type with the all-important "boundry" param
			// needed to decode the form data on the server
			headers.remove("Content-Type")
		else
			// for x-www-form-urlencoded form data, convert it all to Strs
			this.form = form?.map { it.toStr }
	}
	
	Void send() {
		startTimes.push(Duration.now)
		
		doResFn := |HttpRes res| {
			// a HTTP status of 0 typically means a connection error
			if (res.status == 0) {
				log.warn("HTTP 0 Err - Dodgy connectivity suspected")
				log.warn("HTTP 0 Err - Response returned in ${(Duration.now - startTimes.peek).toLocale}")
				
				// we get random connection issues that seem to return immediately
				// so just try again if that happens
				if ((Duration.now - startTimes.peek) < maxResponseTime) {
					
					// don't keep trying forever - so put a cap on it!
					if (startTimes.size <= maxRetries) {
						log.warn("HTTP 0 Err - Retrying attempt No. ${startTimes.size}")
						
						// do it again, but better!
						send()
						return
					} else
						log.warn("HTTP 0 Err - Max retries exceeded: ${startTimes.size} > ${maxRetries}")
				} else
					log.warn("HTTP 0 Err - Not retrying, the long response time indicates a real error")
			}
			
			if (log.isDebug) {
				out := "HTTP/1.1 ${res.status}\n"
				res.headers.each |v, k| { out += "${k}: ${v}\n" }
				out += "\n"
				if (res.content.trimToNull != null) {
					out += res.content
					out += "\n"
				}
				log.debug("\n\nDomJax HTTP Response:\n\n${out}\n")
			}
			
			// success!
			resFn(res)
		}

		_doSend(isMultipart, doResFn)
	}
	
	private native Void _doSend(Bool isMultipart, |HttpRes res| resFn)
}
