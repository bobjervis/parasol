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
int x;
boolean y;

(x, y) = f();

printf("x: %d y: %s\n", x, y ? "true" : "false");
assert(x == 5);
assert(!y);

int, boolean f() {
	return 5, false;
}


string s;
boolean b;

printf("sf():\n");
(s, b) = sf();
printf("called\n");
string, boolean sf() {
	return "top", true;
}

assert(s == "top");
assert(b);
