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

import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;
import parasol:process;
import parasol:storage;

monitor class ContextLock {
	ref<Context>[string] _contexts;
	string _contextDirectory;

	~ContextLock() {
		_contexts.deleteAll();
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
 */
public class Context {
	private string _name;
	private string _database;

	Context(string name) {
		_name = name;
	}

	Context(string name, string path) {
		_name = name;
		_database = path;
	}
/*
	Context(string name, http.Uri url) {
	}
 */
	~Context() {
		lock(contextLock) {
			_contexts.remove(_name);
		}
	}
/*
	public static ref<Context> createFromURL(string name, string url) {
		lock(contextLock) {
		}
	}
 */

	public int compare(ref<Context> other) {
		return this._name.compare(other._name);
	}

	public string name() {
		return _name;
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
		string contextDb = storage.constructPath(contextHome, name);
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
		string contextDb = storage.constructPath(contextHome, name);
		// If the disk exists or is otherwise un-creatable, we can't create the context
		if (!storage.makeDirectory(contextDb, false))
			return null;
		return _contexts[name] = new Context(name, contextDb);
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
		return _contexts[name];
	}
}
/**
 */
public ref<Context> getActiveContext() {
	string name = process.environment.get("PARASOL_CONTEXT");
	if (name == null)
		name = "default";
	return get(name);
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
	return storage.constructPath(home, ".parasol/contexts");
}
/**
 */
public class Unit {
	private string	_filename;
	private boolean _parsed;
	private boolean _rootFile;
/*
	private string _domain;
	private ref<Namespace> _namespaceSymbol;
	private ref<Ternary> _namespaceNode;
	private ref<UnitScope> _fileScope;
	private ref<SyntaxTree> _tree;
	private boolean _scopesBuilt;
	private boolean _staticsInitialized;
	private string _source;
	private ref<Scanner> _scanner;
*/
	public Unit(string f, boolean rootFile) {
		_filename = f;
		_rootFile = rootFile;
	}

	public Unit() {
	}
/*
	~Unit() {
		delete _tree;
		delete _scanner;
	}
	
	public void prepareForNewCompile() {
		delete _scanner;
		delete _tree;
		_tree = null;
		_scanner = null;
		_parsed = false;
		_scopesBuilt = false;
		_staticsInitialized = false;
		_namespaceNode = null;
		_domain = null;
	}
	
	public ref<Scanner> scanner() {
		if (_scanner == null)
			_scanner = Scanner.create(this);
		return _scanner;
	}
	
	public ref<Scanner> paradocScanner() {
		if (_scanner == null)
			_scanner = Scanner.createParadoc(this);
		return _scanner;
	}
	
	public ref<Scanner> newScanner() {
		return Scanner.create(this);
	}

	public boolean setSource(string source) {
		if (_filename != null)
			return false;
		_source = source;
		return true;
	}
	
	public void completeNamespace(ref<CompileContext> compileContext) {
		compileContext.arena().conjureNamespace(_domain, _namespaceNode, compileContext);
	}

	public boolean parseFile(ref<CompileContext> compileContext) {
		if (_parsed)
			return false;
		_parsed = true;
		compileContext.definingFile = this;
		_tree = new SyntaxTree();
		_tree.parse(this, compileContext);
		registerNamespace();
		return true;
	}

	public void noNamespaceError(ref<CompileContext> compileContext) {
		_tree.root().add(MessageId.NO_NAMESPACE_DEFINED, compileContext.pool());
	}

	private void registerNamespace() {
		for (ref<NodeList> nl = _tree.root().statements(); nl != null; nl = nl.next) {
			if (nl.node.op() == Operator.DECLARE_NAMESPACE) {
				if (_namespaceNode == null) {
					ref<Unary> u = ref<Unary>(nl.node);
					boolean x;
	
					_namespaceNode = ref<Ternary>(u.operand());
					(_domain, x) = _namespaceNode.left().dottedName();
				} else
					nl.node.add(MessageId.NON_UNIQUE_NAMESPACE, _tree.pool());
			}
		}
	}

	public boolean matches(string domain, ref<Ternary> importNode) {
		if (_namespaceNode == null)
			return false;
		if (_domain != domain)
			return false;
		return _namespaceNode.namespaceConforms(importNode);
	}

	public boolean buildScopes(string domain, ref<CompileContext> compileContext) {
		if (_scopesBuilt)
			return false;
		_scopesBuilt = true;
		_fileScope = compileContext.arena().createUnitScope(compileContext.arena().root(), _tree.root(), this);
		_tree.root().scope = _fileScope;
		compileContext.buildScopes();
		ref<Scope> domainScope = compileContext.arena().createDomain(domain);
		if (_namespaceNode != null) {
			_namespaceSymbol = _namespaceNode.middle().makeNamespaces(domainScope, domain, compileContext);
			ref<Doclet> doclet = _tree.getDoclet(_namespaceNode);
			if (doclet != null) {
				if (_namespaceSymbol._doclet == null)
					_namespaceSymbol._doclet = doclet;
				else
					_namespaceNode.add(MessageId.REDUNDANT_DOCLET, compileContext.pool());
			}
			_fileScope.mergeIntoNamespace(_namespaceSymbol, compileContext);
		} else
			_namespaceSymbol = compileContext.arena().anonymous();

		return true;
	}

	boolean collectStaticInitializers(ref<Target> target) {
		if (_staticsInitialized)
			return false;
		if (!_scopesBuilt && !_rootFile)
			return false;
		target.declareStaticBlock(this);
		_staticsInitialized = true;
		return true;
	}
 
	void clearStaticInitializers() {
		_staticsInitialized = false;
	}
 
	public string getNamespaceString() {
		if (_namespaceNode != null) {
			string name;
			boolean x;
			
			(name, x) = _namespaceNode.middle().dottedName();
			return _domain + ":" + name;
		} else
			return "<anonymous>";
	}

	public ref<SyntaxTree> swapTree(ref<SyntaxTree> replacement) {
		ref<SyntaxTree> original = _tree;
		_tree = replacement;
		return original;
	}
	
	public ref<SyntaxTree> tree() {
		return _tree; 
	}

	public ref<Namespace> namespaceSymbol() {
		return _namespaceSymbol;
	}

	public boolean hasNamespace() { 
		return _namespaceNode != null; 
	}

	public string domain() {
		return _domain;
	}

	public boolean parsed() {
		return _parsed;
	}
	
	public string filename() {
		if (_filename == null)
			return "<inline>";
		else
			return _filename; 
	}
	
	public string source() {
		return _source;
	}
	
	public ref<UnitScope> fileScope() {
		return _fileScope;
	}
	
	public boolean scopesBuilt() {
		return _scopesBuilt;
	}

	public void dumpMessage(ref<Node> node, ref<Commentary> comment) {
		if (!node.location().isInFile()) {
			printf("%s :", filename()); 
			printf(" %s\n", comment.message());
		} else {
			int lineNumber = _scanner.lineNumber(node.location());
			if (lineNumber >= 0)
				printf("%s %d: %s\n", filename(), lineNumber + 1, comment.message());
			else
				printf("%s [byte %d]: %s\n", filename(), node.location().offset, comment.message());
		}
	}
*/
}


