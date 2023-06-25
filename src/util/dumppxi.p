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
import parasol:pxi;
import parasol:storage;
import parasol:process;
import parasol:runtime;
import parasol:x86_64;

class DumpPxiCommand extends process.Command {
	public DumpPxiCommand() {
		finalArguments(1, int.MAX_VALUE, "<file> ...");
		description("Produce a formatted dump of a pxi file.");
		sectionOption = stringOption('s', "section",
				"Include detailed dump of this section type.");
		asmOption = stringOption('a', "asm",
				"Include an assembly listing of the code in the dump of the named section type.");
		relocationsOption = booleanOption('r', "reloc",
				"when -s or -a are also present, include the relocations in the output for the section");
		helpOption('?', "help", "Display this help.");
	}
	
	ref<process.Option<string>> sectionOption;
	ref<process.Option<string>> asmOption;
	ref<process.Option<boolean>> relocationsOption;
}

DumpPxiCommand command;

runtime.Target verbose;
runtime.Target assembly;

int main(string[] args) {
	if (!command.parse(args))
		command.help();
	string[] files = command.finalArguments();
	if (command.sectionOption.set()) {
		verbose = pxi.sectionType(command.sectionOption.value);
		if (verbose == runtime.Target.ERROR) {
			printf("Invalid section type: %s\n", command.sectionOption.value);
			return 1;
		}
	}
	if (command.asmOption.set()) {
		assembly = pxi.sectionType(command.asmOption.value);
		if (assembly == runtime.Target.ERROR) {
			printf("Invalid section type for assembly: %s\n", command.asmOption.value);
			return 1;
		}
	}
	boolean anyFailed = false;
	pxi.registerSectionReader(runtime.Target.X86_64_LNX, x86_64NextReader);
	pxi.registerSectionReader(runtime.Target.X86_64_LNX_SRC, x86_64NextReader);
	pxi.registerSectionReader(runtime.Target.X86_64_WIN, x86_64NextReader);
	for (int i = 0; i < files.length(); i++)
		if (!dump(files[i]))
			anyFailed = true;
	if (anyFailed)
		return 1;
	else
		return 0;
}

boolean dump(string filename) {
	ref<pxi.Pxi> p = pxi.Pxi.load(filename);
	if (p == null) {
		printf("Could not open %s\n", filename);
		return false;
	}
	printf("File %s: %d sections\n", filename, p.sectionCount());
	int best = p.bestSection();
	for (int i = 0; i < p.sectionCount(); i++) {
		pxi.SectionEntry entry = p.entry(i);
		runtime.Target st = p.sectionType(i);
		string label;
		label.printf("[%d]", i);
		string type;
		type.printf("%s (%d)", pxi.sectionTypeName(st), int(st));
		string offset;
		offset.printf("@%x", entry.offset);
		printf("  %c %4s %16s %10s [%d bytes]\n", i == best ? '*' : ' ', label, type, offset, entry.length);
		if (verbose == st || assembly == st || (command.relocationsOption.set() && st == runtime.Target.X86_64_LNX_SRC)) {
			ref<pxi.Section> s = p.readSection(i);
			if (s == null)
				printf("      <<- ERROR ->>\n");
		}
	}
	p.close();
	return true;
}


ref<pxi.Section> x86_64NextReader(storage.File pxiFile, long length) {
	pxi.X86_64SectionHeader header;
	
	if (pxiFile.read(&header, header.bytes) != header.bytes) {
		printf("          Could not read x86-64 section header\n");
		return null;
	}
	long imageOffset = pxiFile.tell();
	byte[] memory;

	memory.resize(int(length - header.bytes));
	long actual = pxiFile.read(&memory);
	if (actual != memory.length()) {
		printf("Could not read %d bytes from the indicated section\n", length);
		return null;
	}
	if (assembly != runtime.Target.ERROR) {
		if (actual != memory.length())
			return null;
		runtime.Arena arena();
		x86_64.Disassembler d(&arena, 0, int(actual), &memory[0], &header);
//		d.setDataMap(&_dataMap[0][0], _dataMap[0].length());
//		d.setFunctionMap(&_functionMap);
//		d.setOrdinalMap(&_ordinalMap);
//		d.setSourceLocations(&_sourceLocations[0], _sourceLocations.length());
//		d.setVtablesClasses(&_vtables);
		if (!d.disassemble()) {
			printf("Disassembly FAILED\n");
		}
	} else if (verbose != runtime.Target.ERROR)
		x86_64.printHeader(&header, imageOffset);
	if (command.relocationsOption.set()) {
		if (actual != memory.length())
			return null;
		if (header.relocationCount > 0) {
			printf("\nPXI Fixups:\n");
			pointer<int> f = pointer<int>(&memory[0] + header.relocationOffset);
			for (int i = 0; i < header.relocationCount; i++)
				printf("    [%d] %#x\n", i, f[i]);
		}
	}
	return new PlaceHolder();
}

class PlaceHolder extends pxi.Section {
	PlaceHolder() {
		super(runtime.Target.MAX_TARGET);
	}
	
	public long length() {
		return 0;
	}
	
	public void write(storage.File pxiFile) {
	}
}
