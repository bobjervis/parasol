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
import parasol:thread.Thread;
import parasol:thread.ThreadPool;

ThreadPool<int> pool(4);

int value;

assert(value == 0);

pool.execute(f, &value);

Thread.sleep(300);

assert(value == 17);

void f(address p) {
	ref<int> pvalue = ref<int>(p);
	*pvalue = 17;
}

