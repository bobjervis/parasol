int main(string[] args) {
	unsigned a = 1;
	unsigned b = 0;
	unsigned c = 35;
	unsigned d = 17;
	int ia = 1;

	// All of these expressions should be true (given the above)

	assert(a == a);
	assert(a > b);
	assert(b <= a);
	assert(a != b);
	assert(c == 35);
	assert(b >= 0);
	assert(d >= 11);
	assert(a <> 7);
	assert(a !<> 1);
	assert(d < 100);
	assert(c !< 35);
	assert(c !< 30);
	assert(d !> 20);
	assert(b !>= 4);
	assert(c !<= 30);
	
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
	assert(d - c > 0);

	assert(d >> ia == 8);
	assert(d << ia == 34);
	assert(d >>> ia == 8);

	// Assigning a value should make the result variable equal to the source

	assert(d != a);
	assert(d <> a);
	d = a;
	assert(d == a);
	assert(d !<> a);

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
	assert(-d == 0xffffffef);
	assert(~d == 0xffffffee);
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
	
	assert(unsigned.MAX_VALUE == 0xffffffff);
	
	assert(unsigned.MIN_VALUE == 0x00000000);
	return 0;
}

unsigned func(unsigned p) {
	return p;
}
