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
namespace parasollanguage.org:debug.symbols;

import parasol:storage;
import native:linux.elf;
import native:linux;

public class ElfFile {
	pointer<byte> _fileAddress;
	long _fileSize;

	ElfFile(pointer<byte> fileAddress, long fileSize) {
		_fileAddress = fileAddress;
		_fileSize = fileSize;
	}

	~ElfFile() {
		linux.munmap(_fileAddress, _fileSize);
	}

	public static ref<ElfFile> load(string path) {
		address location;
		long length;
		(location, length) = storage.memoryMap(path, storage.AccessFlags.READ, 0, long.MAX_VALUE);
		if (location == null || length < elf.Elf64_Ehdr.bytes)
			return null;
 
		hdr := ref<elf.Elf64_Ehdr>(location);
		if (hdr.isValid() && (hdr.isExecutable() || hdr.isSharedObject()))
			return new ElfFile(pointer<byte>(location), length);
		else
			return null;
	}

	ref<elf.Elf64_Ehdr> elfHeader() {
		return ref<elf.Elf64_Ehdr>(_fileAddress);
	}
}

