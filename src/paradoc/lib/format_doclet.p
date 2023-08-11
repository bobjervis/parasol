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

string expandDocletString(ref<compiler.Doclet> doclet, string text, ref<compiler.Symbol> sym, string baseName) {
	string result = "";
	string linkText;
	string offsetText;
	boolean inlineTag;
	boolean inOffset;
	boolean closeA;
	boolean closeSpan;
	int offset;

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
				inOffset = false;
				closeSpan = true;
				break;

			case 'l':
				result.append("<span class=code>");
				inlineTag = true;
				inOffset = true;
				closeSpan = true;
				closeA = true;
				break;

			case 'p':
				inlineTag = true;
				inOffset = true;
				closeA = true;
				break;

			case '}':
				if (closeA) {
					result.append(transformLink(doclet, offset, linkText, sym, baseName));
					closeA = false;
				}
				if (closeSpan) {
					closeSpan = false;
					result.append("</span>");
				}
				linkText = null;
				inlineTag = false;
				inOffset = false;
			}
		} else if (inOffset) {
			if (text[i] != ';')
				offsetText.append(text[i]);
			else {
				inOffset = false;
				offset = int.parse(offsetText);
				offsetText = null;
			}
		} else if (inlineTag)
			linkText.append(text[i]);
		else
			result.append(text[i]);
	}
	if (closeA) {
		result.append(transformLink(doclet, offset, linkText, sym, baseName));
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
string transformLink(ref<compiler.Doclet> doclet, int location, string linkTextIn, ref<compiler.Symbol> sym, string baseName) {
//	printf("transformLink('%s', ..., %s)\n", linkTextIn, baseName);
//	sym.print(0, false);
	string linkText = linkTextIn.trim();
	int idx = linkText.indexOf(' ');
	string caption;
	if (idx >= 0) {
		caption = linkText.substr(idx + 1).trim();
		linkText.resize(idx);
	} else
		caption = linkText;
	idx = linkText.indexOf(':');
	string[] components;
	ref<compiler.Scope> scope;
	if (idx >= 0) {
		string domain = linkText.substr(0, idx);
		scope = compileContext.forest().getDomain(domain);
		if (scope == null) {
			printLinkError(doclet, location, linkTextIn.trim());
//			printf("Link to %s in generated file %s is undefined.\n", linkText, baseName);
			return caption;			// If we didn't find a symbol by looking in the lexical scopes,
									// it's undefined, there's nowhere else to go.
		}
		components = linkText.substr(idx + 1).split('.');
	} else {
		components = linkText.split('.');
		scope = scopeFor(sym);
	}
	ref<compiler.Symbol> s;
	for (i in components) {
		if (scope == null) {
			printLinkError(doclet, location, linkTextIn.trim());
//			printf("Link to %s in generated file %s is undefined.\n", linkText, baseName);
			return caption;			// If we didn't find a symbol by looking in the lexical scopes,
									// it's undefined, there's nowhere else to go.
		}
		do {
			s = scope.lookup(components[i], null);
			if (s != null || i > 0 || idx >= 0)
				break;
			scope = scope.enclosing();
		} while (scope != null);
		if (s == null) {
			printLinkError(doclet, location, linkTextIn.trim());
//			printf("Link to %s in generated file %s is undefined.\n", linkText, baseName);
			return caption;			// If we didn't find a symbol by looking in the lexical scopes,
									// it's undefined, there's nowhere else to go.
		}
		if (i == components.length() - 1)
			break;
		scope = scopeFor(s);
	}
	string path = linkTo(s);
	if (path == null) {
		printLinkError(doclet, location, linkTextIn.trim());
//		printf("Link to %s in generated file %s is undefined.\n", linkTextIn.trim(), baseName.substr(suffix));
		return caption;
	}
	linkText = storage.makeCompactPath(path, baseName);
	int suffix = outputFolder.length() + 1;
	if (verboseOption.set())
		printf("File %3$s links to %2$s as %1$s\n", linkText, path.substr(suffix), baseName.substr(suffix));
/*
				if (s.type().family() != runtime.TypeFamily.TYPEDEF)
					return caption;
				if (!hasClasses) {
					hasClasses = true;
					path = storage.path(path, "classes");
				}
				path = storage.path(path, s.name());
				scope = scopeFor(s);
				if (scope == null) {
					printf("%s has no scope\n", s.name());
					return caption;
				}
				s = scope.lookup(components[i + 1], null);
				if (s == null)
					return caption;
			}
			if (!hasClasses) {
				hasClasses = true;
				path = storage.path(path, "classes");
			}
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
 */
	return "<a href=\"" + linkText + "\">" + caption + "</a>";
}

private void printLinkError(ref<compiler.Doclet> doclet, int location, string linkText) {
	runtime.SourceOffset loc(location);
	int lineNumber = doclet.unit.lineNumber(loc);
	if (lineNumber >= 0)
		printf("%s %d: Link '%s' is undefined\n", doclet.unit.filename(), lineNumber + 1, linkText);
	else
		printf("%s [byte %d]: Link '%s' is undefined\n", doclet.unit.filename(), loc.offset, linkText);
}

