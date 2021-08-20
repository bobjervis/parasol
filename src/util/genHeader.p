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
import parasol:script;
import parasol:storage;
import parasol:process;
import parasol:runtime;
import parasol:pxi;
import parasol:compiler.Arena;
import parasol:compiler.Target;
import parasol:time;

/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2015 Robert Jervis";
/*
 *	Parasol Header Generator:
 *
 *		This code orchestrates a compile and then generates a C header file. For
 *		enums shared between Parasol code and underlying native C libraries, these
 *		generated headers simplify data exchange.
 *		
 */
class GenHeaderCommand extends process.Command {
	public GenHeaderCommand() {
		finalArguments(0, int.MAX_VALUE, "<filename> <header-filename>");
		description("The given filename is parsed as a Parasol program. " +
					"\n" +
					"All Parasol declarations that are marked with the annotation @Header " +
					"will be written as C declarations to the named header file." +
					"\n" +
					"Refer to the Parasol language reference manual for details on " +
					"permitted syntax." +
					"\n" +
					"Parasol Runtime Version " + runtime.RUNTIME_VERSION + "\r" +
					"Copyright (c) " + COPYRIGHT_STRING
					);
		importPathOption = stringOption('I', "importPath", 
					"Sets the path of directories like the --explicit option, " +
					"but the directories ^/lib and ^/alys/lib' are appended to " +
					"those specified with this option.");
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		logImportsOption = booleanOption(0, "logImports",
					"Log all import processing");
		explicitOption = stringOption('X', "explicit",
					"Sets the path of directories to search for imported symbols. " +
					"Directories are separated by commas. " +
					"The special directory ^ can be used to signify the Parasol " +
					"install directory. ");
		helpOption('?', "help",
					"Displays this help.");
	}

	ref<process.Option<string>> importPathOption;
	ref<process.Option<boolean>> verboseOption;
	ref<process.Option<string>> explicitOption;
	ref<process.Option<boolean>> logImportsOption;
	ref<process.Option<boolean>> symbolTableOption;
}

private ref<GenHeaderCommand> genHeaderCommand;
private string[] finalArguments;

int main(string[] args) {
	int result = 1;
	
	genHeaderCommand = new GenHeaderCommand();
	if (!genHeaderCommand.parse(args))
		genHeaderCommand.help();
	if (genHeaderCommand.importPathOption.set() &&
		genHeaderCommand.explicitOption.set()) {
		printf("Cannot set both --explicit and --importPath arguments.\n");
		genHeaderCommand.help();
	}
	finalArguments = genHeaderCommand.finalArguments();
	if (finalArguments.length() != 2)
		genHeaderCommand.help();
	printf("Creating header %s\n", finalArguments[1]);
	Arena arena;

	if (!configureArena(&arena))
		return 1;
	string filename = finalArguments[0];
	ref<Target> target = arena.compile(filename, false, false, false, null, null);
	if (genHeaderCommand.symbolTableOption.value)
		arena.printSymbolTable();
	if (genHeaderCommand.verboseOption.value) {
		arena.print();
		target.print();
	}
	if (target == null) {
		printf("%s failed to compile\n", filename);
		arena.printMessages();
		return 1;
	}
	ref<Writer> header = storage.createTextFile(finalArguments[1]);
	if (header == null) {
		printf("Could not create file %s\n", finalArguments[1]);
		return 1;
	}
	header.write("/*\n");
	header.write(" * Generated file - DO NOT MODIFY\n");
	header.write(" */\n");
	header.write("#ifndef PARASOL_HEADER_H\n");
	header.write("#define PARASOL_HEADER_H\n");
	if (!arena.writeHeader(header)) {
		delete header;
		printf("Failed to write header %s\n", finalArguments[1]);
		return 0;
	} else {
		header.write("#endif // PARASOL_HEADER_H\n");
		delete header;
		return 1;
	}
}

boolean configureArena(ref<Arena> arena) {
	if (genHeaderCommand.explicitOption.set())
		arena.setImportPath(genHeaderCommand.explicitOption.value);
	else if (genHeaderCommand.importPathOption.set())
		arena.setImportPath(genHeaderCommand.importPathOption.value + ",^/src/lib,^/alys/lib");
	arena.logImports = genHeaderCommand.logImportsOption.value;
	arena.verbose = genHeaderCommand.verboseOption.value;
	if (arena.load()) 
		return true;
	else {
		arena.printMessages();
		if (genHeaderCommand.verboseOption.value)
			arena.print();
		printf("Failed to load arena\n");
		return false;
	}
}
