/*
   Copyright 2015 Rovert Jervis

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
map<string, string> testMap;

printf("%d\n", long.MIN_VALUE);

assert(testMap.size() == 0);

print("Before\n");
*testMap.createEmpty("abc") = "xyz";
print("After\n");
*testMap.createEmpty("def") = "mno";
print("After 2\n");
assert(testMap.get("abc") == "xyz");
print("Done!\n");

map<int, string> intMap;

intMap.set("abc", 1);

*intMap.createEmpty("def") = 34;

assert(intMap.get("abc") == 1);


map<string, string> deletingMap;

deletingMap.set("abc", "123");
deletingMap.set("def", "456");
deletingMap.set("ghi", "789");

boolean saw123, saw456, saw789, saw246;

assert(deletingMap.size() == 3);

iterateMap();
assert(saw123);
assert(saw456);
assert(saw789);
assert(!saw246);

deletingMap.remove("def");

assert(deletingMap.size() == 2);

iterateMap();
assert(saw123);
assert(!saw456);
assert(saw789);
assert(!saw246);

deletingMap.set("def", "246");

assert(deletingMap.size() == 3);

iterateMap();
assert(saw123);
assert(!saw456);
assert(saw789);
assert(saw246);

void iterateMap() {
	saw123 = false;
	saw456 = false;
	saw789 = false;
	saw246 = false;
	int n = 0;
	for (map<string, string>.iterator i = deletingMap.begin(); i.hasNext(); i.next(), n++) {
		switch (i.get()) {
		case "123":
			assert(i.key() == "abc");
			saw123 = true;
			break;
			
		case "456":
			assert(i.key() == "def");
			saw456 = true;
			break;
			
		case "789":
			assert(i.key() == "ghi");
			saw789 = true;
			break;
			
		case "246":
			assert(i.key() == "def");
			saw246 = true;
			break;
			
		default:
			printf("Unexpected value in iterated elements: [%s]: %s\n", i.key(), i.get());
			assert(false);
		}
	}
}
