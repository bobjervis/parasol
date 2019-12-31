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

void f(int key, substring... args) {
	switch (key) {
	case 1:
		assert(args[0].length() == 3);
		string s = args[0];
		assert(s.length() == 3);
		assert(s == "abc");
		break;

	case 2:
		assert(args[0].length() == 5);
		s = args[0];
		assert(s.length() == 5);
		assert(s == "defgh");
		break;

	default:
		printf("Unexpected key: %d\n", key);
		assert(false);
	}
}

f(1, "abc");
string s = "defgh";
string t = "ijkl";
substring ss = s;
ref<substring> ssp = &ss;
f(2, *ssp);

substring left() {
	return s;
}

substring right() {
	return t;
}

assert(left() != right());

class Y {
	abstract substring id();
}

class X extends Y {
	substring _x;

	X(substring ss) {
		_x = ss;
	}

	substring id() {
		return _x;
	}

	ref<X> me() {
		return this;
	}
}

X x1("mn");
X x2("opqrstu");
ref<X> xp1 = &x1;
ref<X> xp2 = &x2;

if (xp1.id() != xp2.me().id())
	;
else
	assert(false);


