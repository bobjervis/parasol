/*
   Copyright 2015 Rovert Jervis

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

import parasol:compiler.FileStat;
import parasol:x86_64.ExceptionEntry;
import parasol:x86_64.SourceLocation;
import parasol:process;
import native:windows;

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
//		printf("    failure address %p\n", raised.exceptionAddress);
//		printf("    sp: %p fp: %p stack size: %d\n", raised.stackPointer, raised.framePointer, raised.stackSize);
		address stackLow = _exceptionContext.stackPointer;
		address stackHigh = pointer<byte>(_exceptionContext.stackPointer) + _exceptionContext.stackSize;
		address fp = _exceptionContext.framePointer;
		address ip = _exceptionContext.exceptionAddress;
		string tag = "->";
		int lowCode = int(lowCodeAddress());
		int staticMemoryLength = int(highCodeAddress()) - lowCode;
		while (long(fp) >= long(stackLow) && long(fp) < long(stackHigh)) {
//			printf("fp = %p ip = %p relative = %x", fp, ip, int(ip) - int(_staticMemory));
			pointer<address> stack = pointer<address>(fp);
			long nextFp = _exceptionContext.slot(fp);
			int relative = int(ip) - lowCode;
			string locationLabel;
			if (relative >= staticMemoryLength || relative < 0)
				locationLabel.printf("ext @%x", ip);
			else
				locationLabel = formattedLocation(relative, locationIsExact);
			output.printf(" %2s %s\n", tag, locationLabel);
//			if (nextFp != 0 && nextFp < long(fp)) {
//				printf("    *** Stored frame pointer out of sequence: %p\n", nextFp);
//				break;
//			}
			fp = address(nextFp);
			ip = address(_exceptionContext.slot(stack + 1));
			tag = "";
			locationIsExact = false;
		}
		return output;
	}
	
	private static string formattedLocation(int offset, boolean locationIsExact) {
		int unadjustedOffset = offset;
		if (!locationIsExact)
			offset--;
		pointer<SourceLocation> psl = sourceLocations();
		int interval = sourceLocationsCount();
		string result;
		for (;;) {
			if (interval <= 0) {
				result.printf("@%x", offset);
				break;
			}
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
	
	void throwNow(address framePointer, address stackPointer) {
		if (_exceptionContext == null) {
			_exceptionContext = createExceptionContext(stackPointer);
			_exceptionContext.framePointer = framePointer;
			_exceptionContext.exceptionAddress = pointer<address>(stackPointer)[-1];
		}
		address stackTop = address(long(_exceptionContext.stackBase) + _exceptionContext.stackSize);
		pointer<address> searchEnd = pointer<address>(stackTop) + -2;
		pointer<address> frame = pointer<address>(_exceptionContext.framePointer);
		pointer<address> stack = pointer<address>(_exceptionContext.stackPointer);
		if (frame < stack || frame >= searchEnd) {
			for (pointer<address> rbpCandidate = stack; rbpCandidate < searchEnd; rbpCandidate++)
				crawlStack(rbpCandidate);
		} else
			crawlStack(frame);
		printf("\nRBP %p is out of stack range [%p - %p] ip %p\n", 
				_exceptionContext.framePointer, _exceptionContext.stackPointer, 
				stackTop, _exceptionContext.exceptionAddress);
		process.exit(1);
	}
	
	private void crawlStack(pointer<address> frame) {
		pointer<address> initialRbp = frame;
		pointer<address> oldRbp;
		pointer<ExceptionEntry> ee = pointer<ExceptionEntry>(exceptionsAddress());
		int count = exceptionsCount();
		if (count == 0) {
			printf("No exceptions table for this image.\n");
			process.exit(1);
		}
		pointer<byte> lowCode = lowCodeAddress();
		pointer<byte> highCode = highCodeAddress();
		int(address ip, address elem) comparator = comparatorCurrentIp;
		pointer<byte> ip = pointer<byte>(_exceptionContext.exceptionAddress);
		address stackTop = address(long(_exceptionContext.stackBase) + _exceptionContext.stackSize);
		pointer<address> plausibleEnd = pointer<address>(stackTop) + -2;
		do {
			if (ip >= lowCode && ip < highCode) {
				int location = int(ip - lowCode);
				address result = bsearch(&location, ee, count, ExceptionEntry.bytes, comparator);

				if (result != null) {
					ref<ExceptionEntry> ee = ref<ExceptionEntry>(result);

					// If we have a handler, call it.
					if (ee.handler != 0) {
						callCatchHandler(this, frame, ee.handler);
						process.exit(1);
					}
				}
			}
			oldRbp = frame;
			ip = pointer<byte>(frame[1]);
			frame = pointer<address>(*frame);
			comparator = comparatorReturnAddress;
		} while (frame > oldRbp && frame < plausibleEnd);
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

public class RuntimeException extends Exception {
	RuntimeException() {
	}
	
	RuntimeException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}
	
	public string message() {
		if (_exceptionContext == null)
			return "RuntimeException (not thrown)\n";
		pointer<byte> message = windows.FormatMessage(unsigned(_exceptionContext.exceptionType));
		string text(message);
		string output;
		output.printf("RuntimeException: ");
		if (_exceptionContext.exceptionType == 0)
			output.printf("Assertion failed ip %p", _exceptionContext.exceptionAddress);
		else {
			output.printf("Uncaught exception %x", _exceptionContext.exceptionType);
			if (message != null)
				output.printf(" (%s)", text);
			output.printf(" ip %p", _exceptionContext.exceptionAddress);
			if (_exceptionContext.exceptionType == EXCEPTION_ACCESS_VIOLATION ||
				_exceptionContext.exceptionType == EXCEPTION_IN_PAGE_ERROR)
				output.printf(" flags %d referencing %p", _exceptionContext.exceptionFlags, _exceptionContext.memoryAddress);
		}
		return output;
	}
	
	ref<RuntimeException> clone() {
		ref<RuntimeException> n = new RuntimeException(_exceptionContext);
		return n;
	}	

}

public class DivideByZeroException extends RuntimeException {
	DivideByZeroException(ref<ExceptionContext> exceptionContext) {
		super(exceptionContext);
	}

	ref<DivideByZeroException> clone() {
		ref<DivideByZeroException> n = new DivideByZeroException(_exceptionContext);
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
 * It is called under the scope of the ExecutionContext of the code throwing the eexception. Doing this inside the
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
	if (info.exceptionType == int(0xc0000094))
		throw DivideByZeroException(context);
	else {
		printf("exception %x at %p\n", info.exceptionType, info.codePointer);
		printf("Unexpected exception type\n");
		throw RuntimeException(context);
	}
}

ref<ExceptionContext> createExceptionContext(address stackPointer) {
	address top = stackTop();
	
	long stackSize = long(top) - long(stackPointer);
	pointer<byte> memory = pointer<byte>(allocz(stackSize + ExceptionContext.bytes));
	ref<ExceptionContext> results = ref<ExceptionContext>(memory);
	results.stackCopy = memory + ExceptionContext.bytes;
	memcpy(results.stackCopy, stackPointer, int(stackSize));
	results.stackPointer = stackPointer;
	results.stackBase = stackPointer;
	results.stackSize = int(stackSize);
	return results;
}


public abstract ref<ExceptionContext> exceptionContext(ref<ExceptionContext> newContext);

abstract void registerHardwareExceptionHandler(void handler(ref<HardwareException> info));

public abstract ref<Exception> fetchExposedException();
abstract address stackTop();
abstract address exceptionsAddress();
abstract int exceptionsCount();
abstract pointer<byte> lowCodeAddress();
abstract pointer<byte> highCodeAddress();

abstract void setSourceLocations(address location, int count);
abstract pointer<SourceLocation> sourceLocations();
abstract int sourceLocationsCount();

abstract void callCatchHandler(ref<Exception> exception, address frame, int handler);

class ExceptionContext {
	public address exceptionAddress;		// The machine instruction causing the exception
	public address stackPointer;			// The thread stack point at the moment of the exception
	public address framePointer;			// The frame pointer at the moment of the exception

	// This is a copy of the hardware stack at the time of the exception.  It may extend beyond the actual
	// hardware stack at the moment of the exception because, for example, the call to create the copy used
	// the address of a local variable to get a stack offset.
	
	// To compute the address in the copy from a forensic machine address, use the following:
	//
	//	COPY_ADDRESS = STACK_ADDRESS - stackBase + stackCopy;
	
	public address stackBase;			// The machine address of the hardware stack this copy was taken from
	public pointer<byte> stackCopy;		// The first byte of the copy
	public address memoryAddress;		// Valid only for memory exceptions: memory location referenced
	public int exceptionType;			// Exception type
	public int exceptionFlags;			// Flags (dependent on type).
	public int stackSize;				// The length of the copy
	
	long slot(address stackAddress) {
		long addr = long(stackAddress);
		long base = long(stackBase);
		long copy = long(address(stackCopy));
		long target = addr - base + copy;
		ref<long> copyAddress = ref<long>(address(target));
		return *copyAddress;
	}
}

@Header
class HardwareException {
	public address codePointer;
	public address framePointer;
	public address stackPointer;
	public long exceptionInfo0;
	public int exceptionInfo1;
	public int exceptionType;
}
