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
namespace parasol:types;

public class address {}

public class boolean {
//	public boolean() {
//	}
	
//	public boolean(boolean value) {
//	}
}

@Final 
public class void {}

public class ClassInfo {}
public class `*Namespace*` {}
public class `*deferred*`{}
public class `*array*`{}
public class `*object*`{}

public class Array{}

public class Object {
	private var[string] _members;
	
	public var get(string key) {
		return _members[key];
	}
	
	public void set(string key, var value) {
		_members[key] = value;
	}
}
