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
class A {
	private static int x;
	
	void set(int y) {
		x = y;
	}
	
	int get() {
		return x;
	}
}

A a;
A b;

assert(a.get() == 0);
assert(b.get() == 0);

a.set(4);

assert(a.get() == 4);
assert(b.get() == 4);

b.set(6);

assert(a.get() == 6);
assert(b.get() == 6);

class B {
	private static int x = 5;
	
	int get() {
		return x;
	}
}

B v;

assert(v.get() == 5);