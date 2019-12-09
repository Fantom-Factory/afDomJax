using build::BuildPod

class Build : BuildPod {

	new make() {
		podName = "afDomJax"
		summary = "My Awesome domJax project"
		version = Version("0.0.1")

		meta = [
			"pod.dis"		: "DomJax",
			"repo.tags"		: "web",
			"repo.public"	: "true",
			"repo.internal"	: "true",
			"afIoc.module"	: "afDomJax::DomJaxModule"
		]

		depends = [
			// ---- Fantom Core -----------------
			"sys        1.0.73 - 1.0",
			"dom        1.0.73 - 1.0",

			// ---- Fantom Factory Core ---------
			"afIoc        3.0.8  - 3.0",
//			"afIocEnv     1.1.0  - 1.1",
			"afIocConfig  1.1.0  - 1.1",
//			"afFormBean   1.2.4  - 1.2",

			// ---- Fantom Factory Web ----------
			"afBedSheet   1.5.14 - 1.5",
			"afDuvet      1.1.8  - 1.1",
		]

		srcDirs = [`fan/`, `fan/bedsheet/`, `fan/client/`, `fan/components/`, `test/`]
		resDirs = [`doc/`]
		jsDirs  = [`js/`]
	}
}
