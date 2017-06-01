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
class Location {
	long offset;
}

class CompileString {
	pointer<byte> data;
	int length;
}

byte[] buffer;

buffer.resize(15);

void func(address first, CompileString value, Location location) {
	assert(first == null);
	assert(value.data == &buffer[0]);
	assert(value.length == 5);
	assert(location.offset == 3);
}

CompileString v;

v.data = &buffer[0];
v.length = 5;

CompileString func2() {
	return v;
}

Location loc;

loc.offset = 3;

func(null, func2(), loc);   