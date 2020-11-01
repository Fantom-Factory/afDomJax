using afIoc
using afBedSheet::HttpRedirect
using afBedSheet::ResponseProcessors
using afBedSheet::GzipCompressible

const class DomJaxModule {

	Void defineServices(RegistryBuilder bob) {
		bob.addService(DomJaxServer#)
	}

	// ---- BedSheet Configuration ----------------------------------------------------------------

	@Contribute { serviceType=ResponseProcessors# }
	Void contributeResponseProcessors(Configuration config) {
		config[DomJaxMsg#] = 				config.build(DomJaxMsgResponseProcessor#)
		config.overrideValue(HttpRedirect#,	config.build(RedirectResponseProcessor#), "afDomJax.HttpRedirect")
	}
	
	@Contribute { serviceType=GzipCompressible# }
	Void configureGzipCompressible(Configuration config) {
		config[MimeType("text/fog")] = true
	}
}
