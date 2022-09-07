using dom::Win
using dom::Elem
using dom::Event
using dom::HttpRes
using dom::KeyFrame
using dom::KeyFrames
using dom::DomFile

@Js class Form {
	private Func?	_onSubmitFn
	private	Func?	_onResFn
	private	Func?	_onMsgFn
	private	Func?	_onFormErrsFn
	private	Func?	_onRedirectFn
	private	Func?	_onErrFn
	private	Func?	_onOkayFn

	** CSS class applied to the form and elements upon receiving a DomJax FormErrMsg response.
			Str				cssInvalid		:= "invalid"

	Elem		elem		{ private set }
	DomJax		domjax
	DomJaxReq	req
	Bool		shakeInvalidInputs	// let's have this as "opt-in"

	Uri action {
		get { req._url }
		set { req._url = it }
	}

	MimeType enctype {
		get { MimeType(req.headers["Content-Type"]) }
		set { req.headers["Content-Type"] = it.toStr }
	}

	private new _make(Elem formElem, DomJax? domjax := null) {
		action			:= Uri.decode(formElem["action"] ?: throw Err("Form #${formElem.id} does not define an action attr"))
		this.elem		= formElem
		this.domjax		= domjax ?: DomJax()
		this.req		= this.domjax.postReq(action)
		this.enctype	= MimeType (formElem["enctype"] ?: "application/x-www-form-urlencoded")

		formElem["method"]  = "POST"

		// useCapture=true, because `blur` doesn't bubble. See https://developer.mozilla.org/en-US/docs/Web/Events/blur#Event_delegation
		formElem.onEvent("blur" ,	 true ) |e| {
			if (checkValidity(e.target) == false)
				e.target.style.addClass(cssInvalid)
		}
		formElem.onEvent("focus",	 false) |e| {
			// if people are typing - let the input look valid
			// don't judge the input before it's submitted!
			e.target.style.removeClass(cssInvalid)
		}
		formElem.onEvent("input",	 false) |e| {
			// remove invalid marker when the input suddenly becomes valid
			if (checkValidity(e.target))
				e.target.style.removeClass(cssInvalid)
		}
		formElem.onEvent("submit",	 false) |e| {
			doSubmit(e)
		}
	}

	** 'selector' may be an 'Elem' or a Str selector.
	static new make(Obj selector, DomJax? domjax := null) {
		elem := selector as Elem 
		if (elem == null) {
			elem = Win.cur.doc.querySelector(selector)
			if (elem == null) throw Err("Could not find Form: ${selector}")
		}

		if (elem.prop(Form#.qname) == null)
			elem.setProp(Form#.qname, Form._make(elem, domjax))

		return elem.prop(Form#.qname)
	}

	** A callback fn that can stop the form submission by returning 'true'. 
	This onSubmit(|Str:Obj formData, Form->Bool|? fn) {
		_onSubmitFn = fn
		return this
	}

	** Called when the server responds after posting the form.
	This onRes(|HttpRes, Form|? fn) {
		_onResFn = fn
		return this
	}
	
	** Called when the server responds with a DomJaxMsg after posting the form.
	This onMsg(|DomJaxMsg, Form|? fn) {
		_onMsgFn = fn
		return this
	}

	** Called when the server responds with a Redirect message after posting the form.
	This onRedirect(|DomJaxRedirect, Form|? fn) {
		_onRedirectFn = fn
		return this
	}

	** Called when the server responds with a FormError message after posting the form.
	This onFormErrs(|DomJaxFormErrs, Form|? fn) {
		_onFormErrsFn = fn
		return this
	}

	** Called when the server responds with an Error message after posting the form.
	This onErr(|DomJaxErr, Form|? fn) {
		_onErrFn = fn
		return this
	}

	** Called when the server responds with an Okay message after posting the form.
	This onOkay(|DomJaxMsg, Form|? fn) {
		_onOkayFn = fn
		return this
	}

	** Turns form validation off. Useful for debugging.
	Bool validate {
		get { formElem.attr("novalidate") == null }
		set { if (it) formElem.removeAttr("novalidate"); else formElem.setAttr("novalidate", "") }
	}
	
	** Returns 'true' if all inputs are valid. 
	Bool isValid() {
		checkValidity(formElem)
	}

	** Manually submits the form.
	** Returns 'true' if the form was valid and submitted.
	Bool submit(Bool force := false) {
		if (force == false)
			if (reportValidity(formElem) == false)
				return false
		doSubmit(null)
		return true
	}
	
	** No-op.
	Void noop() { }
	
	** Gathers up and returns all form values.
	Str:Obj values() {
		// shame the browser can't gather form data for us... :(
		// and FormData is multi-part only
		formData := Str:Obj[:]
		allFormInputs.each |input| {
			if (!input.enabled) return

			value := null
			// let's submit sensible values (i.e. "true") for Checkbox, Radio, et al
			switch (input.attr("type")?.lower ?: input.tagName.lower) {
				case "checkbox"	: value = input->checked == true // make sure it's a bool
				case "radio"	: value = input->checked == true ? input->value : null
				// https://stackoverflow.com/questions/14333797/finding-which-option-is-selected-in-select-without-jquery
				case "select"	:
					// cater for selects with "multiple" values
					values := input.querySelectorAll("option:checked").map { it->value }
					if (values.size > 0)
						// CSV is down and dirty, but it gets us out of a hole with DLR
						value	= values.size == 1 ? values.first : values.join(",")
				case "file"		:
					// I'm not sure how we define an input with multiple files!?
					value = (DomFile?) input->files->first
				default			: value = input->value
			}

			if (value != null)
				formData[input->name] = value
		}
		return formData
	}
	
	Void setInputErr(Str inputName, Str errMsg) {
		inputElem := formElem.querySelector("[name=${inputName}]") 
		if (inputElem == null) {
			Log.get("afDomJax").warn("Could not find input for name: ${inputName}")
			return
		}
		
		// do NOT set a form field err msg - 'cos they ALL need to be cleared before the form can be submitted again
		// while this sounds fine in theory, in practice this does not play nice with LastPass auto fills and the like
		// so, given it's just a pop-up title msg, best to just ignore it
		// Hyperform.setMsg(elem, errMsg)

		inputElem.style.addClass(cssInvalid)
		if (shakeInvalidInputs)
			shakyShaky(inputElem)
	}
	
	** Checks the element's value against its constraints.
	** If the value is invalid, it fires an 'invalid' event at the element and returns 'false';
	** otherwise returns 'true'.
	native Bool checkValidity(Elem elem)
	
	** Performs the same validity checking steps as 'checkValidity()' but if 'invalid', 
	** this also fires the 'invalid' event on the element reports the problem to the user.
	native Bool reportValidity(Elem elem)
	
	private Void doSubmit(Event? event) {
		event?.stop
		
		formData := this.values
		inputs	 := Elem[,]
		allFormInputs.each |input| {
			if (!input.enabled) return

			// disable inputs until we get a server response, to prevent multiple submits
			inputs.add(input)
			input.style.addClass("submitting")
			input.enabled = false
			if (input["type"] == "submit")
				input.setProp("disabled", true)

			// if we're able to submit, the inputs should be valid
			input.style.removeClass(cssInvalid)
		}		
		
		enableInputsFn := |->| {
			// re-enable inputs as soon as, just in case fn throws an err
			inputs.each |input| {
				input.style.removeClass("submitting")
				input.enabled = true
				if (input["type"] == "submit")
					input.setProp("disabled", false)
			}
		}
		
		stop := true
		try	stop = _onSubmitFn?.call(formData, this) ?: false
		catch (Err err)
			domjax.callErrFn(DomJaxMsg.makeClientErr("Client Error", "When processing form submission", err))

		if (stop) {
			enableInputsFn()
			return
		}

		// hide any form level err msgs - as they shouldn't be applicable anymore
		// (as in, why would we be submitting an invalid form!?)
		formElem.style.removeClass(cssInvalid)
		
		domjax.onResponse |httpRes| {
			enableInputsFn()
			_onResFn?.call(httpRes, this)
		}
		
		// be-careful not to overwrite any existing DomJax onMsgFn
		if (_onMsgFn != null)
			domjax.onMsg {
				// given this is an async fn - double check it still exists!
				_onMsgFn?.call(it, this)
			}

		domjax.onFormErrs |msg| {
			formElem.style.addClass(cssInvalid)

			msg.formMsgs.each |val, key| {
				setInputErr(key, val)
			}
			
			// call the callback so we can check num of bad logins etc
			_onFormErrsFn?.call(msg, this)
		}
		
		// be-careful not to overwrite the standard redirect implementation
		if (_onRedirectFn != null)
			domjax.onRedirect {
				// given this is an async fn - double check it still exists!
				_onRedirectFn?.call(it, this)
			}
		
		// be-careful not to overwrite any existing DomJax onMsgFn
		if (_onErrFn != null)
			domjax.onErr {
				// given this is an async fn - double check it still exists!
				_onErrFn?.call(it, this)
			}
		
		req.form = formData
		domjax.send(req) {
			_onOkayFn?.call(it, this)
		}
	}
	
	private Elem formElem() { elem }

	private Elem[] allFormInputs() {
		formElem.querySelectorAll("input, select, submit, button, textarea")
	}
	
	static Void shakyShaky(Elem elem) {
		// https://stackoverflow.com/questions/15726000/css-animation-similar-to-mac-os-x-10-8-invalid-password-shake
		shakey := KeyFrames([
			KeyFrame("8%, 41%"	, ["transform": "translateX(-10px)"]),
			KeyFrame("25%, 58%"	, ["transform": "translateX( 10px)"]),
			KeyFrame("75%"		, ["transform": "translateX( -5px)"]),
			KeyFrame("92%"		, ["transform": "translateX(  5px)"]),
			KeyFrame("0%, 100%"	, ["transform": "translateX(  0  )"]),
		])
		elem.animateStart(shakey, null, 500ms)
	}
}
