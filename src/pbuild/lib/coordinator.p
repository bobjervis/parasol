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

import parasol:context;
import parasol:exception;
import parasol:process;
import parasol:runtime;
import parasol:script;
import parasol:storage;
import parasol:text.memDump;
import parasol:thread;
import parasol:types.Set;

string MAKE_FILE = "make.pbld";

string PARASOL_INSTALL_PACKAGE_NAME = "install:parasollanguage.org";

ref<Package> corePackage;					// If this maker is building the parasol runtime, be sure to use it
											// in other builds as well.
ref<Package> installPackage;				// If this maker is building the parasol compiler, be sure to use it
											// in other builds as well.

private monitor class CoordinatorVolatileData {
	boolean _overallSuccess;
}

public class Coordinator extends CoordinatorVolatileData {
	private string _buildDir;
	private string _buildFile;
	private int _buildThreads;
	private string _outputDir;
	private string _targetOS;
	private string _targetCPU;
	private Set<string> _suites;
	private Set<string> _definedSuites;
	private string _uiPrefix;
	private boolean _generateSymbolTables;
	private boolean _generateDisassembly;
	private boolean _reportOutOfDate;
	private boolean _verbose;
	private boolean _trace;
	private boolean _logImports;
	private ref<thread.Thread>[] _threads;
	private ref<Package>[string] _packageMap;		// maps package name to Package, all the packages discovered that will be built
	private ref<context.PseudoContext> _pseudoContext;
	private ref<Product>[] _products;
	private ref<Test>[] _tests;
	private string[] _onPassScripts;
	private string[] _onPassDirs;
	private static Monitor _lock;
	private static ref<thread.ThreadPool<boolean>> _workers;
	private Set<string> _uniqueTests;

	public Coordinator(string buildDir, 
					   string buildFile, 
					   int buildThreads, 
					   string outputDir, 
					   string targetOS, string targetCPU,
					   string uiPrefix,
					   string suites,
					   boolean generateSymbolTables,
					   boolean generateDisassembly,
					   boolean reportOutOfDate,
					   boolean verbose,
					   boolean trace,
					   boolean logImports) {
		lock(_lock) {
			if (_workers == null)
				_workers = new thread.ThreadPool<boolean>(buildThreads);
		}
		if (buildDir == null)
			_buildDir = ".";
		else
			_buildDir = buildDir;
		if (buildFile == null) {
			_buildFile = storage.constructPath(_buildDir, MAKE_FILE);
			if (!storage.exists(_buildFile))
				_buildFile = null;
		} else
			_buildFile = buildFile;
		if (buildThreads == 0)
			_buildThreads = thread.cpuCount();
		else
			_buildThreads = buildThreads;
		if (outputDir == null && _buildFile != null)
			_outputDir = storage.constructPath(_buildDir, "build");
		else
			_outputDir = outputDir;
		if (targetOS == null)
			_targetOS = thisOS();
		else
			_targetOS = targetOS;
		if (targetCPU == null)
			_targetCPU = thisCPU();
		else
			_targetCPU = targetCPU;
		_uiPrefix = uiPrefix;
		if (suites != null) {
			string[] suiteNames = suites.split(',');
			for (i in suiteNames)
				_suites.add(suiteNames[i]);
		}
		// Make sure the prefix test ends with a / - so that we don't accidentally match partial filenames.
		if (_uiPrefix != null && !_uiPrefix.endsWith("/"))
			_uiPrefix.append('/');
		_generateSymbolTables = generateSymbolTables;
		_generateDisassembly = generateDisassembly;
		_reportOutOfDate = reportOutOfDate;
		_verbose = verbose;
		_trace = trace;
		_logImports = logImports;
		_pseudoContext = new context.PseudoContext(context.getActiveContext());
	}

	~Coordinator() {
		_tests.deleteAll();
	}

	public boolean validate() {
		switch (_targetOS) {
		case "linux":
		case "windows":
			break;

		default:
			printf("Unknown target OS '%s'\n", _targetOS);
			return false;
		}
		switch (_targetCPU) {
		case "x86-64":
			break;

		default:
			printf("Unknown target CPU '%s'\n", _targetCPU);
			return false;
		}

		if (_buildFile != null) {
			if (!parseBuildFile(_buildFile, _buildDir, _outputDir))
				return false;
		} else if (!recurseThrough(_buildDir))
			return false;	

		if (_suites.size() != _definedSuites.size()) {
			for (Set<string>.iterator i = _suites.begin(); i.hasNext(); i.next()) {
				if (!_definedSuites.contains(i.key()))
					printf("    FAIL: Undefined test suite in command-line %s\n", i.key());
			}
			return false;
		}

		if (_products.length() == 0)
			printf("No build files found - nothing to do.\n");

		if (_verbose) {
			for (i in _products)
				_products[i].print(0);
			for (i in _tests)
				printf("  TEST %s\n", _tests[i].toString());
			for (i in _onPassScripts)
				printf("  PASS SCRIPT @ %s\n", _onPassDirs[i]);
		}

		return true;
	}

	private boolean recurseThrough(string dir) {
		ref<storage.Directory> d = new storage.Directory(dir);
		boolean success = true;
		string[] dirs;
		if (d.first()) {
			do {
				string filepath = d.path();
				string filename = d.filename();
				if (filename == MAKE_FILE) {
					string outputDir = storage.constructPath(dir, "build");
					if (!parseBuildFile(filepath, dir, outputDir))
						success = false;
					delete d;
					return success;
				}
				if (filename.startsWith("."))
					continue;
				if (storage.isDirectory(filepath))
					dirs.append(filepath);
			} while (d.next());
		} else {
			printf("    FAIL: Could not match any files with %s/*\n", dir);
			success = false;
		}
		delete d;
		for (i in dirs)
			if (!recurseThrough(dirs[i]))
				success = false;
		return success;
	}

	private boolean parseBuildFile(string buildFile, string buildDir, string outputDir) {
		ref<BuildFile> bf = BuildFile.parse(buildFile, null, errorMessage, _targetOS, _targetCPU);

		if (bf == null)
			return false;


		string absBuildDir = storage.absolutePath(buildDir);

		for (i in bf.products)
			if (!bf.products[i].defineContext(this, absBuildDir, outputDir)) {
				delete bf;
				return false;
			}

		for (i in bf.tests) {
			ref<Suite> t = bf.tests[i];
			if (!t.composeTestList(&bf.tests, buildFile, absBuildDir, _trace)) {
				delete bf;
				return false;
			}
			if (runSuite(t.suite())) {
				_definedSuites.add(t.suite());
				ref<Test>[] tests = t.tests();
				for (j in tests)
					addTest(tests[j]);
				string onPassScript = t.onPassScript();
				if (onPassScript != null)
					addOnPassScript(buildDir, onPassScript);
			}
		}

		for (i in bf.products)
			_products.append(bf.products[i]);

		bf.products.clear();
		bf.tests.clear();

		delete bf;

		return true;
	}

	public void addTest(ref<Test> t) {
		string key = t.toString();
		if (!_uniqueTests.contains(key)) {
			_tests.append(t);
			_uniqueTests.add(key);
		}
	}

	public void addOnPassScript(string testDir, string script) {
		_onPassScripts.append(script);
		_onPassDirs.append(testDir);
	}

	public int run() {
		lock(*this) {
			_overallSuccess = true;
		}
		for (i in _products) {
			ref<Product> product = _products[i];
			if (product.class == Package) {
				ref<Package> p = ref<Package>(product);
				if (p.name() == context.PARASOL_CORE_PACKAGE_NAME)
					corePackage = p;
				else if (p.name() == PARASOL_INSTALL_PACKAGE_NAME)
					installPackage = p;
				ref<context.Package> ctxPkg = p.ctxPackage();
				if (!_pseudoContext.definePackage(ctxPkg)) {
					printf("    FAIL: Package %s is duplicated in this build.\n", p.name());
					delete ctxPkg;

				}
			}
		}
		if (corePackage != null)
			printf("    Building %s\n", context.PARASOL_CORE_PACKAGE_NAME);
		if (installPackage != null)
			printf("    Building %s\n", PARASOL_INSTALL_PACKAGE_NAME);

		for (i in _products) {
			ref<thread.Thread> t = new thread.Thread();
			_threads.append(t);
			t.start(productBuilder, _products[i]);
		}
		for (i in _threads)
			_threads[i].join();
//		printf("Threads joined\n");
		_threads.deleteAll();
		boolean success;
		lock (*this) {
			success = _overallSuccess;
		}
		if (success) {
			string filename;
			if (_tests.length() > 0) {
				printf(" -- Begin test execution --\n");
				ref<storage.FileWriter> tempContext;

				(filename, tempContext) = storage.createTempFile("tcf_XXXXXX");
				ref<context.TemporaryContext> tc = new context.TemporaryContext(null);
				for (i in _products) {
					ref<Product> p = _products[i];
					if (p.class != Package)
						continue;
					ref<Package> pkg = ref<Package>(p);
					if (pkg.generateManifest())
						tc.definePackage(ref<Package>(p).ctxPackage());
				}
				success = tc.writeContextData(tempContext);
				delete tempContext;
				delete tc;
				if (!success) {
					printf("    FAIL: Could not create temporary context for tests\n");
					return 1;
				}
			}
			process.environment.set("PARASOL_CONTEXT_FILE", filename);
			for (i in _tests) {
				if (!_tests[i].run())
					success = false;
			}
			if (success) {
				for (i in _onPassScripts) {
					ref<process.Process> p = new process.Process();
					if (!p.execute(_onPassDirs[i], "/bin/bash", process.useParentEnvironment, "-cev", _onPassScripts[i])) {
						printf("    FAIL: on_pass script failed\n");
						success = false;
					}
					delete p;
				}
			}
			if (success)
				printf("SUCCESS!\n");
		} else {
			printf("  Outcome    Product\n");
			for (i in _products)
				printf("    %s   %s\n", _products[i].outcome(), _products[i].name());
			printf("FAIL: Build contained failures.\n");
		}
		return success ? 0 : 1;
	}

	private static void productBuilder(address arg) {
		ref<Product> product = ref<Product>(arg);
//		printf("    %d Starting build of %s\n", thread.currentThread().id(), product.toString());
		boolean success;
		try {
			success = product.build();
		} catch (Exception e) {
			exception.uncaughtException(&e);
			printf("\n");			
		}
		if (!success) {
			product.coordinator().declareFailure();
			printf("    FAIL: product %s build failed\n", product.toString());
		}
//		printf("    Build %s success? %s\n", product.toString(), string(success));
		product.future().post(success);
	}

	public void declareFailure() {
		lock(*this) {
			_overallSuccess = false;
		}
	}

	public string outputDir() {
		return _outputDir;
	}

	public ref<context.Context> activeContext() {
		return _pseudoContext;
	}

	public ref<thread.ThreadPool<boolean>> workers() {
		return _workers;
	}

	public string targetOS() {
		return _targetOS;
	}

	public string targetCPU() {
		return _targetCPU;
	}

	public boolean runSuite(string suiteName) {
		return _suites.contains(suiteName);
	}

	public string uiPrefix() {
		return _uiPrefix;
	}

	public boolean reportOutOfDate() {
		return _reportOutOfDate;
	}

	public boolean verbose() {
		return _verbose;
	}

	public boolean trace() {
		return _trace;
	}

	public boolean logImports() {
		return _logImports;
	}

	public boolean generateSymbolTables() {
		return _generateSymbolTables;
	}

	public boolean generateDisassembly() {
		return _generateDisassembly;
	}
}

void errorMessage(string filename, string format, var... args) {
	printf("    FAIL: %s ", filename);
	printf(format, args);
	printf("\n");
}

public string thisOS() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return "windows";
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return "linux";
	}
	return "<unknown>";
}

public string thisCPU() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN ||
		runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return "x86-64";
	}
	return "<unknown>";
}

