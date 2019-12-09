using dom::Doc
using dom::Elem
using dom::Win

@Js class DomJaxUnscrambler {
	private static const Int[] possible := "!#\$%()*+-/\\|:=?@~ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#\$%()*+-/\\|:=?@~".chars
	
	Duration initialTimeout	:= 2.2sec
	
	Void unscramble(Str cssSelector := "[data-unscramble]") {
		// pause for dramatic effect
		Win.cur.setTimeout(initialTimeout) {
			Win.cur.doc.querySelectorAll(cssSelector).each |elem| {
				secret := Buf.fromBase64(elem.attr("data-unscramble").reverse).readAllStr.reverse
				countdown(elem, secret, 0)
			}
		}
	}
	
	private Void countdown(Elem elem, Str secret, Int cnt) {
		size := cnt++ / 4
		text := secret[0..<size] + Str.fromChars((0..<secret.size-size).toList.map { possible.random })
		elem.text = text
		elem->href = "mailto:${text}"
		if (size < secret.size)
			Win.cur.setTimeout(1000ms/60) { countdown(elem, secret, cnt) }
	}	
}
