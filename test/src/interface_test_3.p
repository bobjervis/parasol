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
boolean constructorBCalled;
boolean destructorBCalled;
boolean actionBCalled;
boolean actionCCalled;

interface AA {
	void action();
}

class B implements AA {
	int x;

	B() { 
		assert(!constructorBCalled);			// Compiler bug: interfaces seem to trigger repeated constructor calls.
		constructorBCalled = true;
	}

	~B() {
		destructorBCalled = true;
	}

	void action() {
		actionBCalled = true;
	}
}

class C implements AA {

	void action() {
		actionCCalled = true;
	}
}

ref<B> b = new B();
ref<C> c = new C;

AA a;

a = b;

a.action();

assert(actionBCalled);

delete a;										// Compiler bug: interface destructors are not generated.

assert(destructorBCalled);

a = c;

a.action();

assert(actionCCalled);

delete a;		// no destructor defined, but should not blow up
