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
class InnerWithVtable {
	int foo() {
		return 3;
	}
}

class Derived extends InnerWithVtable {
	int foo() {
		return 5;
	}
}

class Outer {
	Derived d;
}

ref<Outer> o = new Outer();

ref<InnerWithVtable> inner = &o.d;

assert(o.d.foo() == 5);			// Doesn't use the vtable

assert(inner.foo() == 5);		// Does use the vtable
