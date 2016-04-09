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
import parasol:text;

class A {
	int _filler;
	
	~A() {
		_filler++;
		destructorCountA++;
	}
	
	void foo() {
		
	}
}

class B extends A {
	int _signal;
	
	~B() {
		assert(_signal == 1);
	}
	
	void foo() {
		_signal = 1;
	}
}

int destructorCountA;

int f() {
	A a;
	
	return 3;
}

int x = f();

assert(x == 3);
printf("destructorCountA: %d\n", destructorCountA);
assert(destructorCountA == 1);

ref<A> ra = new A;

delete ra;

assert(destructorCountA == 2);

ref<B> rb = new B;

printf("rb = %p\n", rb);
text.memDump(address(long(rb) - 0x20), B.bytes + 0x40);

ra = rb;

ra.foo();

printf("after foo() rb = %p\n", rb);
text.memDump(address(long(rb) - 0x20), B.bytes + 0x40);

delete rb;

assert(destructorCountA == 3);

class C {
	long filler;
	A needsDestructor;
	
	~C() {
		filler = 3;
	}
}

ref<C> c = new C;

delete c;

assert(destructorCountA == 4);

int destructorCountInnerD;

class InnerD {
	int y;
	
	~InnerD() {
		destructorCountInnerD++;
	}
}

class D extends A {
	InnerD x;
}

ref<A> rac = new D();

delete rac;

assert(destructorCountInnerD == 1);
assert(destructorCountA == 5);
