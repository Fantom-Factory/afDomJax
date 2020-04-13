using afIoc::Inject
using afIoc::Scope
using afBedSheet::Text
using afBedSheet::HttpRequest
using afBedSheet::HttpResponse
using afBedSheet::HttpRedirect
using afBedSheet::ResponseProcessor

internal const class RedirectResponseProcessor : ResponseProcessor {
	@Inject private const HttpRequest		httpReq
	@Inject private const HttpResponse		httpRes
			private const ResponseProcessor	origProcessor
	
	new make(Scope scope, |This| f) {
		f(this)
		this.origProcessor = scope.build(Type.find("afBedSheet::HttpRedirectProcessor"))
	}
	
	override Obj process(Obj response) {
		if (!httpReq.isXmlHttpRequest || httpReq.headers["X-Requested-By"] != DomJax#.pod.name)
			return origProcessor.process(response)
		
		redirect	:= (HttpRedirect) response
		statusCode	:= redirect.type.statusCode(httpReq.httpVersion)
		reMethod	:= (statusCode == 307 || statusCode == 308) ? httpReq.httpMethod : "GET"
		return DomJaxMsg.makeRedirect(redirect.location, reMethod)
	}
}
