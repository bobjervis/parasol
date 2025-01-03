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
/**
 * @ignore - This namespace is for internal compiler implementation and is not intended for end-user services.
 */
namespace parasol:pxi;

import parasol:storage;
import parasol:runtime;
/**
 * Pxi: Parasol eXecutable Image
 * 
 * This format describes the platform-independent image format used to encode and distribute compiled
 * Parasol programs.  Most programs should not need this format, since the normal model is to run the
 * program source code directly.
 * 
 * This format is necessary, however, for distributing the Parasol compiler itself.
 * 
 * The file format is a binary data file consisting of one or more Sections.  Each section contains distinct
 * information and merely describes a discrete, contiguous region of the file.  A section table provides 
 * minimal information about the section: a section type, a file offset and length.  All other information
 * about the section is contained in the described region
 * 
 * A well-formed PXI file will have a section table where all section entries have 
 * 
 * 	- a non-zero section type.
 * 	- a region that lies within the file after the section table.
 * 	
 * The intention of this design is to distribute a Parasol runtime written in C++ that is re-compiled and
 * ported to a variety of environments.  A single vendor can include native binaries for as many target
 * architectures as they desire, and that a single PXI distribution can be run successfully on all operating
 * systems - only limited by the manner in which the vendor's code accesses operating system-specific features.
 * 
 * A Parasol program can be written to ignore the underlying operating system and target the portable runtime
 * components of the language.  Parasol code could also take advantage of underlying Windows or Linux features.
 *
 * The Parasol runtime will scan the section table and launch the first section that has the 'best' executable
 * code for the runtime.  For example, a Linux runtime on an Intel 64-bit machine could run X86_64 Linux
 * sections.  If the runtime is passed a command-line flag that declares a specific section type to use, then
 * that will be the one run.  By default, though, the runtime would launch the X86_64 binary.
 */
public class Pxi {
	private ref<Section>[] _sections;
	private string _filename;
	private storage.File _pxiFile;
	private SectionEntry[] _entries;

	public static ref<Pxi> load(string filename) {
		ref<Pxi> pxi = new Pxi(filename);
		if (pxi.read() == PxiStatus.SUCCESS)
			return pxi;
		else {
			delete pxi;
			return null;
		}
	}
	
	public static ref<Pxi> create(string filename) {
		return new Pxi(filename);
	}
	
	private Pxi(string filename) {
		_filename = filename;
	}
	
	~Pxi() {
		_pxiFile.close();
		_sections.deleteAll();
	}
	
	public void declareSection(ref<Section> s) {
		_sections.append(s);
	}
	
	public boolean write() {
		storage.File f;

		if (!f.create(_filename)) {
			printf("            FAIL: Could not create '%s'\n", _filename);
			return false;
		}
		PxiHeader header;
		header.sections = char(_sections.length());
		if (f.write(&header, header.bytes) < 0)
			return false;

		long offset = header.bytes + _sections.length() * SectionEntry.bytes;
		for (int i = 0; i < _sections.length(); i++) {
			ref<Section> s = _sections[i];
			SectionEntry se;
			se.sectionType = byte(int(s.sectionType()));
			se.offset = offset;
			se.length = s.length();
			offset += se.length;
			if (f.write(&se, se.bytes) < 0)
				return false;
		}
		for (int i = 0; i < _sections.length(); i++)
			if (!_sections[i].write(f))
				return false;
		return true;
	}

	PxiStatus read() {
		if (!_pxiFile.open(_filename))
			return PxiStatus.COULD_NOT_OPEN;
		PxiStatus status = read(_pxiFile);
		return status;
	}

	PxiStatus read(storage.File pxiFile) {
		PxiHeader header;
		if (pxiFile.read(&header, header.bytes) != header.bytes)
			return PxiStatus.FILE_HEADER_INCOMPLETE;
		if (header.magic != MAGIC_NUMBER)
			return PxiStatus.BAD_MAGIC;
		if (header.version == 0)
			return PxiStatus.VERSION_ZERO;
		_entries.resize(header.sections);
		int sectionTableSize = SectionEntry.bytes * header.sections;
		if (pxiFile.read(&_entries[0], sectionTableSize) != sectionTableSize)
			return PxiStatus.SECTION_TABLE_INCOMPLETE;
		else
			return PxiStatus.SUCCESS;
	}
	
	public int sectionCount() {
		return _entries.length();
	}
	
	public int bestSection() {
		int best = -1;
		int bestPriority = readerMap.length();
		for (int i = 0; i < _entries.length(); i++) {
			for (int j = 0; j < bestPriority; j++) {
				if (_entries[i].sectionType == int(readerMap[j].sectionType) &&
					readerMap[j].sectionReader != null) {
					best = i;
					bestPriority = j;
				}
			}
		}
		return best;
	}
	
	public ref<Section> readSection(int sectionIndex) {
		for (int j = 0; j < readerMap.length(); j++) {
			if (_entries[sectionIndex].sectionType == int(readerMap[j].sectionType) &&
				readerMap[j].sectionReader != null) {
				if (_pxiFile.seek(int(_entries[sectionIndex].offset), storage.Seek.START) < 0)
					return null;
				ReaderMap r = readerMap[j];
				return r.sectionReader(_pxiFile, _entries[sectionIndex].length);
			}
		}
		return null;
	}

	public boolean close() {
		return _pxiFile.close();
	}
	
	public runtime.Target sectionType(int i) {
		return runtime.Target(_entries[i].sectionType);
	}
	
	public SectionEntry entry(int i) {
		return _entries[i];
	}
}

public enum PxiStatus {
	SUCCESS,					// Operation was successful
	COULD_NOT_OPEN,				// Could not open the pxi file
	FILE_HEADER_INCOMPLETE,		// Could not read the full file header 
	BAD_MAGIC,					// File header had a bad magic number
	VERSION_ZERO,				// File header had a zero version number
	SECTION_TABLE_INCOMPLETE	// Could not read the full section entry table
	
}

public class Section {
	private runtime.Target _sectionType;
	
	public Section(runtime.Target st) {
		_sectionType = st;
	}
	
	public runtime.Target sectionType() {
		return _sectionType;
	}
	
	public abstract long length();
	
	public abstract boolean write(storage.File pxiFile);
}

unsigned MAGIC_NUMBER = unsigned(~0x50584920);
char CURRENT_VERSION = 1;
/*
 * All PXI files start with the PxiHeader. 
 */
@Layout("little-endian")
class PxiHeader {
	
	PxiHeader() {
		magic = MAGIC_NUMBER;
		version = CURRENT_VERSION;
	}
	
	unsigned magic;			// MAGIC_NUMBER
	char version;			// 
	char sections;			// The number of sections in the section table following the header
}
/*
 * Each Section Table entry uses this structure.
 */
@Layout("little-endian")
class SectionEntry {
	byte sectionType;		// A section type describing the data in the section.
	private byte _1;		// must be zero
	private char _2;		// must be zero
	private int _3;			// must be zero
	long offset;			// The offset of the section in the file, in bytes.
	long length;			// The length of the section, in bytes.
}

public runtime.Target sectionType(string name) {
	return sectionTypes[name];
}

public string sectionTypeName(runtime.Target st) {
	if (unsigned(int(st)) < unsigned(runtime.Target.MAX_TARGET))
		return string(st);
	else
		return "<unknown>";
}

private runtime.Target[string] sectionTypes = [
	"x86-64-lnx":	runtime.Target.X86_64_LNX_NEW,
	"x86-64-win":	runtime.Target.X86_64_WIN,
];


private class ReaderMap {
	public runtime.Target sectionType;
	public ref<Section>(storage.File, long) sectionReader;
	
//	ref<Section> sectionReader(file.File pxiFile, long length) {
//		return sectionReader(pxiFile, length);
//	}
}

private ReaderMap[] readerMap;
/**
 * Register a section reader to process the section when it is loaded.
 */
public boolean registerSectionReader(runtime.Target sectionType, ref<Section> sectionReader(storage.File pxiFile, long length)) {
	for (int i = 0; i < readerMap.length(); i++)
		if (readerMap[i].sectionType == sectionType)
			return false;
	ReaderMap rm;
	rm.sectionType = sectionType;
	rm.sectionReader = sectionReader;
	readerMap.append(rm);
	return true;
}
