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
interface A {
	int f(long y);
	
	void g(string s);
}


class C implements A {
	int f(long y) {
		return int(y);
	}
	
	void g(string z) {
		printf(z);
		assert(z.startsWith("hel"));
	}
}

ref<C> c = new C;

A a = c;

a.g("hello");

assert(a.f(0x200000045) == 69);
