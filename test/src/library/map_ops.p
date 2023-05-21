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
string[string] testMap;

assert(testMap["anything"] == null);

testMap["abc"] = "xyz";

testMap["def"] = "mno";

assert(testMap["abc"] == "xyz");

int[string] intMap;

intMap["abc"] = 1;

intMap["def"] = 34;

assert(intMap["abc"] == 1);

enum Enum {
	A, B, C
}

Enum[string] m2;

m2["a"] = Enum.A;
m2["b"] = Enum.B;
m2["c"] = Enum.C;

assert(m2["b"] == Enum.B);

assert(m2["e"] == null);
