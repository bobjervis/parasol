

boolean abstractCallHit;

class Abstracted {
	public abstract void f(int x, int y, byte... z);
	
	void funcx() {
		// This should compile just fine.
		f(1, 2);
	}
}

class Concrete extends Abstracted {
	private int _local;
	
	public Concrete() {
		_local = 4;
	}
	
	public void f(int x, int y, byte... z) {
		if (_local == 4)
			abstractCallHit = true;
	}
	
}

Concrete concrete;

func(&concrete);

assert(abstractCallHit);

void func(ref<Abstracted> a) {
	a.f(1, 2, 'a');
}

