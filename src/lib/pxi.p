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
namespace parasol:pxi;

import parasol:file;
/*
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
	private file.File _pxiFile;
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
	}
	
	void declareSection(ref<Section> s) {
		_sections.append(s);
	}
	
	public boolean write() {
		file.File f = file.createBinaryFile(_filename);
		PxiHeader header;
		header.sections = char(_sections.length());
		f.write(&header, header.bytes);
		long offset = header.bytes + _sections.length() * SectionEntry.bytes;
		for (int i = 0; i < _sections.length(); i++) {
			ref<Section> s = _sections[i];
			SectionEntry se;
			se.sectionType = byte(int(s.sectionType()));
			se.offset = offset;
			se.length = s.length();
			offset += se.length;
			f.write(&se, se.bytes);
		}
		for (int i = 0; i < _sections.length(); i++)
			_sections[i].write(f);
		boolean result = f.hasError();
		return f.close() && !result;
	}

	PxiStatus read() {
		_pxiFile = file.openBinaryFile(_filename);
		if (!_pxiFile.opened())
			return PxiStatus.COULD_NOT_OPEN;
		PxiStatus status = read(_pxiFile);
		return status;
	}

	PxiStatus read(file.File pxiFile) {
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
	
	int sectionCount() {
		return _entries.length();
	}
	
	int bestSection() {
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
	
	ref<Section> readSection(int sectionIndex) {
		for (int j = 0; j < readerMap.length(); j++) {
			if (_entries[sectionIndex].sectionType == int(readerMap[j].sectionType) &&
				readerMap[j].sectionReader != null) {
				if (_pxiFile.seek(int(_entries[sectionIndex].offset), file.Seek.START) < 0)
					return null;
				ReaderMap r = readerMap[j];
				return r.sectionReader(_pxiFile, _entries[sectionIndex].length);
			}
		}
		return null;
	}

	boolean close() {
		return _pxiFile.close();
	}
	
	SectionType sectionType(int i) {
		return SectionType(_entries[i].sectionType);
	}
	
	SectionEntry entry(int i) {
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
	private SectionType _sectionType;
	
	public Section(SectionType st) {
		_sectionType = st;
	}
	
	public SectionType sectionType() {
		return _sectionType;
	}
	
	public abstract long length();
	
	public abstract void write(file.File pxiFile);
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

@Header("ST_")
public enum SectionType {
	ERROR,						// 0x00 A section given this type has unknown data at the section offset
	SOURCE,						// 0x01 the region is in POSIX IEEE P1003.1 USTar archive format.
	NOT_USED_2,					// 0x02 Parasol byte codes
	X86_64_LNX,					// 0x03 Parasol 64-bit for Intel and AMD processors, Linux calling conventions.
	X86_64_WIN,					// 0x04 Parasol 64-bit for Intel and AMD processors, Windows calling conventions.
	FILLER
}

public SectionType sectionType(string name) {
	return sectionTypes[name];
}

public string sectionTypeName(SectionType st) {
	if (unsigned(int(st)) < unsigned(SectionType.FILLER))
		return string(st);
	else
		return "<unknown>";
}

private SectionType[string] sectionTypes = [
	"x86-64-lnx":	SectionType.X86_64_LNX,
	"x86-64-win":	SectionType.X86_64_WIN,
];


private class ReaderMap {
	public SectionType sectionType;
	public ref<Section> sectionReader(file.File pxiFile, long length);
	
//	ref<Section> sectionReader(file.File pxiFile, long length) {
//		return sectionReader(pxiFile, length);
//	}
}

private ReaderMap[] readerMap;
/**
 * Register a section reader to process the section when it is loaded.
 */
public boolean registerSectionReader(SectionType sectionType, ref<Section> sectionReader(file.File pxiFile, long length)) {
	for (int i = 0; i < readerMap.length(); i++)
		if (readerMap[i].sectionType == sectionType)
			return false;
	ReaderMap rm;
	rm.sectionType = sectionType;
	rm.sectionReader = sectionReader;
	readerMap.append(rm);
	return true;
}
