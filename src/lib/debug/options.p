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
namespace parasollanguage.org:debug;

import parasol:compiler;
import parasol:process;

public class PBugOptions {
	public ref<process.Option<string>> applicationOption;
	public ref<process.Option<string>> buildFileOption;
	public ref<process.Option<string>> parasolLocationOption;
	public ref<process.Option<int>> processOption;
	public ref<process.Option<string>> joinOption;
	public ref<process.Option<string>> controlOption;
	public ref<process.Option<string>> scriptOption;
	public ref<process.Option<int>> managerOption;
	public ref<process.Option<boolean>> verboseOption;
	public ref<process.Option<boolean>> elisionOption;
	public ref<process.Option<boolean>> semiOption;

	PBugOptions(ref<process.Command> command) {
		processOption = command.integerOption('p', "process", "The id of a running process that is not already " +
					"under the control of a debugger.");
		controlOption = command.stringOption('c', "control", "The URL of the default service that will act as this pbug's manager");
		managerOption = command.integerOption('m', "manager", 
					"If present, run this process as a manager, using the supplied port number.");
		applicationOption = command.stringOption('a', "application", "Names an application product described in the " +
					"build scripts to be found (using the same rules as pbuild uses to find them).");
		buildFileOption = command.stringOption('f', "file",
					"Designates the path for the build file. " +
					"If no -a or ---application option is included as well, this option has no effect. " +
					"If this option is provided, only this one build script will be loaded and searched. " +
					"Default: Apply the search algorithm described for pbuild.");
		scriptOption = command.stringOption('s', "script",
					"Designated the path for a script file describing a test scenario,. "+
					"If this option is provided, the arguments are not interpreted directly as command-line options but are instead " +
					"interpreted as arguments to the test script.")
		verboseOption = command.booleanOption('v', null,
					"Enables verbose output.")
		parasolLocationOption = command.stringOption(0, "location", "The location of the Parasol runtime to use. " +
					"This is useful when debugging a script rather than a compiled application.");
		joinOption = command.stringOption('j', "join",
					"Join a running debug session. The string argument is the host:port identity of a running debug session.");
		elisionOption = command.booleanOption('e', "elide", "Enables semi-colon elision (default " + string(compiler.semiColonElision) + ")");
		semiOption = command.booleanOption(0, "semi-colon", "Disables semi-colon elision (default " + string(compiler.semiColonElision) + ")");
	}

	public string[] copiedOptions() {
		string[] copy;
		if (processOption.set()) {
			copy.append("-p");
			copy.append(string(processOption.value));
		}
		if (applicationOption.set()) {
			copy.append("-a");
			copy.append(applicationOption.value);
		}
		if (buildFileOption.set()) {
			copy.append("-f");
			copy.append(buildFileOption.value);
		}
		if (verboseOption.set())
			copy.append("-v");
		if (elisionOption.set())
			copy.append("-e");
		if (semiOption.set())
			copy.append("--semi-colon");
		if (parasolLocationOption.set())
			copy.append("--location=" + parasolLocationOption.value);
		return copy;
	}
}
