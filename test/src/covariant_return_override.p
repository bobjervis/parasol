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
	int _base;
	
	abstract ref<Base> foo();
}

class Derived extends Base {
	ref<Derived> foo() {
		return this;
	}
	
	void bar() {
		foo().baz();
	}
	
	void baz() {
		flagHit = true;
	}
}

boolean flagHit;

Derived d;

d.bar();

assert(flagHit);

