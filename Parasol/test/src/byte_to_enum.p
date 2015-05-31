byte x = 3;

enum R {
	A, B, C, D, E, F
}

R y = R(x);

assert(y == R.D);
