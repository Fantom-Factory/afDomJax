package fan.afDomJax;

import fan.sys.*;

public class FormPeer {

	public static FormPeer make(Form self) throws Exception {
		return new FormPeer();
	}

	// just enable forms to be submitted for now
	public boolean checkValidity(Form self) { return true; }

	// just enable forms to be submitted for now
	public boolean reportValidity(Form self) { return true; }
}
