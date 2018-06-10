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
#ifndef X86_PXI_H_
#define X86_PXI_H_

#include "pxi.h"
#include <string.h>

namespace parasol {

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

class X86_64Section : public pxi::Section {
	X86_64SectionHeader _header;
	void *_image;
	size_t _imageLength;
	char *_libParasolPath;

public:
	X86_64Section(FILE *pxiFile, long long length);

	virtual ~X86_64Section();

	virtual bool run(char **args, int *returnValue, long long runtimeFlags);

	bool valid() {
		return _image != null;
	}

	void reportLibParasolPath(const char *path) {
		_libParasolPath = strdup(path);
	}
};

}
#endif /* X86_PXI_H_ */
