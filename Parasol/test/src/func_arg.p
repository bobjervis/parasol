assert(t(2, f, "abc") == 8);

assert(t(5, g, "df") == 11);

int t(int x, int h(string n), string z) {
	return x + h(z);
}

int f(string y) {
	return 3 + y.length();
}

int g(string y) {
	return 3 * y.length();
}
