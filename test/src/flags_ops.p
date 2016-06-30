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
flags A {
	B, C, D, E
}

int main(string[] args) {
	A a = A.B;
	A b = A.C;
	A c = A.D;
	A d = A.E;

	// All of these expressions should be true (given the above)

	assert(a == a);
	assert(a != b);
	assert(c == A.D);
	
	assert((a | b) == (A.B|A.C));
	assert((b | a) == (A.B|A.C));
	assert((a ^ b) == (A.B|A.C));
	assert((b ^ a) == (A.B|A.C));
	assert((a & c) == 0);

	// Assigning a value should make the result variable equal to the source

	assert(d != a);
	d = a;
	assert(d == a);

	// Or'ing in true should make the result true

	d = A.E;
	d |= a;
	assert(d == (A.B|A.E));

	d = A.E;
	d |= b;
	assert(d == (A.C|A.E));

	d = A.E;
	d ^= a;
	assert(d == (A.B|A.E));

	d = A.E;
	d ^= b;
	assert(d == (A.C|A.E));

	d = A.E;
	d &= a;
	assert(d == 0);

	d = A.E;
	assert((d |= a) == (A.B|A.E));

	d = A.E;
	assert((d |= b) == (A.C|A.E));

	d = A.E;
	assert((d ^= a) == (A.B|A.E));

	d = A.E;
	assert((d ^= b) == (A.C|A.E));

	d = A.E;
	assert((d &= a) == 0);

	d = A.E;
	assert(~d == (A.B|A.C|A.D));

	assert(func(d) == A.E);
	
	assert(!(d & A.D));

	assert(d & A.D || a & A.B);
	assert(d & A.E || a & A.C);
	assert(!(d & A.D || a & A.C));
	assert(d & A.E && a & A.B);
	assert(!(d & A.D && a & A.B));
	assert(!(d & A.E && a & A.C));
	return 0;
}

A func(A flagsParam) {
	return flagsParam;
}
