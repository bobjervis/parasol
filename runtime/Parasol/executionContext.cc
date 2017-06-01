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
#include "runtime.h"

namespace parasol {

static int comparatorCurrentIp(const void *ip, const void *elem) {
	int location = *(int*)ip;
	ExceptionEntry *ee = (ExceptionEntry*)elem;

	if (location < ee[0].location)
		return -1;
	else if (location < ee[1].location)
		return 0;
	else
		return 1;
}

static int comparatorReturnAddress(const void *ip, const void *elem) {
	int location = *(int*)ip;
	ExceptionEntry *ee = (ExceptionEntry*)elem;
	if (location <= ee[0].location)
		return -1;
	else if (location <= ee[1].location)
		return 0;
	else
		return 1;
}
/*
 * This method is called when the RBPO value makes no sense. This arises from low-level C/C++ runtime
 * routines that do not create a standard stack frame. Now we have to scan the stack for a plausible
 * starting point.
 */
void ExecutionContext::crawlStack(const StackState &state, void *rbp) {
}

void *ExecutionContext::exceptionsAddress() {
	return (char*)_image + _pxiHeader->exceptionsOffset;
}

int ExecutionContext::exceptionsCount() {
	return _pxiHeader->exceptionsCount;
}

byte *ExecutionContext::highCodeAddress() {
	return (byte*)_image + _pxiHeader->builtInOffset;
}

void ExecutionContext::callCatchHandler(Exception *exception, void *framePointer, int handler) {
	void (*h)(Exception *exception) = (void(*)(Exception*))((byte*)_image + handler);
	callAndSetFramePtr(framePointer, (void*) h, exception);
}

void ExecutionContext::registerHardwareExceptionHandler(void (*handler)(HardwareException *info)) {
	_hardwareExceptionHandler = handler;
}
}
