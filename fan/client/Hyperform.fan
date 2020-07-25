using dom::Elem

@NoDoc
@Js class Hyperform {
	
	native static Void setMsg(Elem elem, Str msg)

	native static Bool checkValidity(Elem elem)

	native static Bool reportValidity(Elem elem)
}
