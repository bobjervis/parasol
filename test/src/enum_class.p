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

boolean destructorsAllowed;

enum A {
	B(1, "xyz"),
	C(4, "abc"),
	D;

	private int _x;
	private string _y;

	A(int x, string y) {
		_x = x;
		_y = y;
	}

	A() {
		_x = 7;
	}

	~A() {
		assert(destructorsAllowed);
	}

	boolean isHappy() {
		printf("this = %p _x = %d\n", this, _x);
		if (_x > 2)
			return true;
		else
			return false;
	}
}

assert(!A.B.isHappy());
assert(A.C.isHappy());
assert(A.D.isHappy());

void f() {
	A b = A.B;
	
	assert(!b.isHappy());
	
	A c = A.C;
	
	assert(c.isHappy());
}

f();

destructorsAllowed = true;				// Relying on the fact that static lifetimes of boolean's last to process
										// termination.

A[] array;

array.append(A.B);
array.append(A.D);

int x = 0;

assert(!array[x].isHappy());
assert(array[x + 1].isHappy());
