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
namespace parasol:memory;

import native:C;

class Allocator {
	public abstract void clear();
	
	public abstract address alloc(long n);
	
	public abstract void free(address p);
}

class NoReleasePool extends Allocator {
	private static long BLOCK_SIZE = 64 * 1024;

	private long _remaining;
	private pointer<byte> _freeSpace;
	private pointer<byte>[] _blocks;
	
	public NoReleasePool() {
	}

	~NoReleasePool() {
		clear();
	}
	
	public void clear() {
		for (int i = 0; i < _blocks.length(); i++)
			C.free(_blocks[i]);
		_blocks.clear();
	}
	
	public address alloc(long n) {
		n = (n + (address.bytes - 1)) & ~(address.bytes - 1);		// round up to align
		if (n >= BLOCK_SIZE) {
			pointer<byte> megaBlock = pointer<byte>(allocz(n));
			_blocks.append(megaBlock);
			return megaBlock;
		} else if (n >= _remaining) {
			pointer<byte> block = pointer<byte>(allocz(BLOCK_SIZE));
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
	
	public void free(address p) {
		// No release allocator just ignores deletes.
	}
}
