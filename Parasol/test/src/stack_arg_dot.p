class Blob {
	long offset;
}

class Wrapper {
	Blob b;
	long z;
}

Wrapper w;

w.b.offset = 45;

void func(Blob y) {
	assert(y.offset == 45);
}

pointer<Wrapper> p = pointer<Wrapper>(&w);

int y = 0;

func(p[y].b);
