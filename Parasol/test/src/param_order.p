// This tests whether the function parameters are being passed in the correct order.

assert(f(234, 543) == 543);

assert(g(1, 65, 876) == 876);

assert(h(1, 2, 3, 4) == 2);

int f(int a, int b) {
	return b;
}
int g(int a, int b, int c) {
	assert(a == 1);
	return c;
}

int h(int axysyz, int b, int c, int dddd) {
	assert(c == 3);
	return b;
}
