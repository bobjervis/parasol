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
namespace parasol:paradoc;

import parasol:compiler;
import parasol:process;
import parasol:storage;

ref<process.Option<string>> templateDirectoryOption;
ref<process.Option<boolean>> verboseOption;
ref<process.Option<boolean>> logImportsOption;
ref<process.Option<boolean>> symbolTableOption;
public string outputFolder;
string templateFolder;
string template1file;
string template1bFile;
string template2file;
string stylesheetPath;

public boolean prepareOutputs(string o) {
	outputFolder = o;
	if (storage.exists(outputFolder) && !storage.deleteDirectoryTree(outputFolder)) {
		printf("Failed to clean up old output folder '%s'\n", outputFolder);
		return false;
	}
	printf("Writing to %s\n", outputFolder);
	if (!storage.ensure(outputFolder))
		return false;

		// First set up source file paths.

	string dir;

	if (templateDirectoryOption.set())
		dir = templateDirectoryOption.value;
	else {
		string bin = process.binaryFilename();
		
		dir = storage.path(storage.directory(bin), "../template");
	}
	string cssFile = storage.path(dir, "stylesheet", "css");
	string newCss = storage.path(outputFolder, "stylesheet", "css");
	if (!storage.copyFile(cssFile, newCss))
		printf("Could not copy CSS file from %s to %s\n", cssFile, newCss);
	template1file = storage.path(dir, "template1", "html");
	template1bFile = storage.path(dir, "template1b", "html");
	template2file = storage.path(dir, "template2", "html");
	stylesheetPath = storage.path(outputFolder, "stylesheet", "css");
	templateFolder = dir;
	return true;
}

byte[], string[] parseNumbering() {
	byte[] styles;
	string[] interstitials;

	string numbering = formattingOptions["numbering"];

	int previous = 0;
	for (i in numbering) {
		switch (numbering[i]) {
		case 'A':
		case 'a':
		case 'I':
		case '1':
			if (previous < i)
				interstitials.append(numbering.substr(previous, i));
			else
				interstitials.append("");
			previous = i + 1;
			styles.append(numbering[i]);
		}
	}
	if (previous < numbering.length())
		interstitials.append(numbering.substr(previous));
	else 
		interstitials.append("");
	return styles, interstitials;
}

int endOfToken(substring s) {
	for (int i = 0; i < s.length(); i++)
		if (s[i] == ' ' ||
			s[i] == '\t' ||
			s[i] == '\n')
			return i;
	return -1;
}

public void insertTemplate1(ref<Writer> output, string myPath) {
	ref<Reader> template1 = storage.openTextFile(template1file);

	if (template1 != null) {
		string tempData = template1.readAll();

		delete template1;

		for (int i = 0; i < tempData.length(); i++) {
			if (tempData[i] == '$') {
				string path = storage.makeCompactPath(stylesheetPath, myPath);
				output.write(path);
			} else
				output.write(tempData[i]);
		}
	} else {
		printf("Could not read template1.html file from %s\n", template1file);
	}
}

public void insertTemplate2(ref<Writer> output) {
	ref<Reader> template2 = storage.openTextFile(template2file);

	if (template2 != null) {
		string tempData = template2.readAll();

		delete template2;

		output.write(tempData);
	} else
		printf("Could not read template2.html file from %s\n", template2file);
}

int compareOverloadedSymbols(ref<compiler.OverloadInstance> sym1, ref<compiler.OverloadInstance> sym2) {
	return compareSymbols(ref<compiler.Symbol>(sym1), sym2);
}

int compareSymbols(ref<compiler.Symbol> sym1, ref<compiler.Symbol> sym2) {
	return sym1.name().compare(sym2.name());
}


