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
	int _filler;
	
	~A() {
		_filler++;
		destructorCountA++;
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

class B {
	long filler;
	A needsDestructor;
	
	~B() {
		filler = 3;
	}
}

ref<B> b = new B;

delete b;

assert(destructorCountA == 3);

void plainFunc() {
	A plainA;
}

plainFunc();

assert(destructorCountA == 4);
