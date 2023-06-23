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
namespace parasol:pbuild;

import parasol:process;
import parasol:script;
import parasol:storage;

public class Suite {
	private string _suite;
	private string _testDir;
	private string[] _includes;			// The names of the other suites to include
	private ref<Suite>[] _included;		// The included suites
	private ref<Test>[] _myTests;		// The tests declared in this suite
	private string _onPassScript;
	private string _afterPassScript;
	private boolean _composing;
	private boolean _composed;
	private boolean _trace;
	private ref<Test>[] _tests;			// The tests declared here and in all included suites rec

	Suite(ref<BuildFile> buildFile, ref<script.Object> object) {
		ref<script.Atom> a = object.get("suite");
		if (a != null)
			_suite = a.toString();
		else
			buildFile.error(object, "'suite' attribute missing'");
		a = object.get("content");
		if (a != null) {
			if (a.class != script.Vector)
				addComponent(buildFile, a);
			else {
				ref<script.Vector> v = ref<script.Vector>(a);
				for (int i = 0; i < v.length(); i++)
					addComponent(buildFile, v.get(i));
			}
		}
	}

	~Suite() {
		_myTests.deleteAll();
	}

	public boolean validate(ref<script.Parser> parser) {
		return _suite !=  null;
	}

	private void addComponent(ref<BuildFile> buildFile, ref<script.Atom> a) {
		if (a.class != script.Object) {
			if (a.class != script.TextRun)
				buildFile.error(a, "Not a valid component for a test suite definition");
			return;
		}
		ref<script.Object> def = ref<script.Object>(a);
		switch (def.get("tag").toString()) {
		case "include":
			ref<script.Atom> a = def.get("suite");
			if (a != null)
				_includes.append(a.toString());
			else
				buildFile.error(def, "An include tag must have a 'suite' attribute");
			break;

		case "ets":
			_myTests.append(new EtsTest(def, this));
			break;
				
		case "on_pass":
			if (_onPassScript != null) {
				buildFile.error(def, "More than one on_pass script in suite '%s'", _suite);
				return;
			}
			a = def.get("content");
			if (a != null)
				_onPassScript = a.toString();
			break;

		case "after_pass":
			if (_afterPassScript != null) {
				buildFile.error(def, "More than one after_pass script in suite '%s'", _suite);
				return;
			}
			a = def.get("content");
			if (a != null)
				_afterPassScript = a.toString();
			break;
			
		default:
			buildFile.error(def, "Unexpected tag '%s'\n", def.get("tag").toString());
		}
	}
	/**
	 * @param suites The full set of defined test suites for this build file.
	 */
	public boolean composeTestList(ref<ref<Suite>[]> suites, string buildFile, string testDir, boolean trace) {
		_testDir = testDir;
		_trace = trace;
		return composeTestList(suites,buildFile);
	}

	private boolean composeTestList(ref<ref<Suite>[]> suites, string buildFile) {
		if (_composed)
			return true;
		if (_composing) {
			printf("        FAIL: infinite include loop of suite %s in file %s\n", _suite, buildFile);
			return false;
		}
		_composing = true;
		for (i in _includes) {
			string suite = _includes[i];
			boolean found;
			for (j in *suites) {
				if ((*suites)[j].suite() == suite) {
					if (!(*suites)[j].composeTestList(suites, buildFile)) {
						_composing = false;
						_composed = true;
						return false;
					}
					_included.append((*suites)[j]);
					found = true;
					break;
				}
			}
			if (!found) {
				printf("        FAIL: could not find included suite '%s' in suite %s in file %s\n", suite, _suite, buildFile);
				_composing = false;
				_composed = true;
				return false;
			}
		}

		harvestTests(this, buildFile);

		for (i in _included) {
			if (_included[i]._onPassScript != null) {
				if (_onPassScript != null)
					_onPassScript = _included[i]._onPassScript + "\n" + _onPassScript;
				else
					_onPassScript = _included[i]._onPassScript;
			}
			if (_included[i]._afterPassScript != null) {
				if (_afterPassScript != null)
					_afterPassScript = _included[i]._afterPassScript + "\n" + _afterPassScript;
				else
					_afterPassScript = _included[i]._afterPassScript;
			}
		}

		_composing = false;
		_composed = true;
		return true;
	}

	void harvestTests(ref<Suite> aggregator, string buildFile) {
		for (i in _myTests)
			aggregator._tests.append(_myTests[i]);
		for (i in _included) {
			if (_included[i]._composing) {
				printf("        FAIL: infinite include loop of suite %s in file %s\n", _suite, buildFile);
				return;
			}
			_included[i].harvestTests(aggregator, buildFile);
		}
	}

	public string suite() {
		return _suite;
	}

	public string onPassScript() {
		return _onPassScript;
	}

	public string afterPassScript() {
		return _afterPassScript;
	}

	public ref<Test>[] tests() {
		return _tests;
	}

	public string testDir() {
		return _testDir;
	}

	public boolean trace() {
		return _trace;
	}

	public void print(int indent) {
		printf("Suite %s\n", _suite);
		for (i in _includes) {
			printf("%5s include %s\n", _included.length() <= i ? "x" : " ", _includes[i]);
		}
		if (_tests.length() == 0)
			for (i in _myTests)
				printf("      %s\n", _myTests[i].toString());
		for (i in _tests)
			printf("%5s %s\n", _tests[i].suite() == this ? " " : "i", _tests[i].toString());
	}
}

public class EtsTest extends Test {
	private string _filename;

	public EtsTest(ref<script.Object> ets, ref<Suite> suite) {
		super(suite);
		ref<script.Atom> a = ets.get("name");
		if (a != null)
			_filename = a.toString();
	}

	public boolean validate() {
		return _filename != null;
	}

	public boolean run() {
		ref<process.Process> p = new process.Process();
		string workingDirectory = suite().testDir();
		string binaryDirectory;
		string pcCommand;
		if (installPackage != null)
			binaryDirectory = storage.constructPath(installPackage.path(), "bin");
		else
			binaryDirectory = storage.directory(process.binaryFilename());
		pcCommand = storage.constructPath(binaryDirectory, "pc");
		string[] args;
		args.append("test/drivers/etsTests.p");
		if (installPackage != null)
			args.append("--compileFromSource");
		if (suite().trace())
			args.append("--trace");
		args.append("--root=.");
		args.append(_filename);
		printf("    working dir %s\n    %s ", workingDirectory, pcCommand);
		for (i in args)
			printf("'%s' ", args[i]);
		printf("\n");
		boolean success;
		int exitStatus;

		(success, exitStatus) = p.execute(workingDirectory, pcCommand, process.useParentEnvironment, args);
		if (success) {
			delete p;
			return true;
		} else {
			printf("exit status %d\n", exitStatus);
			delete p;
			printf("    FAIL: Test %s contained failures.\n", _filename);
			return false;
		}
	}

	public string toString() {
		string s;
		s.printf("ets %s", _filename);
		return s;
	}
}

public class Test {
	private ref<Suite> _suite;

	protected Test(ref<Suite> suite) {
		_suite = suite;
	}

	public boolean run() {
		printf("Test.run\n");
		return false;
	}
		
	public abstract string toString();

	public ref<Suite> suite() {
		return _suite;
	}
}

public class IncludeObject extends script.Object {
	private string _suite;

	public static ref<script.Object> factory() {
		return new IncludeObject();
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("suite");
		if (a == null)
			return false;
		_suite = a.toString();
		a = get("content");
		if (a != null)
			return false;
		return true;
	}

	public string suite() {
		return _suite;
	}
}

public class Ets extends script.Object {
	private string _name;
	private string _importArgument;
	private string[] _packages;


	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("name");
		if (a == null)
			return false;
		_name = a.toString();
		a = get("import");
		if (a != null)
			_importArgument = a.toString();
		a = get("content");
		if (a == null)
			return true;
		boolean success = true;
		if (a.class != script.Vector) {
			if (!addComponent(a))
				success = false;
		} else {
			ref<script.Vector> v = ref<script.Vector>(a);
			for (int i = 0; i < v.length(); i++) {
				a = v.get(i);
				if (!addComponent(a))
					success = false;
			}
		}
		return success;
	}

	private boolean addComponent(ref<script.Atom> a) {
		printf("        FAIL: Unexpected entity: %s\n", a.toString());
		return false;
	}

	public boolean usePackage(string package) {
		if (package == null)
			return false;
		_packages.append(package);
		return true;
	}

	public string name() {
		return _name;
	}
/*
	public string importPath() {
		string path;

		for (i in _importDirs) {
			if (path.length() > 0)
				path += ",";
			path += _importDirs[i];
		}
		if (_importArgument != null) {
			if (path.length()  > 0)
				path += ",";
			path += _importArgument;
		}
		return path;
	}
 */
}

public class OnPassObject extends script.Object {
	private string _onPassScript;

	public static ref<script.Object> factory() {
		return new OnPassObject();
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("content");
		if (a == null)
			return false;
		_onPassScript = a.toString();
		return true;
	}

	public string onPassScript() {
		return _onPassScript;
	}
}

