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
class Base {
	int foo() {
		return 1;
	}
}

class D1 extends Base {
	int foo() {
		return 2;
	}
}

class D2 extends Base {
	int foo() {
		return 3;
	}
}

class D3 extends D2 {
	int foo() {
		return 4;
	}
}

assert(Base > D1);
assert(Base > D2);
assert(Base > D3);
assert(D2 > D3);
if (D1 > D2)
	assert(false);
if (D1 > Base)
	assert(false);

assert(D1 < Base);
assert(D2 < Base);
assert(D2 < Base);
assert(D3 < D2);
if (D1 < D2)
	assert(false);
if (Base < D1)
	assert(false);

assert(Base >= Base);
assert(D1 >= D1);
assert(D2 >= D2);
assert(D3 >= D3);
assert(Base >= D1);
assert(Base >= D2);
assert(Base >= D3);
assert(D2 >= D3);
if (D1 >= D2)
	assert(false);
if (D2 >= Base)
	assert(false);

assert(Base <= Base);
assert(D1 <= D1);
assert(D2 <= D2);
assert(D3 <= D3);
assert(D1 <= Base);
assert(D2 <= Base);
assert(D2 <= Base);
assert(D3 <= D2);
if (D1 <= D2)
	assert(false);

assert(Base == Base);
assert(D1 == D1);
assert(D2 == D2);
assert(D3 == D3);
if (D1 == D2)
	assert(false);

assert(Base <> D1);
assert(Base <> D2);
assert(Base <> D3);
assert(D1 <> Base);
assert(D2 <> Base);
assert(D3 <> Base);
assert(D2 <> D3);
assert(D3 <> D2);
if (D1 <> D2)
	assert(false);

assert(Base <>= Base);
assert(D1 <>= D1);
assert(D2 <>= D2);
assert(D2 <>= Base);
assert(Base <>= D2);
assert(D3 <>= D3);
assert(Base <>= D1);
assert(Base <>= D2);
assert(Base <>= D3);
assert(D1 <>= Base);
assert(D2 <>= Base);
assert(D3 <>= Base);
assert(D2 <>= D3);
assert(D3 <>= D2);
if (D1 <>= D2)
	assert(false);

assert(D1 !> D2);
assert(Base !> Base);
assert(D3 !> Base);
if (Base !> D1)
	assert(false);

assert(D2 !< D1);
assert(D3 !< D3);
assert(D2 !< D3);
assert(Base !< D2);
if (D1 !< Base)
	assert(false);

assert(D1 !>= D2);
assert(D3 !>= Base);
if (D1 !>= D1)
	assert(false);
if (Base !>= D1)
	assert(false);

assert(D2 !<= D1);
assert(D2 !<= D3);
assert(Base !<= D2);
if (Base !<= Base)
	assert(false);
if (D1 !<= Base)
	assert(false);

assert(D1 != D2);
assert(Base != D3);
if (Base != Base)
	assert(false);

assert(D1 !<> D2);
assert(Base !<> int);
assert(Base !<> Base);
if (Base !<> D1)
	assert(false);
if (D1 !<> Base)
	assert(false);

assert(D1 !<>= D2);
assert(Base !<>= int);
if (Base !<>= D1)
	assert(false);
