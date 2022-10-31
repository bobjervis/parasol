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
#ifndef PXI_H
#define PXI_H
#include"machine.h"
#include <stddef.h>

namespace pxi {

static const unsigned MAGIC_NUMBER = ~0x50584920;
static const unsigned short CURRENT_VERSION = 1;

class Section;

Section *load(const char *filename);

class PxiHeader {
public:
	unsigned magic;					// MAGIC_NUMBER
	unsigned short version;			//
	unsigned short sections;		// The number of sections in the section table following the header
};

class SectionEntry {
public:
	unsigned char sectionType;		// A section type describing the data in the section.
private:
	unsigned char _1;		// must be zero
	short _2;		// must be zero
	int _3;			// must be zero
public:
	long long offset;			// The offset of the section in the file, in bytes.
	long long length;			// The length of the section, in bytes.
};

class X86_64SectionHeader {
public:
	int entryPoint;			// Object id of the starting function to run in the image
	int builtInOffset;		// Offset in image of built-in table
	int builtInCount;		// Total number of built-ins
	int vtablesOffset;		// Offset in image of vtables
	int vtableData;			// Total number of vtable slots
	int typeDataOffset;		// Offset in image of type data
	int typeDataLength;		// Total number of bytes of type data
	int stringsOffset;		// Offset in image of strings area
	int stringsLength;		// Total number of bytes in strings area
	int relocationOffset;	// Offset in image of relocations list
	int relocationCount;	// Total number of relocations
	int builtInsText;		// Offset in image of built-ins text
	int exceptionsOffset;	// Offset in image of exception table
	int exceptionsCount;	// Number of ExceptionEntry elements in the table
	int nativeBindingsOffset;// Offset in image of native bindings
	int nativeBindingsCount;// Number of native bindings
};

class Section {
public:
	Section(X86_64SectionHeader &header, byte *image, size_t imageLength) {
		this->header = header;
		this->image = image;
		this->imageLength = imageLength;
	}

	bool run(char **args, int *returnValue);

	X86_64SectionHeader header;
	byte *image;
	size_t imageLength;
};

}
#endif // PXI_H
