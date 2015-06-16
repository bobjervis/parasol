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
enum a { 
	A, 
	B, 
	C 
}; 

a x = a.B;

a y;

y = a.C;

assert(y == a.C);

assert(byte(x) == 1);

switch (y) {
case	A:
	assert(false);
default:
	break;
}

switch(y) {
case A:
case B:
	assert(false);
default:
	break;
}

switch(y) {
case C:
	break;
default:
	assert(false);
}

y = null;

a func(a x) {
	x = a.B;
	return x;
}

assert(func(a.C) == a.B);
