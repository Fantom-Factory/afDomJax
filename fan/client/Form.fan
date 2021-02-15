using dom::Win
using dom::Elem
using dom::Event
using dom::HttpRes
using dom::KeyFrame
using dom::KeyFrames

@Js class Form {
	private Func?	_onSubmitFn
	private	Func?	_onMsgFn
	private	Func?	_onFormErrsFn
	private	Func?	_onRedirectFn
	private	Func?	_onErrFn
	private	Func?	_onOkayFn

	** CSS class applied to the form (and input) upon validation.
			Str				cssValidated	:= "isWasValid"
	** CSS class applied to the form upon submitting a request. (Use to hide form error divs.)
			Str				cssValid		:= "is-valid"
	** CSS class applied to the form upon receiving a DomJax FormErrMsg response.
			Str				cssInvalid		:= "is-invalid"

	Elem		elem		{ private set }
	DomJax		domjax
	DomJaxReq	req
	Bool		shakeInvalidInputs	// let's have this as "opt-in"

	private new _make(Elem formElem, DomJax? domjax := null) {
		this.elem	= formElem
		this.domjax	= domjax ?: DomJax()
		this.req	= this.domjax.postReq(formAction)
		
		elem["method"]  = "POST"

		// useCapture=true, because `blur` doesn't bubble. See https://developer.mozilla.org/en-US/docs/Web/Events/blur#Event_delegation
		elem.onEvent("blur" ,	 true ) |e| { e.target.style.addClass(cssValidated) }
		elem.onEvent("valid",	 false) |e| { e.target.style.addClass(cssValidated) }
		elem.onEvent("submit",	 false) |e| { doSubmit(e) }		
		elem.onEvent("validate", false) |e| {
			// ensure we can see all the form validation errors 
			allFormInputs.each |input| {
				input.style.addClass(cssValidated)
				// something strange is going on... I can't re-submit the form without this!?
				Hyperform.setMsg(input, "")
			}
		}
		elem.onEvent("invalid", false) |e| {
			if (shakeInvalidInputs)
				shakyShaky(e.target)
		}
		allFormInputs.each {
			it.onEvent("focus",	 false) |e| {
				// if people are typing - let the input look valid
				// don't judge the input before it's submitted!
				e.target.style.removeClass(cssValidated).removeClass(cssValid).removeClass(cssInvalid)
				Hyperform.setMsg(e.target, "")
			}			
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

	Uri formAction() {
		Uri.decode(elem["action"] ?: throw Err("Form #${elem.id} does not define an action attr"))
	}

	** A callback fn that can stop the form submission by returning 'true'. 
	This onSubmit(|Str:Str formData, Form form->Bool|? fn) {
		_onSubmitFn = fn
		return this
	}

	This onMsg(|DomJaxMsg, Form form|? fn) {
		_onMsgFn = fn
		return this
	}

	This onRedirect(|DomJaxRedirect, Form form|? fn) {
		_onRedirectFn = fn
		return this
	}

	This onFormErrs(|DomJaxFormErrs, Form form|? fn) {
		_onFormErrsFn = fn
		return this
	}

	This onErr(|DomJaxErr, Form form|? fn) {
		_onErrFn = fn
		return this
	}

	This onOkay(|DomJaxMsg, Form form|? fn) {
		_onOkayFn = fn
		return this
	}

	** Turns form validation off. Useful for debugging.
	Bool validate {
		get { elem.attr("novalidate") == null }
		set { if (it) elem.removeAttr("novalidate"); else elem.setAttr("novalidate", "") }
	}
	
	** Returns 'true' if all inputs are valid. 
	** 
	** If 'report' is 'true' then input errors are reported to the user.
	Bool isValid(Bool report := false) {
		report ? Hyperform.reportValidity(elem) : Hyperform.checkValidity(elem)
	}
	
	** Manually submits the form.
	Void submit(Bool force := false, Bool report := true) {
		if (!force)
			if (!isValid(report))
				return
		doSubmit(null)
	}
	
	** No-op.
	Void noop() { }
	
	private Void doSubmit(Event? event) {
		event?.stop
		
		// shame the browser can't gather form data for us... :(
		// and FormData is multi-part only
		formData := Str:Str[:]
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
			Hyperform.setMsg(input, "")

			value := null
			// let's submit sensible values for Checkbox, Radio, et al
			switch (input.attr("type")?.lower ?: input.tagName.lower) {
				case "checkbox"	: value = input->checked->toStr
				case "radio"	: value = input->checked == true ? input->value : null
				// https://stackoverflow.com/questions/14333797/finding-which-option-is-selected-in-select-without-jquery
				case "select"	: value = input.querySelector("option:checked")->value
				default			: value = input->value
			}

			if (value != null)
				formData[input->name] = value
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
		elem.style.removeClass(cssInvalid).addClass(cssValid)
		
		domjax.onResponse |httpRes| {
			enableInputsFn()
		}
		
		// be-careful not to overwrite any existing DomJax onMsgFn
		if (_onMsgFn != null)
			domjax.onMsg {
				// given this is an async fn - double check it still exists!
				_onMsgFn?.call(it, this)
			}

		domjax.onFormErrs |msg| {
			elem.style.removeClass(cssValid).addClass(cssInvalid)	//.addClass(cssValidated)	// reserve isWasValid just for inputs - the CSS usually adds an icon

			msg.formMsgs.each |val, key| {
				elem := elem.querySelector("[name=${key}]") 
				Hyperform.setMsg(elem, val)
				elem.style.addClass(cssInvalid)
				elem.style.addClass(cssValidated)
				if (shakeInvalidInputs)
					shakyShaky(elem)
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

	private Elem[] allFormInputs() {
		elem.querySelectorAll("input, select, submit, button, textarea")
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
