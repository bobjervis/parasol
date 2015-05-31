int f(int a, int c, int... b) {
	return 0;
}

int f(byte b, byte c, int... d) {
	return 456;
}

byte n = 1;
byte m = 2;
int x = f(n, m, 3);

assert(x == 456);


