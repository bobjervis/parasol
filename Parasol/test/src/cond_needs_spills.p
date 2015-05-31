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
int func(int a, int b) {
	return a - b;
}

int outer(int x, int y, int z) {
	printf("x = %d y = %d z = %d\n", x, y, z);
	return x + y + z;
}

boolean test() {
	return false;
}

boolean testResult = test();

int value = outer(3, 17, testResult ? func(200, 194) : -3);

printf("value = %d\n", value);
assert(value == 17);

