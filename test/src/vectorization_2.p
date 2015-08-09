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

int[] a, b;

a.append(100);
a.append(45);
a.append(-23503);

b.append(37);
b.append(0);
b.append(44);
b.append(116);

int[] d;

d = a + b;

assert(d.length() == 4);
assert(d[0] == 137);
assert(d[1] == 45);
assert(d[2] == -23459);
assert(d[3] == 216);

d.clear();

d = a - b;

assert(d.length() == 4);
assert(d[0] == 63);
assert(d[1] == 45);
assert(d[2] == -23547);
assert(d[3] == -16);

d.clear();

d = a * b;

assert(d.length() == 4);
assert(d[0] == 3700);
assert(d[1] == 0);
assert(d[2] == 23503 * -44);
assert(d[3] == 11600);

d.clear();

d = b / a;		// b contains a zero, a no no in integer arithmetic

assert(d.length() == 4);
assert(d[0] == 0);
assert(d[1] == 0);
assert(d[2] == 44 / -23503);
assert(d[3] == 1);

d.clear();

d = b % a;		// b contains a zero, a no no in integer arithmetic

assert(d.length() == 4);
assert(d[0] == 37);
assert(d[1] == 0);
assert(d[2] == 44 % -23503);
assert(d[3] == 16);

d.clear();

d = a & b;

assert(d.length() == 4);
assert(d[0] == (100 & 37));
assert(d[1] == 0);
assert(d[2] == (-23503 & 44));
assert(d[3] == (116 & 100));

d.clear();

d = a | b;

assert(d.length() == 4);
assert(d[0] == (100 | 37));
assert(d[1] == 45);
assert(d[2] == (-23503 | 44));
assert(d[3] == (116 | 100));

d.clear();

d = a ^ b;

assert(d.length() == 4);
assert(d[0] == (100 ^ 37));
assert(d[1] == 45);
assert(d[2] == (-23503 ^ 44));
assert(d[3] == (116 ^ 100));

int[] shift;

shift.append(1);
shift.append(0);
shift.append(2);
shift.append(3);

d = a >> shift;

assert(d.length() == 4);
printf("%d %d %d %d\n", d[0], d[1], d[2], d[3]);
assert(d[0] == 50);
assert(d[1] == 45);
assert(d[2] == (-23503 >> 2));
assert(d[3] == 12);
