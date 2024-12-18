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

ref<int> x;

assert(x.bytes == 8);

pointer<byte> start, end;

byte y;

start = pointer<byte>(&y);
end = pointer<byte>(&y) + 3;

printf("Byte pointer difference test:\n");
assert(end - start == 3); 

pointer<int> sL, eL;

sL = pointer<int>(&x);
eL = pointer<int>(&x) + 3;

printf("Int pointer difference test:\n");

assert(eL - sL == 3); 

assert(pointer<byte>(eL) - pointer<byte>(sL) == 3 * int.bytes);

printf("Increment/decrement tests:\n");
sL++;

assert(eL - sL == 2);

eL--;

assert(eL - sL == 1);

sL += 2;

assert(eL - sL == -1);

sL -= 2;

assert(eL - sL == 1);

printf("Basic pointer arithmetic confirmed.\n");

boolean coerceTest1(address data) {
	ref<boolean> resultp = ref<boolean>(data);
	return *resultp;
}

boolean coerceFlag1 = true;
boolean coerceFlag2 = false;

assert(coerceTest1(&coerceFlag1));
assert(!coerceTest1(&coerceFlag2));

printf("Coercion tests passed.\n");

ref<byte> bp;

assert(bp == ref<byte>(0));

printf("Null pointer initialization test passed.\n");

address retAddress(ref<int> p) {
	return p;
}

assert(sL == retAddress(sL));

ref<int> xp = sL;

printf("pointer -> ref conversion test passed.\n");

pointer<int> arrayElemPtr;

int[] a;

a.append(3);
a.append(4);

printf("Array constructed.\n");

arrayElemPtr = &a[1];

assert(*arrayElemPtr == 4);
assert(arrayElemPtr[-1] == 3);

printf("Array contents confirmed via pointers.\n");

ff();

printf("Pointer tests passed.\n");

void ff() {
	byte b = 3;

	ref<byte> bp = &b;

	boolean a = true;

	ref<ref<byte>> bpp = a ? &bp : null;

	assert(bpp != null);
	assert(*bpp == bp);
	assert(**bpp == 3);
}

address xcvt;

long xl = long(xcvt);

pointer<byte> pb = pointer<byte>(&y);

xl = long(pb);

assert(xl == long(&y));

string s = "abcdef";

pointer<byte> cp = &s[2];

assert(*cp == 'c');
assert(*++cp == 'd');
assert(*cp++ == 'd');
assert(*cp == 'e');
assert(*--cp == 'd');
assert(*cp-- == 'd');
assert(*cp == 'c');

// This following text was introduced because of a codegen assertion.

class P<class I, class E> {
	pointer<I> x;

	E m() {
		long i = 0;
		E r = *x[E(i)];
		return r;
	}
}

P<ref<int>, int> pp;

int ppn = 17;
pp.x = pointer<ref<int>>(new ref<int>);
*pp.x = &ppn;

assert(pp.m() == 17);
