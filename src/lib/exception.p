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

public class Exception {
	public Exception() {
		
	}
	
	public Exception(string message) {
		
	}
}

@Header
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

