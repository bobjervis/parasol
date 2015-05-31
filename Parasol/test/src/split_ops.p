string importPath = "abc,def";
string[] elements = importPath.split(',');
assert(elements.length() == 2);
assert(elements[0] == "abc");
assert(elements[1] == "def");

printf("[%s,%s]\n", elements[0], elements[1]);

Foo bar;

bar.func(importPath);

class Foo {
	ref<string>[] _importPath;
	
	void func(string importPath) {
		for (int i = 0; i < _importPath.length(); i++)
			delete _importPath[i];
		_importPath.clear();
		string[] elements = importPath.split(',');
		printf("Split done: %d\n", elements.length());
		assert(elements.length() == 2);
		assert(elements[0] == "abc");
		assert(elements[1] == "def");
	}
}
