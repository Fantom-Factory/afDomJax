using afIoc::Inject
using afDuvet::HtmlInjector

const class DomJaxServer {
	
	@Inject private const HtmlInjector	injector

	new make(|This| f) { f(this) }
	
	Void injectJs() {
		// these aren't as important as Fantom, so they can load after the main app
		injector.injectScript.fromLocalUrl(`/pod/afDomJax/res/hyperform-0.11.0.min.js`).async
	}
}
