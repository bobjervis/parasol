class Base {
	int f() {
		return 17;
	}
}

class Derived extends Base {
	private int _x;
	
	Derived(int x) {
		_x = x;
	}
	
	int f() {
		return _x;
	}
}

Derived g_instance(24);

assert(g_instance.f() == 24);
