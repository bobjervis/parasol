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
ref<process.Option<string>> homeCaptionOption;
ref<process.Option<boolean>> verboseOption;
ref<process.Option<boolean>> forceOption;
ref<process.Option<boolean>> validateOnlyOption;
ref<process.Option<boolean>> logImportsOption;
ref<process.Option<boolean>> symbolTableOption;
public string codeOutputFolder;					// Folder to contain the auto-generated output (not any .ph file content).
public string contentOutputFolder;

string templateFolder;
string template1file;
string template1bFile;
string template2file;
string stylesheetPath;

public boolean prepareOutputs(string o) {
	if (validateOnlyOption.set())
		printf("*** No output will be written ***\n");
	else {
		codeOutputFolder = o;
		if (storage.exists(codeOutputFolder)) {
			if (forceOption.set()) {
				if (!storage.deleteDirectoryTree(codeOutputFolder)) {
					printf("Failed to clean up old output folder '%s'\n", codeOutputFolder);
					return false;
				}
			} else {
				printf("Output directory exists, use -f to force delete\n");
				return false;
			}
		}
		if (verboseOption.set())
			printf("Writing to %s\n", codeOutputFolder);
		if (!storage.ensure(codeOutputFolder))
			return false;
		if (contentDirectoryOption.set()) {
			contentOutputFolder = codeOutputFolder;
			codeOutputFolder = null;
		}
	}
	if (contentDirectoryOption.set())
		defineOutputDirectory(contentOutputFolder);
	else
		defineOutputDirectory(codeOutputFolder);

		// set up source file paths.

	string dir;

	if (templateDirectoryOption.set())
		dir = templateDirectoryOption.value;
	else {
		string bin = process.binaryFilename();
		
		dir = storage.path(storage.directory(bin), "../template");
	}
	string cssFile = storage.path(dir, "stylesheet.css");
	if (contentDirectoryOption.set())
		stylesheetPath = storage.path(contentOutputFolder, "stylesheet.css");
	else
		stylesheetPath = storage.path(codeOutputFolder, "stylesheet.css");
	(new Content(ContentType.FILE, cssFile, stylesheetPath)).add();
	template1file = storage.path(dir, "template1.html");
	template1bFile = storage.path(dir, "template1b.html");
	template2file = storage.path(dir, "template2.html");
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

int compareOverloadedSymbols(ref<compiler.OverloadInstance> sym1, ref<compiler.OverloadInstance> sym2) {
	return compareSymbols(ref<compiler.Symbol>(sym1), sym2);
}

int compareSymbols(ref<compiler.Symbol> sym1, ref<compiler.Symbol> sym2) {
	return sym1.name().compare(sym2.name());
}

string linkTo(ref<compiler.Symbol> sym) {
	ref<compiler.Namespace> nm;
	if (sym.class == compiler.Namespace) {
		nm = ref<compiler.Namespace>(sym);
		string nameSpace = nm.domain() + "_" + nm.dottedName();
		path = storage.path(codeOutputFolder, nameSpace);
		return storage.path(path, "namespace-summary.html");
	}
	ref<compiler.Scope> enclosing = sym.enclosing();
	string path = codeOutputFolder;

	nm = enclosing.getNamespace();
	if (nm == null)
		sym.print(0, false);
	string nameSpace = nm.domain() + "_" + nm.dottedName();
	path = storage.path(codeOutputFolder, nameSpace);
	if (sym.class == compiler.Overload) {
		ref<compiler.Overload> ov = ref<compiler.Overload>(sym);
		ref<ref<compiler.OverloadInstance>[]> inst = ov.instances();
		sym = (*inst)[0];
	}

	string classChain;
	
	for (ref<compiler.Scope> scope = sym.enclosing(); scope != null; scope = scope.enclosing()) {
		if (scope.class <= compiler.ClassScope) {
			ref<compiler.ClassScope> cs = ref<compiler.ClassScope>(scope);
			if (cs.classType == null || cs.classType.definition() == null)
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

//	assert(sym.type() != null);
	if (sym.type() == null)
		return null;
	switch (sym.type().family()) {
	case BOOLEAN:
	case SIGNED_16:
	case SIGNED_32:
	case SIGNED_64:
	case UNSIGNED_8:
	case STRING:
	case VAR:
	case CLASS:
	case REF:
	case FUNCTION:
	case ENUM:
	case FLAGS:
	case INTERFACE:
		if (classChain != null)
			path = storage.path(storage.path(path, "classes"), classChain + ".html");
		else
			path = storage.path(path, "namespace-summary.html");
		return path + "#" + sym.name();

	case TYPEDEF:
		if (classChain != null)
			path = storage.path(storage.path(path, "classes"), classChain + "." + sym.name() + ".html");
		else
			path = storage.path(storage.path(path, "classes"), sym.name() + ".html");
		return path;

	default:
		printf("sym %s %s\n", string(sym.type().family()), sym.name());
	}
	assert(false);
	return null;
}


