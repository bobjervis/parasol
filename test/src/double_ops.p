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
int main(string[] args) {
	printf("Test of double operations.\n");
	double a = 1;
	double b = 0;
	double c = 35;
	double d = 17;

	double NaN = b / b;
	
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
	assert(a <>= b);
	assert(a !<>= NaN);
	
	assert(a * c == 35);
	assert(c / 5 == 7);
	assert(34 / d == 2);
	assert(a + d == 18);
	assert(c - d == 18);
	assert(d - c < 0);
	
	// Assigning a value should make the result variable equal to the source

	assert(d != a);
	assert(d <> a);
	d = a;
	assert(d == a);
	assert(d !<> a);

	d = 17;
	d += a;
	assert(d == 18);

	d = 17;
	d -= a;
	assert(d == 16);

	d = 17;
	d *= 3;
	assert(d == 51);

	d = 15;
	d /= 3;
	assert(d == 5);

	d = 17;
	assert((d += a) == 18);

	d = 17;
	assert((d -= a) == 16);

	d = 17;
	assert((d *= 3) == 51);

	d = 15;
	assert((d /= 3) == 5);

	d = 17;
	assert(+d == 17);
	assert(-d == -17);
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
	
	d = 5.0;
	
	assert(d * 2.5 == 12.5);
	
	return 0;
}

double func(double p) {
	return p;
}
