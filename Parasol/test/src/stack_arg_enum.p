enum R {
	NONE,
	RAX
}

void func(int a1, int a2, int a3, int a4, R reg) {
	assert(reg == R.RAX);
}

func(1, 2, 3, 4, R.RAX);
