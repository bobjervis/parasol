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
namespace parasol:pxi;

import parasol:storage;
import parasol:runtime;

public class X86_64ExceptionEntry {
	public int location;
	public int handler;
}

public class X86_64SectionHeader {
	public int entryPoint;			// Object id of the starting function to run in the image
	public int sourceMapOffset;		// Offset in image of the source map
	public int builtInCount;		// Total number of built-ins
	public int vtablesOffset;		// Offset in image of vtables
	public int vtableData;			// Total number of vtable slots
	public int typeDataOffset;		// Offset in image of type data 
	public int typeDataLength;		// Total number of bytes of type data
	public int stringsOffset;		// Offset in image of strings area
	public int stringsLength;		// Total number of bytes in strings area
	public int relocationOffset;	// Offset in image of relocations list
	public int relocationCount;		// Total number of relocations
	public int builtInsText;		// Offset in image of built-ins text
	public int exceptionsOffset;	// Offset in image of exception table
	public int exceptionsCount;		// Number of X86_64ExceptionEntry elements in the table
	public int nativeBindingsOffset;// Offset in image of native bindings
	public int nativeBindingsCount;	// Number of native bindings
}
/**
	This describes the source locations information as it is encoded in the image.

	A compile will prepare this data and inject it into the image. The location of the
	source map is found by computing the following:

<pre>
			{@code imageAddress + relocationOffset + int.bytes * relocationCount }
</pre>

	As noted in the comments inside the class itself, the rest of the data appears 
	in the image after this object. each span<T, LEN> descrIbes an array of LEN instaances
    of type T, suitably aligned for type T. This is equivalent to a C array T[LEN].

	(Note the template {@code span<class T, long LEN>} is not currently supported.
<pre>
            Code Locations

    span<int, codeLocationsCount> codeAddress;
    span<int, codeLocationsCount> fileIndex;
    span<int, codeLocationsCount> fileOffset;

            Source Files

    span<int, sourceFileCount> filename;        // filename is the image offset of the
                                                // string literal containing the name
    span<int, sourceFileCount> firstLineNumber; // The index into the lineNumbers and
                                                // lineFileOffsets arrays.
    span<int, sourceFileCount> linesCount;
    span<int, sourceFileCount> baseLineNumber;  // usually 1 for a normal file, but
                                                // any value that is relevant to the
                                                // context from which the source came
            Source Line Numbers

	span<int, lineNumberCount> lineFileOffsets; // All the line numbers across all files
</pre>
 */
public class X86_64SourceMap {
	public int codeLocationsCount;
	public int sourceFileCount;
	public int lineNumberCount;
}

