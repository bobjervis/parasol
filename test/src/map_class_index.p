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

class Key {
	long stuff;

	Key() {	}
	
	Key(long s) {
		stuff = s;
	}
	
	int compare(Key k) {
		if (stuff > k.stuff)
			return 1;
		else if (stuff < k.stuff)
			return -1;
		else
			return 0;
	}
	
	int hash() {
		return int(stuff);
	}
}

boolean[Key] map;

Key k1(45);

Key k2(63);

map[k1] = true;

map[k2] = false;

Key k3(112);

assert(map.size() == 2);
assert(map[k1]);
assert(!map[k2]);
assert(!map[k3]);
