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
namespace shared:ns;

int visibleFunc() {
	return anotherValue;
}

int value = 6;

foo baz;

int get_possible_dup() {
	return should_not_duplicate;
}

private int should_not_duplicate = 5;

// This is for the interface_test_4

public interface A {
	int f();
}

