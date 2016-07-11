/*
   Copyright 2015 Rovert Jervis

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
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <process.h>
#include "basic_types.h"
#include "pxi.h"
#include "common/command_line.h"
#include "common/file_system.h"
#include "common/platform.h"
/*
 *	Parasol engine architecture:
 *
 *		Runtime executes a runnable object
 *		
 */
class ParasolCommand : public commandLine::Command {
public:
	ParasolCommand() {
		finalArguments(0, INT_MAX, "<filename> [arguments ...]");
		description("The given filename is run as a pxi image or if --test is supplied as a unit test script. "
					"Any command-line arguments appearing after are passed "
					"to any main function in that file."
					"\n"
					"Parasol Runtime Version " RUNTIME_VERSION "\r"
					"Copyright (c) " COPYRIGHT_STRING
					);
		leaksArgument = booleanArgument(0, "leaks", "Check for memory leaks.");
		verboseArgument = booleanArgument('v', null,
					"Enables verbose output.");
		traceArgument = booleanArgument(0, "trace",
					"Trace execution of each instruction (byte code targets only).");
		helpArgument('?', "help",
					"Displays this help.");
	}

	commandLine::Argument<bool> *verboseArgument;
	commandLine::Argument<bool> *traceArgument;
	commandLine::Argument<bool> *leaksArgument;
};

static ParasolCommand parasolCommand;

static void parseCommandLine(int argc, char **argv);
static int runCommand();

int main(int argc, char **argv) {
	platform::setup();
	parseCommandLine(argc, argv);
	return runCommand();
}

void parseCommandLine(int argc, char **argv) {
	if (!parasolCommand.parse(argc, argv) ||
		parasolCommand.finalArgc() == 0)
		parasolCommand.help();
}

int runCommand() {
	long long runtimeFlags = 0;
	if (parasolCommand.leaksArgument->value())
		runtimeFlags |= 1;
	if (parasolCommand.traceArgument->value())
		runtimeFlags |= 2;
	char **args = parasolCommand.finalArgv();
	int returnValue;
	pxi::Pxi* pxi = pxi::Pxi::load(args[0]);
	if (pxi == null) {
		printf("Failed to load %s\n", args[0]);
		return 1;
	}
	if (pxi->run(args, &returnValue, runtimeFlags))
		return returnValue;
	else {
		printf("Unable to run pxi %s\n", args[0]);
		return 1;
	}
}
