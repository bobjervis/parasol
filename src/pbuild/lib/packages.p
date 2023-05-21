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
import parasol:process;
import parasol:pxi;
import parasol:runtime;
import parasol:script;
import parasol:storage;
import parasol:thread;
import parasol:time;

class Product extends Folder {
	private string _buildDir;
	private string _outputDir;
	private ref<Coordinator> _coordinator;
	private thread.Future<boolean> _future;
	protected boolean _compileSkipped;
	protected boolean _componentFailures;
	protected ref<Product>[] _includedProducts;

	Product(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object);
	}

	boolean defineContext(ref<Coordinator> coordinator, string buildDir, string outputDir) {
		findProducts(&_includedProducts);
		_coordinator = coordinator;
		_buildDir = buildDir;
		_outputDir = outputDir;
		return true;
	}

	boolean build() {
		printf("Unimplemented build: %s\n", toString());
		return false;
	}

	string buildDir() {
		return _buildDir;
	}

	string outputDir() {
		return _outputDir;
	}

	ref<Coordinator> coordinator() {
		return _coordinator;
	}

	public ref<thread.Future<boolean>> future() {
		return &_future;
	}

	void post(boolean outcome) {
		_future.post(outcome);
	}

	abstract string toString();

	public string outcome() {
		if (_compileSkipped)
			return "skip";
		else if (_componentFailures)
			return "    ";
		else if (_future.get())
			return "pass";
		else
			return "FAIL";
	}
}

public class Package extends Product {
	protected ref<context.Package> _package;
	protected ref<compiler.CompileContext> _compileContext;
	protected ref<runtime.Arena> _arena;

	protected boolean _buildSuccessful;
	protected string _packageDir;
	protected boolean _preserveAnonymousUnits;
	protected boolean _generateManifest;
	protected string[] _usedPackageNames;
	protected string[] _initFirst;
	protected string[] _initLast;
	protected ref<context.Package>[] _usedPackages;

	public Package(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object);
		if (enclosing != null && this.class != Pxi)
			buildFile.error(object, "Packages cannot be nested inside other components");
		if (_name != null) {
			if (this.class == Package && !context.validatePackageName(_name))
				buildFile.error(a, "Package name '%s' is malformed", _name);;
		} else
			buildFile.error(object, "Package must have a name");
		ref<script.Atom> a = object.get("preserveAnonymousUnits");
		if (a != null) {
			string value = a.toString();
			if (value == "true")
				_preserveAnonymousUnits = true;
			else if (value != "false")
				buildFile.error(a, "Attribute 'preserveAnonymousUnits' must be true or false");
		}
		a = object.get("manifest");
		if (a != null) {
			string value = a.toString();
			if (value == "true")
				_generateManifest = true;
			else if (value != "false")
				buildFile.error(a, "Attribute 'manifest' must be true or false");
		} else
			_generateManifest = true;
		if (this.class == Package)
			_package = new context.PseudoPackage(this);
	}

	boolean use(ref<BuildFile> buildFile, ref<script.Object> object) {
		ref<script.Atom> a = object.get("package");
		if (a == null) {
			buildFile.error(object, "Attribute 'package' is required");
			return false;
		}
		string name = a.toString();
		if (!context.validatePackageName(name)) {
			buildFile.error(object, "Attribute 'package' must be a valid package name");
			return false;
		}
		if (name == _name) {
			buildFile.error(object, "A package cannot use itself");
			return false;
		}
		_usedPackageNames.append(name);
//		printf("%s using %s\n", _name, name);
		return true;
	}

	boolean defineContext(ref<Coordinator> coordinator, string buildDir, string outputDir) {
		super.defineContext(coordinator, buildDir, outputDir);
		_packageDir = storage.constructPath(outputDir, _name + ".tmp");
		if (storage.exists(_packageDir)) {
			if (!storage.deleteDirectoryTree(_packageDir)) {
				printf("\n        FAIL: Could not remove existing temporary %s\n", _packageDir);
				return false;
			}
		}
		return true;
	}

	void defineStaticInitializer(Placement placement, ref<BuildFile> buildFile, ref<script.Object> object) {
		ref<script.Atom> a = object.get("content");
		if (a == null)
			return;
		string list = a.toString();
		if (list == null)
			return;
		string[] names = list.split('\n');
		for (i in names)
			names[i] = names[i].trim();
		switch (placement) {
		case FIRST:
			_initFirst.append(names);
			break;

		case LAST:
			_initLast.append(names);
		}
	}

	public boolean build() {
//		printf("    %d Implemented build: %s\n", thread.currentThread().id(), toString());
//		for (i in _includedProducts)
//			printf("        [%d] %s\n", i, _includedProducts[i].toString());
		boolean success, returnNow;

		(success, returnNow) = buildComponents();
		
		if (returnNow)
			return success;
	
//		printf("        %s Component outcomes successful: %s\n", _name, string(success));
		if (!buildTmpPackage(true))
			return false;
//		printf("        %s compileSkipped? %s\n", _name, _compileSkipped);
		if (_compileSkipped) {
			printf("        %s - up to date\n", _name);
			_packageDir = storage.constructPath(outputDir(), _name);
		} else {
			if (!deployPackage())
				return false;
			if (!writeSentinelFile())
				return false;
		}
		_buildSuccessful = true;
		if (!_compileSkipped)
			printf("        %s - built\n", _name);
		return true;
	}

	protected boolean, boolean buildComponents() {
		for (i in _usedPackageNames) {
//			printf("    %d Looking for %s -> %s\n", thread.currentThread().id(), _name, _usedPackageNames[i]);
			ref<context.Package> p = coordinator().activeContext().getPackage(_usedPackageNames[i]);
			if (p == null) {
				printf("        FAIL: Unknown reference '%s' in package '%s'\n", _usedPackageNames[i], _name);
				return false, true;
			}
			_usedPackages.append(p);
			if (p.class == context.PseudoPackage) {
//				printf("Verified that %s -> %s in the same build\n", _name, _usedPackageNames[i]);
				ref<Package> pkg = ref<context.PseudoPackage>(p).buildPackage();
				_includedProducts.append(pkg);
			}
		}
		boolean success = true;
		for (i in _includedProducts) {
			if (!_includedProducts[i].future().get()) {
//				printf("    %s failed, aborting %s\n", _includedProducts[i].name(), _name);
				success = false;
			}
		}
		if (!success) {
			_componentFailures = true;
			coordinator().declareFailure();
			// This will abort, but suppress the normal 'build failed' message for a package.
			return true, true;
		}
		return true, false;
	}

	protected boolean buildTmpPackage(boolean copyContents) {
		boolean success;
		if (!shouldCompile()) {
			_buildSuccessful = true;
			_compileSkipped = true;
			return true;
		}
//		printf("Copy %s\n", _name);
		if (copyContents && !this.copyContents())
			return false;

		if (_generateManifest) {
			ref<compiler.Target> t;
			(t, success) = compile();
			delete t;
			return success;
		} else
			return true;
	}

	protected boolean deployPackage() {
		string tmpDir = _packageDir;
		if (_generateManifest && !_compileContext.forest().generateManifest(storage.constructPath(tmpDir, context.PACKAGE_MANIFEST), _initFirst, _initLast)) 
			return false;
		_packageDir = storage.constructPath(outputDir(), _name);
		if (storage.exists(_packageDir)) {
			if (!storage.deleteDirectoryTree(_packageDir)) {
				printf("        FAIL: Could not remove old %s\n", _packageDir);
				return false;
			}
		}
		if (!storage.rename(tmpDir, _packageDir)) {
			printf("        FAIL: Could not rename %s to %s\n", tmpDir, _packageDir);
			return false;
		}
		return true;
	}

	public boolean shouldCompile() {
		time.Instant accessed, modified, created;
		boolean success;

		string sentinelFile = sentinelFileName();

//		printf("        sentinel file %s\n", sentinelFile);
		(accessed, modified, created, success) = storage.fileTimes(sentinelFile);

		if (success) {
			if (corePackage != null && corePackage != this && corePackage.inputsNewer(modified))
				return true;
			return inputsNewer(modified);
		} else
			return true;
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		if (super.inputsNewer(timeStamp))
			return true;
//		printf("        %s super inputsNewer false\n", _name);
		for (i in _usedPackages)
			if (_usedPackages[i].inputsNewer(timeStamp))
				return true;
		return false;
	}

	public boolean openCompiler() {
		configureArena();

//		printf("loadRoot for %s\n", _name);
		if (!_compileContext.loadRoot(_name == context.PARASOL_CORE_PACKAGE_NAME, _usedPackages)) {
			printf("        FAIL: Unable to load root scope\n");
			closeCompiler();
			return false;
		}
		return true;
	}

	public void closeCompiler() {
		delete _compileContext;
		delete _arena;
		_compileContext = null;
		_arena = null;
	}

	public ref<compiler.Target>, boolean compile() {
		if (!openCompiler())
			return null, false;			

		ref<compiler.Target> target;
		string[] unitFilenames;
		getUnitFilenames(&unitFilenames);
//		printf("    %d found %d unit filenames\n", thread.currentThread().id(), unitFilenames.length());
		target = _compileContext.compilePackage(unitFilenames, _packageDir);
		
		if (coordinator().generateSymbolTables())
			_arena.printSymbolTable();
		if (coordinator().verbose())
			_arena.print();
		if (!printMessages()) {
			delete target;
			return null, false;
		} else if (target == null)
			return null, false;
		return target, true;
	}

	protected boolean writeSentinelFile() {
		string sentinelFile = sentinelFileName();

		storage.File f;

		if (f.create(sentinelFile)) {				// This should update the modification time
			f.close();
			return true;
		} else {
			printf("        FAIL: Could not create sentinel file '%s'\n", sentinelFile);
			return false;
		}
	}
	/**
	 * Retrieve a list of units that are members of the namespace referenced by the 
	 * function argument. This will only be called after the build has successfully
	 * completed.
	 *
	 * @param namespaceNode A compiler namespace parse tree node containing the namespace
	 * that must be fetched.
	 *
	 * @return A list of zero of more filenames where the units assigned to that namespace
	 * can be found. If the length of the array is zero, this package does not contain
	 * any units in that namespace.
	 */
	public string[] getNamespaceUnits(ref<compiler.Ternary> namespaceNode) {
//		printf("(%s).getNamespaceUnits(%s)\n", _name, namespaceOf(namespaceNode));
		return _package.getNamespaceUnits(namespaceNode, _compileContext);
	}

	private string namespaceOf(ref<compiler.Ternary> namespaceNode) {
		string domain;
		boolean result;
		
		(domain, result) = namespaceNode.left().dottedName();
		string name;
			
		if (namespaceNode.middle().op() == compiler.Operator.EMPTY)
			(name, result) = namespaceNode.right().dottedName();
		else
			(name, result) = namespaceNode.middle().dottedName();
		return domain + ":" + name;
	}

	protected string sentinelFileName() {
		return storage.constructPath(outputDir(), _name + ".ok");
	}

	protected boolean printMessages() {
		if (_arena.countMessages() > 0) {
			if (coordinator().uiPrefix() != null) {
				_arena.allNodes(extractMessagesWrapper, this);
			} else
				_arena.printMessages();
			failMessage();
			return false;
		}
		return true;
	}

	protected void failMessage() {
		printf("        FAIL: %s failed to compile\n", _name);
	}	

	private static void extractMessagesWrapper(ref<compiler.Unit> file, ref<compiler.Node> node, ref<compiler.Commentary> comment, address arg) {
		ref<Package>(arg).extractMessage(file, node, comment);
	}

	private void extractMessage(ref<compiler.Unit> file, ref<compiler.Node> node, ref<compiler.Commentary> comment) {
		string filename = file.filename();
		if (filename.startsWith(coordinator().uiPrefix())) {
			filename = filename.substr(coordinator().uiPrefix().length() - 1);
			if (node.location().isInFile()) {
				ref<compiler.Scanner> scanner = file.scanner();
				// The old scanner (which is already closed, so it cannot be used to re-scan tokens) has line number info.
				int lineNumber = scanner.lineNumber(node.location());

				byte commentClass = 'g';
				scanner = file.newScanner();
				scanner.seek(node.location());
				scanner.next();
				compiler.Location endLoc = scanner.cursor();
				delete scanner;
				printf("={<%c%d %d %d %d %s>}=: %s\n", commentClass, lineNumber + 1, 
								node.location().offset,
								node.location().offset,
								endLoc.offset,
								filename, comment.message());
			} else
				printf("%s : %s\n", filename, comment.message());
		} else
			file.dumpMessage(node, comment);
	}

	public string path() {
		return _packageDir;
	}

	public boolean shouldExport() {
		return true;
	}

	public string productPath() {
		return storage.constructPath(outputDir(), _name);
	}

	public string productName() {
		return _name;
	}

	public boolean generateManifest() {
		return _generateManifest;
	}

	public string packageDir() {
		return _packageDir;
	}

	public ref<context.Package> ctxPackage() {
		return _package;
	}

	public string importPath() {
		if (_contents != null)
			return storage.constructPath(buildDir(), _contents);
		else
			return path();
	}

	void configureArena() {
		_arena = new runtime.Arena(coordinator().activeContext());


//		printf("Arena configured for %s coordinator = %p\n", _name, coordinator());
		_arena.verbose = coordinator().verbose();
		if (coordinator().targetOS() != thisOS() || coordinator().targetCPU() != thisCPU()) {
			switch (coordinator().targetOS()) {
			case "linux":
				_arena.preferredTarget = pxi.sectionType("x86-64-lnx");
				break;

			case "windows":
				_arena.preferredTarget = pxi.sectionType("x86-64-win");
				break;
			}
		}
		_compileContext = new compiler.CompileContext(_arena, coordinator().verbose(), coordinator().logImports());
	}

	public string toString() {
		return "package " + _name;
	}
}

class Application extends Package {
	protected string _main;
	private Role _role;

	public enum Role {
		ERROR,
		UTILITY,
		SERVICE,
		TEST
	}

	Application(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object);
		_generateManifest = false;
		ref<script.Atom> a = object.get("main");
		if (a != null)
			_main = a.toString();
		else
			buildFile.error(object, "'main' attribute reuired for command");
		a = object.get("role");
		if (a != null) {
			if (this.class != Application &&
				this.class != Binary) {
				buildFile.error(a, "A 'role' attribute is not allowed");
				return;
			}
			switch (a.toString()) {
			case "test":
				_role = Role.TEST;
				break;

			case "utility":
				_role = Role.UTILITY;
				break;

			case "service":
				_role = Role.SERVICE;
				break;

			default:
				buildFile.error(a, "'role' attribute must be 'test', 'utility' or 'service'");
			}
		} else
			_role = Role.UTILITY;
	}

	public boolean build() {
		boolean success, returnNow;

		(success, returnNow) = buildComponents();
		
		if (returnNow)
			return success;
		if (!shouldCompile()) {
			_buildSuccessful = true;
			_compileSkipped = true;
			printf("        %s - up to date\n", _name);
			return true;
		}
		ref<compiler.Target> t;
		(t, success) = compile();
		delete t;
		if (!success)
			return false;

		if (!storage.ensure(_packageDir)) {
			printf("        FAIL: Could not create package directory '%s'\n", _packageDir);
			return false;
		}
		string mainFile = storage.constructPath(buildDir(), _main);
		string mainScript = storage.filename(_main);
		string mainDest = storage.constructPath(_packageDir, mainScript);
		printf("mainDest = '%s'\n", mainDest);
		if (!storage.copyFile(mainFile, mainDest)) {
			printf("        FAIL: Could not copy main file from %s\n", mainFile);
			return false;
		}

		ref<compiler.Unit>[] units = _arena.units();
		string libDir = storage.constructPath(_packageDir, "lib");
		for (int i = 2; i < units.length(); i++) {
			printf("        [%d] %s\n", i, units[i].filename());
			string source = units[i].filename();
			string filename = storage.filename(source);
			int extLoc = filename.lastIndexOf('.');
			string extension;
			if (extLoc < 0)
				extension = "";
			else
				extension = filename.substr(extLoc);
			string basename = filename.substr(0, extLoc);
			string stem = storage.constructPath(libDir, basename);
			for (int iteration = 0; ; iteration++) {
				string dest = composeNameVariant(stem, extension, iteration);
				if (storage.exists(dest))
					continue;
				if (!storage.copyFile(source, dest)) {
					printf("        FAIL: Could not copy '%s' to '%s'\n", source, dest);
					return false;
				}
			}
		}

		printf("Implemented build: %s\n", toString());
		
		return false;
	}

	private static string composeNameVariant(string stem, string extension, int iteration) {
		if (iteration == 0)
			return stem + extension;
		else {
			// Can't printf directly into stem because string parameters can't be modified without catastrophe.
			string s = stem;
			s.printf(" (%d)%s", iteration, extension);
			return s;
		}
	}

	public boolean run() {
		if (!buildTmpPackage(true))
			return false;
		ref<context.Package> p = coordinator().activeContext().getPackage(context.PARASOL_CORE_PACKAGE_NAME);
		if (p == null) {
			printf("        FAIL: Could not find package '" + context.PARASOL_CORE_PACKAGE_NAME + "'\n");
			return false;
		}
		string parasolDir = _packageDir + "/parasol";
		if (!storage.copyDirectoryTree(p.directory(), parasolDir, false)) {
			printf("        FAIL: Could not copy package from %s\n", p.directory());
			return false;
		}

		// copy all compiled units to subdirectory. Need to figure out how to express this...
		assert(false);

		string mainFile = storage.constructPath(buildDir(), _main);
		string mainScript = storage.filename(_main);
		string mainDest = storage.constructPath(_packageDir, mainScript);
		if (!storage.copyFile(mainFile, mainDest)) {
			printf("        FAIL: Could not copy main file from %s\n", mainFile);
			return false;
		}

		// write launch script
		string runScript = storage.constructPath(_packageDir, "run");
		ref<Writer> w = storage.createTextFile(runScript);
		if (w == null) {
			printf("        FAIL: Could not create run script\n");
			return false;
		}
		w.printf("pbuild_root=$(dirname \"`readlink -f \\\"$0\\\"`\")\n");
		w.printf("exec \"$pbuild_root/parasol/bin/pc\" ");

		w.printf("\"$pbuild_root/%s\" \"$@\"\n", storage.filename(_main));
		delete w;
		if (!storage.setExecutable(runScript, true)) {
			printf("        FAIL: Could not make run script executable\n");
			return false;
		}

		// write asm script
		string asmScript = _packageDir;
		asmScript.append("/asm");
		w = storage.createTextFile(asmScript);
		if (w == null) {
			printf("        FAIL: Could not create asm script\n");
			return false;
		}
		w.printf("pbuild_root=$(dirname \"`readlink -f \\\"$0\\\"`\")\n");
		w.printf("exec \"$pbuild_root/parasol/bin/pc\" --asm -c \"$pbuild_root/%s\" \"$@\"\n", mainScript);
		delete w;
		if (!storage.setExecutable(asmScript, true)) {
			printf("        FAIL: Could not make run script executable\n");
			return false;
		}

		_buildSuccessful = true;
		return deployPackage();
	}

	public boolean shouldCompile() {
		time.Instant accessed, modified, created;
		boolean success;

		string packageDir = storage.constructPath(outputDir(), _name);
		string runScript = storage.constructPath(packageDir, "run");

		(accessed, modified, created, success) = storage.fileTimes(runScript);

		if (success) {
			if (corePackage != null && corePackage.inputsNewer(modified))
				return true;
			return inputsNewer(modified);
		} else {
			if (coordinator().reportOutOfDate())
				printf("            %s - never built, building\n", runScript);
			return true;
		}
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		time.Instant accessed, modified, created;
		boolean success;

		string mainFile = storage.constructPath(buildDir(), _main, null);

		(accessed, modified, created, success) = storage.fileTimes(mainFile);

		if (!success) {
			if (coordinator().reportOutOfDate())
				printf(" - %s doesn't exist, building", mainFile);
			return true;
		}

		if (modified.compare(&timeStamp) > 0) {
			if (coordinator().reportOutOfDate())
				printf(" - %s out of date, building", mainFile);
			return true;
		}

		return super.inputsNewer(timeStamp);
	}

	public ref<compiler.Target>, boolean compile() {
		if (!openCompiler())
			return null, false;


		string mainFile = storage.constructPath(buildDir(), _main);
		ref<compiler.Target> target = _compileContext.compile(mainFile);
		if (coordinator().generateSymbolTables())
			_arena.printSymbolTable();
		if (coordinator().verbose())
			_arena.print();
		if (!printMessages())
			return target, false;
		if (coordinator().generateDisassembly()) {
			if (!target.disassemble(_arena)) {
				return target, false;
			}
		}
		return target, true;
	}

	public string toString() {
		return "application " + _name;
	}

}

class Binary extends Application {
	Binary(ref<BuildFile> buildFile, ref<script.Object> object) {
		super(buildFile, null, object);
	}

	public boolean build() {
		boolean success, returnNow;

		(success, returnNow) = buildComponents();
		
		if (returnNow)
			return success;
		if (!shouldCompile()) {
			_buildSuccessful = true;
			_compileSkipped = true;
			printf("        %s - up to date\n", _name);
			return true;
		}
		ref<compiler.Target> t;
		(t, success) = compile();
		delete t;
		if (!success)
			return false;

		string parasolRoot = installPackage.path();
		string binDir = storage.constructPath(parasolRoot, "bin", null);
		string rtFile = storage.constructPath(binDir, "parasolrt", null);
		string destFile = storage.constructPath(_packageDir, "parasolrt", null);
		if (!storage.copyFile(rtFile, destFile)) {
			printf("        FAIL: Could not copy parasolrt from %s\n", parasolRoot);
			return false;
		}
		string soFile = storage.constructPath(binDir, "libparasol.so.1");
		destFile = storage.constructPath(_packageDir, "libparasol.so.1");
		if (!storage.copyFile(soFile, destFile)) {
			printf("        FAIL: Could not copy libparasol.so.1 from %s\n", parasolRoot);
			return false;
		}
		soFile = storage.constructPath(_packageDir, "libparasol.so");
		if (!storage.createSymLink("libparasol.so.1", soFile)) {
			printf("        FAIL: Could not link libparasol.so in %s\n", _packageDir);
			return false;
		}

		// write launch script
		string runScript = storage.constructPath(_packageDir, "run", null);
		ref<Writer> w = storage.createTextFile(runScript);
		if (w == null) {
			printf("        FAIL: Could not create run script\n");
			return false;
		}
		w.printf("#!/bin/bash\npbuild_root=$(dirname \"`readlink -f \\\"$0\\\"`\")\n");
		w.printf("if [ \"x$LD_LIBRARY_PATH\" == \"x\" ]\nthen\n");
		w.printf("export LD_LIBRARY_PATH=$pbuild_root\n");
		w.printf("else\n");
		w.printf("export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$pbuild_root\n");
		w.printf("fi\n");
		w.printf("echo $LD_LIBRARY_PATH\n");
		w.printf("exec \"$pbuild_root/parasolrt\" \"$pbuild_root/application.pxi\" $@\n");
		delete w;
		if (!storage.setExecutable(runScript, true)) {
			printf("        FAIL: Could not make run script executable\n");
			return false;
		}
		_buildSuccessful = true;
		if (deployPackage()) {
			printf("        %s - built\n", _name);
			return true;
		} else
			return false;
	}

	public ref<compiler.Target>, boolean compile() {
		ref<compiler.Target> target;
		boolean success;
		(target, success) = super.compile();
		if (!success)
			return target, false;
		if (!storage.ensure(path())) {
			printf("        FAIL: Could not ensure %s\n", path());
			return target, false;
		}
		string pxiFile = storage.constructPath(_packageDir, "application.pxi");
		ref<pxi.Pxi> output = pxi.Pxi.create(pxiFile);
		target.writePxi(output);
		if (!output.write()) {
			printf("        FAIL: Error writing to %s\n", pxiFile);
			return target, false;
		}
		return target, true;
	}

	public string toString() {
		return "binary " + _name;
	}
}

class Command extends Application {
	Command(ref<BuildFile> buildFile, ref<script.Object> object) {
		super(buildFile, null, object);
	}

	public boolean build() {
		if (!shouldCompile()) {
			printf("        %s - up to date\n", _name);
			_compileSkipped = true;
			return true;
		}
		ref<compiler.Target> t;
		boolean success;
//		printf("        Calling compile for %s\n", toString());
		(t, success) = compile();
		delete t;
		if (success && writeSentinelFile()) {
			printf("        %s - built\n", _name);
			return true;
		}
		return false;
	}

	public boolean shouldCompile() {
		time.Instant accessed, modified, created;
		boolean success;

		(accessed, modified, created, success) = storage.fileTimes(sentinelFileName());

		if (success) {
			if (inputsNewer(modified))
				return true;
			if (corePackage != null)
				return corePackage.inputsNewer(modified);
			else
				return false;
		} else {
			if (coordinator().reportOutOfDate())
				printf("            %s - never built, building\n", _name);
			return true;
		}
	}

	protected void failMessage() {
		printf("        FAIL: %s failed to compile\n", toString());
	}	

	public string toString() {
		return "command " + _name;
	}

	public boolean shouldExport() {
		return false;
	}

}

class Pxi extends Application {
	private string _target;

	Pxi(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object);
		ref<script.Atom> a = object.get("target");
		if (a != null)
			_target = a.toString();
	}

	boolean build() {
		if (!shouldCompile()) {
			_buildSuccessful = true;
			_compileSkipped = true;
			printf("        %s - up to date\n", _name);
			return true;
		}
		if (!openCompiler())
			return false;

		ref<compiler.Target> t;
		boolean success;
		(t, success) = compile();
		delete t;

		closeCompiler();
		if (!_compileSkipped)
			printf("        %s - built\n", _name);
		return success;
	}

	public ref<compiler.Target>, boolean compile() {

		string mainFile = storage.constructPath(buildDir(), _main);
		ref<compiler.Target> target = _compileContext.compile(mainFile);
		if (coordinator().generateSymbolTables())
			_arena.printSymbolTable();
		if (coordinator().verbose())
			_arena.print();
		if (!printMessages())
			return target, false;
		if (coordinator().generateDisassembly()) {
			if (!target.disassemble(_arena)) {
				return target, false;
			}
		}
		string pxiFile = storage.constructPath(outputDir(), _name);//path();
		ref<pxi.Pxi> output = pxi.Pxi.create(pxiFile);
		target.writePxi(output);
		if (!output.write()) {
			printf("        FAIL: Error writing to %s\n", pxiFile);
			return target, false;
		}
		return target, true;
	}

	public boolean shouldCompile() {
		time.Instant accessed, modified, created;
		boolean success;
		string target = storage.constructPath(outputDir(), _name);

		(accessed, modified, created, success) = storage.fileTimes(target);
		if (success) {
			if (corePackage != null && corePackage != this && corePackage.inputsNewer(modified))
				return true;
			return inputsNewer(modified);
		} else {
			if (coordinator().reportOutOfDate())
				printf("            %s - never built, building\n", path());
			return true;
		}
		return true;
	}

	public boolean copy() {
		string destination = path();
		string target = storage.constructPath(outputDir(), _name);
		if (!storage.copyFile(target, destination)) {
			printf("    FAIL: Could not copy %s to %s\n", target, destination);
			return false;
		}
		return true;
	}

	public string toString() {
		string s;
		s.printf("pxi %s", _name);
		return s;
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		return false;
	}

	public string path() {
		if (_enclosing != null)
			return storage.constructPath(_enclosing.path(), _name);
		else
			return _name;
	}
}

class MakeProduct extends Product {
	private string _target;
	private string _makefile;
	private static Monitor _makeLock;

	MakeProduct(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		// The Folder constructuor will contain a set of File tags. These are the
		// dependencies in the makefile, so we only need to invoke make if they're
		// newer. The files themselves are not copied to the product output.
		super(buildFile, enclosing, object);
		ref<script.Atom> a = object.get("target");
		if (a != null)
			_target = a.toString();
		a = object.get("makefile");
		if (a != null)
			_makefile = a.toString();

		// technically, we should parse the makefile, etc., but yuck. Been there done that.

	}

	public boolean build() {
		string target = storage.constructPath(buildDir(), _target);
		string product = path();
		time.Instant accessed, modified, created;
		boolean success;

		(accessed, modified, created, success) = storage.fileTimes(product);
		if (success) {
			if (!inputsNewer(modified)) {
				_compileSkipped = true;
				printf("        %s - up to date\n", _name);
				return true;
			}
		} else {
			(accessed, modified, created, success) = storage.fileTimes(target);
			if (success) {
				if (!inputsNewer(modified)) {
					_compileSkipped = true;
					printf("        %s - up to date\n", _name);
					return true;
				}
			} else {
				if (coordinator().reportOutOfDate())
					printf("        %s - never built, building\n", _name);
			}
		}
		process.stdout.flush();
		lock (_makeLock) {
			// TODO: Need Windows logic for this, to make it portable
			ref<process.Process> p = new process.Process();
			success = p.execute(buildDir(), "/usr/bin/make", process.useParentEnvironment, 
											"-f", _makefile, _target);
			delete p;
		}
		if (success)
			printf("        %s - built\n", _name);
		return success;
	}

	public boolean copy() {
		string destination = path();
		string target = storage.constructPath(outputDir(), _name);
		if (!storage.copyFile(target, destination)) {
			printf("    FAIL: Could not copy %s to %s\n", target, destination);
			return false;
		}
		return true;
	}
}

class Elf extends MakeProduct {
	Elf(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		// The Folder constructuor will contain a set of File tags. These are the
		// dependencies in the makefile, so we only need to invoke make if they're
		// newer. The files themselves are not copied to the product output.
		super(buildFile, enclosing, object);
	}

	public string toString() {
		string s;
		s.printf("elf %s", _name);
		return s;
	}
}

/**
 * At some point, a Windows port will be needed, so thisis a place-holder.
 */
class Exe extends MakeProduct {
	private string _name;

	Exe(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		// The Folder constructuor will contain a set of File tags. These are the
		// dependencies in the makefile, so we only need to invoke make if they're
		// newer. The files themselves are not copied to the product output.
		super(buildFile, enclosing, object);
	}

	public string toString() {
		string s;
		s.printf("exe %s", _name);
		return s;
	}
}
