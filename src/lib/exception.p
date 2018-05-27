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
namespace parasol:exception;

import parasol:compiler.BuiltInType;
import parasol:compiler.FileStat;
import parasol:compiler.Type;
import parasol:x86_64.ExceptionEntry;
import parasol:x86_64.SourceLocation;
import parasol:memory;
import parasol:process;
import parasol:runtime;
import parasol:thread;
import native:windows;
import native:linux;
import native:C;

int EXCEPTION_ACCESS_VIOLATION	= int(0xc0000005);
int EXCEPTION_IN_PAGE_ERROR		= int(0xc0000006);

public class Exception {
	protected ref<ExceptionContext> _exceptionContext;
	string _message;
	
	public Exception() {
		
	}
	
	public Exception(string message) {
		_message = message;
	}
	
	Exception(ref<ExceptionContext> exceptionContext) {
		_exceptionContext = exceptionContext;
	}
	
	ref<Exception> clone() {
		ref<Exception> n = new Exception(_message);
		n._exceptionContext = _exceptionContext;
		return n;
	}
	
	public string message() {
		return _message;
	}
	
	public void printStackTrace() {
		string s = textStackTrace();
		print(s);
	}
	
	public string textStackTrace() {
		if (_exceptionContext == null)
			return "Exception was never thrown, no stack trace.\n";
		string output;
		boolean locationIsExact = true;

		if (_exceptionContext.exceptionType == 0)
			locationIsExact = false;
//		printf("    failure address %p\n", _exceptionContext.exceptionAddress);
		address stackHigh = pointer<byte>(_exceptionContext.stackPointer) + _exceptionContext.stackSize;
		address fp = _exceptionContext.inferredFramePointer;
		address ip = _exceptionContext.exceptionAddress;
		string tag = "->";
		int lowCode = int(runtime.lowCodeAddress());
		int staticMemoryLength = int(runtime.highCodeAddress()) - lowCode;
		int ignoreFrames = ignoreTopFrames();
		while (_exceptionContext.valid(fp)) {
//			printf("fp = %p ip = %p relative = %x\n", fp, ip, int(ip) - lowCode);
			pointer<address> stack = pointer<address>(fp);
			long nextFp = _exceptionContext.slot(fp);
			int relative = int(ip) - lowCode;
			if (ignoreFrames > 0)
				ignoreFrames--;
			else {
				string locationLabel;
				if (relative >= staticMemoryLength || relative < 0)
					locationLabel = formattedExternalLocation(ip);
				else
					locationLabel = formattedLocation(ip, relative, locationIsExact);
				output.printf(" %2s %s\n", tag, locationLabel);
				tag = "";
			}
//			if (nextFp != 0 && nextFp < long(fp)) {
//				printf("    *** Stored frame pointer out of sequence: %p\n", nextFp);
//				break;
//			}
			fp = address(nextFp);
			ip = address(_exceptionContext.slot(stack + 1));
			locationIsExact = false;
		}
		return output;
	}
	
	int ignoreTopFrames() {
		return 0;
	}
	
	void throwNow(address framePointer, address stackPointer) {
		
		// The default treatment is that the return address just under the stackPointer is the starting point for
		// 'throw' resolution. That will cover the cases where the exception context doesn't exist (this is a plain
		// 'throw' statement), or this is a re-thrown exception (in which case the lastCrawledFramePointer will not be
		// null). If there is an _exceptionContext set but no lastCrawledFramePointer, we are processing a hardware
		// exception for the first time.
		
		int(address, address) comparator = comparatorReturnAddress;
		pointer<byte> ip = pointer<pointer<byte>>(stackPointer)[-1];
		if (_exceptionContext == null) {
			// An inital throw statement of an unthrown exception
			_exceptionContext = createExceptionContext(stackPointer);
			_exceptionContext.framePointer = framePointer;
			_exceptionContext.exceptionAddress = pointer<address>(stackPointer)[-1];
		} else if (_exceptionContext.lastCrawledFramePointer == null) {
			// first time handling of a hardware exception
			ip = pointer<byte>(_exceptionContext.exceptionAddress);
			comparator = comparatorCurrentIp;
		} // else a re-thrown exception
		address stackTop = address(long(_exceptionContext.stackBase) + _exceptionContext.stackSize);
		pointer<address> searchEnd = pointer<address>(stackTop) + -2;
		pointer<address> frame = pointer<address>(_exceptionContext.framePointer);
		pointer<address> stack = pointer<address>(_exceptionContext.stackPointer);
		ref<ExceptionEntry> ee;
		if (frame < stack || frame >= searchEnd) {
			for (pointer<address> rbpCandidate = stack; rbpCandidate < searchEnd; rbpCandidate++) {
				(ee, frame) = crawlStack(ip, rbpCandidate, comparator);
				if (ee != null)
					break;
			}
		} else
			(ee, frame) = crawlStack(ip, frame, comparator);
		if (ee != null) {
			_exceptionContext.lastCrawledFramePointer = frame;
			callCatchHandler(this, frame, ee.handler);
			process.exit(1);
		}
		printf("\nFATAL: Could not find a stack handler for this address.\n");
		_exceptionContext.print();
		print(textStackTrace());
//		process.exit(1);
	}
	
	private ref<ExceptionEntry>, pointer<address> crawlStack(pointer<byte> ip, pointer<address> frame, int comparator(address ip, address elem)) {
		_exceptionContext.inferredFramePointer = frame;
		pointer<address> oldRbp;
		pointer<ExceptionEntry> ee = pointer<ExceptionEntry>(exceptionsAddress());
		int count = exceptionsCount();
		if (count == 0) {
			printf("No exceptions table for this image.\n");
			process.exit(1);
		}
//		printf("crawlStack(%p, %p, ...)\n", ip, frame);
		pointer<byte> lowCode = runtime.lowCodeAddress();
		pointer<byte> highCode = runtime.highCodeAddress();
//		int(address ip, address elem) comparator = comparatorCurrentIp;
		address stackTop = address(long(_exceptionContext.stackBase) + _exceptionContext.stackSize);
		pointer<address> plausibleEnd = pointer<address>(stackTop) + -2;
		do {
			if (ip >= lowCode && ip < highCode) {
				int location = int(ip - lowCode);
//				printf("Checking location %x", location);
				address result = bsearch(&location, ee, count, ExceptionEntry.bytes, comparator);
//				printf(" -> found %p", result);
				if (result != null) {
					ref<ExceptionEntry> ee = ref<ExceptionEntry>(result);

//					printf("(handler %x)\n", ee.handler);
					// If we have a handler, call it.
					if (ee.handler != 0)
						return ee, frame;
				}
//				printf("\n");
			}
			oldRbp = frame;
			ip = pointer<byte>(frame[1]);
			frame = pointer<address>(*frame);
			comparator = comparatorReturnAddress;
		} while (frame > oldRbp && frame < plausibleEnd);
		return null, null;
	}

	void inferFramePointer() {
		pointer<byte> ip = pointer<byte>(_exceptionContext.exceptionAddress);
		ref<ExceptionEntry> ee;
		pointer<address> frame = pointer<address>(_exceptionContext.framePointer);
		if (_exceptionContext.valid(frame)) {
			(ee, frame) = crawlStack(ip, frame, comparatorCurrentIp);
			if (ee != null) {
				_exceptionContext.inferredFramePointer = frame;
				return;
			}
		}
		address stackTop = address(long(_exceptionContext.stackBase) + _exceptionContext.stackSize);
		pointer<address> searchEnd = pointer<address>(stackTop) + -2;
		pointer<address> stack = pointer<address>(_exceptionContext.stackPointer);
		for (pointer<address> rbpCandidate = stack; rbpCandidate < searchEnd; rbpCandidate++) {
			(ee, frame) = crawlStack(ip, rbpCandidate, comparatorCurrentIp);
			if (ee != null) {
				_exceptionContext.inferredFramePointer = rbpCandidate;
				return;
			}
		}
	}
	/*
	 * findStack confirms whether there are any valid stack frames (ones with Parasol code from
	 * this image in them). Second, if it is valid, it counts how many frames there are so calling code
	 * can allocate storage for the stack walk.
	 * 
	 * 
	 * RETURNS:	-1 if this could not be confirmed to be a valid Parasol stack, or >= 1 for
	 * 			valid stacks (the number is the number of stack frames found).
	 */
	private int countStackFrames(pointer<address> frame) {
		pointer<address> oldRbp;
		pointer<ExceptionEntry> ee = pointer<ExceptionEntry>(exceptionsAddress());
		int count = exceptionsCount();
		if (count == 0) {
			printf("No exceptions table for this image.\n");
			process.exit(1);
		}
		pointer<byte> lowCode = runtime.lowCodeAddress();
		pointer<byte> highCode = runtime.highCodeAddress();
		int(address, address) comparator = comparatorCurrentIp;
		address stackTop = address(long(_exceptionContext.stackBase) + _exceptionContext.stackSize);
		pointer<address> plausibleEnd = pointer<address>(stackTop) + -2;
		int frames = 0;
		boolean confirmed;
		do {
			oldRbp = frame;
			pointer<byte> ip = pointer<byte>(frame[1]);
			if (ip >= lowCode && ip < highCode)
				confirmed = true;
			frame = pointer<address>(*frame);
			comparator = comparatorReturnAddress;
			frames++;
		} while (frame > oldRbp && frame < plausibleEnd);
		if (confirmed)
			return frames;
		else
			return -1;
	}
	
	ref<ExceptionContext> exceptionContext() {
		return _exceptionContext;
	}
}

private address bsearch(address key, address tableAddress, int tableSize, int rowSize, int comparator(address a, address b)) {
	pointer<byte> table = pointer<byte>(tableAddress);
	while (tableSize > 0) {
		int midIndex = tableSize / 2;
		pointer<byte> midPoint = table + midIndex * rowSize;
		int comp = comparator(key, midPoint);
		if (comp < 0)
			tableSize = midIndex;
		else if (comp > 0) {
			table = midPoint + rowSize;
			tableSize -= midIndex + 1; 
		} else
			return midPoint;
	}
	return null;
}

private int comparatorCurrentIp(address ip, address elem) {
	int location = *ref<int>(ip);
	pointer<ExceptionEntry> ee = pointer<ExceptionEntry>(elem);

	if (location < ee[0].location)
		return -1;
	else if (location < ee[1].location)
		return 0;
	else
		return 1;
}

private int comparatorReturnAddress(address ip, address elem) {
	int location = *ref<int>(ip);
	pointer<ExceptionEntry> ee = pointer<ExceptionEntry>(elem);

	if (location <= ee[0].location)
		return -1;
	else if (location <= ee[1].location)
		return 0;
	else
		return 1;
}

public class BoundsException extends Exception {
	public BoundsException() {
	}
	
	public BoundsException(string message) {
		super(message);
	}

	ref<BoundsException> clone() {
		ref<BoundsException> n = new BoundsException(_message);
		n._exceptionContext = _exceptionContext;
		return n;
	}	
}

public class IllegalArgumentException extends Exception {
	public IllegalArgumentException() {
	}

	public IllegalArgumentException(string message) {
		super(message);
	}

	ref<IllegalArgumentException> clone() {
		ref<IllegalArgumentException> n = new IllegalArgumentException(_message);
		n._exceptionContext = _exceptionContext;
		return n;
	}
}


public class CRuntimeException extends RuntimeException {
	public CRuntimeException() {
		
	}

	CRuntimeException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}
	
	ref<CRuntimeException> clone() {
		ref<CRuntimeException> n = new CRuntimeException();
		n._exceptionContext = _exceptionContext;
		return n;
	}	
}

public class RuntimeException extends Exception {
	RuntimeException() {
	}
	
	RuntimeException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}
	
	public string message() {
		if (_exceptionContext == null)
			return "RuntimeException (not thrown)\n";
		string output;
		output.printf("RuntimeException: ");

		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			pointer<byte> message = formatMessage(unsigned(_exceptionContext.exceptionType));

			string text(message);
			output.printf("%x", _exceptionContext.exceptionType);
			if (message != null) {
				if (text.endsWith("\r\n"))
					text = text.substring(0, text.length() - 2);
				output.printf(" (%s)", text);
			}
			output.printf(" ip %p", _exceptionContext.exceptionAddress, runtime.lowCodeAddress());
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			output.printf("%x", _exceptionContext.exceptionType);
		return output;
	}
	
	ref<RuntimeException> clone() {
		ref<RuntimeException> n = new RuntimeException(_exceptionContext);
		return n;
	}	

}

public abstract pointer<byte> formatMessage(unsigned ntstatus);

public class DivideByZeroException extends RuntimeException {
	DivideByZeroException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}

	ref<DivideByZeroException> clone() {
		ref<DivideByZeroException> n = new DivideByZeroException(_exceptionContext);
		return n;
	}	

}

public class IllegalInstructionException extends RuntimeException {
	IllegalInstructionException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}

	ref<IllegalInstructionException> clone() {
		ref<IllegalInstructionException> n = new IllegalInstructionException(_exceptionContext);
		return n;
	}	

}

public class AssertionFailedException extends RuntimeException {
	AssertionFailedException() {
	}

	ref<AssertionFailedException> clone() {
		ref<AssertionFailedException> n = new AssertionFailedException();
		n._exceptionContext = _exceptionContext;
		return n;
	}	

	public string message() {
		if (_exceptionContext == null)
			return "AssertionFailedException (not thrown)\n";
		return "Assertion failed";
	}
	
	int ignoreTopFrames() {
		return 1;
	}
}

public class CorruptHeapException extends RuntimeException {
	CorruptHeapException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}
	
	ref<CorruptHeapException> clone() {
		ref<CorruptHeapException> a = new CorruptHeapException(_exceptionContext);
		return a;
	}
}

public class StackOverflowException extends RuntimeException {
	StackOverflowException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}
	
	ref<StackOverflowException> clone() {
		ref<StackOverflowException> a = new StackOverflowException(_exceptionContext);
		return a;
	}
}

public class AccessException extends RuntimeException {
	AccessException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}
	
	ref<AccessException> clone() {
		ref<AccessException> a = new AccessException(_exceptionContext);
		return a;
	}

	public string message() {
		if (_exceptionContext == null)
			return "AccessException (not thrown)\n";
		string output;
		output.printf("AccessException: flags %d referencing %p", _exceptionContext.exceptionFlags, _exceptionContext.memoryAddress);
		return output;
	}
	}

public class NullPointerException extends AccessException {
	NullPointerException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}
	
	ref<NullPointerException> clone() {
		ref<NullPointerException> n = new NullPointerException(_exceptionContext);
		return n;
	}
}

public class PermissionsException extends AccessException {
	PermissionsException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}
	
	ref<PermissionsException> clone() {
		ref<PermissionsException> n = new PermissionsException(_exceptionContext);
		return n;
	}
}
/**
 * Throw an exception. It performs the exact same semantics as the throw statement.
 * The throw statement will generate this call (and provide the magic frame and stack pointer).
 *  
 * Note: This function does not return.
 * 
 * @param e The non-null Exception to be thrown.
 * @param frame The frame pointer when the exception was thrown.
 * @param stackPointer The stack pointer when the exception was thrown.
 */
void throwException(ref<Exception> e, address frame, address stackPointer) {
	e.clone().throwNow(frame, stackPointer);
	printf("Thrown!\n");
}
/**
 * Intercept an uncaught exception. This code is called from the catch handler that encloses the static initializers.
 * 
 * It is called under the scope of the ExecutionContext of the code throwing the exception. Doing this inside the
 * enclosed ExecutionContext means that the source locations are correctly aligned for the stack trace.
 * 
 * Note that this handler also exposes the exception so that the caller to eval knows that the call failed because of an
 * uncaught exception.
 * 
 * @param e The uncaught exeption.  
 */
void uncaughtException(ref<Exception> e) {
	printf("\nUncaught exception!\n\n%s\n", e.message());
	e.printStackTrace();
	exposeException(e);
}

void hardwareExceptionHandler(ref<HardwareException> info) {
	ref<ExceptionContext> context = createExceptionContext(info.stackPointer);
	context.framePointer = info.framePointer;
	context.exceptionAddress = info.codePointer;
	context.memoryAddress = address(info.exceptionInfo0);
	context.exceptionFlags = info.exceptionInfo1;
	context.exceptionType = info.exceptionType;
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		if (info.exceptionType == 0xffffffffc0000374) {
			throw CorruptHeapException(context);
		} else if (info.exceptionType == 0xffffffffc00000fd) {
			throw StackOverflowException(context);
		} else if (info.exceptionType == 0xffffffffc0000005) {
			if (context.memoryAddress == null)
				throw NullPointerException(context);
			else
				throw AccessException(context);
		} else if (info.exceptionType == int(0xc0000094))
			throw DivideByZeroException(context);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		switch (info.exceptionType) {
		case 0xb80:						// SIGSEGV + SI_KERNEL
		case 0xb01:						// SIGSEGV + SEGV_MAPERR
			if (context.memoryAddress == null)
				throw NullPointerException(context);
			else
				throw AccessException(context);	
			
		case 0xb02:						// SIGSEGV + SEGV_ACCERR
			throw PermissionsException(context);	
			
		case 0x801:						// SIGTRAP + FPE_INTDIV
			throw DivideByZeroException(context);
			
		case 0x402:						// SIGILL + ILL_ILLOPN
			throw IllegalInstructionException(context);
			
		case 0x6fa:						// SIGABRT + tkill
			throw CRuntimeException(context);

		case 0x300:						// SIGQUIT - dump all threads
			dumpAllThreads(context);
			thread.exit(0);

		case 0x3fa:						// SIGQUIT sent from inside the house - just dump me.
			dumpMyThread(context);
			thread.exit(0);
		}
	}
	printf("exception %x at %p\n", info.exceptionType, info.codePointer);
	printf("Unexpected exception type\n");
	throw RuntimeException(context);
}
/*
 * dispatchException is called from the compiler when deciding which catch clause to execute when an exception is
 * thrown.
 * 
 * Note that the body of the exception is copied from the tmeporary location to the destination if there is a match.
 * 
 * PARAMETERS
 * 	e			The thrown exception. May be any type derived from Exception.
 * 	t			The type record of the Exception class that this handler matches.
 * 	destination	If the thrown exception's type matches the passed type, then the exception is copied.
 * 	size		The amount to copy.
 * 	
 * RETURNS	true if the exception should be handled, false if it should not
 */
private boolean dispatchException(ref<Exception> e, ref<Type> t, ref<Exception> destination, int size) {
	ref<Type> actual = **ref<ref<ref<Type>>>(e);
/*
	printf("dispatchException %p actual %p t %p equals %s isSubtype %s\n", e, actual, t, actual.equals(t) ? "true" : "false", actual.isSubtype(t) ? "true" : "false");
		printf("actual class %x t class %x\n", pxiOffset(**ref<ref<address>>(actual)), pxiOffset(**ref<ref<address>>(t)));
		printf("actual vtable %x t vtable %x\n", pxiOffset(*ref<address>(actual)), pxiOffset(*ref<address>(t)));
		printf("actual family %s t family %s\n", string(actual.family()), string(t.family()));
//	}
	if (t.class == BuiltInType) {
		printf("t._classType = %x\n", pxiOffset(ref<BuiltInType>(t).classType()));
		printf("t._classType vatble %x\n", pxiOffset(*ref<address>(ref<BuiltInType>(t).classType())));
	}
*/
	if (actual.equals(t) || actual.isSubtype(t)) {
		C.memcpy(destination, e, size);
		return true;
	} else
		return false;
}

private int pxiOffset(address a) {
	return int(a) - int(runtime.lowCodeAddress());
	
}

ref<ExceptionContext> createExceptionContext(address stackPointer) {
	address top = runtime.stackTop();
	
	long stackSize = long(top) - long(stackPointer);
	pointer<byte> mem = pointer<byte>(memory.alloc(stackSize + ExceptionContext.bytes));
	ref<ExceptionContext> results = ref<ExceptionContext>(mem);
	results.stackCopy = mem + ExceptionContext.bytes;
	C.memcpy(results.stackCopy, stackPointer, int(stackSize));
	results.stackPointer = stackPointer;
	results.stackBase = stackPointer;
	results.stackSize = int(stackSize);
	return results;
}


public abstract ref<ExceptionContext> exceptionContext(ref<ExceptionContext> newContext);
/**
 * This method records in the runtime's ExecutionContext the given exception, if this is passed a null,
 * the 'uncaught exception' indicator is effectively reset. If passed a null, the enclosing ExecutionContext
 * will detect that an uncaught exception terminated execution.
 */
private abstract void exposeException(ref<Exception> e);

abstract void registerHardwareExceptionHandler(void handler(ref<HardwareException> info));

public abstract ref<Exception> fetchExposedException();
abstract address exceptionsAddress();
abstract int exceptionsCount();

abstract void setSourceLocations(address location, int count);
abstract pointer<SourceLocation> sourceLocations();
abstract int sourceLocationsCount();

abstract void callCatchHandler(ref<Exception> exception, address frame, int handler);

public class ExceptionContext {
	public address exceptionAddress;		// The machine instruction causing the exception
	public address stackPointer;			// The thread stack point at the moment of the exception
	public address framePointer;			// The hardware frame pointer at the moment of the exception
	public address lastCrawledFramePointer;	// Used when re-throwing an exception to ensure proper crawl.

	// This is a copy of the hardware stack at the time of the exception.  It may extend beyond the actual
	// hardware stack at the moment of the exception because, for example, the call to create the copy used
	// the address of a local variable to get a stack offset.
	
	// To compute the address in the copy from a forensic machine address, use the following:
	//
	//	COPY_ADDRESS = STACK_ADDRESS - stackBase + stackCopy;
	
	public address stackBase;			// The machine address of the hardware stack this copy was taken from
	public pointer<byte> stackCopy;		// The first byte of the copy
	public address memoryAddress;		// Valid only for access exceptions: memory location referenced
	public int exceptionType;			// Exception type
	public int exceptionFlags;			// Flags (dependent on type).
	public int stackSize;				// The length of the copy
	public address inferredFramePointer;	// The frame pointer inferred when the hardware value is not valid.
											// Note: C++ and OS ilbraries do not maintain a proper frame pointer
											// so hardware exceptions can leave the stack chain corrupted at the top.
	
	boolean valid(address stackAddress) {
		return pointer<byte>(stackBase) <= pointer<byte>(stackAddress) &&
				pointer<byte>(stackAddress) < pointer<byte>(stackBase) + stackSize;
	}

	long slot(address stackAddress) {
		if (!valid(stackAddress))
			return 0;
		long addr = long(stackAddress);
		long base = long(stackBase);
		long copy = long(address(stackCopy));
		long target = addr - base + copy;
		ref<long> copyAddress = ref<long>(address(target));
		return *copyAddress;
	}
	
	void print() {
		printf("    exception address          %p\n", exceptionAddress);
		printf("    stack pointer              %p\n", stackPointer);
		printf("    frame pointer              %p\n", framePointer);
		printf("    inferred frame pointer     %p\n", inferredFramePointer);
		printf("    last crawled frame pointer %p\n", lastCrawledFramePointer);
		printf("    stack base                 %p\n", stackBase);
		printf("    stack top                  %p\n", long(stackBase) + stackSize);
		printf("    exception type             %x\n", unsigned(exceptionType));
		printf("    exception flags            %x\n", unsigned(exceptionFlags));
	}
}

@Header
public class HardwareException {
	public address codePointer;
	public address framePointer;
	public address stackPointer;
	public long exceptionInfo0;
	public int exceptionInfo1;
	public int exceptionType;
}
/**
 * @param ip The machine address to obtain a symbol for.
 * @param offset The offset into the Parasol code image where the symbol could be found. If
 * the value is -1, then only the ip is used and it is assumed to be outside Parasol code.
 * @param locationIsExact true if this is the exact address you care about. For example, if
 * it is the return address from a function, it may be pointing to the next source line so
 * this code will adjust to look for the location one byte before the given address.
 */
public string formattedLocation(address ip, int offset, boolean locationIsExact) {
	if (offset < 0)
		return "-";
	int unadjustedOffset = offset;
	if (!locationIsExact)
		offset--;
	pointer<SourceLocation> psl = sourceLocations();
	int interval = sourceLocationsCount();
	string result;
	for (;;) {
		if (interval <= 0)
			return formattedExternalLocation(ip);
		int middle = interval / 2;
		if (psl[middle].offset > offset)
			interval = middle;
		else if (middle == interval - 1 || psl[middle + 1].offset > offset) {
			ref<FileStat> file = psl[middle].file;
			result.printf("%s %d (@%x)", file.filename(), file.scanner().lineNumber(psl[middle].location) + 1, unadjustedOffset);
			break;
		} else {
			psl = &psl[middle + 1];
			interval = interval - middle - 1;
		}
	}
	return result;
}

private string formattedExternalLocation(address ip) {
	string result;
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.Dl_info info;

		if (ip != null && linux.dladdr(ip, &info) != 0) {
			long symOffset = long(ip) - long(info.dli_saddr);
			if (info.dli_sname == null)
				result.printf("%s (@%p)", string(info.dli_fname), ip); 
			else
				result.printf("%s %s+0x%x (@%p)", string(info.dli_fname), string(info.dli_sname), symOffset, ip); 
			return result;
		}
	}
	result.printf("@%p", ip);
	return result;
}

private Monitor serializeDumps;

private void dumpMyThread(ref<ExceptionContext> context) {
	ref<thread.Thread> t = thread.currentThread();
	Exception e(context);
	lock (serializeDumps) {
		printf("\nThread %s (%d) stack\n", t.name(), t.id());
		process.stdout.flush();
		e.inferFramePointer();
		string s = e.textStackTrace();
		if (s.length() == 0)
			context.print();
		else
			print(s);
	}
}

private void dumpAllThreads(ref<ExceptionContext> context) {
	printf("\n\nSIGQUIT dump:\n\n");
	dumpMyThread(context);
	ref<thread.Thread> t = thread.currentThread();
	ref<thread.Thread>[] threads = thread.getActiveThreads();
	int pid = linux.getpid();
	for (int i = 0; i < threads.length(); i++) {
		if (threads[i] == t || threads[i] == null)
			continue;
//		printf("t %p thread %p\n", t, threads[i]);
		linux.tgkill(pid, int(threads[i].id()), linux.SIGQUIT);
	}
	thread.sleep(1000);
}

