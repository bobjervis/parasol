/*
 * x86_pxi.h
 *
 *  Created on: May 19, 2015
 *      Author: Bob
 */

#ifndef X86_PXI_H_
#define X86_PXI_H_

#include "pxi.h"

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
};

class X86_64Section : public pxi::Section {
	X86_64SectionHeader _header;
	void *_image;
	size_t _imageLength;

public:
	X86_64Section(FILE *pxiFile, long long length);

	virtual ~X86_64Section();

	virtual bool run(char **args, int *returnValue, bool trace);

	bool valid() {
		return _image != null;
	}

};

}
#endif /* X86_PXI_H_ */
