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
#ifndef PXI_H
#define PXI_H
#include <stdio.h>
#include "common/string.h"
#include "parasol_enums.h"

namespace pxi {

static const unsigned MAGIC_NUMBER = ~0x50584920;
static const unsigned short CURRENT_VERSION = 1;

class Section;

class Pxi {
public:
	static Pxi *load(const string &filename);

	static Pxi *create(const string &filename);

	bool run(char **args, int *returnValue, long long runtimeFlags);

private:
	Pxi(const string &filename);

	bool read();

	Section *read(FILE *pxiFile);

	Section* _section;
	string _filename;
};

class PxiHeader {
public:
	PxiHeader() {
		magic = MAGIC_NUMBER;
		version = CURRENT_VERSION;
	}

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

class Section {
public:
	virtual bool run(char **args, int *returnValue, long long runtimeFlags) = 0;
};

bool registerSectionReader(SectionType sectionType, Section *(*sectionReader)(FILE *pxiFile, long long length));

}
#endif // PXI_H
