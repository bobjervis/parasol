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
func(2, "abc", "def");

func(0);

func2(45, 45);

func3(275, 275);

void func(int x, string... y) {
	printf("x=%d y.length() = %d\n", x, y.length());
	assert(x == y.length());
}

void func2(int x, int... y) {
	assert(y.length() == 1);
	assert(x == y[0]);
}

void func3(int x, int... y) {
	func2(x, y);
}

string s;

s.printf("%s %s %s %s %s %s %s %s %s %s", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j");

assert(s == "a b c d e f g h i j");
