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

void *sourceLocations() {
	ExecutionContext *context = threadContext.get();
	return context->sourceLocations();
}

int sourceLocationsCount() {
	ExecutionContext *context = threadContext.get();
	return context->sourceLocationsCount();
}

void setSourceLocations(void *location, int count) {
	ExecutionContext *context = threadContext.get();
	context->setSourceLocations(location, count);
}

long long getRuntimeFlags() {
	ExecutionContext *context = threadContext.get();
	return context->runtimeFlags();
}

long long setRuntimeFlags(long long flags) {
	ExecutionContext *context = threadContext.get();
	long long x = context->runtimeFlags();
	context->setRuntimeFlags(flags);
	return x;
}

}

}
