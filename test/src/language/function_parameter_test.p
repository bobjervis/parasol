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
class A<class E> {
	E f1;
	E f2;
	
	int meth1(int comp(E a, E b)) {
		foo(5);
		return comp(f1, f2);
	}
	
	static void foo(int x) {
		
	}
}

int compInst(int x, int y) {
	return x + y;
}

A<int> x;

x.f1 = 15;
x.f2 = 27;

assert(x.meth1(compInst) == 42);
