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
/**
 * The compiler namespace defines the facilities necessary to compile Parasol programs into
 * executable code.
 *
 * You must first create and load an Arena object. The Arena object holds global state information
 * about the compilation, such as the symbol table.
 *
 * <i>This is important</i> if you want to put a &lt; character into your comment, to avoid it
 * being mistaken for an HTML tag, be sure to escape it either with the \&lt; HTML escape syntax or
 * the somewhat less hard to read escape of \\\<.
 */
namespace parasol:compiler;

import parasol:storage;
import parasol:process;
import parasol:runtime;

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

	private ref<OverloadInstance> _map;
	private ref<OverloadInstance> _vector;
	private ref<OverloadInstance> _enumVector;
	private ref<OverloadInstance> _ref;
	private ref<OverloadInstance> _pointer;
	private ref<PlainSymbol> _Object;
	private ref<PlainSymbol> _Array;

	int builtScopes;
	boolean _deleteSourceCache;
	boolean verbose;
	boolean logImports;
	/**
	 * This is set during configuration to true in order to decorate the parse trees with
	 * references to doclets (and of course to parse those doclets).
	 */
	public boolean paradoc;

	runtime.Target preferredTarget;

	public Arena() {
		_sourceCache = new SourceCache();
		_deleteSourceCache = true;
		init();
	}
	
	public Arena(ref<SourceCache> sourceCache) {
		_sourceCache = sourceCache;
		init();
	}

	public Arena(string rootFolder) {
		_sourceCache = new SourceCache();
		_deleteSourceCache = true;
		_rootFolder = rootFolder;
		init();
	}

	private void init() {
		setImportPath("^/src/lib");
		_global = new MemoryPool();
		_builtInType.resize(TypeFamily.BUILTIN_TYPES);
		_builtInType[TypeFamily.ERROR] = _global.newBuiltInType(TypeFamily.ERROR, null);
		if (_rootFolder == null)
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
	
	public ref<Target> compile(string filename, boolean countCurrentObjects, boolean verbose, boolean leaksFlag,
														string profilePath, string coveragePath) {
		ref<FileStat> mainFile = new FileStat(filename, false);
		return compile(mainFile, countCurrentObjects, verbose, leaksFlag, profilePath, coveragePath);
	}
	
	public ref<Target> compile(ref<FileStat> mainFile, boolean countCurrentObjects, boolean verbose, boolean leaksFlag,
														string profilePath, string coveragePath) {
		CompileContext context(this, _global, verbose);

		if (!compileOnly(mainFile, verbose, &context))
			return null;
		return codegen(mainFile, countCurrentObjects, verbose, leaksFlag, profilePath, coveragePath, &context);
	}

	public void compilePackage(boolean countCurrentObjects, boolean verbose) {
		CompileContext context(this, _global, verbose);

		// 'import' all the namespaces in the primary import directory (the package directory).
		// _importPath[0] is the ImportDirectory we need to pull in.

		_importPath[0].compilePackage(&context);
		if (createBuiltIns(&context))
			context.compileFile();
	}

	public ref<ImportDirectory> compilePackage(int index, ref<CompileContext> compileContext) {
		if (index >= _importPath.length())
			return null;

		// 'import' all the namespaces in the primary import directory (the package directory).
		// _importPath[0] is the ImportDirectory we need to pull in.

		_importPath[index].compilePackage(compileContext);
		return _importPath[index];
	}

	public void finishCompilePackages(ref<CompileContext> compileContext) {
		if (createBuiltIns(compileContext))
			compileContext.compileFile();
	}

	public boolean compileOnly(ref<FileStat> mainFile, boolean verbose, ref<CompileContext> compileContext) {
		mainFile.parseFile(compileContext);
		if (verbose)
			printf("Main file parsed\n");
		_specialFiles.setFile(mainFile);
//		mainFile.tree().root().print(0);
		if (mainFile.hasNamespace())
			mainFile.completeNamespace(compileContext);
		else
			mainFile.buildScopes(null, compileContext);
		if (verbose)
			printf("Top level scopes constructed\n");
		if (!createBuiltIns(compileContext))
			return false;
		
		_main = mainFile.fileScope();
		if (verbose)
			printf("Initial compilation phases completed.\n");
		compileContext.compileFile();
		return true;
	}

	public ref<Target> codegen(ref<FileStat> mainFile, boolean countCurrentObjects,
										boolean verbose, boolean leaksFlag, string profilePath, string coveragePath, 
										ref<CompileContext> compileContext) {
		if (verbose)
			printf("Beginning code generation\n");
		ref<Target> target;
		target = Target.generate(this, mainFile, countCurrentObjects, compileContext,
										verbose, leaksFlag, profilePath, coveragePath);
		return target;
	}
	
	int getIndex(address[] objects, address addr) {
		for (int i = 0; i < objects.length(); i++)
			if (objects[i] == addr)
				return i;
		return -1;
	}

	public boolean writeHeader(ref<Writer> header) {
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
		if (s == null)
			return null;
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

	public boolean createBuiltIns(ref<CompileContext> compileContext) {
		compileContext.resolveImports();
		ref<Symbol> sym = _root.lookup("ref", compileContext);
		if (sym == null) {
			missingRootSymbol("ref");
			return false;
		}
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_ref = (*o.instances())[0];
		}
		sym = _root.lookup("pointer", compileContext);
		if (sym == null) {
			missingRootSymbol("pointer");
			return false;
		}
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_pointer = (*o.instances())[0];
		}
		sym = _root.lookup("vector", compileContext);
		if (sym == null) {
			missingRootSymbol("vector");
			return false;
		}
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_vector = (*o.instances())[0];
			if (_vector.parameterCount() != 2)
				_vector = (*o.instances())[1];
			_enumVector = _vector;
		}
		sym = _root.lookup("map", compileContext);
		if (sym == null) {
			missingRootSymbol("map");
			return false;
		}
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_map = (*o.instances())[0];
		}
		sym = _root.lookup("Object", compileContext);
		if (sym == null) {
			missingRootSymbol("Object");
			return false;
		}
		if (sym.class == PlainSymbol)
			_Object = ref<PlainSymbol>(sym);
		sym = _root.lookup("Array", compileContext);
		if (sym == null) {
			missingRootSymbol("Array");
			return false;
		}
		if (sym.class == PlainSymbol)
			_Array = ref<PlainSymbol>(sym);

		boolean allDefined = true;
		for (int i = 0; i < builtInMap.length(); i++) {
			ref<Symbol> sym = _root.lookup(builtInMap[i].name, compileContext);
			if (sym != null)
				_builtInType[builtInMap[i].family] = sym.bindBuiltInType(builtInMap[i].family, compileContext);
			if (_builtInType[builtInMap[i].family] == null) {
				missingRootSymbol(builtInMap[i].name);
				allDefined = false;
				_builtInType[builtInMap[i].family] = compileContext.pool().newBuiltInType(builtInMap[i].family, ref<ClassType>(null));
			}
		}
		_builtInType[TypeFamily.VOID] = compileContext.pool().newBuiltInType(TypeFamily.VOID, ref<ClassType>(null));
		return allDefined;
	}

	private void missingRootSymbol(string name) {
		_root.definition().add(MessageId.UNDEFINED_BUILT_IN, _global, name);
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

			default:
				if (validMapIndex(index, compileContext))
					return _map.createVectorInstance(element, index, compileContext);
				else
					return null;
				
			case	SIGNED_8:
			case	UNSIGNED_8:
			case	SIGNED_16:
			case	UNSIGNED_16:
			case	SIGNED_32:
			case	UNSIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_64:
				break;
			}
		}
		return _vector.createVectorInstance(element, index, compileContext);
	}

	public boolean validMapIndex(ref<Type> index, ref<CompileContext> compileContext) {
		switch (index.family()) {
		case	ENUM:
		case	SIGNED_8:
		case	UNSIGNED_8:
		case	SIGNED_16:
		case	UNSIGNED_16:
		case	SIGNED_32:
		case	UNSIGNED_32:
		case	SIGNED_64:
		case	UNSIGNED_64:
			break;

		default:
			if (index.compareMethod(compileContext) == null)
				break;
			
		case	STRING:
		case	STRING16:
		case	FLOAT_32:
		case	FLOAT_64:
		case	ADDRESS:
		case	POINTER:
		case	REF:
		case	INTERFACE:
			return true;
		}
		return false;
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

	public ref<NamespaceScope> createNamespaceScope(ref<Scope> enclosing, ref<Namespace> namespaceSymbol) {
		ref<NamespaceScope>  s = new NamespaceScope(enclosing, namespaceSymbol);
		_scopes.append(s);
		return s;
	}

	public ref<Scope> createRootScope(ref<Node> definition, ref<FileStat> file) {
		ref<Scope>  s = new RootScope(file, definition);
		_scopes.append(s);
		return s;
	}

	public ref<ParameterScope> createParameterScope(ref<Scope> enclosing, ref<Node> definition, ParameterScope.Kind kind) {
		ref<ParameterScope> s = new ParameterScope(enclosing, definition, kind);
		_scopes.append(s);
		return s;
	}

	public ref<ProxyMethodScope> createProxyMethodScope(ref<Scope> enclosing) {
		ref<ProxyMethodScope> s = new ProxyMethodScope(enclosing);
		_scopes.append(s);
		return s;
	}

	public ref<ClassScope> createClassScope(ref<Scope> enclosing, ref<Node> definition, ref<Identifier> className) {
		ref<ClassScope> s = new ClassScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<InterfaceImplementationScope> createInterfaceImplementationScope(ref<InterfaceType> definedInterface, ref<ClassType> implementingClass, int itableSlot) {
		ref<InterfaceImplementationScope> s = new InterfaceImplementationScope(definedInterface, implementingClass, itableSlot);
		_scopes.append(s);
		return s;
	}
	
	public ref<InterfaceImplementationScope> createInterfaceImplementationScope(ref<InterfaceType> definedInterface, ref<ClassType> implementingClass, ref<InterfaceImplementationScope> baseInterface, int firstNewMethod) {
		ref<InterfaceImplementationScope> s = new InterfaceImplementationScope(definedInterface, implementingClass, baseInterface, firstNewMethod);
		_scopes.append(s);
		return s;
	}
	
	public ref<ThunkScope> createThunkScope(ref<InterfaceImplementationScope> enclosing, ref<ParameterScope> func, boolean isDestructor) {
		ref<ThunkScope> s = new ThunkScope(enclosing, func, isDestructor);
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

	public ref<LockScope> createLockScope(ref<Scope> enclosing, ref<Lock> definition) {
		ref<LockScope> s = new LockScope(enclosing, definition);
		_scopes.append(s);
		return s;
	}

	public ref<MonitorScope> createMonitorScope(ref<Scope> enclosing, ref<Node> definition, ref<Identifier> className) {
		ref<MonitorScope> s = new MonitorScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<Scope> createDomain(string domain) {
		ref<Scope> s = _domains[domain];
		if (s == null) {
//			printf("Creating domain for '%s'\n", domain);
			ref<Namespace> nm;
			if (domain.length() == 0)
				nm = anonymous();
			else
				nm = _global.newNamespace(domain, null, _root, null, null, this);
			s = nm.symbols();
			_domains[domain] = s;
		}
		return s;
	}

	public ref<Scope> getDomain(string domain) {
		return _domains[domain];
	}

	public ref<Namespace> anonymous() {
		if (_anonymous == null)
			_anonymous = _global.newNamespace(null, null, _root, null, null, this);
		return _anonymous;
	}

	public void declare(ref<TemplateInstanceType> t) {
		_types.append(t);
	}

	public void clearStaticInitializers() {
		_specialFiles.clearStaticInitializers();
		for (int i = 0; i < _importPath.length(); i++)
			_importPath[i].clearStaticInitializers();
	}
	
	public boolean collectStaticInitializers(ref<Target> target) {
		boolean result = _specialFiles.collectStaticInitializers(target);
		for (int i = _importPath.length() - 1; i >= 0; i--)
			result |= _importPath[i].collectStaticInitializers(target);
		return result;
	}

	public int countMessages() {
		int count = 0;
		count += _specialFiles.countMessages();
		for (int i = 0; i < _types.length(); i++)
			count += _types[i].concreteDefinition().countMessages();
		for (int i = 0; i < _importPath.length(); i++)
			count += _importPath[i].countMessages();
		return count;
	}

	public void printMessages() {
		_specialFiles.printMessages(_types);
		for (int i = 0; i < _importPath.length(); i++)
			_importPath[i].printMessages(_types);
	}

	public void allNodes(void(ref<FileStat>, ref<Node>, ref<Commentary>, address) callback, address arg) {
		_specialFiles.allNodes(_types, callback, arg);
		for (i in _importPath)
			_importPath[i].allNodes(_types, callback, arg);
	}

	public void printSymbolTable() {
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
	
	public void print() {
		printSymbolTable();
		_specialFiles.print();
		for (int i = 0; i < _importPath.length(); i++)
			_importPath[i].print();
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

	public ref<ref<Scope>[]> scopes() { 
		return &_scopes;
	}

	public ref<ref<TemplateInstanceType>[]> types() { 
		return &_types; 
	}

	public boolean isVector(ref<Type> type) {
		if (type.family() != TypeFamily.SHAPE)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(_vector.type());
		return tt.wrappedType() == ref<TemplateInstanceType>(type).templateType();
	}

	public boolean isMap(ref<Type> type) {
		if (type.family() != TypeFamily.SHAPE)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(_map.type());
		return tt.wrappedType() == ref<TemplateInstanceType>(type).templateType();
	}

	public ref<OverloadInstance> refTemplate() { 
		return _ref; 
	}

	public ref<OverloadInstance> pointerTemplate() {
		return _pointer;
	}

	public ref<OverloadInstance> vectorTemplate() {
		return _vector;
	}

	public ref<OverloadInstance> mapTemplate() {
		return _map;
	}

	public ref<PlainSymbol> objectClass() {
		return _Object;
	}

	public ref<PlainSymbol> arrayClass() {
		return _Array;
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
builtInMap.append(BuiltInMap(TypeFamily.VAR, "var"));
builtInMap.append(BuiltInMap(TypeFamily.STRING, "string"));
builtInMap.append(BuiltInMap(TypeFamily.STRING16, "string16"));
builtInMap.append(BuiltInMap(TypeFamily.SUBSTRING, "substring"));
builtInMap.append(BuiltInMap(TypeFamily.SUBSTRING16, "substring16"));
builtInMap.append(BuiltInMap(TypeFamily.BOOLEAN, "boolean"));
builtInMap.append(BuiltInMap(TypeFamily.CLASS_VARIABLE, "ClassInfo"));
builtInMap.append(BuiltInMap(TypeFamily.CLASS_DEFERRED, "*deferred*"));
builtInMap.append(BuiltInMap(TypeFamily.ARRAY_AGGREGATE, "Array"));
builtInMap.append(BuiltInMap(TypeFamily.OBJECT_AGGREGATE, "Object"));
builtInMap.append(BuiltInMap(TypeFamily.ADDRESS, "address"));
builtInMap.append(BuiltInMap(TypeFamily.EXCEPTION, "Exception"));
builtInMap.append(BuiltInMap(TypeFamily.NAMESPACE, "*Namespace*"));
