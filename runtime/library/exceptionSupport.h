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
#ifndef EXCEPTION_SUPPORT_H
#define EXCEPTION_SUPPORT_H

#include "common/machine.h"

namespace parasol {

class Exception;

struct HardwareException {
	void *codePointer;
	void *framePointer;
	void *stackPointer;
	long long exceptionInfo0;
	int exceptionInfo1;
	int exceptionType;
};

struct StackFrame {
	byte *fp;
	byte *code;
	int ip;
};

struct StackState {
	byte *sp;
	byte *stack;
	byte *stackTop;
	Exception *parasolException;
	StackFrame frame;
	int target;
	int exceptionType;
	int exceptionFlags;
	void *memoryAddress;			// Valid only for memory exceptions
};

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

class ExceptionInfo {

};

class Exception {
public:
	void *vtable;
};

}

#endif
