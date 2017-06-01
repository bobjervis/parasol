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

int[] a = [ 1, 2, 33, 7, ];

assert(a.length() == 4);
assert(a[0] == 1);
assert(a[1] == 2);
assert(a[2] == 33);
assert(a[3] == 7);

int[string] x = [ "abc": 3, "def": -17, "ghi": 44 ];

assert(x.size() == 3);

assert(x["def"] == -17);
assert(x["abc"] == 3);
assert(x["ghi"] == 44);
assert(x["ABC"] == 0);

enum E { A, B, C, D }

int[E] xe;

printf("xe length = %d\n", int(xe.length()));

int[E] foo = [ B: 45, 17 ];

printf("foo length = %d\n", int(foo.length()));

assert(foo.length() == E.D);
assert(foo[E.C] == 17);
assert(foo[E.A] == 0);
assert(foo[E.B] == 45);
assert(foo[E.D] == 0);


