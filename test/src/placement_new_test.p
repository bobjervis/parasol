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

class X {
	int _left;
	int _right;
	
	X(int pattern) {
		_left = pattern;
		_right = pattern;
	}
}

long a;

new (&a) X(0x11223344);

assert(a == 0x1122334411223344);

int[] n = [ 1, 2, 3, 4 ];

pointer<int> x = &n[0];

int i = 2;
ref<double> f = new (&x[i]) double;
*f = 0.7;

assert(n[0] == 1);
assert(n[1] == 2);
assert(n[2] != 3);
assert(n[3] != 4);

assert(*f == 0.7);

int[] m = [ 1, 2, 3, 4 ];

pointer<int> z = &m[0];

ref<ref<int>> ff = new (&z[i]) ref<int>;
*ff = &i;

assert(m[0] == 1);
assert(m[1] == 2);
assert(m[2] != 3);
assert(m[3] != 4);

assert(*ff == &i);

