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
#include <stdio.h>
#include "pxi.h"
/*
 * Date and Copyright holder of this code base.
 */
#define COPYRIGHT_STRING "2015 Robert Jervis"
/*
 * Major Release: Incremented when a breaking change is released
 * Minor Feature Release: Incremented when significant new features
 * are released.
 * Fix Release: Incremented when big fixes are released.
 */
#define RUNTIME_VERSION "1.0.0"

/*
 * The C++ code of the Parasol runtime is primarily in a shared object, so that symbols can be looked up (a
 * requirement of the Parasol native binding machenaism..
 *
 * As a result, this executable just does the most basic command line parsing and then loads the PXI argument
 * and runs it.
 */
int main(int argc, char **argv) {
	int returnValue;
	if (argc < 2) {
		printf("Use is: parasolrt <pxi-file> <program arguments>\n");
		return 1;
	}
	pxi::Section* section = pxi::load(argv[1]);
	if (section == null) {
		printf("Failed to load %s\n", argv[1]);
		return 1;
	}
#ifdef PARASOLRT_HEAP
	int heapValue = PARASOLRT_HEAP;
#else
	int heapValue = 0;
#endif
	if (section->run(argv, &returnValue, heapValue))
		return returnValue;
	else {
		printf("Unable to run pxi %s\n", argv[1]);
		return 1;
	}
}
