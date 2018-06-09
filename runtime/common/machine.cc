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
#include "../common/platform.h"
#include <stdlib.h>
#if defined(__WIN64)
#include <windows.h>
#elif __linux__
#include <stdio.h>
#include <time.h>

static const long long MILLIS_PER_SECOND = 1000;
static const long long NANOS_PER_MILLISECOND = 1000000;
#endif

#include "machine.h"

char string::dummy;

const int OUTPUT_BLOCK = 32;

void debugPrint(const string& s) {
#if defined(__WIN64)
	char chars[OUTPUT_BLOCK + 1];

	for (int i = 0; i < s.size(); i += OUTPUT_BLOCK){
		int j = OUTPUT_BLOCK;
		if (i + j > s.size())
			j = s.size() - i;
		memcpy(chars, &s.c_str()[i], j);
		chars[j] = 0;

		OutputDebugString(chars);
	}
#elif __linux__
	printf("%s", s.c_str());
#endif
}

Milliseconds millisecondMark() {
#if defined(__WIN64)
	return GetTickCount();
#elif __linux__
	timespec ts;
	clock_gettime(CLOCK_BOOTTIME, &ts);
	return ts.tv_sec * MILLIS_PER_SECOND + ts.tv_nsec / NANOS_PER_MILLISECOND;
#endif
}
