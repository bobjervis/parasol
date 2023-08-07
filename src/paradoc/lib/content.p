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
			if (verboseOption.set()) {
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
				outputFolder = storage.path(file.targetDirectory(), _arguments[0]);
				printf("paradoc output folder is '%s'\n", outputFolder);
				content = "<a href=\"" + _arguments[0] + "/index.html\">" + _arguments[1] + "</a>";
				break;

			case TOPIC:
				string target = storage.path(file.sourceDirectory(), _arguments[0]);
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

ref<Content>[] content;
ref<Content>[string] fileMap;
ref<Content>[] topicHolders;
ref<Content>[string] anchors;

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
					c.targetPath = storage.path(outputFolder, c.path.substr(baseDirectory.length() + 1), null);
				} else if (c.path.endsWith(".ph")) {
					c.type = ContentType.PH_FILE;
					c.targetPath = storage.path(outputFolder, 
												c.path.substr(baseDirectory.length() + 1, c.path.length() - 2) + "html");
				} else {
					c.type = ContentType.FILE;
					c.targetPath = storage.path(outputFolder, c.path.substr(baseDirectory.length() + 1), null);
				}
				content.append(c);
				if (verboseOption.set())
					printf("%s %s %s\n", c.path, c.targetPath, string(c.type));
				if (c.type == ContentType.DIRECTORY)
					collectContentInventory(baseDirectory, c.path);
			}
		} while (d.next());
	}
	delete d;
}

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
	Content c;
	c.type = ContentType.DIRECTORY;
	c.path = contentDirectory;
	content.append(&c);
	collectContentInventory(contentDirectory, contentDirectory);

	// Okay, start parsing the .ph files

	boolean success = true;
	for (i in content) {
		ref<Content> c = content[i];

		fileMap[c.path] = c;
		if (c.type == ContentType.PH_FILE) {
			if (!c.processPhFile())
				success = false;
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

	return success;
}

public boolean writeContentDirectory() {
	if (validateOnlyOption.set())
		return true;

	// We've parsed in all the .ph files. Now we have to process the macros.

	if (verboseOption.set()) {
		for (i in content) {
			ref<Content> c = content[i];
			string caption;
	
			caption.printf("[%d]", i);
			printf("%7s %20s %s\n", caption, string(c.type), c.path);
		}
		for (i in formattingOptions)
			printf("[%s] = '%s'\n", i, formattingOptions[i]);
	}

	boolean success = true;
	for (i in content) {
		ref<Content> c = content[i];

		switch (c.type) {
		case DIRECTORY:
			if (storage.ensure(c.targetPath))
				printf("%s %s - created directory\n", c.targetPath, string(c.type));
			else
				success = false;
			break;

		case FILE:
			if (storage.copyFile(c.path, c.targetPath))
				printf("%s %s - created file\n", c.targetPath, string(c.type));
			else
				success = false;
			break;

		case PH_FILE:
			if (c.writePhFile())
				printf("%s %s - created\n", c.targetPath, string(c.type));
			else
				success = false;
		}
	}
	return success;
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
/**
 * @param source 
 */
ref<Content> getTargetFile(ref<Content> source, string reference) {
	string target;
	ref<Content> targetFile;

	if (source != null) {
		target = storage.path(source.sourceDirectory(), reference);
		targetFile = fileMap[target];
		if (targetFile == null) {
			printf("Could not find target file for topic %s in file %s\n", reference, source.path);
			return null;
		}
	} else
		targetFile = content[0];
	if (targetFile.type == ContentType.DIRECTORY) {
		target = storage.path(targetFile.path, "index.ph", null);
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

