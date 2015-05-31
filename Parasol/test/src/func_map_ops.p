int f() {
	return 4;
}

int g() {
	return 5;
}

int()[string] funcMap;

funcMap["abc"] = f;
funcMap["def"] = g;

assert(funcMap["abc"]() == 4);
