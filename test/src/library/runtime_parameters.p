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
namespace parasol:runtime;

import parasol:memory;
import parasol:pxi;

printf("SOURCE_LOCATIONS       %d: %p\n", SOURCE_LOCATIONS, getRuntimeParameter(SOURCE_LOCATIONS));
printf("SOURCE_LOCATIONS_COUNT %d: %d\n", SOURCE_LOCATIONS_COUNT, int(getRuntimeParameter(SOURCE_LOCATIONS_COUNT)));
printf("LEAKS_FLAG             %d: %s\n", LEAKS_FLAG, string(memory.StartingHeap(getRuntimeParameter(LEAKS_FLAG))));
printf("SECTION_TYPE           %d: %s\n", SECTION_TYPE, string(Target(int(getRuntimeParameter(SECTION_TYPE)))));

