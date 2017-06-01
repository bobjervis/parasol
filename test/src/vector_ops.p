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
int[] x;

print("Phase I: simple integer array\n");

x.resize(10);

for (int i = 0; i < x.length(); i++)
	x[i] = i;

print("Phase II: Append values to integer array\n");

int[] v;

for (int i = 0; i < 100; i++) {
	v.append(0);
	v[i] = i + 1;
}
	
assert(v.length() == 100);

for (int i = 0; i < 100; i++)
	assert(v[i] == i + 1);
	
print("Phase III: Summing the values in an array\n");

int y = 0;

for (int i = x.length() - 1; i >= 0; i--) {
	y += x[i];
}

assert(y == (x.length() * (x.length() - 1)) / 2);

int[] f() {
	int[] a;
	assert(a.length() == 0);
	a.append(4);
	assert(a.length() == 1);
	a.append(6);
	assert(a.length() == 2);
	assert(a[0] == 4);
	assert(a[1] == 6);
	return a;
}

print("Phase IV: Returning an array by value\n");

int[] xx;

xx = f();

assert(xx.length() == 2);
assert(xx[0] == 4);
assert(xx[1] == 6);

enum E {
   EA,
   EB,
   EC
}

print("Phase V: Enum array\n");

int[E] e;

print("append first\n");

e.append(2);
print("append second\n");

e.append(5);
print("append third\n");

e.append(17);

print("check first\n");

string s("E is ");
s.append(byte('a' + int(e.length())));

s.append(byte('a' + e[E.EA]));
s.append(byte('a' + e[E.EB]));
s.append(byte('a' + e[E.EC]));

printf("len=%d ", int(e.length()));
for (int i = 0; i < 3; i++) {
	printf(" %d", e[E(i)]);
}
printf("\n");

print(s);
print("\n");
assert(e[E.EA] == 2);
assert(e[E.EC] == 17);

e.resize(E.EB);

assert(int(e.length()) == 1);
