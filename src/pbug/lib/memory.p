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
namespace parasollanguage.org:debug;

import parasol:log;
import parasol:memory;
import parasol:pxi;
import parasol:runtime;
import parasol:storage;
import parasol:text;

import native:linux;
import native:linux.elf;

public class MemoryMap {
	ref<TracedProcess> _process;
	ref<MemorySegment>[] _segments;
	ref<File>[string] _files;

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

	public void print() {
		st := _process.state();
		isStopped := st == ProcessState.STOPPED || st == ProcessState.EXIT_CALLED;
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
		if (_image != null)
			return _image;
		length := end - start;
		_imageData = memory.alloc(length);
		if (_imageData == null) {
			logger.error("    No memory for image");
			return null;
		}
//		logger.info("Copying from %p for %x bytes", start, length);
		if (!controller.copy(pid, start, _imageData, int(length))) {
			delete _imageData;
			_imageData = null;
			logger.error("    Couldn't copy image data from pid %d length %,d", pid, length);
			return null;
		}
		_image = new runtime.Image(start, _imageData, int(length));
//		_image.printHeader(-1);
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
	ref<ThreadInfo> _thread;

	DebugStack(ref<ThreadInfo> t) {
		super(0, 0);
		_thread = t;
		regs := t.registers();
		mm := t.process().loadMemory();
		seg := mm.findSegment(regs.rsp);
		if (seg != null) {
			_stackBase = regs.rsp;
			_stackSize = int(seg.end - regs.rsp);
		}
	}

	public long slot(long virtualAddress) {
		long contents;
		boolean success;

		(contents, success) = controller.peek(_thread.process().id(), virtualAddress);
		if (success)
			return contents;
		else
			return 0;
	}
}



