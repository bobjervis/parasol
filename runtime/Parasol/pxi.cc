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
#include "pxi.h"

#include "common/file_system.h"
#include "common/machine.h"
#include "parasol_enums.h"

namespace pxi {

Pxi *Pxi::load(const string &filename) {
	Pxi *pxi = new Pxi(filename);
	if (pxi->read())
		return pxi;
	else {
		delete pxi;
		return null;
	}
}

Pxi::Pxi(const string &filename) {
	_filename = filename;
}

bool Pxi::read() {
	FILE *pxiFile = fileSystem::openBinaryFile(_filename);
	if (pxiFile == null)
		return null;
	_section = read(pxiFile);
	fclose(pxiFile);
	return _section != null;
}

bool Pxi::run(char **args, int *returnValue, long long runtimeFlags) {
	return _section->run(args, returnValue, runtimeFlags);
}

class ReaderMap {
public:
	SectionType sectionType;
	Section *(*sectionReader)(FILE *pxiFile, long long length);
};

static vector<ReaderMap> readerMap;

Section *Pxi::read(FILE *pxiFile) {
	PxiHeader header;
	if (fread(&header, 1, sizeof header, pxiFile) != sizeof header) {
		printf("Could not read header of %s\n", _filename.c_str());
		return null;
	}
	if (header.magic != MAGIC_NUMBER) {
		printf("Pxi file %s does not have MAGIC_NUMBER %x\n", _filename.c_str(), MAGIC_NUMBER);
		return null;
	}
	if (header.version == 0) {
		printf("Expecting non-zero version of pxi file %s\n", _filename.c_str());
		return null;
	}
	SectionEntry *entries = new SectionEntry[header.sections];
	int sectionTableSize = sizeof (SectionEntry) * header.sections;
	if (fread(entries, 1, sectionTableSize, pxiFile) != sectionTableSize) {
		printf("Could not read section table of pxi file %s\n", _filename.c_str());
		return null;
	}
	int best = -1;
	int bestPriority = readerMap.size();
	for (int i = 0; i < header.sections; i++) {
		for (int j = 0; j < bestPriority; j++) {
			if (entries[i].sectionType == readerMap[j].sectionType &&
				readerMap[j].sectionReader != null) {
				best = i;
				bestPriority = j;
			}
		}
	}
	if (best < 0) {
		printf("Could not find executable section of %s\n", _filename.c_str());
		return null;
	}
	if (fseek(pxiFile, (int)entries[best].offset, SEEK_SET) != 0) {
		printf("Could not seek to section %d @ %lld\n", best, entries[best].offset);
		return null;
	}
	Section *section = readerMap[bestPriority].sectionReader(pxiFile, entries[best].length);
	if (section == null) {
		printf("Reader failed for section %d of %s\n", best, _filename.c_str());
		return null;
	}
	return section;
}

bool registerSectionReader(SectionType sectionType, Section *(*sectionReader)(FILE *pxiFile, long long length)) {
	for (int i = 0; i < readerMap.size(); i++) {
		if (readerMap[i].sectionType == sectionType)
			return false;
	}
	ReaderMap rm = { sectionType, sectionReader };
	readerMap.push_back(rm);
	return true;
}

}
