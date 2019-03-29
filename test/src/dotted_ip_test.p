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
import parasol:net;

unsigned x;
boolean success;

(x, success) = net.parseDottedIP("123.45.67.89");
assert(success);
printf("x = %x\n", x);
assert(x == 0x59432d7b);

assert(net.dottedIP(x) == "123.45.67.89");

(x, success) = net.parseDottedIP("123.45.67");
assert(!success);

(x, success) = net.parseDottedIP("12345.67.89.12");
assert(!success);
