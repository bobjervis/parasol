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
#include "pxi.h"

#include "machine.h"
#include "parasol_enums.h"
#include "executionContext.h"
#include <stdio.h>
#if defined(__WIN64)
#include <windows.h>
#elif __linux__
#include <sys/mman.h>
#include <errno.h>
#include <unistd.h>
#include <dlfcn.h>
#include <unistd.h>
#include <stdlib.h>
#include <link.h>
#endif

namespace pxi {

static Section *x86_64Reader(Target sectionType, FILE *pxiFile, long long length);


Section *load(const char *filename) {
	FILE *pxiFile = fopen(filename, "rb");
	if (pxiFile == null)
		return null;
	PxiHeader header;
	if (fread(&header, 1, sizeof header, pxiFile) != sizeof header) {
		printf("Could not read header of %s\n", filename);
		return null;
	}
	if (header.magic != MAGIC_NUMBER) {
		printf("Pxi file %s does not have MAGIC_NUMBER %x\n", filename, MAGIC_NUMBER);
		return null;
	}
	if (header.version == 0) {
		printf("Expecting non-zero version of pxi file %s\n", filename);
		return null;
	}
	SectionEntry entry;
	for (int i = 0; i < header.sections; i++) {
		if (fread(&entry, 1, sizeof entry, pxiFile) != sizeof entry) {
			printf("Could not read section table of pxi file %s\n", filename);
			return null;
		}
		if 
#if defined(__WIN64)
			(entry.sectionType == ST_X86_64_WIN)
#elif __linux__
			(entry.sectionType == ST_X86_64_LNX ||
			 entry.sectionType == ST_X86_64_LNX_SRC)
#endif
		{
			if (fseek(pxiFile, (int)entry.offset, SEEK_SET) != 0) {
				printf("Could not seek to section %d @ %lld\n", i, entry.offset);
				return null;
			}
			Section *section = x86_64Reader((Target)entry.sectionType, pxiFile, entry.length);
			fclose(pxiFile);
			if (section == null) {
				printf("Reader failed for section %d of %s\n", i, filename);
				return null;
			}
			return section;
		}
	}
	printf("Could not find executable section of %s\n", filename);
	return null;
}

static Section *x86_64Reader(Target sectionType, FILE *pxiFile, long long length) {
#if defined(__WIN64)
	byte *image = (byte*)malloc(length);
#elif __linux__
    int pagesize = sysconf(_SC_PAGESIZE);
    if (pagesize == -1) {
    	printf("sysconf failed\n");
    	return null;
    }

    /* Allocate a buffer aligned on a page boundary;
       initial protection is PROT_READ | PROT_WRITE */

    byte *image = (byte*)aligned_alloc(pagesize, length);
#endif
	if (image != null) {
		if (fread(image, 1, length, pxiFile) != length) {
			printf("Could not read x86-64 image\n");
			return null;
		}
	} else {
		printf("Could not allocate image area\n");
		return null;
	}
	return new Section(sectionType, image, length);
}

class NativeBinding {
public:
	char *dllName;
	char *symbolName;
	void *address;
};

Section::Section(Target sectionType, byte *image, size_t imageLength) {
	this->sectionType = sectionType;
	if (sectionType == ST_X86_64_LNX_SRC) { // Legacy file type - Header a separate piece before image.
		this->header = (X86_64SectionHeader*)image;
		this->image = image + sizeof (X86_64SectionHeader);
		this->imageLength = imageLength - sizeof (X86_64SectionHeader);
	} else { // ST_X86_64_LNX - Image contains header, rather than header before image.
		this->header = (X86_64SectionHeader*)image;
		this->image = image;
		this->imageLength = imageLength;
	}
}

bool Section::run(char **args, int *returnValue, int heap_value) {
	parasol::ExecutionContext ec(header, image, null);

	ec.enter();
	parasol::setRuntimeParameter(RP_SECTION_TYPE, (void*)(long)sectionType);
	parasol::setRuntimeParameter(RP_PXI_HEADER, (void*)header);
	parasol::setRuntimeParameter(RP_IMAGE, image);
	parasol::setRuntimeParameter(RP_IMAGE_LENGTH, (void*)(long)imageLength);
	parasol::setRuntimeParameter(RP_HEAP, (void*)(long)heap_value);

	int argc = 0;
	for (int i = 1; args[i] != null; i++)
		argc++;

	int *pxiFixups = (int*)(image + header->relocationOffset);
	for (int i = 0; i < header->relocationCount; i++) {
		int fx = pxiFixups[i];
		long long *vp = (long long*)(image + pxiFixups[i]);
		*vp += (long long)image;
	}

	NativeBinding *nativeBindings = (NativeBinding*)(image + header->nativeBindingsOffset);
	for (int i = 0; i < header->nativeBindingsCount; i++) {
#if defined(__WIN64)
		HMODULE dll = GetModuleHandle(nativeBindings[i].dllName);
		if (dll == 0) {
			printf("Unable to locate DLL %s\n", nativeBindings[i].dllName);
			abort();
		} else {
			nativeBindings[i].address = (void*) GetProcAddress(dll, nativeBindings[i].symbolName);
			if (nativeBindings[i].address == 0) {
				printf("Unable to locate symbol %s in %s\n", nativeBindings[i].symbolName, nativeBindings[i].dllName);
				abort();
			}
		}
		CloseHandle(dll);
#elif __linux__
		const char *soName = nativeBindings[i].dllName;
		if (strcmp(soName, "libparasol.so.1") == 0)
			soName = "libparasol.so";
		void *handle = dlopen(soName, RTLD_LAZY|RTLD_NODELETE);
		if (handle == null) {
			printf("Unable to locate shared object %s (%s)\n", nativeBindings[i].dllName, dlerror());
			abort();
		} else {
			nativeBindings[i].address = dlsym(handle, nativeBindings[i].symbolName);
			if (nativeBindings[i].address == 0) {
				printf("Unable to locate symbol %s in %s (%s)\n", nativeBindings[i].symbolName, nativeBindings[i].dllName, dlerror());
				abort();
			}
		}
		dlclose(handle);
#endif
	}

#if defined(__WIN64)
	DWORD oldProtection;
	int result = VirtualProtect(image, imageLength, PAGE_EXECUTE_READWRITE, &oldProtection);
	if (result == 0) {
		printf("GetLastError=%x\n", GetLastError());
		*(char*)(long long)argc = 0;	// This should cause a crash.
	}
#elif __linux__
	if (mprotect(image, imageLength, PROT_EXEC|PROT_READ|PROT_WRITE) < 0) {
		printf("Could not protect %p [%lx] errno = %d (%s)\n", image, imageLength, errno, strerror(errno));
	}
#endif
	long long *vp = (long long*)(image + header->vtablesOffset);
	for (int i = 0; i < header->vtableData; i++, vp++)
		*vp += (long long)image;
	int value = parasol::evalNative(header, image, args + 1, argc);
	*returnValue = value;
	parasol::Exception *exception = ec.exception();
	if (exception != null) {
		printf("\nUncaught Exception.\n");
		return false;
	} else
		return true;
}

}
