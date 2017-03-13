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
#if defined(__WIN64)
#include <windows.h>
#endif
#include "runtime.h"
#include "x86_pxi.h"

namespace parasol {

static pxi::Section *x86_64reader(FILE *pxiFile, long long length);
static pxi::Section *x86_64NextReader(FILE *pxiFile, long long length);

class Loader {
public:
	Loader();
};

Loader::Loader() {
	if (!pxi::registerSectionReader(ST_X86_64, x86_64reader))
		printf("Could not register x86_64SectionReader for ST_X86_64\n");
	if (!pxi::registerSectionReader(ST_X86_64_NEXT, x86_64NextReader))
		printf("Could not register x86_64SectionReaderNext for ST_X86_64_NEXT\n");
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

bool X86_64Section::run(char **args, int *returnValue, long long runtimeFlags) {
	ExecutionContext ec(&_header, _image, runtimeFlags);

	ec.enter();

	int argc = 0;
	for (int i = 1; args[i] != null; i++)
		argc++;

	char *image = (char*)_image;
	void **builtIns = (void**)(image + _header.builtInOffset);
	for (int i = 0; i < _header.builtInCount; i++, builtIns++) {
		if ((unsigned long long)*builtIns > 80) {
			printf("builtIns = %p *builtIns = %p\n", builtIns, *builtIns);
			*(char*)argc = 0;	// This should cause a crash.
		}
		*builtIns = (void*)builtInFunctionAddress(int((long long)*builtIns));
	}

	int *pxiFixups = (int*)(image + _header.relocationOffset);
	for (int i = 0; i < _header.relocationCount; i++) {
		int fx = pxiFixups[i];
		long long *vp = (long long*)(image + pxiFixups[i]);
		*vp += (long long)image;
	}
#if defined(__WIN64)
	DWORD oldProtection;
	int result = VirtualProtect(_image, _imageLength, PAGE_EXECUTE_READWRITE, &oldProtection);
	if (result == 0) {
		printf("GetLastError=%x\n", GetLastError());
		*(char*)argc = 0;	// This should cause a crash.
	}
#endif
	long long *vp = (long long*)(image + _header.vtablesOffset);
	for (int i = 0; i < _header.vtableData; i++, vp++)
		*vp += (long long)image;
	ec.trace = (runtimeFlags & 2) != 0;
	int value = evalNative(&_header, (byte*)_image, args + 1, argc);
	*returnValue = value;
	ec.trace = false;
	Exception *exception = ec.exception();
	if (exception != null) {
		printf("\nUncaught Exception.\n");
		return false;
	} else
		return true;
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

X86_64NextSection::X86_64NextSection(FILE *pxiFile, long long length) {
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

X86_64NextSection::~X86_64NextSection() {
	free(_image);
}

class NativeBinding {
public:
	char *dllName;
	char *symbolName;
	void *address;
};

bool X86_64NextSection::run(char **args, int *returnValue, long long runtimeFlags) {
	ExecutionContext ec((X86_64SectionHeader*)&_header, _image, runtimeFlags);

	ec.enter();

	int argc = 0;
	for (int i = 1; args[i] != null; i++)
		argc++;

	char *image = (char*)_image;
	void **builtIns = (void**)(image + _header.builtInOffset);
	for (int i = 0; i < _header.builtInCount; i++, builtIns++) {
		if ((unsigned long long)*builtIns > 80) {
			printf("builtIns = %p *builtIns = %p\n", builtIns, *builtIns);
			*(char*)argc = 0;	// This should cause a crash.
		}
		*builtIns = (void*)builtInFunctionAddress(int((long long)*builtIns));
	}

	int *pxiFixups = (int*)(image + _header.relocationOffset);
	for (int i = 0; i < _header.relocationCount; i++) {
		int fx = pxiFixups[i];
		long long *vp = (long long*)(image + pxiFixups[i]);
		*vp += (long long)image;
	}

	NativeBinding *nativeBindings = (NativeBinding*)(image + _header.nativeBindingsOffset);
	for (int i = 0; i < _header.nativeBindingsCount; i++) {
#if defined(__WIN64)
		HMODULE dll = GetModuleHandle(nativeBindings[i].dllName);
		if (dll == 0) {
			printf("Unable to locate DLL %s\n", nativeBindings[i].dllName);
			*(char*)argc = 0;	// This should cause a crash.
		} else {
			nativeBindings[i].address = (void*) GetProcAddress(dll, nativeBindings[i].symbolName);
			if (nativeBindings[i].address == 0) {
				printf("Unable to locate DLL %s\n", nativeBindings[i].dllName);
				*(char*)argc = 0;	// This should cause a crash.
			}
		}
#endif
	}

#if defined(__WIN64)
	DWORD oldProtection;
	int result = VirtualProtect(_image, _imageLength, PAGE_EXECUTE_READWRITE, &oldProtection);
	if (result == 0) {
		printf("GetLastError=%x\n", GetLastError());
		*(char*)argc = 0;	// This should cause a crash.
	}
#endif
	long long *vp = (long long*)(image + _header.vtablesOffset);
	for (int i = 0; i < _header.vtableData; i++, vp++)
		*vp += (long long)image;
	ec.trace = (runtimeFlags & 2) != 0;
	int value = evalNative((X86_64SectionHeader*)&_header, (byte*)_image, args + 1, argc);
	*returnValue = value;
	ec.trace = false;
	Exception *exception = ec.exception();
	if (exception != null) {
		printf("\nUncaught Exception.\n");
		return false;
	} else
		return true;
}

static pxi::Section *x86_64NextReader(FILE *pxiFile, long long length) {
	X86_64NextSection *section = new X86_64NextSection(pxiFile, length);
	if (section->valid())
		return section;
	else {
		delete section;
		return null;
	}
}

}
