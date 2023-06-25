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
#include <string.h>
#include <stdlib.h>
#if defined(__WIN64)
#include <windows.h>
#endif

namespace parasol {

ExecutionContext::ExecutionContext(pxi::X86_64SectionHeader *pxiHeader, void *image, 
								   ExecutionContext *outer) {
	_exception = null;
	_stackTop = null;
	_pxiHeader = pxiHeader;
	_image = image;
	_runtimeParameters = (void**)calloc(ALLOC_INCREMENT, sizeof (void*));
	_runtimeParametersCount = ALLOC_INCREMENT;
	if (outer != null) {
		for (int i = 0; i < outer->_runtimeParametersCount; i++)
			setRuntimeParameter(i, outer->getRuntimeParameter(i));
	}
}

void ExecutionContext::enter() {
	threadContext.set(this);
}

void ExecutionContext::prepareArgs(char **argv, int argc) {
	_argv = argv;
	_argc = argc;
}

struct string {
	int size;
	char data[1];
};

int ExecutionContext::runNative(int (*start)(void *args)) {
	byte *x;
	_stackTop = (byte*) &x;
	long long inlineParasolArray[2];		// Arguments are a string array.
	string **args = new string*[_argc];
	for (int i = 0; i < _argc; i++) {
		int len = strlen(_argv[i]);
		args[i] = (string*)new char[sizeof(string) + len];
		args[i]->size = strlen(_argv[i]);
		strcpy(args[i]->data, _argv[i]);
	}

	inlineParasolArray[1] = (long long)args;
	inlineParasolArray[0] = _argc;
	int result = start(inlineParasolArray);
	return result;
}

ExecutionContext *ExecutionContext::clone() {
	return new ExecutionContext(_pxiHeader, _image, this);
}

void *ExecutionContext::exceptionsAddress() {
	return (char*)_image + _pxiHeader->exceptionsOffset;
}

int ExecutionContext::exceptionsCount() {
	return _pxiHeader->exceptionsCount;
}

byte *ExecutionContext::highCodeAddress() {
	return (byte*)_image + _pxiHeader->typeDataOffset;
}

void ExecutionContext::callCatchHandler(Exception *exception, void *framePointer, int handler) {
	void (*h)(Exception *exception) = (void(*)(Exception*))((byte*)_image + handler);
	callAndSetFramePtr(framePointer, (void*) h, exception);
}

#if __linux__
__thread ExecutionContext *ThreadContext::_threadContextValue;
#endif

extern "C" {

ExecutionContext *dupExecutionContext() {
	ExecutionContext *context = threadContext.get();
	return context->clone();
}

void *exceptionsAddress() {
	ExecutionContext *context = threadContext.get();
	return context->exceptionsAddress();
}

int exceptionsCount() {
	ExecutionContext *context = threadContext.get();
	return context->exceptionsCount();
}

byte *lowCodeAddress() {
	ExecutionContext *context = threadContext.get();
	return context->lowCodeAddress();
}

byte *highCodeAddress() {
	ExecutionContext *context = threadContext.get();
	return context->highCodeAddress();
}

void *getRuntimeParameter(int i) {
	ExecutionContext *context = threadContext.get();
	if (context == null)
		return null;
	else
		return context->getRuntimeParameter(i);
}

void setRuntimeParameter(int i, void *newValue) {
	ExecutionContext *context = threadContext.get();
	if (context != null)
		context->setRuntimeParameter(i, newValue);
}

void callCatchHandler(Exception *exception, void *framePointer, int handler) {
	ExecutionContext *context = threadContext.get();
	context->callCatchHandler(exception, framePointer, handler);
}

/*
 * exposeException - The compiler inserts a hidden try around the top level of a unit static initialization block
 * whose catch consists solely of recording the otherwise uncaught exception for later processing. THis is basically
 * the hook to transmit the failing exception out of the nested context and out to the invoker.
 *
 * Note: currently the logic is written interms of ExceptionContext objects, but must eventually be converted to use
 * actual Exception objects.
 */
void exposeException(Exception *e) {
	ExecutionContext *context = threadContext.get();
	context->exposeException(e);
}

Exception *fetchExposedException() {
	ExecutionContext *context = threadContext.get();
	Exception *e = context->exception();
	context->exposeException(null);
	return e;
}

void *formatMessage(unsigned NTStatusMessage) {
#if defined(__WIN64)
   char *lpMessageBuffer;
   HMODULE Hand = LoadLibrary("NTDLL.DLL");

   FormatMessage(
       FORMAT_MESSAGE_ALLOCATE_BUFFER |
       FORMAT_MESSAGE_FROM_SYSTEM |
       FORMAT_MESSAGE_FROM_HMODULE,
       Hand,
       NTStatusMessage,
       MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
       (char*) &lpMessageBuffer,
       0,
       NULL );

   // Now display the string.

   int length = (int) strlen(lpMessageBuffer) + 1;
   void *memory = malloc(length);

   memcpy(memory, lpMessageBuffer, length);

   // Free the buffer allocated by the system.
   LocalFree( lpMessageBuffer );
   FreeLibrary(Hand);
   return memory;
#elif __linux__
   return (void*)"";
#endif
}

void callAndSetFramePtr(void *newRbp, void *newRip, void *arg) {
#if defined(__WIN64)
	asm ("mov %rcx,%rbp");
	asm ("mov %r8,%rcx");
	asm ("jmp *%rdx");
#elif __linux__
	asm ("mov %rdi,%rbp");
	asm ("mov %rdx,%rdi");
	asm ("jmp *%rsi");
#endif
}

void *returnAddress() {
	asm("mov 8(%rbp),%rax");
	asm("ret");
	return 0;
}

void *framePointer() {
	asm("mov %rbp,%rax");
	asm("ret");
	return 0;
}

byte *stackTop() {
	ExecutionContext *context = threadContext.get();
	if (context != 0)
		return context->stackTop();
	else
		return 0;
}

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
int eval(pxi::X86_64SectionHeader *header, byte *image, char **argv, int argc) {
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
int evalNative(pxi::X86_64SectionHeader *header, byte *image, char **argv, int argc) {
	ExecutionContext *outer = threadContext.get();
	ExecutionContext *context = new ExecutionContext(header, image, outer);

	threadContext.set(context);
	int (*start)(void *args) = (int (*)(void*))(image + header->entryPoint);
	context->prepareArgs(argv + 1, argc - 1);
	return context->runNative(start);
}

}

}