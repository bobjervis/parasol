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
namespace parasol:runtime;

import native:linux;
import native:windows;
import parasol:compiler.FileStat;
import parasol:compiler.Location;
import parasol:exception.ExceptionContext;
import parasol:x86_64.X86_64SectionHeader;

/*
 * Major Release: Incremented when a breaking change is released
 * Minor Feature Release: Incremented when significant new features
 * are released.
 * Fix Release: Incremented when bug fixes are released.
 *
 * Note: Since Major Release == 0 means this is 'unreleased' and any public API can change at any moment.
 */
public string RUNTIME_VERSION = "0.1.0";

/*
 * This is a special variable used to control compile-time conditional compilation. For now, this is hacked in
 * to the compiler optimization logic to coomunicate precisely which compile target was selected to build this
 * runtime.
 */
@CompileTarget
public Target compileTarget = Target.X86_64_WIN;	// TODO: Remove this as there should be magic setting this value

@Header("ST_")
public enum Target {
	ERROR,						// 0x00 A section given this type has unknown data at the section offset
	SOURCE,						// 0x01 the region is in POSIX IEEE P1003.1 USTar archive format.
	NOT_USED_2,					// 0x02 Parasol byte codes
	X86_64_LNX,					// 0x03 Parasol 64-bit for Intel and AMD processors, Linux calling conventions.
	X86_64_WIN,					// 0x04 Parasol 64-bit for Intel and AMD processors, Windows calling conventions.
	FILLER
}

public abstract int injectObjects(pointer<address> objects, int objectCount);

// eval calls the ByteCodes interpreter.  startObject is the byteCode function that should be run.

public abstract int eval(int startObject, pointer<pointer<byte>> args, int argsCount, pointer<pointer<byte>> exceptionInfo);

public abstract int evalNative(ref<X86_64SectionHeader> header, address image, pointer<pointer<byte>> args, int argsCount);

public abstract int supportedTarget(int index);

public abstract int runningTarget();

public abstract pointer<byte> builtInFunctionName(int index);
public abstract pointer<byte> builtInFunctionDomain(int index);
public abstract address builtInFunctionAddress(int index);
public abstract int builtInFunctionArguments(int index);
public abstract int builtInFunctionReturns(int index);

public abstract pointer<byte> lowCodeAddress();
public abstract pointer<byte> highCodeAddress();
public abstract address stackTop();

/**
 * This method returns the byte address of the next instruction after the call to the currently running function.
 * A value of null indicates that the returnAddress of this function is unavailable.
 */
public /*abstract*/ address returnAddress() {
	return null;
}
/**
 * This method returns the frame pointer for the current function. A value of null indicates that a frame pointer
 * for this method is unavailable. 
 */
public /*abstract*/ address framePointer() {
	return null;
}

public abstract long getRuntimeFlags();

public address allocateRegion(long length) {
	address v;
	if (compileTarget == Target.X86_64_WIN) {
		v = windows.VirtualAlloc(null, length, windows.MEM_COMMIT|windows.MEM_RESERVE, windows.PAGE_READWRITE);
	} else if (compileTarget == Target.X86_64_LNX) {
		int pagesize = linux.sysconf(int(linux.SysConf._SC_PAGESIZE));
		if (pagesize == -1) {
			printf("sysconf failed\n");
			assert(false);
		}
		return linux.aligned_alloc(pagesize, length);
	} else
		return null;
	return v;
}

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

public class SourceLocation {
	public ref<FileStat>	file;			// Source file containing this location
	public Location			location;		// Source byte offset
	public int				offset;			// Code location
}

abstract void setSourceLocations(address location, int count);
abstract pointer<SourceLocation> sourceLocations();
abstract int sourceLocationsCount();

public ref<SourceLocation> getSourceLocation(address ip, boolean locationIsExact) {
	int lowCode = int(lowCodeAddress());
	int offset = int(ip) - lowCode;
	if (offset < 0)
		return null;
	if (!locationIsExact)
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

@Linux("libparasol.so.1", "parasol_gFormat")
public abstract int parasol_gFormat(pointer<byte> buffer, int length, double value, int precision);

