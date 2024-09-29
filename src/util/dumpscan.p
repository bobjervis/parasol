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
import parasol:process;

class DumpScanCommand extends process.Command {
	public DumpScanCommand() {
		finalArguments(1, int.MAX_VALUE, "<file> ...");
		description("Produce a list of scanned tokens from a Parasol source file.");
		enableElisionOption = booleanOption('e', "elision",
				"if present, enable semi-colon elision");
		helpOption('?', "help", "Display this help.");
		versionOption("version", "Display the version of the command.");
	}

	ref<process.Option<boolean>> enableElisionOption;
}

DumpScanCommand command;

int main(string[] args) {
	if (!command.parse(args))
		command.help();
	string[] files = command.finalArguments();

	for (i in files) {
		file := files[i];
		printf("Scan of file %s:\n", file);

		fs := new compiler.Unit(file, ".");
		if (command.enableElisionOption.set())
			compiler.semiColonElision = compiler.SemiColonElision.ENABLED;
		scanner := compiler.Scanner.create(fs);
		if (!scanner.opened()) {
			printf("Unable to open file %s\n", file);
			delete scanner;
			continue;
		}
		for (;;) {
			t := scanner.next();
			if (t == compiler.Token.END_OF_STREAM)
				break;
			location := scanner.location();
			string value;
			switch (t) {
			case IDENTIFIER:
			case INTEGER:
			case FLOATING_POINT:
			case CHARACTER:
			case STRING:
			case ANNOTATION:
				value = scanner.value();
			}
			printf("[] %s ", string(t));
			switch (t){
			case IDENTIFIER:
			case INTEGER:
			case FLOATING_POINT:
			case CHARACTER:
			case STRING:
			case ANNOTATION:
				printf("'%s' ", value);
			}
			printf("@ %d(%d)\n", fs.lineNumber(location) + 1, location);
		}
		delete scanner;
		delete fs;
	}
	return 0;
}

