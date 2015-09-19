class Foo {
	int offset;

	int compare(Foo loc) {
		return offset - loc.offset;
	}

}

Foo a, b, c;

a.offset = 300;
b.offset = 400;
c.offset = 3000;

Foo[] classy;

classy.append(a);
classy.append(b);
classy.append(c);

Foo key;

key.offset = 600;

int match = classy.binarySearchClosestGreater(key);

printf("class match = %d\n", match);

assert(match == 2);

string[] stuff;


stuff.append("abc");
stuff.append("def");
stuff.append("ghi");

match = stuff.binarySearchClosestGreater("ers");

printf("string match = %d\n", match);

assert(match == 2);
