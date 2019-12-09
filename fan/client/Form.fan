using dom::Elem
using dom::Event

@Js class Form {
	private |Obj? res|?	_onSuccessFn
	private |->Bool|?	_onSubmitFn
	
	Elem		elem		{ private set }
	DomJax		domjax
	DomJaxReq	req
	
	Uri formAction() {
		Uri.decode(elem["action"])
	}
	
	new make(Elem formElem, |This|? f := null) {
		elem	= formElem
		domjax	= DomJax(formElem)
		req		= domjax.postReq(formAction)
		
		f?.call(this)	// let users reset domjax / req

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
	
	** A callback fn that can stop the form submission by returning 'true'. 
	Void onSubmit(|->Bool| fn) {
		_onSubmitFn = fn
	}

	Void onSuccess(|DomJaxMsg? msg| fn) {
		_onSuccessFn = fn
	}

	** Turns form validation off. Usefull for debugging.
	Bool validate {
		get { elem.attr("novalidate") == null }
		set { if (it) elem.removeAttr("novalidate"); else elem.setAttr("novalidate", "") }
	}
	
	private Void doSubmit(Event event) {
		event.stop
		
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
		elem.querySelectorAll("input, submit, button").each |input| {
			if (!input.enabled) return

			// disable inputs until we get a server response, to prevent multiple submits
			inputs.add(input)
			input.style.addClass("submitting")
			input.enabled = false
			if (input.style.hasClass("ckit-Button"))
				input.style.addClass("disabled")
			
			// if we're able to submit, the inputs should be valid
			Hyperform.setMsg(input, "")

			value := null
			// let's submit sensible values for Checkbox, Radio, et al
			switch (input.attr("type")?.lower) {
				case "checkbox"	: value = input->checked->toStr
				case "radio"	: value = input->checked == true ? input->value : null
				default			: value = input->value
			}

			if (value != null)
				formData[input->name] = value
		}
		
		domjax.onResponse {
			// re-enable inputs now, just in case fn throws an err
			inputs.each |input| {
				input.style.removeClass("submitting")
				input.enabled = true
				if (input.style.hasClass("ckit-Button"))
					input.style.removeClass("disabled")
			}
		}
		
		domjax.onFormErrs |msg| {
			msgDiv.querySelector(".errMsg").text = msg.errMsg
			msgDiv.style.removeClass("d-none")
	
			msg.formMsgs.each |val, key| {
				elem := elem.querySelector("[name=${key}]") 
				elem.style.addClass("isWasValid")
				Hyperform.setMsg(elem, val)
			}
		}
		
		req.form = formData
		domjax.send(req) |msg| { _onSuccessFn(msg) }
	}
}
