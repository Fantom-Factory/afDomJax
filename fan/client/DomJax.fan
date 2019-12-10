using dom::Elem
using dom::HttpReq
using dom::HttpRes
using dom::Win
using concurrent::Actor

@Js class DomJax {
	private Log		log		:= DomJax#.pod.log
	private Elem?	parent	// FIXME needs to be passed to something to set masks and toasts
	private	Func?	onResponseFn
	private	Func?	onFormErrsFn
	private	Func?	onRedirectFn
	private	Func?	onErrFn
	
	new fromParent(Elem? parent) {
		this.parent = parent
		
		onResponse	(Actor.locals["afDomJax.onResponse"	])
		onFormErrs	(Actor.locals["afDomJax.onFormErrs"	])
		onRedirect	(Actor.locals["afDomJax.onRedirect"	])
		onErr		(Actor.locals["afDomJax.onErr"		])
		
		if (this.onRedirectFn	== null)	this.onRedirect		 { doRedirect(it) }
		if (this.onErrFn 		== null)	this.onErr |err, fn| { doErr(err, fn) }
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
	
	Void get(Uri url, |DomJaxMsg|? fn := null) {
		DomJaxReq(url, this).send(fn)
	}

	Void postForm(Uri url, Str:Str form, |DomJaxMsg|? fn := null) {
		postReq(url) { it.form = form }.send(fn)
	}

	Void send(DomJaxReq req, |DomJaxMsg|? fn := null) {
		
		if (req.form != null) {
			if (csrfToken != null && req.form != null)
				req.form = req.form.rw["_csrfToken"] = csrfToken
			req.body = Uri.encodeQuery(req.form)
			req.headers["Content-Type"] = "application/x-www-form-urlencoded"
		}
		
		req.headers["X-Requested-With"] = "XMLHttpRequest"
		req.headers["X-Requested-By"]	= DomJax#.pod.name

		url := req.url
		_doSend(req.method, url, req.headers, req.body) { processRes(url, it, fn) }
	}

	Void goto(DomJaxReq req) {
		if (req.method != "GET")
			throw Err("Can only 'goto' GET requests - ${req.method} methods may return a redirect")
		_doGoto(req.url)
	}
	
	// todo - use to clear masks and throbbers regardless of what the server returns
	This onResponse(|HttpRes|? fn) {
		this.onResponseFn = fn
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
	
	** Implementations should should call fn(err) to inform other listeners of the err.
//	This onErr(|DomJaxErr, |DomJaxMsg?|? |? fn) {	// This messes with F4
	This onErr(Func? fn) {
		this.onErrFn = fn
		return this
	}
	
	This callErrFn(DomJaxErr err, |DomJaxMsg|? fn := null) {
		// Brian's weird type system throws NPEs if call() is used
		onErrFn?.callList([err, fn])
		return this
	}
	
	// ----------------------------------------
	
	private Void processRes(Uri url, HttpRes res, |DomJaxMsg|? fn) {

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
				callErrFn(DomJaxMsg.makeClientErr("HTTP Content Error", "Unsupported Content-Type " + res.headers["Content-Type"] + " at ${url}"), fn)
				return
			}
			
			msg := (DomJaxMsg) res.content.toBuf.readObj

			if (msg.isFormErrs) {
				onFormErrsFn?.call(msg.toFormErrs)
				return
			}

			if (msg.isRedirect) {
				onRedirectFn?.call(msg.toRedirect)
				return
			}

			if (msg.isErr) {
				callErrFn(msg.toErr, fn)
				return
			}

			if (res.status != 200) {
				callErrFn(DomJaxMsg.makeClientErr("HTTP Error: ${res.status}", "When contacting: ${url}"), fn)
				return
			}

			fn?.call(msg)

		} catch (Err err) {
			// don't pass fn() to be called again if it just failed the first time round!
			callErrFn(DomJaxMsg.makeClientErr("Client Error", "When processing server response", err), null)
		}
	}
	
	private Void doRedirect(DomJaxRedirect redirect) {
		if (redirect.method == "GET")
			return Win.cur.hyperlink(redirect.location)
		
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
	
	private Void doErr(DomJaxErr err, |DomJaxMsg?|? fn) {
		Win.cur.alert("${err.errTitle}\n\n${err.errMsg}")
		fn?.call(err)
	}
	
	** Override hook for server-side testing.
	@NoDoc
	virtual Void _doSend(Str method, Uri url, Str:Str headers, Obj? body, |HttpRes| fn) {
		HttpReq { it.uri = url; it.headers = headers }.send(method, body, fn)
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
	Str			method := "GET"
	Obj?[]?		context
	[Str:Str]?	query
	Str:Str		headers	:= Str:Str[:]
	[Str:Str]?	form
	Obj?		body
	
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
			context := this.context
			if (context != null && url.pathStr.contains("*")) {
				path := url.path.map {
					// maybe we should be doing some value encoding here?
					it == "*" ? (context.remove(0) ?: "null"): it	// how does BedSheet decode nulls?
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

	Void send(|DomJaxMsg|? fn := null) {
		domjax.send(this, fn)
	}

	Void sendVia(DomJax domjax, |DomJaxMsg|? fn := null) {
		domjax.send(this, fn)
	}

	Void goto() {
		domjax.goto(this)
	}

	Void gotoVia(DomJax domjax) {
		domjax.goto(this)
	}
}
