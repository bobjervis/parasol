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
int[] a, b;

a.append(3);
a.append(17);
a.append(23);

b = a;

assert(b.length() == 3);
assert(b[2] == 23);
assert(b[1] == 17);
assert(b[0] == 3);

int[] c;

c = -a;

assert(c.length() == 3);
assert(c[0] == -3);
assert(c[1] == -17);
assert(c[2] == -23);

a.append(44);

c = +a;

assert(c.length() == 4);
assert(c[0] == 3);
assert(c[1] == 17);
assert(c[2] == 23);
assert(c[3] == 44);

int[] d;

d = ~a;

assert(d.length() == 4);
assert(d[0] == ~3);
assert(d[1] == ~17);
assert(d[2] == ~23);
assert(d[3] == ~44);

boolean[] boo;

boo.append(true);
boo.append(true);
boo.append(false);

boolean[] far;

far = !boo;

assert(far.length() == 3);
assert(far[0] == false);
assert(far[1] == false);
assert(far[2] == true);
