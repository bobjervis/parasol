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
import parasol:memory;
import parasol:pxi;
import parasol:compiler.Arena;
import parasol:compiler.Target;
import parasol:time;

/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2015 Robert Jervis";
/*
 *	Parasol engine architecture:
 *
 *		Parser produces a concrete syntax tree from a character stream
 *		Formatter produces a drawing program from a concrete syntax tree
 *		Renderer executes a drawing program
 *		Compiler produces a symbol table from a concrete syntax tree
 *		Coder produces a runnable object from a symbol table entry
 *		Runtime executes a runnable object
 *		
 */
class ParasolCommand extends process.Command {
	public ParasolCommand() {
		commandName("pc");
		finalArguments(0, int.MAX_VALUE, "<filename> [arguments ...]");
		description("The given filename is run as a Parasol program. " +
					"Any command-line arguments appearing after are passed " +
					"to any main function in that file." +
					"\n" +
					"If no arguments are given at all, or if the filename is a single " +
					"dash (-), statements are read from standard input. " +
					"If the standard-input stream is connected to a terminal, the " +
					"engine enters conversational mode, writing prompts to " +
					"the standard-output." +
					"\n" +
					"Refer to the Parasol language reference manual for details on " +
					"permitted syntax." +
					"\n" +
					"Parasol Runtime Version " + runtime.RUNTIME_VERSION + "\r" +
					"Copyright (c) " + COPYRIGHT_STRING
					);
		importPathOption = stringOption('I', "importPath", 
					"Sets the path of directories like the --explicit option, " +
					"but the directory ^/src/lib is appended to " +
					"those specified with this option.");
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		logImportsOption = booleanOption(0, "logImports",
					"Log all import processing");
		disassemblyOption = booleanOption(0, "asm",
					"Display disassembly of instructions and internal tables");
		explicitOption = stringOption('X', "explicit",
					"Sets the path of directories to search for imported symbols. " +
					"Directories are separated by commas. " +
					"The special directory ^ can be used to signify the Parasol " +
					"install directory. ");
		pxiOption = stringOption(0, "pxi",
					"Writes compiled output to the given file. " + 
					"Does not execute the program.");
		profileOption = stringOption('p', "profile",
					"Produce a profile report, wriitng the profile data to the " +
					"path provided as this argument value.");
		coverageOption = stringOption(0, "cover",
					"Produce a code coverage report, accumulating the data in a " +
					"file at the path provided in the argument value.");
		targetOption = stringOption(0, "target",
					"Selects the target runtime for this execution. " +
					"Default: " + pxi.sectionTypeName(runtime.Target(runtime.supportedTarget(0))));
		rootOption = stringOption(0, "root",
					"Designates a specific directory to treat as the 'root' of the install tree. " +
					"The default is the parent directory of the runtime binary program.");
		compileOnlyOption = booleanOption('c', "compile",
					"Only compile the application, do not run it.");
		heapOption = stringOption(0, "heap",
					"Use a production heap ('prod'), a leak-detecting heap ('leaks') or a " +
					"guarded heap ('guard'). Defaults to 'prod'. " +
					"The leaks heap option writes a leaks report to leaks.txt when the process terminates " +
					"normally. " +
					"The guarded heap writes sentinel bytes before and after each allocation region of memory and checks " +
					"their value when the block is deleted, or when the program terminates normally. " +
					"If teh guarded heap detects that these guard areas have been modified, it throws a " +
					"CorruptHeapException.");
		helpOption('?', "help",
					"Displays this help.");
	}

	ref<process.Option<string>> importPathOption;
	ref<process.Option<boolean>> verboseOption;
	ref<process.Option<boolean>> disassemblyOption;
	ref<process.Option<string>> explicitOption;
	ref<process.Option<string>> pxiOption;
	ref<process.Option<string>> targetOption;
	ref<process.Option<string>> rootOption;
	ref<process.Option<string>> profileOption;
	ref<process.Option<string>> coverageOption;
	ref<process.Option<string>> heapOption;
	ref<process.Option<boolean>> logImportsOption;
	ref<process.Option<boolean>> symbolTableOption;
	ref<process.Option<boolean>> compileOnlyOption;
	memory.StartingHeap heap;

}

private ref<ParasolCommand> parasolCommand;
private string[] finalArguments;

enum CommandLineVariant {
	INTERACTIVE,
	COMMAND,
	COMPILE
}

int main(string[] args) {
	int result = 1;
	switch (parseCommandLine(args)) {
	case	INTERACTIVE:
		printf("Conversational mode is unfinished.\n");
		break;

	case	COMMAND:
		result = runCommand();
		break;

	case	COMPILE:
		result = compileCommand();
		break;
	}
	delete parasolCommand;
	return result;
}

CommandLineVariant parseCommandLine(string[] args) {
	string[memory.StartingHeap] heapOptionValues = [
		"prod",
		"leaks",
		"guard"
	];

	parasolCommand = new ParasolCommand();
	if (!parasolCommand.parse(args))
		parasolCommand.help();
	if (parasolCommand.importPathOption.set() &&
		parasolCommand.explicitOption.set()) {
		printf("Cannot set both --explicit and --importPath arguments.\n");
		parasolCommand.help();
	}
	if (parasolCommand.heapOption.set()) {
		boolean foundIt;
		for (i in heapOptionValues)
			if (heapOptionValues[i] == parasolCommand.heapOption.value) {
				foundIt = true;
				parasolCommand.heap = i;
			}
		if (!foundIt) {
			printf("Heap option has an invalid value: '%s'\n", parasolCommand.heapOption.value);
			parasolCommand.help();
		}
	}

	if (parasolCommand.targetOption.set()) {
		if (pxi.sectionType(parasolCommand.targetOption.value) == null) {
			printf("Invalid value for target argument: %s\n", parasolCommand.targetOption.value);
			parasolCommand.help();
		}
	}
	finalArguments = parasolCommand.finalArguments();
	if (finalArguments.length() == 0)
		return CommandLineVariant.INTERACTIVE;
	else if (parasolCommand.pxiOption.set())
		return CommandLineVariant.COMPILE;
	else
		return CommandLineVariant.COMMAND;
}

int runCommand() {
	Arena arena;

	if (!configureArena(&arena))
		return 1;
	string[] args = parasolCommand.finalArguments();

	int returnValue;
	boolean result;

	ref<Target> target = arena.compile(args[0],
								parasolCommand.verboseOption.value,
								parasolCommand.heap,
								parasolCommand.profileOption.value,
								parasolCommand.coverageOption.value);
	if (parasolCommand.symbolTableOption.value)
		arena.printSymbolTable();
	if (parasolCommand.verboseOption.value) {
		arena.print();
		if (target != null)
			target.print();
	}
	if (arena.countMessages() > 0) {
		printf("%s failed to compile\n", args[0]);
		arena.printMessages();
		returnValue = 1;
	} else if (!disassemble(&arena, target, args[0]))
		returnValue = 1;
	else if (!parasolCommand.compileOnlyOption.value) {
		(returnValue, result) = target.run(args);
		if (!result) {
			if (returnValue != -1)
				printf("%s failed!\n", args[0]);
			returnValue = 1;
		}
	}
	delete target;
	return returnValue;
}

int compileCommand() {
	Arena arena;

	printf("Compiling to %s\n", parasolCommand.pxiOption.value);
	time.Time start = time.Time.now();
	if (!configureArena(&arena))
		return 1;
	string filename = parasolCommand.finalArguments()[0];
	ref<Target> target = arena.compile(filename, parasolCommand.verboseOption.value, ParasolCommand.heap, null, null);
	if (parasolCommand.symbolTableOption.value)
		arena.printSymbolTable();
	if (!disassemble(&arena, target, filename))
		return 1;
	if (parasolCommand.verboseOption.value) {
		arena.print();
		target.print();
	}
	if (arena.countMessages() > 0) {
		printf("%s failed to compile\n", filename);
		arena.printMessages();
		return 1;
	}
	boolean anyFailure = false;
	ref<pxi.Pxi> output = pxi.Pxi.create(parasolCommand.pxiOption.value);
	target.writePxi(output);
	delete target;
	if (!output.write()) {
		printf("Error writing to %s\n", parasolCommand.pxiOption.value);
		anyFailure = true;
	}
	delete output;
	time.Time end = time.Time.now();
	printf("Done in %d milliseconds\n", end.milliseconds() - start.milliseconds());
	if (anyFailure)
		return 1;
	else
		return 0;
}

boolean configureArena(ref<Arena> arena) {
	arena.logImports = parasolCommand.logImportsOption.value;
	if (parasolCommand.rootOption.set())
		arena.setRootFolder(parasolCommand.rootOption.value);
	if (parasolCommand.explicitOption.set())
		arena.setImportPath(parasolCommand.explicitOption.value);
	else if (parasolCommand.importPathOption.set())
		arena.setImportPath(parasolCommand.importPathOption.value + ",^/src/lib");
	arena.verbose = parasolCommand.verboseOption.value;
	if (arena.logImports)
		printf("Running with import path: %s\n", arena.importPath());
	if (parasolCommand.targetOption.set())
		arena.preferredTarget = pxi.sectionType(parasolCommand.targetOption.value);
	if (arena.load()) 
		return true;
	else {
		arena.printMessages();
		if (parasolCommand.verboseOption.value)
			arena.print();
		printf("Failed to load arena\n");
		return false;
	}
}

private boolean disassemble(ref<Arena> arena, ref<Target> target, string filename) {
	if (!parasolCommand.disassemblyOption.value)
		return true;
	if (target.disassemble(arena))
		return true;
	printf("Could not disassemble target for %s\n", filename);
	return false;
}
