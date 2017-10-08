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
// Binary differencer
import parasol:process;
import parasol:file;

class BDiffCommand extends process.Command {
	public BDiffCommand() {
		finalArguments(2, 2, "<file1> <file2>");
		description("Compares two binary files.");
		helpArgument('?', "help", "Display this help.");
	}
}

BDiffCommand command;

int main(string[] args) {
	if (!command.parse(args))
		command.help();
	string[] files = command.finalArgs();
	file.File left = file.openBinaryFile(files[0]);
	file.File right = file.openBinaryFile(files[1]);
	
	boolean allGood = true;
	if (!left.opened()) {
		printf("Could not open file '%s'\n", files[0]);
		allGood = false;
	}
	if (!right.opened()) {
		printf("Could not open file '%s'\n", files[1]);
		allGood = false;
	}
	if (!allGood)
		return 1;
	left.seek(0, file.Seek.END);
	int sizeLeft = left.tell();
	right.seek(0, file.Seek.END);
	int sizeRight = right.tell();
	if (sizeLeft != sizeRight) {
		printf("Files have different sizes: %s (%d) %s (%d)\n", files[0], sizeLeft, files[1], sizeRight);
		return 1;
	}
	left.seek(0, file.Seek.START);
	right.seek(0, file.Seek.START);
	int offset = 0;
	boolean differences = false;
	for (;;) {
		int xLeft = left.read();
		if (xLeft == file.EOF)
			break;
		int xRight = right.read();
		if (xLeft != xRight) {
			printf("Files differ at offset %d(%x): %2.2x %2.2x\n", offset, offset, xLeft, xRight);
			differences = true;
		}
		offset++;
	}
	if (!differences)
		printf("Files are identical.\n");
	return differences ? 1 : 0;
}