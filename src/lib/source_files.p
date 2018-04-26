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
namespace parasol:compiler;

import parasol:storage.Directory;

public class SourceCache {
	private ref<ImportDirectory>[string] _map;
	
	~SourceCache() {
		for (ref<ImportDirectory>[string].iterator i = _map.begin(); i.hasNext(); i.next())
			delete i.get();
	}
	
	ref<ImportDirectory> getDirectory(string dirName) {
		ref<ImportDirectory> dir = _map.get(dirName);
		if (dir == null) {
			dir = new ImportDirectory(dirName);
			_map[dirName] = dir;
		}
		return dir;
	}
}

public class ImportDirectory {
	private string _directoryName;
	private boolean _searched;			// true when the directory has been searched and the _files array populated.
	private ref<FileStat>[] _files;
	
	public ImportDirectory(string dirName) {
		_directoryName = dirName;
	}

	~ImportDirectory() {
		_files.deleteAll();
	}
	
	public void prepareForNewCompile() {
		for (int i = 0; i < _files.length(); i++) {
			ref<FileStat> fs = _files[i];
			fs.prepareForNewCompile();
		}
	}
	
	public boolean conjureNamespace(string domain, ref<Ternary> importNode, ref<CompileContext> compileContext, boolean logImports) {
		if (logImports)
			printf("conjureNamespace %s\n", _directoryName);
		search(compileContext, logImports);
		boolean importedSomething = false;
		for (int i = 0; i < _files.length(); i++) {
			ref<FileStat> fs = _files[i];
			if (fs.parseFile(compileContext) && logImports)
				printf("        Parsing file %s\n", fs.filename());
			if (logImports)
				printf("    File %s namespace %s\n", fs.filename(), fs.getNamespaceString());
			if (fs.matches(domain, importNode)) {
//				printf("Matched domain '%s'\n", domain);
				if (fs.buildScopes(domain, compileContext)) {
					if (logImports)
						printf("        Building scopes for %s\n", fs.filename());
					importedSomething = true;
				}
			}
		}
		return importedSomething;
	}
	/**
	 * This method is called on the 'package' directory in order to do a reference compile for
	 * the package. Each source file should be loaded as if it had been needed in the compile.
	 */
	public void compilePackage(ref<CompileContext> compileContext) {
		search(compileContext, false);
		for (i in _files) {
			ref<FileStat> fs = _files[i];
			fs.parseFile(compileContext);
			if (fs.hasNamespace())
				fs.completeNamespace(compileContext);
			else
				fs.noNamespaceError(compileContext);	// Files in a package that have no namespace
														// cannot get imported, so they only slow
														// down the process.
		}
	}

	private void search(ref<CompileContext> compileContext, boolean logImports) {
		if (!_searched) {
			if (logImports)
				printf("Searching %s\n", _directoryName);
			string dirName;
			if (_directoryName.startsWith("^/"))
				dirName = compileContext.arena().rootFolder() + _directoryName.substring(1);
			else
				dirName = _directoryName;
			ref<Directory> dir = new Directory(dirName);
			dir.pattern("*");
			if (dir.first()) {
				if (logImports)
					printf("Found %s\n", dir.path());
				do {
					string filename = dir.path();
					if (filename.endsWith(".p")) {
						ref<FileStat> fs = new FileStat(filename, false);
						_files.append(fs);
					}
				} while (dir.next());
			}
			delete dir;
			_searched = true;
		} else {
			if (logImports)
				printf("In %s\n", _directoryName);
		}
	}

	public void setFile(ref<FileStat> file) {
		_files.append(file);
	}

	public ref<FileStat> file(int index) {
		return _files[index];
	}
	
	public int fileCount() {
		return _files.length();
	}
	
	public int countMessages() {
		int count = 0;
		for (int i = 0; i < _files.length(); i++) {
			ref<SyntaxTree> tree = _files[i].tree();
			if (tree != null)
				count += tree.root().countMessages();
		}
		return count;
	}
	
	public void printMessages(ref<TemplateInstanceType>[] instances) {
		for (int i = 0; i < _files.length(); i++) {
			ref<SyntaxTree> tree = _files[i].tree();
			if (tree != null) {
				dumpMessages(_files[i], tree.root());
			}
			for (int j = 0; j < instances.length(); j++) {
				ref<TemplateInstanceType> instance = instances[j];
				if (instance.definingFile() == _files[i]) {
					if (instance.concreteDefinition().countMessages() > 0)
						dumpMessages(_files[i], instance.concreteDefinition());
				}
			}
		}
	}

	public void allNodes(ref<TemplateInstanceType>[] instances, 
			void(ref<FileStat>, ref<Node>, ref<Commentary>, address) callback, address arg) {
		for (i in _files) {
			ref<SyntaxTree> tree = _files[i].tree();
			if (tree != null) {
				allNodes(_files[i], tree.root(), callback, arg);
			}
			for (j in instances) {
				ref<TemplateInstanceType> instance = instances[j];
				if (instance.definingFile() == _files[i]) {
					if (instance.concreteDefinition().countMessages() > 0)
						allNodes(_files[i], instance.concreteDefinition(), callback, arg);
				}
			}
			for (j in instances) {
				ref<TemplateInstanceType> instance = instances[j];
				if (instance.definingFile() == _files[i]) {
					if (instance.concreteDefinition().countMessages() > 0)
						allNodes(_files[i], instance.concreteDefinition(), callback, arg);
				}
			}
		}			
	}

	public void printSymbolTable() {
		for (int i = 0; i < _files.length(); i++) {
			printf("    %s (%s)\n", _files[i].filename(), _files[i].getNamespaceString());
			if (_files[i].fileScope() != null)
				_files[i].fileScope().print(8, true);
		}
	}
	
	public void print() {
		printf("%s %s\n", _searched ? "(searched)" : "", _directoryName);
		for (int i = 0; i < _files.length(); i++) {
			printf("    %s (%s)\n", _files[i].filename(), _files[i].getNamespaceString());
			if (_files[i].namespaceSymbol() != null)
				_files[i].namespaceSymbol().print(8, false);
			else
				printf("        Namespace: <anonymous>\n");
			if (_files[i].tree() != null)
				_files[i].tree().root().print(8);
			else
				printf("       Tree: <null>\n");
		}
	}

	public boolean collectStaticInitializers(ref<Target> target) {
		boolean result = false;
		ref<FileStat>[] f = _files;
		f.sort(compareFilenames, true);
		for (int i = 0; i < f.length(); i++)
			result |= f[i].collectStaticInitializers(target);
		return result;
	}

	
	private static int compareFilenames(ref<FileStat> one, ref<FileStat> other) {
		return one.filename().compare(other.filename());
	}

	public void clearStaticInitializers() {
		for (int i = 0; i < _files.length(); i++)
			_files[i].clearStaticInitializers();
	}
	
	public string directoryName() {
		return _directoryName;
	}
}

void dumpMessages(ref<FileStat> file, ref<Node> n) {
	Message[] messages;
	n.getMessageList(&messages);
	if (messages.length() > 0) {
		for (int j = 0; j < messages.length(); j++) {
			ref<Commentary> comment = messages[j].commentary;
			file.dumpMessage(messages[j].node, comment);
		}
	}
}

void allNodes(ref<FileStat> file, ref<Node> n, void(ref<FileStat>, ref<Node>, ref<Commentary>, address) callback, address arg) {
	Message[] messages;
	n.getMessageList(&messages);
	if (messages.length() > 0) {
		for (j in messages) {
			callback(file, messages[j].node, messages[j].commentary, arg);
		}
	}
}

public class FileStat {
	private string	_filename;
	private boolean _parsed;
	private boolean _rootFile;
	private string _domain;
	private ref<Namespace> _namespaceSymbol;
	private ref<Ternary> _namespaceNode;
	private ref<UnitScope> _fileScope;
	private ref<SyntaxTree> _tree;
	private boolean _scopesBuilt;
	private boolean _staticsInitialized;
	private string _source;
	private ref<Scanner> _scanner;
	
	public FileStat(string f, boolean rootFile) {
		_filename = f;
		_rootFile = rootFile;
	}

	public FileStat() {
	}

	~FileStat() {
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
				ref<Unary> u = ref<Unary>(nl.node);
				boolean x;

				_namespaceNode = ref<Ternary>(u.operand());
				(_domain, x) = _namespaceNode.left().dottedName();
				break;
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
			_namespaceSymbol = _namespaceNode.middle().makeNamespaces(domainScope, compileContext);
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
}
