assert(f(-1) == Case.NEGATION);

enum Case {
	NEGATION,
	unknown
}

Case f(int x) {
	switch (x) {
	case  -1:
		return Case.NEGATION;
	}
	return Case.unknown;
}