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
import parasol:pbuild;
import parasol:runtime;

class PBuildCommand extends process.Command {
	pbuild.BuildOptions buildOptions;

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
					"While making the builder do more work, if there are changes in multiple " +
					"sub-projects, or dependencies across projects, this build will properly " +
					"handle them." +
					"\n" +
					"If no products are given as arguments, then all products enabled in " +
					"the build scripts will be built. " +
					"If one or more products are given as arguments, then only those products " +
					"plus any products the named ones are dependent one will be built." +
					"\n" +
					"Parasol Compiler Version " + runtime.image.version() + "\n" +
					"Copyright (c) 2015 Robert Jervis"
					);
		buildOptions.installContextOption = stringOption('i', "install",
					"Designates a Parasol context, into which the command-line arguments designating package " +
					"products are to be installed" +
					".");
		buildOptions.buildDirOption = stringOption('d', "dir",
					"Designates the root directory for the build source tree. " +
					"Default: .");
		buildOptions.buildFileOption = stringOption('f', "file",
					"Designates the path for the build file. " +
					"If this option is provided, only this one build script will be loaded and executed. " +
					"Default: Apply the search algorithm described below.");
		buildOptions.buildThreadsOption = integerOption('t', "threads",
					"Declares the number of threads to be used in the build. " +
					"Default: number of cpus on machine.");
		buildOptions.outputDirOption = stringOption('o', "out",
					"Designates the output directory where all products will be stored. " +
					"If no out directory is designated on the command-line, then a directory " +
					"named 'build' will be used to store the outputs described in each build file " +
					"included in the build.");
		buildOptions.reportOutOfDateOption = booleanOption('r', "report",
					"Reports which file caused a given product to be rebuilt.");
		buildOptions.verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		buildOptions.traceOption = booleanOption(0, "trace", "Trace the execution of each test.");
		buildOptions.logImportsOption = booleanOption(0, "logImports",
					"Log all import processing.");
		buildOptions.officialBuildOption = booleanOption(0, "official", 
					"Do not include a date/time extension on the build version and build all targets");
		buildOptions.symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		buildOptions.disassemblyOption = booleanOption(0, "asm",
					"Display disassembly of generated code");
		buildOptions.uiReadyOption = stringOption(0, "ui",
					"Display error messages with mark up suitable for the UI. The argument string is the filename prefix that identifies files being compiled (versus reference libraries not in the editor)");
		buildOptions.targetOSOption = stringOption(0, "os",
					"Selects the target operating system for this execution. " +
					"Default: " + pbuild.thisOS());
		buildOptions.targetCPUOption = stringOption(0, "cpu",
					"Selects the target operating system for this execution. " +
					"Default: " + pbuild.thisCPU());
		buildOptions.suitesOption = stringOption(0, "tests",
					"Run the indicated test suite(s) after successful completion of the build.");
		helpOption('?', "help",
					"Displays this help.");
		versionOption("version", "Display the version of the pbuild app.");
	}
}

PBuildCommand pbuildCommand;

public int main(string[] args) {
	if (!pbuildCommand.parse(args))
		pbuildCommand.help();
	pbuildCommand.buildOptions.setOptionDefaults();
	pbuild.Coordinator coordinator(&pbuildCommand.buildOptions,
								   pbuildCommand.finalArguments());
	if (!coordinator.validate()) {
		printf("FAIL: Errors encountered trying to find and parse build scripts.\n");
		pbuildCommand.help();
	}
	// Note: if the build files contain any 'after_pass' scripts, those will be exec'ed
	// from inside this function, and it will not return.
	return coordinator.run();
}
