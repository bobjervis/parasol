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
monitor class M {
}

class A extends M {

private static string concat(string a, string b, int x) {
	string c(x);
	return a + b + c;
}

	void f() {
		string n;
		int i = 50;

		lock (*this) {
			n = concat("ab", "c", i);
		}
		assert(n == "abc50");

		string m;

		m = concat(n, "--", -3);

		printf("m = '%s'\n", m);
		assert(m == "abc50---3");
	}
}

A x;

x.f();

