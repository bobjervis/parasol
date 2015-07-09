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
import parasol:commandLine;
import parasol:script;
import parasol:storage;
import parasol:process;
import parasol:runtime;
import parasol:pxi;
import parasol:pxi.SectionType;
import parasol:compiler.Arena;
import parasol:compiler.Target;
import parasol:file;
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
class GenHeaderCommand extends commandLine.Command {
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
		importPathArgument = stringArgument('I', "importPath", 
					"Sets the path of directories like the --explicit option, " +
					"but the directories ^/lib and ^/alys/lib' are appended to " +
					"those specified with this option.");
		verboseArgument = booleanArgument('v', null,
					"Enables verbose output.");
		symbolTableArgument = booleanArgument(0, "syms",
					"Print the symbol table.");
		logImportsArgument = booleanArgument(0, "logImports",
					"Log all import processing");
		explicitArgument = stringArgument('X', "explicit",
					"Sets the path of directories to search for imported symbols. " +
					"Directories are separated by commas. " +
					"The special directory ^ can be used to signify the Parasol " +
					"install directory. ");
		helpArgument('?', "help",
					"Displays this help.");
	}

	ref<commandLine.Argument<string>> importPathArgument;
	ref<commandLine.Argument<boolean>> verboseArgument;
	ref<commandLine.Argument<string>> explicitArgument;
	ref<commandLine.Argument<boolean>> logImportsArgument;
	ref<commandLine.Argument<boolean>> symbolTableArgument;
}

private ref<GenHeaderCommand> genHeaderCommand;
private string[] finalArgs;

int main(string[] args) {
	int result = 1;
	
	genHeaderCommand = new GenHeaderCommand();
	if (!genHeaderCommand.parse(args))
		genHeaderCommand.help();
	if (genHeaderCommand.importPathArgument.set() &&
		genHeaderCommand.explicitArgument.set()) {
		printf("Cannot set both --explicit and --importPath arguments.\n");
		genHeaderCommand.help();
	}
	finalArgs = genHeaderCommand.finalArgs();
	if (finalArgs.length() != 2)
		genHeaderCommand.help();
	printf("Creating header %s\n", finalArgs[1]);
	Arena arena;

	if (!configureArena(&arena))
		return 1;
	string filename = finalArgs[0];
	ref<Target> target = arena.compile(filename, false, false);
	if (genHeaderCommand.symbolTableArgument.value)
		arena.printSymbolTable();
	if (genHeaderCommand.verboseArgument.value) {
		arena.print();
		target.print();
	}
	if (target == null) {
		printf("%s failed to compile\n", filename);
		arena.printMessages();
		return 1;
	}
	file.File header = file.createTextFile(finalArgs[1]);
	if (!header.opened()) {
		printf("Could not create file %s\n", finalArgs[1]);
		return 1;
	}
	header.write("/*\n");
	header.write(" * Generated file - DO NOT MODIFY\n");
	header.write(" */\n");
	header.write("#ifndef PARASOL_HEADER_H\n");
	header.write("#define PARASOL_HEADER_H\n");
	if (!arena.writeHeader(header)) {
		header.close();
		printf("Failed to write header %s\n", finalArgs[1]);
		return 0;
	} else {
		header.write("#endif // PARASOL_HEADER_H\n");
		header.close();
		return 1;
	}
}

boolean configureArena(ref<Arena> arena) {
	if (genHeaderCommand.explicitArgument.set())
		arena.setImportPath(genHeaderCommand.explicitArgument.value);
	else if (genHeaderCommand.importPathArgument.set())
		arena.setImportPath(genHeaderCommand.importPathArgument.value + ",^/src/lib,^/alys/lib");
	arena.logImports = genHeaderCommand.logImportsArgument.value;
	arena.verbose = genHeaderCommand.verboseArgument.value;
	if (arena.load()) 
		return true;
	else {
		arena.printMessages();
		if (genHeaderCommand.verboseArgument.value)
			arena.print();
		printf("Failed to load arena\n");
		return false;
	}
}
