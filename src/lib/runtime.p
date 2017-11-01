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
import parasol:pxi.SectionType;
import parasol:exception.ExceptionContext;
import parasol:x86_64.X86_64SectionHeader;

/*
 * Major Release: Incremented when a breaking change is released
 * Minor Feature Release: Incremented when significant new features
 * are released.
 * Fix Release: Incremented when big fixes are released.
 */
public string RUNTIME_VERSION = "0.1.0";

/*
 * This is a special variable used to control compile-time conditional compilation. For now, this is hacked in
 * to the compiler optimization logic to coomunicate precisely which compile target was selected to build this
 * runtime.
 */
@CompileTarget
public SectionType compileTarget = SectionType.X86_64_WIN;	// TODO: Remove this as there should be magic setting this value

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

public abstract long getRuntimeFlags();

public address allocateRegion(long length) {
	address v;
	if (compileTarget == SectionType.X86_64_WIN) {
		v = windows.VirtualAlloc(null, length, windows.MEM_COMMIT|windows.MEM_RESERVE, windows.PAGE_READWRITE);
	} else if (compileTarget == SectionType.X86_64_LNX) {
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
	if (compileTarget == SectionType.X86_64_WIN) {
		unsigned oldProtection;
		int result = windows.VirtualProtect(location, length, windows.PAGE_EXECUTE_READWRITE, &oldProtection);
//		printf("VirtualProtect(%p, %d, %x, %p) -> %d oldProtection %x\n", location, length, int(windows.PAGE_EXECUTE_READWRITE), null, result, int(oldProtection));
		return result != 0;
	} else if (compileTarget == SectionType.X86_64_LNX)
		return linux.mprotect(location, length, linux.PROT_EXEC|linux.PROT_READ|linux.PROT_WRITE) == 0;
	return false;
}
