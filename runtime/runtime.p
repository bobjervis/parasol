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
import parasol:x86_64.X86_64SectionHeader;
import parasol:memory;

/**
 * The Parasol Runtime version string.
 *
 *{@code &lt;Major Release&gt;.&lt;Minor Release&gt;.&lt;Fix Release&gt;}
 *
 * Major Release: Incremented when a breaking change is released
 * Minor Feature Release: Incremented when significant new features
 * are released.
 * Fix Release: Incremented when bug fixes are released.
 *
 * Note: Major Release == 0 means this is 'unreleased' and any public API can change at any moment.
 */
public string RUNTIME_VERSION = "0.4.1";

/**
 * This is a special variable used to control compile-time conditional compilation.
 *
 * For now, this is hacked in to the compiler optimization logic to coomunicate precisely which compile
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
	NOT_USED_1,
	/**
	 * @ignore RESERVED - DO NOT USE
	 */
	NOT_USED_2,
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
	 * debugger
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
public abstract int eval(ref<X86_64SectionHeader> header, address image, pointer<pointer<byte>> args, int argsCount);
/** @ignore */
@Linux("libparasol.so.1", "supportedTarget")
@Windows("parasol.dll", "supportedTarget")
public abstract int supportedTarget(int index);
/** @ignore */
@Linux("libparasol.so.1", "lowCodeAddress")
@Windows("parasol.dll", "lowCodeAddress")
public abstract pointer<byte> lowCodeAddress();
/** @ignore */
@Linux("libparasol.so.1", "highCodeAddress")
@Windows("parasol.dll", "highCodeAddress")
public abstract pointer<byte> highCodeAddress();
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
 * @param length The length supplied with the original call to {@link allocateRegion).
 */
public void freeRegion(address region, long length) {
	if (compileTarget == Target.X86_64_WIN) {
		windows.VirtualFree(region, length, windows.MEM_RELEASE);
	} else if (compileTarget == Target.X86_64_LNX) {
		C.free(region);
	}
}
/**
 * SourceMap - in a pxi x86-64 section, source locations appear at the end of the section,
 * After relocations
 * 
 * SourceMaps come into existence two ways:
 * <ul>
 *    <li> Through the compiler running and building out the data structures as a side-effect
 *         of code generation.
 *    <li> From being loaded out of a PXI file image.
 * </ul>
 *
 * 
 */
public class SourceMap {
	public int locationCount;
	public pointer<int> codeAddress;
	public pointer<int> fileIndex;
	public pointer<int> fileOffset;
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

	public SourceFile(string filename) {
		_filename = filename;
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
public ref<SourceLocation> getSourceLocation(address ip, boolean isReturnAddress) {
	pointer<byte> lowCode = pointer<byte>(lowCodeAddress());
	if (pointer<byte>(ip) < lowCode ||
		pointer<byte>(highCodeAddress()) <= pointer<byte>(ip))
		return null;
	int offset = int(ip) - int(lowCode);
	
	if (!isReturnAddress)
		offset--;
	pointer<SourceLocation> psl = sourceLocations();
	int interval = sourceLocationsCount();
	for (;;) {
		if (interval <= 0)
			return null;
		int middle = interval / 2;
		if (psl[middle].offset > offset)
			interval = middle;
		else if (middle == interval - 1 || psl[middle + 1].offset > offset) {
			return psl + middle;
		} else {
			psl = &psl[middle + 1];
			interval = interval - middle - 1;
		}
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
public void setSourceLocations(pointer<SourceLocation> location, int count) {
	setRuntimeParameter(SOURCE_LOCATIONS, location);
	setRuntimeParameter(SOURCE_LOCATIONS_COUNT, address(count));
}
/** @ignore */
public pointer<SourceLocation> sourceLocations() {
	return pointer<SourceLocation>(getRuntimeParameter(SOURCE_LOCATIONS));
}
/** @ignore */
public int sourceLocationsCount() {
	return int(getRuntimeParameter(SOURCE_LOCATIONS_COUNT));
}

public void setSectionType() {
	if (compileTarget == Target.X86_64_WIN) {
		setRuntimeParameter(SECTION_TYPE, address(Target.X86_64_WIN));
	} else if (compileTarget == Target.X86_64_LNX) {
		setRuntimeParameter(SECTION_TYPE, address(Target.X86_64_LNX_SRC));
	}
}
/** @ignore */
@Constant
int PARASOL_THREAD = 0;
/** @ignore */
@Constant
int SOURCE_LOCATIONS = 1;
/** @ignore */
@Constant
int SOURCE_LOCATIONS_COUNT = 2;
/** @ignore */
@Constant
int LEAKS_FLAG = 3;
/** @ignore */
@Constant
int SECTION_TYPE = 4;
/** @ignore */
@Linux("libparasol.so.1", "getRuntimeParameter")
@Windows("parasol.dll", "getRuntimeParameter")
public abstract address getRuntimeParameter(int i);
/** @ignore */
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
	string output;
	int lowCode = int(lowCodeAddress());
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
		int relative = int(ip) - lowCode;
		string locationLabel = exception.formattedLocation(ip, relative, false);
		output.printf("%s\n", locationLabel);
	}
	return output;
}



