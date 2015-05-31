import parasol:commandLine;

class TestCommand extends commandLine.Command {
	ref<commandLine.Argument<string>> aStringArgument;
	ref<commandLine.Argument<boolean>> aBooleanArgument;

	public TestCommand() {
		finalArguments(1, 2, "parameter [ TEST-STRING-2 ]");
		description("Test the command-line parsing library.");
		aStringArgument = stringArgument('S', "aString", 
					"Sets a string argument.");
		aBooleanArgument = booleanArgument('B', "aBoolean",
					"Sets a boolean argument.");
		helpArgument('?', "help", "Displays this help.");
	}

}

private TestCommand testCommand;

int main(string[] args) {
	if (!testCommand.parse(args)) {
		print("Arguments parse failed\n");
		return 7;
	}
	print("Arguments parse succeeded\n");
	string[] params = testCommand.finalArgs();
	pointer<long> xp = pointer<long>(&params);
	if (params.length() == 2) {
		if (params[1] != "TEST-STRING-2")
			return 2;
	}
	if (testCommand.aBooleanArgument.value) {
		if (testCommand.aStringArgument.set()) {
			if (testCommand.aStringArgument.value != params[0])
				return 3;
		} else {
			if ("boolean-true-no-string-disallowed" == params[0])
				return 5;
		}
	} else {
		if (testCommand.aStringArgument.set()) {
			if (testCommand.aStringArgument.value == params[0])
				return 4;
		} else {
			if ("boolean-false-no-string-disallowed" == params[0])
				return 6;
		}
	}
	return 0;
}
