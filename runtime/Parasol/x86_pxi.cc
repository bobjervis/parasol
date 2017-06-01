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
#if defined(__WIN64)
#include <windows.h>
#elif __linux__
#include <sys/mman.h>
#include <errno.h>
#include <unistd.h>
#include <dlfcn.h>
#endif
#include "runtime.h"
#include "x86_pxi.h"

namespace parasol {

static pxi::Section *x86_64Reader(FILE *pxiFile, long long length);

class Loader {
public:
	Loader();
};

Loader::Loader() {
	if (!pxi::registerSectionReader(ST_X86_64_WIN, x86_64Reader))
		printf("Could not register x86_64SectionReader for ST_X86_64_WIN\n");
}

Loader loader;

X86_64Section::X86_64Section(FILE *pxiFile, long long length) {
	if (fread(&_header, 1, sizeof _header, pxiFile) != sizeof _header) {
		printf("Could not read x86-64 section header\n");
		return;
	}
	_imageLength = (size_t)length - sizeof _header;
#if defined(__WIN64)
	_image = malloc(_imageLength);
#elif __linux__
    int pagesize = sysconf(_SC_PAGESIZE);
    if (pagesize == -1) {
    	printf("sysconf failed\n");
    	return;
    }

    /* Allocate a buffer aligned on a page boundary;
       initial protection is PROT_READ | PROT_WRITE */

    _image = aligned_alloc(pagesize, _imageLength);
#endif
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

class NativeBinding {
public:
	char *dllName;
	char *symbolName;
	void *address;
};

bool X86_64Section::run(char **args, int *returnValue, long long runtimeFlags) {
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
				printf("Unable to locate symbol %s in %s\n", nativeBindings[i].symbolName, nativeBindings[i].dllName);
				*(char*)argc = 0;	// This should cause a crash.
			}
		}
		CloseHandle(dll);
#elif __linux__
		void *handle = dlopen(nativeBindings[i].dllName, RTLD_LAZY);
		if (handle == null) {
			printf("Unable to locate shared object %s (%s)\n", nativeBindings[i].dllName, dlerror());
			*(char*)argc = 0;	// This should cause a crash.
		} else {
			nativeBindings[i].address = dlsym(handle, nativeBindings[i].symbolName);
			if (nativeBindings[i].address == 0) {
				printf("Unable to locate symbol %s in %s (%s)\n", nativeBindings[i].symbolName, nativeBindings[i].dllName, dlerror());
				*(char*)argc = 0;	// This should cause a crash.
			}
		}
		dlclose(handle);
#endif
	}

#if defined(__WIN64)
	DWORD oldProtection;
	int result = VirtualProtect(_image, _imageLength, PAGE_EXECUTE_READWRITE, &oldProtection);
	if (result == 0) {
		printf("GetLastError=%x\n", GetLastError());
		*(char*)argc = 0;	// This should cause a crash.
	}
#elif __linux__
	if (mprotect(_image, _imageLength, PROT_EXEC|PROT_READ|PROT_WRITE) < 0) {
		printf("Could not protect %p [%x] errno = %d (%s)\n", _image, _imageLength, errno, strerror(errno));
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

static pxi::Section *x86_64Reader(FILE *pxiFile, long long length) {
	X86_64Section *section = new X86_64Section(pxiFile, length);
	if (section->valid())
		return section;
	else {
		delete section;
		return null;
	}
}

}
