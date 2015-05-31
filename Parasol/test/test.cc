/*
   Copyright 2015 Rovert Jervis

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
#include "../common/platform.h"
#include "test.h"

#include <stdlib.h>
#include "../common/atom.h"
#include "../common/file_system.h"
#include "../common/machine.h"
#include "../common/parser.h"
#include "../common/script.h"
#include "../common/timing.h"

namespace test {

bool listAllTests = false;

static void init();
static vector<script::Atom*>* parseOne(const char* arg);

int launch(int argc, char** argv) {
	vector<vector<script::Atom*>*> scripts;
	vector<string> filenames;
	script::init();
	init();
	for (int i = 0; i < argc; i++) {
		filenames.push_back(argv[i]);
		vector<script::Atom*>* atoms = parseOne(argv[i]);
		if (atoms)
			scripts.push_back(atoms);
	}
	int result = 0;
	if (scripts.size() != argc) {
		printf("\n=============\nFailed to parse\n");
		result = 1;
	} else {
		int totalAtoms = 0;
		int totalRuns = 0;
		int failedRuns = 0;
		for (int i = 0; i < scripts.size(); i++) {
			printf("Running script %s\n", filenames[i].c_str());
			for (int j = 0; j < scripts[i]->size(); j++) {
				script::Atom* a = (*scripts[i])[j];
				totalAtoms++;
				if (a->isRunnable()) {
					totalRuns++;
					if (listAllTests) {
						string output;
						script::Atom *n = a->get("name");

						if (n != null)
							output = "Script: " + n->toString();
						else
							output = "Atom: " + a->toSource();
						printf("%s\n-------------\n", output.c_str());
					}
					if (!a->run()) {
						failedRuns++;
						script::Atom* o = a->get("output");
						if (o != null)
							printf("%s", o->toString().c_str());
						o = a->get("name");
						if (a->get("tag")->toString() == "script" && o != null)
							printf("Failed script: %s\n=============\n", o->toString().c_str());
						else
							printf("Failed atom:\n%s\n=============\n", a->toSource().c_str());
					}
				}
			}
		}
		if (totalRuns == 0) {
			printf("\n   *** No runnable atoms ***\n\n");
			for (int i = 0; i < scripts.size(); i++) {
				printf("Script %s:\n", filenames[i].c_str());
				for (int j = 0; j < scripts[i]->size(); j++) {
					script::Atom* a = (*scripts[i])[j];
					printf("%s", a->toString().c_str());
				}
			}
			putchar('\n');
			result = 1;
		} else if (failedRuns != 0) {
			printf("=============\n*** Failed %d/%d runs ***\n", failedRuns, totalRuns);
			result = 1;
		} else {
			printf("-------------\nPassed %d runs\nTotal atoms %d\n", totalRuns, totalAtoms);
			result = 0;
		}
	}
	for (int i = 0; i < scripts.size(); i++)
		scripts[i]->deleteAll();
	scripts.deleteAll();
	return result;
}

void run() {
}

class PerfObject : script::Object {
public:
	static script::Object* factory() {
		return new PerfObject();
	}

	PerfObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		int repeatCount = 1;
		Atom* repeat = get("repeat");
		if (repeat != null)
			repeatCount = repeat->toString().toInt();
		vector<timing::Interval> snapshot;
		timing::defineSnapshot(&snapshot);
		timing::enableProfiling();
		bool result = runAnyContent();
		timing::disableProfiling();
		timing::print(snapshot);
		return result;
	}

};

class PassObject : script::Object {
public:
	static script::Object* factory() {
		return new PassObject();
	}

	PassObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		return true;
	}

};

class EnsureObject : script::Object {
public:
	static script::Object* factory() {
		return new EnsureObject();
	}

	EnsureObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool validate(script::Parser* parser) {
		Atom* dir = get("dir");
		if (dir == null) {
			printf("Missing dir:\n");
			return false;
		}
		_path = fileSystem::pathRelativeTo(dir->toString(), parser->filename());
		return true;
	}

	virtual bool run() {
		return fileSystem::ensure(_path);
	}

private:
	string	_path;
};

script::Object* RepeatObject::factory() {
	return new RepeatObject();
}

bool RepeatObject::isRunnable() const {
	return true;
}

bool RepeatObject::validate(script::Parser* parser) {
	Atom* a = get("count");
	if (a == null) {
		printf("No count attribute\n");
		return false;
	}
	_count = a->toString().toInt();
	return true;
}

bool RepeatObject::run() {
	for (int i = 0; i < _count; i++)
		if (!runAnyContent())
			return false;
	return true;
}

static void init() {
	script::objectFactory("pass", PassObject::factory);
	script::objectFactory("ensure", EnsureObject::factory);
	script::objectFactory("repeat", RepeatObject::factory);
	script::objectFactory("perf", PerfObject::factory);
}

static vector<script::Atom*>* parseOne(const char* arg) {
	script::Parser* p = script::Parser::load(arg);
	if (p != null) {
		vector<script::Atom*>* atoms = new vector<script::Atom*>;
		p->content(atoms);
		if (!p->parse()) {
			atoms->deleteAll();
			delete atoms;
			atoms = null;
		}
		delete p;
		return atoms;
	} else
		return null;
}

}  // namespace test
