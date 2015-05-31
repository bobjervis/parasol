class Base {
	Base() {
	}
	
	int inheritedFunc() {
		flagBase = true;
		return 3;
	}
}

class Derived extends Base {
	Derived() {
		super();
	}
	
	int inheritedFunc() {
		int x = super.inheritedFunc();
		flagDerived = true;
		return x * 2;
	}
}

Derived d;

boolean flagBase;
boolean flagDerived;

assert(d.inheritedFunc() == 6);

assert(flagBase);
assert(flagDerived);

Base b;

ref<Base> bp = &b;

flagBase = false;
assert(bp.inheritedFunc() == 3);
assert(flagBase);

assert(bp.class == Base);

ref<Base> x = &d;

assert(x.class == Derived);
