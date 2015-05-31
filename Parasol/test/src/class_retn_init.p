class Word {
	long x;
	
	Word(long xx) {
		x = xx;
	}
}

Word f() {
	Word w(27);
	return w;
}

Word ww = f();

assert(ww.x == 27);
