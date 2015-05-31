/*
 * x86_pxi.cc
 *
 *  Created on: May 19, 2015
 *      Author: Bob
 */
#include <windows.h>
#include "runtime.h"
#include "x86_pxi.h"

namespace parasol {

static pxi::Section *x86_64reader(FILE *pxiFile, long long length);

class Loader {
public:
	Loader();
};

Loader::Loader() {
	if (!pxi::registerSectionReader(ST_X86_64, x86_64reader))
		printf("Could not register x86_64SectionReader for ST_X86_64\n");
}

Loader loader;

X86_64Section::X86_64Section(FILE *pxiFile, long long length) {
	if (fread(&_header, 1, sizeof _header, pxiFile) != sizeof _header) {
		printf("Could not read x86-64 section header\n");
		return;
	}
	_imageLength = (size_t)length - sizeof _header;
	_image = malloc(_imageLength);
	if (_image != null) {
		if (fread(_image, 1, _imageLength, pxiFile) != _imageLength) {
			printf("Could not read x86-64 image\n");
			return;
		}
	} else {
		printf("Could not allocate image area\n");
		return;
	}

	// Do any post-load initializations and fixups
}

X86_64Section::~X86_64Section() {
	free(_image);
}

bool X86_64Section::run(char **args, int *returnValue, bool trace) {
	ExecutionContext ec(&_header, _image);

	ec.enter();

	int argc = 0;
	for (int i = 1; args[i] != null; i++)
		argc++;

	char *image = (char*)_image;
	void **builtIns = (void**)(image + _header.builtInOffset);
	for (int i = 0; i < _header.builtInCount; i++, builtIns++) {
		if ((unsigned long long)*builtIns > 50) {
			printf("builtIns = %p *builtIns = %p\n", builtIns, *builtIns);
			*(char*)argc = 0;	// This should cause a crash.
		}
		*builtIns = (void*)builtInFunctionAddress(int((long long)*builtIns));
	}

	int *pxiFixups = (int*)(image + _header.relocationOffset);
	for (int i = 0; i < _header.relocationCount; i++) {
		int fx = pxiFixups[i];
		// TODO: Implement actual fixups.
		*(char*)argc = 0;	// This should cause a crash.
	}
	DWORD oldProtection;
	int result = VirtualProtect(_image, _imageLength, PAGE_EXECUTE_READWRITE, &oldProtection);
	if (result == 0) {
		printf("GetLastError=%x\n", GetLastError());
		*(char*)argc = 0;	// This should cause a crash.
	}
	long long *vp = (long long*)(image + _header.vtablesOffset);
	for (int i = 0; i < _header.vtableData; i++, vp++)
		*vp += (long long)image;
	ec.trace = trace;
	int value = evalNative(&_header, (byte*)_image, args + 1, argc);
	*returnValue = value;
	ec.trace = false;
	ExceptionContext *raised = ec.exceptionContext(null);
	if (raised != null) {
		printf("\n");
		bool locationIsExact = false;
		char *message = (char*)formatMessage(unsigned(raised->exceptionType));
		if (raised->exceptionType == 0)
			printf("Assertion failed ip %p", raised->exceptionAddress);
		else {
			printf("Uncaught exception %x", raised->exceptionType);
			if (message != null)
				printf(" (%s)", message);
			printf(" ip %p", raised->exceptionAddress);
		}
		if (raised->exceptionType == EXCEPTION_ACCESS_VIOLATION ||
			raised->exceptionType == EXCEPTION_IN_PAGE_ERROR) {
			locationIsExact = true;
			printf(" flags %d referencing %p", raised->exceptionFlags, raised->memoryAddress);
		}

		printf("\n");
		vector<byte> stackSnapshot;

//			printf("exceptionInfo = [ %p, %p, %p, %p, %p, %p ]\n", exceptionInfo[0], exceptionInfo[1], exceptionInfo[2], exceptionInfo[3], exceptionInfo[4], exceptionInfo[5]);
		stackSnapshot.resize(raised->stackSize);
		raised->stackCopy = &stackSnapshot[0];
//			printf("stack snapshot size %d\n", stackSnapshot.length());

		fetchSnapshot(&stackSnapshot[0], stackSnapshot.size());
//			printf("    failure address %p\n", raised->exceptionAddress);
//			printf("    sp: %p fp: %p stack size: %d\n", raised->stackPointer, raised->framePointer, raised->stackSize);
		byte *stackLow = (byte*)raised->stackPointer;
		byte *stackHigh = (byte*)raised->stackPointer + raised->stackSize;
		byte *fp = (byte*)raised->framePointer;
		void *ip = raised->exceptionAddress;
		string tag = "->";
		while (fp >= stackLow && fp < stackHigh) {
//				printf("fp = %p ip = %p relative = %x", fp, ip, int(ip) - int(_staticMemory));
			void **stack = (void**)fp;
			long long nextFp = raised->slot(fp);
			int relative = int((long long)ip - (long long)image);
//				printf("relative = (%p) %x\n", ip, relative);
			string locationLabel;
//			if (relative >= (int)_imageLength || relative < 0)
				locationLabel.printf("@%x", relative);
//			else
//				locationLabel = formattedLocation(relative, locationIsExact);
			printf(" %2s %s\n", tag.c_str(), locationLabel.c_str());
//				if (nextFp != 0 && nextFp < long(fp)) {
//					printf("    *** Stored frame pointer out of sequence: %p\n", nextFp);
//					break;
//				}
			fp = (byte*)nextFp;
			ip = (void*)raised->slot(stack + 1);
			tag = "";
			locationIsExact = false;
		}
		printf("\n");
		return false;
	} else
		return true;

/*
		if (exceptionInfo[3] != null) {
			ref<ExceptionContext> ec = ref<ExceptionContext>(exceptionInfo[3]);
//			printf("assertion failed!\n");
			boolean locationIsExact = false;
			pointer<byte> message = windows.FormatMessage(unsigned(raised->exceptionType));
			string text(message);
			if (raised->exceptionType == 0)
				printf("Assertion failed ip %p", raised->exceptionAddress);
			else {
				printf("Uncaught exception %x", raised->exceptionType);
				if (message != null)
					printf(" (%s)", text);
				printf(" ip %p", raised->exceptionAddress);
			}
			if (raised->exceptionType == EXCEPTION_ACCESS_VIOLATION ||
				raised->exceptionType == EXCEPTION_IN_PAGE_ERROR) {
				locationIsExact = true;
				printf(" flags %d referencing %p", raised->exceptionFlags, raised->memoryAddress);
			}

			printf("\n");
			byte[] stackSnapshot;

//			printf("exceptionInfo = [ %p, %p, %p, %p, %p, %p ]\n", exceptionInfo[0], exceptionInfo[1], exceptionInfo[2], exceptionInfo[3], exceptionInfo[4], exceptionInfo[5]);
			stackSnapshot.resize(raised->stackSize);
			raised->stackCopy = &stackSnapshot[0];
//			printf("stack snapshot size %d\n", stackSnapshot.length());

			runtime.fetchSnapshot(&stackSnapshot[0], stackSnapshot.length());
//			printf("    failure address %p\n", raised->exceptionAddress);
//			printf("    sp: %p fp: %p stack size: %d\n", raised->stackPointer, raised->framePointer, raised->stackSize);
			address stackLow = raised->stackPointer;
			address stackHigh = pointer<byte>(raised->stackPointer) + raised->stackSize;
			address fp = raised->framePointer;
			address ip = raised->exceptionAddress;
			string tag = "->";
			while (long(fp) >= long(stackLow) && long(fp) < long(stackHigh)) {
//				printf("fp = %p ip = %p relative = %x", fp, ip, int(ip) - int(_staticMemory));
				pointer<address> stack = pointer<address>(fp);
				long nextFp = raised->slot(fp);
				int relative = int(ip) - int(_staticMemory);
//				printf("relative = (%p) %x\n", ip, relative);
				string locationLabel;
				if (relative >= _staticMemoryLength || relative < 0)
					locationLabel.printf("@%x", relative);
				else
					locationLabel = formattedLocation(relative, locationIsExact);
				printf(" %2s %s\n", tag, locationLabel);
//				if (nextFp != 0 && nextFp < long(fp)) {
//					printf("    *** Stored frame pointer out of sequence: %p\n", nextFp);
//					break;
//				}
				fp = address(nextFp);
				ip = address(raised->slot(stack + 1));
				tag = "";
				locationIsExact = false;
			}
			printf("\n");
			return 0, false;
 */
}

static pxi::Section *x86_64reader(FILE *pxiFile, long long length) {
	X86_64Section *section = new X86_64Section(pxiFile, length);
	if (section->valid())
		return section;
	else {
		delete section;
		return null;
	}
}

}
