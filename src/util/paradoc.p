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
import parasol:compiler.BuiltInType;
import parasol:compiler.Class;
import parasol:compiler.CompileContext;
import parasol:compiler.Doclet;
import parasol:compiler.EnumInstanceType;
import parasol:compiler.FileStat;
import parasol:compiler.FlagsInstanceType;
import parasol:compiler.FunctionType;
import parasol:compiler.Identifier;
import parasol:compiler.ImportDirectory;
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
string stylesheetPath;

map<string, long> classFiles;

Arena arena;

int main(string[] args) {
	parseCommandLine(args);
	outputFolder = finalArgs[0];

	if (storage.exists(outputFolder)) {
//		printf("Output directory '%s' exists, cannot over-write.\n", outputFolder);
//		outputFolder = null;
//		anyFailure = true;
	}

	if (!configureArena(&arena))
		return 1;
	CompileContext context(&arena, arena.global(), paradocCommand.verboseArgument.value);

	for (int i = 1; i < finalArgs.length(); i++)
		libraries.append(arena.compilePackage(i - 1, &context));
	arena.finishCompilePackages(&context);

	// We are now done with compiling, time to analyze the results

	if (paradocCommand.symbolTableArgument.value)
		arena.printSymbolTable();
	if (paradocCommand.verboseArgument.value)
		arena.print();
	boolean anyFailure = false;
	if (arena.countMessages() > 0) {
		printf("Failed to compile\n");
		arena.printMessages();
		anyFailure = true;
	}
	if (outputFolder != null) {
		printf("Writing to %s\n", outputFolder);
		if (storage.ensure(outputFolder)) {
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
			stylesheetPath = storage.constructPath(outputFolder, "stylesheet", "css");
			if (!collectNamespacesToDocument())
				anyFailure = true;
			if (!indexTypes())
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
	arena.paradoc = true;
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

boolean indexTypes() {
	for (i in names) {
		string dirName = names[i].name;
		for (int i = 0; i < dirName.length(); i++)
			if (dirName[i] == ':')
				dirName[i] = '_';
		string nmPath = storage.constructPath(outputFolder, dirName, null);
		indexTypesFromNamespace(names[i].name, names[i].symbol, nmPath);
	}
	return true;
}

void indexTypesFromNamespace(string name, ref<Namespace> nm, string dirName) {
	string overviewPage = storage.constructPath(dirName, "namespace-summary", "html");
//	printf("Creating %s\n", dirName);
	if (!storage.ensure(dirName)) {
		printf("Could not create directory '%s'\n", dirName);
		process.exit(1);
	}

	string classesDir = storage.constructPath(dirName, "classes", null);

	indexTypesInScope(nm.symbols(), classesDir, overviewPage);
}

void indexTypesInClass(ref<Symbol> sym, string dirName) {
	ref<Scope> scope = scopeFor(sym);
	if (scope == null)
		return;
	if (sym.definition() != scope.className()) {
		ref<Type> t = typeFor(sym);
		if (t.family() != TypeFamily.TEMPLATE)
			return;
	}
	string name = sym.name().asString();
	string classFile = storage.constructPath(dirName, name, "html");
	if (!storage.ensure(dirName)) {
		printf("Could not ensure directory %s\n", dirName);
		process.exit(1);
	}

	if (classFiles[long(scope)] == null)
		classFiles[long(scope)] = classFile;

	string subDir = storage.constructPath(dirName, name, null);

	indexTypesInScope(scope, subDir, classFile);
}

void indexTypesInScope(ref<Scope> symbols, string dirName, string baseName) {
	ref<ref<Symbol>[Scope.SymbolKey]> symMap = symbols.symbols();

	ref<Symbol>[] classes;

	for (i in *symMap) {
		ref<Symbol> sym = (*symMap)[i];

		if (sym.class == PlainSymbol) {
			if (sym.visibility() != Operator.PUBLIC)
				continue;
			ref<Type> type = sym.type();
			switch (type.family()) {
			case CLASS:
			case INTERFACE:
			case TYPEDEF:
				classes.append(sym);
				break;
			}
		} else if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			ref<ref<OverloadInstance>[]> instances = o.instances();
			for (j in *instances) {
				ref<OverloadInstance> oi = (*instances)[j];

				if (oi.visibility() != Operator.PUBLIC)
					continue;
				if (o.kind() != Operator.FUNCTION)
					classes.append(oi);
			}
		}

	}

	for (i in classes) {
		ref<Symbol> sym = classes[i];

		indexTypesInClass(sym, dirName);
	}
}

boolean generateNamespaceDocumentation() {
	for (i in libraries) {
		printf("[%d] Library %s\n", i, libraries[i].directoryName());
	}
	string overviewPage = storage.constructPath(outputFolder, "index", "html");
	ref<Writer> overview = storage.createTextFile(overviewPage);

	insertTemplate1(overview, overviewPage);

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
		ref<Symbol> sym = names[i].symbol;
		ref<Doclet> doclet = sym.doclet();
		if (doclet != null)
			overview.write(doclet.summary);
		overview.write("</td>\n");
		overview.write("</tr>\n");
		generateNamespaceSummary(names[i].name, names[i].symbol);
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

void generateNamespaceSummary(string name, ref<Namespace> nm) {
	string dirName = namespaceFile(nm);
	if (!storage.ensure(dirName)) {
		printf("Could not create directory '%s'\n", dirName);
		process.exit(1);
	}
	string overviewPage = storage.constructPath(dirName, "namespace-summary", "html");
	ref<Writer> overview = storage.createTextFile(overviewPage);

	insertTemplate1(overview, overviewPage);

	overview.printf("<title>%s</title>\n", name);
	overview.write("<body>\n");
	overview.printf("<div class=namespace-title>Namespace %s</div>\n", name);

	ref<Doclet> doclet = nm.doclet();
	if (doclet != null)
		overview.printf("<div class=namespace-text>%s</div>\n", doclet.text);

	string classesDir = storage.constructPath(dirName, "classes", null);

	generateScopeContents(nm.symbols(), overview, classesDir, overviewPage, 
								"Object", "Function", "INTERNAL ERROR", false, false);

	delete overview;
}

string namespaceReference(ref<Namespace> nm) {
	string path = namespaceFile(nm);
	string s;
	s.printf("<a href=\"%s\">%s</a>", path, nm.fullNamespace());
	return s;
}

string namespaceFile(ref<Namespace> nm) {
	string s;
	string dirName = nm.fullNamespace();
	for (int i = 0; i < dirName.length(); i++)
		if (dirName[i] == ':')
			dirName[i] = '_';
	return storage.constructPath(outputFolder, dirName, null);
}

boolean generateClassPage(ref<Symbol> sym, string name, string dirName) {
	ref<Scope> scope = scopeFor(sym);
	if (scope == null) {
		printf("No type or scope for %s / %s\n", dirName, name);
		return false;
	}
	string classFile = storage.constructPath(dirName, name, "html");
	if (!storage.ensure(dirName)) {
		printf("Could not ensure directory %s\n", dirName);
		process.exit(1);
	}
	ref<Writer> classPage = storage.createTextFile(classFile);
	if (classPage == null) {
		printf("Could not create class file %s\n", classFile);
		process.exit(1);
	}

	insertTemplate1(classPage, classFile);

	classPage.printf("<title>%s</title>\n", name);
	classPage.write("<body>\n");

	ref<Namespace> nm = sym.enclosingNamespace();

	classPage.printf("<div class=namespace-info><b>Namespace</b> %s</div>\n", namespaceReference(nm));
	ref<Type> t = typeFor(sym);
	boolean isInterface;
	boolean hasConstants;
	string enumLabel;
	switch (t.family()) {
	case	INTERFACE:
		classPage.printf("<div class=class-title>Interface %s</div>", name);
		isInterface = true;
		enumLabel = "INTERNAL ERROR";
		break;

	case	FLAGS:
		hasConstants = true;
		classPage.printf("<div class=class-title>Flags %s</div>", name);
		enumLabel = "Flags";
		break;

	case	ENUM:
		hasConstants = true;
		classPage.printf("<div class=class-title>Enum %s</div>", name);
		enumLabel = "Enum";
		break;

	default:
		classPage.printf("<div class=class-title>%sClass %s", t.isConcrete(null) ? "" : "Abstract ", name);
		if (t.family() == TypeFamily.TEMPLATE) {
			classPage.write("&lt;");
			ref<ParameterScope> p = ref<ParameterScope>(t.scope());
			ref<ref<Symbol>[]> params = p.parameters();
			for (i in *params) {
				ref<Symbol> sym = (*params)[i];
				if (i > 0)
					classPage.write(", ");
				classPage.printf("%s %s", typeString(sym.type(), classFile), sym.name().asString());
			}
			classPage.write("&gt;");
		}
		classPage.printf("</div>\n");
		classPage.printf("<div class=class-hierarchy>");
		generateBaseClassName(classPage, t, classFile, false);
		classPage.printf("</div>\n");
		ref<ref<InterfaceType>[]> interfaces = t.interfaces();
		if (interfaces != null && interfaces.length() > 0) {
			printf("Got one: %s\n", name);
			classPage.write("<div class=impl-iface-caption>All implemented interfaces:</div>\n");
			classPage.write("<div class=impl-ifaces>\n");
			for (i in *interfaces) {
				ref<Type> iface = (*interfaces)[i];

				classPage.write(typeString(iface, classFile));
				classPage.write('\n');
			}
			classPage.write("</div>\n");
		}
	}
	ref<Doclet> doclet = sym.doclet();
	if (doclet != null)
		classPage.printf("<div class=class-text>%s</div>\n", doclet.text);

	string subDir = storage.constructPath(dirName, name, null);

	generateScopeContents(scope, classPage, subDir, classFile, "Member", "Method", enumLabel, isInterface, hasConstants);

	delete classPage;
	return true;
}

int generateBaseClassName(ref<Writer> output, ref<Type> t, string baseName, boolean includeLink) {
	if (t == null)
		return 0;
	int indent = generateBaseClassName(output, t.getSuper(), baseName, true);
	string n = fullyQualifiedClassName(t, baseName, includeLink);
	if (n == null)
		return indent;
	for (int i = 0; i < indent; i++)
		output.write(' ');
	if (t.isMonitorClass())
		output.write("monitor class ");
	output.write(n);
	output.write('\n');
	return indent + 4;
}

string fullyQualifiedClassName(ref<Type> t, string baseName, boolean includeLink) {
	ref<Scope> scope = t.scope();
	if (scope == null)
		return typeString(t, baseName);

	ref<Namespace> nm = scope.getNamespace();
	if (nm == null)
		return typeString(t, baseName);
	string s;
	if (includeLink) {
		string classFile = classFiles[long(scope)];
		if (classFile == null)
			return null;
		string url = storage.makeCompactPath(classFile, baseName);
		s.printf("<a href=\"%s\">", url);
	}
	s.printf("%s.%s", nm.fullNamespace(), qualifiedName(t));
	if (includeLink)
		s.printf("</a>");
	return s;
}

string qualifiedName(ref<Type> t) {
	ref<Scope> scope = t.scope();
	if (scope == null)
		return null;
	ref<Type> e = scope.enclosing().enclosingClassType();
	string s;
//	printf("qualifiedName e = %s\n", e != null ? e.signature() : "<null>");
	if (e != null)
		s = qualifiedName(e) + ".";
	ref<Node> definition = scope.definition();
	switch (definition.op()) {
	case	CLASS:
	case	MONITOR_CLASS:
		s.append(ref<Class>(definition).name().value().asString());
		break;

	case	TEMPLATE:
		s.append(ref<Template>(definition).name().value().asString());
		break;

	default:
		definition.print(0);
		assert(false);
	}
	return s;
}

void generateScopeContents(ref<Scope> scope, ref<Writer> output, string dirName, string baseName, string objectLabel, string functionLabel, string enumLabel, boolean isInterface, boolean hasConstants) {
	ref<ref<Symbol>[Scope.SymbolKey]> symMap = scope.symbols();

	ref<OverloadInstance>[] constructors;
	ref<OverloadInstance>[] functions;
	ref<Symbol>[] enumConstants;
	ref<Symbol>[] enums;
	ref<Symbol>[] objects;
	ref<Symbol>[] interfaces;
	ref<Symbol>[] classes;
	ref<Symbol>[] exceptions;

	for (i in *symMap) {
		ref<Symbol> sym = (*symMap)[i];

		if (sym.class == PlainSymbol) {
			ref<Type> type = sym.type();
			if (!isInterface && 
				sym.visibility() != Operator.PUBLIC &&
				sym.visibility() != Operator.PROTECTED) {
				switch (type.family()) {
				case	ENUM:
				case	FLAGS:
					if (hasConstants)
						enumConstants.append(sym);
					break;
				}
				continue;
			}
			switch (type.family()) {
			case INTERFACE:
				interfaces.append(sym);
				break;

			case FLAGS:
			case ENUM:
				break;

			case TYPEDEF:
				type = type.wrappedType();
				if (type == null)
					break;
				if (type.isException())
					exceptions.append(sym);
				else if (type.family() == TypeFamily.ENUM ||
						 type.family() == TypeFamily.FLAGS)
					enums.append(sym);
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

				if (!isInterface && oi.visibility() != Operator.PUBLIC && oi.visibility() != Operator.PROTECTED)
					continue;
				if (o.kind() == Operator.FUNCTION)
					functions.append(oi);
				else
					classes.append(oi);
			}
		}

	}

	ref<ref<ParameterScope>[]> constructorScopes = scope.constructors();

	for (i in *constructorScopes) {
		ref<ParameterScope> ps = (*constructorScopes)[i];
		ref<OverloadInstance> sym = ps.symbol();
		if (sym != null && (sym.visibility() == Operator.PUBLIC || sym.visibility() == Operator.PROTECTED))
			constructors.append(sym);
	}

	if (enumConstants.length() > 0) {
		output.write("<table class=\"overviewSummary\">\n");
		output.printf("<caption><span>%s Constants Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n", enumLabel);
		output.write("<tr>\n");
		output.write("<th class=\"linkcol\">Constant</th>\n");
		output.write("<th class=\"descriptioncol\">Description</th>\n");
		output.write("</tr>\n");
		output.write("<tbody>\n");
		enumConstants.sort(compareSymbols, true);
		for (i in enumConstants) {
			ref<Symbol> sym = enumConstants[i];
			output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			ref<Type> type = sym.type();
			output.printf("<td class=\"linkcol\"><a href=\"#%s\"\">%s</a></td>\n", sym.name().asString(), sym.name().asString());
			output.write("<td class=\"descriptioncol\">");
			output.write("</td>\n");
			output.write("</tr>\n");
		}
		output.write("</tbody>\n");
		output.write("</table>\n");
	}

	if (enums.length() > 0) {
		output.write("<table class=\"overviewSummary\">\n");
		output.write("<caption><span>Flags and Enums Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		output.write("<tr>\n");
		output.write("<th class=\"linkcol\">Type</th>\n");
		output.write("<th class=\"descriptioncol\">Description</th>\n");
		output.write("</tr>\n");
		output.write("<tbody>\n");
		enums.sort(compareSymbols, true);
		for (i in enums) {
			ref<Symbol> sym = enums[i];
			generateClassSummaryEntry(output, i, sym, dirName, baseName);
		}
		output.write("</tbody>\n");
		output.write("</table>\n");
	}

	if (objects.length() > 0) {
		output.write("<table class=\"overviewSummary\">\n");
		output.printf("<caption><span>%s Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n", objectLabel);
		output.write("<tr>\n");
		output.write("<th class=\"linkcol\">Type</th>\n");
		output.write("<th class=\"descriptioncol\">Object and Description</th>\n");
		output.write("</tr>\n");
		output.write("<tbody>\n");
		objects.sort(compareSymbols, true);
		for (i in objects) {
			ref<Symbol> sym = objects[i];

			output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			ref<Type> type = sym.type();
			output.printf("<td class=\"linkcol\">%s</td>\n", typeString(type, baseName));
			output.write("<td class=\"descriptioncol\">");
			output.printf("<a href=\"#%s\"><span class=code>%s</span></a><br>", sym.name().asString(), sym.name().asString());
			output.write("</td>\n");
			output.write("</tr>\n");
		}
		output.write("</tbody>\n");
		output.write("</table>\n");
	}

	if (constructors.length() > 0)
		functionSummary(output, &constructors, true, "Constructor", baseName);

	if (functions.length() > 0)
		functionSummary(output, &functions, false, functionLabel, baseName);

	if (interfaces.length() > 0) {
		output.write("<table class=\"overviewSummary\">\n");
		output.write("<caption><span>Interface Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		output.write("<tr>\n");
		output.write("<th class=\"linkcol\">Interface</th>\n");
		output.write("<th class=\"descriptioncol\">Description</th>\n");
		output.write("</tr>\n");
		output.write("<tbody>\n");
		interfaces.sort(compareSymbols, true);
		for (i in interfaces) {
			ref<Symbol> sym = interfaces[i];
			generateClassSummaryEntry(output, i, sym, dirName, baseName);
		}
		output.write("</tbody>\n");
		output.write("</table>\n");
	}

	if (classes.length() > 0) {
		output.write("<table class=\"overviewSummary\">\n");
		output.write("<caption><span>Class Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		output.write("<tr>\n");
		output.write("<th class=\"linkcol\">Class</th>\n");
		output.write("<th class=\"descriptioncol\">Description</th>\n");
		output.write("</tr>\n");
		output.write("<tbody>\n");
		classes.sort(compareSymbols, true);
		for (i in classes) {
			ref<Symbol> sym = classes[i];
			generateClassSummaryEntry(output, i, sym, dirName, baseName);
		}
		output.write("</tbody>\n");
		output.write("</table>\n");
	}

	if (exceptions.length() > 0) {
		output.write("<table class=\"overviewSummary\">\n");
		output.write("<caption><span>Exception Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n");
		output.write("<tr>\n");
		output.write("<th class=\"linkcol\">Class</th>\n");
		output.write("<th class=\"descriptioncol\">Description</th>\n");
		output.write("</tr>\n");
		output.write("<tbody>\n");
		exceptions.sort(compareSymbols, true);
		for (i in exceptions) {
			ref<Symbol> sym = exceptions[i];
			generateClassSummaryEntry(output, i, sym, dirName, baseName);
		}
		output.write("</tbody>\n");
		output.write("</table>\n");
	}

	if (enumConstants.length() > 0) {
		output.printf("<div class=block>\n");
		output.printf("<div class=block-header>%s Constants Detail</div>\n", enumLabel);
		for (i in enumConstants) {
			ref<Symbol> sym = enumConstants[i];
			string name = sym.name().asString();

			output.printf("<a id=\"%s\"></a>\n", name);
			output.printf("<div class=entity>%s</div>\n", name);
			output.printf("<div class=declaration>public static final %s %s</div>\n", typeString(sym.type(), baseName), name);
		}
		output.printf("</div>\n");
	}

	if (objects.length() > 0) {
		output.printf("<div class=block>\n");
		output.printf("<div class=block-header>%s Detail</div>\n", objectLabel);
		for (i in objects) {
			ref<Symbol> sym = objects[i];
			string name = sym.name().asString();

			output.printf("<a id=\"%s\"></a>\n", name);
			output.printf("<div class=entity>%s</div>\n", name);
			output.printf("<div class=declaration>");
			ref<Type> type = sym.type();
			switch (sym.visibility()) {
			case	PUBLIC:
				output.write("public ");
				break;

			case	PROTECTED:
				output.write("protected ");
				break;
			}
			if (sym.storageClass() == StorageClass.STATIC && sym.enclosing().storageClass() != StorageClass.STATIC)
				output.printf("static ");
			output.printf("%s %s</div>\n", typeString(type, baseName), name);
		}
		output.printf("</div>\n");
	}

	if (constructors.length() > 0)
		functionDetail(output, &constructors, true, "Constructor", baseName);

	if (functions.length() > 0)
		functionDetail(output, &functions, false, functionLabel, baseName);
}

void functionSummary(ref<Writer> output, ref<ref<OverloadInstance>[]> functions, boolean asConstructors, string functionLabel, string baseName) {
	output.write("<table class=\"overviewSummary\">\n");
	output.printf("<caption><span>%s Summary</span><span class=\"tabEnd\">&nbsp;</span></caption>\n", functionLabel);
	output.write("<tr>\n");
	if (asConstructors)
		output.write("<th class=\"linkcol\">Qualifier</th>\n");
	else
		output.write("<th class=\"linkcol\">Return Type(s)</th>\n");
	output.write("<th class=\"descriptioncol\">Function and Description</th>\n");
	output.write("</tr>\n");
	output.write("<tbody>\n");
	functions.sort(compareOverloadedSymbols, true);
	for (i in *functions) {
		ref<NodeList> nl;
		ref<OverloadInstance> sym = (*functions)[i];
		ref<FunctionType> ft = ref<FunctionType>(sym.type());
		output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
		output.write("<td class=\"linkcol\">");
		if (asConstructors) {
			switch (sym.visibility()) {
			case	PUBLIC:
				output.write("public ");
				break;
	
			case	PROTECTED:
				output.write("protected");
				break;
			}
		} else {
			nl = ft.returnType();
			if (nl == null)
				output.write("void");
			else {
				while (nl != null) {
					output.printf("%s", typeString(nl.node.type, baseName));
					if (nl.next != null)
						output.write(", ");
					nl = nl.next;
				}
			}
		}
		output.write("</td>\n<td>");
		output.printf("<span class=code><a href=\"#%s\">%s</a>(", sym.name().asString(), sym.name().asString());
		nl = ft.parameters();
		ref<ParameterScope> scope = ft.functionScope();
		ref<ref<Symbol>[]> parameters = scope.parameters();
		int j = 0;
		while (nl != null) {
			if (nl.node.getProperEllipsis() != null)
				output.printf("%s...", typeString(nl.node.type.elementType(), baseName));
			else
				output.printf("%s", typeString(nl.node.type, baseName));
			if (parameters != null && parameters.length() > j)
				output.printf(" %s", (*parameters)[j].name().asString());
			else
				output.write(" ???");
			if (nl.next != null)
				output.write(", ");
			nl = nl.next;
			j++;
		}
		output.write(")</span>");
		ref<Doclet> doclet = sym.doclet();
		if (doclet != null)
			output.printf("\n<div class=descriptioncol>%s</div>", doclet.summary);
		output.write("</td>\n");
		output.write("</tr>\n");
	}
	output.write("</tbody>\n");
	output.write("</table>\n");
}

void functionDetail(ref<Writer> output, ref<ref<OverloadInstance>[]> functions, boolean asConstructors, string functionLabel, string baseName) {
	output.printf("<div class=block>\n");
	output.printf("<div class=block-header>%s Detail</div>\n", functionLabel);
	for (i in *functions) {
		ref<OverloadInstance> sym = (*functions)[i];
		string name = sym.name().asString();

		output.printf("<a id=\"%s\"></a>\n", name);
		output.printf("<div class=entity>%s</div>\n", name);
		output.printf("<div class=declaration>");
		switch (sym.visibility()) {
		case	PUBLIC:
			output.write("public ");
			break;

		case	PROTECTED:
			output.write("protected ");
			break;
		}
		if (!sym.isConcrete(null))
			output.write("abstract ");
		ref<NodeList> nl;
		ref<FunctionType> ft = ref<FunctionType>(sym.type());
		if (!asConstructors) {
			nl = ft.returnType();
			if (nl == null)
				output.write("void");
			else {
				while (nl != null) {
					output.printf("%s", typeString(nl.node.type, baseName));
					if (nl.next != null)
						output.write(", ");
					nl = nl.next;
				}
			}
			output.write(' ');
		}
		output.printf("%s(", name);
		nl = ft.parameters();
		ref<ParameterScope> scope = ft.functionScope();
		ref<ref<Symbol>[]> parameters = scope.parameters();
		int j = 0;
		while (nl != null) {
			if (nl.node.getProperEllipsis() != null)
				output.printf("%s...", typeString(nl.node.type.elementType(), baseName));
			else
				output.printf("%s", typeString(nl.node.type, baseName));
			if (parameters != null && parameters.length() > j)
				output.printf(" %s", (*parameters)[j].name().asString());
			else
				output.write(" ???");
			if (nl.next != null)
				output.write(",\n                ");
			nl = nl.next;
			j++;
		}
		output.write(")\n</div>\n");
		ref<Doclet> doclet = sym.doclet();
		if (doclet != null)
			output.printf("\n<div class=func-description>%s</div>", doclet.text);
	}
	output.write("</div>\n");
}

void generateTypeSummaryEntry(ref<Writer> output, int i, ref<Symbol> sym, string dirName, string baseName) {
	ref<Scope> scope = scopeFor(sym);
	if (scope == null)
		return;
	output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");

	string name = sym.name().asString();
	ref<Type> t = sym.type();
	output.printf("<td class=\"linkcol\">");
	switch (t.family()) {
	case	ENUM:
		output.write(typeString(t, baseName));
		break;

	default:
		output.printf("??? %s", typeString(t, baseName));
	}
	output.printf("</td>\n");

	output.write("<td class=\"descriptioncol\">");
	output.write("</td>\n");
	output.write("</tr>\n");
}

void generateClassSummaryEntry(ref<Writer> output, int i, ref<Symbol> sym, string dirName, string baseName) {
	ref<Scope> scope = scopeFor(sym);
	if (scope == null)
		return;
	output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");

	string name = sym.name().asString();
	if (sym.definition() == scope.className()) {
		if (!generateClassPage(sym, name, dirName))
			return;
	}
	ref<Type> t = typeFor(sym);
	switch (t.family()) {
	case	TEMPLATE:
	case	ENUM:
	case	FLAGS:
		if (!generateClassPage(sym, name, dirName))
			return;
	}
	output.printf("<td class=\"linkcol\">");
	if (sym.definition() != scope.className() && t.family() != TypeFamily.TEMPLATE)
		output.printf("%s = ", name);
	output.printf("%s</td>\n", typeString(sym.type(), baseName));

	output.write("<td class=\"descriptioncol\">");
	ref<Doclet> doclet = sym.doclet();
	if (doclet != null)
		output.write(doclet.summary);
	output.write("</td>\n");
	output.write("</tr>\n");
}

int compareSymbols(ref<Symbol> sym1, ref<Symbol> sym2) {
	return sym1.name().compare(*sym2.name());
}

int compareOverloadedSymbols(ref<OverloadInstance> sym1, ref<OverloadInstance> sym2) {
	return compareSymbols(ref<Symbol>(sym1), sym2);
}

string typeString(ref<Type> type, string baseName) {
	switch (type.family()) {
	case	UNSIGNED_8:
	case	UNSIGNED_16:
	case	UNSIGNED_32:
	case	UNSIGNED_64:
	case	SIGNED_8:
	case	SIGNED_16:
	case	SIGNED_32:
	case	SIGNED_64:
	case	FLOAT_32:
	case	FLOAT_64:
	case	BOOLEAN:
	case	ADDRESS:
	case	VAR:
	case	CLASS:
	case	INTERFACE:
	case	STRING:
	case	EXCEPTION:
		string t = type.signature();
		string classFile = classFiles[long(type.scope())];
		if (classFile == null)
			return t;
		string url = storage.makeCompactPath(classFile, baseName);
		return "<a href=\"" + url + "\">" + t + "</a>";

	case	POINTER:
		ref<var[]> args = ref<TemplateInstanceType>(type).arguments();
		return "pointer&lt;" + typeString(ref<Type>((*args)[0]), baseName) + "&gt;";

	case	REF:
		args = ref<TemplateInstanceType>(type).arguments();
		return "ref&lt;" + typeString(ref<Type>((*args)[0]), baseName) + "&gt;";

	case	FUNCTION:
		ref<FunctionType> ft = ref<FunctionType>(type);
		string f;

		ref<NodeList> nl = ft.returnType();
		if (nl == null)
			f.append("void");
		else {
			f.append(typeString(nl.node.type, baseName));
			nl = nl.next;
			while (nl != null) {
				f.append(", ");
				f.append(typeString(nl.node.type, baseName));
				nl = nl.next;
			}
		}
		f.append(" (");
		nl = ft.parameters();
		if (nl != null) {
			f.append(typeString(nl.node.type, baseName));
			nl = nl.next;
			while (nl != null) {
				f.append(", ");
				if (nl.node.getProperEllipsis() != null) {
					f.append(typeString(nl.node.type.elementType(), baseName));
					f.append("...");
				} else
					f.append(typeString(nl.node.type, baseName));
				nl = nl.next;
			}
		}			
		f.append(")");
		return f;

	case	TYPEDEF:
		return typeString(type.wrappedType(), baseName);

	case	TEMPLATE:
		classFile = classFiles[long(type.scope())];
		if (classFile == null)
			return null;
		url = storage.makeCompactPath(classFile, baseName);
		ref<TemplateType> template = ref<TemplateType>(type);
		string s = "<a href=\"" + url + "\">" + template.definingSymbol().name().asString() + "</a>";
		s.append("&lt;");
		ref<ParameterScope> p = ref<ParameterScope>(template.scope());
		ref<ref<Symbol>[]> params = p.parameters();
		for (i in *params) {
			ref<Symbol> sym = (*params)[i];
			if (i > 0)
				s.append(", ");
			s.printf("%s %s", typeString(sym.type(), baseName), sym.name().asString());
		}
		s.append("&gt;");
		return s;

	case	CLASS_DEFERRED:
		return "class";

	case	FLAGS:
		classFile = classFiles[long(type.scope())];
		if (classFile == null)
			return null;
		url = storage.makeCompactPath(classFile, baseName);
		sym = ref<FlagsInstanceType>(type).symbol();
		name = sym.name().asString();
		s.printf("<a href=\"%s\">%s</a>", url, name);
		return s;

	case	ENUM:
		classFile = classFiles[long(type.scope())];
		if (classFile == null)
			return null;
		url = storage.makeCompactPath(classFile, baseName);
		ref<Symbol> sym = ref<EnumInstanceType>(type).symbol();
		string name = sym.name().asString();
		s.printf("<a href=\"%s\">%s</a>", url, name);
		return s;

	case	SHAPE:
		ref<Type> e = type.elementType();
		ref<Type> i = type.indexType();
		if (arena.isVector(type)) {
			s = typeString(e, baseName);
			if (i != arena.builtInType(TypeFamily.SIGNED_32))
				s.printf("[%s]", typeString(i, baseName));
			else
				s.append("[]");
			return s;
		} else {
			// maps are a little more complicated. A map based on an integral type has to be declared as map<e, i>
			// while a map of a non-integral type canbe written as e[i].
			if (arena.validMapIndex(i))
				s.printf("%s[%s]", typeString(e, baseName), typeString(i, baseName));
			else
				s.printf("map&lt;%s, %s&gt;", typeString(e, baseName), typeString(i, baseName));
			return s;
		}

	default:
		return type.signature() + "/" + string(type.family());
	}
	return type.signature();
}

ref<Scope> scopeFor(ref<Symbol> sym) {
	ref<Type> t = sym.type();
	if (t == null)
		return null;
	if (t.family() == TypeFamily.TYPEDEF)
		t = ref<TypedefType>(t).wrappedType();
	return t.scope();
}

ref<Type> typeFor(ref<Symbol> sym) {
	ref<Type> t = sym.type();
	if (t == null)
		return null;
	if (t.family() == TypeFamily.TYPEDEF)
		t = ref<TypedefType>(t).wrappedType();
	return t;
}

void insertTemplate1(ref<Writer> output, string myPath) {
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

