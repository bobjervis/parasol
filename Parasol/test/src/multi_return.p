int x;
boolean y;

(x, y) = f();

printf("x: %d y: %s\n", x, y ? "true" : "false");
assert(x == 5);
assert(!y);

int, boolean f() {
	return 5, false;
}


string s;
boolean b;

printf("sf():\n");
(s, b) = sf();
printf("called\n");
string, boolean sf() {
	return "top", true;
}

assert(s == "top");
assert(b);
