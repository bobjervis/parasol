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

unsigned u;
short s;
int i;
long l;
float f;
double d;
var v;
address a;
boolean bool;
enum E { A, B, C };
E e;
ref<int> p;
int(double) fn;

bool = true;

b = byte(bool);
c = char(bool);
u = unsigned(bool);
s = short(bool);
i = int(bool);
l = long(bool);
f = float(bool);
d = double(bool);
v = var(bool);
a = address(bool);
e = E(bool);
p = ref<int>(bool);
fn = int(double)(bool);

assert(b == 1);
assert(c == 1);
assert(u == 1);
assert(s == 1);
assert(i == 1);
assert(l == 1);
assert(f == 1);
assert(d == 1);
assert(long(v) == 1);
assert(long(a) == 1);
assert(long(e) == 1);
assert(long(p) == 1);
assert(long(fn) == 1);

b = 253;

c = b;
u = b;
s = b;
i = b;
l = b;
f = b;
d = b;
v = b;
a = address(b);
bool = boolean(b);
e = E(b);
p = ref<int>(b);
fn = int(double)(b);

assert(c == 253);
assert(u == 253);
assert(s == 253);
assert(i == 253);
assert(l == 253);
assert(f == 253);
assert(d == 253);
assert(v == 253);
assert(long(a) == 253);
assert(long(bool) == 253);
assert(long(e) == 253);
assert(long(p) == 253);
assert(long(fn) == 253);

c = 64007;

b = byte(c);
u = c;
s = short(c);
i = c;
l = c;
f = c;
d = c;
v = c;
a = address(c);
bool = boolean(c);
e = E(c);
p = ref<int>(c);
fn = int(double)(c);

assert(b == 7);
assert(u == 64007);
assert(s == -1529);
assert(i == 64007);
assert(l == 64007);
assert(f == 64007);
assert(d == 64007);
assert(v == 64007);
assert(long(a) == 64007);
assert(long(bool) == 7);
assert(long(e) == 7);
assert(long(p) == 64007);
assert(long(fn) == 64007);

u = 3567421900;

b = byte(u);
c = char(u);
s = short(u);
i = int(u);
l = u;
f = u;
d = u;
v = u;
a = address(u);
bool = boolean(u);
e = E(u);

assert(b == 204);
assert(c == 35276);
assert(s == -30260);
assert(i == -727545396);
assert(l == 3567421900);
assert(f == 3567421900);
assert(d == 3567421900);
assert(v == 3567421900);
assert(long(a) == 3567421900);
assert(long(bool) == 204);
assert(long(e) == 204);

s = 24880;

b = byte(s);
c = char(s);
u = unsigned(s);
i = s;
l = s;
f = s;
d = s;
v = s;
a = address(s);
bool = boolean(s);
e = E(s);

assert(b == 48);
assert(c == 24880);
assert(u == 24880);
assert(i == 24880);
assert(l == 24880);
assert(f == 24880);
assert(d == 24880);
assert(v == 24880);
assert(long(a) == 24880);
assert(long(bool) == 48);
assert(long(e) == 48);

i = 1027843991;

b = byte(i);
c = char(i);
u = unsigned(i);
s = short(i);
l = i;
f = i;
d = i;
v = i;
a = address(i);
bool = boolean(i);
e = E(i);
p = ref<int>(i);
fn = int(double)(i);

assert(b == 151);
assert(c == 42903);
assert(u == 1027843991);
assert(s == -22633);
assert(l == 1027843991);
assert(f == 1027843991);
assert(d == 1027843991);
assert(v == 1027843991);
assert(long(a) == 1027843991);
assert(long(bool) == 151);
assert(long(e) == 151);
assert(long(p) == 1027843991);
assert(long(fn) == 1027843991);

l = 9098143217445643188;

b = byte(l);
c = char(l);
u = unsigned(l);
s = short(l);
i = int(l);
f = l;
d = l;
v = l;
a = address(l);
bool = boolean(l);
e = E(l);
p = ref<int>(l);
fn = int(double)(l);

assert(b == 180);
assert(c == 9140);
assert(u == 1601840052);
assert(s == 9140);
assert(i == 1601840052);
assert(f == 9098143217445643188);
assert(d == 9098143217445643188);
assert(v == 9098143217445643188);
assert(long(a) == 9098143217445643188);
assert(long(bool) == 180);
assert(long(e) == 180);
assert(long(p) == 9098143217445643188);
assert(long(fn) == 9098143217445643188);

f = 16121908;

b = byte(f);
c = char(f);
u = unsigned(f);
s = short(f);
i = int(f);
l = long(f);
d = f;
v = f;
a = address(f);
bool = boolean(f);
e = E(f);
p = ref<int>(f);
fn = int(double)(f);

assert(b == 52);
assert(c == 52);
assert(u == 16121908);
assert(s == 52);
assert(i == 16121908);
assert(f == 16121908);
assert(d == 16121908);
assert(float(v) == 16121908);
assert(long(a) == 16121908);
assert(long(bool) == 52);
assert(long(e) == 52);
assert(long(p) == 16121908);
assert(long(fn) == 16121908);

d = 2632372374184627;

b = byte(d);
c = char(d);
u = unsigned(d);
s = short(d);
i = int(d);
l = long(d);
f = float(d);
v = d;
a = address(d);
bool = boolean(d);
e = E(d);
p = ref<int>(d);
fn = int(double)(d);

assert(b == 179);
assert(c == 41651);
assert(u == 4098335411);
assert(s == -23885);
assert(i == -196631885);
assert(l == 2632372374184627);
assert(f == 2632372374184627);
assert(double(v) == 2632372374184627);
assert(long(a) == 2632372374184627);
assert(long(bool) == 179);
assert(long(e) == 179);
assert(long(p) == 2632372374184627);
assert(long(fn) == 2632372374184627);

e = e.C;

b = byte(e);
c = char(e);
u = unsigned(e);
s = short(e);
i = int(e);
l = long(e);
f = float(e);
d = double(e);
//v = e;
a = address(e);
bool = boolean(e);
p = ref<int>(e);
fn = int(double)(e);

assert(b == 2);
assert(c == 2);
assert(u == 2);
assert(s == 2);
assert(i == 2);
assert(l == 2);
assert(f == 2);
assert(d == 2);
//assert(v == 2);
assert(long(a) == long(e.C));
assert(long(bool) == 2);
assert(long(p) == long(e.C));
assert(long(fn) == long(e.C));



