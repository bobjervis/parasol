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

class TestCommand extends process.Command {
	ref<process.Argument<string>> aStringArgument;
	ref<process.Argument<boolean>> aBooleanArgument;

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
		printf("Arguments parse failed\n");
		return 7;
	}
	printf("Arguments parse succeeded\n");
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
