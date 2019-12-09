using afIoc
using afBedSheet::Redirect
using afBedSheet::ResponseProcessors
using afBedSheet::GzipCompressible

const class DomJaxModule {

	// ---- BedSheet Configuration ----------------------------------------------------------------

	@Contribute { serviceType=ResponseProcessors# }
	Void contributeResponseProcessors(Configuration config) {
		config[DomJaxMsg#] = 			config.build(DomJaxMsgResponseProcessor#)
		config.overrideValue(Redirect#,	config.build(RedirectResponseProcessor#))
	}
	
	@Contribute { serviceType=GzipCompressible# }
	Void configureGzipCompressible(Configuration config) {
		config[MimeType("text/fog")] = true
	}
}
	