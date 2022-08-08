
fan.afDomJax.FormPeer = fan.sys.Obj.$extend(fan.sys.Obj);

fan.afDomJax.FormPeer.prototype.$ctor = function(self) {}

fan.afDomJax.FormPeer.prototype.checkValidity = function(self, elem) {
	var element = elem.peer.elem;
	if (typeof element.checkValidity === undefined)
		return true;	// tell IE everything is okay - let the server handle it
	return element.checkValidity();
}

fan.afDomJax.FormPeer.prototype.reportValidity = function(self, elem) {
	var element = elem.peer.elem;
	if (typeof element.reportValidity === undefined)
		return true;	// tell IE everything is okay - let the server handle it
	return element.reportValidity();
}
