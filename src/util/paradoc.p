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
import parasol:memory;
import parasol:storage;
import parasol:process;
import parasol:runtime;
import parasol:compiler.Arena;
import parasol:compiler.BuiltInType;
import parasol:compiler.ClassDeclarator;
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

class Paradoc extends process.Command {
	public Paradoc() {
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
		importPathOption = stringOption('I', "importPath", 
					"Sets the path of directories like the --explicit option, " +
					"but the directory ^/src/lib is appended to " +
					"those specified with this option.");
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		symbolTableOption = booleanOption(0, "syms",
					"Print the symbol table.");
		logImportsOption = booleanOption(0, "logImports",
					"Log all import processing");
		explicitOption = stringOption('X', "explicit",
					"Sets the path of directories to search for imported symbols. " +
					"Directories are separated by commas. " +
					"The special directory ^ can be used to signify the Parasol " +
					"install directory. ");
		rootOption = stringOption(0, "root",
					"Designates a specific directory to treat as the 'root' of the install tree. " +
					"The default is the parent directory of the runtime binary program.");
		templateDirectoryOption = stringOption('t', "template",
					"Designates a directory to treat as the source for a set of template files. " +
					"These templates fill in details of the generated HTML and can be customized " +
					"without modifying the program code.");
		contentDirectoryOption = stringOption('c', "content",
					"Designates that the output directory named in the command line is to be " +
					"constructed by copying recursively the contents of the directory named by " +
					"this option. " +
					"Each file with a .ph extension is processed by paradoc and replaced by a file " +
					"with the same name, but with a .html extension.");
		helpOption('?', "help",
					"Displays this help.");
	}

	ref<process.Option<string>> importPathOption;
	ref<process.Option<boolean>> verboseOption;
	ref<process.Option<string>> explicitOption;
	ref<process.Option<string>> rootOption;
	ref<process.Option<boolean>> logImportsOption;
	ref<process.Option<boolean>> symbolTableOption;
	ref<process.Option<string>> templateDirectoryOption;
	ref<process.Option<string>> contentDirectoryOption;
}

private ref<Paradoc> paradoc;
private string[] finalArguments;
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
	process.stdout.flush();
	parseCommandLine(args);
	outputFolder = finalArguments[0];

//	printf("Configuring\n");
	if (!configureArena(&arena))
		return 1;
	CompileContext context(&arena, arena.global(), paradoc.verboseOption.value, memory.StartingMemoryHeap.PRODUCTION_HEAP, null, null);

	for (int i = 1; i < finalArguments.length(); i++)
		libraries.append(arena.compilePackage(i - 1, &context));
//	printf("Starting!\n");
	arena.finishCompilePackages(&context);

	// We are now done with compiling, time to analyze the results

	if (paradoc.symbolTableOption.value)
		arena.printSymbolTable();
	if (paradoc.verboseOption.value)
		arena.print();
	boolean anyFailure = false;
	if (arena.countMessages() > 0) {
		printf("Failed to compile\n");
		arena.printMessages();
		anyFailure = true;
	}
//	printf("Done!\n");
	if (storage.exists(outputFolder) && !storage.deleteDirectoryTree(outputFolder)) {
		printf("Failed to clean up old output folder '%s'\n", outputFolder);
		return 1;
	}
	printf("Writing to %s\n", outputFolder);
	if (storage.ensure(outputFolder)) {

		// First set up source file paths.

		string dir;
		if (paradoc.templateDirectoryOption.set())
			dir = paradoc.templateDirectoryOption.value;
		else {
			string bin = process.binaryFilename();
			
			dir = storage.constructPath(storage.directory(bin), "../template", null);
		}
		string cssFile = storage.constructPath(dir, "stylesheet", "css");
		string newCss = storage.constructPath(outputFolder, "stylesheet", "css");
		if (!storage.copyFile(cssFile, newCss))
			printf("Could not copy CSS file from %s to %s\n", cssFile, newCss);
		template1file = storage.constructPath(dir, "template1", "html");
		template1bFile = storage.constructPath(dir, "template1b", "html");
		template2file = storage.constructPath(dir, "template2", "html");
		stylesheetPath = storage.constructPath(outputFolder, "stylesheet", "css");

		// Also do internal processing of the symbol table.

		if (!collectNamespacesToDocument())
			anyFailure = true;

		// If we ar e using a content directory, start from it.

		if (paradoc.contentDirectoryOption.set())
			anyFailure = !processContentDirectory(paradoc.contentDirectoryOption.value, dir);
		if (!indexTypes())
			anyFailure = true;
		if (!generateNamespaceDocumentation())
			anyFailure = true;
	} else {
		printf("Could not create the output folder\n");
		anyFailure = true;
	}
	if (anyFailure)
		return 1;
	else
		return 0;
}

ref<Content>[] content;
ref<Content>[string] fileMap;
ref<Content>[] topicHolders;

boolean processContentDirectory(string contentDirectory, string templateDirectory) {
	if (!storage.exists(contentDirectory)) {
		printf("Content directory '%s' does not exist.\n", contentDirectory);
		return false;
	}
	if (!storage.isDirectory(contentDirectory)) {
		printf("Indicate content directory '%s' is not a directory.\n", contentDirectory);
		return false;
	}
	Content c;
	c.type = ContentType.DIRECTORY;
	c.path = contentDirectory;
	content.append(&c);
	collectContentInventory(contentDirectory, contentDirectory);

	// Okay, start building the destination directory


	boolean success = true;
	for (i in content) {
		ref<Content> c = content[i];

		fileMap[c.path] = c;
		switch (c.type) {
		case DIRECTORY:
			if (storage.ensure(c.targetPath))
				printf("%s %s - created\n", c.targetPath, string(c.type));
			else
				success = false;
			break;

		case FILE:
			if (storage.copyFile(c.path, c.targetPath))
				printf("%s %s - created\n", c.targetPath, string(c.type));
			else
				success = false;
			break;

		case PH_FILE:
			if (!c.processPhFile())
				success = false;
		}
	}

	// We've parsed in all the .ph files. Now we have to process the macros.

	if (paradoc.verboseOption.set()) {
		for (i in content) {
			ref<Content> c = content[i];
			string caption;
	
			caption.printf("[%d]", i);
			printf("%7s %20s %s\n", caption, string(c.type), c.path);
		}
	}

	// First, thread the topics and levels so that we know how to number them.


	ref<Content> targetFile = getTargetFile(null, null);
	if (targetFile != null)	// we have an index.ph, at least. Start lacing things up.
		thread(targetFile);

	byte[] numberingStyles;
	string[] numberingInterstitials;

	(numberingStyles, numberingInterstitials) = parseNumbering();

	int[] levelCounts;		// each element contains the last value assigned for that level.
	int previousLevel;		// the number of the previous level tag to be processed.
	for (i in topicHolders) {
//		printf("[%d] %s\n", i, topicHolders[i].path);

		ref<Content> c = topicHolders[i];

		for (j in c.levels) {
			ref<MacroSpan> l = c.levels[j];

			int level;
			boolean b;
			(level, b) = int.parse(l.argument(0));
			if (!b) {
				printf("Level %s is not an integer in file %s\n", l.argument(0), c.path);
				success = false;
			}
			if (level < 0 || level > numberingStyles.length()) {
				printf("level %d in file %s is out of range (0-%d)\n", level, c.path, numberingStyles.length());
				success = false;
			} else if (level > 0) {
				if (levelCounts.length() < level)
					levelCounts.resize(level);
				levelCounts[level - 1] += 1;
				for (int i = level; i < levelCounts.length(); i++)
					levelCounts[i] = 0;
				string newContent;
				for (int i = 0; i < level; i++) {
					newContent += numberingInterstitials[i];
					switch (numberingStyles[i]) {
					case '1':
						newContent += string(levelCounts[i]);
						break;
					}
				}
				newContent += numberingInterstitials[numberingInterstitials.length() - 1] + " " + l.argument(1);
				l.content = newContent;
			} else {
				l.content = l.argument(1);
			}
			l.done();
		}
	}
	for (i in topicHolders) {
		ref<Content> c = topicHolders[i];
		for (j in c.topics)
			c.topics[j].setTopicGroup();
	}

/*

	for (i in content) {
		ref<Content> c = content[i];

		for (j in c.topics) {
			ref<MacroSpan> m = c.topics[j];

			ref<Content> targetFile = getTargetFile(c, m.argument(0));
			if (targetFile == null)
				continue;
			if (targetFile.levels.length() == 0) {
				printf("No level defined in target file %s for topic %s in %s\n", targetFile.path, m.argument(0), c.path);
				success = false;
				continue;
			}
			ref<MacroSpan> l = targetFile.levels[0];
			
		}		
	}
*/
	for (i in formattingOptions)
		printf("[%s] = '%s'\n", i, formattingOptions[i]);

	// Now write the processed PH files

	for (i in content) {
		ref<Content> c = content[i];

		if (c.type == ContentType.PH_FILE) {
			if (c.writePhFile())
				printf("%s %s - created\n", c.targetPath, string(c.type));
			else
				success = false;
		}
	}
	return success;
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

void thread(ref<Content> file) {
	if (file.topics.length() > 0) {
		topicHolders.append(file);
		for (i in file.topics) {
			ref<MacroSpan> t = file.topics[i];

			ref<Content> f = getTargetFile(file, t.argument(0));
			if (f.levels.length() > 0)
				t.target = f.levels[0];
			thread(f); 
		}
	} else if (file.levels.length() > 0)
		topicHolders.append(file);
}

ref<Content> getTargetFile(ref<Content> source, string reference) {
	string target;
	ref<Content> targetFile;

	if (source != null) {
		target = storage.constructPath(source.sourceDirectory(), reference, null);
		targetFile = fileMap[target];
		if (targetFile == null) {
			printf("Could not find target file for topic %s in file %s\n", reference, source.path);
			return null;
		}
	} else
		targetFile = content[0];
	if (targetFile.type == ContentType.DIRECTORY) {
		target = storage.constructPath(targetFile.path, "index.ph", null);
		targetFile = fileMap[target];
		if (targetFile == null) {
			if (source != null)
				printf("No index.ph for target directory %s in file %s\n", reference, source.path);
			else
				printf("No index.ph for content directory %s\n", content[0].path);
			return null;
		}
	}
	return targetFile;
}

enum ContentType {
	FILE,
	DIRECTORY,
	PH_FILE
}

class Content {
	ContentType type;
	string path;
	string targetPath;
	ref<Span>[] spans;
	ref<Span> open;
	ref<MacroSpan> topLevel;
	ref<MacroSpan>[] topics;
	ref<MacroSpan>[] links;
	ref<MacroSpan>[] docLinks;
	ref<MacroSpan>[] levels;

	string sourceDirectory() {
		if (type == ContentType.DIRECTORY)
			return path;
		else
			return storage.directory(path);
	}

	string targetDirectory() {
		if (type == ContentType.DIRECTORY)
			return targetPath;
		else
			return storage.directory(targetPath);
	}

	boolean processPhFile() {
		ref<Reader> r = storage.openTextFile(path);
		if (r == null)
			return false;
		boolean success = true;
		for (;;) {
			int ch = r.read();

			if (ch < 0)
				break;
			if (ch == '{') {
				int ch2 = r.read();
				if (ch2 == '@') {
					flushOpen();
					open = new MacroSpan;
					int macro;
					for (;;) {
						macro = r.read();
						if (macro < 0)
							break;
						if (macro == '}') {
							if (!open.parse(this))
								success = false;
							flushOpen();
							break;
						}
						record(macro);
					}
				} else {
					record('{');
					r.unread();
				}
			} else
				record(ch);
		}
		flushOpen();
		delete r;
		return success;
	}

	private void record(int data) {
		if (open == null)
			open = new Span;
		open.content.append(byte(data));
	}

	private void flushOpen() {
		if (open != null) {
			spans.append(open);
			open = null;
		}
	}

	boolean writePhFile() {
		ref<Writer> w = storage.createTextFile(targetPath);

		insertTemplate1(w, targetPath);
//		w.printf("<title>%s</title>\n", corpusTitle);
		w.write("</head>\n<body>\n");
		boolean success = true;
		for (i in spans) {
			if (spans[i].content != null)
				w.write(spans[i].content);
			else
				success = false;
		}
		w.write("</body>\n");
		delete w;
		return success;
	}
}

class Span {
	string content;

	boolean parse(ref<Content> file) {
		return false;
	}
}

enum Verb {
	OPTION(2),
	PARADOC(2),
	TOPIC(1),
	LEVEL(2),
	LINK(2),
	DOC_LINK(2),
	ANCHOR(1),
	CODE(0),
	GRAMMAR(0),
	PRODUCTION(2),
	END_GRAMMAR(0),
	PROCESSED(0)		// The verb of any completely processed macro is changed to this one, which simply does no further work.
	;
	private int _arguments;

	Verb(int arguments) {
		_arguments = arguments;
	}

	int arguments() {
		return _arguments;
	}
}

Verb[string] verbs;
verbs["code"] = Verb.CODE;
verbs["option"] = Verb.OPTION;
verbs["paradoc"] = Verb.PARADOC;
verbs["topic"] = Verb.TOPIC;
verbs["level"] = Verb.LEVEL;
verbs["link"] = Verb.LINK;
verbs["doc-link"] = Verb.DOC_LINK;
verbs["anchor"] = Verb.ANCHOR;
verbs["code"] = Verb.CODE;
verbs["grammar"] = Verb.GRAMMAR;
verbs["production"] = Verb.PRODUCTION;
verbs["end-grammar"] = Verb.END_GRAMMAR;

string[string] formattingOptions;

// default formatting options
formattingOptions["numbering"] = "I.A.1.a";

ref<Content>[string] anchors;

class MacroSpan extends Span {
	private Verb _verb;
	private ref<Content> _enclosing;
	private string[] _arguments;
	ref<MacroSpan> target;				// for TOPIC verbs, this is the first LEVEL verb under that topic.
	private byte _level;
	private int _index;

	boolean parse(ref<Content> file) {
		_enclosing = file;
		if (content == null)
			return false;
		int index = endOfToken(content);
		substring verb;
		substring arguments;
		if (index >= 0) {
			verb = content.substr(0, index);
			arguments = content.substr(index + 1);
		} else {
			verb = content;
			arguments = "";
		}
		if (verbs.contains(verb)) {
			_verb = verbs[verb];
			int argumentCount = _verb.arguments();

			while (argumentCount > 1) {
				index = endOfToken(arguments);
				if (index < 0) {
					printf("Expecting %d arguments with verb %s in %s\n", _verb.arguments(), verb, file.path);
					return false;
				}
				_arguments.append(arguments.substr(0, index));
				arguments = arguments.substr(index + 1);
				argumentCount--;
			}
			if (argumentCount > 0)
				_arguments.append(arguments);
			if (paradoc.verboseOption.set()) {
				printf("Processing verb %s(", string(_verb));
				for (i in _arguments) {
					if (i > 0)
						printf(",'%s'", _arguments[i]);
					else
						printf("'%s'", _arguments[i]);
				}
				printf(")\n");
			}
			switch (_verb) {
			case CODE:
				content = "<pre class=code>" + arguments + "</pre>";
				break;

			case OPTION:
				formattingOptions[_arguments[0]] = _arguments[1];
				content = "";
				break;

			case PARADOC:
				outputFolder = storage.constructPath(file.targetDirectory(), _arguments[0]);
				content = "<a href=\"" + _arguments[0] + "\">" + _arguments[1] + "</a>";
				break;

			case TOPIC:
				string target = storage.constructPath(file.sourceDirectory(), _arguments[0]);
				_index = file.topics.length();
				file.topics.append(this);
				break;

			case LEVEL:
				if (file.topLevel == null)
					file.topLevel = this;
				boolean success;
				(_level, success) = byte.parse(_arguments[0]);
				if (!success) {
					printf("Level %s is not valid in file %s\n", _arguments[0], file.path);
					return false;
				}
				_index = file.levels.length();
				file.levels.append(this);
				break;

			case DOC_LINK:
				file.docLinks.append(this);
				break;

			case ANCHOR:
				if (anchors.contains(_arguments[0])) {
					printf("Anchor %s in %s duplicates an anchor in %s\n", _arguments[0], file.path, anchors[_arguments[0]].path);
					return false;
				}
				anchors[_arguments[0]] = file;
				content = "<a name=\"" + _arguments[0] + "\"></a>";
				break;

			case LINK:
				file.links.append(this);
				break;

			case GRAMMAR:
				content = "<table class=grammar><thead><td class=lhs></td><td>Production</td></thead>\n";
				break;

			case PRODUCTION:
				if (_arguments[0] != "|")
					content = "<tr class=production><td><i>" + _arguments[0] + "</i>:</td><td><span style=\"font-family:monospace;\">&nbsp;&nbsp;</span>" + _arguments[1] + "</td><tr>\n";
				else
					content = "<tr><td></td><td><span style=\"font-family:monospace;\">| </span>" + _arguments[1] + "</td><tr>\n";
				break;

			case END_GRAMMAR:
				content = "</table>\n";
				break;
			}
		} else {
			printf("Unknown verb %s in %s: {@%s}\n", verb, file.path, content);
			return false;
		}
		return true;
	}
	/**
	 * Construct the final content string for a 'topic' macro. The target, if not null, is a level
	 * macro that satisfies the requirements of being the first level macro in the file named in the topic macro.
	 */
	void setTopicGroup() {
		if (target != null)
			content = target.levelGroup(_enclosing);
		else {
			string href = _enclosing.path;
			href = href.substr(0, href.length() - 3) + ".html";
			content = "<a href=\"" + href + "\">" + href + "</a>";		
		}
	}

	private string levelGroup(ref<Content> base) {
		string href = storage.makeCompactPath(_enclosing.path, base.path);
		if (href.endsWith(".ph"))
			href = href.substr(0, href.length() - 3) + ".html";
		string output = "<a href=\"" + href + "\">" + content + "</a>";

		string group;
		boolean finished;
		int startAt = _index + 1;
		int i;
		while (topicHolders[i] != _enclosing)
			i++;
		do {
			ref<Content> c = topicHolders[i];
			for (int j = startAt; j < c.levels.length(); j++) {
				ref<MacroSpan> l = c.levels[j];

				if (l._level <= _level) {
					finished = true;
					break;
				}
				// ignore any levels deeper than one more than the target
				if (l._level > _level + 1)
					continue;
				string tg = l.levelGroup(base);
				if (tg != null)
					group.append("<li>" + tg);
			}
			i++;
			startAt = 0;
		} while (!finished && i < topicHolders.length());
		if (group.length() > 0)
			output += "<ul>\n" + group + "</ul>\n";
		return output;
	}

	void done() {
		_verb = Verb.PROCESSED;
	}

	ref<Content> enclosing() {
		return _enclosing;
	}

	string argument(int i) {
		return _arguments[i];
	}

	void print() {
		printf("File %s %s(", _enclosing.path, string(_verb));
		for (i in _arguments) {
			if (i > 0)
				printf(",");
			printf("'%s'", _arguments[i]);
		}
		printf(")");
		if (target != null)
			printf(" target %p(%s)", target, string(target._verb));
		printf("\n");
	}
}

	
int endOfToken(substring s) {
	for (int i = 0; i < s.length(); i++)
		if (s[i] == ' ' ||
			s[i] == '\t' ||
			s[i] == '\n')
			return i;
	return -1;
}

void collectContentInventory(string baseDirectory, string directory) {
	ref<storage.Directory> d = new storage.Directory(directory);
	if (d.first()) {
		do {
			ref<Content> c = new Content;

			c.path = d.path();
			switch (d.filename()) {
			case ".":
			case "..":
				break;

			default:
				if (storage.isDirectory(c.path)) {
					c.type = ContentType.DIRECTORY;
					c.targetPath = storage.constructPath(outputFolder, c.path.substr(baseDirectory.length() + 1), null);
				} else if (c.path.endsWith(".ph")) {
					c.type = ContentType.PH_FILE;
					c.targetPath = storage.constructPath(outputFolder, c.path.substr(baseDirectory.length() + 1, c.path.length() - 2) + "html", null);
				} else {
					c.type = ContentType.FILE;
					c.targetPath = storage.constructPath(outputFolder, c.path.substr(baseDirectory.length() + 1), null);
				}
				content.append(c);
				if (paradoc.verboseOption.set())
					printf("%s %s %s\n", c.path, c.targetPath, string(c.type));
				if (c.type == ContentType.DIRECTORY)
					collectContentInventory(baseDirectory, c.path);
			}
		} while (d.next());
	}
	delete d;
}

void parseCommandLine(string[] args) {
	paradoc = new Paradoc();
	if (!paradoc.parse(args))
		paradoc.help();
	if (paradoc.importPathOption.set() &&
		paradoc.explicitOption.set()) {
		printf("Cannot set both --explicit and --importPath arguments.\n");
		paradoc.help();
	}
	finalArguments = paradoc.finalArguments();
}

boolean configureArena(ref<Arena> arena) {
	arena.paradoc = true;
	arena.logImports = paradoc.logImportsOption.value;
	if (paradoc.rootOption.set())
		arena.setRootFolder(paradoc.rootOption.value);
	string importPath;

	for (int i = 1; i < finalArguments.length(); i++) {
		if (i > 1)
			importPath.append(',');
		importPath.append(finalArguments[i]);
	}
	if (paradoc.explicitOption.set()) {
		if (paradoc.explicitOption.value.length() > 0) {
			if (finalArguments.length() > 1)
				importPath.append(',');
			importPath.append(paradoc.explicitOption.value);
		}
	} else if (paradoc.importPathOption.set()) {
		if (finalArguments.length() > 1)
			importPath.append(',');
		importPath.append(paradoc.importPathOption.value + ",^/src/lib");
	} else {
		if (finalArguments.length() > 1)
			importPath.append(',');
		importPath.append("^/src/lib");
	}
	arena.setImportPath(importPath);
	arena.verbose = paradoc.verboseOption.value;
	if (arena.logImports)
		printf("Running with import path: %s\n", arena.importPath());
	if (arena.load())
		return true;
	else {
		arena.printMessages();
		if (paradoc.verboseOption.value)
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
					ref<Doclet> doclet = nm.doclet();
					if (doclet == null || !doclet.ignore) {
						Names item;
						item.name = nameSpace;
						item.symbol = nm;
						names.append(item);
					}
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
	string name = sym.name();
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
			if (sym.doclet() != null && sym.doclet().ignore)
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
				if (oi.doclet() != null && oi.doclet().ignore)
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
			overview.write(expandDocletString(doclet.summary, sym, overviewPage));
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

	ref<Doclet> doclet = nm.doclet();
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
	return storage.constructPath(namespaceDir(nm), "namespace-summary", "html");
}

string namespaceDir(ref<Namespace> nm) {
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
	ref<Doclet> doclet = sym.doclet();
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

	case	TEMPLATE:
		classPage.printf("<table class=template-params>\n");
		classPage.printf("<tr>\n");
		classPage.printf("<td>%sClass&nbsp;%s&lt;</td>\n<td>", t.isConcrete(null) ? "" : "Abstract&nbsp;", name);
		ref<ParameterScope> p = ref<ParameterScope>(scope);
		assert(t.class == TemplateType);
		ref<ref<Symbol>[]> params = p.parameters();
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
			ref<Symbol> param = (*params)[i];
			string pname = param.name();
			if (param.type() == null)
				classPage.printf("&lt;null&gt;&nbsp;%s", pname);
			else
				classPage.printf("%s&nbsp;%s", typeString(param.type(), classFile), pname);
			if (i < params.length() - 1)
				classPage.write(",</td>\n");
			else
				classPage.write("&gt;</td>\n");
			string comment = paramMap[pname];
			if (comment != null)
				classPage.printf("<td><div class=param-text>%s</div></td>\n", expandDocletString(comment, sym, classFile));
			if (i < params.length() - 1)
				classPage.write("</tr>\n<tr>\n<td></td><td>");
		}
		classPage.write("</tr>\n</table>\n");
		generateClassInfo(t, classPage, classFile);
		ref<TemplateType> template = ref<TemplateType>(t);
		ref<Template> temp = template.definition();
		scope = temp.classDef.scope;
		break;

	default:
		classPage.printf("<div class=class-title>%sClass %s", t.isConcrete(null) ? "" : "Abstract ", name);
		classPage.printf("</div>\n");
		generateClassInfo(t, classPage, classFile);
	}
	if (doclet != null) {
		if (doclet.author != null)
			classPage.printf("<div class=author><span class=author-caption>Author: </span>%s</div>\n", expandDocletString(doclet.author, sym, classFile));
		if (doclet.deprecated != null)
			classPage.printf("<div class=deprecated-outline><div class=deprecated-caption>Deprecated</div><div class=deprecated>%s</div></div>\n", expandDocletString(doclet.deprecated, sym, classFile));
		classPage.printf("<div class=class-text>%s</div>\n", expandDocletString(doclet.text, sym, classFile));
		if (doclet.threading != null)
			classPage.printf("<div class=threading-caption>Threading</div><div class=threading>%s</div>\n", expandDocletString(doclet.threading, sym, classFile));
		if (doclet.since != null)
			classPage.printf("<div class=since-caption>Since</div><div class=since>%s</div>\n", expandDocletString(doclet.since, sym, classFile));
		if (doclet.see != null)
			classPage.printf("<div class=see-caption>See Also</div><div class=see>%s</div>\n", expandDocletString(doclet.see, sym, classFile));
	}

	string subDir = storage.constructPath(dirName, name, null);

	generateScopeContents(scope, classPage, subDir, classFile, "Member", "Method", enumLabel, isInterface, hasConstants);

	delete classPage;
	return true;
}

void generateClassInfo(ref<Type> t, ref<Writer> classPage, string classFile) {
	classPage.printf("<div class=class-hierarchy>");
	generateBaseClassName(classPage, t, classFile, false);
	classPage.printf("</div>\n");
	ref<ref<InterfaceType>[]> interfaces = t.interfaces();
	if (interfaces != null && interfaces.length() > 0) {
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
		s.append(ref<ClassDeclarator>(definition).name().identifier());
		break;

	case	TEMPLATE:
		s.append(ref<Template>(definition).name().identifier());
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
			if (sym.doclet() != null && sym.doclet().ignore)
				continue;
			ref<Type> type = sym.type();
			if (type == null)
				continue;
			if (!isInterface && 
				sym.visibility() != Operator.PUBLIC &&
				sym.visibility() != Operator.PROTECTED)
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

				if (oi.doclet() != null && oi.doclet().ignore)
					continue;
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
		ref<OverloadInstance> sym = ps.symbol;
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
			output.printf("<td class=\"linkcol\"><a href=\"#%s\"\">%s</a></td>\n", sym.name(), sym.name());
			output.write("<td class=\"descriptioncol\">");
			ref<Doclet> doclet = sym.doclet();
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
			output.printf("<a href=\"#%s\"><span class=code>%s</span></a><br>", sym.name(), sym.name());
			ref<Doclet> doclet = sym.doclet();
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
			string name = sym.name();

			output.printf("<a id=\"%s\"></a>\n", name);
			output.printf("<div class=entity>%s</div>\n", name);
			output.printf("<div class=declaration>public static final %s %s <span class=\"enum-value\">(%d)</span></div>\n", typeString(sym.type(), baseName), name, sym.offset);
			ref<Doclet> doclet = sym.doclet();
			if (doclet != null)
				output.printf("\n<div class=enum-description>%s</div>", expandDocletString(doclet.text, sym, baseName));
		}
		output.printf("</div>\n");
	}

	if (objects.length() > 0) {
		output.printf("<div class=block>\n");
		output.printf("<div class=block-header>%s Detail</div>\n", objectLabel);
		for (i in objects) {
			ref<Symbol> sym = objects[i];
			string name = sym.name();

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
			ref<Doclet> doclet = sym.doclet();
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
//		sym.printSimple();
		ref<Type> symType = sym.type();
		if (symType == null || symType.family() == TypeFamily.CLASS_DEFERRED) {
			continue;
		}
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
			pointer<ref<Type>> tp = ft.returnTypes();
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
		pointer<ref<Type>> tp = ft.parameters();
		ref<ParameterScope> scope = ft.functionScope();
		ref<ref<Symbol>[]> parameters = scope.parameters();
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
		ref<Doclet> doclet = sym.doclet();
		if (doclet != null)
			output.printf("\n<div class=descriptioncol>%s</div>", expandDocletString(doclet.summary, sym, baseName));
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
		ref<Type> symType = sym.type();
		if (symType == null || symType.family() == TypeFamily.CLASS_DEFERRED) {
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
		else if (sym.enclosing() == sym.enclosingClassScope() && sym.storageClass() == StorageClass.STATIC)
			output.write("static&nbsp;");
		ref<NodeList> nl;
		ref<FunctionType> ft = ref<FunctionType>(sym.type());
		if (!asConstructors) {
			pointer<ref<Type>> tp = ft.returnTypes();
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

		pointer<ref<Type>> tp = ft.parameters();
		ref<ParameterScope> scope = ft.functionScope();
		ref<ref<Symbol>[]> parameters = scope.parameters();
		int j = 0;
		ref<Doclet> doclet = sym.doclet();
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
			string pname = (*parameters)[j].name();
			if (parameters != null && parameters.length() > j)
				output.printf("&nbsp;%s", pname);
			else
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

void generateTypeSummaryEntry(ref<Writer> output, int i, ref<Symbol> sym, string dirName, string baseName) {
	ref<Scope> scope = scopeFor(sym);
	if (scope == null)
		return;
	output.printf("<tr class=\"%s\">\n", i % 2 == 0 ? "altColor" : "rowColor");

	string name = sym.name();
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

	string name = sym.name();
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
	if (sym.type() == null)
		output.printf("&lt;null&gt;</td>\n");
	else		
		output.printf("%s</td>\n", typeString(sym.type(), baseName));

	output.write("<td class=\"descriptioncol\">");
	ref<Doclet> doclet = sym.doclet();
	if (doclet != null)
		output.write(expandDocletString(doclet.summary, sym, baseName));
	output.write("</td>\n");
	output.write("</tr>\n");
}

string expandDocletString(string text, ref<Symbol> sym, string baseName) {
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
string transformLink(string linkTextIn, ref<Symbol> sym, string baseName) {
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
		ref<Scope> scope = arena.getDomain(domain);
		if (scope == null)
			return caption;
		path = linkText.substr(idx + 1);
		string[] components = path.split('.');
		string directory = domain + "_";
		ref<Symbol> nm;
		int i;
		for (i = 0; i < components.length(); i++) {
			nm = scope.lookup(components[i], null);
			if (nm == null)
				return caption;
			if (nm.class != Namespace)
				break;
			scope = ref<Namespace>(nm).symbols();
			if (i > 0)
				directory += ".";
			directory += components[i];
		}
		path = storage.constructPath(outputFolder, directory, null);
		if (i >= components.length()) {
			path = storage.constructPath(path, "namespace-summary", "html");
			linkText = storage.makeCompactPath(path, baseName);
		} else {
			boolean hasClasses;
			for (; i < components.length() - 1; i++) {
				if (nm.type().family() != TypeFamily.TYPEDEF)
					return caption;
				if (!hasClasses) {
					hasClasses = true;
					path = storage.constructPath(path, "classes", null);
				}
				path = storage.constructPath(path, nm.name(), null);
				scope = scopeFor(nm);
				if (scope == null)
					return caption;
				nm = scope.lookup(components[i + 1], null);
				if (nm == null)
					return caption;
			}
			if (nm.type() != null && nm.type().family() == TypeFamily.TYPEDEF) {
				if (!hasClasses)
					path = storage.constructPath(path, "classes", null);
				path = storage.constructPath(path, nm.name(), "html");
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
		ref<Namespace> nm;
		boolean hasClasses;
		if (sym.class == Namespace) {
			nm = ref<Namespace>(sym);
			path = storage.constructPath(outputFolder, nm.domain() + "_" + nm.dottedName(), null);
		} else {
			nm = sym.enclosingNamespace();
			path = pathToMyParent(sym);
			if (sym.enclosing() != sym.enclosingUnit())
				hasClasses = true;
		}
		string[] components = linkText.split('.');
		ref<Scope> scope = scopeFor(sym);
		ref<Symbol> s = scope.lookup(components[0], null);
		if (s == null) {
			if (sym == nm)
				return caption;					// If we didn't find a symbol by looking in the namespace,
												// it's undefined, there's nowhere else to go.
			scope = sym.enclosing();
			if (scope == sym.enclosingUnit())
				scope = nm.type().scope();
			s = scope.lookup(components[0], null);
			if (s == null)
				return caption;
		} else {
			if (!hasClasses) {
				hasClasses = true;
				path = storage.constructPath(path, "classes", null);
			}
			path = storage.constructPath(path, sym.name(), null);
		}
		for (int i = 0; i < components.length() - 1; i++) {
			if (s.type().family() != TypeFamily.TYPEDEF)
				return caption;
			if (!hasClasses) {
				hasClasses = true;
				path = storage.constructPath(path, "classes", null);
			}
			path = storage.constructPath(path, s.name(), null);
			scope = scopeFor(s);
			if (scope == null) {
				printf("%s has no scope\n", s.name());
				return caption;
			}
			s = scope.lookup(components[i + 1], null);
			if (s == null)
				return caption;
		}
		if (s.type() != null && s.type().family() == TypeFamily.TYPEDEF) {
			if (!hasClasses)
				path = storage.constructPath(path, "classes", null);
			path = storage.constructPath(path, s.name(), "html");
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
/*
 * sym is a symbol, possibly a namespace, class, function  or object.
 */
string pathToMyParent(ref<Symbol> sym) {
	return pathToMyParent(sym.enclosing());
}

string pathToMyParent(ref<Scope> scope) {
	if (scope == scope.enclosingUnit()) {
		ref<Namespace> nm = scope.getNamespace();
		return storage.constructPath(outputFolder, nm.domain() + "_" + nm.dottedName(), null);
	}
	ref<Type> type = scope.enclosingClassType();
	if (type == null)
		return "type <null>";
	scope = type.scope();
	string path = pathToMyParent(scope.enclosing());
	if (scope.enclosing() == scope.enclosingUnit())
		path = storage.constructPath(path, "classes", null);
	return storage.constructPath(path, type.signature(), null);
}

int compareSymbols(ref<Symbol> sym1, ref<Symbol> sym2) {
	return sym1.name().compare(sym2.name());
}

int compareOverloadedSymbols(ref<OverloadInstance> sym1, ref<OverloadInstance> sym2) {
	return compareSymbols(ref<Symbol>(sym1), sym2);
}

string typeString(ref<Type> type, string baseName) {
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
		ref<var[]> args = ref<TemplateInstanceType>(type).arguments();
		return "pointer&lt;" + typeString(ref<Type>((*args)[0]), baseName) + "&gt;";

	case	REF:
		args = ref<TemplateInstanceType>(type).arguments();
		return "ref&lt;" + typeString(ref<Type>((*args)[0]), baseName) + "&gt;";


	case	FUNCTION:
		ref<FunctionType> ft = ref<FunctionType>(type);
		string f;

		pointer<ref<Type>> tp = ft.returnTypes();
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
		ref<TemplateType> template = ref<TemplateType>(type);
		string s = "<a href=\"" + url + "\">" + template.definingSymbol().name() + "</a>";
		s.append("&lt;");
		ref<ParameterScope> p = ref<ParameterScope>(template.scope());
		ref<ref<Symbol>[]> params = p.parameters();
		for (i in *params) {
			ref<Symbol> sym = (*params)[i];
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
		sym = ref<FlagsInstanceType>(type).symbol();
		name = sym.name();
		s.printf("<a href=\"%s\">%s</a>", url, name);
		return s;

	case	ENUM:
		classFile = classFiles[long(type.scope())];
		if (classFile == null)
			return null;
		url = storage.makeCompactPath(classFile, baseName);
		ref<Symbol> sym = ref<EnumInstanceType>(type).typeSymbol();
		string name = sym.name();
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
			// while a map of a non-integral type can be written as e[i].
			if (arena.validMapIndex(i, null))
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

