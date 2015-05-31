func(2, "abc", "def");

func(0);

func2(45, 45);

func3(275, 275);

void func(int x, string... y) {
	printf("x=%d y.length() = %d\n", x, y.length());
	assert(x == y.length());
}

void func2(int x, int... y) {
	assert(y.length() == 1);
	assert(x == y[0]);
}

void func3(int x, int... y) {
	func2(x, y);
}
