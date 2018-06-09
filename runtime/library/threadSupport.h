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
#ifndef _TARGET_SUPPORT_H
#define _TARGET_SUPPORT_H
#include "executionContext.h"

namespace parasol {

class ThreadContext {
public:
	ThreadContext() {
#if defined(__WIN64)
		_slot = TlsAlloc();
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

}

#endif

