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
namespace parasol:test;

private void f(ref<int> x, int y) {
	if (*x > 5) {
	} else
		y = 5;
}

boolean calledConstructor;
StaticConstructor staticConstructor;

class Sample {
	public int y;
	public int z;
}

class StaticConstructor {
	StaticConstructor() {
		calledConstructor = true;
	}
}

public enum SampleEnum {
	A, B, C, D
}
