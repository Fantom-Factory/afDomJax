using afIoc::Inject
using afIoc::Scope
using afBedSheet::Text
using afBedSheet::HttpRequest
using afBedSheet::HttpResponse
using afBedSheet::Redirect
using afBedSheet::ResponseProcessor

internal const class RedirectResponseProcessor : ResponseProcessor {
	@Inject private const HttpRequest		httpReq
	@Inject private const HttpResponse		httpRes
			private const ResponseProcessor	origProcessor
	
	new make(Scope scope, |This| f) {
		f(this)
		this.origProcessor = scope.build(Type.find("afBedSheet::RedirectProcessor"))
	}
	
	override Obj process(Obj response) {
		if (!httpReq.isXmlHttpRequest)	// TODO add specific domjax header
			return origProcessor.process(response)
		
		redirect	:= (Redirect) response
		statusCode	:= redirect.type.statusCode(httpReq.httpVersion)
		reMethod	:= (statusCode == 307 || statusCode == 308) ? httpReq.httpMethod : "GET"
		return DomJaxMsg.makeRedirect(redirect.location, reMethod)
	}
}
