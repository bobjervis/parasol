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
import parasol:compiler.test.initTestObjects;
import parasol:test.launch;
import parasol:test.listAllTests;
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
class TestCommand extends process.Command {
	public TestCommand() {
		finalArguments(0, int.MAX_VALUE, "<script-filename> ...");
		description("The given filenames are run as a Parasol test script in ets format. " +
					"\n" +
					"Refer to the Parasol language reference manual for details on " +
					"permitted syntax." +
					"\n" +
					"Parasol Runtime Version " + runtime.RUNTIME_VERSION + "\r" +
					"Copyright (c) " + COPYRIGHT_STRING
					);
		rootDirOption = stringOption('r', "root",
					"Set's the root of the test tree to this directory.");
		importPathOption = stringOption('I', "importPath", 
					"Sets the path of directories like the --explicit option, " +
					"but the directory ^/src/lib are appended to " +
					"those specified with this option.");
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		showParseStageErrorsOption = booleanOption('p', "parseErrors",
					"Show errors know at the end of the parse stage. " +
					"Showing these messages still lets an expected failure test pass.");
		symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		logImportsOption = booleanOption(0, "logImports",
					"Log all import processing");
		traceOption = booleanOption(0, "trace",
					"Trace execution of each test.");
		explicitOption = stringOption('X', "explicit",
					"Sets the path of directories to search for imported symbols. " +
					"Directories are separated by commas. " +
					"The special directory ^ can be used to signify the Parasol " +
					"install directory. ");
		headerOption = stringOption('H', "header",
					"Writes any declaration marked with a @Header annotation as a " + 
					"C declaration. " + 
					"The named output file will be overwritten if it already exists.");
		testPxiOption = stringOption(0, "testpxi",
					"Uses this pxi file with run tests.");
		targetOption = stringOption(0, "target",
					"Selects the target runtime for this execution. " +
					"Default: " + pxi.sectionTypeName(runtime.Target(runtime.supportedTarget(0))));
		compileFromSourceOption = booleanOption('s', "compileFromSource",
					"In --test mode, any 'run' tests are run with 'compiler/main.p' included.");
		helpOption('?', "help",
					"Displays this help.");
	}

	ref<process.Option<string>> rootDirOption;
	ref<process.Option<string>> importPathOption;
	ref<process.Option<boolean>> verboseOption;
	ref<process.Option<boolean>> traceOption;
	ref<process.Option<string>> explicitOption;
	ref<process.Option<string>> headerOption;
	ref<process.Option<string>> targetOption;
	ref<process.Option<string>> testPxiOption;
	ref<process.Option<boolean>> logImportsOption;
	ref<process.Option<boolean>> symbolTableOption;
	ref<process.Option<boolean>> compileFromSourceOption;
	ref<process.Option<boolean>> showParseStageErrorsOption;
}

int main(string[] args) {
	TestCommand runetsCommand;
	if (!runetsCommand.parse(args))
		runetsCommand.help();
	if (runetsCommand.importPathOption.set() &&
		runetsCommand.explicitOption.set()) {
		printf("Cannot set both --explicit and --importPath arguments.\n");
		runetsCommand.help();
	}
	if (runetsCommand.targetOption.set()) {
		if (pxi.sectionType(runetsCommand.targetOption.value) == null) {
			printf("Invalid value for target argument: %s\n", runetsCommand.targetOption.value);
			runetsCommand.help();
		}
	}
	script.setCommandPrefix(storage.absolutePath(process.binaryFilename()) + " --test");
	listAllTests = runetsCommand.traceOption.value;
	string pxiName;
	if (runetsCommand.testPxiOption.set())
		pxiName = runetsCommand.testPxiOption.value;
	else {
		string binDir = storage.directory(process.binaryFilename());
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			pxiName = storage.constructPath(binDir, "x86-64-win.pxi");
		else
			pxiName = storage.constructPath(binDir, "x86-64-lnx.pxi");
	}
	initTestObjects(process.binaryFilename(), pxiName, runetsCommand.verboseOption.value, 
			runetsCommand.compileFromSourceOption.value,
			runetsCommand.symbolTableOption.value,
			runetsCommand.targetOption.value,
			runetsCommand.importPathOption.value,
			runetsCommand.rootDirOption.value, runetsCommand.showParseStageErrorsOption.value);
//		initCommonTestObjects();
	string[] s = runetsCommand.finalArguments();
	return launch(s);
}
