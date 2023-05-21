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
class A {
	int b, c;
}

A[][] a;

a.resize(2);
int j;
a[j].resize(10);
j++;
a[j].resize(20);
assert(a.length() == 2);
assert(a[0].length() == 10);
assert(a[1].length() == 20);
j = 0;
for (int i = 0; i < a[j].length(); i++)
	a[j][i].b = i * 3 + 7;
int k = 1;
for (int i = 0; i < a[j].length(); i++) {
	a[k][i * 2].c = a[j][i].b - 4;
	a[k][i * 2 + 1].c = a[j][i].b * 17 + 6;
}

for (int i = 0; i < a[j].length(); i++)
	printf("a[0][%d] = %d\n", i, a[j][i].b);

for (int i = 0; i < a[k].length(); i++)
	printf("a[1][%d] = %d\n", i, a[k][i].c);
