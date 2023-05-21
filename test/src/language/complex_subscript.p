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
int offset = 2000;

class E {
	int loc;
	int handler;
}

class H {
	int loc;
	int segmentOffset;
}

E[] _exceptionTable;
H[] _exceptionHandlers;

E e;

e.loc = 123;
e.handler = 456;

H h;

h.loc = 122;
h.segmentOffset = 319;

_exceptionTable.append(e);
_exceptionHandlers.append(h);

int i = 0;

_exceptionTable[i].handler = offset + _exceptionHandlers[i].segmentOffset;

printf("handler = %d\n", _exceptionTable[i].handler);
assert(_exceptionTable[i].handler == 2319);
