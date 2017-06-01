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
class Base {
	Base() {
	}
	
	int inheritedFunc() {
		flagBase = true;
		return 3;
	}
}

class Derived extends Base {
	Derived() {
		super();
	}
	
	int inheritedFunc() {
		int x = super.inheritedFunc();
		flagDerived = true;
		return x * 2;
	}
}

Derived d;

boolean flagBase;
boolean flagDerived;

assert(d.inheritedFunc() == 6);

assert(flagBase);
assert(flagDerived);

printf("Derived class direct call test - PASSED\n");

Base b;

ref<Base> bp = &b;

address vtable = *ref<address>(&b);
text.memDump(vtable, 24);

flagBase = false;
assert(bp.inheritedFunc() == 3);
assert(flagBase);

assert(bp.class == Base);

printf("Base class indirect call test - PASSED\n");

ref<Base> x = &d;

assert(x.class == Derived);

printf("Base class indirect class detection test - PASSED\n");

