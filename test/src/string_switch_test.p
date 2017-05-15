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

int select(string key) {
	switch (key) {
	case "B":
		return 1;
		
	case "A":
		return 265;
		
	case "C":
		return 300;
	}	
	return -1;
}

assert(select("A") == 265);
assert(select("B") == 1);
assert(select("C") == 300);

assert(select("anything else") == -1);
