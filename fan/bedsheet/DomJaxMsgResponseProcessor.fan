using afIoc::Inject
using afBedSheet::Text
using afBedSheet::HttpRequest
using afBedSheet::HttpResponse
using afBedSheet::ResponseProcessor
using afPickle::Pickle

internal const class DomJaxMsgResponseProcessor : ResponseProcessor {
	@Inject private const HttpRequest	httpReq
	@Inject private const HttpResponse	httpRes
	
	new make(|This| f) { f(this) }

	override Obj process(Obj response) {
		csrfToken := httpReq.stash["afSleepSafe.csrfTokenFn"]?->call
		if (csrfToken != null)
			httpRes.headers["X-csrfToken"] = csrfToken

		fog := Pickle.writeObj(response, ["usings" : ["sys", "afDomJax"], "skipNulls" : true])
		return Text.fromContentType(fog, MimeType("text/fog"))
	}
}
