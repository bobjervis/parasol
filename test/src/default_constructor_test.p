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

// The goal of the test is to determine that default constructors are called in the appropriate
// places where the semantics dictate that they go, and not in places where they don't.

int defaultConstructorCallCount;

@Constant
int MAGIC_VALUE = 0x34718f2e;

class C {
	private int _value;
	
	public C() {
		defaultConstructorCallCount++;
		_value = MAGIC_VALUE;
	}
	
	public int value() {
		return _value;
	}
}

printf("Start of test\n");

// Even though 'global' is declared below this point, the semantics of default constructors demands that
// they be executed before entry to the scope, so that side-effects like this can be detected.

assert(defaultConstructorCallCount == 1);
defaultConstructorCallCount = 0;
assert(global.value() == MAGIC_VALUE);

C global;

f();

void f() {
	// Even though 'local' is declared below this point, the semantics of default constructors demands that
	// they be executed before entry to the scope, so that side-effects like this can be detected.

	assert(defaultConstructorCallCount == 1);
	defaultConstructorCallCount = 0;
	assert(local.value() == MAGIC_VALUE);

	C local;
}

