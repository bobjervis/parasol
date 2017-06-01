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
import parasol:file;
import parasol:commandLine;
import parasol:x86_64;

class DumpPxiCommand extends commandLine.Command {
	public DumpPxiCommand() {
		finalArguments(1, int.MAX_VALUE, "<file> ...");
		description("Produce a formatted dump of a pxi file.");
		sectionArgument = stringArgument('s', "section",
				"Include detailed dump of this section type.");
		helpArgument('?', "help", "Display this help.");
	}
	
	ref<commandLine.Argument<string>> sectionArgument;
}

DumpPxiCommand command;

pxi.SectionType verbose;

int main(string[] args) {
	if (!command.parse(args))
		command.help();
	string[] files = command.finalArgs();
	if (command.sectionArgument.set()) {
		verbose = pxi.sectionType(command.sectionArgument.value);
		if (verbose == null) {
			printf("Invalid section type: %s\n", command.sectionArgument.value);
			return 1;
		}
	}
	boolean anyFailed = false;
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
		pxi.SectionType st = p.sectionType(i);
		string label;
		label.printf("[%d]", i);
		string type;
		type.printf("%s (%d)", pxi.sectionTypeName(st), int(st));
		string offset;
		offset.printf("@%x", entry.offset);
		printf("  %c %4s %16s %10s [%d bytes]\n", i == best ? '*' : ' ', label, type, offset, entry.length);
		if (st == pxi.SectionType.X86_64_WIN)
			pxi.registerSectionReader(pxi.SectionType.X86_64_WIN, x86_64NextReader);
		else
			continue;
		ref<pxi.Section> s = p.readSection(i);
		if (s == null)
			printf("      <<- ERROR ->>\n");
	}
	p.close();
	return true;
}


ref<pxi.Section> x86_64NextReader(file.File pxiFile, long length) {
	x86_64.X86_64SectionHeader header;
	
	if (pxiFile.read(&header, header.bytes) != header.bytes) {
		printf("          Could not read x86-64 section header\n");
		return null;
	}
	x86_64.printHeader(&header, pxiFile.tell());
	return new PlaceHolder();
}

class PlaceHolder extends pxi.Section {
	PlaceHolder() {
		super(pxi.SectionType.FILLER);
	}
	
	public long length() {
		return 0;
	}
	
	public void write(file.File pxiFile) {
	}
}
