package fan.afDomJax;

import fan.sys.*;

public class DomJaxMiniReqPeer {
	
	private DomJaxMiniReq self;
	
	public DomJaxMiniReqPeer(DomJaxMiniReq self) {
		this.self = self;
	}

	public static DomJaxMiniReqPeer make(DomJaxMiniReq self) throws Exception {
		return new DomJaxMiniReqPeer(self);
	}
	
	public void _doSend(DomJaxMiniReq self, boolean isMultipart, Func resFn) {
		// boot this bad boy back into Fantom land!
		self._doSendJava(isMultipart, resFn);
	}
}
