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

import parasol:storage;
import parasol:stream;

ref<Page>[] pages;
ref<Page>[string] pageMap;
ref<Page>[] pageSequence;

class Page {
	private int _index;
	private string _path;
	private string _targetPath;
	private ref<Page> _parent;
	private ref<Page>[] _children;
	private boolean _isTopic;
	private int _topicOrderIndex;

	Page(string path, string targetPath) {
		_path = path;
		_targetPath = targetPath;
	}

	void add() {
		_index = pages.length();
		pages.append(this);
		pageMap[_targetPath] = this;
		if (verboseOption.set()) {
			if (_path != null)
				printf("      Added page [%d] %s -> %s\n", _index, _path, _targetPath);
			else
				printf("      Added page [%d] %s\n", _index, toString());
		}
	}
	
	void childPage(ref<Page> child) {
		child._parent = this;
		_children.append(child);
	}

	void insertNavBar(ref<Writer> writer) {
	}

	void setPageSequence() {
		_topicOrderIndex = pageSequence.length();
		_isTopic = true;
		if (verboseOption.set())
			printf("    [%d] %s\n", _topicOrderIndex, _targetPath);
		pageSequence.append(this);
		for (i in _children)
			_children[i].setPageSequence();
	}

	string path() {
		return _path;
	}

	string targetPath() {
		return _targetPath;
	}

	int index() {
		return _index;
	}

	boolean hasPrevious() {
		return _topicOrderIndex > 0;
	}

	boolean hasNext() {
		return _isTopic && _topicOrderIndex < pageSequence.length() - 1;
	}

	boolean hasUp() {
		return _parent != null;
	}

	string caption() {
		return null;
	}

	ref<Page> previous() {
		if (_topicOrderIndex > 0)
			return pageSequence[_topicOrderIndex - 1];
		else
			return null;
	}

	ref<Page> up() {
		return _parent;
	}

	ref<Page> next() {
		if (_isTopic && _topicOrderIndex < pageSequence.length() - 1)
			return pageSequence[_topicOrderIndex + 1];
		else
			return null;
	}

	abstract boolean write();

	abstract string toString();
}

void defineOutputDirectory(string path) {
	(new Content(ContentType.DIRECTORY, null, path)).add();
}

public boolean generatePages() {
	if (validateOnlyOption.set())
		return true;
	boolean success = true;
	for (i in pages)
		if (!pages[i].write())
			success = false;
	return success;
}

public void insertTemplate1(ref<Writer> output, ref<Page> page) {
	ref<Reader> template1 = storage.openTextFile(template1file);

	if (template1 != null)
		insertTemplate(template1, output, page);
	else
		printf("Could not read template1.html file from %s\n", template1file);
}

public void insertTemplate2(ref<Writer> output, ref<Page> page) {
	ref<Reader> template2 = storage.openTextFile(template2file);

	if (template2 != null)
		insertTemplate(template2, output, page);
	else
		printf("Could not read template2.html file from %s\n", template2file);
}

private void insertTemplate(ref<Reader> reader, ref<Writer> writer, ref<Page> page) {
	for (;;) {
		int c;

		c = reader.read();
		if (c == stream.EOF)
			break;
		switch (c) {
		case '$':
			string path = storage.makeCompactPath(stylesheetPath, page.targetPath());
			writer.write(path);
			break;

		case '@':
			if (homeCaptionOption.set()) {
				homeUrl := storage.makeCompactPath(contentOutputFolder, page.targetPath());
				homeCaption := homeCaptionOption.value;
				writer.printf("<div class=nav-home><a href=\"%s\">Go to %s</a></div>", homeUrl, homeCaption);
			}
			if (page.hasPrevious()) {
				prevUrl := storage.makeCompactPath(page.previous().targetPath(), page.targetPath());
				prevCaption := page.previous().caption();
				writer.printf("<div class=nav-prev><a href=\"%s\">Previous Page %s</a></div>", prevUrl, prevCaption);
			}
			if (page.hasUp()) {
				upUrl := storage.makeCompactPath(page.up().targetPath(), page.targetPath());
				upCaption := page.up().caption();
				writer.printf("<div class=nav-up><a href=\"%s\">Enclosing Topic %s</a></div>", upUrl, upCaption);
			}
			if (page.hasNext()) {
				nextUrl := storage.makeCompactPath(page.next().targetPath(), page.targetPath());
				nextCaption := page.next().caption();
				writer.printf("<div class=nav-next><a href=\"%s\">Next Page %s</a></div>", nextUrl, nextCaption);
			}
			break;

		case '^':
			if (page.caption() != null)
				writer.printf("<title>%s</title>", page.caption());
			break;

		default:
			writer.write(byte(c));
		}
	}
	delete reader;
}




