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
/**
 * Provides facilities for manipulating the Parasol language runtime.
 */
namespace parasol:runtime;

import native:C;
import native:linux;
import native:windows;
import parasol:context;
import parasol:exception;
import parasol:thread.Thread;
import parasol:pxi;
import parasol:memory;
import parasol:storage;
import parasol:thread;
/**
 * This is a special variable used to control compile-time conditional compilation.
 *
 * For now, this is hacked in to the compiler optimization logic to communicate precisely which compile
 * target was selected to build this runtime.
 */
@CompileTarget
public Target compileTarget;
/**
 * The target machine/OS of the code generator is also the identifier of the running environment.
 */
@Header("ST_")
public enum Target {
	/**
	 * This indicates some sort of error condition, like an invalid target option.
	 */
	ERROR,
	/**
	 * @ignore RESERVED - DO NOT USE
	 */
	X86_64_LNX_NEW,
	/**
	 * @ignore RESERVED - DO NOT USE
	 */
	NOT_USED_1,
	/**
	 * This is an Intel x64-64 machine instruction set running the Linux operating system.
	 */
	X86_64_LNX,
	/**
	 * This is an Intel x86-64 machine instruction set running the Windows operating system.
	 */
	X86_64_WIN,	
	/**
	 * This is an Intel x64-64 machine instruction set running the Linux operating system.
	 * The section includes source locations maps (used in stack traces and useful for a
	 * debugger)
	 */
	X86_64_LNX_SRC,
	/**
	 * This is not an actual target, but one greater than the maximum valid target value.
	 */
	MAX_TARGET
}
/** @ignore */
@Linux("libparasol.so.1", "eval")
@Windows("parasol.dll", "eval")
public abstract int eval(ref<pxi.X86_64SectionHeader> header, address image, pointer<pointer<byte>> args, int argsCount);
/** @ignore */
@Linux("libparasol.so.1", "supportedTarget")
@Windows("parasol.dll", "supportedTarget")
public abstract int supportedTarget(int index);
/** @ignore */
@Linux("libparasol.so.1", "stackTop")
@Windows("parasol.dll", "stackTop")
public abstract address stackTop();
/**
 * This method returns the byte address of the next instruction after the call to the currently running function.
 *
 * @return The byte address of the return address of the current function. A value of null indicates that the returnAddress of this function is unavailable.
 */
@Linux("libparasol.so.1", "returnAddress")
@Windows("parasol.dll", "returnAddress")
public abstract address returnAddress();
/**
 * This method returns the frame pointer for the current function.
 *
 * @return The value of the frame pointer. A value of null indicates that a frame pointer
 * for this method is unavailable. 
 */
@Linux("libparasol.so.1", "framePointer")
@Windows("parasol.dll", "framePointer")
public abstract address framePointer();
/**
 * This method returns a value accessible from the FS segment register.
 *
 * @param The offset from FS to retrieve. This value should be 8-byte aligned.
 *
 * @return The long value stored at that location.
 */
@Linux("libparasol.so.1", "getFsSegment")
@Windows("parasol.dll", "getFsSegment")
public abstract address getFsSegment(long offset);

/**
 * Allocate a large page-aligned region of storage, outside the Heap.
 *
 * @param length The size of the region in bytes.
 *
 * @return The address of the allocated region, or null if the region could not be allocated.
 */
public address allocateRegion(long length) {
	address v;
	if (compileTarget == Target.X86_64_WIN) {
		v = windows.VirtualAlloc(null, length, windows.MEM_COMMIT|windows.MEM_RESERVE, windows.PAGE_READWRITE);
	} else if (compileTarget == Target.X86_64_LNX) {
		int pagesize = linux.sysconf(linux.SysConf._SC_PAGESIZE);
		if (pagesize == -1) {
			printf("sysconf failed (%d)\n", int(linux.SysConf._SC_PAGESIZE));
			assert(false);
		}
		return linux.aligned_alloc(pagesize, length);
	} else
		return null;
	return v;
}
/**
 * Make a region of storage executable.
 *
 * @param location The starting address to be marked.
 * @param length The number of bytes to be marked as executable.
 *
 * @return true if the region could be marked, false otherwise.
 */
public boolean makeRegionExecutable(address location, long length) {
	if (compileTarget == Target.X86_64_WIN) {
		unsigned oldProtection;
		int result = windows.VirtualProtect(location, length, windows.PAGE_EXECUTE_READWRITE, &oldProtection);
//		printf("VirtualProtect(%p, %d, %x, %p) -> %d oldProtection %x\n", location, length, int(windows.PAGE_EXECUTE_READWRITE), null, result, int(oldProtection));
		return result != 0;
	} else if (compileTarget == Target.X86_64_LNX)
		return linux.mprotect(location, length, linux.PROT_EXEC|linux.PROT_READ|linux.PROT_WRITE) == 0;
	return false;
}
/**
 * Free a region allocated via {@link allocateRegion}
 *
 * @param region The address of a region returned from a prior call to {@link allocateRegion}.
 * @param length The length supplied with the original call to {@link allocateRegion}.
 */
public void freeRegion(address region, long length) {
	if (compileTarget == Target.X86_64_WIN) {
		windows.VirtualFree(region, length, windows.MEM_RELEASE);
	} else if (compileTarget == Target.X86_64_LNX) {
		C.free(region);
	}
}
/**
 * The Image object describes essential information about the image that is currently running.
 * As a PXI file is loaded or a Parasol compiler instance runs a just-compiled image, the
 * new image runs with its own copy of static data, so the Image object is created new.
 *
 * The image object is initially constructed by extracting information from the runtme parameters
 * passed into the running instance. These parameters are set by the parasolrt executable when
 * launching a compiled image, or set by the Parasol compiler when running a new image.
 *
 * Image objects are also created by dumppxi to hold an in-memory copy of a pxi file, and by pbug
 * to make and examine a copy of the Parasol image being debugged.
 *
 * To support all these scenarios, the _image parameter is the pointer to the local, in-memory
 * image, while _imageAddr is the file offset (for dumppxi)
 */
public class Image {
	private ref<pxi.X86_64SectionHeader> _pxiHeader;
	private pointer<byte> _image;
	private long _imageAddr;
	private int _imageLength;
	private ref<pxi.X86_64SourceMap> _sourceMap;
	private pointer<int> _codeAddresses;
	private pointer<int> _fileIndices;
	private pointer<int> _fileOffsets;
	private pointer<int> _filenames;
	private pointer<int> _firstLineNumbers;
	private pointer<int> _linesCounts;
	private pointer<int> _baseLineNumbers;
	private pointer<int> _lineFileOffsets;

	Image() {
		_pxiHeader = pxiHeader();
		_image = pointer<byte>(imageAddress());
		_imageAddr = long(_image);
		_imageLength = imageLength();
	}

	public Image(long imageAddr, address image, int length) {
		_imageAddr = imageAddr;
		_image = pointer<byte>(image);
		_pxiHeader = ref<pxi.X86_64SectionHeader>(image);
		_imageLength = length;
	}
	/**
	 * Return the version of the image.
	 *
	 * @return The version string of the image, or null if no version information is available.
	 */
	public string version() {
		if (_pxiHeader.versionOffset > 0) {
			v := _image + _pxiHeader.versionOffset + int.bytes;
			
			return string(v);		// This will safely construct a string from the null terminated bytes
									// at the versionOffset (plus the string literal length int).
		} else
			return null;
	}
	/**
	 * Construct a string representing a machine location, including information about relative location
	 * within a compiled image.
	 *
	 * @param ip The machine address to obtain a source location for.
	 *
	 * @param offset The offset into the Parasol code image where the symbol could be found. If
	 * the value is negative, then only the ip is used and it is assumed to be outside Parasol code.
	 *
	 * @param locationIsExact true if this is the exact address you care about. For example, if
	 * it is the return address from a function, it may be pointing to the next source line so
	 * pass false to this parameter and the code will adjust to look for the location one byte before
	 * the given address.
	 *
	 * @return The formatted string.
	 *
	 * If the location is outside a compiled Parasol image, a native operating system utility is used to obtain
	 * as good a symbolic address as reasonably possible. If no good symbolic address is available, then the
	 * hex address is formatted.
	 *
	 * If the location is inside a compile Parasol image, the Parasol source filename and line number is returned,
	 * along with the image-relative offset of the machine code.
	 */
	public string formattedLocation(long ip, int offset) {
		string filename;
		int lineNumber;
		(filename, lineNumber) = getSourceLocation(ip);
		if (filename == null) {
			return formattedExternalLocation(ip);
		} else {
			string result;
			result.printf("%s %d", filename, lineNumber);
			if (offset != 0)
				result.printf(" (@%x)", offset);
			return result;
		}
	}

	private static string formattedExternalLocation(long ip) {
		string result;
		if (compileTarget == Target.X86_64_WIN) {
		} else if (compileTarget == Target.X86_64_LNX) {
			linux.Dl_info info;
	
			if (ip != 0 && linux.dladdr(address(ip), &info) != 0) {
				long symOffset = ip - long(info.dli_saddr);
				if (info.dli_sname == null)
					result.printf("%s (@%p)", string(info.dli_fname), ip); 
				else
					result.printf("%s %s+0x%x (@%p)", string(info.dli_fname), string(info.dli_sname), symOffset, ip); 
				return result;
			}
		}
		result.printf("@%x", ip);
		return result;
	}
	
	/** 
 	 * Return the source filename and line number corresponding to the machine address passed
	 * to this function.
	 *
	 * @param ip The instruction pointer to be found in the image's source information.
	 * Note that to request the source line of a return address, the value passed should be one
	 * less than the return address.
	 *
	 * @param isReturnAddress If true, the ip parameter is the stored return address. Source line
	 * information should account for this detail since in some cases, the return address of a
	 * function call may actually point at the source line after the call itself.
	 *
	 * @return The source filename at the indicated location, or null if the code address is not
	 * in Parasol code.
	 * @return The line number pf the indicated location, or -1 if the code location is not in
	 * Parasol code.
	 */
	public string, int getSourceLocation(long ip) {
		if (ip < _imageAddr ||
			highCodeAddress() <= ip)
			return null, -1;
		if (_sourceMap == null) {
			_sourceMap = ref<pxi.X86_64SourceMap>(_image + _pxiHeader.sourceMapOffset);
			_codeAddresses = pointer<int>(_image + _pxiHeader.sourceMapOffset + 
														pxi.X86_64SourceMap.bytes);
			_fileIndices = _codeAddresses + _sourceMap.codeLocationsCount;
			_fileOffsets = _fileIndices + _sourceMap.codeLocationsCount;
			_filenames = _fileOffsets + _sourceMap.codeLocationsCount;
//			for (int i = 0; i < _sourceMap.codeLocationsCount; i++) {
//				printf("[%5d] %8x f %3d. %6d.\n", i, _codeAddresses[i], _fileIndices[i], _fileOffsets[i]);
//			}
//			for (int i = 0; i < _sourceMap.sourceFileCount; i++) {
//				printf("[%3d] ", i);
//				pointer<byte> filename = _image + _filenames[i];
//				printf("%s\n", filename);
//			}
			_firstLineNumbers = _filenames + _sourceMap.sourceFileCount;
			_linesCounts = _firstLineNumbers + _sourceMap.sourceFileCount;
			_baseLineNumbers = _linesCounts + _sourceMap.sourceFileCount;
			_lineFileOffsets = _baseLineNumbers + _sourceMap.sourceFileCount;
		}

		int offset = int(ip - _imageAddr);
		
		int[] lookup(_codeAddresses, _sourceMap.codeLocationsCount);
			
		int index = lookup.binarySearchClosestNotGreater(offset);
//		printf("offset = %x index = %d\n", offset, index);
//		printf("bucket offset %x\n", _codeAddresses[index]);
//		printf("  next offset %x\n", _codeAddresses[index + 1]);

		int fileIndex = _fileIndices[index] - 1;
		if (fileIndex < 0)
			return null, -1;
		int fileOffset = _fileOffsets[index];
		string filename = string(_image + _filenames[fileIndex]);


//		printf("File %d. %s offset %d\n", fileIndex, filename, fileOffset);

		int lineEntryOffset = _firstLineNumbers[fileIndex];

		int[] lookupLine(pointer<int>(pointer<byte>(_lineFileOffsets) + lineEntryOffset),
							_linesCounts[fileIndex]);
 		filename = storage.makeCompactPath(filename, "./xyz");
		int lineNumber = lookupLine.binarySearchClosestGreater(fileOffset) + 1 + _baseLineNumbers[fileIndex];
//		printf("lineNumber = %d base line number %d\n", lineNumber, _baseLineNumbers[fileIndex]);
		return filename, lineNumber;
	}
	/** @ignore */
	public long codeAddress() {
		return _imageAddr;
	}
	/** @ignore */
	public long highCodeAddress() {
		return _imageAddr + _pxiHeader.typeDataOffset;
	}

	public long entryPoint() {
		return _imageAddr + _pxiHeader.entryPoint;
	}

	public void printHeader(long fileOffset) {
		printf("\n");
		if (_pxiHeader.versionOffset > 0 && _pxiHeader.versionOffset < _imageLength) {
			v := _image + _pxiHeader.versionOffset;
			printf("        version  %20s\n", string(v));
		} else
			printf("        version offset       %8x\n", _pxiHeader.versionOffset);
		if (fileOffset >= 0)
			printf("        image offset         %8x\n", fileOffset);
		printf("        entryPoint           %8x\n", _pxiHeader.entryPoint);
		printf("        vtablesOffset        %8x", _pxiHeader.vtablesOffset);
		if (fileOffset >= 0)
			printf(" (file offset %x)", _pxiHeader.vtablesOffset + fileOffset);
		printf("\n");
		printf("        vtableData           %8x\n", _pxiHeader.vtableData);
		printf("        typeDataOffset       %8x", _pxiHeader.typeDataOffset);
		if (fileOffset >= 0)
			printf(" (file offset %x)", _pxiHeader.typeDataOffset + fileOffset);
		printf("\n");
		printf("        typeDataLength       %8x\n", _pxiHeader.typeDataLength);
		printf("        stringsOffset        %8x", _pxiHeader.stringsOffset);
		if (fileOffset >= 0)
			printf(" (file offset %x)", _pxiHeader.stringsOffset + fileOffset);
		printf("\n");
		printf("        stringsLength        %8x\n", _pxiHeader.stringsLength);
		printf("        nativeBindingsOffset %8x", _pxiHeader.nativeBindingsOffset);
		if (fileOffset >= 0)
			printf(" (file offset %x)", _pxiHeader.nativeBindingsOffset + fileOffset);
		printf("\n");
		printf("        nativeBindingsCount  %8d.\n", _pxiHeader.nativeBindingsCount);
		printf("        relocationOffset     %8x", _pxiHeader.relocationOffset);
		if (fileOffset >= 0)
			printf(" (file offset %x)", _pxiHeader.relocationOffset + fileOffset);
		printf("\n");
		printf("        relocationCount      %8d.\n", _pxiHeader.relocationCount);
		printf("        builtInsText         %8x", _pxiHeader.builtInsText);
		if (fileOffset >= 0)
			printf(" (file offset %x)", _pxiHeader.builtInsText + fileOffset);
		printf("\n");
		printf("        exceptionsOffset     %8x", _pxiHeader.exceptionsOffset);
		if (fileOffset >= 0)
			printf(" (file offset %x)", _pxiHeader.exceptionsOffset + fileOffset);
		printf("\n");
		printf("        exceptionsCount      %8d.\n", _pxiHeader.exceptionsCount);
		printf("        sourceMapOffset      %8x", _pxiHeader.sourceMapOffset);
		if (fileOffset >= 0)
			printf(" (file offset %x)", _pxiHeader.sourceMapOffset + fileOffset);
		printf("\n");
	}
}
/**
 * The image object describes various aspects of the currently running Parasol instance.
 *
 * Note that the pc command line runs a compiled parasol instance of the command-line compiler.
 * When that compiler runs the compiled program, it does so by creating a new Parasol instance
 * in memory. This object describes information about the compiled image, the code, static data and
 * various meta-data stored in the image.
 */
public Image image;
/**
 * This is defined in C++ code and provides the necessary context information when starting up any
 * Parasol thread.
 */
public class ExecutionContext {
	public pointer<byte> _stackTop;
	public ref<Exception> _exception;
	public ref<pxi.X86_64SectionHeader> _pxiHeader;
	public address _image;
	public pointer<pointer<byte>> _argv;
	public int _argc;
	public address _sourceLocations;
	public int _sourceLocationsCount;
	public ref<thread.Thread> _parasolThread;
	public pointer<address> _runtimeParameters;
	public int _runtimeParametersCount;
}

public class SourceLocation {
	public ref<SourceFile>		file;			// Source file containing this location
	public SourceOffset			location;		// Source byte offset
	public int					offset;			// Code location
}

public class SourceFile {
	private string _filename;
	private SourceOffset[] _lines;
	private int _baseLineNumber;				// Line number of first character in scanner input.

	public int sourceFileIndex;					// Set during code generation to indicate that a source
												// file entry has been allocated in the image

	public SourceFile(string filename) {
		_filename = filename;
		sourceFileIndex = -1;
	}

	public SourceFile(string filename, int baseLineNumber) {
		_filename = filename;
		_baseLineNumber = baseLineNumber;
	}

	public string filename() {
		return _filename;
	}

	public void append(SourceOffset location) {
		_lines.append(location);
	}

	public int lineNumber(SourceOffset location) {
		int x = _lines.binarySearchClosestGreater(location);
		return _baseLineNumber + x;
	}

	public ref<SourceOffset[]> lines() {
		return &_lines;
	}

	public int baseLineNumber() {
		return _baseLineNumber;
	}
}
	
public class SourceOffset {
	public static SourceOffset OUT_OF_FILE(-1);

	public int		offset;
	
	public SourceOffset() {
	}
	
	public SourceOffset(int v) {
		offset = v;
	}

	public int compare(SourceOffset loc) {
		return offset - loc.offset;
	}

	public boolean isInFile() {
		return offset != OUT_OF_FILE.offset;
	}
}
/** @ignore */
public ref<Thread> parasolThread() {
	return ref<Thread>(getRuntimeParameter(PARASOL_THREAD));
}
/** @ignore */
public void setParasolThread(ref<Thread> t) {
	setRuntimeParameter(PARASOL_THREAD, t);
}
/** @ignore */
public memory.StartingHeap startingHeap() {
	return memory.StartingHeap(getRuntimeParameter(LEAKS_FLAG));
}
/** @ignore */
public void setStartingHeap(memory.StartingHeap newValue) {
	setRuntimeParameter(LEAKS_FLAG, address(newValue));
}
/** @ignore */
public void setSectionType() {
	if (compileTarget == Target.X86_64_WIN) {
		setRuntimeParameter(SECTION_TYPE, address(Target.X86_64_WIN));
	} else if (compileTarget == Target.X86_64_LNX) {
		setRuntimeParameter(SECTION_TYPE, address(Target.X86_64_LNX_SRC));
	}
}
/** @ignore */
public ref<pxi.X86_64SectionHeader> pxiHeader() {
	return ref<pxi.X86_64SectionHeader>(getRuntimeParameter(PXI_HEADER));
}
/** @ignore */
public void setPxiHeader(ref<pxi.X86_64SectionHeader> newHeader) {
	setRuntimeParameter(PXI_HEADER, newHeader);
}
/** @ignore */
public address imageAddress() {
	return getRuntimeParameter(IMAGE);
}
/** @ignore */
public void setImageAddress(address newImage) {
	setRuntimeParameter(IMAGE, newImage);
}
/** @ignore */
public int imageLength() {
	return int(getRuntimeParameter(IMAGE_LENGTH));
}
/** @ignore */
public void setImageLength(int newLength) {
	setRuntimeParameter(IMAGE_LENGTH, address(long(newLength)));
}
/*	Runtime Parameters
 *
 *	These are context parameters passed from the enclosing environment, either
 *	the Parasol compiler or the binary executable that has loaded a PXI file.
 *
 *	Each parameter is an 'address' which can be treated as a simple integer or e
 *	
 */
/** @ignore */
@Constant
int PARASOL_THREAD = 0;
/** @ignore */
@Constant
int LEAKS_FLAG = 3;
/** @ignore */
@Constant
int SECTION_TYPE = 4;
/** @ignore */
@Constant
int PXI_HEADER = 5;
/** @ignore */
@Constant
int IMAGE = 6;
/** @ignore */
@Constant
int IMAGE_LENGTH = 7;
/** @ignore */
@Linux("libparasol.so.1", "getRuntimeParameter")
@Windows("parasol.dll", "getRuntimeParameter")
public abstract address getRuntimeParameter(int i);
/**
 @ignore */
@Linux("libparasol.so.1", "setRuntimeParameter")
@Windows("parasol.dll", "setRuntimeParameter")
public abstract void setRuntimeParameter(int i, address newValue);

public class Profiler {
	ref<ProfileTables> _tables;

	public Profiler(ref<ProfileTables> tables) {
		_tables = tables;
	}
}
/** @ignore */
public class ProfileTables {
}

public class Coverage {
	ref<CoverageTables> _tables;

	public Coverage(ref<CoverageTables> tables) {
		_tables = tables;
	}
}
/** @ignore */
public class CoverageTables {
}
/**
 * Return a text stack trace for the code location of the call to this function.
 *
 * @return The stack trace of the current running thread.
 */
public string stackTrace() {
	return stackTrace(0);
}
/**
 * Return a text stack trace for the code location of the call to this function.
 *
 *
 * @param skipFrames Skip that many frames when generating the stack trace. If
 * the value is zero, all frames, starting with the caller, are included. A value
 * of 1 will exclude the caller's frame, a value of 2 will exclude the caller and 
 * the caller's caller. If the skip value is larger than the number of frames in
 * the stack, the returned trace is the empty string.
 *
 * @return The stack trace of the current running thread.
 */
public string stackTrace(int skipFrames) {
	string output;
	long lowCode = image.codeAddress();
	address ip = returnAddress();
	address frame = framePointer();
	address top = stackTop();
	if (long(frame) > long(top))
		return output;		
	while (frame != null) {
		pointer<address> lastFrame = pointer<address>(frame);
		frame = lastFrame[0];
		if (long(frame) > long(top))
			break;		
		ip = lastFrame[1];
		int relative = int(long(ip) - lowCode);
		string locationLabel = image.formattedLocation(long(ip) - 1, relative);
		if (skipFrames <= 0)
			output.printf("%s\n", locationLabel);
		else
			skipFrames--;
	}
	return output;
}
/**
 * A Virtual Hardware Stack.
 *
 * This provides a common interface for code that wants to do stack traces and inspection of local
 * variables.
 *
 * This is a base class. Specific implementations will implement the details of fetching data from the
 * stack.
 * {@link parasol:exception.ExceptionContext} provides an implementation for a snapshot of the stack where a Parasol Exception was
 * thrown.
 * {@link parasol:debug.DebugStack} provides an implementation suitable for a debugger.
 *
 * 
 */
public class VirtualStack {
	protected long _stackBase;                                  // The base address (smallest accessible address)
	protected int _stackSize;                                   // The length of the virtual stack

	public VirtualStack(long base, int size) {
		_stackBase = base;
		_stackSize = size;
	}

	public VirtualStack() {
	}

	public boolean valid(address stackAddress) {
		return valid(long(stackAddress));
	}

	public long base() {
		return _stackBase;
	}

	public int size() {
		return _stackSize;
	}

	public boolean valid(long stackAddress) {
		return _stackBase <= stackAddress &&
				stackAddress < _stackBase + _stackSize;
	}

	public long slot(address stackAddress) {
		return slot(long(stackAddress));
	}

	public abstract long slot(long stackAddress);

	public abstract boolean isCode(long addr);

	public abstract boolean isParasolCode(long addr);

	public abstract string symbolAt(long addr, long adjustment);

	public abstract int pid();

	public abstract int tid();

	enum SlotType {
		VOIDED,
		CODE,
		PARASOL,
		STACK_REF,
		MAIN,
		THREAD
	}

	class InterestingSlot {
		SlotType type;
		boolean confirmed;
		long offset;			// offset from rsp where the interesting slot was found
		long value;				// value at that slot
		string symbol;			// any symbolic data about the slot

		InterestingSlot(SlotType type, long offset, long value, string symbol) {
			this.type = type;
			this.offset = offset;
			this.value = value;
			this.symbol = symbol;
		}

		InterestingSlot() {}
	}

	InterestingSlot[] _returnAddresses;
	/**
	 * Analyze the stack to construct a set of stack frames, which can be subsequently read out.
	 * 
	 * Assume that the stack is at least word (8-byte) aligned. At any call to a function, the stack should be
	 * paragraph (16-byte) aligned on Linux, because Linux code assumes it can use vector-processor instructions
	 * that require it.
	 *
	 * This means that any function return address should be found in a word that has a final hex digit of 8.
	 * In addition, that means that any saved Parasol frame pointer value will have an address with a final hex
	 * digit of 0.
	 *
	 * A stack of Parasol frames will consist of a pair of PARASOL and STACK_REF frames in adjacent slots.
	 * Such pairs will be separated by junk, but the next valid pair will have the STACK_REF point at the STACK_REF
	 * of this pair.
	 *
	 * Figuring out which addresses on the stack are real return addresses and which are phantom's is hard, either random
	 * function pointers or former return addresses tht have survived and been re-incorporated into a new stack frame.
	 * If every stack frame in the stack is a Parasol function, the stack is relatively simple. Every return address
	 * appear immediately after a saved frame pointer.
	 *
	 * The saved frame pointer values form a chain where one value contains the address of the next saved frame pointer.
	 * And just above each such chain element lies the unambiguous return address.
	 * Every Parasol code address not found just after an element of this chain is not a return address.
	 * 
	 * Complexities enter when a C code return address is encountered.
	 * The C compiler treats rbp as a general purpose register and offers fewer clues to the structure present on the
	 * stack.
	 *
	 * If assembly code is included in the stack, almost any arrangement of memory values could be encountered.
	 * While some of the ways to obscure the meaning of a stack trace do happen, it is alright to get a wrong answer
	 * in the face of a thoroughly confusing arrangement of values, this does not come up often in practice.
	 * The effort used in this code is to reason from the available evidence and to include dubious values where
	 * evidence is not conclusive, with appropriate labeling.
	 *
	 * The first reasoning works as follows: code is written either in Parasol or some unknown compiled language
	 * with unknown conventions (other than the OS ABI, so function calls from Parasol do conform to the rules for
	 * passing parameters in registers and to preserve register values.
	 * Calls from one non-Parasol function to another could conform to any convention.
	 *
	 * The initial scan of the stack identifies Parasol code addresses, non-Parasol code addresses and stack slots
	 * that contain stack addresses higher than the slot itself (these are potential saved stack frame values), along
	 * with two special symbols: the Parasol 'runNative' C++ method that calls the image entry point and the linux
	 * 'start_thread' function that calls (on a new thread) the function given as the starting point for the thread.
	 * The first special symbol is labeled MAIN because it is normally the place where the main thread of a process
	 * will start executing Parasol code.
	 * The second special symbol is labeled THREAD because it is normally the place where spawned Thread's start
	 * executing Parasol code.
	 *
	 * If the main thread does not have a MAIN symbol return address on its stack, this might be a C program with
	 * no Parasol.
	 * Currently, Parasol does not support operating as a library that gets called from a C main function,
	 * so a process main thread without a MAIN symbol wil lprobably not contain any Parasol code at all.
	 * 
	 * In the case of the MAIN symbol, the very next slot in the candidates list should be a Parasol code address.
	 * The address will be somewhere in the static initializers or the destructors,
	 * depending on where the program is in it's execution.
	 * Even if the static initializer called a C function directly, the return address would still be in Parasol
	 * code somewhere.
	 *
	 * For a THREAD symbol, a non-Parasol library could spawn it's own threaads and they could never call into Parasol.
	 * Therefore, the next candidate entry could be a non-Parasol return address or even a stack reference.
	 * For Parasol programs that do not call on large 3rd-party libraries, most of the threads you will see will be
	 * Parasol and the next canddiate entry will be in Parasol code.
	 *
	 * The Parasol return address indicates that you were in a Parasol function and are about to enter a new one.
	 * If the candidate after it is a stack ref slot pointing to the address just below the MAIN or THREAD entry,
	 * The function that just got called pushed the frame pointer there.
	 * It could be a Parasol function.
	 * If the next candidate is not such a stack ref, you just entered a C function in some shared object.
	 *
	 * Values on the stack can appear to be return addresses if they happen to fall into the address range of an executable
	 * memory segment. One possibility is that what is stored in the stack is a function pointer. These can be distinguished
	 * by examining the memory contents just before the address on the stack. If the bytes just before the address are
	 * not part of a return instruction, then the address cannot be a return address. If the bytes happen to be a return
	 * address, you can be somewhat confidant that the value is a return address.
	 *
	 * A return address can be found in any stack frame because not all memory slots are erased after returning from a
	 * function. 
	 * While interrupts might stomp on a particular return address, none may occur before another call extends the stack again.
	 * In that case, if Parasol is called it will initialize memory, mostly to zero, very quickly - but not instantly.
	 * If non-Parasol code is called there is no guarantee that a particular memory slot will be over-written at all.
	 *
	 * To authoritatively determine whether a given set of stack contents are a particular set of stack frames, you would need 
	 * debugging information about the function that identifies the layout of the stack frame at each instruction.
	 * If, as in Parasol, a specific frame pointer is maintained, you shouldn't need to know exactly how deep the stack is 
	 * at each instruction, because in a stack crawl you will know the frame you came from and where RSP was at that frame.
	 *
	 * After the raw candidates list has been built since we don't have any information about the shape of the stack frame, 
	 * there are only limited conditions that we can detect and correct.
	 *
	 * The cases (assuming a well-formed MAIN or THREAD address at the stack bottom):
	 *	<ul>
	 *		<li> Saw Parasol return address.
	 *			<ul>
	 *				<li> Pushed stack frame present.
	 *					The language of the new function is unknown, but will be determined by further analysis.
	 *					<ul>
	 *						<li> If the language of the next return address candidate is Parasol, the language is Parasol.
	 *							Action:
	 *							Mark the caller as confirmed Parasol.
	 *						<li> If the language of the next return address candidate is non-Parasol, the language is C.
	 *							Action:
	 *							Mark the caller as confirmed non-Parasol.
	 *							In this case, any Parasol return addresses and stack refs can be discarded until you reach a
	 *							non-Parasol code address.
	 *							If none are found, the current RIP value identifies the function you are currently in.
	 *					</ul>
	 *
	 *				<li> Pushed stack frame absent.
	 *					The language is C or possibly Parasol.
	 *					Action:
	 *					In this case, any Parasol return addresses and stack refs can be discarded until you reach a
	 *					non-Parasol code address.
	 *					If none are found, the current RIP value identifies the function you are currently in.
	 *			</ul>
	 *
	 *		<li> Saw non-Parasol return address.
	 *			<ul>
	 *				<li> Pushed stack frame present.
	 *					The language of the new function is unknown, but will be determined by further analysis.
	 *					<ul>
	 *						<li> If the language of the next return address candidate is Parasol, the language is Parasol.
	 *							Action:
	 *							Mark the caller as confirmed Parasol.
	 *						<li> If the language of the next return address candidate is non-Parasol, the language is C.
	 *							Action:
	 *							Mark the caller as confirmed non-Parasol.
	 *							In this case, any Parasol return addresses and stack refs can be discarded until you reach a
	 *							non-Parasol code address.
	 *							If none are found, the current RIP value identifies the function you are currently in.
	 *					</ul>
	 *
	 *				<li> Pushed stack frame absent.
	 *					The language is C.
	 *					Action:
	 *					In this case, any Parasol return addresses and stack refs can be discarded until you reach a
	 *					non-Parasol code address.
	 *					If none are found, the current RIP value identifies the function you are currently in.
	 *			</ul>
	 *				
	 */
	public void analyzeStack(long rbp, long rip) {
		InterestingSlot[] candidates;

		for (long offset = _stackSize; offset > 0; ) {
			offset -= address.bytes;
			stackSlot := _stackBase + offset;
			value := slot(stackSlot);
			s := symbolAt(value - 1, 1);
			x := candidates.length();
			if (isParasolCode(value) && s != null)
				candidates.append(InterestingSlot(SlotType.PARASOL, offset, value, s));
			else if (isCode(value) && s != null) {
				if (s.startsWith("libparasol.so.1 _ZN7parasol16ExecutionContext9runNativeEPFiPvE")) {
					candidates.clear();
					candidates.append(InterestingSlot(SlotType.MAIN, offset, value, null));
				} else if (s.startsWith("libpthread-2.23.so start_thread")) {
					candidates.clear();
					candidates.append(InterestingSlot(SlotType.THREAD, offset, value, null));
				} else if ((stackSlot & 0xf) == 8)
					candidates.append(InterestingSlot(SlotType.CODE, offset, value, s));
			} else if ((value & 0xf) == 0 && value >= stackSlot + 2 * address.bytes && value < _stackBase + _stackSize) {
				if (candidates.length() == 1 && candidates[0].type == SlotType.MAIN)
					continue;
				candidates.append(InterestingSlot(SlotType.STACK_REF, offset, value, null));
			}
		}
		// If the stack is empty - we having nothing to show.		
		if (candidates.length() == 0)
			return;
/*
		printf("before pruning:\n");
		for (int i = candidates.length() - 1; i >= 0; i--) {
			c := candidates[i];
			printf("    [%2d] %-9s %16x %s (%x)\n", i, string(c.type), c.offset + _stackBase, c.symbol, c.value);
		}
*/
		switch (candidates[0].type) {
		case THREAD:
//			printf("This is a Parasol-launched thread\n");
			if (candidates.length() > 1 && candidates[1].type != SlotType.PARASOL)
				printf("WARN: Unexpected non-Parasol slot candidate %s %s\n", string(candidates[1].type), candidates[1].symbol);
			break;

		case MAIN:
//			printf("This is a Parasol-compiled main thread\n");
			// Any stack refs COULD be present in the stack initializers' stack slots.
			while (candidates.length() > 1 && candidates[1].type == SlotType.STACK_REF)
				candidates.remove(1);
			if (candidates.length() > 1 && candidates[1].type != SlotType.PARASOL && candidates[1].type != SlotType.CODE)
				printf("WARN: Unexpected non-Parasol slot candidate %s %s\n", string(candidates[1].type), candidates[1].symbol);
			break;

		default:
			printf("WARN: Unexpected starting point for an application %s %s\n", string(candidates[1].type), candidates[1].symbol);
		}
		boolean frameChainDetected;
		long previousFrame;
		for (i in candidates) {
			c := &candidates[i];
			switch (c.type) {
			case MAIN:				// The first frame in a compiled-Parasol main thread is the static initializers.
									// this can call any number of other Parasol or non-Parasol functions, but will often
									// appear just below the main function of the application.
			case THREAD:			// The first frame on a Parasol thread is a Parsol function in thread.p
									// that calls 'nested', which in turn calls the user's starting function.
				for (;;) {
					if (candidates.length() < i + 3)
						break;
					if (c[1].type != SlotType.PARASOL ||
						c[2].type != SlotType.STACK_REF ||
						c[1].offset != c[2].offset + address.bytes ||
						c[2].value + address.bytes != c.offset + _stackBase) {
						printf("WARN: Unexpected stack top arrangement, removing possible phantom return addresses @%x", 
									c[1].offset + _stackBase);
						if (c[1].type == SlotType.PARASOL ||
							c[1].type == SlotType.STACK_REF) {
//							printf("removing %d\n", i + 1);
							candidates.remove(i + 1);
							continue;
						}
					}
					frameChainDetected = true;
					previousFrame = _stackBase + c.offset - address.bytes;
					break;
				}
				break;

			case PARASOL:
				if (frameChainDetected) {
					if (candidates.length() < i + 2)
						break;
					c.confirmed = true;
					if (c[1].type == SlotType.STACK_REF &&
						c[1].offset == c.offset - address.bytes &&
						c[1].value == previousFrame)
						previousFrame = c[1].offset + _stackBase;
					else {
						// Next frame is C code, not Parasol - and that code didn't use an ENTER instruction.
//						printf("found malformed frame: offset %x : %x value %x : %x\n", c[1].offset, c.offset, c[1].value, previousFrame);
						frameChainDetected = false;
						for (int j = i + 1; j < candidates.length(); j++) {
							cc := &candidates[j];
							if (cc.type == SlotType.CODE)
								break;
							cc.type = SlotType.VOIDED;
//							printf("voiding %d\n", j);
						}
					}
				}
//				printf("    %-9s %16x %s (%x)\n", string(c.type), c.offset + _stackBase, c.symbol, c.value);
				break;

			case CODE:
//				printf("    %-9s %16x %s (%x)\n", string(c.type), c.offset + _stackBase, c.symbol, c.value);
				frameChainDetected = false;
			}
		}
//		printf("candidates %d\n", candidates.length());
		for (int i = candidates.length() - 1; i >= 0; i--) {
			c := candidates[i];
			switch (c.type) {
			case CODE:
			case PARASOL:
				printf("    %s (%x)\n", c.symbol, c.value);
			}
		}
	}

	/**
	 * This method crawls the stack by one frame.
	 *
	 * This will typically start with the current value of rbp.
	 * If this is a Parasol function, or many C functions, the rbp will be the function's frame pointer.
	 * 
	 * Each successive call should pass the previous returned frame value and so on until a null frame value is returned.
	 *
	 * @return The frame pointer value of the caller.
	 * @return The return address in the caller.
	 */
	public long, long nextFrame(long lastFrame, long lastIp) {
		long stackTop = _stackBase + _stackSize;
		long searchEnd = stackTop - 2 * address.bytes;
		long frame;
		long ip;
		boolean ipValid;

		if (lastFrame < _stackBase || lastFrame >= searchEnd)
			lastFrame = _stackBase - 2 * address.bytes;
		else {
			frame = slot(lastFrame);
			ip = slot(lastFrame + address.bytes);
			ipValid = true;
			if (frame >= lastFrame + 2 * address.bytes && frame < searchEnd)
				return frame, ip;
		}


		// For whatever reason, the frame we are trying to use as the next place to start looking
		// for a return address is no good, so guess by checking all possible values. As soon as we
		// see a stack slot containing a possible next saved frame pointer, we try to resync and see if we have
		// a resumed stack frame chain.
		for (frame = lastFrame + 2 * address.bytes; ; frame += address.bytes) {
			if (frame >= searchEnd) {
				frame = 0;
				break;
			}
			nextFrame := slot(frame);
			if (nextFrame >= frame + 2 * address.bytes && nextFrame < searchEnd) {
				if (!ipValid) {						// This is the case when you are starting the stack trace,
													// So, rip for the top-of-stack is known from the thread registers.
													// But that RBP is not a valid stack address for this thread.
													// So, the slot we found is the first potential saved-rbp and our
													// hope is that the ip is next. Actually, this code should search
													// starting here - looking for a code address somewhere in the process.
					ip = slot(frame + address.bytes);
					frame = nextFrame;
				}
				break;
			}
		}

		return frame, ip;
	} 

}



