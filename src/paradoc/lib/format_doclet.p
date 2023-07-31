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

string expandDocletString(string text, ref<compiler.Symbol> sym, string baseName) {
	string result = "";
	string linkText;
	boolean inlineTag;
	boolean closeA;
	boolean closeSpan;

	for (int i = 0; i < text.length(); i++) {
		if (text[i] == '{') {
			i++;
			switch (text[i]) {
			case '{':
				if (inlineTag)
					linkText.append('{');
				else
					result.append('{');
				break;

			case 'c':
				result.append("<span class=code>");
				inlineTag = false;
				closeSpan = true;
				break;

			case 'l':
				result.append("<span class=code>");
				inlineTag = true;
				closeSpan = true;
				closeA = true;
				break;

			case 'p':
				inlineTag = true;
				closeA = true;
				break;

			case '}':
				if (closeA) {
					result.append(transformLink(linkText, sym, baseName));
					closeA = false;
				}
				if (closeSpan) {
					closeSpan = false;
					result.append("</span>");
				}
				linkText = null;
				inlineTag = false;
			}
		} else if (inlineTag)
			linkText.append(text[i]);
		else
			result.append(text[i]);
	}
	if (closeA) {
		result.append(transformLink(linkText, sym, baseName));
		result.append("</a>");
	}
	if (closeSpan)
		result.append("</span>");
	return result;
}
/*
 * linkText consists of a link and an optional caption. Everything before the first space is the link.
 * The rest of the linkText is the caption.
 *
 * The actual link could be:
 *		<i>domain</i>:<i>namespace</i>.<i>class-chain</i>.<i>symbol</i>
 *		<i>domain</i>:<i>namespace</i>.<i>class-chain</i>
 *		<i>domain</i>:<i>namespace</i>.<i>symbol</i>
 *		<i>class-chain</i>.<i>symbol<i>
 *		<i>class-chain</i>
 * or
 *		<i>symbol</i>
 */
string transformLink(string linkTextIn, ref<compiler.Symbol> sym, string baseName) {
	string linkText = linkTextIn.trim();
	int idx = linkText.indexOf(' ');
	string caption;
	if (idx >= 0) {
		caption = linkText.substr(idx + 1).trim();
		linkText.resize(idx);
	} else
		caption = linkText;
	idx = linkText.indexOf(':');
	string path;
	if (idx >= 0) {
		string domain = linkText.substr(0, idx);
		ref<compiler.Scope> scope = compileContext.forest().getDomain(domain);
		if (scope == null)
			return caption;
		path = linkText.substr(idx + 1);
		string[] components = path.split('.');
		string directory = domain + "_";
		ref<compiler.Symbol> nm;
		int i;
		for (i = 0; i < components.length(); i++) {
			nm = scope.lookup(components[i], null);
			if (nm == null)
				return caption;
			if (nm.class != compiler.Namespace)
				break;
			scope = ref<compiler.Namespace>(nm).symbols();
			if (i > 0)
				directory += ".";
			directory += components[i];
		}
		path = storage.path(outputFolder, directory, null);
		if (i >= components.length()) {
			path = storage.path(path, "namespace-summary", "html");
			linkText = storage.makeCompactPath(path, baseName);
		} else {
			boolean hasClasses;
			for (; i < components.length() - 1; i++) {
				if (nm.type().family() != runtime.TypeFamily.TYPEDEF)
					return caption;
				if (!hasClasses) {
					hasClasses = true;
					path = storage.path(path, "classes", null);
				}
				path = storage.path(path, nm.name(), null);
				scope = scopeFor(nm);
				if (scope == null)
					return caption;
				nm = scope.lookup(components[i + 1], null);
				if (nm == null)
					return caption;
			}
			if (nm.type() != null && nm.type().family() == runtime.TypeFamily.TYPEDEF) {
				if (!hasClasses)
					path = storage.path(path, "classes", null);
				path = storage.path(path, nm.name(), "html");
				if (path == baseName)
					return caption;
				linkText = storage.makeCompactPath(path, baseName);
			} else {
				path += ".html";
				if (path == baseName)
					linkText = "#" + components[i];
				else
					linkText = storage.makeCompactPath(path, baseName) + "#" + components[i];
			}	
		}
	} else {
		ref<compiler.Namespace> nm;
		boolean hasClasses;
		if (sym.class == compiler.Namespace) {
			nm = ref<compiler.Namespace>(sym);
			path = storage.path(outputFolder, nm.domain() + "_" + nm.dottedName(), null);
		} else {
			nm = sym.enclosingNamespace();
			path = pathToMyParent(sym);
			if (sym.enclosing() != sym.enclosingUnit())
				hasClasses = true;
		}
		string[] components = linkText.split('.');
		ref<compiler.Scope> scope = scopeFor(sym);
		ref<compiler.Symbol> s = scope.lookup(components[0], null);
		if (s == null) {
			if (sym == nm)
				return caption;					// If we didn't find a symbol by looking in the namespace,
												// it's undefined, there's nowhere else to go.
			scope = sym.enclosing();
			if (scope == sym.enclosingUnit()) {
				if (nm.type() == null)
					return "*** Broken link " + linkText + " ***";
				scope = nm.type().scope();
			}
			s = scope.lookup(components[0], null);
			if (s == null)
				return caption;
		} else {
			if (!hasClasses) {
				hasClasses = true;
				path = storage.path(path, "classes", null);
			}
			path = storage.path(path, sym.name(), null);
		}
		for (int i = 0; i < components.length() - 1; i++) {
			if (s.type().family() != runtime.TypeFamily.TYPEDEF)
				return caption;
			if (!hasClasses) {
				hasClasses = true;
				path = storage.path(path, "classes", null);
			}
			path = storage.path(path, s.name(), null);
			scope = scopeFor(s);
			if (scope == null) {
				printf("%s has no scope\n", s.name());
				return caption;
			}
			s = scope.lookup(components[i + 1], null);
			if (s == null)
				return caption;
		}
		if (s.type() != null && s.type().family() == runtime.TypeFamily.TYPEDEF) {
			if (!hasClasses)
				path = storage.path(path, "classes", null);
			path = storage.path(path, s.name(), "html");
			if (path == baseName)
				return caption;
			linkText = storage.makeCompactPath(path, baseName);
		} else {
			path += ".html";
			if (path == baseName)
				linkText = "#" + components[components.length() - 1];
			else
				linkText = storage.makeCompactPath(path, baseName) + "#" + components[components.length() - 1];
		}
	}
	return "<a href=\"" + linkText + "\">" + caption + "</a>";
}

