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

