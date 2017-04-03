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


string a = "before";
ClassD x = { e: 'a', f: 'b', g: 0 };


string b = f(a, &x);

printf("b == '%s'\n", b);
assert(b == "before/ab");

string f(string a, ref<ClassD> d) {
	return a + "/" + string(pointer<byte>(&d.e));
}

class ClassD {
	long x;
	long y;
	char c;
	byte d;
	byte e;
	byte f;
	byte g;
}