using dom::Win
using dom::Elem
using dom::Event
using dom::HttpRes

@Js class Form {
	private Func?	_onSubmitFn
	private	Func?	_onMsgFn
	private	Func?	_onFormErrsFn
	private	Func?	_onRedirectFn
	private	Func?	_onErrFn
	private	Func?	_onOkayFn

	Elem		elem		{ private set }
	DomJax		domjax
	DomJaxReq	req

	private new _make(Elem formElem, DomJax? domjax := null) {
		this.elem	= formElem
		this.domjax	= domjax ?: DomJax()
		this.req	= this.domjax.postReq(formAction)
		
		elem["method"]  = "POST"

		// useCapture=true, because `blur` doesn't bubble. See https://developer.mozilla.org/en-US/docs/Web/Events/blur#Event_delegation
		elem.onEvent("blur" ,	 true ) |e| { e.target.style.addClass("isWasValid") }
		elem.onEvent("valid",	 false) |e| { e.target.style.addClass("isWasValid") }
		elem.onEvent("submit",	 false) |e| { doSubmit(e) }		
		elem.onEvent("validate", false) |e| {
			// ensure we can see all the form validation errors 
			elem.querySelectorAll("input").each |input| {
				input.style.addClass("isWasValid")
			}
		}
	}

	static new fromSelector(Str selector, DomJax? domjax := null) {
		elem := Win.cur.doc.querySelector(selector)
		if (elem == null) throw Err("Could not find Form: ${selector}")
		return fromElem(elem, domjax)
	}
	
	static new fromElem(Elem elem, DomJax? domjax := null) {
		if (elem.prop(Form#.qname) == null)
			elem.setProp(Form#.qname, Form._make(elem, domjax))
		return elem.prop(Form#.qname)
	}

	Uri formAction() {
		Uri.decode(elem["action"] ?: throw Err("Form #${elem.id} does not define an action attr"))
	}

	** A callback fn that can stop the form submission by returning 'true'. 
	Void onSubmit(|->Bool| fn) {
		_onSubmitFn = fn
	}

	Void onMsg(|DomJaxMsg| fn) {
		_onMsgFn = fn
	}

	Void onRedirect(|DomJaxRedirect?| fn) {
		_onRedirectFn = fn
	}

	Void onFormErrs(|DomJaxFormErrs?| fn) {
		_onFormErrsFn = fn
	}

	Void onErr(|DomJaxErr?| fn) {
		_onErrFn = fn
	}

	Void onOkay(|DomJaxMsg?| fn) {
		_onOkayFn = fn
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
		// meh - this does nothing.
		//if (event != null && event.target.tagName != "a")
		event?.stop
		
		stop := true
		try	stop = _onSubmitFn?.call ?: false
		catch (Err err)
			domjax.callErrFn(DomJaxMsg.makeClientErr("Client Error", "When processing form submission", err))
		if (stop) return

		// hide any err msg - as it shouldn't be valid anymore
		msgDiv := elem.querySelector(".form-invalid")
		msgDiv?.style?.addClass("d-none")

		// shame the browser can't gather form data for us... :(
		// and FormData is multi-part only
		formData := Str:Str[:]
		inputs	 := Elem[,]
		elem.querySelectorAll("input, select, submit, button, textarea").each |input| {
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
		
		domjax.onResponse |httpRes| {
			// re-enable inputs now, just in case fn throws an err
			inputs.each |input| {
				input.style.removeClass("submitting")
				input.enabled = true
				if (input["type"] == "submit")
					input.setProp("disabled", false)
			}
		}
		
		domjax.onMsg(_onMsgFn)
		
		domjax.onFormErrs |msg| {
			if (msgDiv != null) {
				msgDiv.querySelector(".errMsg").text = msg.errMsg
				msgDiv.style.removeClass("d-none")
			}
	
			msg.formMsgs.each |val, key| {
				elem := elem.querySelector("[name=${key}]") 
				elem.style.addClass("isWasValid")
				Hyperform.setMsg(elem, val)
			}
			
			// call the callback so we can check num of bad logins etc
			_onFormErrsFn?.call(msg)
		}
		
		// be-careful no to overwrite the standard redirect implementation
		if (_onRedirectFn != null)
			domjax.onRedirect(_onRedirectFn)
		
		req.form = formData
		domjax.send(req, _onOkayFn)
	}
}
