/*
   Copyright 2015 Rovert Jervis

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
	void *initialRbp = rbp;
	void *oldRbp;
	char *image = (char*)_image;
	ExceptionEntry *ee = (ExceptionEntry*)(image + _pxiHeader->exceptionsOffset);
	void *lowCode = image;
	void *highCode = image + _pxiHeader->builtInOffset;
	int (*comparator)(const void *ip, const void *elem) = comparatorCurrentIp;
	void *ip = state.frame.code;
	WORD *plausibleEnd = (WORD*)state.stackTop - 2;
	do {
		if (ip >= lowCode && ip < highCode) {
			int location = (int)((WORD)ip - (WORD)lowCode);
//			printf("location = %x\n", location);
			void *result = bsearch(&location, ee, _pxiHeader->exceptionsCount, sizeof (ExceptionEntry), comparator);

//			printf("location = %x result = %d\n", location, result != null ? (int)((ExceptionEntry*)result - ee) : -1);
			if (result != null) {
				ExceptionEntry *ee = (ExceptionEntry*)result;

				// If we have a handler, call it.
				if (ee->handler != 0) {
					void(*handler)(void*) = (void(*)(void*))((WORD)lowCode + ee->handler);

					ExceptionContext *ec = new ExceptionContext;
					ec->exceptionAddress = state.frame.code;
					ec->framePointer = initialRbp;
					ec->stackBase = state.sp;
					ec->stackPointer = state.sp;
					ec->stackSize = _stackSnapshot.size();
					ec->memoryAddress = state.memoryAddress;
					ec->exceptionFlags = state.exceptionFlags;
					ec->exceptionType = state.exceptionType;

					_exceptionContext = ec;

//					printf("Frame hit at %x: handler %p rbp %p\n", location, handler, rbp);
					setRbp(rbp);
					handler(ec);
					exit(1);
				} else {
					printf("No handler for %x\n", location);
					exit(1);
				}
			}
//		} else {
//			printf("Code address lies outside Parasol space: %p\n", ip);
//			exit(1);
		}
		oldRbp = rbp;
		ip = ((void**)rbp)[1];
		rbp = *(void**)rbp;
		comparator = comparatorReturnAddress;
	} while (rbp > oldRbp && rbp < plausibleEnd);
}

void ExecutionContext::throwException(const StackState &state) {
	// state.sp = current stack pointer.
	// state.frame.fp = current frame pointer.
	// state.frame.code = current ip.
	// state.stackTop = sp at evalNative call
	WORD *stack = (WORD*)state.sp;
//	for (int i = 0; i < 28; i++)
//		printf("[%2x] %p\n", i, stack[i]);

	char *image = (char*)_image;
	ExceptionEntry *ee = (ExceptionEntry*)(image + _pxiHeader->exceptionsOffset);

	if (_pxiHeader->exceptionsCount == 0) {
		printf("No entries in exception table (at %p [%d])\n", ee, _pxiHeader->exceptionsCount);
		exit(1);
	}
//	for (int i = 0; i < exceptionTable->length; i++)
//		printf("%d: [%x, %x]\n", i, exceptionTable->entries[i].location, exceptionTable->entries[i].handler);

	void *rbp = state.frame.fp;

//	printf("Exception table:\n");
//	for (int i = 0; i < _pxiHeader->exceptionsCount; i++)
//		printf("[%p] -> %p\n", ee[i].location, ee[i].handler);
	WORD *searchEnd = (WORD*)state.stackTop - 2;
	if (rbp < stack || rbp >= searchEnd) {
		// try to find a plausible RBP value.
//		printf("Searching within [%p - %p]\n", stack, searchEnd);
		for (WORD *rbpCandidate = (WORD*)stack; rbpCandidate < searchEnd; rbpCandidate++)
			crawlStack(state, rbpCandidate);
	} else
		crawlStack(state, rbp);
	printf("RBP %p is out of stack range [%p - %p] ip %p\n", state.frame.fp, state.sp, state.stackTop, state.frame.code);
	exit(1);
}

}
