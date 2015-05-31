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
