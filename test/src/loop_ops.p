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
import parasol:json;

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

ref<Object> florp = {
	a: 17,
	b: "hello world",
	c: [
		23,
		37.5,
		null
	]
};

boolean aSeen, bSeen, cSeen;

for (i in *florp) {
	switch (i) {
	case "a":
		if (aSeen) {
			printf("Seen a twice\n");
			assert(false);
		}
		var a = (*florp)[i];
		assert(a.class == long);
		aSeen = true;
		break;

	case "b":
		if (bSeen) {
			printf("Seen b twice\n");
			assert(false);
		}
		var b = (*florp)[i];
		assert(b.class == string);
		bSeen = true;
		break;

	case "c":
		if (cSeen) {
			printf("Seen c twice\n");
			assert(false);
		}
		var c = (*florp)[i];
		assert(c.class == ref<Array>);
		ref<Array> ca = ref<Array>(c);
		assert((*ca)[0].class == long);
		assert(long((*ca)[0]) == 23);
		assert((*ca)[1].class == double);
		assert(double((*ca)[1]) == 37.5);
		assert((*ca)[2].class == address);
		assert(address((*ca)[2]) == null);
		cSeen = true;
		break;

	default:
		printf("Unexpected property: %s\n", i);
		assert(false);
	}
}
assert(aSeen & bSeen & cSeen);



