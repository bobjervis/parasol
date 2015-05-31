namespace parasol:math;

int abs(int x) {
	if (x < 0)
		return -x;
	else
		return x;
}

long abs(long x) {
	if (x < 0)
		return -x;
	else
		return x;
}

int min(int x, int y) {
	if (x < y)
		return x;
	else
		return y;
}

int max(int x, int y) {
	if (x < y)
		return y;
	else
		return x;
}
