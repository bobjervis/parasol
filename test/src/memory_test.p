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
import parasol:memory;
import native:C;

address allocated;
address freed;

class TestAllocator extends memory.Allocator {
	address alloc(long n) {
		allocated = allocz(int(n));
		return allocated;
	}
	
	void free(address a) {
		freed = a;
		C.free(a);
	}
	
	void clear() {
		
	}
}

TestAllocator ta;

ref<int> xp = ta new int;

assert(xp == allocated);

ta delete xp;

assert(xp == freed);

ref<TestAllocator> rta = &ta;

ref<int> zp = rta new int;

assert(zp == allocated);

rta delete zp;

assert(zp == freed);

