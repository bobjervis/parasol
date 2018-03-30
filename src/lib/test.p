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
namespace parasol:test;

import parasol:storage;
import parasol:script;
import parasol:script.Object;
import parasol:script.Vector;
import parasol:time;
import parasol:pxi;
import parasol:runtime;

private boolean listAllTests = false;

int launch(string[] args) {
	ref<ref<script.Atom>[]>[] scripts;
	string[] filenames;
	time.Time start = time.now();
	
	script.init();
	init();
	for (int i = 0; i < args.length(); i++) {
		filenames.append(args[i]);
		printf("    Parsing %s\n", args[i]);
		ref<ref<script.Atom>[]> atoms = parseOne(args[i]);
		if (atoms != null)
			scripts.append(atoms);
	}
	int result = 0;

	if (scripts.length() != args.length()) {
		printf("\n=============\nFailed to parse\n");
		result = 1;
	} else {
		int totalAtoms = 0;
		int totalRuns = 0;
		int failedRuns = 0;
		for (int i = 0; i < scripts.length(); i++) {
			printf("Running script %s\n", filenames[i].c_str());
			for (int j = 0; j < scripts[i].length(); j++) {
				ref<script.Atom> a = (*scripts[i])[j];
				totalAtoms++;
				if (a.class == Object) {
					printf("Atom not a test: %s\n-------------\n", a.toSource());
				} else if (a.isRunnable()) {
					totalRuns++;
					if (listAllTests) {
						string output;
						ref<script.Atom> n = a.get("name");

						if (n != null)
							output = "Script: " + n.toString();
						else
							output = "Atom: " + a.toSource();
						printf("%s\n-------------\n", output);
					}
					if (!a.run()) {
						failedRuns++;
						ref<script.Atom> o = a.get("output");
						if (o != null)
							printf("%s", o.toString());
						o = a.get("name");
						if (a.get("tag").toString() == "script" && o != null)
							printf("Failed script: %s\n=============\n", o.toString());
						else
							printf("Failed atom:\n%s\n=============\n", a.toSource());
					}
				} else 
					printf("Atom not runnable: '%s'\n-------------\n", a.toSource());
			}
		}
		if (totalRuns == 0) {
			printf("\n   *** No runnable atoms ***\n\n");
			for (int i = 0; i < scripts.length(); i++) {
				printf("Script %s:\n", filenames[i]);
				for (int j = 0; j < scripts[i].length(); j++) {
					ref<script.Atom> a = (*scripts[i])[j];
					printf("%s", a.toString());
				}
			}
			printf("\n");
			result = 1;
		} else if (failedRuns != 0) {
			printf("=============\n*** Failed %d/%d runs ***\n", failedRuns, totalRuns);
			result = 1;
		} else {
			printf("-------------\nPassed %d runs\nTotal atoms %d\n", totalRuns, totalAtoms);
			result = 0;
		}
	}
	time.Time end = time.now();
	long millis = end.value() - start.value();
	long seconds = millis / 1000;
	long minutes = seconds / 60;
	millis %= 1000;
	seconds %= 60;
	printf("\n       Elapsed time: %d:%d.%3.3d.\n", minutes, seconds, millis);
	for (int i = 0; i < scripts.length(); i++)
		scripts[i].deleteAll();
	scripts.deleteAll();
	return result;
}

private void init() {
/*
	script.objectFactory("pass", PassObject.factory);
	script.objectFactory("ensure", EnsureObject.factory);
	script.objectFactory("repeat", RepeatObject.factory);
	script.objectFactory("perf", PerfObject.factory);
*/
	script.objectFactory("conditional", ConditionalObject.factory);
}

private ref<ref<script.Atom>[]> parseOne(string arg) {
	ref<script.Parser> p = script.Parser.load(arg);
	if (p != null) {
		ref<ref<script.Atom>[]> atoms = new ref<script.Atom>[];
		p.content(atoms);
		if (!p.parse()) {
			atoms.deleteAll();
			delete atoms;
			atoms = null;
		}
		delete p;
		ref<ref<script.Atom>[]> results = new ref<script.Atom>[];
		flattenSet(results, atoms);
		return results;
	} else {
		ref<Reader> f = storage.openTextFile(arg);
		if (f != null) {
			printf("Parse of %s failed\n", arg);
			delete f;
		} else
			printf("Could not open %s\n", arg);
		assert(false);
		return null;
	}
}

private void flattenSet(ref<ref<script.Atom>[]> results, ref<ref<script.Atom>[]> source) {
	for (int i = 0; i < source.length(); i++) {
		ref<script.Atom> atom = (*source)[i];
		if (atom.class == ConditionalObject) {
			ref<ConditionalObject> conditional = ref<ConditionalObject>(atom);
			if (conditional.isEnabled()) {
				ref<script.Atom> content = conditional.get("content");
				if (content.class == Vector) {
					ref<script.Vector> v = ref<script.Vector>(content);
					flattenSet(results, v.value());
				}
			}
		} else
			results.append(atom);
	}
}

class ConditionalObject extends script.Object {
	private boolean _isEnabled;
	
	public static ref<script.Object> factory() {
		return new ConditionalObject();
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("target");
		if (a == null)
			return false;
		runtime.Target sectionType = pxi.sectionType(a.toString());
		if (sectionType == null) {
			printf("Unexpected section type name in 'target' attribute: '%s'\n", a.toString());
			return false;
		}
		int enabledTarget = int(sectionType);
		_isEnabled = enabledTarget == runtime.runningTarget();
		return true;
	}
	
	public boolean isEnabled() {
		return _isEnabled;
	} 
}
