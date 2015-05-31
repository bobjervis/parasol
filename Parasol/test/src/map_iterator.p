ref<int>[string] map;

ref<int> a = new int;
ref<int> b = new int;
ref<int> c = new int;
*a = 45;
*b = -17;
*c = 24710;

map["a"] = a;
map["b"] = b;
map["c"] = c;

printf("a = %p b = %p c = %p\n", a, b, c);

printf("Starting iterator now...\n");
for (ref<int>[string].iterator i = map.begin(); i.hasNext(); i.next()) {
	printf("In loop\n");
	ref<int> v = i.get();
	string k = i.key();
	printf("%s: *%p -> %d\n", k, v, *v);
	if (k == "a") {
		assert(v == a);
		assert(*v == 45);
	} else if (k == "b") {
		assert(v == b);
		assert(*v == -17);
	} else {
		assert(k == "c");
		assert(v == c);
		assert(*v == 24710);
	}
}
