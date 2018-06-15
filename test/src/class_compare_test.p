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
class Cbool {
	int x;

	Cbool(int n) {
		x = n;
	}

	boolean compare(ref<Cbool> other) {
		return x == other.x;
	}
}

Cbool cbool1(1);
Cbool cbool2(2);

assert(cbool1 == cbool1);
if (cbool1 == cbool2)
	assert(false);
assert(cbool1 != cbool2);
if (cbool1 != cbool1)
	assert(false);

class Cbyte {
	int x;

	Cbyte(int n) {
		x = n;
	}

	byte compare(ref<Cbyte> other) {
		if (x == other.x)
			return 0;
		else
			return 1;
	}
}

Cbyte cbyte1(1);
Cbyte cbyte2(2);

assert(cbyte1 == cbyte1);
if (cbyte1 == cbyte2)
	assert(false);
assert(cbyte1 != cbyte2);
if (cbyte1 != cbyte1)
	assert(false);

class Cchar {
	int x;

	Cchar(int n) {
		x = n;
	}

	char compare(ref<Cchar> other) {
		if (x == other.x)
			return 0;
		else
			return 1;
	}
}

Cchar cchar1(1);
Cchar cchar2(2);

assert(cchar1 == cchar1);
if (cchar1 == cchar2)
	assert(false);
assert(cchar1 != cchar2);
if (cchar1 != cchar1)
	assert(false);

class Cunsigned {
	int x;

	Cunsigned(int n) {
		x = n;
	}

	unsigned compare(ref<Cunsigned> other) {
		if (x == other.x)
			return 0;
		else
			return 1;
	}
}

Cunsigned cunsigned1(1);
Cunsigned cunsigned2(2);

assert(cunsigned1 == cunsigned1);
if (cunsigned1 == cunsigned2)
	assert(false);
assert(cunsigned1 != cunsigned2);
if (cunsigned1 != cunsigned1)
	assert(false);

class Cshort {
	int x;

	Cshort(int n) {
		x = n;
	}

	short compare(ref<Cshort> other) {
		if (x == other.x)
			return 0;
		else if (x < other.x)
			return short(-1);
		else
			return 1;
	}
}

Cshort cshort1(1);
Cshort cshort2(2);

assert(cshort1 == cshort1);
if (cshort1 == cshort2)
	assert(false);
assert(cshort1 != cshort2);
if (cshort1 != cshort1)
	assert(false);
assert(cshort1 < cshort2);
if (cshort1 < cshort1)
	assert(false);
assert(cshort1 <= cshort2);
if (cshort2 <= cshort1)
	assert(false);
assert(cshort2 > cshort1);
if (cshort1 > cshort2)
	assert(false);
assert(cshort2 >= cshort1);
if (cshort1 >= cshort2)
	assert(false);
assert(cshort1 <> cshort2);
if (cshort1 <> cshort1)
	assert(false);
assert(cshort1 !> cshort2);
if (cshort2 !> cshort1)
	assert(false);
assert(cshort1 !>= cshort2);
if (cshort2 !>= cshort1)
	assert(false);
assert(cshort2 !< cshort1);
if (cshort1 !< cshort2)
	assert(false);
assert(cshort2 !<= cshort1);
if (cshort1 !<= cshort2)
	assert(false);
assert(cshort1 !<> cshort1);
if (cshort1 !<> cshort2)
	assert(false);

class Cint {
	int x;

	Cint(int n) {
		x = n;
	}

	int compare(ref<Cint> other) {
		if (x == other.x)
			return 0;
		else if (x < other.x)
			return -1;
		else
			return 1;
	}
}

Cint cint1(1);
Cint cint2(2);

assert(cint1 == cint1);
if (cint1 == cint2)
	assert(false);
assert(cint1 != cint2);
if (cint1 != cint1)
	assert(false);
assert(cint1 < cint2);
if (cint1 < cint1)
	assert(false);
assert(cint1 <= cint2);
if (cint2 <= cint1)
	assert(false);
assert(cint2 > cint1);
if (cint1 > cint2)
	assert(false);
assert(cint2 >= cint1);
if (cint1 >= cint2)
	assert(false);
assert(cint1 <> cint2);
if (cint1 <> cint1)
	assert(false);
assert(cint1 !> cint2);
if (cint2 !> cint1)
	assert(false);
assert(cint1 !>= cint2);
if (cint2 !>= cint1)
	assert(false);
assert(cint2 !< cint1);
if (cint1 !< cint2)
	assert(false);
assert(cint2 !<= cint1);
if (cint1 !<= cint2)
	assert(false);
assert(cint1 !<> cint1);
if (cint1 !<> cint2)
	assert(false);

class Clong {
	int x;

	Clong(int n) {
		x = n;
	}

	long compare(ref<Clong> other) {
		if (x == other.x)
			return 0;
		else if (x < other.x)
			return -1;
		else
			return 1;
	}
}

Clong clong1(1);
Clong clong2(2);

assert(clong1 == clong1);
if (clong1 == clong2)
	assert(false);
assert(clong1 != clong2);
if (clong1 != clong1)
	assert(false);
assert(clong1 < clong2);
if (clong1 < clong1)
	assert(false);
assert(clong1 <= clong2);
if (clong2 <= clong1)
	assert(false);
assert(clong2 > clong1);
if (clong1 > clong2)
	assert(false);
assert(clong2 >= clong1);
if (clong1 >= clong2)
	assert(false);
assert(clong1 <> clong2);
if (clong1 <> clong1)
	assert(false);
assert(clong1 !> clong2);
if (clong2 !> clong1)
	assert(false);
assert(clong1 !>= clong2);
if (clong2 !>= clong1)
	assert(false);
assert(clong2 !< clong1);
if (clong1 !< clong2)
	assert(false);
assert(clong2 !<= clong1);
if (clong1 !<= clong2)
	assert(false);
assert(clong1 !<> clong1);
if (clong1 !<> clong2)
	assert(false);

class Cfloat {
	int x;

	Cfloat(int n) {
		x = n;
	}

	float compare(ref<Cfloat> other) {
		if (x == int.MAX_VALUE)
			return float.NaN;
		if (x == other.x)
			return 0;
		else if (x < other.x)
			return -1;
		else
			return 1;
	}
}

Cfloat cfloat1(1);
Cfloat cfloat2(2);

assert(cfloat1 == cfloat1);
if (cfloat1 == cfloat2)
	assert(false);
assert(cfloat1 != cfloat2);
if (cfloat1 != cfloat1)
	assert(false);

class Cdouble {
	int x;

	Cdouble(int n) {
		x = n;
	}

	double compare(ref<Cdouble> other) {
		if (x == int.MAX_VALUE)
			return double.NaN;
		if (x == other.x)
			return 0;
		else if (x < other.x)
			return -1;
		else
			return 1;
	}
}

Cdouble cdouble1(1);
Cdouble cdouble2(2);

assert(cdouble1 == cdouble1);
if (cdouble1 == cdouble2)
	assert(false);
assert(cdouble1 != cdouble2);
if (cdouble1 != cdouble1)
	assert(false);






