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
namespace parasollanguage.org:debug.controller;

import parasol:log;
import parasol:memory;
import parasol:pxi;
import parasol:runtime;
import parasol:storage;
import parasol:text;

import native:linux;
import native:linux.elf;

import parasollanguage.org:debug.manager;

public class MemoryMap {
	ref<TracedProcess> _process;
	ref<MemorySegment>[] _segments;
	ref<File>[string] _files;
	ref<runtime.Image>[] _images;
	long _threadContextAddress;
	boolean _threadContextResolved;

	MemoryMap(ref<TracedProcess> p) {
		_process = p;
	}

	~MemoryMap() {
		_files.deleteAll();
		_segments.deleteAll();
	}

	public static ref<MemoryMap> load(ref<TracedProcess> p) {
		ref<Reader> r = storage.openTextFile("/proc/" + p.id() + "/maps");
		if (r == null)
			return null;

		int num = 1;
		mm := new MemoryMap(p);
		for (;; num++) {
			line := r.readLine();
			if (line == null)
				break;
			string[] words;
			int start = 0;
			while (start < line.length()) {
				int space = line.indexOf(' ', start);
				if (space < 0) {
					words.append(line.substr(start));
					break;
				} else {
					words.append(line.substr(start, space));
					do
						space++;
					while (space < line.length() && line[space] == ' ');
					start = space;
				}
			}
			if (words.length() < 5)
				continue;
			string label;
			if (words.length() == 5)
				label = null;
			else
				label = words[5];
			prot := words[1];
			string[] range;
			range = words[0].split('-');
			boolean success;
			long r_start, r_end, offset;
			(r_start, success) = long.parse(range[0], 16);
			if (!success)
				continue;
			(r_end, success) = long.parse(range[1], 16);
			if (!success)
				continue;
			(offset, success) = long.parse(words[2], 16);
			if (!success)
				continue;
			if (prot != "---p") {
				seg := new MemorySegment(r_start, r_end, prot, offset, label);
				mm._segments.append(seg);
				if (seg.filename != null && seg.filename[0] != '[') {
					if (!mm._files.contains(seg.filename))
						mm._files[seg.filename] = new File(seg.filename);
					f := mm._files[seg.filename];
					f.addSegment(seg);
					seg.file = f;
				}
			}
		}
		delete r;
		return mm;
	}

	public ref<MemorySegment> findSegment(long location) {
		for (i in _segments) {
			segment := _segments[i];
			if (segment.start <= location && location < segment.end)
				return segment;
		}
		return null;
	}
	/**
	 * Find a symbol defined for the given machine address.
	 *
	 * There are three possible outcomes:
	 *
	 *	- An ELF symbol was found for the address parameter.
	 *	- A Parasol source location was found for the address parameter.
	 *	- No symbol was found for the address paramter.
	 *
	 * @return The Elf64_Sym, if any, for any symbol found.
	 * @return If the first return value is not null, this is the ELF symbol name.
	 * For C++ symbols, this is a mangled name.
	 * If the first return value is null and this value is not null, it is a
	 * Parasol source location.
	 * If both the first and second return expressions are null, no symbols was found.
	 * @return If a ELF symbol was location, this is the relative offset within that symbol of the address
	 * parameter.
	 * If a Parasol source location was found, the offset is always 0.
	 * If neither was found, the value is an 'reason' for no symbol being found:
	 *
	 * </ul>
	 *		<li>-1 The ELF file named in the memory segment has no symbols.
	 *		<li>-2 The strings segment for the symbol table in the ELF file is invalid.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-3 The link from the symbol table names a non-strings section header.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-4 The offset of the symbol table's string section header is invalid.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-5 The offset of the symbol table's section header is invalid.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-6 None of the symbols defined in the ELF file's symbol table enclosed
	 *		the given address.
	 *		<li>-10 The address is not in mapped memory. No memory segment encloses this
	 *		address.
	 *		<li>-11 The memory map for this address does not name an ELF file.
	 *		This is likely to be because the segment is in a memory-mapped data file.
	 *		<li>-12 The address lies within an anonymous memory segment, like a thread stack,
	 *		or the heap.
	 *		<li>-13 The ELF file has no LOAD program table entries.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-14 The Parasol image this address lies within could not be copied into 
	 *		local memory.
	 */
	public ref<MemorySegment>, ref<elf.Elf64_Sym>, string, long findSymbol(long addr, long adjustment) {
//		logger.info("    _process.findSymbol(%x)", addr);
		seg := findSegment(addr);
		if (seg == null) {
//			logger.info("    Target address is not in mapped memory (%p)", addr);
			return null, null, null, -10;
		}
		if (seg.file != null) {
			e := seg.file.reader();
			if (e == null) {
//				logger.info("    Target address %x is in a non-ELF file, %s. (%s)", addr, seg.filename, string(seg.file.type()));
				return null, null, null, -11;
			}
			header := e.header();
			success := false;
			segAddress := seg.start;
			for (int i = 0; i < header.e_phnum; i++) {
				ph := e.programHeader(i);
				if (ph.p_type == 1) {
//					logger.info("    ph %d Elf vaddr is %p / target address %x", i, ph.p_vaddr, addr);
					success = true;
					baseAddress := segAddress - ph.p_vaddr;
//					logger.info("    baseAddress of symbols %p Target address %x segment relative offset %x", baseAddress, addr, 
//									addr - baseAddress);
					dynsym := e.dynsym();
					symtab := e.symtab();
/*
					if (symtab != null)
						logger.info("    Binary %s has symbols in segment %d", seg.filename, symtab);
					else if (dynsym != null)
						logger.info("    Binary %s has only dynammic link symbols in segment %d", seg.filename, dynsym);
					else
						logger.info("    Binary %s has no symbol information at all", seg.filename);
 */
					ref<elf.Elf64_Sym> sym;
					string name;
					long offset;
					(sym, name, offset) = e.findSymbol(addr - baseAddress);
					if (name != null) {
						s := storage.filename(seg.filename) + " " + name;
						name = s;
					} else {
						name = storage.filename(seg.filename);
						offset = addr - ph.p_vaddr;
					}
/*
					if (sym != null)
						/*logger.info*/printf("    Symbol found at %s+%d (%p)\n", name, offset, addr);
					else
						/*logger.info*/printf("    No symbol for address %p: cause %x\n", addr, offset);
 */
					return seg, sym, name, offset + adjustment;
				}
			}
//			logger.info("    File %s has no LOAD program header entries", seg.filename);
			return null, null, null, -13;
		} else if (seg.prot == Protections.ALL) {
//			logger.info("    Target address %p is possibly in a Parasol image (image offset = %x)", addr, addr - seg.start);
			image := seg.loadImage(_process.id());
			if (image == null)
				return null, null, null, -14;
			string filename;
			int lineno;
			string result;

			(filename, lineno) = image.getSourceLocation(addr);
			if (filename == null)
				result = null;
			else
				result.printf("%s %d", filename, lineno);
			return seg, null, result, 0;
/*
			addr = threadContextAddress();
			if (addr != 0) {
				long contents;
				boolean success;
				(contents, success) = tracer.peek(id(), addr);
				if (!success) {
					logger.error("    Could not peek at address %p for tid %d", addr, id());
					return null, null, -7;
				}
				logger.info("    contents = %p @ %p", contents, addr);
				long offset;
				(offset, success) = tracer.peek(id(), addr + 8);
				logger.info("    offset = %x", offset);
/*
				mm.print();
				runtime.ExecutionContext ec;
				if (!tracer.copy(id(), contents, &ec, ec.bytes)) {
					logger.error("    Could not copy data from pid %d @ %x [%x]", id(), contents, ec.bytes);
					return null, null, null, -14;
				}
				logger.info("stack top      %x", ec._stackTop);
				logger.info("exception      %x", ec._exception);
				logger.info("pxi header     %x", ec._pxiHeader);
				logger.info("image          %x", ec._image);
				logger.info("argv           %x", ec._argv);
				logger.info("argc           %d.", ec._argc);
				logger.info("thread         %x", ec._parasolThread);
				logger.info("runtime params %x", ec._runtimeParameters);
				logger.info("params count   %d.", ec._runtimeParametersCount);
*/
				return null, null, null, -8;
			}
			logger.error("    libparasol.so is inconsistent, does not contains parasol::ThreadContext::threadContextValue");
			return null, null, null, -9;
 */
		}
//		logger.error("    Target address is in an anonymous page (%p)", addr);
		return null, null, null, -12;
	}

	public long threadContextAddress() {
		if (!_threadContextResolved) {
			_threadContextResolved = true;
			f := findFile("libparasol.so", 0);
			if (f == null) {
				logger.warn("    This is not a Parasol program - there is no libparasol.so present");
				return 0;
			}
			e := f.reader();
			logger.info("    reader %p type %s", e, string(f.type()));
			sym := e.findSymbol("_ZN7parasol13ThreadContext19_threadContextValueE");
			if (sym == null) {
				logger.warn("    This is not a Parasol program - the libparasol.so does not have" +
							" parasol::ThreadContext::threadContextValue");
				return 0;
			}
			if ((sym.st_info & 0xf) != 6) {
				logger.warn("    This is not a Parasol program - parasol::ThreadContext::threadContextValue is not TLS");
				return 0;
			}
			if (sym.st_size != 8) {
				logger.warn("    This is not a Parasol program - parasol::ThreadContext::threadContextValue is not a pointer");
				return 0;
			}
			section := e.sectionHeader(sym.st_shndx);
			if (section == null) {
				logger.warn("    This is not a Parasol program - parasol::ThreadContext::threadContextValue has no section header");
				return 0;
			}
			// sym_addr == file-relative offset of this memory location
			//
			sym_addr := sym.st_value + section.sh_addr;
			logger.info("    parasol::ThreadContext::threadContextValue @ file address %p", sym_addr);
			for (int i = 0; ; i++) {
				ph := e.programHeader(i);
				if (ph == null)
					break;
				logger.debug("    ph vaddr = %p symbol %p end = %p", ph.p_vaddr, sym_addr, 
									ph.p_vaddr + ph.p_memsz);
				if (ph.p_type == 1 && 
					ph.p_vaddr <= sym_addr && sym_addr < ph.p_vaddr + ph.p_memsz &&
					(ph.p_flags & 0x7) == 6) {
					seg := f.segment(1);			// This should be the firsst 'data' segment, either a read-only
													// or read-write segment. 
					if (seg == null) {
						logger.error("    libparasol.so should have more than 1 memory segment");
						return 0;			
					}
					if (seg.prot == Protections.READ_ONLY ||
						seg.prot == Protections.READ_WRITE) {
						addr := seg.start + sym_addr - ph.p_vaddr;
						logger.info("    parasol::ThreadContext::threadContextValue @ address %p", addr);
						return addr;
					} else {
						logger.error("    libparasol.so should have a data segment second in the address space");
						return 0;
					}
				}
			}
			logger.error("libparasol.so is inconsistent, no program header contains parasol::ThreadContext::threadContextValue");
		}
		return _threadContextAddress;
	}

	public void print() {
		st := _process.state();
		isStopped := st == manager.ProcessState.STOPPED || st == manager.ProcessState.EXIT_CALLED;
		printf("Memory for process %d state %s\n", _process.id(), string(st));
		long prev_end = 0;

		threads := _process.getThreads();

		for (i in _segments) {
			segment := _segments[i];
			if (segment.start != prev_end)
				printf("\n");
			printf("[%3d] %16x - %16x [%12x] %s", i, segment.start, segment.end, segment.end - segment.start, string(segment.prot));
			if (segment.offset != 0)
				printf(" +%x", segment.offset);
			if (segment.filename != null)
				printf(" %s", segment.filename);
			printf("\n");
			if (isStopped) {
				string s(' ', 56);
				for (j in threads) {
					t := &threads[j];
					regs := t.registers();
					if (regs.rip >= segment.start && regs.rip < segment.end) {
						s.printf(" %d rip", t.tid());
					}
					if (regs.rsp >= segment.start && regs.rsp < segment.end) {
						s.printf(" %d rsp", t.tid());
					}
				}
				if (s.length() > 56)
					printf("%s\n", s);
			}
			prev_end = segment.end;
		}
	}

	void printFile(ref<TracedProcess> p, string pattern) {
		text.Matcher m(pattern);

		for (key in _files) {
			f := _files[key];
			if (m.containedIn(f.filename())) {
				f.print();
			}
		}
	}

	public ref<File> findFile(string pattern, int instance) {
		text.Matcher m(pattern);

		i := 0;
		for (key in _files) {
			f := _files[key];
			if (m.containedIn(f.filename())) {
				if (i == instance)
					return f;
				i++;
			}
		}
		return null;
	}
}

enum Protections {
	READ_ONLY,
	EXECUTE,
	READ_WRITE,
	READ_WRITE_SHARED,
	ALL
}

class MemorySegment {
	long start;
	long end;
	Protections prot;
	long offset;
	string filename;
	ref<File> file;
	address _imageData;
	ref<runtime.Image> _image;

	MemorySegment(long start, long end, string prot, long offset, string filename) {
		this.start = start;
		this.end = end;
		switch (prot) {
		case "r--p": this.prot = Protections.READ_ONLY; break;
		case "r-xp": this.prot = Protections.EXECUTE; break;
		case "rw-p": this.prot = Protections.READ_WRITE; break;
		case "rw-s": this.prot = Protections.READ_WRITE_SHARED; break;
		case "rwxp": this.prot = Protections.ALL; break;
		default:
			printf("Unexpected protections: %s\n", prot);
		}
		this.offset = offset;
		if (filename.length() > 0)
			this.filename = filename;
	}

	MemorySegment() {}

	~MemorySegment() {
		delete _imageData;
		delete _image;
	}

	public ref<runtime.Image> loadImage(int pid) {
		if (_image == null) {
			length := end - start;
			_imageData = memory.alloc(length);
			if (_imageData == null) {
				logger.error("    No memory for image");
				return null;
			}
	//		logger.info("Copying from %p for %x bytes", start, length);
			if (!tracer.copy(pid, start, _imageData, int(length))) {
				delete _imageData;
				_imageData = null;
				logger.error("    Couldn't copy image data @ %x from pid %d length %,d", pid, start, length);
				return null;
			}
			_image = new runtime.Image(start, _imageData, int(length));
	//		_image.printHeader(-1);
		}
		return _image;
	}

	ref<runtime.Image> image() {
		return _image;
	}

	public void print() {
		string s;
		s.printf("seg [%p-%p] %s", start, end, string(prot));
		if (offset != 0)
			s.printf(" %+d", offset);
		if (filename != null)
			s.printf(" file '%s'", filename);
		logger.info(s);
	}		
}

enum FileType {
	UNCLASSIFIED,
	ORDINARY,
	EXECUTABLE,
	SHARED_OBJECT,
	INACCESSIBLE
}

class File {
	string _filename;
	FileType _type;
	ref<MemorySegment>[] _segments;
	ref<elf.Reader> _reader;

	File(string filename) {
		_filename = filename;
	}

	~File() {
		delete _reader;
	}

	string filename() {
		return _filename;
	}

	FileType type() {
		return _type;
	}

	void addSegment(ref<MemorySegment> ms) {
		_segments.append(ms);
	}

	ref<MemorySegment> segment(int i) {
		if (i >= 0 && i < _segments.length())
			return _segments[i];
		else
			return null;
	}

	ref<elf.Reader> reader() {
		if (_reader == null) {
			if (_type == FileType.INACCESSIBLE)
				return null;
			_reader = elf.Reader.open(_filename);
			if (_reader == null) {
				printf("Could not open %s as an ELF file\n", _filename);
				_type = FileType.INACCESSIBLE;
				return _reader;
			}
			header := _reader.header();
			if (header.isValid()) {
				if (header.isExecutable())
					_type = FileType.EXECUTABLE;
				else if (header.isSharedObject())
					_type = FileType.SHARED_OBJECT;
			} else
				_type = FileType.ORDINARY;
		}
		return _reader;
	}

	void print() {
		elf.print(_filename);
	}
}

public class DebugStack extends runtime.VirtualStack {
	private ref<TracedThread> _thread;
	private long _pthread_create_address
	
	DebugStack(ref<TracedThread> t) {
		super(0, 0);
		_thread = t;
		regs := t.registers();
		mm := t.process().loadMemory();
		seg := mm.findSegment(regs.rsp);
		if (seg != null) {
			_stackBase = regs.rsp;
			_stackSize = int(seg.end - regs.rsp);
			printf("RSP = %p seg.end = %p\n", regs.rsp, seg.end)
		}
	}

	public long slot(long virtualAddress) {
		long contents;
		boolean success;

		(contents, success) = tracer.peek(_thread.process().id(), virtualAddress);
		if (success)
			return contents;
		else
			return 0;
	}

	public boolean isCode(long addr) {
		mm := _thread.process().loadMemory();
		seg := mm.findSegment(addr);
		if (seg == null)
			return false;
		return seg.prot == Protections.EXECUTE || seg.prot == Protections.ALL;
	}

	public boolean isParasolCode(long addr) {
		mm := _thread.process().loadMemory();
		seg := mm.findSegment(addr);
		if (seg == null)
			return false;
		return seg.prot == Protections.ALL;
	}


	public string, SlotType symbolAt(long addr, long adjustment) {
		mm := _thread.process().loadMemory();

		ref<MemorySegment> seg;
		ref<elf.Elf64_Sym> sym;
		string name;
		long offset;

		(seg, sym, name, offset) = mm.findSymbol(addr, adjustment);
		if (sym != null) {
			if (offset != 0) {
				if (name == "_ZN7parasol16ExecutionContext9runNativeEPFiPvE")
					return name, SlotType.MAIN
				else if (seg.filename.indexOf("libpthread-2.23.so") >= 0 && name == "start_thread")
					return name, SlotType.THREAD 
				if (offset < 0)
					name.printf("-%x", -offset);
				else
					name.printf("+%x", offset);
			}
		} else if (seg != null && seg.filename.endsWith("/libc.so.6")) {
			if (_pthread_create_address == 0) {
				_pthread_create_address = 1;					// Just so we don't repeat this on failure to find the symbol.
				e := seg.file.reader()
				if (e != null) {
					sym := e.findSymbol("pthread_create")
					if (sym != null) {
						_pthread_create_address = sym.st_value + seg.start - seg.offset
//						printf("pthread_create is at address %x \n", _pthread_create_address)
					}
				}
			}
			// Newer builds of libc include pthread_create but make start_thread a static, erasing it fom the .so dynsym table
			if (addr > _pthread_create_address - 0x300 && addr < _pthread_create_address)
				return "start_thread", SlotType.THREAD
		}
		return name, SlotType.DATA;
	}

	public int pid() {
		return _thread.process().id();
	}

	public int tid() {
		return _thread.tid();
	}
}



