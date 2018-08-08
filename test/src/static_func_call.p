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

boolean got1, got2, got3;

void(int) x;

monitor class C {
	void method() {
		func(1);
		x = func;
		lock (*this) {
			g(func);
		}
	}

	private static void func(int a) {
		if (a == 1)
			got1 = true;
		else if (a == 2)
			got2 = true;
		else if (a == 3)
			got3 = true;
		else {
			printf("Unexpected value of a: %d\n", a);
			assert(false);
		}
	}
}

C c;

c.method();

void g(void(int) f) {
	f(2);
}

x(3);

assert(got1);
assert(got2);
assert(got3);

printf("SUCCESS\n");

