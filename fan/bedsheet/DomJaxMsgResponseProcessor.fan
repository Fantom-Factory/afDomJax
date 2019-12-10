using afIoc::Inject
using afBedSheet::Text
using afBedSheet::HttpRequest
using afBedSheet::HttpResponse
using afBedSheet::ResponseProcessor
using afJson::Json

internal const class DomJaxMsgResponseProcessor : ResponseProcessor {
	static	private const Type:Str		msgTypes	:= [DomJaxMsg#:"0", DomJaxFormErrs#:"1", DomJaxRedirect#:"2", DomJaxErr#:"3"]
	@Inject private const HttpRequest	httpReq
	@Inject private const HttpResponse	httpRes
			private const Json			jsonConv
	
	new make(|This| f) {
		f(this)
		jsonConv = Json().withSerializableMode
	}
	
	override Obj process(Obj response) {
		csrfToken := httpReq.stash["afSleepSafe.csrfTokenFn"]?->call
		if (csrfToken != null)
			httpRes.headers["X-csrfToken"] = csrfToken

		json := msgTypes[response.typeof] + jsonConv.toJson(response)
		return Text.fromContentType(json, MimeType("text/fog"))
	}
}
