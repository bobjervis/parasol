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
	int m;

	void verify(int value) {
		assert(m == value);
	}
}

monitor class N extends M {
	int n;

	void verifyN(int value) {
		assert(n == value);
	}
}

class C extends M {
	int x;
}

M a;
N b;
C c;

lock (a) {
	m = 3;
}

a.verify(3);

lock (b) {
	m = 2;
	n = 7;
}

b.verify(2);
b.verifyN(7);

lock (c) {
	m = 4;
	x = 3;
}

c.x++;

c.verify(4);

assert(c.x == 4);
