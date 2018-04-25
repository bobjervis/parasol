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
import parasol:storage;
import parasol:process;
import parasol:runtime;
import parasol:compiler.Arena;
import parasol:compiler.FileStat;
import parasol:compiler.FunctionType;
import parasol:compiler.ImportDirectory;
import parasol:compiler.Namespace;
import parasol:compiler.NodeList;
import parasol:compiler.Operator;
import parasol:compiler.Overload;
import parasol:compiler.OverloadInstance;
import parasol:compiler.ParameterScope;
import parasol:compiler.PlainSymbol;
import parasol:compiler.Scope;
import parasol:compiler.Symbol;
import parasol:compiler.Type;
import parasol:compiler.TypeFamily;
import parasol:time;

/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2018 Robert Jervis";

class ParadocCommand extends process.Command {
	public ParadocCommand() {
		finalArguments(2, int.MAX_VALUE, "<output-directory> <input-directory> ...");
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
		importPathArgument = stringArgument('I', "importPath", 
					"Sets the path of directories like the --explicit option, " +
					"but the directory ^/src/lib is appended to " +
					"those specified with this option.");
		verboseArgument = booleanArgument('v', null,
					"Enables verbose output.");
		symbolTableArgument = booleanArgument(0, "syms",
					"Print the symbol table.");
		logImportsArgument = booleanArgument(0, "logImports",
					"Log all import processing");
		explicitArgument = stringArgument('X', "explicit",
					"Sets the path of directories to search for imported symbols. " +
					"Directories are separated by commas. " +
					"The special directory ^ can be used to signify the Parasol " +
					"install directory. ");
		rootArgument = stringArgument(0, "root",
					"Designates a specific directory to treat as the 'root' of the install tree. " +
					"The default is the parent directory of the runtime binary program.");
		templateDirectoryArgument = stringArgument('t', "template",
					"Designates a directory to treat as the source for a set of template files. " +
					"These templates fill in details of the generated HTML and can be customized " +
					"without modifying the program code.");
		helpArgument('?', "help",
					"Displays this help.");
	}

	ref<process.Argument<string>> importPathArgument;
	ref<process.Argument<boolean>> verboseArgument;
	ref<process.Argument<string>> explicitArgument;
	ref<process.Argument<string>> rootArgument;
	ref<process.Argument<boolean>> logImportsArgument;
	ref<process.Argument<boolean>> symbolTableArgument;
	ref<process.Argument<string>> templateDirectoryArgument;
}

private ref<ParadocCommand> paradocCommand;
private string[] finalArgs;
string outputFolder;
ref<ImportDirectory>[] libraries;

string corpusTitle = "Parasol Documentation";

string template1file;
string template1bFile;
string template2file;

int main(string[] args) {
	parseCommandLine(args);
	outputFolder = finalArgs[0];

	if (storage.exists(outputFolder)) {
//		printf("Output directory '%s' exists, cannot over-write.\n", outputFolder);
//		outputFolder = null;
//		anyFailure = true;
	}

	Arena arena;

	if (!configureArena(&arena))
		return 1;
	for (int i = 1; i < finalArgs.length(); i++)
		libraries.append(arena.compilePackage(i - 1, paradocCommand.verboseArgument.value));
	if (paradocCommand.symbolTableArgument.value)
		arena.printSymbolTable();
	if (paradocCommand.verboseArgument.value) {
		arena.print();
	}
	boolean anyFailure = false;
	if (arena.countMessages() > 0) {
		printf("Failed to compile\n");
		arena.printMessages();
		anyFailure = true;
	}
	if (outputFolder != null) {
		if (paradocCommand.templateDirectoryArgument.set()) {
			string dir = paradocCommand.templateDirectoryArgument.value;

			string cssFile = storage.constructPath(dir, "stylesheet", "css");
			string newCss = storage.constructPath(outputFolder, "stylesheet", "css");
			if (!storage.copyFile(cssFile, newCss))
				printf("Could not copy CSS file from %s to %s\n", cssFile, newCss);
			template1file = storage.constructPath(dir, "template1", "html");
			template1bFile = storage.constructPath(dir, "template1b", "html");
			template2file = storage.constructPath(dir, "template2", "html");
		}
		printf("Writing to %s\n", outputFolder);
		if (storage.ensure(outputFolder)) {
			if (!collectNamespacesToDocument())
				anyFailure = true;
			if (!generateNamespaceDocumentation())
				anyFailure = true;
		} else {
			printf("Could not create the output folder\n");
			anyFailure = true;
		}
	}
	if (anyFailure)
		return 1;
	else
		return 0;
}

void parseCommandLine(string[] args) {
	paradocCommand = new ParadocCommand();
	if (!paradocCommand.parse(args))
		paradocCommand.help();
	if (paradocCommand.importPathArgument.set() &&
		paradocCommand.explicitArgument.set()) {
		printf("Cannot set both --explicit and --importPath arguments.\n");
		paradocCommand.help();
	}
	finalArgs = paradocCommand.finalArgs();
}

boolean configureArena(ref<Arena> arena) {
	arena.logImports = paradocCommand.logImportsArgument.value;
	if (paradocCommand.rootArgument.set())
		arena.setRootFolder(paradocCommand.rootArgument.value);
	string importPath;

	for (int i = 1; i < finalArgs.length(); i++) {
		importPath.append(finalArgs[i]);
		importPath.append(',');
	}
	if (paradocCommand.explicitArgument.set())
		importPath.append(paradocCommand.explicitArgument.value);
	else if (paradocCommand.importPathArgument.set())
		importPath.append(paradocCommand.importPathArgument.value + ",^/src/lib");
	else
		importPath.append(",^/src/lib");
	arena.setImportPath(importPath);
	arena.verbose = paradocCommand.verboseArgument.value;
	if (arena.logImports)
		printf("Running with import path: %s\n", arena.importPath());
	if (arena.load())
		return true;
	else {
		arena.printMessages();
		if (paradocCommand.verboseArgument.value)
			arena.print();
		printf("Failed to load arena\n");
		return false;
	}
}

class Names {
	string name;
	ref<Namespace> symbol;

	public int compare(Names other) {
		return name.compare(other.name);
	}
}

ref<Namespace>[string] nameMap;

Names[] names;

boolean collectNamespacesToDocument() {
	for (i in libraries) {
		int fileCount = libraries[i].fileCount();
		for (int j = 0; j < fileCount; j++) {
			ref<FileStat> f = libraries[i].file(j);
			if (f.hasNamespace()) {
				string nameSpace = f.getNamespaceString();
				ref<Namespace> nm;
				boolean alreadyExists;

				nm = nameMap[nameSpace];
				if (nm != null)
					alreadyExists = true;
				else {
					nm = f.namespaceSymbol();
					nameMap[nameSpace] = nm;
					Names item;
					item.name = nameSpace;
					item.symbol = nm;
					names.append(item);
				}
			}
		}
	}
	names.sort();
	return true;
}

boolean generateNamespaceDocumentation() {
	for (i in libraries) {
		printf("[%d] Library %s\n", i, libraries[i].directoryName());
	}
	string overviewPage = storage.constructPath(outputFolder, "default", "html");
	ref<Writer> overview = storage.createTextFile(overviewPage);

	ref<Reader> template1 = storage.openTextFile(template1file);

	if (template1 != null) {
		string tempData = template1.readAll();

		delete template1;

		overview.write(tempData);
	} else {
		printf("Could not read template1.html file from %s\n", template1file);
	}

	overview.printf("<title>%s</title>\n", corpusTitle);
	overview.write("<body>\n");
	overview.write("<table class=\"overviewSummary\">\n");
	overview.write("<caption><span>Namespaces</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
	overview.write("<tr>\n");
	overview.write("<th class=\"linkcol\">Namespace</th>\n");
	overview.write("<th class=\"descriptioncol\">Description</th>\n");
	overview.write("</tr>\n");
	overview.write("<tbody>\n");
	for (i in names) {
//		printf("[%d] %s\n", i, names[i].name);

		string dirName = names[i].name;
		for (int i = 0; i < dirName.length(); i++)
			if (dirName[i] == ':')
				dirName[i] = '_';

		overview.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
		overview.printf("<td class=\"linkcol\"><a href=\"%s/namespace-summary.html\">%s</a></td>\n", dirName, names[i].name);
		overview.write("<td class=\"descriptioncol\">");
		overview.write("</td>\n");
		overview.write("</tr>\n");
		string nmPath = storage.constructPath(outputFolder, dirName, null);
		generateNamespaceSummary(names[i].name, names[i].symbol, nmPath);
	}
	overview.write("</tbody>\n");
	overview.write("</table>\n");

	ref<Reader> template2 = storage.openTextFile(template2file);

	if (template2 != null) {
		string tempData = template2.readAll();

		delete template2;

		overview.write(tempData);
	} else
		printf("Could not read template2.html file from %s\n", template2file);

	delete overview;
	return true;
}

void generateNamespaceSummary(string name, ref<Namespace> nm, string dirName) {
	string overviewPage = storage.constructPath(dirName, "namespace-summary", "html");
//	printf("Creating %s\n", dirName);
	if (!storage.ensure(dirName)) {
		printf("Could not create directory '%s'\n", dirName);
		process.exit(1);
	}
	ref<Scope> symbols = nm.symbols();
	ref<ref<Symbol>[Scope.SymbolKey]> symMap = symbols.symbols();

	ref<OverloadInstance>[] functions;
	ref<Symbol>[] objects;
	ref<Symbol>[] interfaces;
	ref<Symbol>[] classes;
	ref<Symbol>[] exceptions;

	for (i in *symMap) {
		ref<Symbol> sym = (*symMap)[i];

		if (sym.class == PlainSymbol) {
			if (sym.visibility() != Operator.PUBLIC)
				continue;
			ref<Type> type = sym.type();
			switch (type.family()) {
			case INTERFACE:
				interfaces.append(sym);
				break;

			case TYPEDEF:
				type = type.wrappedType();
				if (type == null)
					break;
				if (type.isException())
					exceptions.append(sym);
				else if (type.family() == TypeFamily.INTERFACE)
					interfaces.append(sym);
				else
					classes.append(sym);
				break;

			default:
				objects.append(sym);
			}
		} else if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			ref<ref<OverloadInstance>[]> instances = o.instances();
			for (j in *instances) {
				ref<OverloadInstance> oi = (*instances)[j];

				if (oi.visibility() != Operator.PUBLIC)
					continue;
				if (o.kind() == Operator.FUNCTION)
					functions.append(oi);
				else
					classes.append(oi);
			}
		}

	}

	ref<Writer> overview = storage.createTextFile(overviewPage);

	ref<Reader> template1 = storage.openTextFile(template1bFile);

	if (template1 != null) {
		string tempData = template1.readAll();

		delete template1;

		overview.write(tempData);
	} else {
		printf("Could not read template1.html file from %s\n", template1file);
	}

	overview.printf("<title>%s</title>\n", name);
	overview.write("<body>\n");

	if (objects.length() > 0) {
		overview.write("<table class=\"overviewSummary\">\n");
		overview.write("<caption><span>Object Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		overview.write("<tr>\n");
		overview.write("<th class=\"linkcol\">Type</th>\n");
		overview.write("<th class=\"descriptioncol\">Object and Description</th>\n");
		overview.write("</tr>\n");
		overview.write("<tbody>\n");
		objects.sort(compareSymbols, true);
		for (i in objects) {
			ref<Symbol> sym = objects[i];

			overview.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			ref<Type> type = sym.type();
			overview.printf("<td class=\"linkcol\">%s</td>\n", typeString(type));
			overview.write("<td class=\"descriptioncol\">");
			overview.printf("<a href=\"#%s\"><span class=code>%s</span></a><br>", sym.name().asString(), sym.name().asString());
			overview.write("</td>\n");
			overview.write("</tr>\n");
		}
		overview.write("</tbody>\n");
		overview.write("</table>\n");
	}

	if (functions.length() > 0) {
		overview.write("<table class=\"overviewSummary\">\n");
		overview.write("<caption><span>Function Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		overview.write("<tr>\n");
		overview.write("<th class=\"linkcol\">Return Type(s)</th>\n");
		overview.write("<th class=\"descriptioncol\">Function and Description</th>\n");
		overview.write("</tr>\n");
		overview.write("<tbody>\n");
		functions.sort(compareOverloadedSymbols, true);
		for (i in functions) {
			ref<OverloadInstance> sym = functions[i];
			ref<FunctionType> ft = ref<FunctionType>(sym.type());
			overview.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			overview.write("<td class=\"linkcol\">");
			ref<NodeList> nl = ft.returnType();
			if (nl == null)
				overview.write("void");
			else {
				while (nl != null) {
					overview.printf("%s", typeString(nl.node.type));
					if (nl.next != null)
						overview.write(", ");
					nl = nl.next;
				}
			}
			overview.write("</td>\n<td class=\"descriptioncol\">");
			overview.printf("<span class=code><a href=\"#%s\">%s</a>(", sym.name().asString(), sym.name().asString());
			nl = ft.parameters();
			ref<ParameterScope> scope = ft.functionScope();
			ref<ref<Symbol>[]> parameters = scope.parameters();
			int j = 0;
			while (nl != null) {
				overview.printf("%s", typeString(nl.node.type));
				if (parameters != null && parameters.length() > j)
					overview.printf(" %s", (*parameters)[j].name().asString());
				else
					overview.write(" ???");
				if (nl.next != null)
					overview.write(", ");
				nl = nl.next;
				j++;
			}
			overview.write(")</span><br>\n");
			overview.write("</td>\n");
			overview.write("</tr>\n");
		}
		overview.write("</tbody>\n");
		overview.write("</table>\n");
	}

	if (interfaces.length() > 0) {
		overview.write("<table class=\"overviewSummary\">\n");
		overview.write("<caption><span>Interface Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		overview.write("<tr>\n");
		overview.write("<th class=\"linkcol\">Interface</th>\n");
		overview.write("<th class=\"descriptioncol\">Description</th>\n");
		overview.write("</tr>\n");
		overview.write("<tbody>\n");
		interfaces.sort(compareSymbols, true);
		for (i in interfaces) {
			ref<Symbol> sym = interfaces[i];

			overview.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			overview.printf("<td class=\"linkcol\"><a href=\"#%s\">%s</a></td>\n", sym.name().asString(), sym.name().asString());
			overview.write("<td class=\"descriptioncol\">");
			overview.write("</td>\n");
			overview.write("</tr>\n");
		}
		overview.write("</tbody>\n");
		overview.write("</table>\n");
	}

	if (classes.length() > 0) {
		overview.write("<table class=\"overviewSummary\">\n");
		overview.write("<caption><span>Class Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		overview.write("<tr>\n");
		overview.write("<th class=\"linkcol\">Class</th>\n");
		overview.write("<th class=\"descriptioncol\">Description</th>\n");
		overview.write("</tr>\n");
		overview.write("<tbody>\n");
		classes.sort(compareSymbols, true);
		for (i in classes) {
			ref<Symbol> sym = classes[i];

			overview.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			overview.printf("<td class=\"linkcol\"><a href=\"#%s\">%s</a></td>\n", sym.name().asString(), sym.name().asString());
			overview.write("<td class=\"descriptioncol\">");
			overview.write("</td>\n");
			overview.write("</tr>\n");
		}
		overview.write("</tbody>\n");
		overview.write("</table>\n");
	}

	if (exceptions.length() > 0) {
		overview.write("<table class=\"overviewSummary\">\n");
		overview.write("<caption><span>Exception Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		overview.write("<tr>\n");
		overview.write("<th class=\"linkcol\">Class</th>\n");
		overview.write("<th class=\"descriptioncol\">Description</th>\n");
		overview.write("</tr>\n");
		overview.write("<tbody>\n");
		exceptions.sort(compareSymbols, true);
		for (i in exceptions) {
			ref<Symbol> sym = exceptions[i];

			overview.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			overview.printf("<td class=\"linkcol\"><a href=\"#%s\">%s</a></td>\n", sym.name().asString(), sym.name().asString());
			overview.write("<td class=\"descriptioncol\">");
			overview.write("</td>\n");
			overview.write("</tr>\n");
		}
		overview.write("</tbody>\n");
		overview.write("</table>\n");
	}

	delete overview;
}

int compareSymbols(ref<Symbol> sym1, ref<Symbol> sym2) {
	return sym1.name().compare(*sym2.name());
}

int compareOverloadedSymbols(ref<OverloadInstance> sym1, ref<OverloadInstance> sym2) {
	return compareSymbols(ref<Symbol>(sym1), sym2);
}

string typeString(ref<Type> type) {
	if (type.family() == TypeFamily.TYPEDEF)
		return typeString(type.wrappedType());
	return type.signature();
}



