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
import parasol:process;
import parasol:pbuild.Coordinator;
import parasol:pbuild.thisOS;
import parasol:pbuild.thisCPU;
import parasol:thread;

class PBuildCommand extends process.Command {
	public PBuildCommand() {
		finalArguments(0, int.MAX_VALUE, "[ products ... ]");
		description("Parasol Build Utility.\n" +
					"This program builds a Parasol application according to the " +
					"rules in build files. " +
					"\n" +
					"With no file option specified, the builder will search the current " +
					"directory and then recursively in sub-directories until at least one " +
					"build file named 'make.pbld' is found. " +
					"At each sub-directory, if a 'make.pbld' file is found there, the " +
					"search stops and that build file is included in the build " +
					" and no directories underneath that one are searched." +
					"If multiple build files are found in separate branches of the " +
					"directory hierarchy, all will be included in the build." +
					"\n" +
					"Thus, by arranging a collection of related projects under a single " +
					"root, one can orchestrate a build across all included build files. " +
					"While making the maker do more work, if there are changes in multiple " +
					"sub-projects, or dependencies across projects, this build will properly " +
					"handle them." +
					"\n" +
					"If no products are given as arguments, then all products enabled in " +
					"the build scripts will be built. " +
					"If one or more products are given as arguments, then only those products " +
					"plus any products the named ones are dependent one will be built."
					);
		buildDirOption = stringOption('d', "dir",
					"Designates the root directory for the build source tree. " +
					"Default: .");
		buildFileOption = stringOption('f', "file",
					"Designates the path for the build file. " +
					"If this option is provided, only this one build script will be loaded and executed. " +
					"Default: Apply the search algorithm described below.");
		buildThreadsOption = integerOption('t', "threads",
					"Declares the number of threads to be used in the build. " +
					"Default: number of cpus on machine.");
		outputDirOption = stringOption('o', "out",
					"Designates the output directory where all products will be stored. " +
					"If no out directory is designated on the command-line, then a directory " +
					"named 'build' will be used to store the outputs described in each build file " +
					"included in the build.");
		reportOutOfDateOption = booleanOption('r', "report",
					"Reports which file caused a given product to be rebuilt.");
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		traceOption = booleanOption(0, "trace", "Trace the execution of each test.");
		logImportsOption = booleanOption(0, "logImports",
					"Log all import processing.");
		symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		disassemblyOption = booleanOption(0, "asm",
					"Display disassembly of generated code");
		uiReadyOption = stringOption(0, "ui",
					"Display error messages with mark up suitable for the UI. The argument string is the filename prefix that identifies files being compiled (versus reference libraries not in the editor)");
		targetOSOption = stringOption(0, "os",
					"Selects the target operating system for this execution. " +
					"Default: " + thisOS());
		targetCPUOption = stringOption(0, "cpu",
					"Selects the target operating system for this execution. " +
					"Default: " + thisCPU());
		suitesOption = stringOption(0, "tests",
					"Run the indicated test suite(s) after successful completion of the build.");
		helpOption('?', "help",
					"Displays this help.");
	}

	ref<process.Option<string>> buildDirOption;
	ref<process.Option<string>> buildFileOption;
	ref<process.Option<int>> buildThreadsOption;
	ref<process.Option<string>> outputDirOption;
	ref<process.Option<string>> targetOSOption;
	ref<process.Option<string>> targetCPUOption;
	ref<process.Option<string>> suitesOption;
	ref<process.Option<boolean>> traceOption;
	ref<process.Option<boolean>> symbolTableOption;
	ref<process.Option<boolean>> reportOutOfDateOption;
	ref<process.Option<boolean>> verboseOption;
	ref<process.Option<boolean>> logImportsOption;
	ref<process.Option<boolean>> disassemblyOption;
	ref<process.Option<string>> uiReadyOption;
}

PBuildCommand pbuildCommand;

public int main(string[] args) {
	if (!pbuildCommand.parse(args))
		pbuildCommand.help();
	if (!pbuildCommand.buildThreadsOption.set())
		pbuildCommand.buildThreadsOption.value = thread.cpuCount();
	Coordinator coordinator(pbuildCommand.buildDirOption.value,
							pbuildCommand.buildFileOption.value,
							pbuildCommand.buildThreadsOption.value,
							pbuildCommand.outputDirOption.value,
							pbuildCommand.targetOSOption.value,
							pbuildCommand.targetCPUOption.value,
							pbuildCommand.uiReadyOption.value,
							pbuildCommand.suitesOption.value,
							pbuildCommand.symbolTableOption.set(),
							pbuildCommand.disassemblyOption.set(),
							pbuildCommand.reportOutOfDateOption.set(),
							pbuildCommand.verboseOption.set(),
							pbuildCommand.traceOption.set(),
							pbuildCommand.logImportsOption.set(),
							pbuildCommand.finalArguments());
	if (!coordinator.validate()) {
		printf("FAIL: Errors encountered trying to find and parse build scripts.\n");
		pbuildCommand.help();
	}
	// Note: if the build files contain any 'after_pass' scripts, those will be exec'ed
	// from inside this function, and it will not return.
	return coordinator.run();
}
