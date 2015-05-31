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
vector<int> vec_v;

assert(vec_v.length() == 0);

vec_v.append(3);

assert(vec_v.length() == 1);

assert(vec_v.get(0) == 3);

print("Basic append / get confirmed\n");

vec_v.clear();

assert(vec_v.length() == 0);

print("clear confirmed\n");

for (int i = 0; i < 100; i++) {
	vec_v.append(0);
	vec_v.set(i, i + 1);
}
	
assert(vec_v.length() == 100);

print("Vector filled to 100 elements\n");

for (int i = 0; i < 100; i++)
	assert(vec_v.get(i) == i + 1);

print("vector contents confirmed.\n");

vector<int> x;

x.slice(vec_v, 10, 20);

print("sliced\n");

assert(x.length() == 10);

for (int i = 0; i < 10; i++)
	assert(x.get(i) == i + 11);

print("slice confirmed\n");

*x.elementAddress(7) = 46;

assert(x.get(7) == 46);

print("elementAddress assignment confirmed\n");

vector<string> vs;

vs.append("ab");
print("'ab' appended\n");
for (int i = 0; i < vs.length(); i++) {
	print("x1 element:");
	print(vs.get(i));
	print("\n");
}
vs.append("cd");
for (int i = 0; i < vs.length(); i++) {
	print("x2 element:");
	print(vs.get(i));
	print("\n");
}
vs.append("ef");
vs.append("gh");
vs.append("ij");

assert(vs.length() == 5);

for (int i = 0; i < vs.length(); i++) {
	print("src element:");
	print(vs.get(i));
	print("\n");
}
vector<string> vsCopy;

vsCopy.slice(vs, 2, 4);

print("slice completed\n");
assert(vsCopy.length() == 2);
for (int i = 0; i < vsCopy.length(); i++) {
	print("element:");
	print(vsCopy.get(i));
	print("\n");
}
assert(vsCopy.get(0) == "ef");
assert(vsCopy.get(1) == "gh");

print("Passed\n");

