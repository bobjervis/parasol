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
#include "Parasol/runtime.h"
#include "threadSupport.h"
#include "Parasol/parasol_enums.h"

namespace parasol {

extern "C" {
/*
 * Used by the compiler to decide what compile target to choose, or validate a selected target.
 */
int supportedTarget(int index) {
	switch (index) {
#if defined(__WIN64)
	case 0:			return ST_X86_64_WIN;
#elif __linux__
	case 0:			return ST_X86_64_LNX;
#endif
	default:		return -1;
	}
}

void enterThread(ExecutionContext *newContext, void *stackTop) {
	threadContext.set(newContext);
	newContext->setStackTop(stackTop);
}

void exitThread() {
	ExecutionContext *context = threadContext.get();
	if (context != null) {
		threadContext.set(null);
		delete context;
	}
}

void *parasolThread(void *newThread) {
	ExecutionContext *context = threadContext.get();
	return context->parasolThread(newThread);
}

}

__thread ExecutionContext *ThreadContext::_threadContextValue;

}