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
ref<process.Option<boolean>> forceOption;
ref<process.Option<boolean>> validateOnlyOption;
ref<process.Option<boolean>> logImportsOption;
ref<process.Option<boolean>> symbolTableOption;
public string outputFolder;								// Folder to contain the auto-generated output (not any .ph file content).

string templateFolder;
string template1file;
string template1bFile;
string template2file;
string stylesheetPath;

public boolean prepareOutputs(string o) {
	if (validateOnlyOption.set())
		printf("*** No output will be written ***\n");
	else {
		outputFolder = o;
		if (storage.exists(outputFolder)) {
			if (forceOption.set()) {
				if (!storage.deleteDirectoryTree(outputFolder)) {
					printf("Failed to clean up old output folder '%s'\n", outputFolder);
					return false;
				}
			} else {
				printf("Output directory exists, use -f to force delete\n");
				return false;
			}
		}
		printf("Writing to %s\n", outputFolder);
		if (!storage.ensure(outputFolder))
			return false;
	}

		// First set up source file paths.

	string dir;

	if (templateDirectoryOption.set())
		dir = templateDirectoryOption.value;
	else {
		string bin = process.binaryFilename();
		
		dir = storage.path(storage.directory(bin), "../template");
	}
	string cssFile = storage.path(dir, "stylesheet.css");
	string newCss = storage.path(outputFolder, "stylesheet.css");
	if (!validateOnlyOption.set() && !storage.copyFile(cssFile, newCss))
		printf("Could not copy CSS file from %s to %s\n", cssFile, newCss);
	template1file = storage.path(dir, "template1.html");
	template1bFile = storage.path(dir, "template1b.html");
	template2file = storage.path(dir, "template2.html");
	stylesheetPath = storage.path(outputFolder, "stylesheet.css");
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

string linkTo(ref<compiler.Symbol> sym) {
	ref<compiler.Scope> enclosing = sym.enclosing();
	string path = outputFolder;

	ref<compiler.Namespace> nm = enclosing.getNamespace();
	string nameSpace = nm.domain() + "_" + nm.dottedName();
	path = storage.path(outputFolder, nameSpace);
	if (sym.class == compiler.Overload) {
		ref<compiler.Overload> ov = ref<compiler.Overload>(sym);
		ref<ref<compiler.OverloadInstance>[]> inst = ov.instances();
		sym = (*inst)[0];
	}

	string classChain;
	
	for (ref<compiler.Scope> scope = sym.enclosing(); scope != null; scope = scope.enclosing()) {
		if (scope.class <= compiler.ClassScope) {
			ref<compiler.ClassScope> cs = ref<compiler.ClassScope>(scope);
			if (cs.classType.definition() == null)
				continue;
			ref<compiler.ClassDeclarator> cd = cs.classType.definition();
			if (cd.name() == null)
				continue;
			if (classChain == null)
				classChain = cd.name().identifier();
			else
				classChain = cd.name().identifier() + "." + classChain;
		}
	}

	if (classChain != null)
		path = storage.path(storage.path(path, "classes"), classChain);
	else
		path = storage.path(path, "namespace-summary");
//	assert(sym.type() != null);
	switch (sym.type().family()) {
	case BOOLEAN:
	case SIGNED_16:
	case SIGNED_32:
	case UNSIGNED_8:
	case STRING:
	case VAR:
	case CLASS:
	case REF:
	case FUNCTION:
	case ENUM:
		return path + ".html#" + sym.name();

	case TYPEDEF:
		return path;

	default:
		printf("sym %s %s\n", string(sym.type().family()), sym.name());
	}
	assert(false);
	return null;
}


