class Base {
	int _base;
	
	abstract ref<Base> foo();
}

class Derived extends Base {
	ref<Derived> foo() {
		return this;
	}
	
	void bar() {
		foo().baz();
	}
	
	void baz() {
		flagHit = true;
	}
}

boolean flagHit;

Derived d;

d.bar();

assert(flagHit);

