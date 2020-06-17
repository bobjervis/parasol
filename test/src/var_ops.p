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
import parasol:time.Time;

basicIntegerArithmetic();
basicStringOps();
conversions();
subscripting();
multiReturns();
constructors();

void basicIntegerArithmetic() {
	var a = 1;
	var b = 0;
	var c = 35;
	var d = 17;

	// All of these expressions should be true (given the above)

	assert(a == a);
	assert(a > b);
	assert(b <= a);
	assert(a != b);
	assert(c == 35);
	assert(b >= 0);
	assert(a <> 7);
	assert(a !<> 1);
	assert(d < 100);
	assert(c !< 35);
	assert(c !< 30);
	assert(d !> 20);
	assert(b !>= 4);
	assert(a !<= 0);
	
	assert((a | b) == 1);
	assert((b | a) == 1);
	assert((a ^ b) == 1);
	assert((b ^ a) == 1);
	assert((a & c) == 1);
	assert(a * c == 35);
	assert(a / c == 0);
	assert(c / d == 2);
	assert(c % d == 1);
	assert(a + d == 18);
	assert(c - d == 18);
	assert(d - c < 0);
	assert(d >> a == 8);
	assert(d << a == 34);
	assert(d >>> a == 8);

	// Assigning a value should make the result variable equal to the source

	assert(d != a);
	assert(d <> a);
	d = a;
	assert(d == a);
	assert(d !<> a);

	// Or'ing in 1 should make the result the same

	d = 17;
	d |= a;
	assert(d == 17);

	d = 17;
	d |= b;
	assert(d == 17);

	d = 17;
	d ^= a;
	assert(d == 16);

	d = 17;
	d ^= b;
	assert(d == 17);

	d = 17;
	d &= a;
	assert(d == 1);

	d = 17;
	d += a;
	assert(d == 18);

	d = 17;
	d -= a;
	assert(d == 16);

	d = 17;
	d *= 3;
	assert(d == 51);

	d = 17;
	d /= 3;
	assert(d == 5);

	d = 17;
	d %= 5;
	assert(d == 2);

	d = 17;
	d <<= 3;
	assert(d == 0x88);

	d = 17;
	d >>= 1;
	assert(d == 8);

	d = 17;
	d >>>= 1;
	assert(d == 8);

	d = 17;
	assert((d |= a) == 17);

	d = 17;
	assert((d |= b) == 17);

	d = 17;
	assert((d ^= a) == 16);

	d = 17;
	assert((d ^= b) == 17);

	d = 17;
	assert((d &= a) == 1);

	d = 17;
	assert((d += a) == 18);

	d = 17;
	assert((d -= a) == 16);

	d = 17;
	assert((d *= 3) == 51);

	d = 17;
	assert((d /= 3) == 5);

	d = 17;
	assert((d %= 5) == 2);

	d = 17;
	assert((d <<= 3) == 0x88);

	d = 17;
	assert((d >>= 1) == 8);

	d = 17;
	assert((d >>>= 1) == 8);

	assert(func(d) == 8);
}

var func(var p) {
	return p;
}

void basicStringOps() {
	var a;
	var b;
	var c;
	
	a = "sample";
	b = " stuff";
	c = a + b;
	assert(a == "sample");
	assert(b != "something else");
	printf(string(c));
	assert(c == "sample stuff");
	assert(a + b == "sample stuff");
	var f = "xx";
//	assert(f.length() == 2);
//	int x = int(f.printf("%s %d:", a, 35));
//	assert(f == "xxsample 35:");
//	assert(f.length() == 12);
//	assert(x == 10);
}

void conversions() {
	var f = "xx";
	printf("conversions\n");
	string s = string(f);
	assert(s == "xx");
	char c = 'g';
	var x = c;
	char c2 = char(x);
	assert(c2 == c);
	pointer<byte> cp = s.c_str();
	var y = cp;
	pointer<byte> xp = pointer<byte>(y);
	assert(cp == xp);
	assert(isBytePointer(y));
	assert(!isBytePointer(x));
	assert(!isBytePointer(f));

	Time t(17);

	var vt = t;

	Time tx = Time(vt);

	assert(tx.value() == 17);
}

boolean isBytePointer(var v) {
	return v.class == pointer<byte>;
}

void subscripting() {
	var[] array;
	
	for (int i = 0; i < 10; i++)
		array.append(i + 5);
	assert(array.length() == 10);
	for (int i = 0; i < 10; i++)
		assert(array[i] == i + 5);
}

void multiReturns() {
	var a;
	boolean b;
	(a, b) = test2();
	assert(a == 5);
	assert(!b);
	var c;
	boolean d;
	(c, d) = test1();
	assert(c == 5);
	assert(!d);
}

var, boolean test1() {
	return test2();
}

var, boolean test2() {
	var x = 5;
	boolean y = true;
	assert(x == 5);
	return x, !y;
}

void constructors() {
	long x = 7;
	var source = &x;
	var y;
	new (&y) var(source);
	ref<long> z = ref<long>(y);
	assert(z == &x);
}

