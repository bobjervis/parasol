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
import parasol:compiler;
import parasol:storage;
import parasol:process;
import parasol:runtime;
import parasol:memory;
import parasol:pxi;
import parasol:time;
import native:linux;
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
					"Refer to the Parasol language reference manual for details on " +
					"permitted syntax." +
					"\n" +
					"Parasol Compiler Version " + runtime.image.version() + "\n" +
					"Copyright (c) 2015 Robert Jervis"
					);
		contextOption = stringOption(0, "context",
					"Defines a Parasol context to use in the compile and execution of the application. " +
					"This overrides the value of the PARASOL_CONTEXT environment variable.");
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		logImportsOption = booleanOption(0, "logImports",
					"Log all import processing.");
		disassemblyOption = booleanOption(0, "asm",
					"Display disassembly of instructions and internal tables.");
		pxiOption = stringOption(0, "pxi",
					"Writes compiled output to the given file. " + 
					"Does not execute the program.");
		profileOption = stringOption('p', "profile",
					"Produce a profile report, writing the profile data to the " +
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
					"The guarded heap writes sentinel bytes before and after each allocated region of memory and checks " +
					"their value when the block is deleted, or when the program terminates normally. " +
					"If the guarded heap detects that these guard areas have been modified, it throws a " +
					"CorruptHeapException.");
		versionOption = booleanOption(0, "version", "Displays the compiler version.");
		helpOption('?', "help",
					"Displays this help.");
	}

	ref<process.Option<string>> contextOption;
	ref<process.Option<boolean>> verboseOption;
	ref<process.Option<boolean>> disassemblyOption;
	ref<process.Option<string>> pxiOption;
	ref<process.Option<string>> targetOption;
	ref<process.Option<string>> rootOption;
	ref<process.Option<string>> profileOption;
	ref<process.Option<string>> coverageOption;
	ref<process.Option<string>> heapOption;
	ref<process.Option<boolean>> logImportsOption;
	ref<process.Option<boolean>> symbolTableOption;
	ref<process.Option<boolean>> compileOnlyOption;
	ref<process.Option<boolean>> versionOption;
	memory.StartingHeap heap;

}

private ParasolCommand parasolCommand;
private string[] finalArguments;

int main(string[] args) {
	int result;
	parseCommandLine(args);
	if (!parasolCommand.coverageOption.set())
		result = runCommand();
	return result;
}

void parseCommandLine(string[] args) {
	string[memory.StartingHeap] heapOptionValues = [
		"prod",
		"leaks",
		"guard"
	];
	
	if (!parasolCommand.parse(args))
		parasolCommand.help();
	if (parasolCommand.versionOption.set()) {
		printf("%s\n", runtime.image.version());
		process.exit(0);
	}
	finalArguments = parasolCommand.finalArguments();
	if (finalArguments.length() == 0) {
		printf("Must include a filename for the main file of the program\n");
		parasolCommand.help();
	}
	if (parasolCommand.heapOption.set()) {
		boolean foundIt;
		for (i in heapOptionValues)
			if (heapOptionValues[i] == parasolCommand.heapOption.value) {
				foundIt = true;
				parasolCommand.heap = i;
				break;
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
}

int runCommand() {
	compiler.Arena arena;

	configureArena(&arena);

	int returnValue;
	boolean result;

	if (parasolCommand.pxiOption.set())
		printf("Compiling to %s\n", parasolCommand.pxiOption.value);

	time.Time start = time.Time.now();

	compiler.CompileContext compileContext(&arena,
									null,
									parasolCommand.verboseOption.value,
									parasolCommand.heap,
									parasolCommand.profileOption.value,
									parasolCommand.coverageOption.value,
									parasolCommand.logImportsOption.value);

	if (!compileContext.loadRoot(false))
		return 1;

	string[] args = parasolCommand.finalArguments();
	ref<compiler.Target> target = compileContext.compile(args[0]);
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
	} else if (target == null)
		returnValue = 1;
	else if (!disassemble(&arena, target, args[0]))
		returnValue = 1;
	else if (parasolCommand.pxiOption.set()) {
		ref<pxi.Pxi> output = pxi.Pxi.create(parasolCommand.pxiOption.value);
		target.writePxi(output);
		if (!output.write()) {
			printf("Error writing to %s\n", parasolCommand.pxiOption.value);
			returnValue = 1;
		}
		delete output;
		time.Time end = time.Time.now();
		printf("Done in %d milliseconds\n", end.milliseconds() - start.milliseconds());
	} else if (!parasolCommand.compileOnlyOption.value) {
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

void configureArena(ref<compiler.Arena> arena) {
	arena.verbose = parasolCommand.verboseOption.value;
	if (parasolCommand.logImportsOption.value)
		printf("Running with context: %s\n", arena.activeContext().name());
	if (parasolCommand.targetOption.set())
		arena.preferredTarget = pxi.sectionType(parasolCommand.targetOption.value);
}

private boolean disassemble(ref<compiler.Arena> arena, ref<compiler.Target> target, string filename) {
	if (!parasolCommand.disassemblyOption.value)
		return true;
	if (target.disassemble(arena))
		return true;
	printf("Could not disassemble target for %s\n", filename);
	return false;
}
