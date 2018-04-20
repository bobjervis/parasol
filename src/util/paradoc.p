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
import parasol:storage;
import parasol:process;
import parasol:runtime;
import parasol:compiler.Arena;
import parasol:compiler.FileStat;
import parasol:compiler.ImportDirectory;
import parasol:time;

/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2018 Robert Jervis";

class ParadocCommand extends process.Command {
	public ParadocCommand() {
		finalArguments(2, int.MAX_VALUE, "<output-directory> <input-directory> ...");
		description("The given input directories are analyzed as a set of Parasol libraries. " +
					"\n" +
					"Refer to the Parasol language reference manual for details on " +
					"permitted syntax." +
					"\n" +
					"The inline documentation (paradoc) in the namespaces referenced by the sources " +
					"in the given input directories are " +
					"written as HTML pages to the output directory." +
					"\n" +
					"Parasol Runtime Version " + runtime.RUNTIME_VERSION + "\r" +
					"Copyright (c) " + COPYRIGHT_STRING
					);
		importPathArgument = stringArgument('I', "importPath", 
					"Sets the path of directories like the --explicit option, " +
					"but the directory ^/src/lib is appended to " +
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
		rootArgument = stringArgument(0, "root",
					"Designates a specific directory to treat as the 'root' of the install tree. " +
					"The default is the parent directory of the runtime binary program.");
		helpArgument('?', "help",
					"Displays this help.");
	}

	ref<process.Argument<string>> importPathArgument;
	ref<process.Argument<boolean>> verboseArgument;
	ref<process.Argument<string>> explicitArgument;
	ref<process.Argument<string>> rootArgument;
	ref<process.Argument<boolean>> logImportsArgument;
	ref<process.Argument<boolean>> symbolTableArgument;
}

private ref<ParadocCommand> paradocCommand;
private string[] finalArgs;
string outputFolder;
ref<ImportDirectory>[] libraries;

int main(string[] args) {
	parseCommandLine(args);
	outputFolder = finalArgs[0];
	if (storage.exists(outputFolder)) {
		printf("Output directory '%s' exists, cannot over-write.\n", outputFolder);
		outputFolder = null;
		anyFailure = true;
	}

	Arena arena;

	if (!configureArena(&arena))
		return 1;
	for (int i = 1; i < finalArgs.length(); i++)
		libraries.append(arena.compilePackage(i - 1, paradocCommand.verboseArgument.value));
	if (paradocCommand.symbolTableArgument.value)
		arena.printSymbolTable();
	if (paradocCommand.verboseArgument.value) {
		arena.print();
	}
	boolean anyFailure = false;
	if (arena.countMessages() > 0) {
		printf("Failed to compile\n");
		arena.printMessages();
		anyFailure = true;
	}
	if (outputFolder != null) {
		printf("Writing to %s\n", outputFolder);
		if (storage.ensure(outputFolder)) {
			if (!collectNamespacesToDocument())
				anyFailure = true;
			if (!generateNamespaceDocumentation())
				anyFailure = true;
		} else {
			printf("Could not create the output folder\n");
			anyFailure = true;
		}
	}
	if (anyFailure)
		return 1;
	else
		return 0;
}

void parseCommandLine(string[] args) {
	paradocCommand = new ParadocCommand();
	if (!paradocCommand.parse(args))
		paradocCommand.help();
	if (paradocCommand.importPathArgument.set() &&
		paradocCommand.explicitArgument.set()) {
		printf("Cannot set both --explicit and --importPath arguments.\n");
		paradocCommand.help();
	}
	finalArgs = paradocCommand.finalArgs();
}

boolean configureArena(ref<Arena> arena) {
	arena.logImports = paradocCommand.logImportsArgument.value;
	if (paradocCommand.rootArgument.set())
		arena.setRootFolder(paradocCommand.rootArgument.value);
	string importPath;

	for (int i = 1; i < finalArgs.length(); i++) {
		importPath.append(finalArgs[i]);
		importPath.append(',');
	}
	if (paradocCommand.explicitArgument.set())
		importPath.append(paradocCommand.explicitArgument.value);
	else if (paradocCommand.importPathArgument.set())
		importPath.append(paradocCommand.importPathArgument.value + ",^/src/lib");
	else
		importPath.append(",^/src/lib");
	arena.setImportPath(importPath);
	arena.verbose = paradocCommand.verboseArgument.value;
	if (arena.logImports)
		printf("Running with import path: %s\n", arena.importPath());
	if (arena.load())
		return true;
	else {
		arena.printMessages();
		if (paradocCommand.verboseArgument.value)
			arena.print();
		printf("Failed to load arena\n");
		return false;
	}
}

boolean collectNamespacesToDocument() {
	return false;
}

boolean generateNamespaceDocumentation() {
	return false;
}
