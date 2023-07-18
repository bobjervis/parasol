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
import parasol:compiler.BuiltInType;
import parasol:compiler.ClassDeclarator;
import parasol:compiler.CompileContext;
import parasol:compiler.Doclet;
import parasol:compiler.EnumInstanceType;
import parasol:compiler.FlagsInstanceType;
import parasol:compiler.FunctionType;
import parasol:compiler.Identifier;
import parasol:compiler.InterfaceType;
import parasol:compiler.Namespace;
import parasol:compiler.Node;
import parasol:compiler.NodeList;
import parasol:compiler.Operator;
import parasol:compiler.Overload;
import parasol:compiler.OverloadInstance;
import parasol:compiler.ParameterScope;
import parasol:compiler.PlainSymbol;
import parasol:compiler.Scope;
import parasol:compiler.StorageClass;
import parasol:compiler.Symbol;
import parasol:compiler.Type;
import parasol:compiler.Template;
import parasol:compiler.TemplateType;
import parasol:compiler.TemplateInstanceType;
import parasol:compiler.TypedefType;
import parasol:compiler.TypeFamily;
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
					"Parasol Runtime Version " + runtime.RUNTIME_VERSION + "\r" +
					"Copyright (c) " + COPYRIGHT_STRING
					);
		paradoc.verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		paradoc.symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		paradoc.logImportsOption = booleanOption(0, "logImports",
					"Log all import processing");
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
		helpOption('?', "help",
					"Displays this help.");
	}
}

private ref<Paradoc> paradocCmd;
private string[] finalArguments;

int main(string[] args) {
	parseCommandLine(args);

//	printf("Configuring\n");
	boolean anyFailure = !paradoc.configureArena(finalArguments);
	printf("configureArena anyFailure=%s\n", string(anyFailure));
//	printf("Done!\n");
	if (paradoc.prepareOutputs(finalArguments[0])) {
		// Also do internal processing of the symbol table.

		anyFailure |= !paradoc.collectNamespacesToDocument();
	printf("collectNamespacesToDocument anyFailure=%s\n", string(anyFailure));

		// If we ar e using a content directory, start from it.

		if (paradoc.contentDirectoryOption.set())
			anyFailure |= !paradoc.processContentDirectory();
	printf("processContentDirectory anyFailure=%s\n", string(anyFailure));

		anyFailure |= !paradoc.generateNamespaceDocumentation();
	printf("generateNamespaceDocumentation anyFailure=%s\n", string(anyFailure));
	} else {
		printf("Could not create the output folder\n");
		anyFailure = true;
	}
	printf("anyFailure=%s\n", string(anyFailure));
	if (anyFailure)
		return 1;
	else
		return 0;
}

void parseCommandLine(string[] args) {
	paradocCmd = new Paradoc();
	if (!paradocCmd.parse(args))
		paradocCmd.help();
	finalArguments = paradocCmd.finalArguments();
}

