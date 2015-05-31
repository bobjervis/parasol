class Container {
	enum List {
		A, B, C, D
	}
	
	static void f(List x) {
		switch (x) {
		case	B:
			break;
		default:
			assert(false);
		}
	}
}

Container.f(Container.List.B);

assert(Container.List(2) == Container.List.C);
