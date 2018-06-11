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
	 * RESERVED - DO NOT USE
	 */
	NOT_USED_1,
	/**
	 * RESERVED - DO NOT USE
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
	 * This is not an actual target, but one greater than the maximum valid target value.
	 */
	MAX_TARGET
}

@Linux("libparasol.so.1", "eval")
@Windows("parasol.dll", "eval")
public abstract int eval(ref<X86_64SectionHeader> header, address image, long runtimeFlags, pointer<pointer<byte>> args, int argsCount);

@Linux("libparasol.so.1", "supportedTarget")
@Windows("parasol.dll", "supportedTarget")
public abstract int supportedTarget(int index);

@Linux("libparasol.so.1", "lowCodeAddress")
@Windows("parasol.dll", "lowCodeAddress")
public abstract pointer<byte> lowCodeAddress();
@Linux("libparasol.so.1", "highCodeAddress")
@Windows("parasol.dll", "highCodeAddress")
public abstract pointer<byte> highCodeAddress();
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

@Linux("libparasol.so.1", "getRuntimeFlags")
@Windows("parasol.dll", "getRuntimeFlags")
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

@Linux("libparasol.so.1", "setSourceLocations")
@Windows("parasol.dll", "setSourceLocations")
abstract void setSourceLocations(address location, int count);
@Linux("libparasol.so.1", "sourceLocations")
@Windows("parasol.dll", "sourceLocations")
abstract pointer<SourceLocation> sourceLocations();
@Linux("libparasol.so.1", "sourceLocationsCount")
@Windows("parasol.dll", "sourceLocationsCount")
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

