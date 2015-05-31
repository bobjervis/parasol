class Wrapper {
	int [] a;
	int i;
	
	int f() {
		return a[--i];
	}
}

Wrapper w;

w.a.append(5);
w.i = 1;
assert(w.f() == 5);
assert(w.i == 0);

