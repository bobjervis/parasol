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
 * This namespace includes facilities to read ELF file binaries used for Linux
 * and UNIX executable files.
 */
namespace native:linux.elf;

import parasol:storage;

import native:C;

public class Reader {
	pointer<byte> _baseAddress;
	long _size;
	ref<Elf64_Ehdr> _header;
	pointer<byte> _programHeaderTable;
	pointer<byte> _sectionHeaderTable;
	ref<Elf64_Shdr> _dynsym;
	ref<Elf64_Shdr> _symtab;

	public Reader(address contents, long size) {
		_baseAddress = pointer<byte>(contents);
		_header = ref<Elf64_Ehdr>(contents);
		_programHeaderTable = _baseAddress + _header.e_phoff;
		_sectionHeaderTable = _baseAddress + _header.e_shoff;
		_size = size;
		_dynsym = null;
		_symtab = null;
		for (int i = 1; i < _header.e_shnum; i++) {
			sh := sectionHeader(i);
			if (sh.sh_type == 11)
				_dynsym = sh;
			else if (sh.sh_type == 2)
				_symtab = sh;
		}
	}

	~Reader() {
		storage.unmap(_baseAddress, _size);
	}

	public static ref<Reader> open(string path) {
		address contents;
		long size;

		(contents, size) = storage.memoryMap(path, storage.AccessFlags.READ, 0, long.MAX_VALUE);
		if (contents == null)
			return null;
		else
			return new Reader(contents, size);
	}

	public ref<Elf64_Ehdr> header() {
		return _header;
	}

	public long size() {
		return _size;
	}

	public ref<Elf64_Shdr> dynsym() {
		return _dynsym;
	}

	public ref<Elf64_Shdr> symtab() {
		return _symtab;
	}

	public ref<Elf64_Phdr> programHeader(int i) {
		if (i < 0 || i >= _header.e_phnum)
			return null;
		else
			return ref<Elf64_Phdr>(_programHeaderTable + i * _header.e_phentsize);
	}

	public ref<Elf64_Shdr> sectionHeader(int i) {
		if (i < 0 || i >= _header.e_shnum)
			return null;
		else
			return ref<Elf64_Shdr>(_sectionHeaderTable + i * _header.e_shentsize);
	}

	public string name(long x) {
		sh := sectionHeader(_header.e_shstrndx);
		cp := _baseAddress + sh.sh_offset + x;
		return string(cp);
	}

	public pointer<byte> at(long offset) {
		if (offset < 0 || offset >= _size)
			return null;
		else
			return _baseAddress + offset;
	}
	/**
	 * Find a symbol by file-relative address
	 *
	 * An elf file defines, through its program header table, a set of LOAD segments,
	 * each of which defines a range of file-relative addresses. Every symbol is defined
	 * relative to one or another of those segments.
	 *
	 * @param addr The address of the symbol relative to this elf file's virtual address
	 * values.
	 *
	 * @return A pointer to the symbol entry that encloses this address, or null if no symbol matches.
	 * @return The name of the symbol returned in the first return value, or null if that value is null.
	 * @return An offset of where in the returned symbol the parameter value is located.
	 * If the first return value is null, this value is a non-positive number indicating the cause of the
	 * failure.
	 * A value of zero (when the first return value is null) indicates a simple miss, the name wasn't found.
	 * Most of the negative return values indicates some detected level of corruption in the elf file.
	 */
	public ref<Elf64_Sym>, string, long findSymbol(long addr) {
		ref<Elf64_Sym> sym;
		string name;
		long offset;
		if (_symtab != null) {
			(sym, name, offset) = findIn(addr, _symtab);
			if (name != null)
				return sym, name, offset;
		} 
		if (_dynsym != null)
			return findIn(addr, _dynsym);
		return null, null, -6;
	}

	private ref<Elf64_Sym>, string, long findIn(long addr, ref<Elf64_Shdr> header) {
		strings := sectionHeader(header.sh_link);
		if (strings == null)
			return null, null, -2;
		if (strings.sh_type != 3)
			return null, null, -3;
		stringsBase := at(strings.sh_offset);
		if (stringsBase == null)
			return null, null, -4;
		symbolCount := header.sh_size / header.sh_entsize;
		symbolsBase := at(header.sh_offset);
		if (symbolsBase == null)
			return null, null, -5;
		for (int i = 1; i < symbolCount; i++) {
			symbolAddr := symbolsBase + i * header.sh_entsize;
			sym := ref<Elf64_Sym>(symbolAddr);
			if (addr < sym.st_value)
				continue;
			if (addr >= sym.st_value + sym.st_size)
				continue;
			if (sym.st_shndx == 0)
				continue;							// This must be an external reference, not a definition
			info := typeOf(sym.st_info);
			if (info != 1 && info != 2 && info != 6)
				continue;							// This symbol is neither a function, an object nor a TLS object.
			name := stringsBase + sym.st_name;
			return sym, string(name), addr - sym.st_value;
		}
		return null, null, -6;
	}

	public ref<Elf64_Sym> findSymbol(string name) {
		if (_symtab != null)
			symtab := _symtab;
		else if (_dynsym != null)
			symtab = _dynsym;
		if (symtab == null)
			return null;
		strings := sectionHeader(symtab.sh_link);
		if (strings == null)
			return null;
		if (strings.sh_type != 3)
			return null;
		stringsBase := at(strings.sh_offset);
		if (stringsBase == null)
			return null;
		symbolCount := symtab.sh_size / symtab.sh_entsize;
		symbolsBase := at(symtab.sh_offset);
		if (symbolsBase == null)
			return null;
		for (int i = 1; i < symbolCount; i++) {
			symbolAddr := symbolsBase + i * symtab.sh_entsize;
			sym := ref<Elf64_Sym>(symbolAddr);
			candidate := stringsBase + sym.st_name;
			if (C.strcmp(candidate, name.c_str()) == 0)
				return sym;
		}
		return null;
	}
}

public class Elf64_Ehdr {
	//span<byte, 16> e_ident; This is what it should be.
	public long e_ident0;
	public long e_ident1;
	public char e_type;
	public char e_machine;
	public unsigned e_version;
	public long e_entry;			// technically, this isn't an 'address' because
									// it refers to an address within the executable
									// image when this file is run, not an address in 
									// the image of the program reading this data.
	public long e_phoff;
	public long e_shoff;
	public unsigned e_flags;
	public char e_ehsize;
	public char e_phentsize;
	public char e_phnum;
	public char e_shentsize;
	public char e_shnum;
	public char e_shstrndx;

	/**
	 * After reading the initial bytes of an ELF format file into this class,
	 * calling this method will identify whether the file is well formed.
	 *
	 * @return True if the header has a valid magic number, is marked as a valid
	 * 64-bit processor, is encoded with little-endian data, has the current version,
	 * targets the x86-64
	 * machine, has the correct file version. This returns false if any of these
	 * conditions are not met.
	 */
	public boolean isValid() {
		return (e_ident0 & 0xffffffffffffff) == 0x10102464c457f && e_machine == 62 && e_version == 1;
	}
	/**
	 * Identify whether this is an executable ELF file.
	 *
	 * @return true if the file is an executable file, false otherwise.
	 */
	public boolean isExecutable() {
		return e_type == 2;
	}
	/**
	 * Identify whether this is a shared object ELF file.
	 *
	 * @return true if the file is a shared object file, false otherwise.
	 */
	public boolean isSharedObject() {
		return e_type == 3;
	}

	public byte osABI() {
		return byte(e_ident0 >> 56);
	}
}

public class Elf64_Phdr {
	public unsigned p_type;
	public unsigned p_flags;
	public long p_offset;
	public long p_vaddr;
	public long p_paddr;
	public long p_filesz;
	public long p_memsz;
	public long p_align;
}

public class Elf64_Shdr {
	public unsigned sh_name;                /* Section name (string tbl index) */
	public unsigned sh_type;                /* Section type */
	public long     sh_flags;               /* Section flags */
	public long     sh_addr;                /* Section virtual addr at execution */
	public long     sh_offset;              /* Section file offset */
	public long     sh_size;                /* Section size in bytes */
	public int      sh_link;                /* Link to another section */
	public unsigned sh_info;                /* Additional section information */
	public long     sh_addralign;           /* Section alignment */
	public long     sh_entsize;             /* Entry size if section holds table */
}

public class Elf64_Sym {
	public unsigned st_name;                /* Symbol name (string tbl index) */
	public byte st_info;                	/* Symbol type and binding */
	public byte st_other;               	/* Symbol visibility */
	public char st_shndx;               	/* Section index */
	public long st_value;               	/* Symbol value */
	public long st_size;                	/* Symbol size */
}

public void print(string filename) {
	e := Reader.open(filename);
	if (e == null) {
		printf("Could not open %s as an ELF file\n", filename);
		return;
	}
	header := e.header();
	if (!header.isValid()) {
		printf("    Not an ELF file\n");
		return;
	}
	type := "unknown";
	if (header.isExecutable())
		type = "executable";
	else if (header.isSharedObject())
		type = "shared object";
	printf("File %s %s\n", filename, type);
	printf("    Confirmed as valid elf header:\n");
	printf("        os ABI               %d.\n", header.osABI());
	printf("        type                 %d.\n", header.e_type);
	printf("        machine              %d.\n", header.e_machine);
	printf("        version              %d.\n", header.e_version);
	printf("        entry point          %p\n", header.e_entry);
	printf("        program header table %x\n", header.e_phoff);
	printf("        section header table %x\n", header.e_shoff);
	printf("        flags                %x\n", header.e_flags);

	printf("\nProgram Header Table\n\n");
	for (int i = 0; i < header.e_phnum; i++) {
		ph := e.programHeader(i);
		printf("    ph [%3d]: %-12s (%s)", i, programHeaderType(ph.p_type), perms(ph.p_flags));
		if ((ph.p_flags & unsigned(~7)) != 0)
			printf(" flags %x", ph.p_flags & unsigned(~7));
		printf(" off %x addr %x size (%x/%x)@%x\n", ph.p_offset, ph.p_vaddr, ph.p_filesz, ph.p_memsz, ph.p_align);
		if (ph.p_vaddr != ph.p_paddr)
			printf("        paddr  %x\n", ph.p_paddr);
	}

	printf("\nSection Header Table\n\n");
	for (int i = 1; i < header.e_shnum; i++) {
		sh := e.sectionHeader(i);
		printf(" %6d: %-20s %-12s", i, e.name(sh.sh_name), sectionType(sh.sh_type));
		if (sh.sh_flags != 0)
			printf("%s", sectionFlags(sh.sh_flags));
		if (sh.sh_addr != 0)
			printf(" addr %p @%x", sh.sh_addr, sh.sh_addralign);
		if (sh.sh_offset != sh.sh_addr)
			printf(" offset %x", sh.sh_offset);
		printf(" size %d.", sh.sh_size);
		if (sh.sh_link != 0)
			printf(" link [%d]", sh.sh_link);
		if (sh.sh_info != 0)
			printf(" info %x", sh.sh_info);
		if (sh.sh_entsize != 0)
			printf(" entsize %d.", sh.sh_entsize);
		printf("\n");
	}

	for (int i = 0; i < header.e_shnum; i++) {
		sh := e.sectionHeader(i);
		if (sh.sh_type == 11)
			dumpSymbols("Dynamic Link Symbol Table", sh, e.sectionHeader(sh.sh_link), e);
		else if (sh.sh_type == 2)
			dumpSymbols("Symbol Table", sh, e.sectionHeader(sh.sh_link), e);
	}
	delete e;
}


void dumpSymbols(string caption, ref<Elf64_Shdr> symbols, ref<Elf64_Shdr> strings, ref<Reader> e) {
	if (strings == null) {
		printf("The %s section does not refer to a valid section header\n", caption);
		return;
	}
	if (strings.sh_type != 3) {
		printf("The %s section does not refer to a string table section header\n", caption);
		return;
	}
	stringsBase := e.at(strings.sh_offset);
	if (stringsBase == null) {
		printf("The %s section refers to a string table with an invalid file offset\n", caption);
		return;
	}
	symbolCount := symbols.sh_size / symbols.sh_entsize;
	symbolsBase := e.at(symbols.sh_offset);
	if (symbolsBase == null) {
		printf("The %s section has an invalid file offset\n", caption);
		return;
	}
	printf("\n%s\n\n", caption);
	for (int i = 1; i < symbolCount; i++) {
		symbolAddr := symbolsBase + i * symbols.sh_entsize;
		sym := ref<Elf64_Sym>(symbolAddr);
		name := string(stringsBase + sym.st_name);
		printf("     %-16s", name);
		if (sym.st_shndx != 0)
			printf(" @%d:%p", sym.st_shndx, sym.st_value);
		if (sym.st_size != 0)
			printf(" sz %x", sym.st_size);
		visibility := sym.st_other & 3;
		if (visibility != 0)
			printf(" %s", visibilityLabel(visibility));
		printf(" %s %s\n", bindInfo(sym.st_info), symInfo(sym.st_info));
	}
}

unsigned typeOf(unsigned info) {
	return info & 0xf;
}

unsigned bindOf(unsigned info) {
	return info >> 4;
}

string sectionType(unsigned type) {
	if (SectionType[type] != null)
		return SectionType[type];
	else {
		string s;

		s.printf("%x", type);
		return s;
	}
}

string sectionFlags(long f) {
	string s;
	if ((f & 1) != 0)
		s.append(" write");				/* Writable */
	if ((f & 2) != 0)
		s.append(" alloc");				/* Occupies memory during execution */
	if ((f & 4) != 0)
		s.append(" exec");				/* Executable */
	if ((f & 16) != 0)
		s.append(" merge");				/* Might be merged */
	if ((f & 32) != 0)
		s.append(" strings");			/* Contains nul-terminated strings */
	if ((f & 64) != 0)
		s.append(" link");				/* `sh_info' contains SHT index */
	if ((f & 128) != 0)
		s.append(" order");				/* Preserve order after combining */
	if ((f & 256) != 0)
		s.append(" nonstd");			/* Non-standard OS specific handling
                                           required */
	if ((f & 512) != 0)
		s.append(" group");				/* Section is member of a group.  */
	if ((f & 1024) != 0)
		s.append(" tls");				/* Section hold thread-local data.  */
	if ((f & 2048) != 0)
		s.append(" compressed");		/* Section with compressed data. */
	if ((f & (1 << 30)) != 0)
		s.append(" solaris");			/* Special ordering requirement
                                           (Solaris).  */
	if ((f & (1 << 31)) != 0)
		s.append(" exclude");			/* Section is excluded unless
                                           referenced or allocated (Solaris).*/
	return s;
}

string programHeaderType(unsigned type) {
	if (ProgramHeaderType[type] != null)
		return ProgramHeaderType[type];
	else {
		string s;
		s.printf("%x", type);
		return s;
	}
}

string symInfo(unsigned info) {
	info = typeOf(info);
	if (SymbolInfo[info] != null)
		return SymbolInfo[info];
	else {
		string s;
		s.printf("%x", info);
		return s;
	}
}

string bindInfo(unsigned info) {
	info = bindOf(info);
	if (BindInfo[info] != null)
		return BindInfo[info];
	else {
		string s;
		s.printf("%x", info);
		return s;
	}
}

string visibilityLabel(int visibility) {
	if (Visibility[visibility] != null)
		return Visibility[visibility];
	else {
		string s;
		s.printf("%x", visibility);
		return s;
	}
}

string perms(unsigned pflags) {
	string result;
	if ((pflags & 0x4) != 0)
		result = "r";
	else
		result = "";
	if ((pflags & 0x2) != 0)
		result += "w";
	if ((pflags & 0x1) != 0)
		result += "x";
	return result;
}

public map<string, unsigned> ProgramHeaderType;
	ProgramHeaderType[0] = "PT_NULL";                    /* Program header table entry unused */
	ProgramHeaderType[1] = "PT_LOAD";                    /* Loadable program segment */
	ProgramHeaderType[2] = "PT_DYNAMIC";                 /* Dynamic linking information */
	ProgramHeaderType[3] = "PT_INTERP";                  /* Program interpreter */
	ProgramHeaderType[4] = "PT_NOTE";                    /* Auxiliary information */
	ProgramHeaderType[5] = "PT_SHLIB";                   /* Reserved */
	ProgramHeaderType[6] = "PT_PHDR";                    /* Entry for header table itself */
	ProgramHeaderType[7] = "PT_TLS";                     /* Thread-local storage segment */
	ProgramHeaderType[8] = "PT_NUM";                     /* Number of defined types */
	ProgramHeaderType[0x60000000] = "PT_GNU_EH_FRAME";   /* GCC .eh_frame_hdr segment */
	ProgramHeaderType[0x6474e551] = "PT_GNU_STACK";      /* Indicates stack executability */
	ProgramHeaderType[0x6474e552] = "PT_GNU_RELRO";      /* Read-only after relocation */
	ProgramHeaderType[0x6ffffffa] = "PT_SUNWBSS";        /* Sun Specific segment */
	ProgramHeaderType[0x6ffffffb] = "PT_SUNWSTACK";      /* Stack segment */

public map<string, unsigned> SectionType;
	SectionType[0] = "null";				 /* Unused */
	SectionType[1] = "progbits";             /* Program data */
	SectionType[2] = "symtab";               /* Symbol table */
	SectionType[3] = "strtab";               /* String table */
	SectionType[4] = "reloc/a";              /* Relocation entries with addends */
	SectionType[5] = "hash";                 /* Relocation entries with addends */
	SectionType[6] = "dynamic";              /* Dynamic linking information */
	SectionType[7] = "note";                 /* Notes */
	SectionType[8] = "nobits";               /* Program space with no data (bss) */
/*
#define SHT_REL           9             /* Relocation entries, no addends */
#define SHT_SHLIB         10            /* Reserved */
*/ 
	SectionType[11] = "dynsym";              /* Dynamic linker symbol table */

	SectionType[14] = "init_array";          /* Array of constructors */
	SectionType[15] = "fini_array";          /* Array of destructors */
/*
#define SHT_PREINIT_ARRAY 16            /* Array of pre-constructors */
#define SHT_GROUP         17            /* Section group */
#define SHT_SYMTAB_SHNDX  18            /* Extended section indeces */
#define SHT_NUM           19            /* Number of defined types.  */
#define SHT_LOOS          0x60000000    /* Start OS-specific.  */
#define SHT_GNU_ATTRIBUTES 0x6ffffff5   /* Object attributes.  */
*/
	SectionType[0x6ffffff6] = "gnu_hash";    /* GNU-style hash table.  */
/*
#define SHT_GNU_LIBLIST   0x6ffffff7    /* Prelink library list */
#define SHT_CHECKSUM      0x6ffffff8    /* Checksum for DSO content.  */
#define SHT_LOSUNW        0x6ffffffa    /* Sun-specific low bound.  */
#define SHT_SUNW_move     0x6ffffffa
#define SHT_SUNW_COMDAT   0x6ffffffb
#define SHT_SUNW_syminfo  0x6ffffffc
 */
	SectionType[0x6ffffffd] = "gnu_verdef";  /* Version needs section.  */
	SectionType[0x6ffffffe] = "gnu_verneed"; /* Version needs section.  */
	SectionType[0x6fffffff] = "gnu_versym";  /* Version symbol table.  */

public map<string, unsigned> SymbolInfo;
	SymbolInfo[0] = "NOTYPE";		/* Symbol type is unspecified */
	SymbolInfo[1] = "OBJECT";		/* Symbol is a data object */
	SymbolInfo[2] = "FUNC"; 		/* Symbol is a code object */
	SymbolInfo[3] = "SECTION";		/* Symbol associated with a section */
	SymbolInfo[4] = "FILE";			/* Symbol's name is file name */
	SymbolInfo[5] = "COMMON";		/* Symbol is a common data object */
	SymbolInfo[6] = "TLS";			/* Symbol is thread-local data object*/
	SymbolInfo[7] = "NUM";			/* Number of defined types.  */
	SymbolInfo[10] = "GNU_IFUNC";	/* Symbol is indirect code object */

public map<string, unsigned> BindInfo;
	BindInfo[0] = "local";          /* Local symbol */
	BindInfo[1] = "global";         /* Global symbol */
	BindInfo[2] = "weak";           /* Weak symbol */
	BindInfo[3] = "STB_NUM";        /* Number of defined types.  */
	BindInfo[10] = "STB_GNU_UNIQUE";/* Unique symbol.  */


/* Symbol visibility specification encoded in the st_other field.  */
public map<string, int> Visibility;
	Visibility[0] = "default";		/* Default symbol visibility rules */
	Visibility[1] = "internal";		/* Processor specific hidden class */
	Visibility[2] = "hidden";		/* Sym unavailable in other modules */
	Visibility[3] = "protected";	/* Not preemptible, not exported */

