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
class Base {
	int f() {
		return 5;
	}
}

class NoCons extends Base {
	int f() {
		return -1;
	}
}

ref<NoCons> nc;

nc = new NoCons();

assert(nc.f() == -1);

class CTest {
	CTest() {
		
	}
	
	string foo() {
		return "";
	}
	
	void bar() {
		printf("Did it!\n");
	}
}

class Derived extends CTest {
	string foo() {
		return "z";
	}
}

void f(CTest x) {
	x.bar();
}

f(CTest());

ref<CTest> xt;

xt = new CTest();

assert(xt.foo() == "");

ref<CTest> yt;

yt = new CTest;

assert(yt.foo() == "");

