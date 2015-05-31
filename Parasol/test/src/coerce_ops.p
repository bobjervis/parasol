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
byte b = 0x80;
int x = b;
assert(x == 0x80);
char c = 0x8023;
x = c;
assert(x == 0x8023);
b = byte(x);
assert(b == 0x23);
int z = byte(x) + 1;
assert(z == 0x24);

class Base {
	int x;
}

class Derived extends Base {
	int y;
}

Derived dd;

ref<Derived> dptr = &dd;

ref<Base> bptr = dptr;

assert(dd.x == 0);
assert(dd.y == 0);

dptr.x = 15;

assert(dd.x == 15);
assert(bptr.x == 15);

bptr.x = 22;

assert(dd.x == 22);
assert(dptr.x == 22);

dptr.y = 500;

assert(dd.y == 500);

c = 'a';
if (byte(c).isAlphanumeric())
	assert(true);
else
	assert(false);

unsigned ux = 44;

printf("ux=%d\n", ux);

assert(int(ux) == 44);
