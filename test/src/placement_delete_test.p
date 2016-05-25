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
class Test {
	long f;
	
	~Test() {
		destructorCalled++;
		if (f == 17)
			f = 0x123456789abcdef;
		else
			f = 0x987654321;
	}
}

ref<long> lp = new long;

*lp = 17;

int destructorCalled;

(*ref<Test>(lp)).~();


assert(destructorCalled == 1);
assert(*lp == 0x123456789abcdef);

pointer<Test> p = pointer<Test>(lp);

p[0].~();

assert(destructorCalled == 2);
assert(*lp == 0x987654321);
