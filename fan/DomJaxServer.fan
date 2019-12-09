using afIoc::Inject
using afIocEnv::IocEnv
using afIocConfig::Config
using afDuvet::HtmlInjector
using afBedSheet::HttpRequest
using afBedSheet::HttpResponse

const class DomJaxServer {
//	@Inject private const IocEnv			env
//	@Inject private const HttpRequest		httpReq
//	@Inject private const HttpResponse		httpRes
	@Inject private const HtmlInjector		injector
	
//	@Config { id="afBedSheet.podHandler.baseUrl" }
//			private const Uri				podBaseUrl			 

	new make(|This| f) { f(this) }
	
//	Void initDomJaxPage(Method appMethod, Str:Obj pageConfig) {
//		csrfToken	:= httpReq.stash["afSleepSafe.csrfTokenFn"]?->call
//		if (csrfToken != null) {
//			// maps created inline don't allow null values
//			pageConfig["csrfToken"]	= csrfToken
//			if (env.isTest)
//				httpRes.headers["X-csrfToken"] = csrfToken
//		}
//
//		injector.injectFantomMethod(DomJaxPage#init, [appMethod, pageConfig])
//		
//		"sys concurrent graphics web dom afDomJax afMarsApp".split.each |pod| {
//			injector.injectScript.fromLocalUrl(podBaseUrl + `${pod}/${pod}.js`)
//		}
//
////		args	:= [appMethod, pageConfig]
////		argStrs	:= args.map |arg| { StrBuf() { out.writeObj(arg) }.toStr }
////		jargs	:= argStrs.map |Str arg->Str| { "args.add(fan.sys.Str.toBuf(${arg.toCode}).readObj());" }
////
////		injector.injectScript.withScript(
////			"fan.sys.TimeZone.m_cur = fan.sys.TimeZone.fromStr('UTC');
////			 fan.sys.UriPodBase = '${podBaseUrl}';
////			 
////			 var args = fan.sys.List.make(fan.sys.Obj.\$type);
////			 ${jargs.join('\n'.toChar)}
////			 
////			 var qname = '${DomJaxPage#init.qname}';
////			 var main  = fan.sys.Slot.findMethod(qname);
////			 if (main.isStatic()) main.callList(args);
////			 else main.callOn(main.parent().make(), args);"
////		)
//
//		// hyperform isn't as important as Fantom, so they can load after the main app
//		injectHyperform
//	}
	
	Str scrambleEmail(Str email) {
		email.reverse.toBuf.toBase64Uri.reverse
	}
	
	Void injectHyperform() {
		injector.injectScript.fromLocalUrl(`/pod/afDomJax/res/hyperform-0.11.0.min.js`).async		
	}
}
