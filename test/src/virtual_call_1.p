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
	public void put(string label, ref<Base> value) {
		
	}
	
	public string get() {
		return null;
	}
}

class Derived extends Base {
	ref<Base> v;
	string x;
	
	public void put(string label, ref<Base> value) {
		x = label;
		v = value;
	}
}

class Derived2 extends Base {
	string f;
	
	public Derived2(string arg) {
		f = arg;
	}
	
	public string get() {
		return f;
	}
}

Derived d;
void func() {
	ref<Derived> derived = &d;
	string s = "abc";
	
	derived.put("tag", new Derived2(s));
	assert(derived.v.get() == "abc");
	assert(derived.x == "tag");
}

func();

Derived d3;
ref<Base> base = &d3;

base.put("tag2", new Derived);

assert(d3.v.get() == null);
assert(d3.x == "tag2");

