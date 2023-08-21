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

ref<Page>[] pages;
ref<Page>[string] pageMap;

class Page {
	private int _index;
	private string _path;
	private string _targetPath;
	private ref<Page> _parent;

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
	
	void insertNavBar(ref<Writer> writer) {
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


