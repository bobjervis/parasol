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
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "library/pxi.h"
#include "common/command_line.h"
#include "common/file_system.h"
#include "common/platform.h"
/*
 * Date and Copyright holder of this code base.
 */
#define COPYRIGHT_STRING "2015 Robert Jervis"
/*
 * Major Release: Incremented when a breaking change is released
 * Minor Feature Release: Incremented when significant new features
 * are released.
 * Fix Release: Incremented when big fixes are released.
 */
#define RUNTIME_VERSION "1.0.0"

class ParasolCommand : public commandLine::Command {
public:
	ParasolCommand() {
		finalArguments(0, INT_MAX, "<filename> [arguments ...]");
		description("The given filename is run as a pxi image. "
					"Any command-line arguments appearing after are passed "
					"to any main function in that file."
					"\n"
					"Parasol Runtime Version " RUNTIME_VERSION "\r"
					"Copyright (c) " COPYRIGHT_STRING
					);
		leaksArgument = booleanArgument(0, "leaks", "Check for memory leaks.");
		verboseArgument = booleanArgument('v', null,
					"Enables verbose output.");
		helpArgument('?', "help",
					"Displays this help.");
	}

	commandLine::Argument<bool> *verboseArgument;
	commandLine::Argument<bool> *leaksArgument;
};

static ParasolCommand parasolCommand;

static void parseCommandLine(int argc, char **argv);
static int runCommand();
/*
 * The C++ code of the Parasol runtime is primarily in a shared object, so that symbols can be looked up (a
 * requirement of the Parasol native binding machenaism..
 *
 * As a result, this executable just does the most basic command line parsing and then loads the PXI argument
 * and runs it.
 */
int main(int argc, char **argv) {
	platform::setup();
	if (!parasolCommand.parse(argc, argv) ||
		parasolCommand.finalArgc() == 0)
		parasolCommand.help();
	long long runtimeFlags = 0;
	if (parasolCommand.leaksArgument->value())
		runtimeFlags |= 1;
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
