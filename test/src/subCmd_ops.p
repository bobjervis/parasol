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

public int main(string[] args) {
	return test.run(args);
}

TestCommand test;

class TestCommand extends process.Command {
	TestCommand() {
		commandName("test command-line");
		description("This is a test program that illustrates how the Parasol " +
					"command-line processing class operates.");
		finalArguments(1, int.MAX_VALUE, "[ <arguments ]");
		helpArgument('?', "help",
				"Displays this help.");

		subCommand("sub1", &sub1);
		subCommand("sub2", &sub2);
	}

	Sub1Command sub1;
	Sub2Command sub2;

}

class Sub1Command extends process.Command {
	Sub1Command() {
		description("Tests that we can distinguish one sub-command from another.");
		finalArguments(0, 0, "");
		setter = booleanArgument('s', "setter", "A boolean flag to detect");
	}

	ref<process.Argument<boolean>> setter;

	public int main(string[] args) {
		assert(setter.set());
		return 0;
	}
}

class Sub2Command extends process.Command {
	Sub2Command() {
		description("Tests that we can distinguish one sub-command from another.");
		finalArguments(0, 0, "");
		getter = booleanArgument('g', "getter", "A boolean flag to detect");
	}

	ref<process.Argument<boolean>> getter;

	public int main(string[] args) {
		assert(getter.set());
		return 0;
	}
}
