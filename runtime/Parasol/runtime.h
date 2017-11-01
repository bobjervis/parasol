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
#ifndef PARASOL_RUNTIME_H
#define PARASOL_RUNTIME_H

#include "common/machine.h"
#include "parasol_enums.h"
#include "pxi.h"
#include "x86_pxi.h"

namespace parasol {

const int INDENT = 4;

const int BYTE_CODE_TARGET = 1;
const int NATIVE_64_TARGET = 2;

typedef long long WORD;

#define STACK_SLOT (sizeof (WORD))
#define FRAME_SIZE (sizeof(WORD) + 2 * sizeof(void*))

static const int STACK_SIZE = STACK_SLOT * 128 * 1024;

class Code;
class Exception;
class Type;

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

class ExecutionContext {
public:
	ExecutionContext(void **objects, int objectCount);

	ExecutionContext(X86_64SectionHeader *pxiHeader, void *image, long long runtimeFlags);

	~ExecutionContext();

	void enter();

	void push(char **argv, int argc);

	bool push(void *pointerValue);

	bool push(WORD intValue);

	WORD pop();

	WORD peek();

	WORD st(int index);

	void *popAddress();

	void *peekAddress();

	StackState unloadFrame();

	bool run(int objectId);

	int runNative(int (*start)(void *args));

	void reloadFrame(const StackState &saved);

	int injectObjects(void **objects, int objectCount);

	void registerHardwareExceptionHandler(void (*handler)(HardwareException *exceptionContext));

	bool hasHardwareExceptionHandler() {
		return _hardwareExceptionHandler != null;
	}

	void callHardwareExceptionHandler(HardwareException *info);

	void halt();

	void *valueAddress(int i);

	int valueIndex(void *address);

	void print();

	int target() { return _target; }

	int ip() { return _active.ip; }

	byte *fp() { return _active.fp; }

	byte *sp() { return _sp; }

	byte *stack() { return _stack; }

	byte *stackTop() { return _stackTop; }

	void setStackTop(void *p) {
		_stackTop = (byte*)p;
	}

	byte *code() { return _active.code; }

	int lastIp() { return _lastIp; }

	void **objects() { return _objects; }

	int objectCount() { return _objectCount; }

	long long runtimeFlags() { return _runtimeFlags; }

	vector<string> &args() { return _args; }

	void *exceptionsAddress();

	int exceptionsCount();

	void exposeException(Exception *exception) {
		_exception = exception;
	}

	Exception *exception() {
		return _exception;
	}

	byte *lowCodeAddress() {
		return (byte*)_image;
	}

	byte *highCodeAddress();

	void callCatchHandler(Exception *exception, void *framePointer, int handler);

	void *sourceLocations() {
		return _sourceLocations;
	}

	int sourceLocationsCount() {
		return _sourceLocationsCount;
	}

	ExecutionContext *clone();

	void setSourceLocations(void *location, int count);

	void setRuntimeFlags(long long runtimeFlags) { _runtimeFlags = runtimeFlags; }

	void *parasolThread(void *newThread);

private:
	bool run();

//	void invoke(WORD methodName, WORD object);

	void invoke(byte *code);

	void disassemble(int ip);

	int intInByteCode() {
		int x = *(int*)(_active.code + _active.ip);
		_active.ip += sizeof (int);
		return x;
	}

	long long longInByteCode() {
		long long x = *(long long*)(_active.code + _active.ip);
		_active.ip += sizeof (long long);
		return x;
	}

	void crawlStack(const StackState &state, void *rbp);

	int _target;
	void **_objects;
	int _objectCount;
	byte *_stack;
	byte *_stackTop;
	int _length;
	StackFrame _active;
	byte *_sp;
	Exception *_exception;
	X86_64SectionHeader *_pxiHeader;
	void *_image;
	int _lastIp;
	vector<byte> _stackSnapshot;
	vector<string> _args;
	void (*_hardwareExceptionHandler)(HardwareException *info);
	void *_sourceLocations;
	int _sourceLocationsCount;
	long long _runtimeFlags;
	void *_parasolThread;
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
#if 0
enum VariantKind {
	K_EMPTY,			// No value at all, equals null
	K_INT,				// An integer value
	K_DOUBLE,			// A double value
	K_STRING,			// A string value
	K_OBJECT,			// An object value (pointer to object stored indirectly (not currently supported)
	K_REF				// A reference to an object (same bits as an object, but
						// no delete in the destructor
};

class Variant {
	friend class ExecutionContext;
public:
	Variant() {
		_kind = null;
	}

	~Variant() {
		clear();
	}

	Variant(const Variant& source) {
		init(source);
	}

	Variant(Type *kind, void *value) {
		_kind = kind;
		_value.pointer = value;
	}

	bool equals(Variant &other) const;

	const Variant& operator= (const Variant &source) {
		clear();
		init(source);
		return source;
	}

	void clear();

	Type *kind() const { return _kind; }

	long long asLong() const { return _value.integer; }

	double asDouble() const { return _value.floatingPoint; }

	void *asRef() const { return _value.pointer; }

	string *asString() { return (string*)&_value.pointer; }

	void setLong(long long x) { _value.integer = x; }

	void setAddress(void *a) { _value.pointer = a; }

private:
	Type *_kind;

	void init(const Variant& source);

	union {
		long long	integer;
		double		floatingPoint;
//		string		text;				C++ doesn't like this sort of type in a union.
		void		*pointer;
	} _value;

};
#endif
/*
	Returns non-null function name for valid index values, null for invalid values (< 0 or > maximum function).
 */
const char *builtInFunctionName(int index);

const char *builtInFunctionDomain(int index);

WORD (*builtInFunctionAddress(int index))();

int builtInFunctionArguments(int index);

int builtInFunctionReturns(int index);
#if 0
class ByteCodeSectionHeader {
public:
	int entryPoint;				// Object id of the starting function to run in the image
	int objectCount;			// Total number of objects in the object table
	int relocationCount;		// Total number of relocations
private:
	int _1;
};

class ByteCodeRelocation {
public:
	int relocObject;			// Object id of the location of the relocation
	int relocOffset;			// Object offset of the location being relocated
	int reference;				// Object id of the relocation value
	int offset;					// Offset within the reference object of the relocation address
};

class ByteCodeSection : public pxi::Section {
	vector<void *> _objects;
	void *_image;
	int _entryPoint;

public:
	ByteCodeSection(FILE *pxiFile, long long length);

	virtual ~ByteCodeSection();

	virtual bool run(char **args, int *returnValue, long long runtimeFlags);

	bool valid() {
		return _objects.size() > 0 && _image != null;
	}

private:
	void dumpIp(ExecutionContext *executionContext);

	void dumpStack(ExecutionContext *executionContext);

	string collectIp(ExecutionContext *executionContext, byte *code, int ip);

};
#endif

WORD (*builtInFunctionAddress(int index))();
int evalNative(X86_64SectionHeader *header, byte *image, char **argv, int argc);
void *formatMessage(unsigned NTStatusMessage);
void indentBy(int indent);

}


#endif // PARASOL_RUNTIME_H
