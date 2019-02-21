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
#include "exceptionSupport.h"
#include "threadSupport.h"
#if defined(__WIN64)
#include <windows.h>
#elif __linux__
#include <signal.h>
#endif

namespace parasol {

extern "C" {

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

void registerHardwareExceptionHandler(void (*handler)(HardwareException*)) {
	ExecutionContext *context = threadContext.get();
	context->registerHardwareExceptionHandler(handler);
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

}

#if defined(__WIN64)
LONG CALLBACK windowsExceptionHandler(PEXCEPTION_POINTERS ExceptionInfo) {
	ExecutionContext *context = threadContext.get();

	if (context->hasHardwareExceptionHandler()) {
		HardwareException info;

		info.codePointer = (byte*)ExceptionInfo->ContextRecord->Rip;
		info.framePointer = (byte*)ExceptionInfo->ContextRecord->Rbp;
		info.stackPointer = (byte*)ExceptionInfo->ContextRecord->Rsp;
		info.exceptionType = ExceptionInfo->ExceptionRecord->ExceptionCode;
		switch (ExceptionInfo->ExceptionRecord->ExceptionCode) {
		case EXCEPTION_ACCESS_VIOLATION:
		case EXCEPTION_IN_PAGE_ERROR:
			info.exceptionInfo0 = (long long)ExceptionInfo->ExceptionRecord->ExceptionInformation[1];
			info.exceptionInfo1 = (int)ExceptionInfo->ExceptionRecord->ExceptionInformation[0];
		}
		context->callHardwareExceptionHandler(&info);
		printf("Did not expect this to return\n");
		exit(1);
	}
	printf("No hardware exception handler defined\n");
	exit(1);
	return 0;
}

// These are not really Parasol callable, so put them in C++ linkage.

#elif __linux__
static void fillExceptionInfo(HardwareException *he, siginfo_t *info, ucontext *uContext) {
	he->codePointer = (byte*)uContext->uc_mcontext.gregs[REG_RIP];
	he->framePointer = (byte*)uContext->uc_mcontext.gregs[REG_RBP];
	he->stackPointer = (byte*)uContext->uc_mcontext.gregs[REG_RSP];
	he->exceptionType = (info->si_signo << 8) + info->si_code;
	he->exceptionInfo1 = info->si_errno;
}

void sigGeneralHandler(int signum, siginfo_t *info, void *uContext) {
	ExecutionContext *context = threadContext.get();

	if (context != null && context->hasHardwareExceptionHandler()) {
		HardwareException he;

		fillExceptionInfo(&he, info, (ucontext*)uContext);
		he.exceptionInfo0 = 0;
		context->callHardwareExceptionHandler(&he);
		// Most exception handlers throw an exception and crash out elsewhere.
		// But, the SIGTERM handler allows for a user-defined interruptr handler.
		return;
	}
	printf("No hardware exception handler defined\n");
	exit(1);
}

void sigSegvHandler(int signum, siginfo_t *info, void *uContext) {
	ExecutionContext *context = threadContext.get();

	if (context != null && context->hasHardwareExceptionHandler()) {
		HardwareException he;

		fillExceptionInfo(&he, info, (ucontext*)uContext);
		he.exceptionInfo0 = (long long)info->si_addr;
		context->callHardwareExceptionHandler(&he);
		printf("Did not expect this to return\n");
		exit(1);
	}
	printf("No hardware exception handler defined\n");
	exit(1);
}
#endif

}
