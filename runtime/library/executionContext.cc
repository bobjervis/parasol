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
#include <string.h>
#if defined(__WIN64)
#include <windows.h>
#endif

namespace parasol {

ExecutionContext::ExecutionContext(pxi::X86_64SectionHeader *pxiHeader, void *image, ExecutionContext *outer) {
	_exception = null;
	_stackTop = null;
	_target = -1;
	_pxiHeader = pxiHeader;
	_image = image;
	if (outer != null) {
		for (int i = 0; i < outer->_runtimeParameters.size(); i++)
			setRuntimeParameter(i, outer->getRuntimeParameter(i));
	}
}

void ExecutionContext::enter() {
	_target = NATIVE_64_TARGET;
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
	_target = NATIVE_64_TARGET;
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
	ExecutionContext *newContext = new ExecutionContext(_pxiHeader, _image, this);
	newContext->_target = _target;
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

extern "C" {

ExecutionContext *dupExecutionContext() {
	ExecutionContext *context = threadContext.get();
	return context->clone();
}

}

}