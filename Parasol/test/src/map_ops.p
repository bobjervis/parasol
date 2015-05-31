string[string] testMap;

testMap["abc"] = "xyz";

testMap["def"] = "mno";

assert(testMap["abc"] == "xyz");

int[string] intMap;

intMap["abc"] = 1;

intMap["def"] = 34;

assert(intMap["abc"] == 1);

enum Enum {
	A, B, C
}

Enum[string] m2;

m2["a"] = Enum.A;
m2["b"] = Enum.B;
m2["c"] = Enum.C;

assert(m2["b"] == Enum.B);

assert(m2["e"] == null);
