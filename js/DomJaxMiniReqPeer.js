
fan.afDomJax.DomJaxMiniReqPeer = fan.sys.Obj.$extend(fan.sys.Obj);

fan.afDomJax.DomJaxMiniReqPeer.prototype.$ctor = function(self) {}

// a lot of this is nabbed from dom::HttpReq
fan.afDomJax.DomJaxMiniReqPeer.prototype._doSend = function(self, isMultipart, resFn) {
	var xhr  = new XMLHttpRequest();

	// open request
	xhr.open(self.m_method.toUpperCase(), self.m_url.encode(), true);

	// call fn when complete
	xhr.onreadystatechange = function() {
		if (xhr.readyState == 4)
			resFn.call(fan.afDomJax.DomJaxMiniReqPeer.makeRes(xhr));
	}

	// set response type
	xhr.responseType = "text";

	// setup headers
	var keys = self.m_headers.keys();
	for (var i = 0; i < keys.size(); i++) {
		var key = keys.get(i);
		var val = self.m_headers.get(key);
		xhr.setRequestHeader(key, val);
	}

	// encode the form data
	var form = self.m_form;
	var data = null;

	if (form != null && isMultipart == false)
		data = fan.sys.Uri.encodeQuery(form);

	if (form != null && isMultipart == true) {
		var formData = new FormData();
		var keys = form.keys();
		for (var i = 0; i < keys.size(); i++) {
			var key = keys.get(i);
			var val = form.get(key);

			// formData.set() does an implicit toStr() for us
			// so we only need to extract DomFiles
			if (fan.sys.ObjUtil.is(val, fan.dom.DomFile.$type))
				val = val.peer.file;

			formData.set(key, val);
		}
		data = formData;
	}

	xhr.send(data);
}

fan.afDomJax.DomJaxMiniReqPeer.makeRes = function(xhr) {
	var isText = xhr.responseType == "" || xhr.responseType == "text";

	var res = fan.dom.HttpRes.make();
	res.m_$xhr    = xhr;
	res.m_status  = xhr.status;
	res.m_content = isText ? xhr.responseText : "";

	var all = xhr.getAllResponseHeaders().split("\n");
	for (var i = 0; i < all.length; i++) {
		if (all[i].length == 0) continue;
		var j = all[i].indexOf(":");
		var k = fan.sys.Str.trim(all[i].substr(0, j));
		var v = fan.sys.Str.trim(all[i].substr(j+1));
		res.m_headers.set(k, v);
	}

	return res;
}
