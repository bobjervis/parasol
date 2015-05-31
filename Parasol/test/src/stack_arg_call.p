void func(int i1, int i2, int i3, int i4, int s1, int s2) {
	assert(s2 == 7);
	
}

func(0, 0, 0, 0, f(), 7);

int f() {
	return 3;
}