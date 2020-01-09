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
		disassemblyArgument = booleanArgument(0, "asm",
					"Display disassembly of instructions and internal tables");
		explicitArgument = stringArgument('X', "explicit",
					"Sets the path of directories to search for imported symbols. " +
					"Directories are separated by commas. " +
					"The special directory ^ can be used to signify the Parasol " +
					"install directory. ");
		pxiArgument = stringArgument(0, "pxi",
					"Writes compiled output to the given file. " + 
					"Does not execute the program.");
		leaksArgument = booleanArgument(0, "leaks",
					"Use a leak-detecting heap for allocations. Produce a leak " +
					"report when the process terminates.");
		profileArgument = stringArgument('p', "profile",
					"Produce a profile report, wriitng the profile data to the " +
					"path provided as this argument value.");
		coverageArgument = stringArgument(0, "cover",
					"Produce a code coverage report, accumulating the data in a " +
					"file at the path provided in the argument value.");
		targetArgument = stringArgument(0, "target",
					"Selects the target runtime for this execution. " +
					"Default: " + pxi.sectionTypeName(runtime.Target(runtime.supportedTarget(0))));
		rootArgument = stringArgument(0, "root",
					"Designates a specific directory to treat as the 'root' of the install tree. " +
					"The default is the parent directory of the runtime binary program.");
		compileOnlyArgument = booleanArgument('c', "compile",
					"Only compile the application, do not run it.");
		helpArgument('?', "help",
					"Displays this help.");
	}

	ref<process.Argument<string>> importPathArgument;
	ref<process.Argument<boolean>> verboseArgument;
	ref<process.Argument<boolean>> disassemblyArgument;
	ref<process.Argument<string>> explicitArgument;
	ref<process.Argument<string>> pxiArgument;
	ref<process.Argument<string>> targetArgument;
	ref<process.Argument<string>> rootArgument;
	ref<process.Argument<string>> profileArgument;
	ref<process.Argument<string>> coverageArgument;
	ref<process.Argument<boolean>> leaksArgument;
	ref<process.Argument<boolean>> logImportsArgument;
	ref<process.Argument<boolean>> symbolTableArgument;
	ref<process.Argument<boolean>> compileOnlyArgument;
}

private ref<ParasolCommand> parasolCommand;
private string[] finalArgs;

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
	return result;
}

CommandLineVariant parseCommandLine(string[] args) {
	parasolCommand = new ParasolCommand();
	if (!parasolCommand.parse(args))
		parasolCommand.help();
	if (parasolCommand.importPathArgument.set() &&
		parasolCommand.explicitArgument.set()) {
		printf("Cannot set both --explicit and --importPath arguments.\n");
		parasolCommand.help();
	}
	if (parasolCommand.targetArgument.set()) {
		if (pxi.sectionType(parasolCommand.targetArgument.value) == null) {
			printf("Invalid value for target argument: %s\n", parasolCommand.targetArgument.value);
			parasolCommand.help();
		}
	}
	finalArgs = parasolCommand.finalArgs();
	if (finalArgs.length() == 0)
		return CommandLineVariant.INTERACTIVE;
	else if (parasolCommand.pxiArgument.set())
		return CommandLineVariant.COMPILE;
	else
		return CommandLineVariant.COMMAND;
}

int runCommand() {
	Arena arena;

	if (!configureArena(&arena))
		return 1;
	string[] args = parasolCommand.finalArgs();

	int returnValue;
	boolean result;
	
	ref<Target> target = arena.compile(args[0], true,
								parasolCommand.verboseArgument.value,
								parasolCommand.leaksArgument.value,
								parasolCommand.profileArgument.value,
								parasolCommand.coverageArgument.value);
	if (parasolCommand.symbolTableArgument.value)
		arena.printSymbolTable();
	if (parasolCommand.verboseArgument.value) {
		arena.print();
		if (target != null)
			target.print();
	}
	if (arena.countMessages() > 0) {
		printf("%s failed to compile\n", args[0]);
		arena.printMessages();
		return 1;
	}
	if (!disassemble(&arena, target, args[0]))
		return 1;
	if (!parasolCommand.compileOnlyArgument.value) {
		(returnValue, result) = target.run(args);
		if (!result) {
			if (returnValue == -1) {
			} else
				printf("%s failed!\n", args[0]);
			return 1;
		}
	}
	delete target;
	return returnValue;
}

int compileCommand() {
	Arena arena;

	printf("Compiling to %s\n", parasolCommand.pxiArgument.value);
	time.Time start = time.Time.now();
	if (!configureArena(&arena))
		return 1;
	string filename = parasolCommand.finalArgs()[0];
	ref<Target> target = arena.compile(filename, false, parasolCommand.verboseArgument.value, false, null, null);
	if (parasolCommand.symbolTableArgument.value)
		arena.printSymbolTable();
	if (!disassemble(&arena, target, filename))
		return 1;
	if (parasolCommand.verboseArgument.value) {
		arena.print();
		target.print();
	}
	if (arena.countMessages() > 0) {
		printf("%s failed to compile\n", filename);
		arena.printMessages();
		return 1;
	}
	boolean anyFailure = false;
	ref<pxi.Pxi> output = pxi.Pxi.create(parasolCommand.pxiArgument.value);
	target.writePxi(output);
	if (!output.write()) {
		printf("Error writing to %s\n", parasolCommand.pxiArgument.value);
		anyFailure = true;
	}
	time.Time end = time.Time.now();
	printf("Done in %d milliseconds\n", end.value() - start.value());
	if (anyFailure)
		return 1;
	else
		return 0;
}

boolean configureArena(ref<Arena> arena) {
	arena.logImports = parasolCommand.logImportsArgument.value;
	if (parasolCommand.rootArgument.set())
		arena.setRootFolder(parasolCommand.rootArgument.value);
	if (parasolCommand.explicitArgument.set())
		arena.setImportPath(parasolCommand.explicitArgument.value);
	else if (parasolCommand.importPathArgument.set())
		arena.setImportPath(parasolCommand.importPathArgument.value + ",^/src/lib");
	arena.verbose = parasolCommand.verboseArgument.value;
	if (arena.logImports)
		printf("Running with import path: %s\n", arena.importPath());
	if (parasolCommand.targetArgument.set())
		arena.preferredTarget = pxi.sectionType(parasolCommand.targetArgument.value);
	if (arena.load()) 
		return true;
	else {
		arena.printMessages();
		if (parasolCommand.verboseArgument.value)
			arena.print();
		printf("Failed to load arena\n");
		return false;
	}
}

private boolean disassemble(ref<Arena> arena, ref<Target> target, string filename) {
	if (!parasolCommand.disassemblyArgument.value)
		return true;
	if (target.disassemble(arena))
		return true;
	printf("Could not disassemble target for %s\n", filename);
	return false;
}
