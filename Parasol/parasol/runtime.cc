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
#include <windows.h>
#include "common/process.h"
#include "basic_types.h"

namespace parasol {

#define MEM_VALID(x) if ((unsigned long long)(x) < 0x10000) { printf("Invalid memory address: %p\n", (x)); fflush(stdout); return false; }

static pxi::Section *byteCodeSectionReader(FILE *pxiFile, long long length);

class BuiltInFunctionMap {
public:
	const char *name;
	WORD (*func)();
	int args;
	int returns;
	const char *domain;
};

extern BuiltInFunctionMap builtInFunctionMap[];

class ThreadContext {
public:
	ThreadContext() {
		_slot = TlsAlloc();
	}

	bool set(ExecutionContext *value) {
		if (TlsSetValue(_slot, value))
			return true;
		else
			return false;
	}

	ExecutionContext *get() {
		return (ExecutionContext*)TlsGetValue(_slot);
	}

private:
	DWORD	_slot;
};

ByteCodeMap::ByteCodeMap() {
	name[B_ILLEGAL] = "<invalid byte code>";
	name[B_INT] = "int";
	name[B_LONG] = "long";
	name[B_STRING] = "string";
	name[B_CALL] = "call";
	name[B_XCALL] = "call.ext";
	name[B_ICALL] = "call.ind";
	name[B_VCALL] = "call.virt";
	name[B_INVOKE] = "invoke";
	name[B_CHKSTK] = "chkstk";
	name[B_SP] = "push";
	name[B_LOCALS] = "locals";
	name[B_VARG] = "varg";
	name[B_VARG1] = "varg1";
	name[B_POP] = "pop";
	name[B_POPN] = "pop";
	name[B_DUP] = "dup";
	name[B_SWAP] = "swap";
	name[B_RET] = "ret";
	name[B_RET1] = "ret1";
	name[B_RETN] = "ret";
	name[B_STSA] = "st.addr";
	name[B_LDSA] = "ld.addr";
	name[B_STSB] = "st.byte";
	name[B_LDSB] = "ld.byte";
	name[B_STSC] = "st.char";
	name[B_LDSC] = "ld.char";
	name[B_STSI] = "st.int";
	name[B_LDSI] = "ld.int";
	name[B_LDSU] = "ld.uns";
	name[B_STSS] = "st.shrt";
	name[B_LDSS] = "ld.shrt";
	name[B_STAA] = "st.addr";
	name[B_LDAA] = "ld.addr";
	name[B_STAB] = "st.byte";
	name[B_STSO] = "st.obj";
	name[B_LDAB] = "ld.byte";
	name[B_LDAC] = "ld.char";
	name[B_STAS] = "st.shrt";
	name[B_LDAS] = "ld.shrt";
	name[B_STAI] = "st.int";
	name[B_LDAI] = "ld.int";
	name[B_LDAU] = "ld.uns";
	name[B_LDAO] = "ld.obj";
	name[B_STAO] = "st.obj";
	name[B_STAV] = "st.var";
	name[B_STVA] = "st.addr";
	name[B_STVB] = "st.byte";
	name[B_STVI] = "st.int";
	name[B_STVS] = "st.shrt";
	name[B_STVO] = "st.obj";
	name[B_STVV] = "st.var";
	name[B_LDPA] = "ld.addr";
	name[B_STPA] = "st.addr";
	name[B_LDPB] = "ld.byte";
	name[B_STPB] = "st.byte";
	name[B_LDPC] = "ld.char";
	name[B_STPS] = "st.shrt";
	name[B_LDPS] = "ld.shrt";
	name[B_LDPI] = "ld.int";
	name[B_LDPL] = "ld.long";
	name[B_STPL] = "st.long";
	name[B_LDPU] = "ld.uns";
	name[B_STPI] = "st.int";
	name[B_LDPO] = "ld.obj";
	name[B_STPO] = "st.obj";
	name[B_LDIA] = "ld.addr";
	name[B_LDTR] = "ld.class";
	name[B_STIA] = "st.addr";
	name[B_POPIA] = "st.pop";
	name[B_LDIB] = "ld.byte",
	name[B_STIB] = "st.byte",
	name[B_LDIC] = "ld.char";
	name[B_STIC] = "st.char";
	name[B_LDII] = "ld.int";
	name[B_STII] = "st.int";
	name[B_LDIL] = "ld.long";
	name[B_STIL] = "st.long";
	name[B_LDIU] = "ld.uns";
	name[B_LDIO] = "ld.obj";
	name[B_STIO] = "st.obj";
	name[B_LDIV] = "ld.var";
	name[B_STIV] = "st.var";
	name[B_THROW] = "throw";
	name[B_NEW] = "new";
	name[B_DELETE] = "delete";
	name[B_ADDR] = "addr";
	name[B_AUTO] = "auto";
	name[B_AVARG] = "auto";
	name[B_ZERO_A] = "zero.addr";
	name[B_ZERO_I] = "zero";
	name[B_PARAMS] = "parms";
	name[B_VALUE] = "value";
	name[B_CHAR_AT] = "char.at";
	name[B_CLASSV] = "class.var";
	name[B_ASTRING] = "addr";
	name[B_NEG] = "neg.int";
	name[B_BCM] = "bcm.int";
	name[B_MUL] = "mul.int";
	name[B_DIV] = "div.int";
	name[B_REM] = "rem.int";
	name[B_ADD] = "add.int";
	name[B_SUB] = "sub.int";
	name[B_LSH] = "lsh.int";
	name[B_RSH] = "rsh.int";
	name[B_URS] = "urs.int";
	name[B_OR] = "or.int";
	name[B_AND] = "and.int";
	name[B_XOR] = "xor.int";
	name[B_MULV] = "mul.var";
	name[B_DIVV] = "div.var";
	name[B_REMV] = "rem.var";
	name[B_ADDV] = "add.var";
	name[B_SUBV] = "sub.var";
	name[B_LSHV] = "lsh.var";
	name[B_RSHV] = "rsh.var";
	name[B_URSV] = "urs.var";
	name[B_ORV] = "or.var";
	name[B_ANDV] = "and.var";
	name[B_XORV] = "xor.var";
	name[B_NOT] = "not.int";
	name[B_EQI] = "eq.int";
	name[B_NEI] = "ne.int";
	name[B_GTI] = "gt.int";
	name[B_GEI] = "ge.int";
	name[B_LTI] = "lt.int";
	name[B_LEI] = "le.int";
	name[B_GTU] = "gt.uns";
	name[B_GEU] = "ge.uns";
	name[B_LTU] = "lt.uns";
	name[B_LEU] = "le.uns";
	name[B_EQL] = "eq.long";
	name[B_NEL] = "ne.long";
	name[B_GTL] = "gt.long";
	name[B_GEL] = "ge.long";
	name[B_LTL] = "lt.long";
	name[B_LEL] = "le.long";
	name[B_GTA] = "gt.addr";
	name[B_GEA] = "ge.addr";
	name[B_LTA] = "lt.addr";
	name[B_LEA] = "le.addr";
	name[B_EQV] = "eq.var";
	name[B_NEV] = "ne.var";
	name[B_GTV] = "gt.var";
	name[B_GEV] = "ge.var";
	name[B_LTV] = "lt.var";
	name[B_LEV] = "le.var";
	name[B_LGV] = "lg.var";
	name[B_NGV] = "ng.var";
	name[B_NGEV] = "nge.var";
	name[B_NLV] = "nl.var";
	name[B_NLEV] = "nle.var";
	name[B_NLGV] = "nlg.var";
	name[B_CVTBI] = "cvt.bi";
	name[B_CVTCI] = "cvt.usi";
	name[B_CVTIL] = "cvt.il";
	name[B_CVTUL] = "cvt.ul";
	name[B_CVTIV] = "cvt.iv";
	name[B_CVTLV] = "cvt.lv";
	name[B_CVTSV] = "cvt.sv";
	name[B_CVTAV] = "cvt.av";
	name[B_CVTVI] = "cvt.vi";
	name[B_CVTVS] = "cvt.vs";
	name[B_CVTVA] = "cvt.va";
	name[B_SWITCHI] = "switch.int";
	name[B_SWITCHE] = "switch.enum";
	name[B_string] = "[string]";
	name[B_JMP] = "jmp";
	name[B_JZ] = "jz";
	name[B_JNZ] = "jnz";

	const char *last = "<none>";
	int lastI = -1;
	for (int i = 0; i < B_MAX_BYTECODE; i++)
		if (name[i] == null) {
			printf("ERROR: Byte codee %d has no name entry (last defined entry: %s %d)\n", i, last, lastI);
		} else {
			last = name[i];
			lastI = i;
		}
	if (!pxi::registerSectionReader(ST_BYTE_CODES, byteCodeSectionReader))
		printf("Could not register byteCodeSectionReader for ST_BYTE_CODES\n");
}

static ByteCodeMap byteCodeMap;
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

const char * ByteCodeMap::name[B_MAX_BYTECODE];

ExecutionContext::ExecutionContext(void **objects, int objectCount) {
	_length = STACK_SIZE;
	_stack = (byte*)malloc(STACK_SIZE);
	_sp = _stack + STACK_SIZE;
	_exceptionContext = null;
	_stackTop = _sp;
	_active.code = null;
	_active.ip = 0;
	_lastIp = 0;
	_objects = objects;
	_objectCount = objectCount;
	_target = -1;
	_image = null;
}

ExecutionContext::ExecutionContext(X86_64SectionHeader *pxiHeader, void *image) {
	_length = 2 * sizeof (void*);
	_stack = (byte*)malloc(_length);
	_sp = _stack + _length;
	_exceptionContext = null;
	_stackTop = _sp;
	_active.code = null;
	_active.ip = 0;
	_lastIp = 0;
	_objects = null;
	_objectCount = 0;
	_target = -1;
	_pxiHeader = pxiHeader;
	_image = image;
}

ExecutionContext::~ExecutionContext() {
	free(_stack);
}

void ExecutionContext::enter() {
	ExecutionContext *outer = threadContext.get();
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

ExceptionContext *ExecutionContext::exceptionContext(ExceptionContext *exceptionInfo) {
	ExceptionContext *old = _exceptionContext;
	_exceptionContext = exceptionInfo;
	return old;
}

bool ExecutionContext::push(char **argv, int argc){
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

extern "C" {

CALLBACK long my_exception_handler(EXCEPTION_POINTERS * exception_data) {
	throw *exception_data->ExceptionRecord;
}

}

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
		context->snapshot(outer.sp);
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
	ExecutionContext context(header, image);

	threadContext.set(&context);
//	StackState outer = context->unloadFrame();
	int (*start)(void *args) = (int (*)(void*))(image + header->entryPoint);
	context.push(argv, argc);
	int result = context.runNative(start);

	// Transfer any uncaught exception to the outer context.

	ExceptionContext *ec = context.exceptionContext(null);
	outer->exceptionContext(ec);
	outer->transferSnapshot(&context);
	threadContext.set(outer);
//	context->reloadFrame(outer);
	return result;
}

// Deprecated
static int exposeException(void *exception) {
	return 0;
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
#ifdef MSVC
	EXCEPTION_POINTERS *exception;
	EXCEPTION_RECORD xr;
	__try
#else
#ifdef __SEH__
//	asm ("\t.l_startw:\n"
//			"\t.seh_handler __C_specific_handler, @except\n"
//			"\t.seh_handlerdata\n"
//			"\t.long 1\n"
//			"\t.rva .l_startw, .l_endw, my_exception_handler ,.l_endw\n"
//			"\t.text"
//   	);
	try
#else
	try
#endif
#endif
	{
		result = run();
#ifdef MSVC
	} __except(exception = GetExceptionInformation(), xr = *exception->ExceptionRecord, EXCEPTION_EXECUTE_HANDLER) {
		printf("   ");
		process::dumpExceptionRecord(&xr, 0);
		printf("\n");
		threadContext.set(outer);
		result = false;
	}
#else

#ifdef __SEH__
//	asm ("\tnop\n"
//			"\t.l_endw: nop\n");
	}
	catch (EXCEPTION_RECORD &xr) {
		threadContext.set(outer);
		return false;
	}
#else
	catch (...) {
		threadContext.set(outer);
		return false;
	}
#endif
#endif

	threadContext.set(outer);
	return result;
}

LONG CALLBACK windowsExceptionHandler(PEXCEPTION_POINTERS ExceptionInfo) {
	ExecutionContext *context = threadContext.get();
	StackState saved;
	StackState pseudo;

	saved = context->unloadFrame();
	pseudo.frame.fp = (byte*)ExceptionInfo->ContextRecord->Rbp;
	pseudo.frame.code = (byte*)ExceptionInfo->ContextRecord->Rip;
	pseudo.frame.ip = -1;
//	printf("Caught exception at %p\n", pseudo.frame.code);
	pseudo.sp = (byte*)ExceptionInfo->ContextRecord->Rsp;
	pseudo.stackTop = saved.stackTop;
	pseudo.target = NATIVE_64_TARGET;
	pseudo.exceptionType = ExceptionInfo->ExceptionRecord->ExceptionCode;
	switch (pseudo.exceptionType) {
	case EXCEPTION_ACCESS_VIOLATION:
	case EXCEPTION_IN_PAGE_ERROR:
		pseudo.exceptionFlags = (int)ExceptionInfo->ExceptionRecord->ExceptionInformation[0];
		pseudo.memoryAddress = (void*)ExceptionInfo->ExceptionRecord->ExceptionInformation[1];
	}
	context->reloadFrame(pseudo);
	context->snapshot(pseudo.stackTop);

	// The last snapshot survives the reload of the frame.

	context->reloadFrame(saved);
	context->throwException(pseudo);
	exit(1);
	return 0;
}

int ExecutionContext::runNative(int (*start)(void *args)) {
	_target = NATIVE_64_TARGET;
	byte *x;
	_stackTop = (byte*) &x;
	PVOID handle = AddVectoredExceptionHandler(0, windowsExceptionHandler);
	int result = start(_sp);
	RemoveVectoredExceptionHandler(handle);
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

void ExecutionContext::snapshot(byte *highestSp) {
	_stackSnapshot.resize(highestSp - _sp);
	memcpy(&_stackSnapshot[0], _sp, _stackSnapshot.size());
}

void ExecutionContext::transferSnapshot(ExecutionContext *source) {
	_stackSnapshot.resize(source->_stackSnapshot.size());
	memcpy(&_stackSnapshot[0], &source->_stackSnapshot[0], _stackSnapshot.size());
}

void ExecutionContext::fetchSnapshot(byte *output, int length) {
	memcpy(output, &_stackSnapshot[0], length);
	_stackSnapshot.clear();
//	printf("Cleared\n");
}

void fetchSnapshot(byte *output, int length) {
	ExecutionContext *context = threadContext.get();
//	stackDump(context);
	context->fetchSnapshot(output, length);
//	stackDump(context);
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
	printf("%d objects sp = %p (%d) fp = %p (%d) \n", _objectCount, _sp, _sp - _stack, _active.fp, _active.fp - _stack);
	printf("ip = %d code = %p _lastIp = %d\n", _active.ip, _active.code, _lastIp);
}

bool ExecutionContext::run() {
	int i;
	WORD left, right;
	WORD val;
	int *vtable;
	void *p;
	int objectId;

	if (trace)
		objectId = valueIndex(_active.code);
	for (;;) {
		if (trace) {
			printf("%05x %05x [%03d] (%016llx) ", _active.fp - _stack, _sp - _stack, objectId, st(0));
			fflush(stdout);
			disassemble(_active.ip);
		}
		_lastIp = _active.ip;
		byte byteCode = _active.code[_active.ip];
		_active.ip++;
		switch (byteCode) {
		case	B_INT:
			push(intInByteCode());
			break;

		case	B_LONG:
			push(longInByteCode());
			break;

		case	B_STRING:
			i = intInByteCode();
			push(*(WORD*)valueAddress(i));
			break;

		case	B_ADDR:
			i = intInByteCode();
			push(valueAddress(i));
			break;

		case	B_ASTRING:
			i = intInByteCode();
			push(valueAddress(i));
			break;

		case	B_VALUE:
			i = intInByteCode();
			push(valueAddress(i));
			break;

		case	B_CHAR_AT:
			right = pop();
			left = pop();
			MEM_VALID(((char *)left + sizeof (int) + right));
			push(*((char *)left + sizeof (int) + right));
			break;

		case	B_STSA:
		case	B_STSI:
			i = intInByteCode();
			*(int*)valueAddress(i) = peek();
			break;

		case	B_STSO:
			i = intInByteCode();
			left = intInByteCode();
			memcpy(valueAddress(i), (void*)_sp, left);
			break;

		case	B_LDSA:
			i = intInByteCode();
			push(*(WORD*)valueAddress(i));
			break;

		case	B_LDSI:
			i = intInByteCode();
			push(*(int*)valueAddress(i));
			break;

		case	B_LDSU:
			i = intInByteCode();
			push(*(unsigned*)valueAddress(i));
			break;

		case	B_STSB:
			i = intInByteCode();
			*(unsigned char*)valueAddress(i) = peek();
			break;

		case	B_LDSB:
			i = intInByteCode();
			push(*(unsigned char*)valueAddress(i));
			break;

		case	B_LDSC:
			i = intInByteCode();
			push(*(unsigned short*)valueAddress(i));
			break;

		case	B_STSC:
		case	B_STSS:
			i = intInByteCode();
			*(short*)valueAddress(i) = peek();
			break;

		case	B_LDSS:
			i = intInByteCode();
			push(*(short*)valueAddress(i));
			break;

		case	B_NEW:
			i = intInByteCode();
			p = malloc(i);
			if (p != null)
				memset(p, 0, i);
			push(p);
			break;

		case	B_DELETE:
			val = pop();
			free((void*)val);
			break;

		case	B_CHKSTK:
			i = intInByteCode();
			if (_active.fp - _sp != i) {
				printf("Stack not as expected! expected = %d actual = %lld\n", i, _active.fp - _sp);
				return false;
			}
			break;

		case	B_CALL:
			i = intInByteCode();
			p = valueAddress(i);
			if (trace)
				objectId = i;
			invoke((byte*)p);
			break;

		case	B_XCALL: {
			i = intInByteCode();
			BuiltInFunctionMap *m = &builtInFunctionMap[i];
			WORD x;
			bool oldTrace;
			switch (m->args) {
			case 0:
				x = ((WORD(*)())m->func)();
				break;
			case 1:
				oldTrace = trace;
				x = ((WORD(*)(WORD))m->func)(peek());
				if (!oldTrace && trace) {
					printf("oldTrace: %s trace = %s\n", oldTrace ? "true" : "false", trace ? "true" : "false");
					objectId = valueIndex(_active.code);
					printf("_active.code %p objectId %d\n", _active.code, objectId);
				}
				break;
			case 2:
				x = ((WORD(*)(WORD, WORD))m->func)(st(0), st(1));
				if (!oldTrace && trace) {
					printf("oldTrace: %s trace = %s\n", oldTrace ? "true" : "false", trace ? "true" : "false");
					objectId = valueIndex(_active.code);
					printf("_active.code %p objectId %d\n", _active.code, objectId);
				}
				break;
			case 3:
				x = ((WORD(*)(WORD, WORD, WORD))m->func)(st(0), st(1), st(2));
				break;
			case 4:
				x = ((WORD(*)(WORD, WORD, WORD, WORD))m->func)(st(0), st(1), st(2), st(3));
				break;
			default:
				printf("Executing function taking %d arguments\n", m->args);
				return false;
			}
			if (_active.ip == -1)
				return false;
			objectId = valueIndex(_active.code);
			_sp += m->args * sizeof (WORD);
			if (m->returns > 0)
				push(x);
			break;
		}

		case	B_LDTR:
			p = popAddress();
			MEM_VALID(p);
			vtable = *(int**)p;
			push(*(int*)valueAddress(vtable[0]));
			break;

		case	B_VCALL:
			i = intInByteCode();
			_active.ip += sizeof (int);
			p = peekAddress();
			MEM_VALID(p);
			vtable = *(int**)p;				// the 'this' object of the callee
			p = valueAddress(vtable[i]);
			if (trace)
				objectId = vtable[i];
			if (vtable[i] < 0) {
				printf("vtable slot abstract %d %d\n", i, vtable[i]);
				return false;
			}
			invoke((byte*)p);
			break;

		case	B_ICALL:
			p = popAddress();
			MEM_VALID(p);
			if (trace)
				objectId = valueIndex(p);
			invoke((byte*)p);
			break;

		case	B_LOCALS:
			i = intInByteCode();
			_sp -= i;
			memset(_sp, 0, i);
			break;

		case	B_SP:
			i = intInByteCode();
			_sp -= i;
			memset(_sp, 0, i);
			push(_sp);
			break;

		case	B_VARG:
			i = intInByteCode();
			_sp += i;
			break;

		case	B_VARG1:
			i = intInByteCode();
			val = pop();
			_sp += i;
			push(val);
			break;

		case	B_RET:
			i = intInByteCode();
			_sp = _active.fp;
			_active.fp = (byte*)popAddress();
			_active.code = (byte*)popAddress();
			if (trace)
				objectId = valueIndex(_active.code);
			_active.ip = pop();
			if (_active.ip == -1)
				return false;
			_sp += i;
			break;

		case	B_RET1:
			i = intInByteCode();
			val = pop();
			_sp = _active.fp;
			_active = *(StackFrame*)_sp;
			_sp += 3 * sizeof (void*);
			if (_active.fp == 0) {
				push(val);
				return true;
			}
			if (trace)
				objectId = valueIndex(_active.code);
			if (_active.ip == -1)
				return false;
			_sp += i;
			push(val);
			break;

		case	B_RETN:{
			int returnPayloadSize = intInByteCode();
			int argsSize = intInByteCode();
			void *returnLocation = _sp;
			_sp = _active.fp;
			_active.fp = (byte*)popAddress();
			if (_active.fp == 0) {
				_sp -= (returnPayloadSize + (sizeof(WORD) - 1)) & ~(sizeof(WORD) - 1);
				memmove(_sp, returnLocation, returnPayloadSize);
				return true;
			}
			_active.code = (byte*)popAddress();
			MEM_VALID(_active.code);
			if (trace)
				objectId = valueIndex(_active.code);
			_active.ip = pop();
			if (_active.ip == -1)
				return false;
			_sp += argsSize;
			_sp -= (returnPayloadSize + (sizeof(WORD) - 1)) & ~(sizeof(WORD) - 1);
			memmove(_sp, returnLocation, returnPayloadSize);
			break;
		}
		case	B_POP:
			_sp += sizeof(WORD);
			break;

		case	B_POPN:
			i = intInByteCode();
			_sp += i;
			break;

		case	B_SWAP:
			left = pop();
			right = pop();
			push(left);
			push(right);
			break;

		case	B_DUP:
			push(peek());
			break;

		case	B_NEG:
			push(-pop());
			break;

		case	B_BCM:
			push(~pop());
			break;

		case	B_MUL:
			push(pop() * pop());
			break;

		case	B_DIV:
			right = pop();
			left = pop();
			push(left / right);
			break;

		case	B_REM:
			right = pop();
			left = pop();
			push(left % right);
			break;

		case	B_ADD:
			push(pop() + pop());
			break;

		case	B_SUB:
			right = pop();
			left = pop();
			push(left - right);
			break;

		case	B_LSH:
			right = pop();
			left = pop();
			push(left << right);
			break;

		case	B_RSH:
			right = pop();
			left = pop();
			push(left >> right);
			break;

		case	B_URS:
			right = pop();
			left = pop();
			push(((unsigned long long)left) >> right);
			break;

		case	B_OR:
			push(pop() | pop());
			break;

		case	B_AND:
			push(pop() & pop());
			break;

		case	B_XOR:
			push(pop() ^ pop());
			break;

		case	B_NOT:
			push(!pop());
			break;

		case	B_EQV:
		case	B_NLGV:
			val = varCompare(_sp + sizeof(Variant), _sp);
			_sp += 2 * sizeof(Variant);
			push(val == 0);
			break;

		case	B_NEV:
		case	B_LGV:
			val = varCompare(_sp + sizeof(Variant), _sp);
			_sp += 2 * sizeof(Variant);
			push(val != 0);
			break;

		case	B_GTV:
		case	B_NLEV:
			val = varCompare(_sp + sizeof(Variant), _sp);
			_sp += 2 * sizeof(Variant);
			push(val > 0);
			break;

		case	B_GEV:
		case	B_NLV:
			val = varCompare(_sp + sizeof(Variant), _sp);
			_sp += 2 * sizeof(Variant);
			push(val >= 0);
			break;

		case	B_LTV:
		case	B_NGEV:
			val = varCompare(_sp + sizeof(Variant), _sp);
			_sp += 2 * sizeof(Variant);
			push(val < 0);
			break;

		case	B_LEV:
		case	B_NGV:
			val = varCompare(_sp + sizeof(Variant), _sp);
			_sp += 2 * sizeof(Variant);
			push(val <= 0);
			break;

		case	B_ADDV:
			varAdd(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_SUBV:
			varSub(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_MULV:
			varMul(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_DIVV:
			varDiv(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_REMV:
			varRem(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_RSHV:
			varRsh(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_LSHV:
			varLsh(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_URSV:
			varUrs(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_ANDV:
			varAnd(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_ORV:
			varOr(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_XORV:
			varXor(_sp + sizeof(Variant), _sp);
			_sp += sizeof(Variant);
			break;

		case	B_EQI:
			push((int)pop() == (int)pop());
			break;

		case	B_NEI:
			push((int)pop() != (int)pop());
			break;

		case	B_GTI:
			right = pop();
			left = pop();
			push((int)left > (int)right);
			break;

		case	B_GEI:
			right = pop();
			left = pop();
			push((int)left >= (int)right);
			break;

		case	B_LTI:
			right = pop();
			left = pop();
			push((int)left < (int)right);
			break;

		case	B_LEI:
			right = pop();
			left = pop();
			push((int)left <= (int)right);
			break;

		case	B_EQL:
			push(pop() == pop());
			break;

		case	B_NEL:
			push(pop() != pop());
			break;

		case	B_GTL:
			right = pop();
			left = pop();
			push(left > right);
			break;

		case	B_GEL:
			right = pop();
			left = pop();
			push(left >= right);
			break;

		case	B_LTL:
			right = pop();
			left = pop();
			push(left < right);
			break;

		case	B_LEL:
			right = pop();
			left = pop();
			push(left <= right);
			break;

		case	B_GTU:
			right = pop();
			left = pop();
			push((unsigned)left > (unsigned)right);
			break;

		case	B_GEU:
			right = pop();
			left = pop();
			push((unsigned)left >= (unsigned)right);
			break;

		case	B_LTU:
			right = pop();
			left = pop();
			push((unsigned)left < (unsigned)right);
			break;

		case	B_LEU:
			right = pop();
			left = pop();
			push((unsigned)left <= (unsigned)right);
			break;

		case	B_CVTBI:
			push(pop() & 0xff);
			break;

		case	B_CVTCI:
			push(pop() & 0xffff);
			break;

		case	B_CVTIL:
			push((int)pop());
			break;

		case	B_CVTUL:
			push((unsigned)pop());
			break;

		case	B_CVTIV:
		case	B_CVTLV:
			val = pop();		// ST(0) = type of pointer
			left = pop();	    // ST(1) = value of pointer
			_sp -= sizeof(Variant);
			((Variant*)_sp)->_value.integer = left;
			((Variant*)_sp)->_kind = (Type*)val;
			break;

		case	B_CVTAV:
		case	B_CVTSV:
			val = pop();		// ST(0) = type of pointer
			left = pop();	    // ST(1) = value of pointer
			_sp -= sizeof(Variant);
			((Variant*)_sp)->_value.pointer = (void*)left;
			((Variant*)_sp)->_kind = (Type*)val;
			break;

		case	B_CLASSV:
			p = ((Variant*)_sp)->_kind;
			_sp += sizeof(Variant);
			push(p);
			break;

		case	B_CVTVI:
		case	B_CVTVA:
		case	B_CVTVS:
			// TODO: Add check for string type
			val = ((Variant*)_sp)->_value.integer;
			_sp += sizeof(Variant);
			push(val);
			break;

		case	B_JZ:
			val = pop();
			if (val == 0)
				_active.ip = intInByteCode();
			else
				_active.ip += sizeof(int);
			break;

		case	B_JNZ:
			val = pop();
			if (val != 0)
				_active.ip = intInByteCode();
			else
				_active.ip += sizeof(int);
			break;

		case	B_SWITCHI:{
			val = pop();
			int caseCount = intInByteCode();
			int defaultLabel = intInByteCode();
			for (i = 0; i < caseCount; i++) {
				int caseVal = intInByteCode();
				if (caseVal == val) {
					_active.ip = intInByteCode();
					break;
				}
				_active.ip += sizeof(int);
			}
			if (i >= caseCount)
				_active.ip = defaultLabel;
			break;
		}
		case	B_SWITCHE:{
			val = pop();
			int caseCount = intInByteCode();
			int defaultLabel = intInByteCode();
			for (i = 0; i < caseCount; i++) {
				int caseValIndex = intInByteCode();
				int valOffset = intInByteCode();
				long long caseVal = (long long)valueAddress(caseValIndex) + valOffset * 4;
				if (caseVal == val) {
					_active.ip = intInByteCode();
					break;
				}
				_active.ip += sizeof(int);
			}
			if (i >= caseCount)
				_active.ip = defaultLabel;
			break;
		}
		case	B_JMP:
			_active.ip = intInByteCode();
			break;

		case	B_LDAB:
			i = intInByteCode();
			push(_active.fp[i]);
			break;

		case	B_LDAC:
			i = intInByteCode();
			push(*(unsigned short*)(_active.fp + i));
			break;

		case	B_STAB:
			i = intInByteCode();
			_active.fp[i] = peek();
			break;

		case	B_STAS:
			i = intInByteCode();
			*(short*)(_active.fp + i) = peek();
			break;

		case	B_LDAA:
			i = intInByteCode();
			push(*(WORD*)(_active.fp + i));
			break;

		case	B_LDAI:
			i = intInByteCode();
			push(*(int*)(_active.fp + i));
			break;

		case	B_LDAU:
			i = intInByteCode();
			push(*(unsigned*)(_active.fp + i));
			break;

		case	B_STAA:
			i = intInByteCode();
			*(WORD*)(_active.fp + i) = peek();
			break;

		case	B_STAI:
			i = intInByteCode();
			*(int*)(_active.fp + i) = peek();
			break;

		case	B_LDAO:
			i = intInByteCode();
			val = intInByteCode();
			_sp -= (val + sizeof(WORD) - 1) & ~(sizeof(WORD) - 1);
			memcpy(_sp, _active.fp + i, val);
			break;

		case	B_STAO:
			i = intInByteCode();
			val = intInByteCode();
			memcpy(_active.fp + i, _sp, val);
			break;

		case	B_STAV:
			i = intInByteCode();
			*((Variant*)(_active.fp + i)) = *((Variant*)_sp);
			break;

		case	B_STVA:
			i = intInByteCode();
			*(WORD*)(_active.fp - i) = peek();
			break;

		case	B_STVB:
			i = intInByteCode();
			_active.fp[-i] = peek();
			break;

		case	B_STVS:
			i = intInByteCode();
			*(short*)(_active.fp - i) = peek();
			break;

		case	B_STVI:
			i = intInByteCode();
			*(int*)(_active.fp - i) = peek();
			break;

		case	B_STVO:
			i = intInByteCode();
			val = intInByteCode();
			memcpy(_active.fp - i, _sp, val);
			break;

			memcpy(_active.fp - i, _sp, val);
			break;

		case	B_STVV:
			i = intInByteCode();
			*((Variant*)(_active.fp - i)) = *((Variant*)_sp);
			break;

		case	B_LDPA:
			i = intInByteCode();
			push(*(void**)(_active.fp + FRAME_SIZE + i));
			break;

		case	B_LDPI:
			i = intInByteCode();
			push(*(int*)(_active.fp + FRAME_SIZE + i));
			break;

		case	B_LDPU:
			i = intInByteCode();
			push(*(unsigned*)(_active.fp + FRAME_SIZE + i));
			break;

		case	B_LDPL:
			i = intInByteCode();
			push(*(long long*)(_active.fp + FRAME_SIZE + i));
			break;

		case	B_LDPO:
			i = intInByteCode();
			val = intInByteCode();
			_sp -= (val + sizeof(WORD) - 1) & ~(sizeof(WORD) - 1);
			memcpy(_sp, _active.fp + FRAME_SIZE + i, val);
			break;

		case	B_STPO:
			i = intInByteCode();
			val = intInByteCode();
			memcpy(_active.fp + FRAME_SIZE + i, _sp, val);
			break;

		case	B_STPL:
		case	B_STPA:
			i = intInByteCode();
			*(WORD*)(_active.fp + FRAME_SIZE + i) = peek();
			break;

		case	B_STPI:
			i = intInByteCode();
			*(int*)(_active.fp + FRAME_SIZE + i) = peek();
			break;

		case	B_LDPB:
			i = intInByteCode();
			push(*(byte*)(_active.fp + FRAME_SIZE + i));
			break;

		case	B_STPS:
			i = intInByteCode();
			*(unsigned short*)(_active.fp + FRAME_SIZE + i) = (unsigned short)peek();
			break;

		case	B_LDPC:
			i = intInByteCode();
			push(*(unsigned short*)(_active.fp + FRAME_SIZE + i));
			break;

		case	B_LDPS:
			i = intInByteCode();
			push(*(short*)(_active.fp + FRAME_SIZE + i));
			break;

		case	B_STPB:
			i = intInByteCode();
			*(unsigned char*)(_active.fp + FRAME_SIZE + i) = (unsigned char)peek();
			break;

		case	B_AUTO:
			i = intInByteCode();
			push(_active.fp + i);
			break;

		case	B_AVARG:
			i = intInByteCode();
			push(_active.fp - i);
			break;

		case	B_ZERO_A:
			i = intInByteCode();
			val = intInByteCode();
			memset(_active.fp + i, 0, val);
			break;

		case	B_ZERO_I:
			left = pop();
			MEM_VALID(left);
			val = intInByteCode();
			memset((void*)left, 0, val);
			break;

		case	B_PARAMS:
			i = intInByteCode();
			push(_active.fp + FRAME_SIZE + i);
			break;

		case	B_LDIA:
		case	B_LDIL:
			left = pop();
			MEM_VALID(left);
			push(*(WORD*)left);
			break;

		case	B_LDII:
			left = pop();
			MEM_VALID(left);
			push(*(int*)left);
			break;

		case	B_LDIU:
			left = pop();
			MEM_VALID(left);
			push(*(unsigned*)left);
			break;

		case	B_LDIV:
			left = pop();
			MEM_VALID(left);
			_sp -= sizeof(Variant);
			*((Variant*)_sp) = *((Variant*)left);
			break;

		case	B_LDIB:
			left = pop();
			MEM_VALID(left);
			push((int)*(unsigned char*)left);
			break;

		case	B_LDIC:
			left = pop();
			MEM_VALID(left);
			push((int)*(unsigned short*)left);
			break;

		case	B_LDIO:
			val = intInByteCode();
			right = pop();
			MEM_VALID(right);
			_sp -= (val + sizeof(WORD) - 1) & ~(sizeof(WORD) - 1);
			memcpy(_sp, (void*)right, val);
			break;

		case	B_STIO:
			val = intInByteCode();
			right = pop();
			MEM_VALID(right);
			memcpy((void*)right, _sp, val);
			break;

		case	B_STIL:
		case	B_STIA:
			left = pop();
			MEM_VALID(left);
			*(WORD*)left = peek();
			break;

		case	B_STII:
			left = pop();
			MEM_VALID(left);
			*(int*)left = peek();
			break;

		case	B_POPIA:
			val = pop();
			left = peek();
			MEM_VALID(left);
			*(int*)left = val;
			break;

		case	B_STIV:
			left = pop();
			MEM_VALID(left);
			*((Variant*)left) = *(Variant*)_sp;
			break;

		case	B_STIB:
			left = pop();
			MEM_VALID(left);
			*(unsigned char*)left = (unsigned char)peek();
			break;

		case	B_STIC:
			left = pop();
			MEM_VALID(left);
			*(unsigned short*)left = (unsigned short)peek();
			break;

		default:
			printf("[%d]+%d Could not execute '%s'(%d)\n", valueIndex(_active.code), _active.ip - 1, ByteCodeMap::name[byteCode], byteCode);
			fflush(stdout);
			return false;
		}
	}
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

const int NATIVE_64_RETURN_ADDRESS = 18;
const int NATIVE_64_FRAME_ADDRESS = 15;

int builtInAssert(int booleanValue) {
	booleanValue &= 0xff;					// Cast to boolean
	if (!booleanValue) {
		ExecutionContext *context = threadContext.get();
		switch (context->target()) {
		case	BYTE_CODE_TARGET:
			printf("assertion failed at ip=%d!\n", context->ip());
			context->halt();
			break;

		case	NATIVE_64_TARGET: {
			StackState saved;
			StackState pseudo;

			saved = context->unloadFrame();
			WORD *stack = (WORD*)&context;
			pseudo.frame.fp = (byte*)stack[NATIVE_64_FRAME_ADDRESS];
			pseudo.frame.code = (byte*)stack[NATIVE_64_RETURN_ADDRESS];
			pseudo.frame.ip = -1;
			pseudo.sp = (byte*)&stack[NATIVE_64_RETURN_ADDRESS + 1];
			pseudo.stackTop = saved.stackTop;
			pseudo.target = NATIVE_64_TARGET;
			pseudo.exceptionType = 0;
			context->reloadFrame(pseudo);
			context->snapshot(pseudo.stackTop);

			// The last snapshot survives the reload of the frame.

			context->reloadFrame(saved);
			context->throwException(pseudo);
			exit(1);
		}
		default:
			printf("assertion failed in unknown target %d\n", context->target());
			exit(1);
		}
	}
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

void *builtinVirtualAlloc(void *lpAddress, SIZE_T sz, DWORD flAllocationType, DWORD flProtect) {
	return VirtualAlloc(lpAddress, sz, flAllocationType, flProtect);
}

BOOL builtinVirtualProtect(void *lpAddress, SIZE_T sz, DWORD flNewProtect, DWORD *lpflOldProtect) {
	return VirtualProtect(lpAddress, sz, flNewProtect, lpflOldProtect);
}

unsigned builtinGetLastError() {
	return GetLastError();
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

#define nativeFunction(f) ((WORD(*)())f)


static void *allocz(size_t size) {
	void *p = malloc(size);
	if (p != null)
		memset(p, 0, size);
	return p;
}

static void *fMemcpy(void *dest, void *src, size_t len) {
	return memcpy(dest, src, len);
}

static void *fMemset(void *dest, char c, size_t len) {
	return memset(dest, c, len);
}

static int pGetModuleFileName(void *hModule, void *buffer, int bufferLen) {
	DWORD result = GetModuleFileName((HMODULE)hModule, (LPCH)buffer, bufferLen);
	return result;
}

static unsigned pGetFullPathName(char *filename, unsigned bufSz, char *buffer, char **filePart) {
	DWORD result = GetFullPathName(filename, bufSz, buffer, filePart);
	return result;
}

static void *pFindFirstFile(char *pattern, WIN32_FIND_DATA *buffer) {
	HANDLE result = FindFirstFile(pattern, buffer);
	return result;
}

static int pFindNextFile(void *handle, WIN32_FIND_DATA *buffer) {
	DWORD result = FindNextFile(handle, buffer);
	return result;
}

static int pFindClose(void *handle) {
	BOOL result = FindClose(handle);
	return result;
}

static FILE *builtInfopen(char *file, char*opts) {
	FILE *result = fopen(file, opts);
	return result;
}

static int builtinFseek(FILE *fp, long offset, int whence) {
	int result = fseek(fp, offset, whence);
	return result;
}

static unsigned builtinFread(void *cp, unsigned size, unsigned count, FILE *fp) {
	return fread(cp, size, count, fp);
}

struct SpawnPayload {
	const char *buffer;
	int length;
	process::exception_t outcome;
};

static int processDebugSpawn(char *command, SpawnPayload *output, long long timeout) {
	string out;
	string cmd(command);

	int result = process::debugSpawn(cmd, &out, &output->outcome, (time_t)(timeout / 1000));
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
	case 0:			return ST_X86_64;
	case 1:			return ST_BYTE_CODES;
	default:		return -1;
	}
}

static int runningTarget() {
	ExecutionContext *context = threadContext.get();
	switch (context->target()) {
	case BYTE_CODE_TARGET:		return ST_BYTE_CODES;
	case NATIVE_64_TARGET:		return ST_X86_64;
	default:					return -1;
	}
}

class ParasolTime {
public:
	static ParasolTime UNDEFINED;

	ParasolTime() {
		_time = 0;
	}

	ParasolTime(time_t t) {
		_time = t * 1000;			// Record as millisec units.
	}

	ParasolTime(FILETIME& t) {
		// Use UNIX era, and millis rather than 100nsec units
		_time = (*(__int64*)&t - ERA_DIFF) / 10000;
	}

	void clear() { _time = 0; }

	bool operator == (const ParasolTime& t2) const {
		return _time == t2._time;
	}

	bool operator != (const ParasolTime& t2) const {
		return _time != t2._time;
	}

	bool operator < (const ParasolTime& t2) const {
		return _time < t2._time;
	}

	bool operator > (const ParasolTime& t2) const {
		return _time > t2._time;
	}

	bool operator <= (const ParasolTime& t2) const {
		return _time <= t2._time;
	}

	bool operator >= (const ParasolTime& t2) const {
		return _time >= t2._time;
	}

//	string toString();

//	void touch();

	void setValue(__int64 t) { _time = t; }

	__int64 value() const { return _time; }

private:
	static const __int64 ERA_DIFF = 0x019DB1DED53E8000LL;

	__int64		_time;
};

static __int64 now() {
	SYSTEMTIME s;
	FILETIME f;

	GetSystemTime(&s);
	SystemTimeToFileTime(&s, &f);
	ParasolTime result(f);
	return result.value();
}

void *formatMessage(unsigned NTStatusMessage) {
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
}

ExceptionContext *pExceptionContext(ExceptionContext *newContext) {
	ExecutionContext *context = threadContext.get();
	return context->exceptionContext(newContext);
}

BuiltInFunctionMap builtInFunctionMap[] = {
	{ "print",			nativeFunction(builtInPrint),	1,	1 },
	{ "assert",			nativeFunction(builtInAssert),	1,	0 },
	{ "allocz",			nativeFunction(allocz),			1,	1 },
	{ "free",			nativeFunction(free),			1,	0 },
	{ "memcpy",			nativeFunction(fMemcpy),		3,	1 },
	{ "memset",			nativeFunction(fMemset),		3,	1 },
	{ "fopen",			nativeFunction(builtInfopen),	2,	1, "native" },
	{ "fclose",			nativeFunction(fclose),			1,	1, "native" },
	{ "ftell",			nativeFunction(ftell),			1,	1, "native" },
	{ "fseek",			nativeFunction(builtinFseek),	3,	1, "native" },
	{ "fgetc",			nativeFunction(fgetc),			1,	1, "native" },
	{ "fread",			nativeFunction(builtinFread),	4,  1, "native" },
	{ "fwrite",			nativeFunction(fwrite),			4,  1, "native" },
	{ "ferror",			nativeFunction(ferror),			1,	1, "native" },
	{ "exit",			nativeFunction(exit),			1,	1, "native" },
	{ "getenv",			nativeFunction(getenv),			1,	1, "native" },
	{ "GetModuleFileName",
						nativeFunction(pGetModuleFileName),
														3,	1, "native" },
	{ "GetFullPathName",nativeFunction(pGetFullPathName),
														4,	1, "native" },
	{ "FindFirstFile",	nativeFunction(pFindFirstFile),	2,	1, "native" },
	{ "FindNextFile",	nativeFunction(pFindNextFile),	2,	1, "native" },
	{ "FindClose",		nativeFunction(pFindClose),		1,	1, "native" },

	{ "builtInFunctionName",
						nativeFunction(builtInFunctionName),
														1,	1, "parasol" },
	{ "builtInFunctionDomain",
						nativeFunction(builtInFunctionDomain),
														1,	1, "parasol" },
	{ "builtInFunctionAddress",
						nativeFunction(builtInFunctionAddress),
														1,	1, "parasol" },
	{ "builtInFunctionArguments",
						nativeFunction(builtInFunctionArguments),
														1,	1, "parasol" },
	{ "builtInFunctionReturns",
						nativeFunction(builtInFunctionReturns),
														1,	1, "parasol" },
	{ "debugSpawnImpl", nativeFunction(processDebugSpawn),
														3,	1, "parasol" },
	{ "disposeOfPayload",
						nativeFunction(disposeOfPayload),
														1,	0, "parasol" },
	{ "injectObjects",	nativeFunction(injectObjects),	2,	1, "parasol" },
	{ "eval",			nativeFunction(eval),			4,	1, "parasol" },
	{ "setTrace",		nativeFunction(setTrace),		1,	1, "parasol" },
	{ "fetchSnapshot",	nativeFunction(fetchSnapshot),	2,	0, "parasol" },
	{ "supportedTarget",nativeFunction(supportedTarget),1,	1, "parasol" },
	// TODO: Remove plain 'now' in favor of the new function whenever...
	{ "now",			nativeFunction(now),			0,	1, "parasol" },
	{ "exit",			nativeFunction(exit),			1,	1, "parasol" },
	{ "evalNative",		nativeFunction(evalNative),		4,	1, "parasol" },
	{ "VirtualAlloc",	nativeFunction(builtinVirtualAlloc),
														4,	1, "native" },
	{ "VirtualProtect",	nativeFunction(builtinVirtualProtect),
														4,	1, "native" },
	{ "GetLastError",	nativeFunction(builtinGetLastError),
														0,	1, "native" },
	{ "exposeException",nativeFunction(exposeException),1,	1 },
	{ "_now",			nativeFunction(now),			0,	1, "parasol" },
	{ "FormatMessage",	nativeFunction(formatMessage),	1,	1, "native" },
	{ "runningTarget",  nativeFunction(runningTarget),  0,  1, "parasol" },
	{ "exceptionContext",
						nativeFunction(pExceptionContext),
														1,	1, "parasol" },

/*
	{ "open",			nativeFunction(open),			2,	1 },
	{ "openCreat",		nativeFunction(open),			3,	1 },
	{ "close",			nativeFunction(close),			1,	1 },
	{ "read",			nativeFunction(read),			1,	1 },
	{ "write",			nativeFunction(write),			1,	1 },
	{ "seek",			nativeFunction(seek),			1,	1 },
 */
	{ 0 }
};

const char *builtInFunctionName(int index) {
	if (index < sizeof builtInFunctionMap / sizeof builtInFunctionMap[0]) {
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
	int x, y;
	printf("%4d:\t%s", ip, ByteCodeMap::name[_active.code[ip]]);
	switch (_active.code[ip]) {
	case	B_NEW:
	case	B_INT:
	case	B_RET:
	case	B_RET1:
	case	B_VARG:
	case	B_VARG1:
	case	B_CHKSTK:
	case	B_LDIO:
	case	B_STIO:
	case	B_POPN:
	case	B_INVOKE:
	case	B_ZERO_I:
		printf("\t%d", *((int*)&_active.code[ip + 1]));
		ip += 4;
		break;

	case	B_LONG:
		printf("\t%lld", *((WORD*)&_active.code[ip + 1]));
		ip += 8;
		break;

	case	B_RETN:
		x = *((int*)&_active.code[ip + 1]);
		ip += 4;
		printf("\t%d, %d", x, *((int*)&_active.code[ip + 1]));
		ip += 4;
		break;

	case	B_LDAA:
	case	B_STAA:
	case	B_LDAB:
	case	B_STAB:
	case	B_LDAC:
	case	B_LDAS:
	case	B_STAS:
	case	B_STAV:
	case	B_LDAI:
	case	B_LDAU:
	case	B_STAI:
	case	B_AUTO:
		printf("\t[fp%+d]", *((int*)&_active.code[ip + 1]));
		ip += 4;
		break;

	case	B_STVA:
	case	B_STVB:
	case	B_STVI:
	case	B_STVS:
	case	B_STVV:
	case	B_AVARG:
		printf("\t[fp%+d]", -*((int*)&_active.code[ip + 1]));
		ip += 4;
		break;

	case	B_ZERO_A:
	case	B_STAO:
	case	B_LDAO:
		printf("\t[fp%+d],%d", *((int*)&_active.code[ip + 1]),
			*((int*)&_active.code[ip + 5]));
		ip += 8;
		break;

	case	B_STVO:
		printf("\t[fp%+d],%d", -*((int*)&_active.code[ip + 1]),
			*((int*)&_active.code[ip + 5]));
		ip += 8;
		break;

	case	B_LDPA:
	case	B_STPA:
	case	B_LDPC:
	case	B_LDPS:
	case	B_STPS:
	case	B_LDPB:
	case	B_STPB:
	case	B_LDPI:
	case	B_LDPL:
	case	B_LDPU:
	case	B_STPI:
	case	B_STPL:
	case	B_PARAMS:
		printf("\t[param+%d]", *((int*)&_active.code[ip + 1]));
		ip += 4;
		break;

	case	B_LDPO:
	case	B_STPO:
		printf("\t[param+%d],%d", *((int*)&_active.code[ip + 1]),
			*((int*)&_active.code[ip + 5]));
		ip += 8;
		break;

	case	B_SWITCHI:
		x = *((int*)&_active.code[ip + 1]);
		printf("\t%d cases, default ", x);
		ip += 4;
		y = *((int*)&_active.code[ip + 1]);
		printf("%d:", y);
		ip += 4;
		for (int j = 0; j < x; j++) {
			int value = *((int*)&_active.code[ip + 1]);
			ip += 4;
			int label = *((int*)&_active.code[ip + 1]);
			ip += 4;
			printf("\n      %08x -> %d", value, label);
		}
		break;

	case	B_SWITCHE:
		x = *((int*)&_active.code[ip + 1]);
		printf("\t%d cases, default ", x);
		ip += 4;
		y = *((int*)&_active.code[ip + 1]);
		printf("%d:", y);
		ip += 4;
		for (int j = 0; j < x; j++) {
			int value = *((int*)&_active.code[ip + 1]);
			ip += 4;
			int offset = *((int*)&_active.code[ip + 1]);
			ip += 4;
			int label = *((int*)&_active.code[ip + 1]);
			ip += 4;
			printf("\n      %08x -> %d", value, label);
		}
		break;

	case	B_JMP:
	case	B_JZ:
	case	B_JNZ:
		x = *((int*)&_active.code[ip + 1]);
		printf("\t%d", x);
		ip += 4;
		break;

	case	B_LOCALS:
		printf("\t%d", *((int*)&_active.code[ip + 1]));
		ip += 4;
		break;

	case	B_SP:
		printf("\t%d,sp", *((int*)&_active.code[ip + 1]));
		ip += 4;
		break;

	case	B_STSA:
	case	B_STSB:
	case	B_STSC:
	case	B_STSI:
	case	B_STSS:
	case	B_LDSA:
	case	B_LDSB:
	case	B_LDSC:
	case	B_LDSI:
	case	B_LDSU:
	case	B_LDSS:
	case	B_VALUE:
	case	B_CALL:
	case	B_STRING:
	case	B_ASTRING:
	case	B_ADDR:
		x = *((int*)&_active.code[ip + 1]);
		if (x == -1)
			printf("\t<invalid>");
		else {
			printf("\t");
			if (x >= 0 && x < _objectCount)
				printf("[%d]", x);
			else
				printf("<invalid:%d>", x);
		}
		ip += 4;
		break;

	case	B_XCALL:
		x = *((int*)&_active.code[ip + 1]);
		if (x == -1)
			printf("\t<invalid>");
		else
			printf("\t%s (%d)", builtInFunctionName(x), x);
		ip += 4;
		break;

	case	B_VCALL:
		x = *((int*)&_active.code[ip + 1]);
		ip += 4;
		printf("\t@%d,", x);
		y = *((int*)&_active.code[ip + 1]);
		ip += 4;
		if (y >= 0 && y < _objectCount)
			printf("[%d]", y);
		else
			printf("<invalid:%d>", y);
		break;

	case	B_STSO:
		x = *((int*)&_active.code[ip + 1]);
		if (x == -1)
			printf("\t<invalid>");
		else {
			printf("\t");
			if (x >= 0 && x < _objectCount)
				printf("[%d]", x);
			else
				printf("<invalid:%d>", x);
		}
		printf(",%d", *((int*)&_active.code[ip + 5]));
		ip += 8;
		break;
	}
	printf("\n");
}

static pxi::Section *byteCodeSectionReader(FILE *pxiFile, long long length) {
	ByteCodeSection *section = new ByteCodeSection(pxiFile, length);
	if (section->valid())
		return section;
	else {
		delete section;
		return null;
	}
}

ByteCodeSection::ByteCodeSection(FILE *pxiFile, long long length) {
	_image = null;
	ByteCodeSectionHeader header;

	if (fread(&header, 1, sizeof header, pxiFile) != sizeof header) {
		printf("Could not read byte-code section header\n");
		return;
	}
	_entryPoint = header.entryPoint;
	vector<int> objectTable;
	objectTable.resize(header.objectCount);
	int imageLength = length - sizeof(header) - header.objectCount * sizeof(int) - header.relocationCount * sizeof (ByteCodeRelocation);
	if (imageLength == 0) {
		printf("Image is zero bytes long\n");
		return;
	}
	if (fread(&objectTable[0], 1, header.objectCount * sizeof (int), pxiFile) != header.objectCount * sizeof (int)) {
		printf("Could not read byte code object table\n");
		return;
	}
	void *data = malloc(imageLength);
	if (fread(data, 1, imageLength, pxiFile) != imageLength) {
		printf("Could not read byte code image\n");
		return;
	}
	vector<ByteCodeRelocation> relocations;
	relocations.resize(header.relocationCount);
	if (fread(&relocations[0], 1, relocations.size() * sizeof (ByteCodeRelocation), pxiFile) != relocations.size() * sizeof (ByteCodeRelocation)) {
		printf("Could not read relocations\n");
		return;
	}
	_image = data;
	char *cp = (char*)data;
	for (int i = 0; i < objectTable.size(); i++)
		_objects.push_back(cp + objectTable[i]);
	for (int i = 0; i < relocations.size(); i++) {
		void **location = (void**)((char*)_objects[relocations[i].relocObject] + relocations[i].relocOffset);
		*location = (char*)_objects[relocations[i].reference] + relocations[i].offset;
	}
}

ByteCodeSection::~ByteCodeSection() {
	if (_image)
		free(_image);
}

bool ByteCodeSection::run(char **args, int *returnValue, bool trace) {
	ExecutionContext executionContext(&_objects[0], _objects.size());
	int argc = 0;
	for (int i = 1; args[i] != null; i++)
		argc++;
	executionContext.push(args + 1, argc);
	executionContext.trace = trace;
	executionContext.unloadFrame();
	if (executionContext.run(_entryPoint)) {
		long long x = executionContext.pop();
		*returnValue = x;
		return true;
	} else {
		printf("Execution terminated due to uncaught exception at address %d\n", executionContext.lastIp());
		dumpIp(&executionContext);
		dumpStack(&executionContext);
		*returnValue = -1;
		return false;
	}
}

void ByteCodeSection::dumpIp(ExecutionContext *executionContext) {
	string s = collectIp(executionContext, executionContext->code(), executionContext->lastIp());
	printf(" -> %s\n", s.c_str());
}

void ByteCodeSection::dumpStack(ExecutionContext *executionContext) {
	byte *code = executionContext->code();
	byte *fp = executionContext->fp();
	if (fp == null) {
		printf("    <No stack>\n");
		return;
	}
	int ip = 0;
	for (;;) {
		StackFrame *frame = (StackFrame*)fp;
		fp = frame->fp;
		code = frame->code;
		ip = frame->ip;
		if (ip <= 0)
			break;
		string text = collectIp(executionContext, code, ip);
		printf("    %s\n", text.c_str());
	}
}

string ByteCodeSection::collectIp(ExecutionContext *executionContext, byte *byteCodes, int ip) {
	int i = executionContext->valueIndex(byteCodes);
	if (i < 0) {
		string s;

		s.printf("invalid address %p:%d", byteCodes, ip);
		return s;
	}
	string s;
	s.printf("[%d]:%d", i, ip);
	return s;
}

WORD stackSlot(ExceptionContext *context, void *stackAddress) {
	WORD *copyAddress = (WORD*)((WORD)stackAddress - (WORD)context->stackBase + (WORD)context->stackCopy);
	return *copyAddress;
}

}
