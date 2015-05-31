private int primer;

private enum Enum {
	A,
	B
}

Enum x = Enum.A;

assert(x != Enum.B);
