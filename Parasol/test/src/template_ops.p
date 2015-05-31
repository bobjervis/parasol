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
TestTemplate<byte> V;

int n = V.f(0x10);

assert(n == 4);

class TestTemplate<class A> {
    int f(A x) {
		int i = 0;
		while (x != 0) {
			x <<= 1;
			i++;
		}
		return i;
	}
}
