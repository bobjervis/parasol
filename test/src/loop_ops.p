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
int[] a = [ 17, 2300, -45, 1007001 ];

boolean case0, case1, case2, case3;

for (i in a) {
	switch (i) {
	case	0:
		assert(a[i] == 17);
		assert(!case0);
		assert(!case1);
		assert(!case2);
		assert(!case3);
		case0 = true;
		break;

	case	1:
		assert(a[i] == 2300);
		assert(case0);
		assert(!case1);
		assert(!case2);
		assert(!case3);
		case1 = true;
		break;

	case	2:
		assert(a[i] == -45);
		assert(case0);
		assert(case1);
		assert(!case2);
		assert(!case3);
		case2 = true;
		break;

	case	3:
		assert(a[i] == 1007001);
		assert(case0);
		assert(case1);
		assert(case2);
		assert(!case3);
		case3 = true;
		break;

	default:
		assert(false);
	}
}

assert(case0);
assert(case1);
assert(case2);
assert(case3);

string[string] m;

m["abc"] = "def";
m["ghi"] = "jkl";
m["mno"] = "pqr";
m["stu"] = "vwx";

case0 = false;
case1 = false;
case2 = false;
case3 = false;

for (i in m) {
	switch (i) {
	case "abc":
		assert(!case0);
		assert(m[i] == "def");
		case0 = true;
		break;

	case "ghi":
		assert(!case1);
		assert(m[i] == "jkl");
		case1 = true;
		break;

	case "mno":
		assert(!case2);
		assert(m[i] == "pqr");
		case2 = true;
		break;

	case "stu":
		assert(!case3);
		assert(m[i] == "vwx");
		case3 = true;
		break;

	default:
		assert(false);
	}
}

assert(case0);
assert(case1);
assert(case2);
assert(case3);

