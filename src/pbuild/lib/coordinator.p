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

import parasol:compiler;
import parasol:context;
import parasol:exception;
import parasol:process;
import parasol:runtime;
import parasol:script;
import parasol:storage;
import parasol:text.memDump;
import parasol:thread;
import parasol:types.Set;
import native:linux;

string MAKE_FILE = "make.pbld";

string PARASOL_INSTALL_PACKAGE_NAME = "install:parasollanguage.org";

public ref<Package> corePackage;					// If this maker is building the parasol runtime, be sure to use it
											// in other builds as well.
ref<Package> installPackage;				// If this maker is building the parasol compiler, be sure to use it
											// in other builds as well.

private monitor class CoordinatorVolatileData {
	boolean _overallSuccess;
}

public class BuildOptions {
	public ref<process.Option<string>> buildDirOption;
	public ref<process.Option<string>> buildFileOption;
	public ref<process.Option<int>> buildThreadsOption;
	public ref<process.Option<string>> outputDirOption;
	public ref<process.Option<string>> targetOSOption;
	public ref<process.Option<string>> targetCPUOption;
	public ref<process.Option<string>> suitesOption;
	public ref<process.Option<boolean>> traceOption;
	public ref<process.Option<boolean>> officialBuildOption;
	public ref<process.Option<boolean>> symbolTableOption;
	public ref<process.Option<boolean>> reportOutOfDateOption;
	public ref<process.Option<boolean>> verboseOption;
	public ref<process.Option<boolean>> logImportsOption;
	public ref<process.Option<boolean>> disassemblyOption;
	public ref<process.Option<string>> uiReadyOption;
	public ref<process.Option<string>> installContextOption;
	public ref<process.Option<boolean>> elisionOption;
	public ref<process.Option<boolean>> semiOption;

	public void setOptionDefaults() {
		if (buildDirOption == null)
			buildDirOption = process.Command.defaultStringOption();
		if (buildFileOption == null)
			buildFileOption = process.Command.defaultStringOption();
		if (buildThreadsOption == null)
			buildThreadsOption = process.Command.defaultIntOption();
		if (outputDirOption == null)
			outputDirOption = process.Command.defaultStringOption();
		if (targetOSOption == null)
			targetOSOption = process.Command.defaultStringOption();
		if (targetCPUOption == null)
			targetCPUOption = process.Command.defaultStringOption();
		if (suitesOption == null)
			suitesOption = process.Command.defaultStringOption();
		if (traceOption == null)
			traceOption = process.Command.defaultBooleanOption();
		if (officialBuildOption == null)
			officialBuildOption = process.Command.defaultBooleanOption();
		if (symbolTableOption == null)
			symbolTableOption = process.Command.defaultBooleanOption();
		if (reportOutOfDateOption == null)
			reportOutOfDateOption = process.Command.defaultBooleanOption();
		if (verboseOption == null)
			verboseOption = process.Command.defaultBooleanOption();
		if (logImportsOption == null)
			logImportsOption = process.Command.defaultBooleanOption();
		if (disassemblyOption == null)
			disassemblyOption = process.Command.defaultBooleanOption();
		if (uiReadyOption == null)
			uiReadyOption = process.Command.defaultStringOption();
		if (installContextOption == null)
			installContextOption = process.Command.defaultStringOption();
		if (elisionOption == null)
			elisionOption = process.Command.defaultBooleanOption();
		if (semiOption == null)
			semiOption = process.Command.defaultBooleanOption();

		if (!buildThreadsOption.set())
			buildThreadsOption.value = thread.cpuCount();
		if (!buildDirOption.set())
			buildDirOption.value = ".";
		if (!outputDirOption.set()) {
			if (buildFileOption.set())
				outputDirOption.value = storage.path(buildDirOption.value, "build");
		}
		if (!targetOSOption.set())
			targetOSOption.value = thisOS();
		if (!targetCPUOption.set())
			targetCPUOption.value = thisCPU();
		// Make sure the prefix test ends with a / - so that we don't accidentally match partial filenames.
		if (uiReadyOption.set() && !uiReadyOption.value.endsWith("/"))
			uiReadyOption.value.append('/');
	}
}

public class Coordinator extends CoordinatorVolatileData {
	private ref<BuildOptions> _buildOptions;
	private ref<context.Context> _installTarget;
	private Set<string> _suites;
	private Set<string> _definedSuites;
	private ref<thread.Thread>[] _threads;
	private ref<Package>[string] _packageMap;		// maps package name to Package, all the packages discovered that will be built
	private ref<context.PseudoContext> _pseudoContext;
	private ref<Product>[] _products;
	private string[] _commandLineProducts;
	private ref<Test>[] _tests;
	private string[] _onPassScripts;
	private string[] _onPassDirs;
	private string _afterPassScript;
	private static Monitor _lock;
	private static ref<thread.ThreadPool<boolean>> _workers;
	private Set<string> _uniqueTests;

	public Coordinator(ref<BuildOptions> buildOptions, string... components) {
		_buildOptions = buildOptions;

		lock(_lock) {
			if (_workers == null)
				_workers = new thread.ThreadPool<boolean>(buildThreads());
		}
		if (_buildOptions.suitesOption.set()) {
			string[] suiteNames = _buildOptions.suitesOption.value.split(',');
			for (i in suiteNames)
				_suites.add(suiteNames[i]);
		}
		_commandLineProducts = components;
		_pseudoContext = new context.PseudoContext(context.getActiveContext());
	}

	~Coordinator() {
		_tests.deleteAll();
	}

	public boolean validate() {
		switch (targetOS()) {
		case "linux":
		case "windows":
			break;

		default:
			printf("Unknown target OS '%s'\n", targetOS());
			return false;
		}
		switch (targetCPU()) {
		case "x86-64":
			break;

		default:
			printf("Unknown target CPU '%s'\n", targetCPU());
			return false;
		}

		if (installContext() != null) {
			printf("Install context: %s\n", installContext());
			_installTarget = context.get(installContext());
			if (_installTarget == null) {
				printf("    FAIL: Install context %s does not exist\n", installContext());
				return false;
			}
		}

		if (buildFile() != null) {
			if (!parseBuildFile(buildFile(), buildDir(), outputDir()))
				return false;
		} else if (!recurseThrough(buildDir(), outputDir()))
			return false;	

		if (_suites.size() != _definedSuites.size()) {
			for (Set<string>.iterator i = _suites.begin(); i.hasNext(); i.next()) {
				if (!_definedSuites.contains(i.key()))
					printf("    FAIL: Undefined test suite in command-line %s\n", i.key());
			}
			return false;
		}

		if (_buildOptions.elisionOption.set()) {
			if (_buildOptions.semiOption.set()) {
				printf("Cannot specify both --elide and --semi-colon options in the same command\n");
				return false;
			}
			compiler.semiColonElision = compiler.SemiColonElision.ENABLED;
		} else if (_buildOptions.semiOption.set())
			compiler.semiColonElision = compiler.SemiColonElision.DISABLED;

		if (_products.length() == 0) {
			printf("    FAIL: No build files found - nothing to do.\n");
			return false;
		}

		boolean success = true;
		if (_commandLineProducts.length() > 0) {
			boolean[] selected;
			selected.resize(_products.length());
			for (i in _commandLineProducts) {
				boolean found;
				for (j in _products) {
					if (_products[j].name() == _commandLineProducts[i]) {
						found = true;
						selected[j] = true;
						break;
					}
				}
				if (!found) {
					printf("    Unknown product: %s\n", _commandLineProducts[i]);
					success = false;
				}
			}
			if (!success) {
				printf("FAILED!\n");
				return false;
			}
			boolean changed;
			boolean[] checked;
			checked.resize(_products.length());
			do {
				changed = false;
				for (i in selected) {
					if (!selected[i])
						continue;
					if (checked[i])
						continue;
					checked[i] = true;
					changed = true;
					included := _products[i].includedProducts();
					for (j in included) {
						k := _products.find(included[j]);
						if (k < _products.length()) {
							selected[k] = true;
						}
					}
				}
			} while (changed);
	
			ref<Product>[] selectedProducts;
			for (i in selected) {
				if (!selected[i])
					continue;
				selectedProducts.append(_products[i]);
				_products[i] = null;
			}
			for (i in _products) {
				if (_products[i] != null)
					delete _products[i];
			}
			_products = selectedProducts;
		}

		if (generateDisassembly()) {
			boolean disassemblyPossible;
			for (i in _products) {
				p := _products[i];
				if (p.class <= RunnableProduct) {
					disassemblyPossible = true;
					break;
				}
			}
			if (!disassemblyPossible) {
				printf("    FAIL: None of the selected products can produce a meaningful dis-assembly\n");
				return false;
			}
		}


		if (verbose()) {
			for (i in _products)
				_products[i].print(0);
			for (i in _tests)
				printf("  TEST %s\n", _tests[i].toString());
			for (i in _onPassScripts)
				printf("  PASS SCRIPT @ %s\n", _onPassDirs[i]);
			if (_afterPassScript != null)
				printf("  AFTER_PASS %s\n", _afterPassScript);
		}

		return true;
	}

	private boolean recurseThrough(string dir, string outputDir) {
		ref<storage.Directory> d = new storage.Directory(dir);
		boolean success = true;
		string[] dirs;
		if (d.first()) {
			do {
				string filepath = d.path();
				string filename = d.filename();
				if (filename == MAKE_FILE) {
					string outDir;
					if (outputDir == null)
						outDir = storage.path(dir, "build");
					else
						outDir = storage.path(outputDir, dir);
					if (!parseBuildFile(filepath, dir, outDir))
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
			if (!recurseThrough(dirs[i], outputDir))
				success = false;
		return success;
	}

	public boolean parseBuildFile(string buildFile, string buildDir, string outputDir) {
		if (buildDir == null) {
			printf("parseBuildFile(%s, null, %s)\n", buildFile, outputDir);
			return false;
		}

		ref<BuildFile> bf = BuildFile.parse(buildFile, null, errorMessage, targetOS(), targetCPU(), this, outputDir, null);

		if (bf == null)
			return false;


		string absBuildDir = storage.absolutePath(buildDir);

		for (i in bf.products) {
			if (!bf.products[i].defineContext(bf, this, absBuildDir, outputDir)) {
				delete bf;
				return false;
			}
		}

		for (i in bf.tests) {
			ref<Suite> t = bf.tests[i];
			if (!t.composeTestList(&bf.tests, buildFile, absBuildDir, trace())) {
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
				string afterPassScript = t.afterPassScript();
				if (afterPassScript != null)
					addAfterPassScript(buildDir, afterPassScript);
			}
		}

		for (i in bf.products)
			_products.append(bf.products[i]);

		bf.products.clear();
		bf.tests.clear();

		delete bf;

		return true;
	}

	public boolean parseBuildFile(ref<BuildFile> importing, ref<script.Object> importDirective) {
		a := importDirective.get("filename");
		if (a == null)
			importing.error(importDirective, "No filename attribute");
		else {
			importedFile := storage.pathRelativeTo(a.toString(), importing.path());

			bf := BuildFile.parse(importedFile, null, errorMessage, targetOS(), targetCPU(), this, 
												importing.buildRoot().path(), importing.macroSet());

			if (bf == null)
				return false;

			absBuildDir := storage.absolutePath(storage.directory(importedFile));

			importing.tests.append(bf.tests);
			importing.products.append(bf.products);

			bf.products.clear();
			bf.tests.clear();
	
			delete bf;
	
			return true;
		}
		return false;
/*
		string name;
		string value;
		a := object.get("name");
		if (a == null)
			importing.error(object, "No name attribute");
		else
			name = a.toString()
		a = object.get("value");
		if (a == null)
			importing.error(object, "No value attribute");
		else
			value = a.toString();
*/
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

	public void addAfterPassScript(string testDir, string script) {
		_afterPassScript.printf("( cd %s\n %s\n )\n", testDir, script);
	}

	public int run() {
		lock(*this) {
			_overallSuccess = true;
		}
		boolean success = true;
		if (_commandLineProducts.length() == 0) {
			printableProducts := 0;
			for (i in _products)
				if (_products[i].showOutcome())
					printableProducts++;
			printf("Building all %d products.\n", printableProducts);
		} else if (_commandLineProducts.length() == 1)
			printf("Building %s.\n", _commandLineProducts[0]);
		else
			printf("Building %d selected products.\n", _commandLineProducts.length());
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

		for (i in _products)
			_products[i].scheduleBuild();
		for (i in _products)
			_products[i].waitForBuild();
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
					printf("%s\n", _onPassScripts[i]);
					if (!p.execute(_onPassDirs[i], "/bin/bash", process.useParentEnvironment, "-cev", _onPassScripts[i])) {
						printf("    FAIL: on_pass script failed\n");
						success = false;
					}
					delete p;
				}
			}
			if (_installTarget != null) {
				printf("    Installing to context %s:\n", installContext());
				for (i in _products) {
					p := _products[i];
					if (p == corePackage)
						continue;
					if (p.class != Package)
						continue;
					bldPkg := ref<Package>(p);
					if (!bldPkg.generateManifest())
						continue;
					pkg := new context.Package(null, null, bldPkg.path());
					if (_installTarget.definePackage(pkg))
						printf("        Installed package %s version %s\n", pkg.name(), pkg.version(),
												 installContext());
					else {
						printf("        FAIL: Could not install package %s version %s\n", pkg.name(), pkg.version(),
												 installContext());
						success = false;
					}
				}
			}
			if (success)
				printf("SUCCESS!\n");
		} else {
			printf("  Outcome    Product\n");
			for (i in _products)
				if (_products[i].showOutcome())
					printf("    %s   %s\n", _products[i].outcome(), _products[i].name());
			printf("FAIL: Build contained failures.\n");
		}
		if (success) {
			if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
				if (_afterPassScript != null) {
					pointer<byte>[] args;
					string s1 = "/bin/bash";
					string s2 = "-cev";
					args.append(s1.c_str());
					args.append(s2.c_str());
					string s = singleLine(_afterPassScript);
					args.append(s.c_str());
					args.append(null);
					linux.execv("/bin/bash".c_str(), &args[0]);
					// If the previous function returns, something went terribly wrong
					printf("execv of bash failed. errno is %s\n", linux.strerror(linux.errno()));
					success = false;
				}
			} else {
				printf("FAIL: build scripts contain after_pass scripts - unsupported on this platform.\n");
				success = false;
			}
		}

		return success ? 0 : 1;
	}

	private static string singleLine(string s) {
		string output;

		for (i in s) {
			if (s[i] == '\n')
				output += " ; ";
			else
				output.append(s[i]);
		}
		return output;
	}

	public void declareFailure() {
		lock(*this) {
			_overallSuccess = false;
		}
	}

	public ref<context.Context> activeContext() {
		return _pseudoContext;
	}

	public ref<thread.ThreadPool<boolean>> workers() {
		return _workers;
	}

	public int buildThreads() {
		return _buildOptions.buildThreadsOption.value;
	}

	public string buildDir() {
		return _buildOptions.buildDirOption.value;
	}

	public string buildFile() {
		return _buildOptions.buildFileOption.value;
	}

	public string outputDir() {
		return _buildOptions.outputDirOption.value;
	}

	public boolean generateDisassembly() {
		return _buildOptions.disassemblyOption.value;
	}

	public boolean officialBuild() {
		return _buildOptions.officialBuildOption.value;
	}
		
	public string targetOS() {
		return _buildOptions.targetOSOption.value;
	}

	public string targetCPU() {
		return _buildOptions.targetCPUOption.value;
	}

	public string installContext() {
		return _buildOptions.installContextOption.value;
	}

	public boolean runSuite(string suiteName) {
		return _suites.contains(suiteName);
	}

	public string uiPrefix() {
		return _buildOptions.uiReadyOption.value;
	}

	public boolean reportOutOfDate() {
		return _buildOptions.reportOutOfDateOption.value;
	}

	public boolean verbose() {
		return _buildOptions.verboseOption.value;
	}

	public boolean trace() {
		return _buildOptions.traceOption.value;
	}

	public boolean logImports() {
		return _buildOptions.logImportsOption.value;
	}

	public boolean generateSymbolTables() {
		return _buildOptions.symbolTableOption.value;
	}

	public ref<Application> getApplication(string name) {
		for (i in _products) {
			p := _products[i];
			printf("[%d] %s %s Application? %s\n", i, p.name(), p.toString(), p.class == Application);
			if (p.name() == name && p.class == Application)
				return ref<Application>(p);
		}
		return null;
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

