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
import parasol:text.Character;

int main(string[] args) {
	char a = 1;
	char b = 0;
	char c = 35;
	char d = 17;

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

	d = 17;
	assert(+d == 17);
	assert(-d == char(0xffef));
	assert(~d == char(0xffee));
	assert(++d == 18);

	d = 17;
	assert(--d == 16);

	d = 17;
	assert(d++ == 17);
	assert(d == 18);

	d = 17;
	assert(d-- == 17);
	assert(d == 16);

	d = 17;
	assert(func(d) == 17);
	
	classificationTest();
	return 0;
}

char func(char p) {
	return p;
}

void classificationTest() {
	for (byte b = byte.MIN_VALUE; b < byte.MAX_VALUE; b++) {
		boolean expected = b == ' ' || b == '\t' || b == '\n' || b == '\r' || b == '\v';
		boolean actual = Character.isSpace(b);
		assert(expected == actual);
	}
	byte b = byte.MAX_VALUE;
	boolean expected = b == ' ' || b == '\t' || b == '\n' || b == '\r' || b == '\v';
	boolean actual = Character.isSpace(b);
	assert(expected == actual);
}
