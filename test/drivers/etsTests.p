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
		traceArgument = booleanArgument(0, "trace",
					"Trace execution of each test.");
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
		targetArgument = stringArgument(0, "target",
					"Selects the target runtime for this execution. " +
					"Default: " + pxi.sectionTypeName(runtime.Target(runtime.supportedTarget(0))));
		compileFromSourceArgument = booleanArgument('s', "compileFromSource",
					"In --test mode, any 'run' tests are run with 'compiler/main.p' included.");
		helpArgument('?', "help",
					"Displays this help.");
	}

	ref<process.Argument<string>> importPathArgument;
	ref<process.Argument<boolean>> verboseArgument;
	ref<process.Argument<boolean>> traceArgument;
	ref<process.Argument<string>> explicitArgument;
	ref<process.Argument<string>> headerArgument;
	ref<process.Argument<string>> targetArgument;
	ref<process.Argument<string>> testPxiArgument;
	ref<process.Argument<boolean>> logImportsArgument;
	ref<process.Argument<boolean>> symbolTableArgument;
	ref<process.Argument<boolean>> compileFromSourceArgument;
}

int main(string[] args) {
	TestCommand parasolCommand;
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
	script.setCommandPrefix(storage.absolutePath(process.binaryFilename()) + " --test");
	listAllTests = parasolCommand.traceArgument.value;
	string pxiName;
	if (runtime.compileTarget == runtime.Target.X86_64_WIN)
		pxiName = "bin/x86-64-win.pxi";
	else
		pxiName = "bin/x86-64-lnx.pxi";
	if (parasolCommand.testPxiArgument.set())
		pxiName = parasolCommand.testPxiArgument.value;
	initTestObjects(process.binaryFilename() + " " + pxiName, parasolCommand.verboseArgument.value, 
			parasolCommand.compileFromSourceArgument.value,
			parasolCommand.symbolTableArgument.value,
			parasolCommand.targetArgument.value);
//		initCommonTestObjects();
	string[] s = parasolCommand.finalArgs();
	return launch(parasolCommand.finalArgs());
}
