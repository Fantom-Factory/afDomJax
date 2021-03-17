using afIoc::Inject
using afDuvet::HtmlInjector
using util::JsonOutStream

** (Service) 
const class DomJaxServer {
	@Inject private const HtmlInjector		injector

	new make(|This| f) { f(this) }
	
	** Injects JS code to initialise Hyperform in the browser.
	** 
	** If not specified, 'opts' defaults to '{revalidate:"hybrid", classes:{...bootstrap-classes...}}'.
	** 
	** See `https://hyperform.js.org/docs/usage.html#configuration`.
	Void injectHyperform([Str:Obj?]? opts := null) {
		opts = opts ?: [
							"revalidate"	: "hybrid",
							"classes"		: [
								"warning"	: "invalid-feedback",
								"valid"		: "is-valid",
								"invalid"	: "is-invalid",
								"validated"	: "was-validated",	// this should really go on the parent form
							]
						]
		injector.injectScript.fromLocalUrl(`/pod/afDomJax/res/hyperform-0.12.0.min.js`)
		injector.injectScript.withScript("hyperform(window, " + JsonOutStream.writeJsonToStr(opts) + ");")
	}
}
