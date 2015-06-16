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
