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

enum X {
	A, B, C
}

X f() {
	byte zTest = 2;
	
	return X(zTest);
}

assert(f() == X.C);

class C {
	byte n;
}

X g() {
	ref<C> c = new C;
	
	c.n = 1;
	
	return X(c.n);
}

assert(g() == X.B);