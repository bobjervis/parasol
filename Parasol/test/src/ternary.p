int a = 4, b = 7, c = 10;

int foo(int x) {
	return x > 5 ? 1 : -1;
}

assert(foo(a < b ? c : a) > 0);
