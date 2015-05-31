#include <limits.h>
#include <stdio.h>
#include <string.h>
#include "basic_types.h"
#include "pxi.h"
#include "common/command_line.h"
#include "common/common_test.h"
#include "common/file_system.h"
#include "common/platform.h"
#include "common/script.h"
#include "test/test.h"
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
		verboseArgument = booleanArgument('v', null,
					"Enables verbose output.");
		traceArgument = booleanArgument(0, "trace",
					"Trace execution of each instruction (byte code targets only).");
		helpArgument('?', "help",
					"Displays this help.");
	}

	commandLine::Argument<bool> *verboseArgument;
	commandLine::Argument<bool> *traceArgument;
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
	char **args = parasolCommand.finalArgv();
	int returnValue;
	pxi::Pxi* pxi = pxi::Pxi::load(args[0]);
	if (pxi == null) {
		printf("Failed to load %s\n", args[0]);
		return 1;
	}
	if (pxi->run(args, &returnValue, parasolCommand.traceArgument->value()))
		return returnValue;
	else {
		printf("Unable to run pxi %s\n", args[0]);
		return 1;
	}
}
