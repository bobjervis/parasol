class Base {
	public void put(string label, ref<Base> value) {
		
	}
	
	public string get() {
		return null;
	}
}

class Derived extends Base {
	ref<Base> v;
	string x;
	
	public void put(string label, ref<Base> value) {
		x = label;
		v = value;
	}
}

class Derived2 extends Base {
	string f;
	
	public Derived2(string arg) {
		f = arg;
	}
	
	public string get() {
		return f;
	}
}

Derived d;
void func() {
	ref<Derived> derived = &d;
	string s = "abc";
	
	derived.put("tag", new Derived2(s));
	assert(derived.v.get() == "abc");
	assert(derived.x == "tag");
}

func();
