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
import parasol:pxi;
import parasol:runtime;
import parasol:script;
import parasol:storage;
import parasol:text;
import parasol:thread;
import parasol:time;
import parasol:types.Set;
import native:linux;

class Product extends Folder {
	private string _buildDir;
	private string _outputDir;
	private ref<Coordinator> _coordinator;
	private thread.Future<boolean> _future;
	protected boolean _compileSkipped;
	protected boolean _componentFailures;
	protected ref<Product>[] _includedProducts;
	protected string _version;

	Product(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object);
	}

	boolean defineContext(ref<BuildFile> buildFile, ref<Coordinator> coordinator, string buildDir, string outputDir) {
//		printf("Product.defineContext %s %s\n", name(), thread.currentThread().name());
		findProducts(buildFile, &_includedProducts);
		_coordinator = coordinator;
		_buildDir = buildDir;
		_outputDir = outputDir;
		return true;
	}

	void resolveNames(ref<BuildFile> buildFile) {
	}

	void scheduleBuild() {
		_coordinator.workers().execute(&_future, productBuilder, this);
	}

	void waitForBuild() {
		boolean buildSuccess = _future.get();
		boolean success = _future.success();
		
		if (!success || !buildSuccess) {
			_coordinator.declareFailure();
			printf("    FAIL: product %s build failed\n", toString());
		}
		e := _future.uncaught();
		if (e != null) {
			exception.uncaughtException(e);
			printf("\n");
		}

	}

	public boolean setVersion(string version) {
//		printf("setVersion %s -> %s\n", toString(), version);
		if (!context.Version.isValid(version))
			return false;
		_version = version;
		return true;
	}

	private static boolean productBuilder(address arg) {
		ref<Product> product = ref<Product>(arg);
//		printf("    %d Starting build of %s\n", thread.currentThread().id(), product.toString());
		return product.build();
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

	public ref<Product>[] includedProducts() {
		return _includedProducts;
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
		else if (_future.get() && _future.success())
			return "pass";
		else
			return "FAIL";
	}

	public boolean showOutcome() {
		return true;
	}

	protected string sentinelFileName() {
		return null;
	}
}

public class ParasolProduct extends Product {
	protected string[] _usedPackageNames;
	protected ref<context.Package>[] _usedPackages;
	protected ref<compiler.CompileContext> _compileContext;
	protected ref<compiler.Arena> _arena;
	protected boolean _buildSuccessful;

	public ParasolProduct(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object, boolean versionAllowed) {
		super(buildFile, enclosing, object);
		if (name() == null)
			buildFile.error(object, toString() + " must have a name");
		a := object.get("version");
		if (a != null) {
			if (!versionAllowed)
				buildFile.error(object, toString() + " shall not have a version");
			else {
				boolean success;

				(_version, success) = buildFile.expandMacros(a);
				if (!success)
					buildFile.error(object, toString() + " version must expand all macros: " + _version);
				else if (_version.indexOf('D') >= 0) {
					if (!context.Version.isValidTemplate(_version))
						buildFile.error(object, toString() + " version must be a valid version template");
				} else if (!context.Version.isValid(_version))
					buildFile.error(object, toString() + " version must be a valid version string");
				if (_version != null && _version.indexOf('D') >= 0) {
					_version = expandTemplate(_version);
				} else if (!buildFile.coordinator().officialBuild()) {
					_version = expandTemplate(_version + ".D");
				}
			}
		}
	}

	public string product() {
		return toString();
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
		if (name == this.name()) {
			buildFile.error(object, "A package cannot use itself");
			return false;
		}
		_usedPackageNames.append(name);
//		printf("%s using %s\n", this.name(), name);
		return true;
	}

	boolean defineContext(ref<BuildFile> buildFile, ref<Coordinator> coordinator, string buildDir, string outputDir) {
//		printf("Package.defineContext %s\n", thread.currentThread().name());
		super.defineContext(buildFile, coordinator, buildDir, outputDir);
		if (storage.exists(tmpPath())) {
			if (!storage.deleteDirectoryTree(tmpPath())) {
				printf("\n        FAIL: Could not remove existing temporary %s\n", tmpPath());
				return false;
			}
		}
		return true;
	}

	protected boolean, boolean buildComponents() {
		if (corePackage != null && corePackage != this)
			_includedProducts.append(corePackage);
		for (i in _usedPackageNames) {
//			printf("    %d Looking for %s -> %s\n", thread.currentThread().id(), _name, _usedPackageNames[i]);
			ref<context.Package> p = coordinator().activeContext().getPackage(_usedPackageNames[i]);
			if (p == null) {
				printf("        FAIL: Unknown reference '%s' in package '%s'\n", _usedPackageNames[i], name());
				return false, true;
			}
			_usedPackages.append(p);
			if (p.class == context.PseudoPackage) {
//				printf("Verified that %s -> %s in the same build\n", _name, _usedPackageNames[i]);
				ref<Package> pkg = ref<context.PseudoPackage>(p).buildPackage();
				_includedProducts.append(pkg);
			}
		}
		discoverExtraIncludedProducts(this);
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

	public boolean shouldCompile() {
		if (coordinator().officialBuild())
			return true;
		time.Instant accessed, modified, created;
		boolean success;

		(accessed, modified, created, success) = storage.fileTimes(sentinelFileName());

		if (success) {
			for (i in _includedProducts) {
				time.Instant iModified;

				(accessed, iModified, created, success) = storage.fileTimes(_includedProducts[i].sentinelFileName());

				if (iModified > modified)
					return true;
			}
			return inputsNewer(modified);
		} else {
			if (coordinator().reportOutOfDate())
				printf("            %s hasn't been built, building\n", toString());
			return true;		// sentinel file doesn't exist, maybe we never built this guy but we gotta build it now
		}
	}

	public boolean openCompiler() {
		_arena = new compiler.Arena(coordinator().activeContext());


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
		_compileContext = new compiler.CompileContext(_arena, 
													  coordinator().verbose(),
													  coordinator().logImports());

		ref<context.Package>[] compileUsing;

		Set<string> knownNames;

		// first de-dup the used package list.
		for (i in _usedPackages) {
			p := _usedPackages[i];
			if (knownNames.contains(p.name()))
				continue;
			compileUsing.append(p);
			knownNames.add(p.name());
		}
		// now form the closure over those packages.
		for (i in compileUsing) {
			p := compileUsing[i];
			used := p.usedPackages();
			for (j in used) {
				u := used[j];
				if (knownNames.contains(u.name()))
					continue;
				compileUsing.append(u);
				knownNames.add(u.name());
			}
		}
		if (!_compileContext.loadRoot(name() == context.PARASOL_CORE_PACKAGE_NAME, compileUsing)) {
			printf("        FAIL: Unable to load root scope\n");
			closeCompiler();
			return false;
		}
		return true;
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

	private static void extractMessagesWrapper(ref<compiler.Unit> file, ref<compiler.Node> node, ref<compiler.Commentary> comment, address arg) {
		ref<ParasolProduct>(arg).extractMessage(file, node, comment);
	}

	private void extractMessage(ref<compiler.Unit> file, ref<compiler.Node> node, ref<compiler.Commentary> comment) {
		string filename = file.filename();
		if (filename.startsWith(coordinator().uiPrefix())) {
			filename = filename.substr(coordinator().uiPrefix().length() - 1);
			if (node.location().isInFile()) {
				ref<compiler.Scanner> scanner = file.scanner();
				// The old scanner (which is already closed, so it cannot be used to re-scan tokens) has line number info.
				int lineNumber = file.lineNumber(node.location());

				byte commentClass = 'g';
				scanner = file.newScanner();
				scanner.seek(node.location());
				scanner.next();
				runtime.SourceOffset endLoc = scanner.cursor();
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

	protected void failMessage() {
		printf("        FAIL: %s failed to compile\n", name());
	}	

	public void closeCompiler() {
		delete _compileContext;
		delete _arena;
		_compileContext = null;
		_arena = null;
	}

	protected boolean deployProduct() {
		if (storage.exists(targetPath())) {
			if (!storage.deleteDirectoryTree(targetPath())) {
				printf("        FAIL: Could not remove old %s\n", targetPath());
				return false;
			}
		}

		if (!storage.rename(tmpPath(), targetPath())) {
			printf("        FAIL: Could not rename %s to %s\n", tmpPath(), targetPath());
			return false;
		}
		return true;
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

	protected string sentinelFileName() {
		return storage.path(outputDir(), filename() + ".ok");
	}

	public string tmpPath() {
		return storage.path(outputDir(), filename() + ".tmp");
	}

	public string targetPath() {
		return storage.path(outputDir(), filename());
	}

	public ref<ParasolProduct> parasolProduct() {
		return this;
	}
}

public class Package extends ParasolProduct {
	protected ref<context.Package> _package;

	protected boolean _preserveAnonymousUnits;
	protected boolean _generateManifest;
	protected string[] _initFirst;
	protected string[] _initLast;

	public Package(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object, true);

		ref<script.Atom> a;

		if (enclosing != null && enclosing.class != BuildRoot)
			buildFile.error(object, "Packages cannot be nested inside other components");
		if (name() != null) {
			if (!context.validatePackageName(name()))
				buildFile.error(a, "Package name '%s' is malformed", name());;
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
		_package = new context.PseudoPackage(buildFile.coordinator().activeContext(), this);
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
		if (_compileSkipped)
			printf("        %s - up to date\n", name());
		else {
			if (!deployProduct())
				return false;

			if (!writeSentinelFile())
				return false;
			printf("        %s - built\n", name());
		}

		_package.setDirectory(targetPath());
		_buildSuccessful = true;
		return true;
	}

	protected boolean buildTmpPackage(boolean copyContents) {
		boolean success;
		if (shouldCompile()) {
			_package.setDirectory(tmpPath());
	//		printf("Copy %s\n", _name);
			if (copyContents && !this.copyContents(tmpPath()))
				return false;
	
			if (_generateManifest) {
				ref<compiler.Target> t;
				(t, success) = compile();
				delete t;
				if (!success)
					return false;
				if (!_compileContext.forest().generateManifest(storage.path(tmpPath(), context.PACKAGE_MANIFEST), 
																					_initFirst, _initLast)) 
					return false;
				metadataFile := storage.path(tmpPath(), context.PACKAGE_METADATA);
				_package.setMetadata(_version, _usedPackages);
				if (!_package.writeMetadata(metadataFile))
					return false;
			}
		} else
			_compileSkipped = true;
		return true;
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		if (super.inputsNewer(timeStamp))
			return true;
		if (corePackage != null && corePackage != this && corePackage.inputsNewer(timeStamp))
			return true;
		for (i in _usedPackages)
			if (_usedPackages[i].inputsNewer(timeStamp))
				return true;
		return false;
	}

	public ref<compiler.Target>, boolean compile() {
		if (!openCompiler())
			return null, false;			

		ref<compiler.Target> target;
		string[] unitFilenames;
		getUnitFilenames(tmpPath(), &unitFilenames);
//		printf("    %d found %d unit filenames\n", thread.currentThread().id(), unitFilenames.length());
		target = _compileContext.compilePackage(this == corePackage, unitFilenames, tmpPath());
		
		if (coordinator().generateSymbolTables())
			_arena.printSymbolTable();
		if (coordinator().verbose())
			_arena.print();
		if (coordinator().generateDisassembly()) {
			if (!target.disassemble(_arena)) {
				return target, false;
			}
		}
		if (!printMessages()) {
			delete target;
			return null, false;
		} else if (target == null)
			return null, false;
		return target, true;
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

	public boolean shouldExport() {
		return true;
	}

	public string productName() {
		return name();
	}

	public boolean generateManifest() {
		return _generateManifest;
	}

	public ref<context.Package> ctxPackage() {
		return _package;
	}

	public string importPath() {
		if (_contents != null)
			return storage.path(buildDir(), _contents);
		else
			return path();
	}

	public string toString() {
		return "package " + name();
	}
}

class RunnableProduct extends ParasolProduct {
	protected string _main;
	private Role _role;

	public enum Role {
		ERROR,
		UTILITY,
		SERVICE,
		TEST
	}

	RunnableProduct(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object, boolean versionAllowed) {
		super(buildFile, enclosing, object, versionAllowed);
		ref<script.Atom> a = object.get("main");
		if (a != null)
			_main = a.toString();
		else
			buildFile.error(object, "'main' attribute required for command");
		a = object.get("role");
		if (a != null) {
			if (this.class != Application) {
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

	public boolean inputsNewer(time.Instant timeStamp) {
		time.Instant accessed, modified, created;
		boolean success;

		string mainFile = storage.path(buildDir(), _main, null);

		(accessed, modified, created, success) = storage.fileTimes(mainFile);

		if (!success) {
			if (coordinator().reportOutOfDate())
				printf("            %s doesn't exist in %s, building\n", herePath(mainFile), product());
			return true;
		}

		if (modified.compare(&timeStamp) > 0) {
			if (coordinator().reportOutOfDate())
				printf("            %s out of date in %s, building\n", herePath(mainFile), product());
			return true;
		}

		string dir = storage.directory(mainFile);

		storage.Directory d(dir);
		if (d.first()) {
			do {
				file := d.filename();
				if (file == "." || file == "..")
					continue;
				path := d.path();
				if (storage.isDirectory(path)) {
					if (checkSubDirectory(this, timeStamp, path))
						return true;
				}
			} while (d.next());
		}
		return super.inputsNewer(timeStamp);

		boolean checkSubDirectory(ref<RunnableProduct> app, time.Instant timeStamp, string dirPath) {
			storage.Directory d(dirPath);
			if (d.first()) {
				do {
					file := d.filename();
					if (file == "." || file == "..")
						continue;
					path := d.path();
					if (file.endsWith(".p")) {
						time.Instant accessed, modified, created;
						boolean success;

						(accessed, modified, created, success) = storage.fileTimes(path);
						if (!success) {			// That's odd - directry scan found it, but fileTimes missed it, should rebuild to see what happens
							if (app.coordinator().reportOutOfDate())
								printf("            %s doesn't exist in %s, building\n", herePath(path), product());
							return true;
						}
						if (modified.compare(&timeStamp) > 0) {
							if (app.coordinator().reportOutOfDate())
								printf("            %s out of date in %s, building\n", herePath(path), product());
							return true;
						}
					}
					if (storage.isDirectory(path)) {
						if (checkSubDirectory(app, timeStamp, path))
							return true;
					}
				} while (d.next());
			}
			return false;
		}
	}
}

public class Application extends RunnableProduct {
	Application(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object, true);
	}

	public boolean build() {
		boolean success, returnNow;

		(success, returnNow) = buildComponents();
		
		if (returnNow)
			return success;
		if (!shouldCompile()) {
			_buildSuccessful = true;
			_compileSkipped = true;
			printf("        %s - up to date\n", name());
			return true;
		}
		ref<compiler.Target> t;
		(t, success) = compile();
		delete t;
		if (!success)
			return false;

		string parasolRoot, binDir;
		if (installPackage != null) {
			if (!installPackage.future().get()) {
				_componentFailures = true;
				return false;
			}
			parasolRoot = installPackage.path();
			binDir = storage.path(parasolRoot, "bin");
		} else {
			binFile := process.binaryFilename();
			binDir = storage.directory(binFile);
			parasolRoot = storage.directory(binDir);
		}
		string rtFile = storage.path(binDir, "parasolrt");
		string destFile = storage.path(tmpPath(), "parasolrt");
		if (!storage.copyFile(rtFile, destFile)) {
			printf("        FAIL: Could not copy parasolrt from %s: %s\n", parasolRoot, linux.strerror(linux.errno()));
			return false;
		}
		string soFile = storage.path(binDir, "libparasol.so.1");
		destFile = storage.path(tmpPath(), "libparasol.so.1");
		if (!storage.copyFile(soFile, destFile)) {
			printf("        FAIL: Could not copy libparasol.so.1 from %s\n", parasolRoot);
			return false;
		}
		soFile = storage.path(tmpPath(), "libparasol.so");
		if (!storage.createSymLink("libparasol.so.1", soFile)) {
			printf("        FAIL: Could not link libparasol.so in %s\n", tmpPath());
			return false;
		}

		// write launch script
		string runScript = storage.path(tmpPath(), "run", null);
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
		w.printf("exec \"$pbuild_root/parasolrt\" \"$pbuild_root/application.pxi\" $@\n");
		delete w;
		if (!storage.setExecutable(runScript, true)) {
			printf("        FAIL: Could not make run script executable\n");
			return false;
		}
		_buildSuccessful = true;
		if (deployProduct() && writeSentinelFile()) {
			printf("        %s - built\n", name());
			return true;
		} else
			return false;
	}

	public ref<compiler.Target>, boolean compile() {
		if (!openCompiler())
			return null, false;			
		string mainFile = storage.path(buildDir(), _main);
		_compileContext.imageVersion = _version;
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
		if (!storage.ensure(tmpPath())) {
			printf("        FAIL: Could not ensure %s\n", tmpPath());
			return target, false;
		}
		if (target == null)
			return target, false;
		string pxiFile = storage.path(tmpPath(), "application.pxi");
		ref<pxi.Pxi> output = pxi.Pxi.create(pxiFile);
		target.writePxi(output);
		if (!output.write()) {
			printf("        FAIL: Error writing to %s\n", pxiFile);
			return target, false;
		}
		return target, true;
	}

	public boolean shouldCompile() {
		if (coordinator().generateDisassembly())
			return true;
		return super.shouldCompile();
	}
	/**
	 * Check whether the directory indicated by this object is well-formed..
	 *
	 * This is not called for a normal build, but is useful for a debugger that is being
	 * directed to run this application.
	 *
	 * @return true if this directory contains the files necessary to run the application,
	 * false otherwise.
	 */
	public boolean verify() {
		return verify(targetPath());
	}

	public static boolean verify(string path) {
		if (!storage.isDirectory(path))
			return false;
		pxi := storage.path(path, "application.pxi");
		if (!storage.exists(pxi))
			return false;
		run := storage.path(path, "run");
		if (!storage.isExecutable(run))
			return false;
		parasolrt := storage.path(path, "parasolrt");
		if (!storage.isExecutable(parasolrt))
			return false;
		return true;
	}

	public string toString() {
		return "application " + name();
	}
}

class Command extends RunnableProduct {
	Command(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object, false);
	}

	public boolean build() {
		boolean success, returnNow;

		(success, returnNow) = buildComponents();
		
		if (returnNow)
			return success;
		if (!shouldCompile()) {
			printf("        %s - up to date\n", name());
			_compileSkipped = true;
			return true;
		}
		ref<compiler.Target> t;
//		printf("        Calling compile for %s\n", toString());
		(t, success) = compile();
		delete t;
		if (success && writeSentinelFile()) {
			printf("        %s - built\n", name());
			return true;
		}
		return false;
	}

	public boolean shouldCompile() {
		if (coordinator().generateDisassembly())
			return true;
		return super.shouldCompile();
	}

	public ref<compiler.Target>, boolean compile() {
		if (!openCompiler())
			return null, false;
		string mainFile = storage.path(buildDir(), _main);
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

	protected void failMessage() {
		printf("        FAIL: %s failed to compile\n", toString());
	}	

	public string toString() {
		return "command " + name();
	}

	public boolean shouldExport() {
		return false;
	}

}

class Pxi extends RunnableProduct {
	private string _target;

	Pxi(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object) {
		super(buildFile, enclosing, object, true);
		ref<script.Atom> a = object.get("target");
		if (a != null)
			_target = a.toString();
	}

	boolean build() {
		boolean success, returnNow;

		(success, returnNow) = buildComponents();
		
		if (returnNow)
			return success;
		if (!shouldCompile()) {
			_buildSuccessful = true;
			_compileSkipped = true;
			printf("        %s - up to date\n", name());
			return true;
		}
		if (!openCompiler())
			return false;

		ref<compiler.Target> t;

		(t, success) = compile();
		delete t;

		closeCompiler();
		if (!_compileSkipped && writeSentinelFile())
			printf("        %s - built\n", name());
		return success;
	}

	public ref<compiler.Target>, boolean compile() {
		string mainFile = storage.path(buildDir(), _main);
		_compileContext.imageVersion = _version;
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
		string pxiFile = storage.path(outputDir(), filename());//path();
		ref<pxi.Pxi> output = pxi.Pxi.create(pxiFile);
		target.writePxi(output);
		if (!output.write()) {
			printf("        FAIL: Error writing to %s\n", pxiFile);
			return target, false;
		}
		return target, true;
	}

	public boolean shouldCompile() {
		if (coordinator().generateDisassembly())
			return true;
		return super.shouldCompile();
	}

	protected string sentinelFileName() {
		return storage.path(outputDir(), filename());
	}

	protected boolean writeSentinelFile() {	
		return true;
	}

	public boolean copy(string targetPath) {
		string destination = storage.path(targetPath, filename());
		string target = storage.path(outputDir(), filename());
		if (!storage.copyFile(target, destination)) {
			printf("    FAIL: Could not copy %s to %s\n", target, destination);
			return false;
		}
		return true;
	}

	public string toString() {
		string s;
		s.printf("pxi %s", name());
		return s;
	}

	public string path() {
		if (_enclosing != null)
			return storage.path(_enclosing.path(), filename());
		else
			return filename();
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
		string target = storage.path(buildDir(), _target);
		string product = path();
		time.Instant accessed, modified, created;
		boolean success;

		(accessed, modified, created, success) = storage.fileTimes(product);
		if (success) {
			if (!inputsNewer(modified)) {
				_compileSkipped = true;
				printf("        %s - up to date\n", name());
				return true;
			}
		} else {
			(accessed, modified, created, success) = storage.fileTimes(target);
			if (success) {
				if (!inputsNewer(modified)) {
					_compileSkipped = true;
					printf("        %s - up to date\n", name());
					return true;
				}
			} else {
				if (coordinator().reportOutOfDate())
					printf("        %s - never built, building\n", name());
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
			printf("        %s - built\n", name());
		return success;
	}

	public boolean copy(string targetPath) {
		string destination = storage.path(targetPath, filename());
		string target = storage.path(outputDir(), filename());
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
		s.printf("elf %s", name());
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

class IncludePackage extends Product {
	private string _src;
	private ref<Package> _package;
	private ref<script.Object> _object;

	public IncludePackage(ref<BuildFile> buildFile, ref<Folder> enclosing, ref<script.Object> object, string name, string src) {
		super(buildFile, enclosing, object);
		assert(this.name() == name);
		_src = src;
		_object = object;
	}

	void resolveNames(ref<BuildFile> buildFile) {
		for (i in buildFile.products) {
			ref<Product> p = buildFile.products[i];
			if (p.class == Package && p.name() == _src) {
				_package = ref<Package>(p);
				_object = null;
				
				return;
			}
		}
		buildFile.error(_object, "    FAIL: Could not find package for name %s\n", name());
	}

	void discoverExtraIncludedProducts(ref<Product> includer) {
		if (_package != null)
			includer._includedProducts.append(_package);
	}

	public boolean build() {
		if (_package == null)
			return false;
		if (!_package.future().get())
			return false;

		string destination;

		prod := parasolProduct();
		if (prod == null)
			destination = path();
		else {
			len := prod.targetPath().length();
			string sub = path().substr(len);
			destination = prod.tmpPath() + sub;
		}
/*
		if (!storage.ensure(path())) {
			printf("        FAIL: Could not ensure %s\n", path());
			return false;
		}
 */
		if (!storage.ensure(storage.directory(destination))) {
			printf("        FAIL: Could not ensure %s\n", storage.directory(destination));
			return false;
		}
		if (!storage.copyDirectoryTree(_package.path(), destination, false)) {
			printf("        FAIL: Could not copy %s to %s\n", _package.path(), destination);
			return false;
		}
		return true;
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		if (_package != null)
			return _package.inputsNewer(timeStamp);
		else
			return true;
	}

	public string toString() {
		string s;
		s.printf("include %s", name());
		return s;
	}

	public boolean showOutcome() {
		return false;
	}
}

string expandTemplate(string template) {
	string output;

	for (i in template) {
		c := template[i];
		if (c == 'D') {
			time.Formatter f("yyyyMMddHHmmss");
			time.Date d(time.Instant.now());
			output.append(f.format(&d));
		} else
			output.append(c);
	}
	return output;
}

string herePath(string path) {
	return storage.makeCompactPath(path, storage.path(storage.currentWorkingDirectory(), "xxx"));
}

void run(string... args) {
	int exitCode;
	string output;

	(exitCode, output) = process.execute(time.Duration.infinite, args);
	if (exitCode == 0)
		printf("%s\n", output);
	else
		printf("%d *\n%s\n", exitCode, output);
}

