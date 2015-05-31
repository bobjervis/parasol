namespace test:head_of_loop;

import test:tail_of_loop;

public class Base {
	public int f() {
		return 3;
	}
}

tail_of_loop.Derived d;

assert(d.f() == 3);
