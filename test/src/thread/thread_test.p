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

import parasol:thread.Thread;

ref<Thread> t = new Thread();

t.start(f, &x);

int x = 174325;

void f(address parameter) {
	printf("x = %d\n", *ref<int>(parameter));
	assert(*ref<int>(parameter) == 174325);
}

t.join();

delete t;
