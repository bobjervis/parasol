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
// This was a code gen bug caused when the temps created in the first call to f were not cleaned up right away,
// nor were they cleaned up at the break (so that case 1 wouldn't blow up

string[] a = [ "rtww", "xx", "w" ];

for (int i = 0; i < 2; i++) {
	switch (i) {
	case	0:
		if (i > 0)
			continue;
		string g = "sxxrtww";
		int b = f(a[0], a[1], a[2]);	// The declaration is important, it means the temps didn't get destroyed. 
		break;

	case	1:
		g = "xxaa";
		f("rtww", string(g, 0, 2), "w"); 
		break;			// On second iteration, temps generated for function arguments above got double freed.
	}
}

int f(string x, string y, string z) {
	assert(x == "rtww");
	assert(y == "xx");
	assert(z == "w");
	return 0;
}

boolean destructorCalled;

class A {
	int x;

	A(int z) {
		x = z;
	}

	~A() {
		destructorCalled = true;
	}
}

for (int i = 0; i < 3; i++) {
	switch (i) {
	case 0:
		A a(45);

		assert(a.x == 45);
		assert(!destructorCalled);
		break;

	case 1:
		assert(destructorCalled);
		destructorCalled = false;
		break;

	case 2:
		assert(!destructorCalled);
	}
}
assert(!destructorCalled);
printf("PASSED\n");


