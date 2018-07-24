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
import parasol:storage;
import parasol:time;

int main(string[] args) {
	if (args.length() < 2) {
		printf( "Use is: runCurlyTests <cases> <cmd> [ <arg1> ... ]\n" +
				"    The @ character in an argument is replaced by the case directory path.\n");
		return 1;
	}
	string[] tests;

	storage.Directory d(args[0]);
	if (d.first()) {
		string[] patterns = args;
		patterns.remove(0);
		do {
			string filename = d.filename();
			if (filename == "." || filename == "..")
				continue;
			tests.append(filename);
		} while (d.next());
		printf("Read %d entries\n", tests.length());
		tests.sort(sortByNumber, true);
		printf("Sorted\n");
		for (k in tests) {
			string dir = storage.constructPath(args[0], tests[k], null);
			int exitcode;
			string output;
			process.exception_t ex;
			string[] actual;

			for (i in patterns) {
				string s;

				for (int j = 0; j < patterns[i].length(); j++) {
					if (patterns[i][j] == '@')
						s.append(dir);
					else
						s.append(patterns[i][j]);
				}
				actual.append(s);
			}

			storage.deleteFile(storage.constructPath(dir, "crash.output.txt", null));
			storage.deleteFile(storage.constructPath(dir, "errors.output.txt", null));
			(exitcode, output, ex) = process.execute(5.seconds(), actual);
			if (exitcode == 0)
				printf("%s compiled\n", dir);
			else {
				int arrow = output.indexOf("->");
				if (arrow >= 0) {
					printf("%s crashed: %d\n", dir, exitcode);
					string outFile = storage.constructPath(dir, "crash.output.txt", null);
					ref<Writer> writer = storage.createTextFile(outFile);
					writer.write(output);
					delete writer;
				} else {
					printf("%s had errors: %d\n", dir, exitcode);
					string outFile = storage.constructPath(dir, "errors.output.txt", null);
					ref<Writer> writer = storage.createTextFile(outFile);
					writer.write(output);
					delete writer;
				}
			} 
		}
	}
	return 0;
}

int sortByNumber(string a, string b) {
	int left = int.parse(a.substring(1));
	int right = int.parse(b.substring(1));
	return left - right;
}

