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

void *parasolThread(void *newThread) {
	ExecutionContext *context = threadContext.get();
	return context->parasolThread(newThread);
}

int eval(X86_64SectionHeader *header, byte *image, long long runtimeFlags, char **argv, int argc) {
	ExecutionContext *outer = threadContext.get();
	ExecutionContext context(header, image, runtimeFlags);

	threadContext.set(&context);
//	StackState outer = context->unloadFrame();
	int (*start)(void *args) = (int (*)(void*))(image + header->entryPoint);
	context.prepareArgs(argv, argc);
	context.setSourceLocations(outer->sourceLocations(), outer->sourceLocationsCount());
	int result = context.runNative(start);

	// Transfer any uncaught exception to the outer context.

	Exception *e = context.exception();
	outer->exposeException(e);
	threadContext.set(outer);
//	context->reloadFrame(outer);
	return result;
}

int evalNative(X86_64SectionHeader *header, byte *image, char **argv, int argc) {
	ExecutionContext *outer = threadContext.get();
	ExecutionContext context(header, image, 0);

	threadContext.set(&context);
//	StackState outer = context->unloadFrame();
	int (*start)(void *args) = (int (*)(void*))(image + header->entryPoint);
	context.prepareArgs(argv, argc);
	context.setSourceLocations(outer->sourceLocations(), outer->sourceLocationsCount());
	int result = context.runNative(start);

	// Transfer any uncaught exception to the outer context.

	Exception *e = context.exception();
	outer->exposeException(e);
	threadContext.set(outer);
//	context->reloadFrame(outer);
	return result;
}

/*
struct SpawnPayload {
	const char *buffer;
	int length;
	process::exception_t outcome;
};

static int processDebugSpawn(char *command, SpawnPayload *output, long long timeout) {
	string out;
	string cmd(command);

	int result = process::debugSpawn(cmd, &out, &output->outcome, (time_t)timeout);
	char *capture = new char[out.size()];
	output->buffer = capture;
	output->length = out.size();
	memcpy(capture, out.c_str(), out.size());
	return result;
}

static int processDebugSpawnInteractive(char *command, SpawnPayload *output, string stdin, long long timeout) {
	string out;
	string cmd(command);

	int result = process::debugSpawnInteractive(cmd, &out, &output->outcome, stdin, (time_t)timeout);
	char *capture = new char[out.size()];
	output->buffer = capture;
	output->length = out.size();
	memcpy(capture, out.c_str(), out.size());
	return result;
}

static void disposeOfPayload(SpawnPayload *output) {
	delete[] output->buffer;
}
*/

}

__thread ExecutionContext *ThreadContext::_threadContextValue;

}