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
#include "executionContext.h"
#include "threadSupport.h"
#include "parasol_enums.h"

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
/*
 * This is called from Parasol.
 */
int eval(X86_64SectionHeader *header, byte *image, char **argv, int argc) {
	ExecutionContext *outer = threadContext.get();
	ExecutionContext context(header, image, outer);

	threadContext.set(&context);
	int (*start)(void *args) = (int (*)(void*))(image + header->entryPoint);
	context.prepareArgs(argv, argc);
	int result = context.runNative(start);

	// Transfer any uncaught exception to the outer context.

	Exception *e = context.exception();
	outer->exposeException(e);
	threadContext.set(outer);
	return result;
}
/*
 * This is called just from the main C++ code.
 */
int evalNative(X86_64SectionHeader *header, byte *image, char **argv, int argc) {
	ExecutionContext *context = new ExecutionContext(header, image, null);

	threadContext.set(context);
	int (*start)(void *args) = (int (*)(void*))(image + header->entryPoint);
	context->prepareArgs(argv + 1, argc - 1);
	return context->runNative(start);
}

}

__thread ExecutionContext *ThreadContext::_threadContextValue;

}