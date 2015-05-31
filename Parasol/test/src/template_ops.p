TestTemplate<byte> V;

int n = V.f(0x10);

assert(n == 4);

class TestTemplate<class A> {
    int f(A x) {
		int i = 0;
		while (x != 0) {
			x <<= 1;
			i++;
		}
		return i;
	}
}
