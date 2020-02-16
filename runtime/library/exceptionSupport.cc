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

}
