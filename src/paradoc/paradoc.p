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
import parasol:compiler;
import parasol:memory;
import parasol:storage;
import parasol:paradoc;
import parasol:process;
import parasol:runtime;
import parasol:time;

/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2018 Robert Jervis";

class Paradoc extends process.Command {
	public Paradoc() {
		finalArguments(1, int.MAX_VALUE, "<output-directory> <input-directory> ...");
		description("The given input directories are analyzed as a set of Parasol libraries. " +
					"\n" +
					"Refer to the Parasol language reference manual for details on " +
					"permitted syntax." +
					"\n" +
					"The inline documentation (paradoc) in the namespaces referenced by the sources " +
					"in the given input directories are " +
					"written as HTML pages to the output directory." +
					"\n" +
					"Parasol Runtime Version " + runtime.image.version() + "\n" +
					"Copyright (c) " + COPYRIGHT_STRING
					);
		paradoc.verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		paradoc.forceOption = booleanOption('f', "force",
					"If the output directory already exiists, delete it. Default behavior: " +
					"do not modify outputs, fail the command.");
		paradoc.validateOnlyOption = booleanOption('n', null,
					"Compile inputs and report errors, but don't write any content.");
		paradoc.symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		paradoc.logImportsOption = booleanOption(0, "logImports",
					"Log all import processing.");
		paradoc.templateDirectoryOption = stringOption('t', "template",
					"Designates a directory to treat as the source for a set of template files. " +
					"These templates fill in details of the generated HTML and can be customized " +
					"without modifying the program code.");
		paradoc.contentDirectoryOption = stringOption('c', "content",
					"Designates that the output directory named in the command line is to be " +
					"constructed by copying recursively the contents of the directory named by " +
					"this option. " +
					"Each file with a .ph extension is processed by paradoc and replaced by a file " +
					"with the same name, but with a .html extension.");
		paradoc.homeCaptionOption = stringOption('h', "home",
					"Provides the caption string that will appear in the 'home' button of " +
					"the navigation bar on every page. " +
					"Default: No home buffon will appear in the navigation bar");
		helpOption('?', "help",
					"Displays this help.");
		versionOption("version",
					"Display the version of the command.");
	}
}

private Paradoc paradocCmd;
private string[] finalArguments;

int main(string[] args) {
	if (!paradocCmd.parse(args))
		paradocCmd.help();

	finalArguments = paradocCmd.finalArguments();

	boolean anyFailure = !paradoc.compilePackages(finalArguments);
	if (paradoc.prepareOutputs(finalArguments[0])) {

		// If we are using a content directory, start from it.

		if (paradoc.contentDirectoryOption.set())
			anyFailure |= !paradoc.processContentDirectory();
		else
			anyFailure |= !paradoc.collectNamespacesToDocument();

		anyFailure |= !paradoc.generatePages();
	} else {
		printf("Could not create the output folder\n");
		anyFailure = true;
	}
	if (anyFailure) {
		printf("FAILED\n");
		return 1;
	} else {
		printf("SUCCESS!\n");
		return 0;
	}
}

