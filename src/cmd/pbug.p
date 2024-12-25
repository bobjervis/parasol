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
import parasol:storage;

import parasollanguage.org:debug;
import parasollanguage.org:debug.manager;
import parasollanguage.org:debug.controller;
import parasollanguage.org:cli;
/**
	The pbug command is part of a larger debugger architecture.

	The Parasol debugging environment involves several inter-locking components:
<ul>
	<li>A UI in the form of an application or browser page capable of showing source code. 
		While this UI could be a full-blown IDE, that is not necessary.
	<li>The pbug --monitor command. In principle, each process being debugged has an associated pbug process instance
		monitoring it's activity.
	<li>The pbug --control command. One instance of this constitutes a single 'debug session' that may be controlling
		multiple, distributed processes. 
		It communicates with the UI using a web socket.
</ul>
 */
class PBugCommand extends process.Command {
	public PBugCommand() {
		finalArguments(0, int.MAX_VALUE, "[ directory | mainfile ] [ arguments ... ]");
		description("pbug - Parasol Debugging Utility.\n" +
					"This program is a debug monitor that runs or attaches to a running process. " +
					"If debugging multiple-processes, there will be one controller for each process so managed." +
					"\n" +
					"If either the -a or --application options are included, the process to be debugged " +
					"is found by searching the build scripts for a product by that name. " +
					"In this way you don't have to find the executable image and type its path to start an " +
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
		options = new debug.PBugOptions(this);
		helpOption('?', "help",
					"Displays this help.");
		versionOption("version", "Display the version of the pbug app.");
	}

	ref<debug.PBugOptions> options;

}

PBugCommand pbugCommand;

public int main(string[] args) {
	if (!pbugCommand.parse(args))
		pbugCommand.help();
	if (pbugCommand.options.processOption.set()) {
		printf("Attaching to a running process is not yet supported.\n");
		return 1;
	}
	arguments := pbugCommand.finalArguments();
	printf("Arguments:\n");
	for (i in arguments)
		printf("arguments[%d] '%s'\n", i, arguments[i]);
	string exePath;
	scriptPath := pbugCommand.options.scriptOption.value
	if (pbugCommand.options.scriptOption.set()) {
		if (pbugCommand.options.applicationOption.set()) {
			printf("FAIL: Cannot specify both a script and application option.\n")
			return 1
		}
		if (!storage.exists(scriptPath)) {
			printf("FAIL: specified script file %s does not exist.\n", scriptPath)
			return 1
		}
	} else if (pbugCommand.options.applicationOption.set()) {
		// This is all kind of gross. 
		pbuild.BuildOptions buildOptions;
		buildOptions.buildFileOption = process.Command.defaultStringOption();
		buildOptions.buildFileOption.setValue(pbugCommand.options.buildFileOption.value);
		buildOptions.verboseOption = process.Command.defaultBooleanOption();
		if (pbugCommand.options.verboseOption.set())
			buildOptions.verboseOption.setValue("true");
		buildOptions.buildThreadsOption = process.Command.defaultIntOption();
		buildOptions.buildThreadsOption.setValue("1");
		buildOptions.setOptionDefaults();

		pbuild.Coordinator coordinator(&buildOptions);
		if (!coordinator.validate()) {
			printf("FAIL: Errors encountered trying to find and parse build scripts.\n");
			pbugCommand.help();
		}
		a := coordinator.getApplication(pbugCommand.options.applicationOption.value);
		if (a == null) {
			printf("Application %s not found.\n", pbugCommand.options.applicationOption.value);
			return 1;
		}
		if (!a.verify()) {
			printf("Application %s cannot be verified, cannot run it.\n", pbugCommand.options.applicationOption.value);
			return 1;
		}
		exePath = a.targetPath();
	} else if (arguments.length() == 0) {
		// Launching the manager with no arguments is fine.
		if (!pbugCommand.options.managerOption.set()) {
			printf("No application to run\n");
			return 1;
		}
	} else {
		exePath = arguments[0];
		arguments.remove(0);
		if (!storage.exists(exePath)) {
			printf("Executable path '%s' does not exist\n", exePath);
			return 1;
		}
	}

	if (pbugCommand.options.controlOption.set()) {
		return controller.run(pbugCommand.options, exePath, arguments);
	}

	if (pbugCommand.options.managerOption.set()) {
		return manager.run(pbugCommand.options, exePath, arguments);
	}

	return cli.run(pbugCommand.options, exePath, arguments);
/*
	if (storage.isDirectory(exePath)) {
		printf("Launching application directory '%s'\n", exePath);
		if (!pbuild.Application.verify(exePath)) {
			printf("Application directory %s cannot be verified, cannot run it.\n", exePath);
			return 1;
		}
		debug.spawnApplication(pbugCommand.options.applicationOption.value, exePath, arguments);
	} else if (storage.exists(exePath))
		debug.spawnParasolScript(pbugCommand.options.parasolLocationOption.value, exePath, arguments);
	else {
		printf("Not a valid script: %s\n", exePath);
		return 1;
	}
	cli.consoleUI();
	return 0;
 */
}
