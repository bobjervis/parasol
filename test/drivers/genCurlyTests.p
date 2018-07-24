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
import parasol:storage;

string base;
string cases;
string[] dirs;

int nextTest = 1;

string currentDir;
string currentFile;

int main(string[] args) {
	if (args.length() < 3) {
		printf( "Use is: getCurlyTests <base> <cases> <dir> ...\n" +
				"    base - names the source from which to copy tests.\n" +
				"    bases - names the directory into which test cases are to be generated.\n" +
				"    dir - each dir names a subdirectory of <base> that will be scanned and copied.\n\n" +
				"Each .p file in the named sub-directories is canned and one case is created for each\n" +
				"left or right curly brace encountered. All files in the named sub-directories are copied,\n" +
				"except for the one curly brace found. The result is a set of case directories, each with\n" +
				"one injected error condition (assuming that the base directory compiles.\n");
		return 1;
	}
	base = args[0];
	cases = args[1];
	dirs = args;
	dirs.remove(0, 2);

	if (!storage.isDirectory(base)) {
		printf("'%s' is not a directory or is not accessible by you.\n", base);
		return 1;
	}
	for (i in dirs) {
		string subDir = storage.constructPath(base, dirs[i], null);
		if (!storage.isDirectory(subDir)) {
			printf("'%s' is not a sub-directory or is not accessible by you.\n", dirs[i]);
			return 1;
		}
	}
	if (!storage.ensure(cases)) {
		printf("Cannot create directory '%s'\n", cases);
		return 1;
	}
	storage.deleteDirectoryTree(cases);
	if (!storage.ensure(cases)) {
		printf("Cannot create directory '%s'\n", cases);
		return 1;
	}

	for (i in dirs) {
		currentDir = dirs[i];
		string subDir = storage.constructPath(base, dirs[i], null);
		ref<storage.Directory> d = new storage.Directory(subDir);
		if (d.first()) {
			do {
				string path = d.path();
				if (path.endsWith(".p")) {
					currentFile = d.filename();
					if (!scanFileContents(path))
						printf("Cannot open '%s'\n", path);
				}
			} while (d.next());
			delete d;
		}
	}
	printf("\n");
	return 0;
}

boolean scanFileContents(string path) {
	ref<Reader> reader = storage.openTextFile(path);
	if (reader == null)
		return false;
//	printf("%s\n", path);
	string contents = reader.readAll();
	delete reader;
	if (contents == null)
		return true;
	compiler.StringScanner scanner(contents, 1, path);
	for (;;) {
		compiler.Token t = scanner.next();
		switch (t) {
		case END_OF_STREAM:
			return true;

		case LEFT_CURLY:
		case RIGHT_CURLY:
			int loc = scanner.byteLocation();
			string casename = "c" + string(nextTest);
			string casedir = storage.constructPath(cases, casename, null);

			if (!storage.ensure(casedir)) {
				printf("\nCould not create case dir '%s'\n", casedir);
				return true;
			}
			for (i in dirs) {
				string src = storage.constructPath(base, dirs[i], null);
				string dest = storage.constructPath(casedir, dirs[i], null);
				if (!storage.ensure(storage.directory(dest))) {
					printf("\nCould not create dest dir '%s'\n", storage.directory(dest));
					return true;
				}
				if (storage.exists(dest)) {
					printf("\nDestination already exists! '%s'\n", dest);
					return true;
				}
				if (!storage.copyDirectoryTree(src, dest, true)) {
//					storage.deleteDirectoryTree(casedir);
					printf("\nCould not copy %s to %s\n", src, dest);
					process.exit(1);
				}
			}
			string testcase = storage.constructPath(casedir, currentDir, null);
			testcase = storage.constructPath(testcase, currentFile, null);
			ref<Writer> writer = storage.createTextFile(testcase);
			if (writer == null) {
				printf("\nCould not create %s\n", testcase);
				return true;
			}
			writer.write(&contents[0], loc);
			writer.write(&contents[loc + 1], contents.length() - loc - 1);
			delete writer;
			printf("Case %s written for file %s/%s location %d                           \r", casedir, currentDir, currentFile, loc);
			process.stdout.flush();
			nextTest++;
//			process.exit(0);
		}
	}
}

