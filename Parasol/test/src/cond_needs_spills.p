int func(int a, int b) {
	return a - b;
}

int outer(int x, int y, int z) {
	printf("x = %d y = %d z = %d\n", x, y, z);
	return x + y + z;
}

boolean test() {
	return false;
}

boolean testResult = test();

int value = outer(3, 17, testResult ? func(200, 194) : -3);

printf("value = %d\n", value);
assert(value == 17);

