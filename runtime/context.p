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
namespace parasol:context;

import parasol:compiler;
import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;
import parasol:process;
import parasol:storage;
import parasol:time;

string PACKAGE_MANIFEST = ":manifest:";

monitor class ContextLock {
	ref<Context>[string] _contexts;
	string _contextDirectory;
	ref<TemporaryContext> _tempContext;		// For runs where PARASOL_CONTEXT_FILE is defined.

	~ContextLock() {
		if (_contexts.contains("default"))
			_contexts["default"].selfDestruct();
		_contexts.remove("default");
		_contexts.deleteAll();
		delete _tempContext;
	}

	void populateContexts() {
		if (_contextDirectory != null)
			return;
		_contextDirectory = getContextHome();
		if (storage.exists(_contextDirectory)) {
			if (storage.isDirectory(_contextDirectory)) {
				storage.Directory d(_contextDirectory);

		        if (d.first()) { 
        		    do { 
                		string contextName = d.filename();
						// Be sure to skip the special directory entries
						if (contextName == "." ||
							contextName == "..")
							continue;
						string path = d.path();
						if (validateContextName(contextName) &&
							storage.isDirectory(path))
							_contexts[contextName] = new Context(contextName, path);
						if (!_contexts.contains("default"))
							_contexts["default"] = new Context("default");
        		    } while (d.next());
		        } 
			} else
				throw IllegalOperationException("Parasol language context database is corrupted");
		} else
			_contexts["default"] = new Context("default");
	}
	/*
	 * A private entry point used to initialize the 'PARASOL_CONTEXT_FILE 'active context'.
	 *
	 * The file format provides the necessary information 
	 */
	ref<Context> loadTemporaryContext(string filename) {
		if (_tempContext == null) {
//			printf("Loading TemporaryContext file %s\n", filename);
			ref<Context> base = getShellActiveContext();
			_tempContext = new TemporaryContext(base);
	
			ref<Reader> file = storage.openTextFile(filename);
			if (file != null && _tempContext.loadFromReader(file, filename))
				delete file;
			else {
				printf("Could not load file %s\n", filename);
				delete file;
				delete _tempContext;
				_tempContext = null;
				return null;
			}
		}
		return _tempContext;
	}

}

ContextLock contextLock;
/**
 * A Parasol language context.
 *
 * This object describes a single Parasol language context and can be inspected
 * or modified.
 *
 * The disk database served by the Context object consists of a set of files describing the following:
 * <ul>
 *     <li>the version of the Parasol builder to use when building packages or applications using the context,
 *     <li>a set of installed packages,
 *     <li>a set of active versions when more than one version of a given package is available,
 *     <li>a set of build configuration parameters.
 * </ul>
 *
 * 
 */
public class Context {
	private string _name;
	private string _database;
	private ref<Package>[string] _packages;
	private ref<Package> _core;
	/**
	 * Strictly for extensions
	 */
	Context() {
	}

	Context(string name) {
		init(name);
	}

	Context(string name, string path) {
		_database = path;
		init(name);
	}
/*
	Context(string name, http.Uri url) {
	}
 */
	private void init(string name) {
		_name = name;
		string core = "core:parasollanguage.org";

		string exePath = process.binaryFilename();
		string installDir = storage.directory(storage.directory(exePath));
		string corePath = storage.path(installDir, "runtime");
		_core = new CorePackage(core, corePath);
		_packages[core] = _core;
	}
	/**
	 * The destructor for a Context. Calling delete on a context that is named 'default' is
	 * not allowed.
	 *
	 * @exception IllegalOperationException Thrown when trying to delete the default context.
	 */
	~Context() {
//		printf("~Context() %p\n", this);
		lock(contextLock) {
			if (_name == "default")
				throw IllegalOperationException("Attempt to delete 'default' context");
			_contexts.remove(_name);
		}
		_packages.deleteAll();
	}

	void selfDestruct() {
		_name = null;
		delete this;
	}
/*
	public static ref<Context> createFromURL(string name, string url) {
		lock(contextLock) {
		}
	}
 */
	/**
	 * Retrieve the named package from this context.
	 */
	public ref<Package> getPackage(string name) {
		ref<Package> p = _packages[name];
		if (p != null)
			return p;
		if (!validatePackageName(name))
			return null;
		// If the default context has never been modified, it won't have a directory
		// in the user's context list, so there won't be a defined _database field.
		if (_database != null) {
			string packageDir = storage.path(_database, "pkg/" + name);
			if (!storage.isDirectory(packageDir))
				return null;
			p = new Package(name, packageDir);
		}
		return null;
	}

	public boolean definePackage(ref<Package> p) {
		return false;
	}

	public int compare(ref<Context> other) {
		return this._name.compare(other._name);
	}

	public string name() {
		return _name;
	}

	public void printSymbolTable() {
	}

	public void print() {
	}
}
/**
 * Create a new context from a directory.
 *
 * @param name The name of the context to be created.
 * @param path An existing Parasol context database, or a copy of one.
 *
 * @return A reference to the newly created context object, or null if the database
 * entry to the context could not be created. Also returns null if the supplied
 * directory path does not name a readable directory, or if the context already exists.
 *
 * @exception IllegalArgumentException Thrown if the name is not a valid context name.
 */
public ref<Context> createFromDirectory(string name, string path) {
	if (!validateContextName(name))
		throw IllegalArgumentException("Invalid context name: " + name);
	if (!storage.isDirectory(path))
		return null;
	lock(contextLock) {
		populateContexts();
		if (_contexts.contains(name))
			return null;
		string contextHome = ensureContextHome();
		if (contextHome == null)
			return null;
		string contextDb = storage.path(contextHome, name);
		// If the disk exists or is otherwise un-creatable, we can't create the context
		if (!storage.createSymLink(path, contextDb))
			return null;
		return _contexts[name] = new Context(name, path);
	}
}
/**
 * Create a new context.
 * @param name The name of the context to be created.
 *
 * @return A reference to the newly created context object, or null if the database
 * entry to the context could not be created. Also returns null if the context already exists.
 *
 * @exception IllegalArgumentException Thrown if the name is not a valid context name.
 */
public ref<Context> create(string name) {
	if (!validateContextName(name))
		throw IllegalArgumentException("Invalid context name: " + name);
	lock(contextLock) {
		populateContexts();
		if (_contexts.contains(name))
			return null;
		string contextHome = ensureContextHome();
		if (contextHome == null)
			return null;
		string contextDb = storage.path(contextHome, name);
		// If the disk exists or is otherwise un-creatable, we can't create the context
		if (!storage.makeDirectory(contextDb, false))
			return null;
		ref<Context> ctx = new Context(name, contextDb);
		_contexts[name] = ctx;
		return ctx;
	}
}
/**
 *	Fetch a context by name.
 *
 * @param name The name of the context to return.
 *
 * @return If there is a context with the name, it is returned. If not, null is
 * returned.
 */
public ref<Context> get(string name) {
	lock (contextLock) {
		ref<Context> result = _contexts[name];
		if (result == null && name == "default") {
			result = new Context(name);
			_contexts[name] = result;
		}
		return result;
	}
}
/**
 * Return the current active context. If the environment varialbe PARASOL_CONTEXT
 * is defined, that is the name to use, otherwise use 'default' and return any context at that name.
 *
 * If the environment variable PARASOL_CONTEXT_FILE is defined, this Parasol process is typically running
 * under a development environment and must use a temporarily created 'context' to resolve any 
 * references to packages that are part of that build. The context is described in the file whose
 * path is given in the value of the variable.
 *
 * @return The currently active context, or null if either PARASOL_CONTEXT or PARASOL_CONTEXT_FILE do not name a valid context.
 */
public ref<Context> getActiveContext() {
	string devFile = process.environment.get("PARASOL_CONTEXT_FILE");
	if (devFile != null)
		return contextLock.loadTemporaryContext(devFile);
	else
		return getShellActiveContext();
}

private ref<Context> getShellActiveContext() {
	string name = process.environment.get("PARASOL_CONTEXT");
	if (name == null)
		name = "default";
	ref<Context> ctx = get(name);

	return ctx;
}

public class TemporaryContext extends Context {
	ref<Context> _base;
	ref<Package>[string] _packages;

	public TemporaryContext(ref<Context> base) {
		_base = base;
	}

	~TemporaryContext() {
//		printf("~TemporaryContext() %p\n", this);
		_packages.deleteAll();
	}

	boolean loadFromReader(ref<Reader> file, string filename) {
		boolean success = true;
		for(int lineno = 1;; lineno++) {
			string line;

			line = file.readLine();
			if (line == null)
				break;
			if (line.length() == 0)
				continue;
			switch (line[0]) {
			case 'P':
				int idx = line.indexOf('@');
				if (idx > 2) {
					substring packageName = line.substr(1, idx);
					substring directory = line.substr(idx + 1);
					ref<Package> p = new Package(packageName, directory);
					definePackage(p);
				} else {
					printf("File %s Line %d: Malformed record '%s'\n", filename, lineno, line);
					success = false;
				}
				break;

			default:
				printf("File %s Line %d: Unknown record '%s'\n", filename, lineno, line);
				success = false;
			}
		}
		return success;
	}

	public boolean writeContextData(ref<Writer> output) {
		for (name in _packages) {
			ref<Package> p = _packages[name];
			output.printf("P%s@%s\n", p.name(), storage.absolutePath(p.directory()));
		}
		return true;
	}

	public boolean definePackage(ref<Package> p) {
		if (_packages.contains(p.name()))
			return false;
		_packages[p.name()] = p;
		return true;
	}

	public ref<Package> getPackage(string name) {
//		printf("pseudo getting %s\n", name);
		ref<Package> p = _packages[name];
		if (p != null) {
//			printf("Found it !\n");
			return p;
		} else
			return _base.getPackage(name);
	}
}

/**
 */
public ref<Context>[] listAll() {
	ref<Context>[] results;

	lock (contextLock) {
		populateContexts();
		for (name in _contexts)
			results.append(_contexts[name]);
	}
	results.sort(contextListCompare, true);
	return results;
	
	int contextListCompare(ref<Context> left, ref<Context> right) {
		return left.compare(right);
	}
}
/**
 * Validates that it's argument is a valid context name.
 *
 * Context names may not contain and forward slash, backslash
 * newline or nul byte characters.
 * Any other characters are allowed.
 *
 * @param name The name string to be validated
 *
 * @return true if the name string can be assigned to a context, false otherwise.
 */
public boolean validateContextName(string name) {
	if (name.indexOf('/') < 0 &&
		name.indexOf('\n') < 0 &&
		name.indexOf('\\') < 0 &&
		name.indexOf(0) < 0)
		return true;
	else
		return false;
	
}
/**
 * Validate a package name.
 *
 * A valid package name consists of a case-insensitive string which has exactly one colon character 
 * with characters on either side. The characters following the colon must be a syntactically correct
 * domain name that does not end with a period.
 *
 * @return true if the name is a valid package name, false otherwise
 * @return If this is a valid package name, the index of the colon character.
 */
public boolean, int validatePackageName(string name) {
	int colonIndex = name.indexOf(':');
	if (colonIndex <= 0 || colonIndex == name.length() - 1) {
		return false, -1;
	}
	substring domain = name.substr(colonIndex + 1);
	if (!domain[0].isAlpha()) {
		return false, -1;
	}
	if (domain[domain.length() - 1] == '-') {
		return false, -1;
	}
	for (int i = 1; i < domain.length(); i++) {
		if (domain[i] == '-' || domain[i] == '.')
			continue;
		if (!domain[i].isAlphanumeric()) {
			return false, -1;
		}
	}
	return true, colonIndex;
}

private string ensureContextHome() {
	string contextHome = getContextHome();
	if (storage.ensure(contextHome))
		return contextHome;
	else {
		printf("Could not create the user context database, check our permissions for '%s'\n", contextHome);
		return null;
	}
}

private string getContextHome() {
	string home = storage.homeDirectory();

	if (home == null)
		throw IllegalOperationException("No home directory for user");
	return storage.path(home, ".parasol/contexts");
}

//@Constant
public string PARASOL_CORE_PACKAGE_NAME = "core:parasollanguage.org";

private monitor class VolatilePackage {
	enum ManifestState {
		NOT_LOADED,
		LOADING,
		LOADED,
		FAILED
	}

	protected ManifestState _manifestState;
}

/**
 * This class describes an installed package. It is built from the information stored in the context database.
 */
public class Package extends VolatilePackage {
	private string _name;
	private string _directory;
	private ref<Namespace>[string] _domains;
	private string[] _initFirst;
	private string[] _initLast;

	Package(string name, string directory) {
		_name = name;
		_directory = directory;
	}

	~Package() {
		_domains.deleteAll();
	}
	/**
	 * Return the directory containing the package files.
	 *
	 * @return The directory of the package files.
	 */
	public string directory() {
		return _directory;
	}
	/** {@ignore} */
	void setDirectory(string directory) {
		_directory = directory;
	}
	/**
	 * Open the package and preapre for it being analyzed.
	 *
	 * @return true if the package iis healthy and ready to be used.
	 * Returns false if the package cannot be used. This could indicate the
	 * package is corrupted in some way or some other reason. For the
	 * PseudoPackage class defined in pbuild, a false value indicates the
	 * package was being rebuilt as part of the build, so any products 
	 * will be unable to build.
	 */
	public boolean open() {
		return true;
	}
	/**
	 * Retrieve a complete list of units in the package.
	 */
	public string[], boolean getUnitFilenames() {
		string[] a;

		for (d in _domains)
			_domains[d].getUnitFilenames(&a);
		return a, false;
	}
	/**
	 * Retrieve a list of units that are members of the namespace referenced by the 
	 * function argument.
	 *
	 * @param domain The domain string of the namespace.
	 * @param namespaces A vector of name components. Each element is one of the
	 * identifier strings in the namespace. Note that this is typically derived from an
	 * import statement, so there may be names of symbols on the end of the list here.
	 * We will want to use the last name that matches, as long as there's one namespace
	 * that does match.
	 *
	 * @return A list of zero of more filenames where the units assigned to that namespace
	 * can be found. If the length of the array is zero, this package does not contain
	 * any units in that namespace.
	 */
	public string[] getNamespaceUnits(string domain, string... namespaces) {
		string[] a;

		if (loadManifest()) {
			ref<Namespace> nm = _domains.get(domain);
			if (nm != null) {
				for (i in namespaces) {
					ref<Namespace> next = nm.get(namespaces[i]);
					if (next == null) {
						if (i == 0)
							return a;			// If this package has no matching
												// namespaces, report no units.
						break;
					}
					nm = next;
				}
				return nm.units();
			}
		}
		return a;
	}
	
	boolean loadManifest() {
		lock (*this) {
			switch (_manifestState) {
			case NOT_LOADED:
				_manifestState = ManifestState.LOADING;
				break;

			case LOADING:
				wait();
				if (_manifestState == ManifestState.FAILED)
					return false;

			case LOADED:
				return true;

			case FAILED:
				return false;
			}
		}

		boolean success;
		string manifestFile = storage.path(_directory, PACKAGE_MANIFEST);
		ref<Reader> r = storage.openTextFile(manifestFile);
		if (r != null) {
			string domain;
			ref<Namespace> currentScope;
			ref<Namespace> nm;
			success = true;
			for (;;) {
				string line = r.readLine();
				if (line == null)
					break;
				if (line.length() == 0)
					continue;
//				printf("Line = '%s' currentScope = %p nm = %p\n", line, currentScope, nm);
				switch (line[0]) {
				case 'D':
					domain = line.substr(1);
					currentScope = createDomain(domain);
					break;
	
				case 'N':
					(currentScope, success) = currentScope.addNamespace(line.substr(1));
					break;
	
				case 'U':
					string unitFilename = storage.path(_directory, line.substr(1));
					currentScope.addUnit(unitFilename);
					break;
	
				case 'X':
					currentScope = currentScope.parent();
					break;

				case 'F':
					unitFilename = storage.path(_directory, line.substr(1));
					_initFirst.append(unitFilename);
					break;

				case 'L':
					unitFilename = storage.path(_directory, line.substr(1));
					_initLast.append(unitFilename);
					break;

				default:
					printf("        FAILED: unexpected content in manifest for package %s: %s\n", 
												_name, manifestFile);
					success = false;
				}
				if (!success)
					break;
			}
			delete r;
		} else
			printf("        FAILED: to open manifest for package %s: %s\n", _name, manifestFile);
		lock (*this) {
			if (success) {
				_manifestState = ManifestState.LOADED;
				notifyAll();
				return true;
			} else {
				_manifestState = ManifestState.FAILED;
				// Purge all the failed data before we unleash any waiting threads.
				_initFirst.clear();
				_initLast.clear();
				_domains.deleteAll();
				notifyAll();
				return false;
			}
		}
	}
	
	public ref<Namespace> createDomain(string domain) {
		ref<Namespace> d = _domains[domain];
		if (d == null) {
			d = new Namespace(null, domain);
			_domains[domain] = d;
		}
		return d;
	}

	public boolean inputsNewer(time.Instant timeStamp) {
		time.Instant modified;
		boolean success;

		(modified, success) = lastModified();
		if (!success)
			return false;			// The package is corrupted, force a recompile, which might fix it.
		return modified.compare(&timeStamp) > 0;
	}

	public time.Instant, boolean lastModified() {
		string manifest = storage.path(_directory, PACKAGE_MANIFEST);
		time.Instant accessed, modified, created;
		boolean success;

		(accessed, modified, created, success) = storage.fileTimes(manifest);
		return modified, success;
	}

	public string name() {
		return _name;
	}

	public string[] initFirst() {
		return _initFirst;
	}

	public string[] initLast() {
		return _initLast;
	}

	void print() {
		lock (*this) {
			for (d in _domains) {
				printf("Domain %s:\n", d);
				_domains[d].print(4);
			}
			if (_initFirst.length() > 0) {
				printf("init first: ");
				for (i in _initFirst)
					printf(" %s", _initFirst[i]);
				printf("\n");
			}
		}
	}
}
/**
 * The CorePackage is a sub-class designed to use the installed Parasol runtimes
 * at /usr/parasol. Each directory there is either a numbered version, beginning with a
 * letter v prefix, or the sym-link file named latest, which should be pointing at
 * one of the other version directories.
 */
class CorePackage extends Package {
	CorePackage(string name, string directory) {
		super(name, directory);
	}
}

class Namespace {
	private string _name;
	private ref<Namespace> _parent;
	private ref<Namespace>[string] _nameMap;
	private string[] _units;

	Namespace(ref<Namespace> parent, string name) {
		_parent = parent;
		_name = name;
	}

	~Namespace() {
		_nameMap.deleteAll();
	}

	public ref<Namespace>, boolean addNamespace(string name) {
		if (_nameMap[name] != null)
			return this, false;
		ref<Namespace> n = new Namespace(this, name);
		_nameMap[name] = n;
		return n, true;
	}

	public void addUnit(string filename) {
		_units.append(filename);
	}

	public ref<Namespace> get(string name) {
		return _nameMap[name];
	}

	public string[] units() {
		return _units;
	}

	public void getUnitFilenames(ref<string[]> output) {
		for (n in _nameMap)
			_nameMap[n].getUnitFilenames(output);
		output.append(_units);
	}

	public ref<Namespace> parent() {
		return _parent;
	}

	void print(int indent) {
		boolean printedSomething;
		for (i in _units) {
			printf("%*.*c  %s\n", indent, indent, ' ', _units[i]);
			printedSomething = true;
		}
		for (n in _nameMap) {
			ref<Namespace> nm = _nameMap[n];
			printf("%*.*c%s%s:\n", indent, indent, ' ', n, n != nm._name ? "(" + nm._name + ")" : "");
			_nameMap[n].print(indent + 4);
			printedSomething = true;
		}
		if (!printedSomething)
			printf("%*.*cNamespace/domain %s is empty\n", indent, indent, ' ', _name);
	}
}
