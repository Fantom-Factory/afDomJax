
fan.afDomJax.HyperformPeer = fan.sys.Obj.$extend(fan.sys.Obj);

fan.afDomJax.HyperformPeer.prototype.$ctor = function(self) {}

fan.afDomJax.HyperformPeer.setMsg = function(elem, msg) {
	var element = elem.peer.elem;

	// prevent stack-overflow errors
	if (msg === "" && element.validity.valid)
		return;

	element.setCustomValidity(msg);
	element.reportValidity();

	// note that user error messages are sticky, meaning the input remains
	// invalid until we manually clear the error msg (with a blank string)
	//element.setCustomValidity("");
}

fan.afDomJax.HyperformPeer.checkValidity = function(elem) {
	return elem.peer.elem.checkValidity()
}

fan.afDomJax.HyperformPeer.reportValidity = function(elem) {
	return elem.peer.elem.reportValidity()
}
