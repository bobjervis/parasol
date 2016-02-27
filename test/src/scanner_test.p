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
import parasol:commandLine;
import parasol:file;
import parasol:random.Random;
import parasol:compiler.FileStat;
import parasol:compiler.Location;
import parasol:compiler.Scanner;
import parasol:compiler.Token;
import native:C;

class TestCommand extends commandLine.Command {
	public TestCommand() {
		finalArguments(1, int.MAX_VALUE, "<source-filename> ...");
		description("The given filenames are scanned using the Parasol Scanner class. " +
					"Each scanned token and the reported location are stored. " +
					"Then, the token array is visited in random order and the original source is " +
					"positioned using the stored location. " +
					"If the resulting token is the same as the first scan and the reported location also " +
					"matches, then the scan is good, otherwise an error is reported." +
					"\n" +
					"Refer to the Parasol language reference manual for details on " +
					"permitted syntax."
					);
		seedArgument = stringArgument(0, "seed", "Sets the seed for the random number generator.");
		skipShuffleArgument = booleanArgument(0, "skipShuffle", "Does not shuffle the tokens before the " +
					"second pass.");
		verboseArgument = booleanArgument('v', null, "Displays all matched tokens.");
		helpArgument('?', "help",
					"Displays this help.");
	}

	ref<commandLine.Argument<string>> seedArgument;
	ref<commandLine.Argument<boolean>> skipShuffleArgument;
	ref<commandLine.Argument<boolean>> verboseArgument;
}

int seed = 1;
Random r;
TestCommand scannerTestCommand;

int main(string[] args) {
	printf("Scanner location calibration test\n");
	if (!scannerTestCommand.parse(args))
		scannerTestCommand.help();
	if (scannerTestCommand.seedArgument.set()) {
		boolean success;
		(seed, success) = int.parse(scannerTestCommand.seedArgument.value);
		if (!success) {
			printf("Unable to parse seed '%s'\n", scannerTestCommand.seedArgument.value);
			scannerTestCommand.help();
		}
	}
	r.set(seed);
	string[] files = scannerTestCommand.finalArgs();
	boolean anyFailed = false;
	for (int i = 0; i < files.length(); i++) {
		if (!scan(files[i]))
			anyFailed = true;
	}
	if (anyFailed)
		return 1;
	else
		return 0;
}

class TokenInfo {
	public Token token;
	public Location location;
	public string value;
}

boolean scan(string filename) {
	string reference;
	
	file.File reader = file.openBinaryFile(filename);
	if (reader.opened()) {
		reference = reader.readAll();
		reader.close();
	} else {
		printf("Unable to read text file %s\n", filename);
		return false;
	}

	ref<FileStat> fs = new FileStat(filename, false);
	ref<Scanner> scanner = Scanner.create(fs);
	if (!scanner.opened()) {
		printf("Unable to open file %s\n", filename);
		return false;
	}
	printf("Scanning file %s\n", filename);
	TokenInfo[] tokens; 
	for (;;) {
		TokenInfo ti;
		ti.token = scanner.next();
		if (ti.token == Token.END_OF_STREAM)
			break;
		ti.location = scanner.location();
		switch (ti.token) {
		case IDENTIFIER:
		case INTEGER:
		case FLOATING_POINT:
		case CHARACTER:
		case STRING:
		case ANNOTATION:
			ti.value = string(scanner.value().asString());
		}
		tokens.append(ti);
		// TODO: The following line is hacky, hacky, hacky - should not be needed.
		C.memset(&ti, 0, ti.bytes);
	}
	ref<Scanner> nscanner = Scanner.create(fs);
	if (!scannerTestCommand.skipShuffleArgument.value)
		shuffle(&tokens);
	for (int i = 0; i < tokens.length(); i++) {
		nscanner.seek(tokens[i].location);
		Token t = nscanner.next();
		int loc = tokens[i].location.offset;
		if (loc > reference.length())
			loc = reference.length();
		int endloc = loc + 4;
		if (endloc > reference.length())
			endloc = reference.length();
		string quot = reference.substring(loc, endloc);
		if (t != tokens[i].token) {
			printf("[%4d] Tokens (%s:%s) {%s} do not match at reported line(location) %d(%d)\n", i, string(tokens[i].token), string(t), quot, scanner.lineNumber(tokens[i].location) + 1, tokens[i].location.offset);
			return false;
		}
		switch (t) {
		case IDENTIFIER:
		case INTEGER:
		case FLOATING_POINT:
		case CHARACTER:
		case STRING:
		case ANNOTATION:
			string s = nscanner.value().asString();
			if (tokens[i].value != s) {
				printf("[%4d] Token %s does not match value: %s:%s {%s} %d(%d)\n", i, string(t), tokens[i].value, s, quot, scanner.lineNumber(tokens[i].location) + 1, tokens[i].location.offset);
				return false;
			}
		}
		if (tokens[i].location.offset != nscanner.location().offset) {
			printf("[%4d] Token %s reports different location: %d(%d) : %d(%d)\n", i, string(t), scanner.lineNumber(tokens[i].location) + 1, tokens[i].location.offset, scanner.lineNumber(nscanner.location()) + 1, nscanner.location().offset);
			return false;
		}
		if (scannerTestCommand.verboseArgument.value) {
			switch (t) {
			case IDENTIFIER:
			case INTEGER:
			case FLOATING_POINT:
			case CHARACTER:
			case STRING:
			case ANNOTATION:
				printf("[%4d] %s '%s' %d(%d)\n", i, string(t), tokens[i].value, scanner.lineNumber(nscanner.location()) + 1, nscanner.location().offset);
				break;
				
			default:
				printf("[%4d] %s %d(%d)\n", i, string(t), scanner.lineNumber(nscanner.location()) + 1, nscanner.location().offset);
			}
		}
	}
	scanner.close();
	delete scanner;
	nscanner.close();
	delete nscanner;
	delete fs;
	return true;
}

void shuffle(ref<TokenInfo[]> tokens) {
	for (int i = 0; i < tokens.length(); i++) {
		int index = r.uniform(tokens.length() - i);
		TokenInfo sv = (*tokens)[i];
		(*tokens)[i] = (*tokens)[index];
		(*tokens)[index] = sv;
	}
}