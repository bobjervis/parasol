class Inner {
	address pointer;
	int length;
}

class Outer {
	address filler;
	Inner inner;
	
	void f(int y) {
		assert(inner.length == y);
	}
}

Outer x;

Inner y;

y.length = 45;

x.inner = y;

assert(x.inner.length == 45);
x.f(45);
