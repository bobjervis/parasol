class A {
	private static int x;
	
	void set(int y) {
		x = y;
	}
	
	int get() {
		return x;
	}
}

A a;
A b;

assert(a.get() == 0);
assert(b.get() == 0);

a.set(4);

assert(a.get() == 4);
assert(b.get() == 4);

b.set(6);

assert(a.get() == 6);
assert(b.get() == 6);

class B {
	private static int x = 5;
	
	int get() {
		return x;
	}
}

B v;

assert(v.get() == 5);
