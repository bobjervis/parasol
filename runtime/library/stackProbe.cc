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

/*
 * callAndSetFramePtr is a very specialized function that is used to call a catch handler with the correct RBP
 * value so that the generated code will do the right thing when it gets control. The arg in this case is the
 * pointer to the Exception object. Note that the catch handler will never return, so a jump is the correct way
 * to transfer control. Because the input values are all loaded up into registers in the X64 calling
 * conventions, the code is the same three instructions, but Windows uses a different set of instructions than
 * Linux does.
 */
#include "executionContext.h"
#include "threadSupport.h"

namespace parasol {

extern "C" {

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

}

}
