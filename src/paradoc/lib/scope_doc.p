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
import parasol:runtime;
import parasol:storage;

map<string, long> classFiles;

void generateScopeContents(ref<compiler.Scope> scope, ref<Writer> output, string dirName, string baseName, string objectLabel, string functionLabel, string enumLabel, boolean isInterface, boolean hasConstants) {
	ref<ref<compiler.Symbol>[compiler.Scope.SymbolKey]> symMap = scope.symbols();

	ref<compiler.OverloadInstance>[] constructors;
	ref<compiler.OverloadInstance>[] functions;
	ref<compiler.Symbol>[] enumConstants;
	ref<compiler.Symbol>[] enums;
	ref<compiler.Symbol>[] objects;
	ref<compiler.Symbol>[] interfaces;
	ref<compiler.Symbol>[] classes;
	ref<compiler.Symbol>[] exceptions;

	for (i in *symMap) {
		ref<compiler.Symbol> sym = (*symMap)[i];

		if (sym.class == compiler.PlainSymbol) {
			if (sym.doclet() != null && sym.doclet().ignore)
				continue;
			ref<compiler.Type> type = sym.type();
			if (type == null)
				continue;
			if (!isInterface && 
				sym.visibility() != compiler.Operator.PUBLIC &&
				sym.visibility() != compiler.Operator.PROTECTED)
				continue;
			switch (type.family()) {
			case INTERFACE:
				interfaces.append(sym);
				break;

			case FLAGS:
			case ENUM:
				if (hasConstants)
					enumConstants.append(sym);
				else
					objects.append(sym);
				break;

			case TYPEDEF:
				type = type.wrappedType();
				if (type == null)
					break;
				if (type.isException())
					exceptions.append(sym);
				else if (type.family() == runtime.TypeFamily.ENUM ||
						 type.family() == runtime.TypeFamily.FLAGS)
					enums.append(sym);
				else if (type.family() == runtime.TypeFamily.INTERFACE)
					interfaces.append(sym);
				else
					classes.append(sym);
				break;

			default:
				objects.append(sym);
			}
		} else if (sym.class == compiler.Overload) {
			ref<compiler.Overload> o = ref<compiler.Overload>(sym);
			ref<ref<compiler.OverloadInstance>[]> instances = o.instances();
			for (j in *instances) {
				ref<compiler.OverloadInstance> oi = (*instances)[j];

				if (oi.doclet() != null && oi.doclet().ignore)
					continue;
				if (!isInterface && oi.visibility() != compiler.Operator.PUBLIC && oi.visibility() != compiler.Operator.PROTECTED)
					continue;
				if (o.kind() == compiler.Operator.FUNCTION)
					functions.append(oi);
				else
					classes.append(oi);
			}
		}

	}

	ref<ref<compiler.ParameterScope>[]> constructorScopes = scope.constructors();

	for (i in *constructorScopes) {
		ref<compiler.ParameterScope> ps = (*constructorScopes)[i];
		ref<compiler.OverloadInstance> sym = ps.symbol;
		if (sym != null && (sym.visibility() == compiler.Operator.PUBLIC ||
							sym.visibility() == compiler.Operator.PROTECTED))
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
			ref<compiler.Symbol> sym = enumConstants[i];
			output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			ref<compiler.Type> type = sym.type();
			output.printf("<td class=\"linkcol\"><a href=\"#%s\"\">%s</a></td>\n", sym.name(), sym.name());
			output.write("<td class=\"descriptioncol\">");
			ref<compiler.Doclet> doclet = sym.doclet();
			if (doclet != null)
				output.write(expandDocletString(doclet.summary, sym, baseName));
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
			ref<compiler.Symbol> sym = enums[i];
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
			ref<compiler.Symbol> sym = objects[i];

			output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");
			ref<compiler.Type> type = sym.type();
			output.printf("<td class=\"linkcol\">%s</td>\n", typeString(type, baseName));
			output.write("<td class=\"descriptioncol\">");
			output.printf("<a href=\"#%s\"><span class=code>%s</span></a><br>", sym.name(), sym.name());
			ref<compiler.Doclet> doclet = sym.doclet();
			if (doclet != null)
				output.printf("\n%s", expandDocletString(doclet.summary, sym, baseName));
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
			ref<compiler.Symbol> sym = interfaces[i];
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
			ref<compiler.Symbol> sym = classes[i];
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
			ref<compiler.Symbol> sym = exceptions[i];
			generateClassSummaryEntry(output, i, sym, dirName, baseName);
		}
		output.write("</tbody>\n");
		output.write("</table>\n");
	}

	if (enumConstants.length() > 0) {
		output.printf("<div class=block>\n");
		output.printf("<div class=block-header>%s Constants Detail</div>\n", enumLabel);
		for (i in enumConstants) {
			ref<compiler.Symbol> sym = enumConstants[i];
			string name = sym.name();

			output.printf("<a id=\"%s\"></a>\n", name);
			output.printf("<div class=entity>%s</div>\n", name);
			output.printf("<div class=declaration>public static final %s %s <span class=\"enum-value\">(%d)</span></div>\n", typeString(sym.type(), baseName), name, sym.offset);
			ref<compiler.Doclet> doclet = sym.doclet();
			if (doclet != null)
				output.printf("\n<div class=enum-description>%s</div>", expandDocletString(doclet.text, sym, baseName));
		}
		output.printf("</div>\n");
	}

	if (objects.length() > 0) {
		output.printf("<div class=block>\n");
		output.printf("<div class=block-header>%s Detail</div>\n", objectLabel);
		for (i in objects) {
			ref<compiler.Symbol> sym = objects[i];
			string name = sym.name();

			output.printf("<a id=\"%s\"></a>\n", name);
			output.printf("<div class=entity>%s</div>\n", name);
			output.printf("<div class=declaration>");
			ref<compiler.Type> type = sym.type();
			switch (sym.visibility()) {
			case	PUBLIC:
				output.write("public ");
				break;

			case	PROTECTED:
				output.write("protected ");
				break;
			}
			if (sym.storageClass() == compiler.StorageClass.STATIC &&
				sym.enclosing().storageClass() != compiler.StorageClass.STATIC)
				output.printf("static ");
			output.printf("%s %s</div>\n", typeString(type, baseName), name);
			ref<compiler.Doclet> doclet = sym.doclet();
			if (doclet != null)
				output.printf("\n<div class=enum-description>%s</div>", expandDocletString(doclet.text, sym, baseName));
		}
		output.printf("</div>\n");
	}

	if (constructors.length() > 0)
		functionDetail(output, &constructors, true, "Constructor", baseName);

	if (functions.length() > 0)
		functionDetail(output, &functions, false, functionLabel, baseName);
}

void generateClassSummaryEntry(ref<Writer> output, int i, ref<compiler.Symbol> sym, string dirName, string baseName) {
	ref<compiler.Scope> scope = scopeFor(sym);
	if (scope == null)
		return;
	output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");

	string name = sym.name();
	if (sym.definition() == scope.className()) {
		if (!generateClassPage(sym, name, dirName))
			return;
	}
	ref<compiler.Type> t = typeFor(sym);
	switch (t.family()) {
	case	TEMPLATE:
	case	ENUM:
	case	FLAGS:
		if (!generateClassPage(sym, name, dirName))
			return;
	}
	output.printf("<td class=\"linkcol\">");
	if (sym.definition() != scope.className() && t.family() != runtime.TypeFamily.TEMPLATE)
		output.printf("%s = ", name);
	if (sym.type() == null)
		output.printf("&lt;null&gt;</td>\n");
	else		
		output.printf("%s</td>\n", typeString(sym.type(), baseName));

	output.write("<td class=\"descriptioncol\">");
	ref<compiler.Doclet> doclet = sym.doclet();
	if (doclet != null)
		output.write(expandDocletString(doclet.summary, sym, baseName));
	output.write("</td>\n");
	output.write("</tr>\n");
}

ref<compiler.Type> typeFor(ref<compiler.Symbol> sym) {
	ref<compiler.Type> t = sym.type();
	if (t == null)
		return null;
	if (t.family() == runtime.TypeFamily.TYPEDEF)
		t = ref<compiler.TypedefType>(t).wrappedType();
	return t;
}

void functionSummary(ref<Writer> output, ref<ref<compiler.OverloadInstance>[]> functions, 
						boolean asConstructors, string functionLabel, string baseName) {
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
		ref<compiler.NodeList> nl;
		ref<compiler.OverloadInstance> sym = (*functions)[i];
//		sym.printSimple();
		ref<compiler.Type> symType = sym.type();
		if (symType == null || symType.family() == runtime.TypeFamily.CLASS_DEFERRED) {
			continue;
		}
		ref<compiler.FunctionType> ft = ref<compiler.FunctionType>(sym.type());
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
			pointer<ref<compiler.Type>> tp = ft.returnTypes();
			if (tp == null)
				output.write("void");
			else {
				for (int i = 0; i < ft.returnCount(); i++) {
					output.printf("%s", typeString(tp[i], baseName));
					if (i < ft.returnCount() - 1)
						output.write(", ");
				}
			}
		}
		output.write("</td>\n<td>");
		output.printf("<span class=code><a href=\"#%s\">%s</a>(", sym.name(), sym.name());
		pointer<ref<compiler.Type>> tp = ft.parameters();
		ref<compiler.ParameterScope> scope = ft.functionScope();
		
		ref<ref<compiler.Symbol>[]> parameters;
		if (scope != null)
			parameters = scope.parameters();
		int j = 0;
		int ellipsisArgument = -1;
		if (ft.hasEllipsis())
			ellipsisArgument = ft.parameterCount() - 1;
		for (int i = 0; i < ft.parameterCount(); i++) {
			if (i == ellipsisArgument)
				output.printf("%s...", typeString(tp[i].elementType(), baseName));
			else
				output.printf("%s", typeString(tp[i], baseName));
			if (parameters != null && parameters.length() > j)
				output.printf(" %s", (*parameters)[j].name());
			else
				output.write(" ???");
			if (i < ft.parameterCount() - 1)
				output.write(", ");
			j++;
		}
		output.write(")</span>");
		ref<compiler.Doclet> doclet = sym.doclet();
		if (doclet != null)
			output.printf("\n<div class=descriptioncol>%s</div>", expandDocletString(doclet.summary, sym, baseName));
		output.write("</td>\n");
		output.write("</tr>\n");
	}
	output.write("</tbody>\n");
	output.write("</table>\n");
}

void functionDetail(ref<Writer> output, ref<ref<compiler.OverloadInstance>[]> functions, boolean asConstructors, string functionLabel, string baseName) {
	output.printf("<div class=block>\n");
	output.printf("<div class=block-header>%s Detail</div>\n", functionLabel);
	for (i in *functions) {
		ref<compiler.OverloadInstance> sym = (*functions)[i];
		ref<compiler.Type> symType = sym.type();
		if (symType == null || symType.family() == runtime.TypeFamily.CLASS_DEFERRED) {
			continue;
		}
		string name = sym.name();

		output.printf("<a id=\"%s\"></a>\n", name);
		output.printf("<div class=entity>%s</div>\n", name);
		output.printf("<div class=declaration>");
		output.printf("<table class=func-params>\n");
		output.printf("<tr>\n");
		output.printf("<td>");
		switch (sym.visibility()) {
		case	PUBLIC:
			output.write("public&nbsp;");
			break;

		case	PROTECTED:
			output.write("protected&nbsp;");
			break;
		}
		if (!sym.isConcrete(null))
			output.write("abstract&nbsp;");
		else if (sym.enclosing() == sym.enclosingClassScope() && sym.storageClass() == compiler.StorageClass.STATIC)
			output.write("static&nbsp;");
		ref<compiler.NodeList> nl;
		ref<compiler.FunctionType> ft = ref<compiler.FunctionType>(sym.type());
		if (!asConstructors) {
			pointer<ref<compiler.Type>> tp = ft.returnTypes();
			int rCount = ft.returnCount();
			if (rCount == 0)
				output.write("void");
			else {
				for (int i = 0; i < rCount; i++) {
					output.printf("%s", typeString(tp[i], baseName));
					if (i < rCount - 1)
						output.write(",&nbsp;");
				}
			}
			output.write("&nbsp;");
		}
		output.printf("%s(", name);
		output.write("</td>\n<td>");

		pointer<ref<compiler.Type>> tp = ft.parameters();
		ref<compiler.ParameterScope> scope = ft.functionScope();
		ref<ref<compiler.Symbol>[]> parameters;
		if (scope != null)
			parameters = scope.parameters();
		int j = 0;
		ref<compiler.Doclet> doclet = sym.doclet();
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
		int pCount = ft.parameterCount();
		if (pCount == 0)
			output.write(")</td>\n");
		int ellipsisArgument = -1;
		if (ft.hasEllipsis())
			ellipsisArgument = pCount - 1;
		for (int i = 0; i < pCount; i++) {
			if (i == ellipsisArgument)
				output.printf("%s...", typeString(tp[i].elementType(), baseName));
			else
				output.printf("%s", typeString(tp[i], baseName));
			string pname;
			if (parameters != null && parameters.length() > j) {
				pname = (*parameters)[j].name();
				output.printf("&nbsp;%s", pname);
			} else
				output.write("&nbsp;???");
			if (i < pCount - 1)
				output.write(",</td>\n");
			else
				output.write(")</td>\n");
			string comment = paramMap[pname];
			if (comment != null)
				output.printf("<td><div class=param-text>%s</div></td>\n", expandDocletString(comment, sym, baseName));
			if (i < pCount - 1)
				output.write("</tr>\n<tr>\n<td></td><td>");
			j++;
		}
		output.write("</tr>\n</table>\n</div>\n");
		if (doclet != null) {
			output.write("\n<div class=func-description>\n");
			if (doclet.deprecated != null)
				output.printf("<div class=deprecated-outline><div class=deprecated-caption>Deprecated</div><div class=deprecated>%s</div></div>\n", expandDocletString(doclet.deprecated, sym, baseName));
			output.printf("\n<div class=func-text>%s</div>", expandDocletString(doclet.text, sym, baseName));
			tp = ft.returnTypes();
			int rCount = ft.returnCount();
			if (doclet.returns.length() > 0 && rCount > 0) {
				output.write("\n<div class=func-return-caption>Returns:</div>");
				if (doclet.returns.length() == 1) {
					output.printf("\n<div class=func-return>%s</div>", expandDocletString(doclet.returns[0], sym, baseName));
				} else {
					output.printf("\n<ol class=func-return>\n");
					for (i in doclet.returns) {
						if (i >= rCount)
							break;
						string ts = typeString(tp[i], baseName);
						output.printf("<li class=func-return>(<span class=code>%s</span>) %s</li>\n", ts, expandDocletString(doclet.returns[i], sym, baseName));
					}
					output.printf("</ol>\n");
				}
			}
			if (doclet.exceptions.length() > 0) {
				output.write("<div class=exceptions-caption>Exceptions:</div>\n<table>\n");
				for (i in doclet.exceptions) {
					int idx = doclet.exceptions[i].indexOf(' ');
					string ename;
					string value;
					if (idx < 0) {
						ename = doclet.exceptions[i];
						value = "";
					} else {
						ename = doclet.exceptions[i].substr(0, idx);
						value = doclet.exceptions[i].substr(idx + 1).trim();
					}
					output.printf("<td><td>%s</td><td>%s</td></tr>\n", ename, expandDocletString(value, sym, baseName));
				}
				output.write("</table>\n");
			}
			if (doclet.threading != null)
				output.printf("<div class=threading-caption>Threading</div><div class=threading>%s</div>\n", expandDocletString(doclet.threading, sym, baseName));
			if (doclet.since != null)
				output.printf("<div class=since-caption>Since</div><div class=since>%s</div>\n", expandDocletString(doclet.since, sym, baseName));
			if (doclet.see != null)
				output.printf("<div class=see-caption>See Also</div><div class=see>%s</div>\n", expandDocletString(doclet.see, sym, baseName));
			output.write("</div>\n");
		}
	}
	output.write("</div>\n");
}

string typeString(ref<compiler.Type> type, string baseName) {
	if (type == null)
		return "<null>";
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
	case	STRING16:
	case	SUBSTRING:
	case	SUBSTRING16:
	case	EXCEPTION:
	case	OBJECT_AGGREGATE:
	case	ARRAY_AGGREGATE:
		string t = type.signature();
		string classFile = classFiles[long(type.scope())];
		if (classFile == null)
			return t;
		string url = storage.makeCompactPath(classFile, baseName);
		return "<a href=\"" + url + "\">" + t + "</a>";

	case	POINTER:
		ref<var[]> args = ref<compiler.TemplateInstanceType>(type).arguments();
		return "pointer&lt;" + typeString(ref<compiler.Type>((*args)[0]), baseName) + "&gt;";

	case	REF:
		args = ref<compiler.TemplateInstanceType>(type).arguments();
		return "ref&lt;" + typeString(ref<compiler.Type>((*args)[0]), baseName) + "&gt;";


	case	FUNCTION:
		ref<compiler.FunctionType> ft = ref<compiler.FunctionType>(type);
		string f;

		pointer<ref<compiler.Type>> tp = ft.returnTypes();
		int rCount = ft.returnCount();
		if (rCount == 0)
			f.append("void");
		else {
			for (int i = 0; i < rCount; i++) {
				f.append(typeString(tp[i], baseName));
				if (i < rCount - 1)
					f.append(", ");
			}
		}
		f.append(" (");
		tp = ft.parameters();
		int pCount = ft.parameterCount();
		int ellipsisArgument = -1;
		if (ft.hasEllipsis())
			ellipsisArgument = pCount - 1;
		for (int i = 0; i < pCount; i++) {
			if (i == ellipsisArgument) {
				f.append(typeString(tp[i].elementType(), baseName));
				f.append("...");
			} else
				f.append(typeString(tp[i], baseName));
			if (i < pCount - 1)
				f.append(", ");
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
		ref<compiler.TemplateType> template = ref<compiler.TemplateType>(type);
		string s = "<a href=\"" + url + "\">" + template.definingSymbol().name() + "</a>";
		s.append("&lt;");
		ref<compiler.ParameterScope> p = ref<compiler.ParameterScope>(template.scope());
		ref<ref<compiler.Symbol>[]> params = p.parameters();
		for (i in *params) {
			ref<compiler.Symbol> sym = (*params)[i];
			if (i > 0)
				s.append(", ");
			if (sym.type() == null)
				s.printf("&lt;null&gt; %s", sym.name());
			else
				s.printf("%s %s", typeString(sym.type(), baseName), sym.name());
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
		sym = ref<compiler.FlagsInstanceType>(type).symbol();
		name = sym.name();
		s.printf("<a href=\"%s\">%s</a>", url, name);
		return s;

	case	ENUM:
		classFile = classFiles[long(type.scope())];
		if (classFile == null)
			return null;
		url = storage.makeCompactPath(classFile, baseName);
		ref<compiler.Symbol> sym = ref<compiler.EnumInstanceType>(type).typeSymbol();
		string name = sym.name();
		s.printf("<a href=\"%s\">%s</a>", url, name);
		return s;

	case	SHAPE:
		ref<compiler.Type> e = type.elementType();
		ref<compiler.Type> i = type.indexType();
		if (compileContext.isVector(type)) {
			s = typeString(e, baseName);
			if (i != compileContext.builtInType(runtime.TypeFamily.SIGNED_32))
				s.printf("[%s]", typeString(i, baseName));
			else
				s.append("[]");
			return s;
		} else {
			// maps are a little more complicated. A map based on an integral type has to be declared as map<e, i>
			// while a map of a non-integral type can be written as e[i].
			if (compileContext.validMapIndex(i))
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

