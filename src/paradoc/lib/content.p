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

import parasol:process;
import parasol:storage;

public ref<process.Option<string>> contentDirectoryOption;

enum ContentType {
	FILE,
	DIRECTORY,
	PH_FILE,
	INDEX_FILE,
	PARADOC
}

class Content extends Page {
	ContentType type;
	ref<Span>[] spans;
	ref<Span> open;
	ref<MacroSpan> topLevel;
	ref<MacroSpan>[] topics;
	ref<MacroSpan>[] links;
	ref<MacroSpan>[] docLinks;
	ref<MacroSpan>[] levels;

	Content(ContentType type, string path, string targetPath) {
		super(path, targetPath);
		this.type = type;
	}

	string toString() {
		switch (type) {
		case DIRECTORY:
			return "<" + string(type) + "> " + targetPath();
		}
		return "<" + string(type) + "> " + path() + " -> " + targetPath();
	}

	string sourceDirectory() {
		if (type == ContentType.DIRECTORY)
			return path();
		else
			return storage.directory(path());
	}

	string targetDirectory() {
		if (type == ContentType.DIRECTORY)
			return targetPath();
		else
			return storage.directory(targetPath());
	}

	string caption() {
		if (levels.length() > 0)
			return levels[0].sectionTitle;
		else
			return storage.filename(targetPath());
	}

	void setPageSequence() {
		if (type == ContentType.PARADOC) {
			for (i in pages) {
				p := pages[i];
				if (p.class != Content)
					p.setPageSequence();
			}
		} else
			super.setPageSequence();
	}

	boolean process() {
		if (verboseOption.set())
			printf("    Processing contents of %s -> %s %s\n", path(), targetPath(), string(type));
		add();
		boolean success = true;
		switch (type) {
		case DIRECTORY:
			if (!collectContentInventory(path(), targetPath()))
				success = false;
			break;

		case PH_FILE:
		case INDEX_FILE:
			if (!processPhFile())
				success = false;
		}
		return success;
	}

	boolean processPhFile() {
		ref<Reader> r = storage.openTextFile(path());
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

	boolean write() {
		if (verboseOption.set()) {
			string caption;
			static boolean firstTime = true;

			if (firstTime) {
				for (i in formattingOptions)
					printf("[%s] = '%s'\n", i, formattingOptions[i]);
				firstTime = false;
			}
			caption.printf("[%d]", index());
			printf("%7s %20s %s\n", caption, string(type), targetPath());
		}
		switch (type) {
		case DIRECTORY:
			if (storage.ensure(targetPath())) {
				if (verboseOption.set())
					printf("%s %s - created directory\n", targetPath(), string(type));
				return true;
			}
			break;

		case FILE:
			if (storage.copyFile(path(), targetPath())) {
				if (verboseOption.set())
					printf("%s %s - created file\n", targetPath(), string(type));
				return true;
			}
			break;

		case INDEX_FILE:
		case PH_FILE:
			if (writePhFile()) {
				if (verboseOption.set())
					printf("%s %s - created\n", targetPath(), string(type));
			}
		}
		return false;
	}

	boolean writePhFile() {
		for (i in docLinks) {
			dl := docLinks[i];
			dl.processDocLink(this);
		}
		ref<Writer> w = storage.createTextFile(targetPath());

		insertTemplate1(w, this);
//		w.printf("<title>%s</title>\n", corpusTitle);
		boolean success = true;
		for (i in spans) {
			if (spans[i].content != null)
				w.write(spans[i].content);
			else
				success = false;
		}
		insertTemplate2(w, this);
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
verbs["anchor"] = Verb.ANCHOR;
verbs["code"] = Verb.CODE;
verbs["doc-link"] = Verb.DOC_LINK;
verbs["end-grammar"] = Verb.END_GRAMMAR;
verbs["grammar"] = Verb.GRAMMAR;
verbs["level"] = Verb.LEVEL;
verbs["link"] = Verb.LINK;
verbs["option"] = Verb.OPTION;
verbs["paradoc"] = Verb.PARADOC;
verbs["production"] = Verb.PRODUCTION;
verbs["topic"] = Verb.TOPIC;

string[string] formattingOptions;

// default formatting options
formattingOptions["numbering"] = "I.A.1.a";

class MacroSpan extends Span {
	private Verb _verb;
	private ref<Content> _enclosing;
	private string[] _arguments;
	ref<MacroSpan> target;				// for TOPIC verbs, this is the first LEVEL verb under that topic.
	private byte _level;
	private int _index;
	string sectionNumber;				// for LEVEL verbs
	string sectionTitle;				// for LEVEL verbs

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
					printf("Expecting %d arguments with verb %s in %s\n", _verb.arguments(), verb, file.path());
					return false;
				}
				_arguments.append(arguments.substr(0, index));
				arguments = arguments.substr(index + 1);
				argumentCount--;
			}
			if (argumentCount > 0)
				_arguments.append(arguments);
			if (verboseOption.set()) {
				printf("        Processing verb %s(", string(_verb));
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
				codeOutputFolder = storage.path(file.targetDirectory(), _arguments[0]);
				if (verboseOption.set())
					printf("            Generated API Output %s\n", codeOutputFolder);
				file.topics.append(this);
				defineOutputDirectory(codeOutputFolder);
				collectNamespacesToDocument();
				content = "<a href=\"" + _arguments[0] + "/index.html\">" + _arguments[1] + "</a>";
				break;

			case TOPIC:
				string target = storage.path(file.sourceDirectory(), _arguments[0]);

				string targetPath = storage.path(contentOutputFolder, target);
				_index = file.topics.length();
				file.topics.append(this);
				break;

			case LEVEL:
				if (file.topLevel == null)
					file.topLevel = this;
				boolean success;
				(_level, success) = byte.parse(_arguments[0]);
				if (!success) {
					printf("Level %s is not valid in file %s\n", _arguments[0], file.path());
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
					printf("Anchor %s in %s duplicates an anchor in %s\n", _arguments[0], file.path(), 
									anchors[_arguments[0]].path());
					return false;
				}
				anchors[_arguments[0]] = file;
				content = "<a name=\"" + _arguments[0] + "\"></a>";
				break;

			case LINK:
				file.links.append(this);
				content = transformLink(null, 0, _arguments[0] + " " + _arguments[1], null, file.targetPath());
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
			printf("Unknown verb %s in %s: {@%s}\n", verb, file.path(), content);
			return false;
		}
		return true;
	}

	string linkText(ref<Content> base) {
		string href = storage.makeCompactPath(_enclosing.path(), base.path());
		if (href.endsWith(".ph"))
			href = href.substr(0, href.length() - 3) + ".html";
		if (this != _enclosing.levels[0] && sectionNumber != null)
			href += "#" + sectionNumber;
		return "<a href=\"" + href + "\">" + sectionTitle + "</a>";
	}

	void processDocLink(ref<Content> file) {
		c := anchors[_arguments[0]];
		string linkText;
		if (c == null) {
			printf("doc-link to unknown anchor in %s: {@%s}\n", file.path(), content);
			return;
		}
		linkText = storage.makeCompactPath(c.targetPath(), file.targetPath());
		content = "<a href=\"" + linkText + "\">" + _arguments[1] + "</a>";
	}
	/**
	 * Construct the final content string for a 'topic' macro. The target, if not null, is a level
	 * macro that satisfies the requirements of being the first level macro in the file named in the topic macro.
	 */
	void setTopicGroup() {
		if (verboseOption.set()) {
			printf("            %s setTopicGroup %s %s -> %s", string(_verb), _arguments[0], _enclosing.path(), _enclosing.targetPath());
			if (target != null)
				printf(" target %s", target._enclosing.toString());
			printf("\n");
		}
		if (_verb == Verb.PARADOC) {
			g := storage.path(_enclosing.targetDirectory(), _arguments[0]);
			idx := storage.path(g, "index.html");
			idx = storage.makeCompactPath(idx, _enclosing.targetPath());
			content = "<a href=\"" + idx + "\">" + _arguments[1] + "</a>";
		} else if (target != null) {
			content = target.levelGroup(_enclosing);
		} else {
			string href = _enclosing.path();
			href = href.substr(0, href.length() - 3) + ".html";
			content = "<a href=\"" + href + "\">" + href + "</a>";
		}
	}

	private string levelGroup(ref<Content> base) {
		string output = linkText(base);

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

	Verb verb() {
		return _verb;
	}

	void print() {
		printf("File %s %s(", _enclosing.path(), string(_verb));
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

ref<Content>[] topicHolders;
ref<Content>[string] anchors;

public boolean processContentDirectory() {
	string contentDirectory = contentDirectoryOption.value;
	if (!storage.exists(contentDirectory)) {
		printf("Content directory '%s' does not exist.\n", contentDirectory);
		return false;
	}
	if (!storage.isDirectory(contentDirectory)) {
		printf("Content directory '%s' is not a directory.\n", contentDirectory);
		return false;
	}
	ref<Content> c = new Content(ContentType.DIRECTORY, contentDirectory, contentOutputFolder);

	// Okay, start by collecting the files and sub-directories of the contentDirectory

	boolean success = c.process();

	if (verboseOption.set()) {
		if (anchors.size() > 0)
			printf("Defined anchors:\n");
		for (i in anchors)
			printf("    [%s] -> %s\n", i, anchors[i].targetPath());
		if (pages.length() > 0)
			printf("Pages:\n");
		for (i in pages) {
			p := pages[i];
			if (p.path() != null)
				printf("    [%d] %s -> %s\n", i, p.path(), p.targetPath());
			else
				printf("    [%d]     %s\n", i, p.targetPath());
		}
	}


	// Now, thread the topics and levels so that we know how to number them.

	if (pages.length() > 1) {		// There was a file in the content directory.
		for (i in pages) {
			p := pages[i];
			if (p.class != Content)
				continue;
			c := ref<Content>(p);
			if (c.type == ContentType.INDEX_FILE) {	// we have an index.ph, at least. Start lacing things up.
				thread(c);
				break;
			}			
		}
	}

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
				printf("Level %s is not an integer in file %s\n", l.argument(0), c.path());
				success = false;
			}
			if (level < 0 || level > numberingStyles.length()) {
				printf("level %d in file %s is out of range (0-%d)\n", level, c.path(), numberingStyles.length());
				success = false;
			} else if (level > 0) {
				if (levelCounts.length() < level)
					levelCounts.resize(level);
				levelCounts[level - 1] += 1;
				for (int i = level; i < levelCounts.length(); i++)
					levelCounts[i] = 0;
				string newContent;
				for (int i = 0; i < level; i++) {
					l.sectionNumber += numberingInterstitials[i];
					switch (numberingStyles[i]) {
					case '1':
						l.sectionNumber += string(levelCounts[i]);
						break;
					}
				}
				l.sectionNumber += numberingInterstitials[numberingInterstitials.length() - 1];
				l.sectionTitle = l.sectionNumber + " " + l.argument(1);
				l.content = "<a id=" + l.sectionNumber + "></a>" + l.sectionTitle;
			} else {
				l.content = l.argument(1);
				l.sectionTitle = l.content;
			}
			l.done();
		}
	}
	for (i in topicHolders) {
		ref<Content> c = topicHolders[i];
		for (j in c.topics)
			c.topics[j].setTopicGroup();
	}
	if (verboseOption.set())
		printf("Pages in Topic Order:\n");
	topicHolders[0].setPageSequence();

	return success;
}

boolean collectContentInventory(string sourcePath, string targetDirectory) {
	ref<Content>[] files;
	ref<Content> index;

	storage.Directory d(sourcePath);
	if (d.first()) {
		do {
			ref<Content> c;
			string filename = d.filename();

			switch (filename) {
			case ".":
			case "..":
				break;

			default:
				string path = d.path();
				if (storage.isDirectory(path))
					c = new Content(ContentType.DIRECTORY, path, 
									storage.path(targetDirectory, filename));
				else if (filename.endsWith(".ph")) {
					ContentType type;
					if (filename == "index.ph")
						type = ContentType.INDEX_FILE;
					else
						type = ContentType.PH_FILE;
					c = new Content(type, path, 
									storage.path(targetDirectory, filename, "html"));
				} else
					c = new Content(ContentType.FILE, path, 
									storage.path(targetDirectory, filename));
				
				if (c.type == ContentType.INDEX_FILE)
					index = c;
				else
					files.append(c);
			}
		} while (d.next());
	}
	boolean success = true;

	// This ordering assures that any index.ph file in a directory immediately follows the directory page.

	if (index != null && !index.process())
		success = false;

	// The order of the rest is unimportant.

	for (i in files)
		if (!files[i].process())
			success = false;
	return success;
}


void thread(ref<Content> file) {
	if (file.topics.length() > 0) {
		topicHolders.append(file);
		for (i in file.topics) {
			ref<MacroSpan> t = file.topics[i];

			if (t.verb() == Verb.PARADOC) {
				c := new Content(ContentType.PARADOC, null, codeOutputFolder);
				topicHolders.append(c);
				file.childPage(codeOverviewPage);
			} else {

				ref<Page> p = getTargetFile(file, t.argument(0));
				
				if (p != null && p.class == Content) {
					file.childPage(p);
					f := ref<Content>(p);
					if (f.levels.length() > 0)
						t.target = f.levels[0];
					thread(f); 
				}
			}
		}
	} else if (file.levels.length() > 0)
		topicHolders.append(file);
}
/**
 * @param source 
 */
ref<Page> getTargetFile(ref<Content> source, string reference) {
	string target;
	ref<Page> targetFile;

	target = storage.path(source.targetDirectory(), reference);
	if (target.endsWith(".ph"))
		target = target.substr(0, target.length() - 3) + ".html";
	target = storage.absolutePath(target);
	targetFile = pageMap[target];
	if (targetFile == null) {
		printf("Could not find target file (%s) for topic %s in file %s\n", target, reference, source.path());
		return null;
	}
	if (storage.isDirectory(targetFile.path())) {
		target = storage.path(targetFile.path(), "index.ph");
		targetFile = pageMap[target];
		if (targetFile == null) {
			printf("No index.ph for target directory %s in file %s\n", reference, source.path());
			return null;
		}
	}
	return targetFile;
}

