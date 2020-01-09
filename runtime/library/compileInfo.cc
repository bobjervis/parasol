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

namespace parasol {

extern "C" {

void *exceptionsAddress() {
	ExecutionContext *context = threadContext.get();
	return context->exceptionsAddress();
}

int exceptionsCount() {
	ExecutionContext *context = threadContext.get();
	return context->exceptionsCount();
}

byte *lowCodeAddress() {
	ExecutionContext *context = threadContext.get();
	return context->lowCodeAddress();
}

byte *highCodeAddress() {
	ExecutionContext *context = threadContext.get();
	return context->highCodeAddress();
}

void *getRuntimeParameter(int i) {
	ExecutionContext *context = threadContext.get();
	if (context == null)
		return null;
	else
		return context->getRuntimeParameter(i);
}

void setRuntimeParameter(int i, void *newValue) {
	ExecutionContext *context = threadContext.get();
	if (context != null)
		context->setRuntimeParameter(i, newValue);
}

}

}
