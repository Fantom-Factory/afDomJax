using afIoc::Inject
using afDuvet::HtmlInjector
using util::JsonOutStream

const class DomJaxServer {
	@Inject private const HtmlInjector		injector

	new make(|This| f) { f(this) }
	
	Str scrambleEmail(Str email) {
		email.reverse.toBuf.toBase64Uri.reverse
	}
	
	** Opts defaults to '{revalidate:"hybrid"}' if not specified.
	** 
	** See `https://hyperform.js.org/docs/usage.html#configuration`.
	Void injectHyperform([Str:Obj?]? opts := null) {
		opts = opts ?: ["revalidate":"hybrid"]
		injector.injectScript.fromLocalUrl(`/pod/afDomJax/res/hyperform-0.11.0.min.js`)
		injector.injectScript.withScript("hyperform(window, " + JsonOutStream.writeJsonToStr(opts) + ");")
	}
}
