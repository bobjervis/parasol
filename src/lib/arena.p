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
namespace parasol:compiler;

import parasol:text;
import parasol:storage;
import parasol:file;
import parasol:process;
import parasol:runtime;
import parasol:pxi.SectionType;

public class Arena {
	private ref<Type>[TypeFamily] _builtInType;
	private ref<MemoryPool> _global;
	private string _rootFolder;
	private ref<Scope> _root;
	private ref<Scope> _main;
	private ref<SourceCache> _sourceCache;
	private ref<ImportDirectory>[] _importPath;
	private ref<ImportDirectory> _specialFiles;			// A pseudo-import directory for the files explicitly loaded (root + main)
	private ref<Scope>[string] _domains;
	private ref<Scope>[] _scopes;
	private ref<Namespace> _anonymous;
	private ref<TemplateInstanceType>[]	_types;

	private ref<Symbol> _int;
	private ref<Symbol> _string;
	private ref<Symbol> _var;
	private ref<OverloadInstance> _map;
	private ref<OverloadInstance> _vector;
	private ref<OverloadInstance> _enumVector;
	private ref<OverloadInstance> _ref;
	private ref<OverloadInstance> _pointer;
	
	private ref<SyntaxTree> _postCodeGeneration;
	
	int builtScopes;
	boolean _deleteSourceCache;
	boolean trace;
	boolean verbose;
	boolean logImports;
	SectionType preferredTarget;

	public Arena() {
		_sourceCache = new SourceCache();
		_deleteSourceCache = true;
		init();
	}
	
	public Arena(ref<SourceCache> sourceCache) {
		_sourceCache = sourceCache;
		init();
	}

	private void init() {
		setImportPath("^/src/lib,^/alys/lib");
		_global = new MemoryPool();
		_builtInType.resize(TypeFamily.BUILTIN_TYPES);
		_builtInType[TypeFamily.ERROR] = _global.newBuiltInType(TypeFamily.ERROR, null);
		_rootFolder = storage.directory(storage.directory(process.binaryFilename()));
		_specialFiles = new ImportDirectory("");
	}
	
	~Arena() {
		delete _specialFiles;
		_importPath.clear();
		delete _global;
		if (_deleteSourceCache)
			delete _sourceCache;
		_scopes.deleteAll();
	}
	/*
	 * setRootFolder
	 * 
	 * Allows one to build alternate sources when changing core source files.
	 */
	public void setRootFolder(string rootFolder) {
		_rootFolder = rootFolder;
	}
	/*
	 * setImportPath
	 * 
	 * If the importPath string is null, clear the import path entirely.
	 * Otherwise, split the string at each comma into component directory
	 * names, stored in the _importPath directory list.  Each component 
	 * is the name of a directory to search when resolving import statements. 
	 */
	public void setImportPath(string importPath) {
		_importPath.clear();
//		printf("setImportPath('%s')\n", importPath);
		if (importPath != null) {
			string[] elements = importPath.split(',');
			for (int i = 0; i < elements.length(); i++) {
				ref<ImportDirectory> dir = _sourceCache.getDirectory(elements[i]);
//				printf("Created import directory '%s'\n", dir.directoryName());
				dir.prepareForNewCompile();
				_importPath.append(dir);
			}
		}
	}

	public string importPath() {
		string result = "";
		for (int i = 0; i < _importPath.length(); i++) {
			if (i > 0)
				result.append(',');
			result.append(_importPath[i].directoryName());
		}
		return result;
	}
	
	public ref<Target> compile(string filename, boolean countCurrentObjects, boolean verbose) {
		ref<FileStat> mainFile = new FileStat(filename, false);
		return compile(mainFile, countCurrentObjects, false, verbose);
	}
	
	public ref<Target> compile(ref<FileStat> mainFile, boolean countCurrentObjects, boolean cloneTree, boolean verbose) {
		CompileContext context(this, _global, verbose);

		cacheRootObjects(_root, &context);

		mainFile.parseFile(&context);
		if (verbose)
			printf("Main file parsed\n");
		_specialFiles.setFile(mainFile);
//		mainFile.tree().root().print(0);
		if (mainFile.hasNamespace())
			mainFile.completeNamespace(&context);
		else
			mainFile.buildTopLevelScopes(&context);
		if (verbose)
			printf("Top level scopes constructed\n");
		context.resolveImports();
		createBuiltIns(_root, &context);
		
		_main = mainFile.fileScope();
		if (verbose)
			printf("Initial compilation phases completed.\n");
		context.compileFile();
		_postCodeGeneration = null;
		if (verbose)
			printf("Beginning code generation\n");
		ref<Target> target;
		if (cloneTree) {
			ref<SyntaxTree> copy = mainFile.tree().clone();
			ref<SyntaxTree> original = mainFile.swapTree(copy);
			target = Target.generate(this, mainFile, countCurrentObjects, &context, verbose);
			_postCodeGeneration = mainFile.swapTree(original);
		} else
			target = Target.generate(this, mainFile, countCurrentObjects, &context, verbose);
		return target;
	}
	
	int getIndex(address[] objects, address addr) {
		for (int i = 0; i < objects.length(); i++)
			if (objects[i] == addr)
				return i;
		return -1;
	}

	boolean writeHeader(file.File header) {
		for (ref<Scope>[string].iterator i = _domains.begin(); i.hasNext(); i.next()) {
			ref<Scope> s = i.get();
			if (!s.writeHeader(header))
				return false;
		}
		return true;
	}
	/**
	 * Get a symbol from a domain plus a namespace and symbol name path.
	 * 
	 * @return null if the path does not name a symbol. This method ignores
	 * visibility along the entire path. Private symbols will be found and returned.
	 */
	public ref<Symbol> getSymbol(string domain, string path, ref<CompileContext> compileContext) {
		ref<Scope> s = _domains.get(domain);
		if (s == null) {
			printf("Failed to find domain for '%s'\n", domain);
			return null;
		}
		string[] components = path.split('.');
		ref<Symbol> found = null;
		for (int i = 0; ; i++) {
			found = s.lookup(components[i], compileContext);
			if (found == null)
				return null;
			if (i == components.length() - 1)
				return found;
			if (found.assignType(compileContext) == null)
				return null;
			s = found.type().scope();
			if (s == null)
				return null;
		}
	}
	
	public ref<Symbol> getImport(boolean firstTry, string domain, ref<Ternary> namespaceNode, ref<CompileContext> compileContext) {
		if (logImports && firstTry) {
			string name;
			boolean result;
			
			if (namespaceNode.middle().op() == Operator.EMPTY)
				(name, result) = namespaceNode.right().dottedName();
			else
				(name, result) = namespaceNode.middle().dottedName();
			printf("Looking for %s:%s\n", domain, name);
		}
		ref<Scope> s = _domains.get(domain);
		if (s != null) {
			ref<Namespace> nm;
			if (namespaceNode.middle().op() == Operator.EMPTY) {
				nm = namespaceNode.right().getNamespace(s, compileContext);
				if (nm != null)
					return nm;
			} else {
				nm = namespaceNode.middle().getNamespace(s, compileContext);
				if (nm != null) {
					ref<Symbol> sym = nm.findImport(namespaceNode, compileContext);
					if (sym != null)
						return sym;
				}
			}
		}
		return null;
	}

	public boolean conjureNamespace(string domain, ref<Ternary> importNode, ref<CompileContext> compileContext) {
		boolean matched = _specialFiles.conjureNamespace(domain, importNode, compileContext, logImports);
		ref<FileStat> outer = compileContext.definingFile;
		for (int i = 0; i < _importPath.length(); i++)
			matched |= _importPath[i].conjureNamespace(domain, importNode, compileContext, logImports);
		compileContext.definingFile = outer;
		return matched;
	}

	public boolean load() {
		string rootFile = storage.constructPath(_rootFolder + "/lib", "root", "p");
		CompileContext rootLoader(this, _global, false);
		ref<FileStat> f = new FileStat(rootFile, true);
		f.parseFile(&rootLoader);
		_specialFiles.setFile(f);
		ref<Block> treeRoot = f.tree().root();
		_root = createRootScope(treeRoot, f);
		treeRoot.scope = _root;
		rootLoader.buildScopes();

		return treeRoot.countMessages() == 0;
	}

	public boolean createBuiltIns(ref<Scope> root, ref<CompileContext> compileContext) {
		boolean allDefined = true;
		for (int i = 0; i < builtInMap.length(); i++) {
			ref<Symbol> sym = root.lookup(builtInMap[i].name, compileContext);
			if (sym != null)
				_builtInType[builtInMap[i].family] = sym.bindBuiltInType(builtInMap[i].family, compileContext);
			if (_builtInType[builtInMap[i].family] == null) {
				root.definition().add(MessageId.UNDEFINED_BUILT_IN, _global, CompileString(builtInMap[i].name));
				allDefined = false;
				_builtInType[builtInMap[i].family] = compileContext.pool().newBuiltInType(builtInMap[i].family, ref<ClassType>(null));
			}
		}
		return allDefined;
	}

	public ref<Type> builtInType(TypeFamily family) {
		return _builtInType[family];
	}

	public ref<Type> buildVectorType(ref<Type> element, ref<Type> index, ref<CompileContext> compileContext) {
		if (index == null)
			index = _builtInType[TypeFamily.SIGNED_32];
		else {
			switch (index.family()) {
			case	ENUM:
				return _enumVector.createVectorInstance(element, index, compileContext);

			case	CLASS:
				if (index.compareMethod(compileContext) == null)
					return null;
				
			case	STRING:
				return _map.createVectorInstance(element, index, compileContext);
			
			case	SIGNED_32:
				break;
			
			default:
				return null;
			}
		}
		return _vector.createVectorInstance(element, index, compileContext);
	}

	ref<Type> createRef(ref<Type> target, ref<CompileContext> compileContext) {
		if (_ref != null)
			return _ref.createAddressInstance(target, compileContext);
		else
			return compileContext.errorType();
	}

	ref<Type> createPointer(ref<Type> target, ref<CompileContext> compileContext) {
		if (_pointer != null)
			return _pointer.createAddressInstance(target, compileContext);
		else
			return compileContext.errorType();
	}

	public void cacheRootObjects(ref<Scope> root, ref<CompileContext> compileContext) {
		ref<Symbol> sym = root.lookup("ref", compileContext);
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_ref = (*o.instances())[0];
		}
		sym = root.lookup("pointer", compileContext);
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_pointer = (*o.instances())[0];
		}
		_int = root.lookup("int", compileContext);
		_string = root.lookup("string", compileContext);
		_var = root.lookup("var", compileContext);
		sym = root.lookup("vector", compileContext);
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_vector = (*o.instances())[1];
			_enumVector = _vector;//o.instances()[2];
		}
		sym = root.lookup("map", compileContext);
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_map = (*o.instances())[0];
		}
	}

	public ref<Scope> createScope(ref<Scope> enclosing, ref<Node> definition, StorageClass storageClass) {
		ref<Scope> s = new Scope(enclosing, definition, storageClass, null);
		_scopes.append(s);
		return s;
	}

	public ref<UnitScope> createUnitScope(ref<Scope> rootScope, ref<Node> definition, ref<FileStat> file) {
		ref<UnitScope>  s = new UnitScope(rootScope, file, definition);
		_scopes.append(s);
		return s;
	}

	public ref<Scope> createRootScope(ref<Node> definition, ref<FileStat> file) {
		ref<Scope>  s = new RootScope(file, definition);
		_scopes.append(s);
		return s;
	}

	ref<ParameterScope> createParameterScope(ref<Scope> enclosing, ref<Node> definition, ParameterScope.Kind kind) {
		ref<ParameterScope> s = new ParameterScope(enclosing, definition, kind);
		_scopes.append(s);
		return s;
	}

	public ref<ClassScope> createClassScope(ref<Scope> enclosing, ref<Node> definition, ref<Identifier> className) {
		ref<ClassScope> s = new ClassScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<EnumScope> createEnumScope(ref<Scope> enclosing, ref<Block> definition, ref<Identifier> className) {
		ref<EnumScope> s = new EnumScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<FlagsScope> createFlagsScope(ref<Scope> enclosing, ref<Block> definition, ref<Identifier> className) {
		ref<FlagsScope> s = new FlagsScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<LockScope> createLockScope(ref<Scope> enclosing, ref<Node> definition) {
		ref<LockScope> s = new LockScope(enclosing, definition);
		_scopes.append(s);
		return s;
	}

	public ref<MonitorScope> createMonitorScope(ref<Scope> enclosing, ref<Node> definition) {
		ref<MonitorScope> s = new MonitorScope(enclosing, definition);
		_scopes.append(s);
		return s;
	}

	public ref<Scope> createDomain(string domain) {
		ref<Scope> s = _domains[domain];
		if (s == null) {
			s = createScope(_root, null, StorageClass.STATIC);
//			printf("Creating domain for '%s'\n", domain);
			_domains[domain] = s;
			if (domain.length() == 0 && _anonymous == null)
				_anonymous = _global.newNamespace(null, _root, s, null, null); 
		}
		return s;
	}

	public ref<Namespace> anonymous() {
		if (_anonymous == null)
			_anonymous = _global.newNamespace(null, _root, createScope(_root, null, StorageClass.STATIC), null, null);
		return _anonymous;
	}

	public void declare(ref<TemplateInstanceType> t) {
		_types.append(t);
	}

	void clearStaticInitializers() {
		_specialFiles.clearStaticInitializers();
		for (int i = 0; i < _importPath.length(); i++)
			_importPath[i].clearStaticInitializers();
	}
	
	boolean collectStaticInitializers(ref<Target> target) {
		boolean result = _specialFiles.collectStaticInitializers(target);
		for (int i = 0; i < _importPath.length(); i++)
			result |= _importPath[i].collectStaticInitializers(target);
		return result;
	}

	int countMessages() {
		int count = 0;
		count += _specialFiles.countMessages();
		for (int i = 0; i < _types.length(); i++)
			count += _types[i].concreteDefinition().countMessages();
		for (int i = 0; i < _importPath.length(); i++)
			count += _importPath[i].countMessages();
		return count;
	}

	void printMessages() {
		_specialFiles.printMessages(_types);
		for (int i = 0; i < _importPath.length(); i++)
			_importPath[i].printMessages(_types);
		if (_postCodeGeneration != null)
			dumpMessages(_specialFiles.file(1), _postCodeGeneration.root());
	}

	void printSymbolTable() {
		_specialFiles.printSymbolTable();
		printf("\nMain scope:\n");
		if (_main != null)
			_main.print(INDENT, true);
		printf("\nRoot scope:\n");
		_root.print(INDENT, true);
		for (int i = 0; i < _importPath.length(); i++)
			_importPath[i].printSymbolTable();
		for (ref<Scope>[string].iterator i = _domains.begin(); i.hasNext(); i.next()) {
			printf("\nDomain %s:\n", i.key());
			i.get().print(INDENT, true);
		}
	}
	
	void print() {
		printSymbolTable();
		_specialFiles.print();
		for (int i = 0; i < _importPath.length(); i++)
			_importPath[i].print();
	}

	public ref<SyntaxTree> postCodeGeneration() {
		return _postCodeGeneration;
	}
	
	public ref<MemoryPool> global() {
		return _global;
	}

	public string rootFolder() {
		return _rootFolder;
	}
	
	public ref<Scope> root() { 
		return _root; 
	}

	ref<ref<Scope>[]> scopes() { 
		return &_scopes;
	}

	ref<ref<TemplateInstanceType>[]> types() { 
		return &_types; 
	}

	ref<Symbol> stringType() {
		return _string;
	}
	
	ref<OverloadInstance> refTemplate() { 
		return _ref; 
	}

	ref<OverloadInstance> pointerTemplate() {
		return _pointer;
	}

	ref<OverloadInstance> vectorTemplate() {
		return _vector;
	}

	ref<OverloadInstance> mapTemplate() {
		return _map;
	}
}

class BuiltInMap {
	BuiltInMap() {}
	
	BuiltInMap(TypeFamily f, string n) {
		family = f;
		name = n;
	}
	
	public TypeFamily family;
	public string name;
}

private BuiltInMap[] builtInMap;

builtInMap.append(BuiltInMap(TypeFamily.SIGNED_16, "short"));
builtInMap.append(BuiltInMap(TypeFamily.SIGNED_32, "int"));
builtInMap.append(BuiltInMap(TypeFamily.SIGNED_64, "long"));
builtInMap.append(BuiltInMap(TypeFamily.UNSIGNED_8, "byte"));
builtInMap.append(BuiltInMap(TypeFamily.UNSIGNED_16, "char"));
builtInMap.append(BuiltInMap(TypeFamily.UNSIGNED_32, "unsigned"));
builtInMap.append(BuiltInMap(TypeFamily.FLOAT_32, "float"));
builtInMap.append(BuiltInMap(TypeFamily.FLOAT_64, "double"));
builtInMap.append(BuiltInMap(TypeFamily.VOID, "void"));
builtInMap.append(BuiltInMap(TypeFamily.VAR, "var"));
builtInMap.append(BuiltInMap(TypeFamily.STRING, "string"));
builtInMap.append(BuiltInMap(TypeFamily.BOOLEAN, "boolean"));
builtInMap.append(BuiltInMap(TypeFamily.CLASS_VARIABLE, "ClassInfo"));
builtInMap.append(BuiltInMap(TypeFamily.CLASS_DEFERRED, "*deferred*"));
builtInMap.append(BuiltInMap(TypeFamily.ARRAY_AGGREGATE, "*array*"));
builtInMap.append(BuiltInMap(TypeFamily.OBJECT_AGGREGATE, "*object*"));
builtInMap.append(BuiltInMap(TypeFamily.ADDRESS, "address"));
builtInMap.append(BuiltInMap(TypeFamily.EXCEPTION, "Exception"));
builtInMap.append(BuiltInMap(TypeFamily.NAMESPACE, "*Namespace*"));
