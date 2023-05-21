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
class Member {
	int _value;
	
	Member() {
		_value = 3;
	}
	
	int value() {
		return _value;
	}
}

class Base {
	Member baseMember;
	
	int baseTest() {
		return baseMember.value();
	}
}

class Derived extends Base {
	void test() {
		assert(baseTest() == 3);
	}
}

class ReallyDerived extends Derived {
	ReallyDerived() {
		test();
	}
}

ref<ReallyDerived> rd = new ReallyDerived();

delete rd;
