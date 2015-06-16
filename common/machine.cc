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
#include "../common/platform.h"
#include <stdlib.h>
#include <windows.h>

#include "machine.h"

char string::dummy;

const int OUTPUT_BLOCK = 32;

void debugPrint(const string& s) {
	char chars[OUTPUT_BLOCK + 1];

	for (int i = 0; i < s.size(); i += OUTPUT_BLOCK){
		int j = OUTPUT_BLOCK;
		if (i + j > s.size())
			j = s.size() - i;
		memcpy(chars, &s.c_str()[i], j);
		chars[j] = 0;

		OutputDebugString(chars);
	}
}

Milliseconds millisecondMark() {
	return GetTickCount();
}

void setRbp(void *newValue) {
	asm ("mov %rcx,%rbp");
}
