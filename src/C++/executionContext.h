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
#ifndef EXECUTION_CONTEXT_H
#define EXECUTION_CONTEXT_H

#include <stdio.h>
#include <stdlib.h>
#include "machine.h"
#include "parasol_enums.h"
#include "pxi.h"

namespace parasol {

class Exception;

// Exception table consist of some number of these entries, sorted by ascending location value.
// Any IP value between the location of one entry and the next is processed by the assicated handler.
// A handler value of 0 indicates no handler exists.
class ExceptionEntry {
public:
	int location;
	int handler;
};

class ExceptionTable {
public:
	int length;
	int capacity;
	ExceptionEntry *entries;
};

#define ALLOC_INCREMENT 5

class ExecutionContext {
public:

	ExecutionContext(pxi::X86_64SectionHeader *pxiHeader, void *image, ExecutionContext *outer);

	void enter();

	void prepareArgs(char **argv, int argc);

	int runNative(int (*start)(void *args));

	byte *stackTop() { return _stackTop; }

	void setStackTop(void *p) {
		_stackTop = (byte*)p;
	}

	void *exceptionsAddress();

	int exceptionsCount();

	void exposeException(Exception *exception) {
		_exception = exception;
	}

	Exception *exception() {
		return _exception;
	}

	byte *lowCodeAddress() {
		return (byte*)_image;
	}

	byte *highCodeAddress();

	void callCatchHandler(Exception *exception, void *framePointer, int handler);

	ExecutionContext *clone();

	void *getRuntimeParameter(int i) {
		if (i >= _runtimeParametersCount)
			return null;
		else {
//			printf("ExecutionContext::getRuntimeParameter(%d) = %p\n", i, _runtimeParameters[i]);
//			printf("read [3] = %p\n", _runtimeParameters[3]);
			return _runtimeParameters[i];
		}
	}

	void setRuntimeParameter(int i, void *newValue) {
//		printf("before [3] = %p\n", _runtimeParameters[3]);
		if (i >= _runtimeParametersCount) {
			if (newValue != null) {
				int size = i + ALLOC_INCREMENT;
				size -= size % ALLOC_INCREMENT;			// truncate to nearest multiple of ALLOC_INCREMENT
				void** p = (void**)calloc(size, sizeof (void*));
				memcpy(p, _runtimeParameters, _runtimeParametersCount * sizeof (void*));
				free(_runtimeParameters);
				_runtimeParameters = p;
				_runtimeParametersCount = size;
			} else
				return;
		}
//		printf("ExecutionContext::setRuntimeParameter(%d, %p)\n", i, newValue);
		_runtimeParameters[i] = newValue;
//		printf("after [3] = %p\n", _runtimeParameters[3]);
	}

private:
	byte *_stackTop;
	Exception *_exception;
	pxi::X86_64SectionHeader *_pxiHeader;
	void *_image;
	char **_argv;
	int _argc;
	void *_sourceLocations;
	int _sourceLocationsCount;
	void *_parasolThread;
	void** _runtimeParameters;
	int _runtimeParametersCount;
};

class ThreadContext {
public:
	ThreadContext() {
#if defined(__WIN64)
		_slot = TlsAlloc();
#elif __linux__
		_threadContextValue = 0;
#endif
	}

	bool set(ExecutionContext *value) {
#if defined(__WIN64)
		if (TlsSetValue(_slot, value))
			return true;
		else
			return false;
#elif __linux__
		_threadContextValue = value;
		return true;
#endif
	}

	ExecutionContext *get() {
#if defined(__WIN64)
		return (ExecutionContext*)TlsGetValue(_slot);
#elif __linux__
		return _threadContextValue;
#endif
	}

private:
#if defined(__WIN64)
	DWORD	_slot;
#endif
#if __linux__
	static __thread ExecutionContext *_threadContextValue;
#endif
};

extern ThreadContext threadContext;

extern "C" {

int evalNative(pxi::X86_64SectionHeader *header, byte *image, char **argv, int argc);

void callAndSetFramePtr(void *newRbp, void *newRip, void *arg);

void *getRuntimeParameter(int i);

void setRuntimeParameter(int i, void *newValue);

}

#define RP_SECTION_TYPE 4

}

#endif
