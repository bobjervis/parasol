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

class ClassPage extends Page {
	ref<compiler.Symbol> _symbol;

	ClassPage(ref<compiler.Symbol> sym, string path) {
		super(null, path);
		_symbol = sym;
	}

	string toString() {
		return "<Symbol> " + _symbol.name() + " -> " + targetPath();
	}

	boolean write() {
		if (verboseOption.set()) {
			string caption;
			caption.printf("[%d]", index());
			printf("%7s Class Page %s\n", caption, targetPath());
		}
		ref<compiler.Scope> scope = scopeFor(_symbol);
		if (scope == null) {
			printf("No type or scope for %s\n", targetPath());
			return false;
		}
		classPage := storage.createTextFile(targetPath());
		if (classPage == null) {
			printf("Could not create class file %s\n", targetPath());
			process.exit(1);
		}
	
		insertTemplate1(classPage, targetPath());
	
		classPage.printf("<title>%s</title>\n", _symbol.name());
		classPage.write("<body>\n");
	
		ref<compiler.Namespace> nm = _symbol.enclosingNamespace();
	
		classPage.printf("<div class=namespace-info><b>Namespace</b> %s</div>\n", namespaceReference(nm));
		ref<compiler.Type> t = typeFor(_symbol);
		boolean isInterface;
		boolean hasConstants;
		string enumLabel;
		ref<compiler.Doclet> doclet = _symbol.doclet();
		switch (t.family()) {
		case	INTERFACE:
			classPage.printf("<div class=class-title>Interface %s</div>", _symbol.name());
			isInterface = true;
			enumLabel = "INTERNAL ERROR";
			break;
	
		case	FLAGS:
			hasConstants = true;
			classPage.printf("<div class=class-title>Flags %s</div>", _symbol.name());
			enumLabel = "Flags";
			break;
	
		case	ENUM:
			hasConstants = true;
			classPage.printf("<div class=class-title>Enum %s</div>", _symbol.name());
			enumLabel = "Enum";
			break;
	
		case	TEMPLATE:
			classPage.printf("<table class=template-params>\n");
			classPage.printf("<tr>\n");
			classPage.printf("<td>%sClass&nbsp;%s&lt;</td>\n<td>", t.isConcrete(null) ? "" : "Abstract&nbsp;", _symbol.name());
			ref<compiler.ParameterScope> p = ref<compiler.ParameterScope>(scope);
			assert(t.class == compiler.TemplateType);
			ref<ref<compiler.Symbol>[]> params = p.parameters();
			string[string] paramMap;
			if (doclet != null) {
				for (i in doclet.params) {
					int idx = doclet.params[i].indexOf(' ');
					if (idx < 0)
						continue;
					string pname = doclet.params[i].substr(0, idx);
					string value = doclet.params[i].substr(idx + 1).trim();
					if (value.length() > 0)
						paramMap[pname] = value;
				}
			}
			for (i in *params) {
				ref<compiler.Symbol> param = (*params)[i];
				string pname = param.name();
				if (param.type() == null)
					classPage.printf("&lt;null&gt;&nbsp;%s", pname);
				else
					classPage.printf("%s&nbsp;%s", typeString(param.type(), targetPath()), pname);
				if (i < params.length() - 1)
					classPage.write(",</td>\n");
				else
					classPage.write("&gt;</td>\n");
				string comment = paramMap[pname];
				if (comment != null)
					classPage.printf("<td><div class=param-text>%s</div></td>\n", 
										expandDocletString(doclet, comment, _symbol, targetPath()));
				if (i < params.length() - 1)
					classPage.write("</tr>\n<tr>\n<td></td><td>");
			}
			classPage.write("</tr>\n</table>\n");
			generateClassInfo(t, classPage, targetPath());
			ref<compiler.TemplateType> template = ref<compiler.TemplateType>(t);
			ref<compiler.Template> temp = template.definition();
			scope = temp.classDef.scope;
			break;
	
		default:
			classPage.printf("<div class=class-title>%sClass %s", t.isConcrete(null) ? "" : "Abstract ", _symbol.name());
			classPage.printf("</div>\n");
			generateClassInfo(t, classPage, targetPath());
		}
		if (doclet != null) {
			if (doclet.author != null)
				classPage.printf("<div class=author><span class=author-caption>Author: </span>%s</div>\n",
										expandDocletString(doclet, doclet.author, _symbol, targetPath()));
			if (doclet.deprecated != null)
				classPage.printf("<div class=deprecated-outline><div class=deprecated-caption>Deprecated</div><div class=deprecated>%s</div></div>\n",
										expandDocletString(doclet, doclet.deprecated, _symbol, targetPath()));
			classPage.printf("<div class=class-text>%s</div>\n", 
										expandDocletString(doclet, doclet.text, _symbol, targetPath()));
			if (doclet.threading != null)
				classPage.printf("<div class=threading-caption>Threading</div><div class=threading>%s</div>\n", 
										expandDocletString(doclet, doclet.threading, _symbol, targetPath()));
			if (doclet.since != null)
				classPage.printf("<div class=since-caption>Since</div><div class=since>%s</div>\n", 
										expandDocletString(doclet, doclet.since, _symbol, targetPath()));
			if (doclet.see != null)
				classPage.printf("<div class=see-caption>See Also</div><div class=see>%s</div>\n", 
										expandDocletString(doclet, doclet.see, _symbol, targetPath()));
		}
	
		string subDir = storage.path(storage.directory(targetPath()), _symbol.name());
	
		generateScopeContents(scope, classPage, subDir, targetPath(), "Member", "Method", enumLabel, isInterface, hasConstants);
	
		delete classPage;
		return true;
	}
}

void generateClassInfo(ref<compiler.Type> t, ref<Writer> classPage, string classFile) {
	classPage.printf("<div class=class-hierarchy>");
	generateBaseClassName(classPage, t, classFile, false);
	classPage.printf("</div>\n");
	ref<ref<compiler.InterfaceType>[]> interfaces = t.interfaces();
	if (interfaces != null && interfaces.length() > 0) {
		classPage.write("<div class=impl-iface-caption>All implemented interfaces:</div>\n");
		classPage.write("<div class=impl-ifaces>\n");
		for (i in *interfaces) {
			ref<compiler.Type> iface = (*interfaces)[i];

			classPage.write(typeString(iface, classFile));
			classPage.write('\n');
		}
		classPage.write("</div>\n");
	}
}

string namespaceReference(ref<compiler.Namespace> nm) {
	string path = namespaceFile(nm);
	string s;
	s.printf("<a href=\"%s\">%s</a>", path, nm.fullNamespace());
	return s;
}

int generateBaseClassName(ref<Writer> output, ref<compiler.Type> t, string baseName, boolean includeLink) {
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

string fullyQualifiedClassName(ref<compiler.Type> t, string baseName, boolean includeLink) {
	ref<compiler.Scope> scope = t.scope();
	if (scope == null)
		return typeString(t, baseName);

	ref<compiler.Namespace> nm = scope.getNamespace();
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

string qualifiedName(ref<compiler.Type> t) {
	ref<compiler.Scope> scope = t.scope();
	if (scope == null)
		return null;
	ref<compiler.Type> e = scope.enclosing().enclosingClassType();
	string s;
//	printf("qualifiedName e = %s\n", e != null ? e.signature() : "<null>");
	if (e != null)
		s = qualifiedName(e) + ".";
	ref<compiler.Node> definition = scope.definition();
	switch (definition.op()) {
	case	CLASS:
	case	MONITOR_CLASS:
		s.append(ref<compiler.ClassDeclarator>(definition).name().identifier());
		break;

	case	TEMPLATE:
		s.append(ref<compiler.Template>(definition).name().identifier());
		break;

	default:
		definition.print(0);
		assert(false);
	}
	return s;
}

