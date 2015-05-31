namespace parasol:x86_64;

import parasol:file;
import parasol:pxi;

class X86_64Section extends pxi.Section {
	private ref<X86_64> _target;
	
	public X86_64Section(ref<X86_64> target) {
		super(pxi.SectionType.X86_64);
		_target = target;
	}
	
	public long length() {
		return _target.imageLength();
	}
	
	public void write(file.File pxiFile) {
		_target.writePxiFile(pxiFile);
	}
}

public class X86_64SectionHeader {
	public int entryPoint;			// Object id of the starting function to run in the image
	public int builtInOffset;		// Offset in image of built-in table
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
	public int exceptionsCount;		// Number of ExceptionEntry elements in the table
}
/*
 * The X86_64 image section is laid out as follows:
 * 
 * 		Section Header
 * 		
 * 		Logical Offset 0:
 * 			X86-64 machine code (function/method coies)
 * 			Built-in Table
 * 			VTables
 * 			Qword-aligned static data
 * 			Types
 * 			Strings
 * 			Dword-align static data
 * 			Word-aligned static data
 * 			Byte-aligned static data
 * 			Relocations
 * 			Exception Table
 * 			Built-ins Text
 *		Optional:
 * 			Source Locations
 */

