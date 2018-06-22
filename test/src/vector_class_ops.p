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
vector<int, int> vec_v;

assert(vec_v.length() == 0);

vec_v.append(3);

assert(vec_v.length() == 1);

assert(vec_v.get(0) == 3);

printf("Basic append / get confirmed\n");

vec_v.clear();

assert(vec_v.length() == 0);

printf("clear confirmed\n");

for (int i = 0; i < 100; i++) {
	vec_v.append(0);
	vec_v.set(i, i + 1);
}
	
assert(vec_v.length() == 100);

printf("Vector filled to 100 elements\n");

for (int i = 0; i < 100; i++)
	assert(vec_v.get(i) == i + 1);

printf("vector contents confirmed.\n");

vector<int, int> x;

x.slice(vec_v, 10, 20);

printf("sliced\n");

assert(x.length() == 10);

for (int i = 0; i < 10; i++)
	assert(x.get(i) == i + 11);

printf("slice confirmed\n");

*x.elementAddress(7) = 46;

assert(x.get(7) == 46);

printf("elementAddress assignment confirmed\n");

vector<string, int> vs;

vs.append("ab");
printf("'ab' appended\n");
for (int i = 0; i < vs.length(); i++) {
	printf("x1 element:");
	printf(vs.get(i));
	printf("\n");
}
vs.append("cd");
for (int i = 0; i < vs.length(); i++) {
	printf("x2 element:");
	printf(vs.get(i));
	printf("\n");
}
vs.append("ef");
vs.append("gh");
vs.append("ij");

assert(vs.length() == 5);

for (int i = 0; i < vs.length(); i++) {
	printf("src element:");
	printf(vs.get(i));
	printf("\n");
}
vector<string, int> vsCopy;

vsCopy.slice(vs, 2, 4);

printf("slice completed\n");
assert(vsCopy.length() == 2);
for (int i = 0; i < vsCopy.length(); i++) {
	printf("element:");
	printf(vsCopy.get(i));
	printf("\n");
}
assert(vsCopy.get(0) == "ef");
assert(vsCopy.get(1) == "gh");

printf("test of imported alternate name for 'vector'\n");

import ivec=parasol:types.vector;

ivec<int, int> ivn;

ivn.append(3);
ivn.append(4);

assert(ivn.length() == 2);
assert(ivn.get(0) == 3);
assert(ivn.get(1) == 4);

assert(ivn[1] == 4);
printf("Passed\n");

