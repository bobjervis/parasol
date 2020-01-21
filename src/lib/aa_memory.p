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
/* TODO: This file relies on the sort order of the file names to ensure that this gets
 * run first in the list of static initializers. It is a hack!!!!
 */
/**
 * Provides facilities for dynamically allocating memory.
 */
namespace parasol:memory;

import native:C;
import native:linux;
import native:windows;
import parasol:runtime;
import parasol:exception;
import parasol:process;
import parasol:thread;
import parasol:storage;
import parasol:text;
/**
 * This implements the 'new' operator.
 *
 * It is called from inline code. Eventually, all memory allocation will be done with an Allocator.
 * Clever bit twiddlers will always find clever ways to pack objects into a single allocation.
 */
public address alloc(long size) {
	if (currentHeap != null)
		return currentHeap.alloc(size);
	else
		return heap.alloc(size);
}
/**
 * This implements the 'delete' operator.
 *
 * It is called from inline code.
 */
public void free(address p) {
	if (currentHeap != null)
		currentHeap.free(p);
	else
		heap.free(p);
}
/*
 * On startup, initialize the heap for normal or leak-detection mode.
 */
private ref<Allocator> currentHeap;

private Heap heap;
private LeakHeap leakHeap(runtime.returnAddress());

exception.registerHardwareExceptionHandler(exception.hardwareExceptionHandler);

currentHeap = &heap;
thread.Thread.init();

if (runtime.leaksFlag())
	currentHeap = &leakHeap;
/*
 * Set up the process streams as soon as the heap is established.
 */
storage.setProcessStreams();
/**
 * Thrown when a memory allocator cannot satisfy a request.
 *
 * This can occur either because the requested quantity of memory exceeds what is
 * available from the underlying operating system, or because the cumulative quantity of allocated
 * memory exhaust the available space.
 *
 * In a 64-bit memory space, you will run out of real memory before you run out of swap space. As
 * A result, your application performance is likely to suffer catastrophically.
 */
public class OutOfMemoryException extends Exception {
	public long requestedAmount;
	
	public OutOfMemoryException(long requestedAmount) {
		super("Insufficient memory for requested " + string(requestedAmount) + " bytes");
		
		this.requestedAmount = requestedAmount;
	}

	ref<OutOfMemoryException> clone() {
		ref<OutOfMemoryException> n = new OutOfMemoryException(requestedAmount);
		return n;
	}
}
/**
 * Thrown when a memory allocator detects corrupted data structures or an invalid argument to free.
 */
public class CorruptHeapException extends Exception {
	public CorruptHeapException(ref<Allocator> heap, address freeArg) {
		super("Corrupt Heap");
	}

	ref<CorruptHeapException> clone() {
		ref<CorruptHeapException> n = new CorruptHeapException(null, null);
		return n;
	}
}

/**
 * This is the abstract base class for all memory allocators.
 *
 * The compiler syntax for the binary new and delete operators expect an
 * Allocator object as the left operand of the operator.
 */
public class Allocator {
	/**
	 * This call frees all memory currently held by the Allocator. 
	 */
	public abstract void clear();
	/**
	 * Allocate a block of memory
	 *
	 * @param n The number of bytes to allocate.
	 *
	 * @return The allocated memory
	 *
	 * @exception OutOfMemoryException is thrown if the memory allocation request fails.
	 *
	 * @exception CorruptHeapException is thrown if the allocator detects data corruption.
	 */
	public abstract address alloc(long n);
	/**
	 * Free a block of memory.
	 *
	 * Passing a value of null has no effect.
	 *
	 * @param p The address returned from a previous call to {@link alloc} on this same
	 * Allocator, or null.
	 *
	 * @exception CorruptHeapException is thrown if the allocator detects data corruption.
	 */
	public abstract void free(address p);
}

public class GuardedHeap extends Allocator {
	public void clear() {
		
	}

	public address alloc(long n) {
		address p = C.calloc(unsigned(n + 48), 1);
		if (p != null) {
			pointer<byte> pb = pointer<byte>(p);
			pointer<int>(pb)[3] = int(n);
			pb[0] = 0xa6;
			pb[1] = 0x6a;
			pb[2] = 0xa6;
			pb[3] = 0x6a;
			pb[4] = 0xa6;
			pb[5] = 0x6a;
			pb[6] = 0xa6;
			pb[7] = 0x6a;
			pb[8] = 0xa6;
			pb[9] = 0x6a;
			pb[10] = 0xa6;
			pb[11] = 0x6a;
			pb[16] = 0xa6;
			pb[17] = 0x6a;
			pb[18] = 0xa6;
			pb[19] = 0x6a;
			pb[20] = 0xa6;
			pb[21] = 0x6a;
			pb[22] = 0xa6;
			pb[23] = 0x6a;
			pb[24] = 0xa6;
			pb[25] = 0x6a;
			pb[26] = 0xa6;
			pb[27] = 0x6a;
			pb[28] = 0xa6;
			pb[29] = 0x6a;
			pb[30] = 0xa6;
			pb[31] = 0x6a;
			pb[n + 32] = 0xa6;
			pb[n + 33] = 0x6a;
			pb[n + 34] = 0xa6;
			pb[n + 35] = 0x6a;
			pb[n + 36] = 0xa6;
			pb[n + 37] = 0x6a;
			pb[n + 38] = 0xa6;
			pb[n + 39] = 0x6a;
			pb[n + 40] = 0xa6;
			pb[n + 41] = 0x6a;
			pb[n + 42] = 0xa6;
			pb[n + 43] = 0x6a;
			pb[n + 44] = 0xa6;
			pb[n + 45] = 0x6a;
			pb[n + 46] = 0xa6;
			pb[n + 47] = 0x6a;
			return pb + 32;
		}
		throw OutOfMemoryException(n);
		return null;
	}
	
	public void free(address p) {
		if (p == null)
			return;
		pointer<byte> pb = pointer<byte>(p) - 32;
		int n = pointer<int>(pb)[3];
		if (pb[0] != 0xa6) fail(pb, n); 
		if (pb[1] != 0x6a) fail(pb, n); 
		if (pb[2] != 0xa6) fail(pb, n); 
		if (pb[3] != 0x6a) fail(pb, n); 
		if (pb[4] != 0xa6) fail(pb, n); 
		if (pb[5] != 0x6a) fail(pb, n); 
		if (pb[6] != 0xa6) fail(pb, n); 
		if (pb[7] != 0x6a) fail(pb, n); 
		if (pb[8] != 0xa6) fail(pb, n); 
		if (pb[9] != 0x6a) fail(pb, n); 
		if (pb[10] != 0xa6) fail(pb, n); 
		if (pb[11] != 0x6a) fail(pb, n); 
		if (pb[16] != 0xa6) fail(pb, n); 
		if (pb[17] != 0x6a) fail(pb, n); 
		if (pb[18] != 0xa6) fail(pb, n); 
		if (pb[19] != 0x6a) fail(pb, n); 
		if (pb[20] != 0xa6) fail(pb, n); 
		if (pb[21] != 0x6a) fail(pb, n); 
		if (pb[22] != 0xa6) fail(pb, n); 
		if (pb[23] != 0x6a) fail(pb, n); 
		if (pb[24] != 0xa6) fail(pb, n); 
		if (pb[25] != 0x6a) fail(pb, n); 
		if (pb[26] != 0xa6) fail(pb, n); 
		if (pb[27] != 0x6a) fail(pb, n); 
		if (pb[28] != 0xa6) fail(pb, n); 
		if (pb[29] != 0x6a) fail(pb, n); 
		if (pb[30] != 0xa6) fail(pb, n); 
		if (pb[31] != 0x6a) fail(pb, n); 
		if (pb[n + 32] != 0xa6) fail(pb, n); 
		if (pb[n + 33] != 0x6a) fail(pb, n); 
		if (pb[n + 34] != 0xa6) fail(pb, n); 
		if (pb[n + 35] != 0x6a) fail(pb, n); 
		if (pb[n + 36] != 0xa6) fail(pb, n); 
		if (pb[n + 37] != 0x6a) fail(pb, n); 
		if (pb[n + 38] != 0xa6) fail(pb, n); 
		if (pb[n + 39] != 0x6a) fail(pb, n); 
		if (pb[n + 40] != 0xa6) fail(pb, n); 
		if (pb[n + 41] != 0x6a) fail(pb, n); 
		if (pb[n + 42] != 0xa6) fail(pb, n); 
		if (pb[n + 43] != 0x6a) fail(pb, n); 
		if (pb[n + 44] != 0xa6) fail(pb, n); 
		if (pb[n + 45] != 0x6a) fail(pb, n); 
		if (pb[n + 46] != 0xa6) fail(pb, n); 
		if (pb[n + 47] != 0x6a) fail(pb, n); 
		C.free(pb);
	}

	private void fail(pointer<byte> pb, int n) {
		currentHeap = &heap;
		
		printf("\n");
		text.memDump(pb - 64, n + 48 + 64);
		throw CorruptHeapException(this, pb + 16);
	}
}

public void fail(pointer<byte> addr) {
	currentHeap = &heap;
	text.memDump(addr - 36, 0x40);
	currentHeap = &guardedHeap;
}

GuardedHeap guardedHeap;

/**
 * This is the main process Heap.
 *
 * The current implementation of the Parasol heap is to use calloc/free from the underlying
 * C library.
 */
public class Heap extends Allocator {
	public void clear() {
		
	}

	public address alloc(long n) {
		address p = C.calloc(unsigned(n), 1);
		if (p != null)
			return p;
		throw OutOfMemoryException(n);
		return null;
	}
	
	public void free(address p) {
		C.free(p);
	}
}
/**
 * This form of heap provides checking for memory leaks.
 *
 * It includes debugging logic that tracks the stack at the time of each call, at termination the
 * process will examine the heap and report on any objects still allocated.
 */
public class LeakHeap extends Allocator {
	@Constant
	private static int BLOCK_ALIGNMENT = 32;	// Allows for blocks to be used in MMX instructions, and avoids 
												// some fragmentation.
	@Constant
	private static long SECTION_LENGTH = 1 * 1024 * 1024;  // try one megabyte.
	@Constant
	private static long SECTION_DATA = SECTION_LENGTH - SectionHeader.bytes;
	@Constant
	private static int IN_USE_FLAG = 1;
	
	class BlockHeader {
		long				blockSize;	// Always a multiple of 16, low order bit overloaded: if set, block is in use
		pointer<address>	callStack;	// First address is the count of remaining frames, each frame is a code address
	}
	
	class SectionHeader {
		long			sectionSize;
		ref<SectionHeader> next;
		ref<FreeBlock> firstFreeBlock;
		private long _filler;
		
		boolean isSectionEndSentinel(ref<BlockHeader> bh) {
			address ses = pointer<byte>(this) + (sectionSize - SectionEndSentinel.bytes);
			return ses == bh;
		}
		
	}
	
	class SectionEndSentinel {
		long			inUseMarker;	// Has the low order bit set, since this was not actually allocated, no other
										// bits matter.
		private long	_filler;			
	}
	
	class FreeBlock {
		long blockSize;
		ref<FreeBlock> previous;
		ref<FreeBlock> next;
		ref<SectionHeader> enclosing;
	}
	
	private ref<SectionHeader> _sections;
	private ref<FreeBlock> _nextFreeBlock;
	private boolean _busy;
	private boolean _everUsed;
	private Monitor _lock;
	private address _staticScopeReturnAddress;

	public LeakHeap(address staticScopeReturnAddress) {
		_staticScopeReturnAddress = staticScopeReturnAddress;
	}
	
	public ~LeakHeap() {
		process.stdout.flush();
		delete process.stdout;
		int errFd;
		if (_everUsed && _sections != null)
			errFd = linux.dup(2);
		process.stdout = null;
		delete process.stderr;
		process.stderr = null;
		delete process.stdin;
		process.stdin = null;
		if (_everUsed) {
			currentHeap = &heap;		// heap is declared first, so it should still be alive when this destructor is called.
			if (_sections != null) {
				ref<Writer> w = storage.createTextFile("leaks.txt");
				string s = "Leaks found!\n";
				linux.write(errFd, &s[0], s.length());
				linux.dup2(1, errFd);
				analyze(w);
				linux.close(errFd);
				delete w;
			}
		}
		thread.Thread.destruct();
	}
	
	public void clear() {
		
	}

	public address alloc(long n) {
		lock (_lock) {
			if (_busy)
				return heap.alloc(n);
			_busy = true;
			_everUsed = true;
			currentHeap = &heap;
	//		printf("LeakHeap.alloc(%#x bytes)\n", n);
			long originalN = n;
			pointer<address> rbp = getRBP(0);
			address stackTop = runtime.stackTop();
			int frames = stackFrames(long(rbp), long(stackTop));
			long framesOffset = (BlockHeader.bytes + n + address.bytes - 1) & ~(address.bytes - 1);
			n = (framesOffset + frames * address.bytes + address.bytes + BLOCK_ALIGNMENT - 1) & ~(BLOCK_ALIGNMENT - 1);
	//		printf("    padded n = %#x\n", n);
	//		print();
			pointer<BlockHeader> bh;
			// Allocate a block.
			if (n > SECTION_DATA) {
				pointer<SectionHeader> nh = allocateSection(n + SectionHeader.bytes);
				if (nh == null)
					throw OutOfMemoryException(originalN);
				bh = pointer<BlockHeader>(nh + 1);
			} else {
				// if _nextFreeBlock is null, we have an empty free list and need to skip directly to allocating a new section.
				ref<FreeBlock> fb = _nextFreeBlock;
				if (fb != null) {
					do {
						if (fb.blockSize >= n) {
							
							// Should we consume the whole free block, or just split it?
							if (fb.blockSize > n) {
								// Split the block, move adjacent references to the new free block
								ref<FreeBlock> nb = ref<FreeBlock>(long(fb) + n);
								nb.blockSize = fb.blockSize - n;
								nb.enclosing = fb.enclosing;
								nb.next = fb.next;
								if (nb.next != null)
									nb.next.previous = nb;
								nb.previous = fb.previous;
								if (nb.previous != null)
									nb.previous.next = nb;
								else
									nb.enclosing.firstFreeBlock = nb;
								_nextFreeBlock = nb;
								if (fb == fb.enclosing.firstFreeBlock)
									fb.enclosing.firstFreeBlock = nb;
	//							printf("        Trimmed free block @%p to %#x bytes\n", nb, nb.blockSize);
							} else {
								_nextFreeBlock = advance(fb);
								if (_nextFreeBlock == fb)
									_nextFreeBlock = null;
								
								// Remove the free block from the section chain.
								if (fb.next != null)
									fb.next.previous = fb.previous;
								if (fb.previous != null)
									fb.previous.next = fb.next;
								else
									fb.enclosing.firstFreeBlock = fb.next;
	//							printf("        Removed free block @%p (%#x bytes)\n", fb, fb.blockSize);
							}
							bh = pointer<BlockHeader>(fb);
							// Note: this dups the exit code.
							bh.blockSize = n + IN_USE_FLAG;
							bh.callStack = pointer<address>(pointer<byte>(bh) + framesOffset);
							rememberStackFrames(bh.callStack, long(rbp), long(stackTop));
							address x = bh + 1;
	//						printf("    Free list: Found it! @%p\n", x);
							currentHeap = &leakHeap;
							_busy = false;
							setMemory(bh + 1, 0, originalN);
							return bh + 1;
						}
						fb = advance(fb);
					} while (fb != _nextFreeBlock);
				}
				pointer<SectionHeader> nh = allocateSection(SECTION_LENGTH);
				if (nh == null)
					throw OutOfMemoryException(originalN);
				bh = pointer<BlockHeader>(nh + 1);
				_nextFreeBlock = ref<FreeBlock>(long(bh) + n);
				_nextFreeBlock.blockSize = SECTION_DATA - n - SectionEndSentinel.bytes;
				_nextFreeBlock.enclosing = nh;
				// This will simplify the end-of-section processing (?)
				ref<SectionEndSentinel> ses = ref<SectionEndSentinel>(long(_nextFreeBlock) + _nextFreeBlock.blockSize);
				ses.inUseMarker = IN_USE_FLAG; 
				nh.firstFreeBlock = _nextFreeBlock;
			}
			bh.blockSize = n + IN_USE_FLAG;
			bh.callStack = pointer<address>(pointer<byte>(bh) + framesOffset);
			rememberStackFrames(bh.callStack, long(rbp), long(stackTop));
			address x = bh + 1;
	//		printf("    New Section: _sections = %p _nextFreeBlock = %p Found it! @%p\n", _sections, _nextFreeBlock, x);
			currentHeap = &leakHeap;
			_busy = false;
			setMemory(bh + 1, 0, originalN);
			return bh + 1;
		}
	}

	private ref<FreeBlock> advance(ref<FreeBlock> fb) {
		if (fb.next != null)
			return fb.next;
		ref<SectionHeader> sh = fb.enclosing;
		for (;;) {
			if (sh.next == null)
				sh = _sections;
			else
				sh = sh.next;
			if (sh.firstFreeBlock != null)
				return sh.firstFreeBlock;
			if (sh == fb.enclosing)
				return null;
		}
	}

	private pointer<SectionHeader> allocateSection(long sectionLength) {
		sectionLength = (sectionLength + BLOCK_ALIGNMENT - 1) & ~(BLOCK_ALIGNMENT - 1);
		pointer<SectionHeader> nh;
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			nh = pointer<SectionHeader>(windows.VirtualAlloc(null, sectionLength, windows.MEM_COMMIT|windows.MEM_RESERVE, windows.PAGE_READWRITE));
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			nh = pointer<SectionHeader>(C.calloc(1, sectionLength));
		}
		if (nh == null)
			return nh;
		nh.sectionSize = SECTION_LENGTH;
		nh.next = _sections;
		_sections = nh;
		return nh;
	}

	private void freeSection(ref<SectionHeader> sh) {
	}
	
	private static int stackFrames(long rbp, long stackTop) {
		int frameCount = 0;
		long stackBottom = stackTop - 0x80000;
		while (rbp > stackBottom && rbp < stackTop) {
			rbp = *pointer<long>(rbp);
			frameCount++;
		}
		return frameCount;
	}

	private static void rememberStackFrames(pointer<address> frames, long rbp, long stackTop) {
		int frameCount = 0;
		long baseCodeAddress = long(runtime.lowCodeAddress());
		long stackBottom = stackTop - 0x80000;
		while (rbp > stackBottom && rbp < stackTop) {
			frameCount++;
			frames[frameCount] = (pointer<address>(rbp))[1];
			rbp = *pointer<long>(rbp);
		}
		frames[0] = address(frameCount);
	}
	
	public void free(address p) {
		if (p == null)
			return;
		lock (_lock) {
			currentHeap = &heap;
	//		printf("LeakHeap.free(%p)\n", p);
			ref<FreeBlock> fb = ref<FreeBlock>(long(p) - BlockHeader.bytes);
			if ((fb.blockSize & IN_USE_FLAG) == 0) {
				throw CorruptHeapException(this, p);
//				currentHeap = &leakHeap;
//				return;
			}
			fb.blockSize -= IN_USE_FLAG;
			for (ref<SectionHeader> sh = _sections; sh != null; sh = sh.next) {
				if (pointer<byte>(fb) > pointer<byte>(sh) && pointer<byte>(fb) < pointer<byte>(sh) + sh.sectionSize) {
	//				printf("    Found section @%p\n", sh);
					// The first special case is no free block in this section at all, then make this guy the free list.
					if (sh.firstFreeBlock == null) {
						fb.next = null;
						fb.previous = null;
						fb.enclosing = sh;
						sh.firstFreeBlock = fb;
						if (!checkForEmptySection(sh))
							throw CorruptHeapException(this, p);
						currentHeap = &leakHeap;
						return;
					} else if (pointer<byte>(sh.firstFreeBlock) > pointer<byte>(fb)) {
						if (long(fb) + fb.blockSize == long(sh.firstFreeBlock)) {
							if (_nextFreeBlock == sh.firstFreeBlock)
								_nextFreeBlock = fb;
							fb.next = sh.firstFreeBlock.next;
							if (fb.next != null)
								fb.next.previous = fb;
							fb.blockSize += sh.firstFreeBlock.blockSize;
						} else {
							fb.next = sh.firstFreeBlock;
							sh.firstFreeBlock.previous = fb;
						}
						fb.enclosing = sh;
						fb.previous = null;
						sh.firstFreeBlock = fb;
						if (!checkForEmptySection(sh))
							throw CorruptHeapException(this, p);
						currentHeap = &leakHeap;
						return;
					}
					for (ref<FreeBlock> srchfb = sh.firstFreeBlock; ; srchfb = srchfb.next) {
						if (srchfb.next == null) {
							if (long(srchfb) + srchfb.blockSize == long(fb)) {
								srchfb.blockSize += fb.blockSize;
							} else {
								srchfb.next = fb;
								fb.previous = srchfb;
							}
							fb.next = null;
							fb.enclosing = sh;
							if (!checkForEmptySection(sh))
								throw CorruptHeapException(this, p);
							currentHeap = &leakHeap;
							return;
						} else if (pointer<byte>(srchfb.next) > pointer<byte>(fb)) {
							if (long(srchfb) + srchfb.blockSize == long(fb)) {
								srchfb.blockSize += fb.blockSize;
								if (long(srchfb) + srchfb.blockSize == long(srchfb.next)) {
									if (_nextFreeBlock == srchfb.next)
										_nextFreeBlock = srchfb;
									srchfb.blockSize += srchfb.next.blockSize;
									srchfb.next = srchfb.next.next;
									if (srchfb.next != null)
										srchfb.next.previous = srchfb;
								}
							} else {
								fb.next = srchfb.next;
								srchfb.next = fb;
								fb.previous = srchfb;
								if (fb.next != null)
									fb.next.previous = fb;
								if (long(fb) + fb.blockSize == long(fb.next)) {
									if (_nextFreeBlock == fb.next)
										_nextFreeBlock = fb;
									fb.blockSize += fb.next.blockSize;
									fb.next = fb.next.next;
									if (fb.next != null)
										fb.next.previous = fb;
								}
							}
							fb.enclosing = sh;
							if (!checkForEmptySection(sh))
								throw CorruptHeapException(this, p);
							currentHeap = &leakHeap;
							return;
						}
					}
				}
			}
		}
		throw CorruptHeapException(this, p);
//		currentHeap = &leakHeap;
	}
	
	private boolean checkForEmptySection(ref<SectionHeader> sh) {
		ref<FreeBlock> fb = sh.firstFreeBlock;
		// If there is a gap between the first free block and the secton header,
		// that must be in-use data, so keep the section.
		if (long(sh) + SectionHeader.bytes != long(fb))
			return true;
		// At least two free blocks means there's a gap between them, at least.
		// That gap has got to be in-use, so keep the section.
		if (fb.next != null)
			return true;
		// We have one free block, it begins right after the section header. If it does not end
		// at the SectionEndSentinel, the gap is in use, so keep the section.
		if (long(sh) + sh.sectionSize - SectionEndSentinel.bytes != long(fb) + fb.blockSize)
			return true;

		// We have an empty section, free it.

		if (sh == _sections) {
			_sections = sh.next;
			freeSection(sh);
			return true;
		} else {
			for (ref<SectionHeader> ssh = _sections; ssh != null; ssh = ssh.next) {
				if (ssh.next == sh) {
					ssh.next = sh.next;
					freeSection(sh);
					return true;
				}
			}
			return false;
		}
	}

	class CallSite {
		ref<CallSite> callers;
		ref<CallSite> next;
		long totalBytes;
		int hits;
		address ip;
		
		ref<CallSite> hit(address ip, long blockSize) {
			blockSize &= ~IN_USE_FLAG;
			for (ref<CallSite> cs = callers; cs != null; cs = cs.next) {
				if (cs.ip == ip) {
					cs.totalBytes += blockSize;
					cs.hits++;
					return cs;
				}
			}
			ref<CallSite> cs = new CallSite;
			cs.next = callers;
			callers = cs;
			cs.ip = ip;
			cs.totalBytes += blockSize;
			cs.hits++;
			return cs;
		}
		
		void print(ref<Writer> output, int indent) {
			output.printf("%*.*c%d (%dKB)", indent, indent, ' ', hits, (totalBytes + 512) / 1024);
			output.flush();
			ref<CallSite> cs = callers;
			if (ip == null)
				output.printf(" Total\n");
			else {
				long baseCodeAddress = long(runtime.lowCodeAddress());
				if (ip != leakHeap._staticScopeReturnAddress)
					output.printf(" %s", exception.formattedLocation(ip, 0, false));
				while (cs != null && cs.next == null) {
					// We have only one call site, so merge it with this one...
					if (cs.ip != leakHeap._staticScopeReturnAddress)
						output.printf(" %s", exception.formattedLocation(cs.ip, 0, false));
					cs = cs.callers;
				}
				output.printf("\n");
			}
			ref<CallSite>[] callersArray;
			for (; cs != null; cs = cs.next)
				callersArray.append(cs);
			
			for (int j = 0; j < callersArray.length() - 1; j++) {
				int best = j;
				for (int i = 1; i < callersArray.length(); i++) {
					if (callersArray[best].totalBytes < callersArray[i].totalBytes)
						best = i;
				}
				if (best != j) {
					ref<CallSite> cs = callersArray[best];
					callersArray[best] = callersArray[j];
					callersArray[j] = cs;
				}
			}
			for (int j = 0; j < callersArray.length(); j++)
				callersArray[j].print(output, indent + 4);
		}
	}
	
	void analyze(ref<Writer> output) {
		long totalBlocks;
		long totalBytes;
		CallSite root;
		
/*
		for (ref<SectionHeader> sh = _sections; sh != null; sh = sh.next) {
			output.printf("Section %p[%x]\n", sh, sh.sectionSize);
			for (ref<FreeBlock> fb = sh.firstFreeBlock; fb != null; fb = fb.next)
				output.printf("    Free %p[%x] prev %p next %p\n", fb, fb.blockSize, fb.previous, fb.next);
		}
 */
		root.ip = null;
		boolean hasNextFreeBlock = false;
		for (ref<SectionHeader> sh = _sections; sh != null; sh = sh.next) {
			pointer<byte> lastUseful = pointer<byte>(sh) + (sh.sectionSize - SectionEndSentinel.bytes);
			for (ref<BlockHeader> bh = ref<BlockHeader>(pointer<SectionHeader>(sh) + 1); 
					pointer<byte>(bh) < lastUseful; 
					bh = ref<BlockHeader>(pointer<byte>(bh) + (bh.blockSize & ~IN_USE_FLAG))) {
				if ((bh.blockSize & IN_USE_FLAG) != 0) {
					pointer<address> callStack = bh.callStack;
					int frames = int(*callStack);
					callStack++;
					ref<CallSite> cs = &root;
					root.hits++;
					root.totalBytes += pointer<byte>(bh.callStack) - pointer<byte>(bh);
					for (int i = 0; i < frames; i++) {
//						printf("[%d] %x\n", i, callStack[i]);
						cs = cs.hit(callStack[i], pointer<byte>(bh.callStack) - pointer<byte>(bh));
					}
				}
			}
		}
		root.print(output, 0);
	}
	
	void print() {
		if (_sections == null) {
			printf("      <empty>\n");
			return;
		}
		boolean hasNextFreeBlock = false;
		for (ref<SectionHeader> sh = _sections; sh != null; sh = sh.next) {
			printf("      Section @%p [%#x]", sh, sh.sectionSize);
			if (sh.firstFreeBlock == null) {
				printf(" - No free space\n");
				continue;
			}
			ref<BlockHeader> bh = ref<BlockHeader>(pointer<SectionHeader>(sh) + 1);
			ref<FreeBlock> prev = null;
			if (sh.firstFreeBlock != null && 
				(pointer<byte>(sh.firstFreeBlock) < pointer<byte>(sh) + SectionHeader.bytes || 
				 pointer<byte>(sh.firstFreeBlock) >= pointer<byte>(sh) + SECTION_LENGTH || 
				 (long(sh.firstFreeBlock) & (BLOCK_ALIGNMENT - 1)) != 0)) {
				printf(" - Bad firstFreeBlock (%p)\n", sh.firstFreeBlock);
				continue;
			}
			printf("\n");
			
			for (ref<FreeBlock> fb = sh.firstFreeBlock; fb != null; fb = fb.next) {
				bh = reportAllocatedBlocks(sh, bh, fb);
				if (fb == _nextFreeBlock)
					hasNextFreeBlock = true;
				printf("     %s @%p [%#x] free", fb == _nextFreeBlock ? "->" : "  ", fb, fb.blockSize);
				if (fb.enclosing != sh)
					printf(" ** bad enclosing pointer (%p) **", fb.enclosing);
				if (fb.previous != prev)
					printf(" ** bad previous pointer (%p) **", fb.previous);
				if (fb.next != null && 
					(pointer<byte>(fb) >= pointer<byte>(fb.next) || 
					 pointer<byte>(fb.next) >= pointer<byte>(sh) + SECTION_LENGTH || 
					 (long(fb.next) & (BLOCK_ALIGNMENT - 1)) != 0)) {
					printf(" ** bad next pointer (%p) **\n", fb.next);
					break;
				}
				printf("\n");
				bh = ref<BlockHeader>(pointer<byte>(fb) + fb.blockSize);
				prev = fb;
			}
			reportAllocatedBlocks(sh, bh, ref<FreeBlock>(pointer<byte>(sh) + sh.sectionSize));
		}
		if (!hasNextFreeBlock)
			printf("** Could not find _nextFreeBlock: %p **\n", _nextFreeBlock);
	}
	
	private ref<BlockHeader> reportAllocatedBlocks(ref<SectionHeader> sh, ref<BlockHeader> bh, ref<FreeBlock> fb) {
		int blocks = 0;
		while (address(bh) != address(fb)) {
			if ((bh.blockSize & IN_USE_FLAG) == 0) {
				printf("            ** @%p [%#x] is not an allocated block **\n", bh, bh.blockSize);
				break;
			}
			if (sh.isSectionEndSentinel(bh)) {
				if (bh.blockSize != IN_USE_FLAG)
					printf("            ** <bad block length in SectionEndSentinel @%p [%#x]> **\n", bh, bh.blockSize);
				break;
			}
			if (bh.blockSize < BLOCK_ALIGNMENT) {
				printf("            ** <bad block length @%p [%#x]> **\n", bh, bh.blockSize);
				break;
			}
			bh = ref<BlockHeader>(long(bh) + bh.blockSize - IN_USE_FLAG);
			if (pointer<byte>(bh) > pointer<byte>(fb)) {
				printf("            ** <bad block list @%p> **\n", bh);
				break;
			}
			blocks++;
		}
		if (blocks > 0)
			printf("        - %d allocated blocks\n", blocks);
		return bh;
	}
	
}
/**
 * An allocator that only releases memory all at once.
 *
 * This allocator provides for efficient allocation of small memory blocks in
 * situations where all of the memory allocated can be released at once.
 *
 * A compiler is a classic example of an application that allocates large numbers of 
 * objects and retains most of them until specific points in time where all the memory gets
 * freed at once. Even allowing for the creation of some garbage, the higher efficiency of the
 * allocaiton process and dramatically improve overall application performance.
 */
public class NoReleasePool extends Allocator {
	private static long BLOCK_SIZE = 64 * 1024;

	private long _remaining;
	private pointer<byte> _freeSpace;
	private pointer<byte>[] _blocks;
	
	public NoReleasePool() {
	}

	~NoReleasePool() {
		clear();
	}
	/**
	 * Releases all memory allocated through this allocator.
	 */
	public void clear() {
		for (int i = 0; i < _blocks.length(); i++)
			currentHeap.free(_blocks[i]);
		_blocks.clear();
	}
	
	public address alloc(long n) {
		n = (n + (address.bytes - 1)) & ~(address.bytes - 1);		// round up to align
		if (n >= BLOCK_SIZE) {
			pointer<byte> megaBlock = pointer<byte>(currentHeap.alloc(n));
			_blocks.append(megaBlock);
			return megaBlock;
		} else if (n >= _remaining) {
			pointer<byte> block = pointer<byte>(currentHeap.alloc(BLOCK_SIZE));
			_blocks.append(block);
			_freeSpace = block + n;
			_remaining = BLOCK_SIZE - n;
			return block;
		} else {
			pointer<byte> block = _freeSpace;
			_freeSpace += int(n);
			_remaining -= n;
			return block;
		}
	}
	/**
	 * This method does nothing. Blocks cannot be individually deleted.
	 *
	 * @param p the address of the block to delete
	 */
	public void free(address p) {
	}
}

private pointer<address> getRBP(var v) {
	return pointer<pointer<address>>(&v)[-2];
}
/**
 * Fill all bytes of a memory area with the same value.
 *
 * @param dest The address of the memory block to be filled.
 * @param value The byte value to fill memory with.
 * @param length The number of bytes to fill.
 */
public void setMemory(address dest, byte value, long length) {
	while (length > int.MAX_VALUE - 15) {
		C.memset(dest, value, int.MAX_VALUE - 15);
		dest = pointer<byte>(dest) + (int.MAX_VALUE - 15);
		length -= int.MAX_VALUE - 15;
	}
	C.memset(dest, value, int(length));
}
