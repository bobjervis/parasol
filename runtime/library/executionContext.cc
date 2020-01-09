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
#if defined(__WIN64)
#include <windows.h>
#elif __linux__
//typedef unsigned long long SIZE_T;
//typedef unsigned DWORD;
//typedef int BOOL;
#include <signal.h>

#endif

namespace parasol {
#if __linux__
void sigGeneralHandler(int signum, siginfo_t *info, void *uContext);

void sigSegvHandler(int signum, siginfo_t *info, void *uContext);
#endif

ExecutionContext::ExecutionContext(X86_64SectionHeader *pxiHeader, void *image, ExecutionContext *outer) {
	_exception = null;
	_stackTop = null;
	_target = -1;
	_pxiHeader = pxiHeader;
	_image = image;
	if (outer != null) {
		_hardwareExceptionHandler = outer->_hardwareExceptionHandler;
		for (int i = 0; i < outer->_runtimeParameters.size(); i++)
			setRuntimeParameter(i, outer->getRuntimeParameter(i));
	} else
		_hardwareExceptionHandler = null;
}

void ExecutionContext::enter() {
	_target = NATIVE_64_TARGET;
	threadContext.set(this);
}

void ExecutionContext::prepareArgs(char **argv, int argc) {
	_args.clear();
	for (int i = 0; i < argc; i++)
		_args.push_back(string(argv[i]));
}

int ExecutionContext::runNative(int (*start)(void *args)) {
	_target = NATIVE_64_TARGET;
	byte *x;
	_stackTop = (byte*) &x;
#if defined(__WIN64)
	PVOID handle = AddVectoredExceptionHandler(0, windowsExceptionHandler);
#elif __linux__
	struct sigaction oldSigIllAction;
	struct sigaction oldSigSegvAction;
	struct sigaction oldSigFpeAction;
	struct sigaction oldSigQuitAction;
	struct sigaction oldSigAbortAction;
	struct sigaction oldSigTermAction;
	struct sigaction newGeneralAction;
	struct sigaction newSegvAction;

	newGeneralAction.sa_sigaction = sigGeneralHandler;
	newGeneralAction.sa_flags = SA_SIGINFO;
	newSegvAction.sa_sigaction = sigSegvHandler;
	newSegvAction.sa_flags = SA_SIGINFO;
	sigaction(SIGILL, &newGeneralAction, &oldSigIllAction);
	sigaction(SIGSEGV, &newSegvAction, &oldSigSegvAction);
	sigaction(SIGFPE, &newGeneralAction, &oldSigFpeAction);
	sigaction(SIGQUIT, &newGeneralAction, &oldSigQuitAction);
	sigaction(SIGABRT, &newGeneralAction, &oldSigAbortAction);
	sigaction(SIGTERM, &newGeneralAction, &oldSigTermAction);
#endif
	long long inlineParasolArray[2];		// Arguments are a string array.

	inlineParasolArray[1] = (long long)&_args[0];
	inlineParasolArray[0] = (((WORD)_args.size() << 32) | _args.size());
	int result = start(inlineParasolArray);
#if defined(__WIN64)
	RemoveVectoredExceptionHandler(handle);
#elif __linux__
	sigaction(SIGILL, &oldSigIllAction, null);
	sigaction(SIGSEGV, &oldSigSegvAction, null);
	sigaction(SIGFPE, &oldSigFpeAction, null);
	sigaction(SIGQUIT, &oldSigQuitAction, null);
	sigaction(SIGABRT, &oldSigAbortAction, null);
	sigaction(SIGTERM, &oldSigTermAction, null);
#endif
	return result;
}

void ExecutionContext::callHardwareExceptionHandler(HardwareException *info) {
	_hardwareExceptionHandler(info);
}

ExecutionContext *ExecutionContext::clone() {
	ExecutionContext *newContext = new ExecutionContext(_pxiHeader, _image, this);
	newContext->_target = _target;
	newContext->_hardwareExceptionHandler = _hardwareExceptionHandler;
	return newContext;
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

extern "C" {

ExecutionContext *dupExecutionContext() {
	ExecutionContext *context = threadContext.get();
	return context->clone();
}

}

}