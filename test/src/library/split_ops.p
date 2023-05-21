/*
   Copyright 2015 Robert Jervis

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */
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
