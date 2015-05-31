import parasol:commandLine;
import parasol:script;
import parasol:storage;
import parasol:process;
import parasol:runtime;
import parasol:pxi;
import parasol:pxi.SectionType;
import parasol:compiler.Arena;
import parasol:compiler.Target;
import parasol:compiler.test.initTestObjects;
import parasol:file;
import parasol:test.launch;
import parasol:test.listAllTests;
import parasol:time;

/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2011 Robert Jervis";
/*
 * Major Release: Incremented when a breaking change is released
 * Minor Feature Release: Incremented when significant new features
 * are released.
 * Fix Release: Incremented when big fixes are released.
 */
string RUNTIME_VERSION = "1.0.0";
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
class ParasolCommand extends commandLine.Command {
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
					"Parasol Runtime Version " + RUNTIME_VERSION + "\r" +
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
		testArgument = booleanArgument(0, "test",
					"Run a test script.");
		logImportsArgument = booleanArgument(0, "logImports",
					"Log all import processing");
		traceArgument = booleanArgument(0, "trace",
					"Trace execution of each instruction.");
		disassemblyArgument = booleanArgument(0, "asm",
					"Display disassembly of bytecodes");
		explicitArgument = stringArgument('X', "explicit",
					"Sets the path of directories to search for imported symbols. " +
					"Directories are separated by commas. " +
					"The special directory ^ can be used to signify the Parasol " +
					"install directory. ");
		headerArgument = stringArgument('H', "header",
					"Writes any declaration marked with a @Header annotation as a " + 
					"C declaration. " + 
					"The named output file will be overwritten if it already exists.");
		testPxiArgument = stringArgument(0, "testpxi",
					"Uses this pxi file with run tests.");
		pxiArgument = stringArgument(0, "pxi",
					"Writes compiled output to the given file. " + 
					"Does not execute the program.");
		targetArgument = stringArgument(0, "target",
					"Selects the target runtime for this execution. " +
					"Default: " + pxi.sectionTypeName(SectionType(runtime.supportedTarget(0))));
		compileFromSourceArgument = booleanArgument('s', "compileFromSource",
					"In --test mode, any 'run' tests are run with 'compile/main.p' included.");
		helpArgument('?', "help",
					"Displays this help.");
	}

	ref<commandLine.Argument<string>> importPathArgument;
	ref<commandLine.Argument<boolean>> verboseArgument;
	ref<commandLine.Argument<boolean>> testArgument;
	ref<commandLine.Argument<boolean>> traceArgument;
	ref<commandLine.Argument<boolean>> disassemblyArgument;
	ref<commandLine.Argument<string>> explicitArgument;
	ref<commandLine.Argument<string>> headerArgument;
	ref<commandLine.Argument<string>> pxiArgument;
	ref<commandLine.Argument<string>> targetArgument;
	ref<commandLine.Argument<string>> testPxiArgument;
	ref<commandLine.Argument<boolean>> logImportsArgument;
	ref<commandLine.Argument<boolean>> symbolTableArgument;
	ref<commandLine.Argument<boolean>> compileFromSourceArgument;
}

private ref<ParasolCommand> parasolCommand;
private string[] finalArgs;

enum CommandLineVariant {
	INTERACTIVE,
	COMMAND,
	COMPILE,
	HEADER,
	TEST
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
		
	case	HEADER:
		result = createHeaderCommand();
		break;
		
	case	TEST:
		result = runTestSuiteCommand();
		break;
	}
	process.exit(result);
	return 0;
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
	if (parasolCommand.testArgument.value)
		return CommandLineVariant.TEST;
	else if (finalArgs.length() == 0)
		return CommandLineVariant.INTERACTIVE;
	else if (parasolCommand.pxiArgument.set())
		return CommandLineVariant.COMPILE;
	else if (parasolCommand.headerArgument.set())
		return CommandLineVariant.HEADER;
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
	
	ref<Target> target = arena.compile(args[0], true, parasolCommand.verboseArgument.value);
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
	(returnValue, result) = target.run(args);
	if (!result) {
		if (returnValue == -1) {
		} else
			printf("%s failed!\n", args[0]);
		return 1;
	}
	return returnValue;
}

int compileCommand() {
	Arena arena;

	printf("Compiling to %s", parasolCommand.pxiArgument.value);
	if (parasolCommand.headerArgument.set())
		printf(" and header to %s", parasolCommand.headerArgument.value);
	printf("\n");
	time.Time start = time.now();
	if (!configureArena(&arena))
		return 1;
	string filename = parasolCommand.finalArgs()[0];
	ref<Target> target = arena.compile(filename, false, parasolCommand.verboseArgument.value);
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
	if (parasolCommand.headerArgument.set()) {
		if (!writeHeader(&arena))
			anyFailure = true;
	}
	ref<pxi.Pxi> output = pxi.Pxi.create(parasolCommand.pxiArgument.value);
	target.writePxi(output);
	if (!output.write()) {
		printf("Error writing to %s\n", parasolCommand.pxiArgument.value);
		anyFailure = true;
	}
	time.Time end = time.now();
	printf("Done in %d milliseconds\n", end.value() - start.value());
	if (anyFailure)
		return 1;
	else
		return 0;
}

int createHeaderCommand() {
	if (parasolCommand.targetArgument.set()) {
		printf("Cannot combine --target and --header options\n");
		return 1;
	}
	printf("Creating header %s\n", parasolCommand.headerArgument.value);
	Arena arena;

	if (!configureArena(&arena))
		return 1;
	string filename = parasolCommand.finalArgs()[0];
	ref<Target> target = arena.compile(filename, false, false);
	if (parasolCommand.symbolTableArgument.value)
		arena.printSymbolTable();
	if (parasolCommand.verboseArgument.value) {
		arena.print();
		target.print();
	}
	if (target == null) {
		printf("%s failed to compile\n", filename);
		arena.printMessages();
		return 1;
	}
	if (!writeHeader(&arena))
		return 1;
	else
		return 0;
}

int runTestSuiteCommand() {
	script.setCommandPrefix(storage.absolutePath(process.binaryFilename()) + " --test");
	listAllTests = parasolCommand.traceArgument.value;
	string pxiName = "debug/parasol.pxi";
	if (parasolCommand.testPxiArgument.set())
		pxiName = parasolCommand.testPxiArgument.value;
	initTestObjects(process.binaryFilename() + " " + pxiName, parasolCommand.verboseArgument.value, 
			parasolCommand.compileFromSourceArgument.value,
			parasolCommand.targetArgument.value);
//		initCommonTestObjects();
	return launch(finalArgs);
}

boolean configureArena(ref<Arena> arena) {
	if (parasolCommand.explicitArgument.set())
		arena.setImportPath(parasolCommand.explicitArgument.value);
	else if (parasolCommand.importPathArgument.set())
		arena.setImportPath(parasolCommand.importPathArgument.value + ",^/src/lib,^/alys/lib");
	arena.logImports = parasolCommand.logImportsArgument.value;
	arena.verbose = parasolCommand.verboseArgument.value;
	arena.trace = parasolCommand.traceArgument.value;
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

private boolean writeHeader(ref<Arena> arena) {
	if (!arena.writeHeader(parasolCommand.headerArgument.value)) {
		printf("Failed to write header %s\n", parasolCommand.headerArgument.value);
		return false;
	} else
		return true;
}

private boolean disassemble(ref<Arena> arena, ref<Target> target, string filename) {
	if (!parasolCommand.disassemblyArgument.value)
		return true;
	if (target.disassemble(arena))
		return true;
	printf("Could not disassemble target for %s\n", filename);
	return false;
}
