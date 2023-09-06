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

compiler.Arena arena;
ref<compiler.CompileContext> compileContext;
ref<CodeOverviewPage> codeOverviewPage;

class Names {
	string name;
	ref<compiler.Namespace> symbol;		// Only for namespace
	ref<compiler.Scope> scope;			// for nexted classes
	ref<compiler.Symbol>[] classes;
	ref<Names>[] children;

	public int compare(Names other) {
		return name.compare(other.name);
	}

	void indexClassesInScope(ref<Page> parent, ref<compiler.Scope> symbols, string dirName) {
		symMap := symbols.symbols();
	
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
	
		if (classes.length() > 0) {
			defineOutputDirectory(dirName);
			classes.sort(compareSymbols, true);
			for (i in classes) {
				ref<compiler.Symbol> sym = classes[i];
		
				n := indexTypesInClass(parent, sym, dirName);
				children.append(n);
			}
		}
	}

	ref<Names> indexTypesInClass(ref<Page> parent, ref<compiler.Symbol> sym, string dirName) {
		ref<compiler.Scope> scope = scopeFor(sym);
		if (scope == null)
			return null;
		if (sym.definition() != scope.className()) {
			ref<compiler.Type> t = typeFor(sym);
			if (t.family() != runtime.TypeFamily.TEMPLATE)
				return null;
		}
		string name = sym.name();
		string classFile = storage.path(dirName, name, "html");
		if (classFiles[long(scope)] == null)
			classFiles[long(scope)] = classFile;
	
		c := new ClassPage(sym, classFile);
		c.add();
		parent.childPage(c);

		string subDir = storage.path(dirName, name);

		n := new Names;
		n.scope = scope;
		n.indexClassesInScope(c, scope, subDir);
		return n;
	}

	string levelGroup(string dirName) {
		string output = "<ul>\n";
		for (j in classes) {
			sym := classes[j];
			if (sym.initializer() != null &&
				sym.initializer().op() != compiler.Operator.CLASS)
				continue;
			output.printf("<li><a href=\"%s/classes/%s.html\">%2$s</a>\n", dirName, sym.name());
			child := children[j];
			if (child != null) {
				subDir := storage.path(storage.path(dirName, "classes"), sym.name());
				output += child.nestedClassGroup(subDir);
			}
		}
		if (output.length() == 5)
			return "";
		output += "</ul>\n";
		return output;
	}

	string nestedClassGroup(string dirName) {
		string output = "<ul>\n";
		for (j in classes) {
			sym := classes[j];
			if (sym.initializer() != null &&
				sym.initializer().op() != compiler.Operator.CLASS)
				continue;
			if (sym.type() == null ||
				sym.type().family() != runtime.TypeFamily.TYPEDEF)
				continue;
			output.printf("<li><a href=\"%s/%s.html\">%2$s</a>\n", dirName, sym.name());
			child := children[j];
			if (child != null)
				output += child.nestedClassGroup(storage.path(dirName, sym.name()));
		}
		if (output.length() == 5)	// The inner loop didn't add anything.
			return "";
		output += "</ul>\n";
		return output;
	}
}

ref<compiler.Namespace>[string] nameMap;

class CodeOverviewPage extends Page {
	Names[] names;

	CodeOverviewPage(string path) {
		super(null, path);
		codeOverviewPage = this;
	}

	string toString() {
		return "<Overview> -> " + targetPath();
	}

	void define(string nameSpace, ref<compiler.Namespace> nm) {
		Names n = { name: nameSpace, symbol: nm };
		names.append(n);
	}

	void instantiateNamespaces() {
		names.sort();
		for (ni in names) {
			ref<Names> n = &names[ni];
			string nameSpace = n.name;
			for (i in nameSpace)
				if (nameSpace[i] == ':') {
					nameSpace[i] = '_';
					break;
				}
			namespaceFolder := storage.path(codeOutputFolder, nameSpace);

			defineOutputDirectory(namespaceFolder);
			namespaceSummary := new NamespaceSummaryPage(storage.path(namespaceFolder, "namespace-summary.html"), n.symbol);
			namespaceSummary.add();
			this.childPage(namespaceSummary);
			classesDir := storage.path(namespaceFolder, "classes");
			n.indexClassesInScope(namespaceSummary, n.symbol.symbols(), classesDir);
		}
	}

	string caption() {
		return "Code Overview Page";
	}

	boolean write() {
		if (verboseOption.set()) {
			string caption;
			caption.printf("[%d]", index());
			printf("%7s Overview Page %s\n", caption, targetPath());
		}
		overviewPage := targetPath();
		overview := storage.createTextFile(overviewPage);
		if (overview == null) {
			printf("Unable to create file '%s'\n", overviewPage);
			return false;
		}
		insertTemplate1(overview, this);
	
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
				overview.write(expandDocletString(doclet, doclet.summary, sym, overviewPage));
			overview.write("</td>\n");
			overview.write("</tr>\n");
		}
		overview.write("</tbody>\n");
		overview.write("</table>\n");
	
		insertTemplate2(overview, this);
	
		delete overview;
		return true;
	}

	string levelGroup(ref<Content> enclosing) {
		string output = "<ul>\n";

		codeOutputPrefix := storage.makeCompactPath(codeOutputFolder, enclosing.targetPath());
		// These are the actual namespaces
		for (i in names) {
			ref<Names> n = &names[i];
			string dirName = codeOutputPrefix + "/" + n.name;
			for (int i = codeOutputPrefix.length() + 1; i < dirName.length(); i++)
				if (dirName[i] == ':')
					dirName[i] = '_';
			output.printf("<li><a href=\"%s/namespace-summary.html\">%s</a>\n", dirName, n.name);
			// Start with the classes directly under the namespace, then on to the nested classes.
			output += n.levelGroup(dirName);
		}
		return output + "</ul>\n";
	}
}

class NamespaceSummaryPage extends Page {
	ref<compiler.Namespace> _nameSpace;

	NamespaceSummaryPage(string path, ref<compiler.Namespace> nm) {
		super(null, path);
		_nameSpace = nm;
	}

	string toString() {
		return "<Namespace> " + namespaceFile(_nameSpace) + " -> " + targetPath();
	}

	string caption() {
		return _nameSpace.fullNamespace();
	}

	boolean write() {
		if (verboseOption.set()) {
			string caption;
			caption.printf("[%d]", index());
			printf("%7s Namespace Summary Page %s\n", caption, targetPath());
		}
		ref<Writer> overview;
		string summaryPage = namespaceFile(_nameSpace);
		string dirName = namespaceDir(_nameSpace);

		overview = storage.createTextFile(summaryPage);
		if (overview == null) {
			printf("Could not create output file %s\n", summaryPage);
			return false;
		}
		insertTemplate1(overview, this);
	
		//insertNavbar(overview);
		overview.printf("<div class=namespace-title>Namespace %s</div>\n", caption());
	
		ref<compiler.Doclet> doclet = _nameSpace.doclet();
		if (doclet != null) {
			if (doclet.author != null)
				overview.printf("<div class=author><span class=author-caption>Author: </span>%s</div>\n",
											expandDocletString(doclet, doclet.author, _nameSpace, summaryPage));
			if (doclet.deprecated != null)
				overview.printf("<div class=deprecated-outline><div class=deprecated-caption>Deprecated</div><div class=deprecated>%s</div></div>\n",
											expandDocletString(doclet, doclet.deprecated, _nameSpace, summaryPage));
			overview.printf("<div class=namespace-text>%s</div>\n",
											expandDocletString(doclet, doclet.text, _nameSpace, summaryPage));
			if (doclet.threading != null)
				overview.printf("<div class=threading-caption>Threading</div><div class=threading>%s</div>\n",
											expandDocletString(doclet, doclet.threading, _nameSpace, summaryPage));
			if (doclet.since != null)
				overview.printf("<div class=since-caption>Since</div><div class=since>%s</div>\n",
											expandDocletString(doclet, doclet.since, _nameSpace, summaryPage));
			if (doclet.see != null)
				overview.printf("<div class=see-caption>See Also</div><div class=see>%s</div>\n",
											expandDocletString(doclet, doclet.see, _nameSpace, summaryPage));
		}
	
		string classesDir = storage.path(dirName, "classes", null);
	
		generateScopeContents(_nameSpace.symbols(), overview, classesDir, summaryPage, 
									"Object", "Function", "INTERNAL ERROR", false, false);
	
		insertTemplate2(overview, this);
		delete overview;
		return true;
	}
}

public boolean compilePackages(string[] finalArguments) {
	arena.paradoc = true;
	arena.verbose = false;
	compileContext = new compiler.CompileContext(&arena, false, logImportsOption.value);
	if (!compileContext.loadRoot(false))
		return false;
	ref<context.Context> activeContext = arena.activeContext();

	string[] unitFilenames;
	boolean isCorePackage;

	boolean allGood = true;
	for (int i = 1; i < finalArguments.length(); i++) {
		ref<context.Package> package = activeContext.getPackage(finalArguments[i]);
		if (package != null) {
			boolean success;
			string[] units;

			(units, success) = package.getUnitFilenames();
			if (!success) {
				allGood = false;
				printf("Could not load unitS from package %s\n", finalArguments[i]);
			}
			unitFilenames.append(package.getUnitFilenames());
			if (package.name() == context.PARASOL_CORE_PACKAGE_NAME)
				isCorePackage = true;
		} else
			printf("Could not find package %s\n", finalArguments[i]);
	}
	if (!allGood)
		return false;
	compileContext.compilePackage(isCorePackage, unitFilenames, "none");

	// We are now done with compiling, time to analyze the results

	if (verboseOption.set()) {
		printf("Compiled %d units!\n", unitFilenames.length());
		for (i in unitFilenames)
			printf("[%3d] %s\n", i, unitFilenames[i]);
	}
	if (symbolTableOption.value)
		arena.printSymbolTable();
	if (arena.countMessages() > 0) {
		printf("Failed to compile\n");
		arena.printMessages();
		return false;
	} else
		return true;
}

public boolean collectNamespacesToDocument() {
	if (codeOutputFolder == null) {
		printf("No destination defined for generated pages\n");
		return false;
	}

	overviewPage := new CodeOverviewPage(storage.path(codeOutputFolder, "index.html"));
	overviewPage.add();

	ref<compiler.Unit>[] units = arena.units();
	for (i in units) {
		ref<compiler.Unit> f = units[i];
		if (f.hasNamespace()) {
			string nameSpace = f.getNamespaceString();
			ref<compiler.Namespace> nm;

			nm = nameMap[nameSpace];
			if (nm != null)
				continue;
			nm = f.namespaceSymbol();
			nameMap[nameSpace] = nm;
			ref<compiler.Doclet> doclet = nm.doclet();
			if (doclet == null || !doclet.ignore) {
				if (verboseOption.set())
					printf("         - Defining namespace %s\n", nameSpace);
				overviewPage.define(nameSpace, nm);
			}
		}
	}
	overviewPage.instantiateNamespaces();
	return true;
}

private int compareSymbols(ref<compiler.Symbol> left, ref<compiler.Symbol> right) {
	return left.compare(right);
}

string namespaceFile(ref<compiler.Namespace> nm) {
	return storage.path(namespaceDir(nm), "namespace-summary.html");
}

string namespaceDir(ref<compiler.Namespace> nm) {
	string s;
	string dirName = nm.fullNamespace();
	for (int i = 0; i < dirName.length(); i++)
		if (dirName[i] == ':')
			dirName[i] = '_';
	return storage.path(codeOutputFolder, dirName);
}

ref<compiler.Scope> scopeFor(ref<compiler.Symbol> sym) {
//		if (s := sym as compiler.Namespace)
//			scope = s.symbols();
//		switch (s := sym) {
//		case compiler.Namespace:
//			scope = s.symbols();
//			break;
//		default:
//			...
//		}
	if (sym.class == compiler.Namespace)
		return ref<compiler.Namespace>(sym).symbols();
	else if (sym.class == compiler.Overload) {
		ref<compiler.Overload> o = ref<compiler.Overload>(sym);
		ref<ref<compiler.OverloadInstance>[]> instances = o.instances();
		if (instances.length() == 0)
			return null;
		if (instances.length() > 1)
			return null;
		sym = (*instances)[0];
	}
	ref<compiler.Type> t = sym.type();
	if (t == null)
		return null;
	switch (t.family()) {
	case SIGNED_32:
	case UNSIGNED_16:
	case BOOLEAN:
	case REF:
	case ENUM:
	case FLAGS:
	case FUNCTION:
	case SHAPE:
	case CLASS:
		return sym.enclosing();

	case TYPEDEF:
		t = ref<compiler.TypedefType>(t).wrappedType();
		ref<compiler.Scope> scope = t.scope();
		switch (t.family()) {
		case TEMPLATE:
			ref<ref<compiler.Scope>[]> enclosed = scope.enclosed();
			if (enclosed.length() == 0)
				return null;
			return (*enclosed)[0];	
		}
		return scope;

	default:
		printf("family = %s\n", string(t.family()));
		sym.print(0, false);
		assert(false);
	}
	return null;
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
		return storage.path(codeOutputFolder, nm.domain() + "_" + nm.dottedName());
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
