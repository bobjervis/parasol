void func(int i1, float f2, long i3, address i4, long s5, pointer<byte> s6, double s7) {
	assert(i1 == 27);
	assert(f2 == 4.4f);
	assert(i3 == 463636);
	assert(i4 == &foo);
	assert(s5 == -42324);
	assert(s6 == &sample[3]);
	assert(s7 == 16.7);
}

int foo = 44;

string sample = "how about that!";

func(27, 4.4f, 463636, &foo, -42324, &sample[3], 16.7);

void func2(int i1, float f2, long i3, address i4, string s5) {
	assert(i1 == 44);
	assert(f2 == 7.3f);
	assert(i3 == 958237);
	assert(i4 == &sample);
	assert(s5 == "*boom*");
}

func2(44, 7.3f, 958237, &sample, "*boom*");