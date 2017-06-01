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
import SampleIn = parasol:test.Sample;
import parasol:test.staticConstructor;
import parasol:test.calledConstructor;
import parasol:test;

int main(string[] args) {
	SampleIn x;
	
	x.y = 3;
	x.z = 5;
	assert(x.y + 2 == x.z);
	assert(calledConstructor);
	print("Passed\n");
	return 0;
}

test.SampleEnum se;

print("Setting se\n");

se = test.SampleEnum(2);

assert(se == test.SampleEnum.C);

print("Static initializers finished\n");