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
import parasol:runtime;
import parasol:storage;

class PBugCommand extends process.Command {
	public PBugCommand() {
		finalArguments(0, int.MAX_VALUE, "[ directory | mainfile ] [ arguments ... ]");
		description("pbug - Parasol Debugging Utility.\n" +
					"This program is a debug monitor that runs or attaches to a running process. " +
					"\n" +
					"If either the -a or --application options are included, the process to be debugged " +
					"is found by searching the build scripts for a product by that name. " +
					"In this way you don't have to find the executaable image and type its path to start an " +
					"application under the debugger. " +
					"\n" +
					"Unless a -f or --file option is included as well, the debugger will search the current " +
					"directory and then recursively in sub-directories until at least one " +
					"build file named 'make.pbld' is found. " +
					"At each sub-directory, if a 'make.pbld' file is found there, the " +
					"search stops and that build file is included in the build " +
					" and no directories underneath that one are searched." +
					"If multiple build files are found in separate branches of the " +
					"directory hierarchy, all will be included in the search." +
					"\n" +
					"Thus, by arranging a collection of related projects under a single " +
					"root, one can locate a built application across all included build files. " +
					"\n" +
					"If either a -p or --process option is included, then the designated process is attached. " +
					"If this option is included, then no arguments should be supplied (they are embedded in the running " +
					"process already)." +
					"\n" +
					"If no overriding options are supplied, the first argument is either a directory containing a " +
					"Parasol application or a mainfile Parasol source file. " +
					"If a source file is named, the process to be debugged is launched under the debugger as if started by " +
					"the pc command." +
					"\n" +
					"Parasol Compiler Version " + runtime.image.version() + "\n" +
					"Copyright (c) 2015 Robert Jervis"
					);
		processOption = integerOption('p', "process", "The id of a running process that is not already " +
					"under the control of a debugger.");
		applicationOption = stringOption('a', "application", "Names an application product described in the " +
					"build scripts to be found (using the same rules as pbuild uses to find them).");
		buildFileOption = stringOption('f', "file",
					"Designates the path for the build file. " +
					"If no -a or ---application option is included as well, this option has no effect. " +
					"If this option is provided, only this one build script will be loaded and searched. " +
					"Default: Apply the search algorithm described below.");
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		helpOption('?', "help",
					"Displays this help.");
		versionOption("version", "Display the version of the pbuild app.");
	}

	ref<process.Option<string>> applicationOption;
	ref<process.Option<string>> buildFileOption;
	ref<process.Option<int>> processOption;
	ref<process.Option<boolean>> verboseOption;
}

PBugCommand pbugCommand;

public int main(string[] args) {
	if (!pbugCommand.parse(args))
		pbugCommand.help();
	if (pbugCommand.processOption.set()) {
		printf("Attaching to a running process is not yet supported.\n");
		return 1;
	}
	arguments := pbugCommand.finalArguments();
	string exePath;
	if (pbugCommand.applicationOption.set()) {
		Coordinator coordinator(null,		// build dir
								pbugCommand.buildFileOption.value,
								1,			// threads
								null,		// output dir
								null,		// target os
								null,		// target cpu
								null,		// ui prefix
								null,		// test suites
								null,		// install context
								false,		// symbol table
								false,		// disassembly
								false,		// report out of date
								pbugCommand.verboseOption.set(),
								false,		// trace
								false);		// log imports
		if (!coordinator.validate()) {
			printf("FAIL: Errors encountered trying to find and parse build scripts.\n");
			pbugCommand.help();
		}
		a := coordinator.getApplication(pbugCommand.applicationOption.value);
		if (a == null) {
			printf("Application %s not found.\n", pbugCommand.applicationOption.value);
			return 1;
		}
		printf("directory: %s\n", a.targetPath());
		exePath = a.targetPath();
	} else if (arguments.length() == 0) {
		printf("No application to run\n");
		return 1;
	} else {
		exePath = arguments[0];
		arguments.remove(0);
	}
	if (storage.isDirectory(exePath)) {
		printf("Launching application directory '%s'\n", exePath);
	} else if (!storage.exists(exePath)) {
		printf("Launching parasol script '%s'\n", exePath);
	}
	return 0;
}
