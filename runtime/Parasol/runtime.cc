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

#include <new>
#include <cstring>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef MSVC
#include <typeinfo.h>
#else
#include <typeinfo>
#endif
#include <exception>
#include <time.h>
#if defined(__WIN64)
#include <windows.h>
#elif __linux__
typedef unsigned long long SIZE_T;
typedef unsigned DWORD;
typedef int BOOL;
#include <signal.h>
#endif
#include "common/process.h"
#include "basic_types.h"

namespace parasol {

#define MEM_VALID(x) if ((unsigned long long)(x) < 0x10000) { printf("Invalid memory address: %p\n", (x)); fflush(stdout); return false; }

class BuiltInFunctionMap {
public:
	const char *name;
	WORD (*func)();
	int args;
	int returns;
	const char *domain;
};

extern BuiltInFunctionMap builtInFunctionMap[];

#if __linux__
static __thread ExecutionContext *_threadContextValue;
#endif

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
};

static ThreadContext threadContext;

static int varCompare(byte *left, byte *right);
// Results stored in left:
static void varAdd(byte *left, byte *right);
static void varSub(byte *left, byte *right);
static void varMul(byte *left, byte *right);
static void varDiv(byte *left, byte *right);
static void varRem(byte *left, byte *right);
static void varRsh(byte *left, byte *right);
static void varLsh(byte *left, byte *right);
static void varUrs(byte *left, byte *right);
static void varAnd(byte *left, byte *right);
static void varOr(byte *left, byte *right);
static void varXor(byte *left, byte *right);
static void *varInvoke(int object, int method);

char ParasolStringParameter::dummy;

ExecutionContext::ExecutionContext(void **objects, int objectCount) {
	_length = STACK_SIZE;
	_stack = (byte*)malloc(STACK_SIZE);
	_sp = _stack + STACK_SIZE;
	_exception = null;
	_stackTop = _sp;
	_active.code = null;
	_active.ip = 0;
	_lastIp = 0;
	_objects = objects;
	_objectCount = objectCount;
	_target = -1;
	_image = null;
	_hardwareExceptionHandler = null;
	_sourceLocations = null;
	_sourceLocationsCount = 0;
	_pxiHeader = null;
	_runtimeFlags = 0;
	trace = false;
}

ExecutionContext::ExecutionContext(X86_64SectionHeader *pxiHeader, void *image, long long runtimeFlags) {
	_length = 2 * sizeof (void*);
	_stack = (byte*)malloc(_length);
	_sp = _stack + _length;
	_exception = null;
	_stackTop = _sp;
	_active.code = null;
	_active.ip = 0;
	_lastIp = 0;
	_objects = null;
	_objectCount = 0;
	_target = -1;
	_pxiHeader = pxiHeader;
	_image = image;
	_hardwareExceptionHandler = null;
	_sourceLocations = null;
	_sourceLocationsCount = 0;
	_runtimeFlags = runtimeFlags;
	trace = false;
}

ExecutionContext::~ExecutionContext() {
	free(_stack);
}

void ExecutionContext::enter() {
	_target = NATIVE_64_TARGET;
	threadContext.set(this);
}

bool ExecutionContext::push(WORD intValue) {
	if (_sp - sizeof(WORD) < _stack)
		return false;
	_sp -= sizeof(WORD);
	*((WORD*)_sp) = intValue;
	return true;
}

void ExecutionContext::push(char **argv, int argc){
	_args.clear();
	for (int i = 0; i < argc; i++)
		_args.push_back(string(argv[i]));
	push(&_args[0]);		// Arguments are a string array.
	push(((WORD)_args.size() << 32) | _args.size());
}

bool ExecutionContext::push(void *pointerValue) {
	if (_sp - sizeof(WORD) < _stack)
		return false;
	_sp -= sizeof(WORD);
	*((void**)_sp) = pointerValue;
	return true;
}

WORD ExecutionContext::pop() {
	WORD i = *((WORD*)_sp);
	_sp += sizeof(WORD);
	return i;
}

WORD ExecutionContext::peek() {
	return *((WORD*)_sp);
}

WORD ExecutionContext::st(int index) {
	return ((WORD*)_sp)[index];
}

void *ExecutionContext::popAddress() {
	void *vp = *((void**)_sp);
	_sp += sizeof(void*);
	return vp;
}

void *ExecutionContext::peekAddress() {
	return *((void**)_sp);
}
#if 0
extern "C" {

CALLBACK long my_exception_handler(EXCEPTION_POINTERS * exception_data) {
	throw *exception_data->ExceptionRecord;
}

}
#endif

static int injectObjects(void **objects, int objectCount) {
	ExecutionContext *context = threadContext.get();
	return context->injectObjects(objects, objectCount);
}

void xxdump(byte *x, int len, int match) {
	printf("     0 ");
	for (int i = 0; i < len; i++) {
		if (i >= len)
			break;
		printf("%c%02x", i == match ? '*' : ' ', x[i]);
		if (((i + 1) & 0xf) == 0)
			printf("\n  %4d ", i + 1);
	}
	printf("\n");
}

void stackDump(ExecutionContext *context) {
	printf("  Stack %p sp %p fp %p\n", context->stack(), context->sp(), context->fp());
	xxdump(context->sp(), 128, context->fp() - context->sp());
}

static int eval(int startObject, char **argv, int argc, byte** exceptionInfo) {
/*
	printf("In eval(%d, [", startObject);
	for (int i = 0; i < argc; i++) {
		if (i > 0)
			printf(",");
		printf(" \"%s\"", argv[i]);
	}
	printf(" ], %d)\n", argc);
*/
	ExecutionContext *context = threadContext.get();
	StackState outer = context->unloadFrame();
	context->push(argv, argc);
	bool result = context->run(startObject);
	if (result) {
		WORD result = context->pop();
		context->reloadFrame(outer);
		return result;
	} else {
		StackState exceptionState = context->unloadFrame();
		exceptionInfo[0] = exceptionState.frame.code;
		exceptionInfo[1] = (byte*) (WORD) context->lastIp();
		exceptionInfo[2] = exceptionState.frame.fp;
		exceptionInfo[3] = exceptionState.sp;
		exceptionInfo[4] = exceptionState.stack;
		exceptionInfo[5] = outer.sp;
		context->reloadFrame(outer);
		return INT_MIN;
	}
}

int evalNative(X86_64SectionHeader *header, byte *image, char **argv, int argc) {
	ExecutionContext *outer = threadContext.get();
	ExecutionContext context(header, image, outer->runtimeFlags());

	threadContext.set(&context);
//	StackState outer = context->unloadFrame();
	int (*start)(void *args) = (int (*)(void*))(image + header->entryPoint);
	context.push(argv, argc);
	context.setSourceLocations(outer->sourceLocations(), outer->sourceLocationsCount());
	int result = context.runNative(start);

	// Transfer any uncaught exception to the outer context.

	Exception *e = context.exception();
	outer->exposeException(e);
	threadContext.set(outer);
//	context->reloadFrame(outer);
	return result;
}

static int setTrace(int newValue) {
	ExecutionContext *context = threadContext.get();
	bool oldValue = context->trace;
	context->trace = (bool) newValue;
//	printf("setTrace(%s) -> %s\n", newValue ? "true" : "false", oldValue ? "true" : "false");
//	context->print();
	return (int) oldValue;
}

StackState ExecutionContext::unloadFrame() {
	StackState ss;
	ss.frame = _active;
	ss.sp = _sp;
	ss.stack = _stack;
	ss.stackTop = _stackTop;
	ss.target = _target;
	memset(&_active, 0, sizeof _active);
	return ss;
}

bool ExecutionContext::run(int objectId) {
	if (trace)
		printf("Entering [%d]\n", objectId);
	if (objectId < 0 || objectId >= _objectCount) {
		if (trace)
			printf("   out of range [0-%d]\n", _objectCount - 1);
		return false;
	}
	ExecutionContext *outer = threadContext.get();
	_target = BYTE_CODE_TARGET;
	threadContext.set(this);
	invoke((byte*)valueAddress(objectId));
	_lastIp = 0;
	bool result;

	threadContext.set(outer);
	return result;
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
	}
	printf("No hardware exception handler defined\n");
	exit(1);
	return 0;
}
#elif __linux__
static void fillExceptionInfo(HardwareException *he, siginfo_t *info, ucontext *uContext) {
	he->codePointer = (byte*)uContext->uc_mcontext.gregs[REG_RIP];
	he->framePointer = (byte*)uContext->uc_mcontext.gregs[REG_RBP];
	he->stackPointer = (byte*)uContext->uc_mcontext.gregs[REG_RSP];
	he->exceptionType = (info->si_signo << 8) + (info->si_code & ~SI_KERNEL);
}

void sigIllHandler(int signum, siginfo_t *info, void *uContext) {
	ExecutionContext *context = threadContext.get();

	if (context->hasHardwareExceptionHandler()) {
		HardwareException he;

		fillExceptionInfo(&he, info, (ucontext*)uContext);
		he.exceptionInfo0 = 0;
		he.exceptionInfo1 = 0;
		context->callHardwareExceptionHandler(&he);
		printf("Did not expect this to return\n");
	}
	printf("No hardware exception handler defined\n");
	exit(1);
}

void sigSegvHandler(int signum, siginfo_t *info, void *uContext) {
	ExecutionContext *context = threadContext.get();

	if (context->hasHardwareExceptionHandler()) {
		HardwareException he;

		fillExceptionInfo(&he, info, (ucontext*)uContext);
		he.exceptionInfo0 = (long long)info->si_addr;
		he.exceptionInfo1 = 0;
		context->callHardwareExceptionHandler(&he);
		printf("Did not expect this to return\n");
	}
	printf("No hardware exception handler defined\n");
	exit(1);
}

void sigFpeHandler(int signum, siginfo_t *info, void *uContext) {
	ExecutionContext *context = threadContext.get();

	if (context->hasHardwareExceptionHandler()) {
		HardwareException he;

		fillExceptionInfo(&he, info, (ucontext*)uContext);
		he.exceptionInfo0 = 0;
		he.exceptionInfo1 = 0;
		context->callHardwareExceptionHandler(&he);
		printf("Did not expect this to return\n");
	}
	printf("No hardware exception handler defined\n");
	exit(1);
}
#endif

int ExecutionContext::runNative(int (*start)(void *args)) {
	_target = NATIVE_64_TARGET;
	byte *x;
	_stackTop = (byte*) &x;
#if defined(__WIN64)
	PVOID handle = AddVectoredExceptionHandler(0, windowsExceptionHandler);
#elif __linux__
	struct sigaction oldSigIllAction;
	struct sigaction oldSigSegvAction;
	struct sigaction oldSigFpeAction;
	struct sigaction newIllAction;
	struct sigaction newSegvAction;
	struct sigaction newFpeAction;

	newIllAction.sa_sigaction = sigIllHandler;
	newIllAction.sa_flags = SA_SIGINFO;
	newSegvAction.sa_sigaction = sigSegvHandler;
	newSegvAction.sa_flags = SA_SIGINFO;
	newFpeAction.sa_sigaction = sigFpeHandler;
	newFpeAction.sa_flags = SA_SIGINFO;
	sigaction(SIGILL, &newIllAction, &oldSigIllAction);
	sigaction(SIGSEGV, &newSegvAction, &oldSigSegvAction);
	sigaction(SIGFPE, &newFpeAction, &oldSigFpeAction);
#endif
	int result = start(_sp);
#if defined(__WIN64)
	RemoveVectoredExceptionHandler(handle);
#elif __linux__
	sigaction(SIGILL, &oldSigIllAction, null);
	sigaction(SIGSEGV, &oldSigSegvAction, null);
	sigaction(SIGFPE, &oldSigFpeAction, null);
#endif
	return result;
}

void ExecutionContext::reloadFrame(const StackState &saved) {
	_active = saved.frame;
	_sp = saved.sp;
	_stack = saved.stack;
	_stackTop = saved.stackTop;
	_target = saved.target;
//	printf ("_target = %d\n", _target);
}

int ExecutionContext::injectObjects(void **objects, int objectCount) {
	int result = _objectCount;
	if (objectCount > 0) {
		int total = _objectCount + objectCount;
		void **newObjects = (void**)malloc(total * sizeof (void*));
		memcpy(newObjects, _objects, _objectCount * sizeof (void*));
		memcpy(newObjects + _objectCount, objects, objectCount * sizeof (void*));
		_objects = newObjects;
		_objectCount += objectCount;
	}
	return result;
}

void ExecutionContext::halt() {
	_active.ip = -1;
}

void ExecutionContext::invoke(byte *code) {
	push(_active.ip);
	push(_active.code);
	push(_active.fp);
	_active.code = code;
	_active.fp = _sp;
	_active.ip = 0;
}

void ExecutionContext::print() {
	printf("%d objects sp = %p (%ld) fp = %p (%ld) \n", _objectCount, _sp, _sp - _stack, _active.fp, _active.fp - _stack);
	printf("ip = %d code = %p _lastIp = %d\n", _active.ip, _active.code, _lastIp);
}

bool ExecutionContext::run() {
	return false;
}

void *ExecutionContext::valueAddress(int i) {
	return _objects[i];
}

int ExecutionContext::valueIndex(void *address) {
	for (int i = 0; i < _objectCount; i++)
		if (_objects[i] == address)
			return i;
	return -1;
}

int builtInPrint(int *ptr) {
	ParasolStringParameter *format = (ParasolStringParameter*)&ptr;
	int count = 0;
	for (int i = 0; i < format->size(); i++) {
		count++;
		putchar((*format)[i]);
	}
	fflush(stdout);
	return count;
}

int builtInAssert(int booleanValue) {
	return 0;
}

void *builtInMalloc(int size) {
	return malloc(size);
}

int builtInFree(void *p) {
	free(p);
	return 0;
}

void *builtInMemcpy(void *dest, void *src, int size) {
	return memcpy(dest, src, size);
}
#if 0
void *builtinVirtualAlloc(void *lpAddress, SIZE_T sz, DWORD flAllocationType, DWORD flProtect) {
#if defined(__WIN64)
	return VirtualAlloc(lpAddress, sz, flAllocationType, flProtect);
#elif __linux__
	return null;
#endif
}

BOOL builtinVirtualProtect(void *lpAddress, SIZE_T sz, DWORD flNewProtect, DWORD *lpflOldProtect) {
#if defined(__WIN64)
	return VirtualProtect(lpAddress, sz, flNewProtect, lpflOldProtect);
#elif __linux__
	return 0;
#endif
}

unsigned builtinGetLastError() {
#if defined(__WIN64)
	return GetLastError();
#elif __linux__
	return 0;
#endif
}

bool Variant::equals(Variant &other) const {
	if (_kind != other._kind)
		return false;
	return _value.integer == other._value.integer;
}

void Variant::clear() {
	// TODO: CLean up allocated memory
	_kind = null;
	_value.integer = 0;
}

void Variant::init(const Variant& source) {
	_kind = source._kind;
//	switch (_kind->family()) {
//	case	TF_STRING:
//		new((void*)&_value.pointer) string(*(string*)&source._value.pointer);
//		break;

//	default:
		// This will copy the necessary bits without altering them.
		_value.integer = source._value.integer;
//	}
}

static int varCompare(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;

	if (left->kind() != right->kind()) {
		return INT_MIN;
	}
	long long diff = left->asLong() - right->asLong();
	if (diff < 0)
		return -1;
	else if (diff > 0)
		return 1;
	else
		return 0;
}

static void varAdd(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() + right->asLong();
	left->setLong(val);
}

static void varSub(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() - right->asLong();
	left->setLong(val);
}

static void varMul(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() * right->asLong();
	left->setLong(val);
}

static void varDiv(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() / right->asLong();
	left->setLong(val);
}

static void varRem(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() % right->asLong();
	left->setLong(val);
}

static void varRsh(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() >> right->asLong();
	left->setLong(val);
}

static void varLsh(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() << right->asLong();
	left->setLong(val);
}

static void varUrs(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = (unsigned long long)left->asLong() >> right->asLong();
	left->setLong(val);
}

static void varAnd(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() & right->asLong();
	left->setLong(val);
}

static void varOr(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() | right->asLong();
	left->setLong(val);
}

static void varXor(byte *bLeft, byte *bRight) {
	Variant *left = (Variant*)bLeft;
	Variant *right = (Variant*)bRight;
	long long val = left->asLong() ^ right->asLong();
	left->setLong(val);
}

static void *varInvoke(int methodName, int object) {
	return null;
}
#endif
#define nativeFunction(f) ((WORD(*)())f)

#if 0
static void *fMemcpy(void *dest, void *src, size_t len) {
	return memcpy(dest, src, len);
}

static void *fMemset(void *dest, char c, size_t len) {
	return memset(dest, c, len);
}
#endif

struct SpawnPayload {
	const char *buffer;
	int length;
	process::exception_t outcome;
};

static int processDebugSpawn(char *command, SpawnPayload *output, long long timeout) {
	string out;
	string cmd(command);

	int result = process::debugSpawn(cmd, &out, &output->outcome, (time_t)timeout);
	char *capture = new char[out.size()];
	output->buffer = capture;
	output->length = out.size();
	memcpy(capture, out.c_str(), out.size());
	return result;
}

static void disposeOfPayload(SpawnPayload *output) {
	delete[] output->buffer;
}

static int supportedTarget(int index) {
	switch (index) {
#if defined(__WIN64)
	case 0:			return ST_X86_64_WIN;
#elif __linux__
	case 0:			return ST_X86_64_LNX;
#endif
	default:		return -1;
	}
}

static int runningTarget() {
	ExecutionContext *context = threadContext.get();
	switch (context->target()) {
#if defined(__WIN64)
	case NATIVE_64_TARGET:		return ST_X86_64_WIN;
#elif __linux__
	case NATIVE_64_TARGET:		return ST_X86_64_LNX;
#endif
	default:					return -1;
	}
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

void ExecutionContext::callHardwareExceptionHandler(HardwareException *info) {
	_hardwareExceptionHandler(info);
}

byte *stackTop() {
	ExecutionContext *context = threadContext.get();
	return context->stackTop();
}

void *exceptionsAddress() {
	ExecutionContext *context = threadContext.get();
	return context->exceptionsAddress();
}

int exceptionsCount() {
	ExecutionContext *context = threadContext.get();
	return context->exceptionsCount();
}

long long getRuntimeFlags() {
	ExecutionContext *context = threadContext.get();
	return context->runtimeFlags();
}

byte *lowCodeAddress() {
	ExecutionContext *context = threadContext.get();
	return context->lowCodeAddress();
}

byte *highCodeAddress() {
	ExecutionContext *context = threadContext.get();
	return context->highCodeAddress();
}

void callCatchHandler(Exception *exception, void *framePointer, int handler) {
	ExecutionContext *context = threadContext.get();
	context->callCatchHandler(exception, framePointer, handler);
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

void ExecutionContext::setSourceLocations(void *location, int count) {
	_sourceLocations = location;
	_sourceLocationsCount = count;
}

ExecutionContext *ExecutionContext::clone() {
	ExecutionContext *newContext;
	if (_target == BYTE_CODE_TARGET)
		newContext = new ExecutionContext(null, 0);
	else
		newContext = new ExecutionContext(_pxiHeader, _image, _runtimeFlags);
	newContext->_target = _target;
	newContext->_hardwareExceptionHandler = _hardwareExceptionHandler;
	newContext->_sourceLocations = _sourceLocations;
	newContext->_sourceLocationsCount = _sourceLocationsCount;
	return newContext;
}

void enterThread(ExecutionContext *newContext, void *stackTop) {
	threadContext.set(newContext);
	newContext->setStackTop(stackTop);
}

void exitThread() {
	ExecutionContext *context = threadContext.get();
	if (context != null) {
		threadContext.set(null);
		delete context;
	}
}

ExecutionContext *dupExecutionContext() {
	ExecutionContext *context = threadContext.get();
	return context->clone();
}

BuiltInFunctionMap builtInFunctionMap[] = {
	{ "print",								nativeFunction(builtInPrint),						1,	1 },
	{ "formatMessage",						nativeFunction(formatMessage),						1,	1, "native" },
	{ "sourceLocations",					nativeFunction(sourceLocations),					1,	0, "parasol" },
	{ "sourceLocationsCount",				nativeFunction(sourceLocationsCount),				1,	0, "parasol" },
	{ "setSourceLocations",					nativeFunction(setSourceLocations),					0,	2, "parasol" },
	{ "builtInFunctionArguments",			nativeFunction(builtInFunctionArguments),			1,	1, "parasol" },
	{ "builtInFunctionName",				nativeFunction(builtInFunctionName),				1,	1, "parasol" },
	{ "builtInFunctionDomain",				nativeFunction(builtInFunctionDomain),				1,	1, "parasol" },
	{ "builtInFunctionReturns",				nativeFunction(builtInFunctionReturns),				1,	1, "parasol" },
	{ "builtInFunctionAddress",				nativeFunction(builtInFunctionAddress),				1,	1, "parasol" },
	{ "fetchExposedException",				nativeFunction(fetchExposedException),				0,	1, "parasol" },
	{ "exposeException",					nativeFunction(exposeException),					1,	1, "parasol" },
	{ "callCatchHandler",					nativeFunction(callCatchHandler),					3,	0, "parasol" },
	{ "registerHardwareExceptionHandler",	nativeFunction(registerHardwareExceptionHandler),	1,	0, "parasol" },
	{ "exceptionsCount",					nativeFunction(exceptionsCount),					0,	1, "parasol" },
	{ "exceptionsAddress",					nativeFunction(exceptionsAddress),					0,	1, "parasol" },
	{ "stackTop",							nativeFunction(stackTop),							0,	1, "parasol" },
	{ "lowCodeAddress",						nativeFunction(lowCodeAddress),						0,	1, "parasol" },
	{ "highCodeAddress",					nativeFunction(highCodeAddress),					0,	1, "parasol" },
	{ "getRuntimeFlags",					nativeFunction(getRuntimeFlags),					0,	1, "parasol" },
	{ "supportedTarget",					nativeFunction(supportedTarget),					1,	1, "parasol" },

	{ "runningTarget",  					nativeFunction(runningTarget), 						0,  1, "parasol" },
	{ "injectObjects",						nativeFunction(injectObjects),						2,	1, "parasol" },
	{ "setTrace",							nativeFunction(setTrace),							1,	1, "parasol" },
	{ "eval",								nativeFunction(eval),								4,	1, "parasol" },
	{ "evalNative",							nativeFunction(evalNative),							4,	1, "parasol" },
	{ "debugSpawnImpl", 					nativeFunction(processDebugSpawn),					3,	1, "parasol" },
	{ "disposeOfPayload",					nativeFunction(disposeOfPayload),					1,	0, "parasol" },

	{ "enterThread",						nativeFunction(enterThread),						2,	0, "parasol" },
	{ "exitThread",							nativeFunction(exitThread),							0,	0, "parasol" },
	{ "dupExecutionContext",				nativeFunction(dupExecutionContext),				0,	1, "parasol" },
	{ 0 }
};

const char *builtInFunctionName(int index) {
	if (index < (int) (sizeof builtInFunctionMap / sizeof builtInFunctionMap[0])) {
		return builtInFunctionMap[index].name;
	} else
		return null;
}

const char *builtInFunctionDomain(int index) {
	return builtInFunctionMap[index].domain;
}

WORD (*builtInFunctionAddress(int index))() {
	return builtInFunctionMap[index].func;
}

int builtInFunctionArguments(int index) {
	return builtInFunctionMap[index].args;
}

int builtInFunctionReturns(int index) {
	return builtInFunctionMap[index].returns;
}

void ExecutionContext::disassemble(int ip) {
}

}
