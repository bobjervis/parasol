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
import parasol:context;
import parasol:process;
import parasol:runtime;
import parasol:storage;

string corpusTitle = "Parasol Documentation";

runtime.Arena arena;
ref<compiler.CompileContext> compileContext;

class Names {
	string name;
	ref<compiler.Namespace> symbol;

	public int compare(Names other) {
		return name.compare(other.name);
	}
}

ref<compiler.Namespace>[string] nameMap;

Names[] names;

public boolean configureArena(string[] finalArguments) {
	arena.paradoc = true;
	arena.verbose = verboseOption.value;
	compileContext = new compiler.CompileContext(&arena, verboseOption.value, logImportsOption.value);
	if (!compileContext.loadRoot(false))
		return false;
	ref<context.Context> activeContext = arena.activeContext();

	string[] unitFilenames;
	for (int i = 1; i < finalArguments.length(); i++) {
		ref<context.Package> package = activeContext.getPackage(finalArguments[i]);
		if (package != null) {
			unitFilenames.append(package.getUnitFilenames());
		} else
			printf("Could not find package %s\n", finalArguments[i]);
	}
	compileContext.compilePackage(unitFilenames, "none");

	// We are now done with compiling, time to analyze the results

	if (symbolTableOption.value)
		arena.printSymbolTable();
	if (verboseOption.value)
		arena.print();
	if (arena.countMessages() > 0) {
		printf("Failed to compile\n");
		arena.printMessages();
		return false;
	} else
		return true;
}

public boolean collectNamespacesToDocument() {
	ref<compiler.Unit>[] units = arena.units();
	for (i in units) {
		ref<compiler.Unit> f = units[i];
		if (f.hasNamespace()) {
			string nameSpace = f.getNamespaceString();
			ref<compiler.Namespace> nm;
			boolean alreadyExists;

			nm = nameMap[nameSpace];
			if (nm != null)
				alreadyExists = true;
			else {
				nm = f.namespaceSymbol();
				nameMap[nameSpace] = nm;
				ref<compiler.Doclet> doclet = nm.doclet();
				if (doclet == null || !doclet.ignore) {
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

public boolean generateNamespaceDocumentation() {
	for (i in names) {
		string dirName = names[i].name;
		for (int i = 0; i < dirName.length(); i++)
			if (dirName[i] == ':')
				dirName[i] = '_';
		string nmPath = storage.path(outputFolder, dirName);
		indexTypesFromNamespace(names[i].name, names[i].symbol, nmPath);
	}
	string overviewPage = storage.path(outputFolder, "index.html");
	ref<Writer> overview = storage.createTextFile(overviewPage);
	if (overview == null) {
		printf("Unable to create file '%s'\n", overviewPage);
		return false;
	}
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
		ref<compiler.Symbol> sym = names[i].symbol;
		ref<compiler.Doclet> doclet = sym.doclet();
		if (doclet != null)
			overview.write(expandDocletString(doclet.summary, sym, overviewPage));
		overview.write("</td>\n");
		overview.write("</tr>\n");
		generateNamespaceSummary(names[i].name, names[i].symbol);
	}
	overview.write("</tbody>\n");
	overview.write("</table>\n");

	insertTemplate2(overview);

	delete overview;
	return true;
}

void indexTypesFromNamespace(string name, ref<compiler.Namespace> nm, string dirName) {
	string overviewPage = storage.path(dirName, "namespace-summary", "html");
//	printf("Creating %s\n", dirName);
	if (!storage.ensure(dirName)) {
		printf("Could not create directory '%s'\n", dirName);
		process.exit(1);
	}

	string classesDir = storage.path(dirName, "classes", null);

	indexTypesInScope(nm.symbols(), classesDir, overviewPage);
}

void indexTypesInScope(ref<compiler.Scope> symbols, string dirName, string baseName) {
	ref<ref<compiler.Symbol>[compiler.Scope.SymbolKey]> symMap = symbols.symbols();

	ref<compiler.Symbol>[] classes;

	for (i in *symMap) {
		ref<compiler.Symbol> sym = (*symMap)[i];

		if (sym.class == compiler.PlainSymbol) {
			if (sym.visibility() != compiler.Operator.PUBLIC)
				continue;
			if (sym.doclet() != null && sym.doclet().ignore)
				continue;
			ref<compiler.Type> type = sym.type();
			switch (type.family()) {
			case CLASS:
			case INTERFACE:
			case TYPEDEF:
				classes.append(sym);
				break;
			}
		} else if (sym.class == compiler.Overload) {
			ref<compiler.Overload> o = ref<compiler.Overload>(sym);
			ref<ref<compiler.OverloadInstance>[]> instances = o.instances();
			for (j in *instances) {
				ref<compiler.OverloadInstance> oi = (*instances)[j];

				if (oi.visibility() != compiler.Operator.PUBLIC)
					continue;
				if (oi.doclet() != null && oi.doclet().ignore)
					continue;
				if (o.kind() != compiler.Operator.FUNCTION)
					classes.append(oi);
			}
		}

	}

	for (i in classes) {
		ref<compiler.Symbol> sym = classes[i];

		indexTypesInClass(sym, dirName);
	}
}

void indexTypesInClass(ref<compiler.Symbol> sym, string dirName) {
	ref<compiler.Scope> scope = scopeFor(sym);
	if (scope == null)
		return;
	if (sym.definition() != scope.className()) {
		ref<compiler.Type> t = typeFor(sym);
		if (t.family() != runtime.TypeFamily.TEMPLATE)
			return;
	}
	string name = sym.name();
	string classFile = storage.path(dirName, name, "html");
	if (!storage.ensure(dirName)) {
		printf("Could not ensure directory %s\n", dirName);
		process.exit(1);
	}

	if (classFiles[long(scope)] == null)
		classFiles[long(scope)] = classFile;

	string subDir = storage.path(dirName, name, null);

	indexTypesInScope(scope, subDir, classFile);
}

void generateNamespaceSummary(string name, ref<compiler.Namespace> nm) {
	string dirName = namespaceDir(nm);
	if (!storage.ensure(dirName)) {
		printf("Could not create directory '%s'\n", dirName);
		process.exit(1);
	}
	string overviewPage = namespaceFile(nm);
	ref<Writer> overview = storage.createTextFile(overviewPage);

	insertTemplate1(overview, overviewPage);

	overview.printf("<title>%s</title>\n", name);
	overview.write("<body>\n");
	overview.printf("<div class=namespace-title>Namespace %s</div>\n", name);

	ref<compiler.Doclet> doclet = nm.doclet();
	if (doclet != null) {
		if (doclet.author != null)
			overview.printf("<div class=author><span class=author-caption>Author: </span>%s</div>\n", expandDocletString(doclet.author, nm, overviewPage));
		if (doclet.deprecated != null)
			overview.printf("<div class=deprecated-outline><div class=deprecated-caption>Deprecated</div><div class=deprecated>%s</div></div>\n", expandDocletString(doclet.deprecated, nm, overviewPage));
		overview.printf("<div class=namespace-text>%s</div>\n", expandDocletString(doclet.text, nm, overviewPage));
		if (doclet.threading != null)
			overview.printf("<div class=threading-caption>Threading</div><div class=threading>%s</div>\n", expandDocletString(doclet.threading, nm, overviewPage));
		if (doclet.since != null)
			overview.printf("<div class=since-caption>Since</div><div class=since>%s</div>\n", expandDocletString(doclet.since, nm, overviewPage));
		if (doclet.see != null)
			overview.printf("<div class=see-caption>See Also</div><div class=see>%s</div>\n", expandDocletString(doclet.see, nm, overviewPage));
	}

	string classesDir = storage.path(dirName, "classes", null);

	generateScopeContents(nm.symbols(), overview, classesDir, overviewPage, 
								"Object", "Function", "INTERNAL ERROR", false, false);

	delete overview;
}

string namespaceFile(ref<compiler.Namespace> nm) {
	return storage.path(namespaceDir(nm), "namespace-summary", "html");
}

string namespaceDir(ref<compiler.Namespace> nm) {
	string s;
	string dirName = nm.fullNamespace();
	for (int i = 0; i < dirName.length(); i++)
		if (dirName[i] == ':')
			dirName[i] = '_';
	return storage.path(outputFolder, dirName, null);
}

ref<compiler.Scope> scopeFor(ref<compiler.Symbol> sym) {
	ref<compiler.Type> t = sym.type();
	if (t == null)
		return null;
	if (t.family() == runtime.TypeFamily.TYPEDEF)
		t = ref<compiler.TypedefType>(t).wrappedType();
	return t.scope();
}
/*
 * sym is a symbol, possibly a namespace, class, function  or object.
 */
string pathToMyParent(ref<compiler.Symbol> sym) {
	return pathToMyParent(sym.enclosing());
}

string pathToMyParent(ref<compiler.Scope> scope) {
	if (scope == scope.enclosingUnit()) {
		ref<compiler.Namespace> nm = scope.getNamespace();
		return storage.path(outputFolder, nm.domain() + "_" + nm.dottedName());
	}
	ref<compiler.Type> type = scope.enclosingClassType();
	if (type == null)
		return "type <null>";
	scope = type.scope();
	string path = pathToMyParent(scope.enclosing());
	if (scope.enclosing() == scope.enclosingUnit())
		path = storage.path(path, "classes");
	return storage.path(path, type.signature());
}
