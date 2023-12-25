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

public enum StartingHeap {
	PRODUCTION,
	DETECT_LEAKS,
	GUARD
}

currentHeap = &heap;
thread.Thread.init();

switch (runtime.startingHeap()) {
case PRODUCTION:
	break;

case DETECT_LEAKS:
	currentHeap = &leakHeap;
	break;

case GUARD:
	currentHeap = &guardedHeap;
	break;
}
/** @ignore 
 * Called when the main thread hits an uncaught exception.
 */
public void resetHeap() {
	currentHeap = &heap;
}
/*
 * Set up the process streams as soon as any special heap is established.
 */
storage.setProcessStreams(false);

if (currentHeap != &heap)
	printf("Using %s\n", string(runtime.startingHeap()));
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
	address _freeArg;

	public CorruptHeapException(ref<Allocator> heap, address freeArg) {
		super(format(freeArg));
		_freeArg = freeArg;
	}

	private static string format(address freeArg) {
		string s;
		s.printf("Corrupt Heap: %p", freeArg);
		return s;
	}

	ref<CorruptHeapException> clone() {
		ref<CorruptHeapException> n = new CorruptHeapException(&leakHeap, _freeArg);
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
		address p = C.calloc(n + 48, 1);
		if (p != null) {
			pointer<unsigned> pi = pointer<unsigned>(p);
			pi[0] = 0xa66aa66a;
			pi[1] = 0xa66aa66a;
			pi[2] = 0xa66aa66a;
			pi[3] = unsigned(n);
			pi[4] = 0xa66aa66a;
			pi[5] = 0xa66aa66a;
			pi[6] = 0xa66aa66a;
			pi[7] = 0xa66aa66a;
			pointer<byte> pb = pointer<byte>(p) + n + 32;
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
			pb[12] = 0xa6;
			pb[13] = 0x6a;
			pb[14] = 0xa6;
			pb[15] = 0x6a;
			return pi + 8;
		}
		throw OutOfMemoryException(n);
		return null;
	}
	
	public void free(address p) {
		if (p == null)
			return;
		pointer<byte> pb = pointer<byte>(p) - 32;
		int n = pointer<int>(pb)[3];
		if (pb[0] != 0x6a) fail(pb, n); 
		if (pb[1] != 0xa6) fail(pb, n); 
		if (pb[2] != 0x6a) fail(pb, n); 
		if (pb[3] != 0xa6) fail(pb, n); 
		if (pb[4] != 0x6a) fail(pb, n); 
		if (pb[5] != 0xa6) fail(pb, n); 
		if (pb[6] != 0x6a) fail(pb, n); 
		if (pb[7] != 0xa6) fail(pb, n); 
		if (pb[8] != 0x6a) fail(pb, n); 
		if (pb[9] != 0xa6) fail(pb, n); 
		if (pb[10] != 0x6a) fail(pb, n); 
		if (pb[11] != 0xa6) fail(pb, n); 
		if (pb[16] != 0x6a) fail(pb, n); 
		if (pb[17] != 0xa6) fail(pb, n); 
		if (pb[18] != 0x6a) fail(pb, n); 
		if (pb[19] != 0xa6) fail(pb, n); 
		if (pb[20] != 0x6a) fail(pb, n); 
		if (pb[21] != 0xa6) fail(pb, n); 
		if (pb[22] != 0x6a) fail(pb, n); 
		if (pb[23] != 0xa6) fail(pb, n); 
		if (pb[24] != 0x6a) fail(pb, n); 
		if (pb[25] != 0xa6) fail(pb, n); 
		if (pb[26] != 0x6a) fail(pb, n); 
		if (pb[27] != 0xa6) fail(pb, n); 
		if (pb[28] != 0x6a) fail(pb, n); 
		if (pb[29] != 0xa6) fail(pb, n); 
		if (pb[30] != 0x6a) fail(pb, n); 
		if (pb[31] != 0xa6) fail(pb, n); 
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
		throw CorruptHeapException(this, pb + 32);
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
		address p = C.calloc(n, 1);
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
	private static int BLOCK_ALIGNMENT = 16;	// Allows for blocks to be used in MMX instructions.
	@Constant
	private static int BLOCK_GRANULARITY = 32;	// Allows for blocks to avoid some fragmentation.
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
	
	private long _allocations;
	private long _frees;

	class SectionHeader {
		long			sectionSize;
		ref<SectionHeader> next;
		ref<FreeBlock> firstFreeBlock;
		private long _filler;
		
		boolean isSectionEndSentinel(ref<BlockHeader> bh) {
			address ses = pointer<byte>(this) + (sectionSize - SectionEndSentinel.bytes);
			return ses == bh;
		}

		void createSectionEndSentinel() {
			ref<SectionEndSentinel> ses = ref<SectionEndSentinel>(pointer<byte>(this) + (sectionSize - SectionEndSentinel.bytes));
			ses.inUseMarker = IN_USE_FLAG + SectionEndSentinel.bytes; 
		}

		boolean contains(address p) {
			if (pointer<byte>(this) > pointer<byte>(p))
				return false;
			else
				return pointer<byte>(this) + sectionSize > pointer<byte>(p);
		}

		boolean free(ref<LeakHeap> lh, ref<FreeBlock> fb) {
//			printf("    Found section @%p\n", sh);
			if (!validateAllocationChain(fb, true)) {
				fb.blockSize += IN_USE_FLAG;
				return false;
			}
			// The first special case is no free block in this section at all, then make this guy the free list.
			if (firstFreeBlock == null) {
				fb.next = null;
				fb.previous = null;
				firstFreeBlock = fb;
				fb.enclosing = this;
				return validateAllocationChain(fb, false);
			} else if (pointer<byte>(firstFreeBlock) > pointer<byte>(fb)) {
				if (long(fb) + fb.blockSize == long(firstFreeBlock)) {
					if (lh._nextFreeBlock == firstFreeBlock)
						lh._nextFreeBlock = fb;
					fb.next = firstFreeBlock.next;
					if (fb.next != null)
						fb.next.previous = fb;
					fb.blockSize += firstFreeBlock.blockSize;
				} else {
					fb.next = firstFreeBlock;
					firstFreeBlock.previous = fb;
				}
				fb.previous = null;
				firstFreeBlock = fb;
				fb.enclosing = this;
				return validateAllocationChain(fb, false);
			}
			for (ref<FreeBlock> srchfb = firstFreeBlock; ; srchfb = srchfb.next) {
				if (srchfb.next == null) {
					if (long(srchfb) + srchfb.blockSize == long(fb)) {
						srchfb.blockSize += fb.blockSize;
					} else {
						srchfb.next = fb;
						fb.previous = srchfb;
					}
					fb.next = null;
					fb.enclosing = this;
					return validateAllocationChain(fb, false);
				} else if (pointer<byte>(srchfb.next) > pointer<byte>(fb)) {
					if (long(srchfb) + srchfb.blockSize == long(fb)) {
						srchfb.blockSize += fb.blockSize;
						if (long(srchfb) + srchfb.blockSize == long(srchfb.next)) {
							if (lh._nextFreeBlock == srchfb.next)
								lh._nextFreeBlock = srchfb;
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
							if (lh._nextFreeBlock == fb.next)
								lh._nextFreeBlock = fb;
							fb.blockSize += fb.next.blockSize;
							fb.next = fb.next.next;
							if (fb.next != null)
								fb.next.previous = fb;
						}
					}
					fb.enclosing = this;
					return validateAllocationChain(fb, false);
				}
			}
			printf("Block %p not in section.\n", fb);
			return false;
		}

		boolean validateAllocationChain(ref<FreeBlock> fb, boolean preCheck) {
			pointer<BlockHeader> endOfSection = pointer<BlockHeader>(long(this) + sectionSize);
			pointer<BlockHeader> startOfSection = pointer<BlockHeader>(pointer<SectionHeader>(this) + 1);
			boolean foundFreeBlock = !preCheck;		// The freed block should still be in the block list during pre-check,
													// but after the free list has been re-assembled, the freed block may
													// no lonfer exist.

			address lastFreeBlock;
			address nextBlock;
			for(ref<BlockHeader> bh = startOfSection; pointer<BlockHeader>(bh) < endOfSection; 
								bh = ref<BlockHeader>(nextBlock)) {
				if (bh == address(fb) && preCheck) {
					// This guy is the block to be freed. It's IN_USE_FLAG has been cleared already, but it won't be in
					// the free list yet.
					foundFreeBlock = true;
					lastFreeBlock = null;
				} else if ((bh.blockSize & ~IN_USE_FLAG) != 0) {
					lastFreeBlock = null;
				} else {
					if (lastFreeBlock != null) {
						printf("free(%p) %s: Two consecutive free blocks @ %p / %p\n", fb, preCheck ? "pre-check" : "post-check", lastFreeBlock, bh);
						return false;
					}
					lastFreeBlock = bh;
				}
				nextBlock = address(long(bh) + (bh.blockSize & ~IN_USE_FLAG));
				if (pointer<BlockHeader>(nextBlock) > endOfSection || pointer<BlockHeader>(nextBlock) < pointer<BlockHeader>(bh) + 1) {
					printf("free(%p) %s: Block %p has out of range size\n", fb, preCheck ? "pre-check" : "post-check", bh);
					return false;
				}
			}
			if (!foundFreeBlock) {
				printf("free(%p) %s: Block to be freed does not exist in block list.\n", fb, preCheck ? "pre-check" : "post-check", fb);
				return false;
			}
			return true;
		}

		boolean print(boolean showAllocated, ref<FreeBlock> nextFreeBlock) {
			boolean hasNextFreeBlock;
			printf("      Section @%p [%#x]", this, sectionSize);
			if (firstFreeBlock == null) {
				printf(" - No free space\n");
				return hasNextFreeBlock;
			}
			ref<BlockHeader> bh = ref<BlockHeader>(pointer<SectionHeader>(this) + 1);
			ref<FreeBlock> prev = null;
			if (firstFreeBlock != null && 
				(pointer<byte>(firstFreeBlock) < pointer<byte>(this) + SectionHeader.bytes || 
				 pointer<byte>(firstFreeBlock) >= pointer<byte>(this) + SECTION_LENGTH || 
				 (long(firstFreeBlock) & (BLOCK_ALIGNMENT - 1)) != 0)) {
				printf(" - Bad firstFreeBlock (%p)\n", firstFreeBlock);
				return hasNextFreeBlock;
			}
			printf("\n");
			
			for (ref<FreeBlock> fb = firstFreeBlock; fb != null; fb = fb.next) {
				bh = reportAllocatedBlocks(this, showAllocated, bh, fb);
				if (fb == nextFreeBlock)
					hasNextFreeBlock = true;
				printf("     %s @%p [%#x] free", fb == nextFreeBlock ? "->" : "  ", fb, fb.blockSize);
				if (fb.enclosing != this)
					printf(" ** bad enclosing pointer (%p) **", fb.enclosing);
				if (fb.previous != prev)
					printf(" ** bad previous pointer (%p) **", fb.previous);
				if (fb.next != null && 
					(pointer<byte>(fb) >= pointer<byte>(fb.next) || 
					 pointer<byte>(fb.next) >= pointer<byte>(this) + SECTION_LENGTH || 
					 (long(fb.next) & (BLOCK_ALIGNMENT - 1)) != 0)) {
					printf(" ** bad next pointer (%p) **\n", fb.next);
					break;
				}
				printf("\n");
				bh = ref<BlockHeader>(pointer<byte>(fb) + fb.blockSize);
				prev = fb;
			}
			reportAllocatedBlocks(this, showAllocated, bh, ref<FreeBlock>(pointer<byte>(this) + sectionSize));
			return hasNextFreeBlock;
		}
	}
	
	private static ref<BlockHeader> reportAllocatedBlocks(ref<SectionHeader> sh, boolean show, ref<BlockHeader> bh, ref<FreeBlock> fb) {
		int blocks = 0;
		while (address(bh) != address(fb)) {
			if (sh.isSectionEndSentinel(bh)) {
				printf("               SES %p\n", bh);
				if (bh.blockSize != (IN_USE_FLAG + SectionEndSentinel.bytes))
					printf("            ** <bad block length in SectionEndSentinel @%p [%#x]> **\n", bh, bh.blockSize);
				break;
			}
			printf("               IN USE %p: [%x] %p", bh, bh.blockSize - 1, bh.callStack);
			if ((bh.blockSize & IN_USE_FLAG) == 0) {
				printf("            ** @%p [%#x] is not an allocated block **\n", bh, bh.blockSize);
				break;
			}
			if (bh.blockSize < BLOCK_GRANULARITY) {
				printf("            ** <bad block length @%p [%#x]> **\n", bh, bh.blockSize);
				break;
			}
			bh = ref<BlockHeader>(long(bh) + bh.blockSize - IN_USE_FLAG);
			if (pointer<byte>(bh) > pointer<byte>(fb)) {
				printf("            ** <bad block list @%p> **\n", bh);
				break;
			}
			printf("\n");
			blocks++;
		}
		if (blocks > 0)
			printf("        - %d allocated blocks\n", blocks);
		return bh;
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
		delete process.stderr;
		process.stderr = null;
		delete process.stdin;
		process.stdin = null;
		delete process.stdout;
		process.stdout = null;
		currentHeap = &heap;		// heap is declared first, so it should still be alive when this destructor is called.
		if (_everUsed) {
			storage.setProcessStreams(true);
			printf("%,17d allocations\n%,17d frees\n", _allocations, _frees);
			if (_allocations > _frees)
				printf("%,17d leaked memory blocks\n", _allocations - _frees);
			else if (_frees > _allocations)
				printf("%,17d excess freed memory blocks\n", _frees - _allocations);
			else {
				for (ref<SectionHeader> sh = _sections; sh != null; sh = sh.next) {
					printf("Section %p[%x]\n", sh, sh.sectionSize);
					for (ref<FreeBlock> fb = sh.firstFreeBlock; fb != null; fb = fb.next)
						printf("    Free %p[%x] prev %p next %p\n", fb, fb.blockSize, fb.previous, fb.next);
				}
			}
			if (_sections != null) {
				printf("Leaks found!\n");
				ref<Writer> w = storage.createTextFile("leaks.txt");
				analyze(w);
				delete w;
			} else
				printf("No leaks found!\n");
		}
		thread.Thread.destruct();
	}
	
	public void clear() {
		
	}

	public address alloc(long n) {
		lock (_lock) {
			_allocations++;
			try {
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
				n = (framesOffset + frames * address.bytes + address.bytes + BLOCK_GRANULARITY - 1) & ~(BLOCK_GRANULARITY - 1);
		//		printf("    padded n = %#x\n", n);
		//		print();
				pointer<BlockHeader> bh;
				// Allocate a block.
				if (n > SECTION_DATA) {
					pointer<SectionHeader> nh = allocateSection(n + SectionHeader.bytes + SectionEndSentinel.bytes);
					if (nh == null)
						throw OutOfMemoryException(originalN);
					bh = pointer<BlockHeader>(nh + 1);
					nh.createSectionEndSentinel();
				} else {
					// if _nextFreeBlock is null, we have an empty free list and need to skip directly to allocating a new section.
					ref<FreeBlock> fb = _nextFreeBlock;
					if (fb != null) {
						do {
							if (fb.blockSize >= n) {
								
								// Should we consume the whole free block, or just split it?
								if (fb.blockSize >= n + BLOCK_GRANULARITY) {
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
									fb.blockSize = n;
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
								bh.blockSize += IN_USE_FLAG;
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
					nh.createSectionEndSentinel();
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
			} catch (Exception e) {
				leakHeap.print(false);
				throw e;
			}
		}
		return null;
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
		nh.sectionSize = sectionLength;
		nh.next = _sections;
		_sections = nh;
		return nh;
	}

	private void freeSection(ref<SectionHeader> sh) {
//		printf("freeSection %p\n", sh);
//		sh.print(null);
		if (sh.contains(_nextFreeBlock)) {
			_nextFreeBlock = null;
			for (ref<SectionHeader> s = _sections; s != null; s = s.next)
				if (s.firstFreeBlock != null) {
					_nextFreeBlock = s.firstFreeBlock;
					break;
				}
		}
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			C.free(sh);
		}
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
		long baseCodeAddress = long(runtime.image.codeAddress());
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
			_frees++;
			currentHeap = &heap;
			ref<FreeBlock> fb = ref<FreeBlock>(long(p) - BlockHeader.bytes);
			if ((fb.blockSize & IN_USE_FLAG) != 0) {
				fb.blockSize -= IN_USE_FLAG;
				for (ref<SectionHeader> sh = _sections; sh != null; sh = sh.next) {
					if (pointer<byte>(fb) > pointer<byte>(sh) && pointer<byte>(fb) < pointer<byte>(sh) + sh.sectionSize) {
						if (sh.free(this, fb) && 
							checkForEmptySection(sh)) {
							currentHeap = &leakHeap;
							return;
						} else
							break;
					}
				}
			} else
				printf("%s Block %p not in use\n%s", thread.currentThread().name(), fb, runtime.stackTrace());
		}
		leakHeap.print(false);
		throw CorruptHeapException(this, p);
	}
	/**
	 * @return true if the heap is contains the given SectionHeader, false if not.
	 */
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
			printf("Empty section %p not in list.\n", sh);
			return false;
		}
	}

	class CallSite {
		ref<CallSite> callers;
		ref<CallSite> next;
		long totalBytes;
		int hits;
		long ip;
		
		ref<CallSite> hit(address ip, long blockSize) {
			blockSize &= ~IN_USE_FLAG;
			for (ref<CallSite> cs = callers; cs != null; cs = cs.next) {
				if (cs.ip == long(ip)) {
					cs.totalBytes += blockSize;
					cs.hits++;
					return cs;
				}
			}
			ref<CallSite> cs = new CallSite;
			cs.next = callers;
			callers = cs;
			cs.ip = long(ip);
			cs.totalBytes += blockSize;
			cs.hits++;
			return cs;
		}
		
		void print(ref<Writer> output, int indent) {
			output.printf("%*.*c%d (%dKB)", indent, indent, ' ', hits, (totalBytes + 512) / 1024);
			output.flush();
			ref<CallSite> cs = callers;
			if (ip == 0)
				output.printf(" Total\n");
			else {
				long baseCodeAddress = runtime.image.codeAddress();
				if (ip != long(leakHeap._staticScopeReturnAddress))
					output.printf(" %s", runtime.image.formattedLocation(ip - 1, 0));
				while (cs != null && cs.next == null) {
					// We have only one call site, so merge it with this one...
					if (cs.ip != long(leakHeap._staticScopeReturnAddress))
						output.printf(" %s", runtime.image.formattedLocation(cs.ip - 1, 0));
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
		root.ip = 0;
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
	
	void print(boolean showAllocated) {
		if (_sections == null) {
			printf("      <empty>\n");
			return;
		}
		boolean hasNextFreeBlock = false;
		for (ref<SectionHeader> sh = _sections; sh != null; sh = sh.next) {
			boolean hnfb = sh.print(showAllocated, _nextFreeBlock);
			if (hnfb)
				hasNextFreeBlock = hnfb;
		}
		if (!hasNextFreeBlock)
			printf("** Could not find _nextFreeBlock: %p **\n", _nextFreeBlock);
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
