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

#include "common/machine.h"
#include "parasol_enums.h"
#include "pxi.h"
#include "x86_pxi.h"
#include "exceptionSupport.h"

namespace parasol {

const int INDENT = 4;

const int BYTE_CODE_TARGET = 1;
const int NATIVE_64_TARGET = 2;

typedef long long WORD;

#define STACK_SLOT (sizeof (WORD))
#define FRAME_SIZE (sizeof(WORD) + 2 * sizeof(void*))

static const int STACK_SIZE = STACK_SLOT * 128 * 1024;

class Code;
class Exception;
class Type;

class ExecutionContext {
public:

	ExecutionContext(X86_64SectionHeader *pxiHeader, void *image, long long runtimeFlags);

	void enter();

	void prepareArgs(char **argv, int argc);

	int runNative(int (*start)(void *args));

	void registerHardwareExceptionHandler(void (*handler)(HardwareException *exceptionContext));

	bool hasHardwareExceptionHandler() {
		return _hardwareExceptionHandler != null;
	}

	void callHardwareExceptionHandler(HardwareException *info);

	byte *stackTop() { return _stackTop; }

	void setStackTop(void *p) {
		_stackTop = (byte*)p;
	}

	long long runtimeFlags() { return _runtimeFlags; }

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

	void *sourceLocations() {
		return _sourceLocations;
	}

	int sourceLocationsCount() {
		return _sourceLocationsCount;
	}

	ExecutionContext *clone();

	void setSourceLocations(void *location, int count);

	void setRuntimeFlags(long long runtimeFlags) { _runtimeFlags = runtimeFlags; }

	void *parasolThread(void *newThread);

private:
	int _target;
	byte *_stackTop;
	Exception *_exception;
	X86_64SectionHeader *_pxiHeader;
	void *_image;
	vector<string> _args;
	void (*_hardwareExceptionHandler)(HardwareException *info);
	void *_sourceLocations;
	int _sourceLocationsCount;
	long long _runtimeFlags;
	void *_parasolThread;
};

extern "C" {

int evalNative(X86_64SectionHeader *header, byte *image, char **argv, int argc);

void callAndSetFramePtr(void *newRbp, void *newRip, void *arg);

}

}

#endif
