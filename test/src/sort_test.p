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

int[] x = [ 1, 23, 5, 99, -4, 6 ];

x.sort();

assert(x.length() == 6);

printf("x = [ %d, %d, %d, %d, %d, %d ]\n", x[0], x[1], x[2], x[3], x[4], x[5]);

assert(x[0] == -4);
assert(x[1] == 1);
assert(x[2] == 5);
assert(x[3] == 6);
assert(x[4] == 23);
assert(x[5] == 99);

int[] y = [ 1, 23, 5, 99, -4, 6 ];

y.sort(false);

assert(y.length() == 6);

printf("y = [ %d, %d, %d, %d, %d, %d ]\n", y[0], y[1], y[2], y[3], y[4], y[5]);

assert(y[0] == 99);
assert(y[1] == 23);
assert(y[2] == 6);
assert(y[3] == 5);
assert(y[4] == 1);
assert(y[5] == -4);

int[] z = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19 ];

z.sort();

assert(z.length() == 18);

printf("z = [ %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d ]\n", z[0], z[1], z[2], z[3], z[4], z[5], z[6], z[7], z[8], z[9], z[10], z[11], z[12], z[13], z[14], z[15], z[16], z[17]);

assert(z[0] == 1);
assert(z[1] == 2);
assert(z[2] == 3);
assert(z[3] == 4);
assert(z[4] == 5);
assert(z[5] == 6);
assert(z[6] == 7);
assert(z[7] == 8);
assert(z[8] == 9);
assert(z[9] == 10);
assert(z[10] == 11);
assert(z[11] == 12);
assert(z[12] == 13);
assert(z[13] == 14);
assert(z[14] == 15);
assert(z[15] == 16);
assert(z[16] == 18);
assert(z[17] == 19);

