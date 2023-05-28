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

import native:C;
import parasol:context;
import parasol:exception.IllegalOperationException;
import parasol:memory;
import parasol:runtime;
import parasol:storage;
import parasol:text;
import parasol:thread;

int INDENT = 4;

public class CompileContext extends CodegenContext {
	public Operator visibility;
	public boolean isStatic;
	public boolean isFinal;
	public ref<Node> annotations;
	public ref<Unit> definingFile;
	public ref<Target> target;
	public ref<PlainSymbol> compileTarget;		// Special 'compileTarget' variable that is used to
												// implement conditional compilation

	private ref<DomainForest> _forest;
	private ref<Scope> _root;
	private boolean _forestIsCreated;
	private ref<FlowContext> _flowContext;
	private ref<MemoryPool> _pool;
	private ref<runtime.Arena> _arena;
	private ref<Scope> _current;
	private boolean _logImports;
	private int _importedScopes;
	private ref<context.Package>[] _packages;	// Packages from which symbols may be imported
	private int _mappedScopes;
	private ref<Variable>[] _variables;
	private ref<PlainSymbol>[] _staticSymbols;	// Populated when assigning storage
	private ref<Node>[] _liveSymbols;			// Populated during fold actions with the set of live symbols that
												// need destructor calls and locks the need unlocked.
	private ref<Scope>[] _liveSymbolScopes;		// Populated during fold actions with the scopes of the live symbols
												// that need destructor calls and locks that need unlocked.
	private int _baseLiveSymbol;				// >= 0, index of first symbol live in this function.
	private ref<Type> _monitorClass;
	private ref<ParameterScope> _throwException;
	private ref<ParameterScope> _dispatchException;
	private ref<Type> _memoryAllocator;
	private ref<Type> _compilerType;
	private ref<InterfaceType>[] _interfaces;
	private ref<BuiltInType>[TypeFamily] _builtInType;
	private ref<OverloadInstance> _ref;
	private ref<OverloadInstance> _map;
	private ref<OverloadInstance> _vector;
	private ref<OverloadInstance> _enumVector;
	private ref<OverloadInstance> _pointer;
	private ref<PlainSymbol> _Object;
	private ref<PlainSymbol> _Array;
	private ref<thread.ThreadPool<boolean>> _workers;
	private boolean _workersAreCreated;

	public class FlowContext {
		private ref<FlowContext> _next;
		private ref<Node> _controller;
		private ref<Scope> _enclosing;			// This is the scope that encloses the flow statement
		
		public FlowContext(ref<Node> controller, ref<Scope> enclosing, ref<FlowContext> next) {
			_next = next;
			_controller = controller;
			_enclosing = enclosing;
		}

		public ref<FlowContext> next() {
			return _next;
		}

		public ref<Scope> enclosingJumpTargetScope() {
			switch (_controller.op()) {
			case	SWITCH:
			case	LOOP:
			case	FOR:
			case	SCOPED_FOR:
			case	WHILE:
			case	DO_WHILE:
				return _enclosing;

			default:
				if (_next != null)
					return _next.enclosingJumpTargetScope();
				else
					return null;
			}
			return null;
		}

		public ref<Scope> enclosingLoopScope() {
			switch (_controller.op()) {
			case	LOOP:
			case	FOR:
			case	SCOPED_FOR:
			case	WHILE:
			case	DO_WHILE:
				return _enclosing;

			default:
				if (_next != null)
					return _next.enclosingLoopScope();
				else
					return null;
			}
			return null;
		}

		public ref<Binary> enclosingSwitch() {
			if (_controller.op() == Operator.SWITCH)
				return ref<Binary>(_controller);
			else if (_next != null)
				return _next.enclosingSwitch();
			else
				return null;
		}

		public ref<Node> enclosingLoop() {
			switch (_controller.op()) {
			case	LOOP:
			case	FOR:
			case	SCOPED_FOR:
			case	WHILE:
			case	DO_WHILE:
				return _controller;

			default:
				if (_next != null)
					return _next.enclosingLoop();
				else
					return null;
			}
			return null;
		}
	}

	CompileContext(ref<runtime.Arena> arena, boolean verbose, boolean logImports) {
		super(verbose, memory.StartingHeap.PRODUCTION, null, null);
		init(arena, null, logImports);
	}

	CompileContext(ref<runtime.Arena> arena, ref<thread.ThreadPool<boolean>> workers, boolean verbose, memory.StartingHeap memoryHeap, string profilePath, string coveragePath, boolean logImports) {
		super(verbose, memoryHeap, profilePath, coveragePath);
		init(arena, workers, logImports);
	}

	CompileContext(ref<DomainForest> forest, ref<thread.ThreadPool<boolean>> workers) {
		super(false, memory.StartingHeap.PRODUCTION, null, null);
		_forest = forest;
		_pool = forest.pool();
		clearDeclarationModifiers();
	}

	private void init(ref<runtime.Arena> arena, ref<thread.ThreadPool<boolean>> workers, boolean logImports) {
		_logImports = logImports;
		_arena = arena;
		clearDeclarationModifiers();
		_forest = new DomainForest();
		_forestIsCreated = true;
		_pool = _forest.pool();
		TypeFamily tf;
		for (; tf < TypeFamily.BUILTIN_TYPES; tf = TypeFamily(int(tf) + 1))
			_builtInType.append(_pool.newBuiltInType(tf));
//		if (workers == null) {
//			workers = new thread.ThreadPool<boolean>(thread.cpuCount());
//			_workersAreCreated = true;
//		}
//		_workers = workers;
	}

	~CompileContext() {
		if (_workersAreCreated)
			delete _workers;
		if (_forestIsCreated)
			delete _forest;
	}

	public boolean loadRoot(boolean buildingCorePackage, ref<context.Package>... usedPackages) {
//		printf("buildingCorePackage=%s\n", string(buildingCorePackage));
		ref<context.Context> activeContext = _arena.activeContext();

		ref<context.Package> corePackage = activeContext.getPackage(context.PARASOL_CORE_PACKAGE_NAME);
		if (corePackage == null)
			throw IllegalOperationException("No package '" + context.PARASOL_CORE_PACKAGE_NAME + "' defined");
		if (!buildingCorePackage && !corePackage.open()) {
			printf("core package won't open\n");
			return false;
		}

		string rootFile = storage.constructPath(corePackage.directory(), "root.p");
		ref<Unit> f = _arena.defineUnit(rootFile, "");
		f.parse(this);
		ref<Block> treeRoot = f.tree().root();
		treeRoot.scope = _root = _arena.createRootScope(treeRoot, f);
//		buildScopes();
		if (treeRoot.countMessages() > 0) {
			_arena.printMessages();
			if (verbose())
				_arena.print();
			return false;
		}
		if (!buildingCorePackage)
			_packages.append(corePackage);
		_packages.append(usedPackages);
		return true;
	}

	public ref<Target> compile(string filename) {
		if (verbose())
			printf("compile(%s)\n", filename);

		if (!storage.exists(filename)) {
			printf("File '%s' does not exist\n", filename);
			return null;
		}
		string[] unitFilenames;

		// This will make the 'main file' unit[1]
		unitFilenames.append(filename);

		collectFilenames(storage.directory(filename), false, &unitFilenames);

		if (verbose()) {
			printf("compiling:\n");
			for (i in unitFilenames)
				printf("[%3i] %s\n", i, unitFilenames[i]);
		}
		boolean success = parseUnits(unitFilenames, "");
		// How do we force filename to be included, even if it has no namespace
		

		ref<Unit> mainFile = _arena.getUnit(1);

		if (!mainFile.hasNamespace())
			mainFile.buildScopes(this);
		if (verbose())
			printf("Top level scopes constructed\n");
/*
		_main = mainFile.scope();
 */
		if (success)
			return finishCompile(mainFile, null);
		else
			return null;
	}

	public ref<Target>, boolean compile(ref<Unit> source, boolean(ref<Node>,string) checkInOrder) {
		ref<Unit> outer = definingFile;
		boolean success = true;

		if (!_arena.defineUnit(source))
			return null, true;
			
		if (!source.parse(this))
			success = false;

		if (source.buildScopes(this)) {
			if (_logImports)
				printf("        Built scopes for %s\n", source.filename());
		}
		definingFile = outer;
		if (success)
			return finishCompile(source, checkInOrder);
		else
			return null, true;
	}

	public ref<Target> compilePackage(string[] unitFilenames, string packageDir) {
		if (parseUnits(unitFilenames, packageDir))
			return finishCompile(null, null);
		else
			return null;
	}

	private static void collectFilenames(string directory, boolean collectParasolSources, ref<string[]> unitFilenames) {
		storage.Directory d(directory);
		if (d.first()) { 
			do {
				// ignore hidden files.
				if (d.filename().startsWith("."))
					continue;
				string path = d.path();
				// recurse through directories, collecting sources there
				if (storage.isDirectory(path))
					collectFilenames(path, true, unitFilenames);
				else if (collectParasolSources && path.endsWith(".p"))
					unitFilenames.append(path);
			} while (d.next());
		}
	}

	private boolean parseUnits(string[] unitFilenames, string packageDir) {
		ref<Unit> outer = definingFile;
		boolean success = true;
//		printf("    %s parsing units\n", packageDir);
		for (i in unitFilenames) {
			ref<Unit> unit = _arena.defineUnit(unitFilenames[i], packageDir);
			// The unit name has already been seen, and parsed. Ignore this instance.
			if (unit.parsed())
				continue;

			if (!unit.parse(this)) {
//				printf("  parse FAIL    [%d] %s\n", i, unitFilenames[i]);
				success = false;
			}

//			printf("    %d about to build scope for unit %s\n", thread.currentThread().id(), unitFilenames[i]);
			if (unit.buildScopes(this)) {
				if (_logImports)
					printf("        Built scopes for %s\n", unitFilenames[i]);
			}
		}
//		printf("    %s parsed %d units\n", packageDir, unitFilenames.length());
		definingFile = outer;
		return success;
	}
	
	public ref<Target>, boolean finishCompile(ref<Unit> mainUnit, boolean(ref<Node>, string) checkInOrder) {
//		printf("finishCompile\n");
		buildScopes();
		resolveImports();
		if (!bindBuiltInSymbols())
			return null, true;
		
		checkForRPCs();
		if (verbose())
			printf("Initial compilation phases completed.\n");
//		printf("before assignTypes\n");
		assignTypes();
//		printf("after assignTypes\n");
		assignMethodMaps();
		for (;;) {
			boolean modified;
			for (int i = 0; i < _arena.scopes().length(); i++)
				modified |= (*_arena.scopes())[i].createPossibleImpliedDestructor(this);
			if (!modified)
				break;
		}
		for (int i = 0; i < _arena.scopes().length(); i++) {
			_current = (*_arena.scopes())[i];
			_current.configureDefaultConstructors(this);
		}
		
		for (int i = 0; i < _arena.scopes().length(); i++)
			(*_arena.scopes())[i].checkVariableStorage(this);
		boolean nodesOrdered = true;
		if (checkInOrder != null)
			nodesOrdered = checkInOrder(mainUnit.tree().root(), mainUnit.source());
		if (verbose())
			printf("Beginning code generation\n");
		return Target.generate(mainUnit, this), nodesOrdered;
	}
	
	public boolean populateNamespace(ref<Ternary> namespaceNode) {
		boolean success = true;
		for (i in _packages) {
			string[] units = _packages[i].getNamespaceUnits(namespaceNode, this);
			string directory = _packages[i].directory();
			for (j in units) {
//				printf("        %s / %s\n", directory, units[j]);
				string filename = storage.constructPath(directory, units[j]);
				ref<Unit> unit = _arena.defineImportedUnit(filename, directory);
				// The unit name has already been seen, and parsed. Ignore this instance.
				if (unit.parsed())
					continue;

				if (!unit.parse(this)) {
					printf("  parse FAIL    [%d] %s\n", j, filename);
					success = false;
				}

				if (unit.buildScopes(this)) {
					if (_logImports)
						printf("        Built scopes for imported unit %s\n", filename);
				}
			}
		}
		return success;
	}

	public void resolveImports() {
//		printf("preps done\n");
		while (_importedScopes < _arena.scopes().length()) {
			ref<Scope> s = (*_arena.scopes())[_importedScopes];
			_importedScopes++;
//			printf(" --- defineImports %d/%d\n", importedScopes, _arena.scopes().length());
			if (s.definition() != null &&
				s.storageClass() != StorageClass.TEMPLATE_INSTANCE)
				s.definition().traverse(Node.Traversal.PRE_ORDER, defineImports, this);
		}
//		printf("Lookups done\n");
	}

	public boolean bindBuiltInSymbols() {
		ref<Symbol> sym = _root.lookup("ref", this);
		if (sym == null) {
			missingRootSymbol("ref");
			return false;
		}
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_ref = (*o.instances())[0];
		}
		sym = _root.lookup("pointer", this);
		if (sym == null) {
			missingRootSymbol("pointer");
			return false;
		}
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_pointer = (*o.instances())[0];
		}
		sym = _root.lookup("vector", this);
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
		sym = _root.lookup("map", this);
		if (sym == null) {
			missingRootSymbol("map");
			return false;
		}
		if (sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			_map = (*o.instances())[0];
		}
		sym = _root.lookup("Object", this);
		if (sym == null) {
			missingRootSymbol("Object");
			return false;
		}
		if (sym.class == PlainSymbol)
			_Object = ref<PlainSymbol>(sym);
		sym = _root.lookup("Array", this);
		if (sym == null) {
			missingRootSymbol("Array");
			return false;
		}
		if (sym.class == PlainSymbol)
			_Array = ref<PlainSymbol>(sym);

		boolean allDefined = true;
		for (int i = 0; i < builtInMap.length(); i++) {
			ref<Symbol> sym = _root.lookup(builtInMap[i].name, this);
			if (sym != null)
				_builtInType[builtInMap[i].family] = sym.bindBuiltInType(builtInMap[i].family, this);
			if (_builtInType[builtInMap[i].family] == null) {
				missingRootSymbol(builtInMap[i].name);
				allDefined = false;
			}
		}
		return allDefined;
	}

	private void missingRootSymbol(string name) {
		_root.definition().add(MessageId.UNDEFINED_BUILT_IN, _pool, name);
	}

	public void assignMethodMaps() {
		for (int i = _mappedScopes; i < _arena.scopes().length(); i++) {
			ref<Scope> scope = (*_arena.scopes())[i];
			scope.checkForDuplicateMethods(this);
			scope.assignMethodMaps(this);
			scope.createPossibleDefaultConstructor(this);
		}
		_mappedScopes = _arena.scopes().length();
	}

	private static TraverseAction defineImports(ref<Node> n, address data) {
		ref<CompileContext> context = ref<CompileContext>(data);
		if (n.op() == Operator.IMPORT) {
			if (!n.deferAnalysis())
				ref<Import>(n).lookupImport(context);
			return TraverseAction.SKIP_CHILDREN;
		}
		return TraverseAction.CONTINUE_TRAVERSAL;
	}

	public void buildScopes() {
		while (_arena.builtScopes < _arena.scopes().length()) {
			ref<Scope> s = (*_arena.scopes())[_arena.builtScopes];
//			s.print(0, false);
			_arena.builtScopes++;

			string label;
/*
			if (s.definition() != null) {
				printf("op = %d max = %d\n", int(s.definition().op()), int(Operator.MAX_OPERATOR));
				label = string(s.definition().op());
				printf("label is %p\n", *ref<address>(&label));
				text.memDump(*ref<address>(&label), 16);
				if (s.definition().op() == Operator.CLASS) {
					ref<ClassDeclarator> c = ref<ClassDeclarator>(s.definition());
					if (c.name() != null) {
						label.printf(" %s", c.name().identifier());
					}
				}
			} else
				label = "<null>";
			printf(" --- buildScopes %d/%d %s\n", _arena.builtScopes, _arena.scopes().length(), label);
*/

 	 	 	clearDeclarationModifiers();

//			printf("s = %p %s\n", s, string(s.storageClass()));
			if (s.definition() != null &&
				s.storageClass() != StorageClass.TEMPLATE_INSTANCE) {
				buildUnderScope(s);
			}
		}
		annotations = null;
	}
	
	public void exemptScopes() {
		_arena.builtScopes = _arena.scopes().length();
	}

	private void buildUnderScope(ref<Scope> s) {
		ref<Node> definition = s.definition();
		ref<Scope> outer = _current;
		_current = s;
		switch (definition.op()) {
		case	FUNCTION:
			ref<FunctionDeclaration> func = ref<FunctionDeclaration>(definition);
			boolean outer = isStatic;
			boolean outerFinal = isFinal;
			isStatic = false;
			isFinal = false;
			for (ref<NodeList> nl = func.arguments(); nl != null; nl = nl.next) {
				buildScopesInTree(nl.node);
			}
			isFinal = outerFinal;
			isStatic = outer;
			if (func.body != null)
				buildScopesInTree(func.body);
			break;

		case	LOCK:
			ref<Lock> k = ref<Lock>(definition);
			buildScopesInTree(k.body());
			break;

		case	ENUM:
		case	BLOCK:
		case	CLASS:
		case	MONITOR_CLASS:
			ref<Block> b = ref<Block>(definition);
			for (ref<NodeList> nl = b.statements(); nl != null; nl = nl.next) {
				// Reset these state conditions accumulated from the traversal so far.
				clearDeclarationModifiers();
				buildScopesInTree(nl.node);
			}
			break;
			
		case	UNIT:
			b = ref<Block>(definition);
			for (ref<NodeList> nl = b.statements(); nl != null; nl = nl.next) {
				// Reset these state conditions accumulated from the traversal so far.
				isStatic = false;
				isFinal = false;
				clearDeclarationModifiers();
				buildScopesInTree(nl.node);
			}
			break;
		
		case	FLAGS:
			b = ref<Block>(definition);
			ref<NodeList> nl = b.statements();
			bindFlags(nl.node);
			break;
			
		case	TEMPLATE:
			ref<Template> t = ref<Template>(definition);
			for (ref<NodeList> nl = t.templateParameters(); nl != null; nl = nl.next)
				buildScopesInTree(nl.node);
			buildScopesInTree(t.classDef);
			break;

		case	SCOPED_FOR:
			ref<For> f = ref<For>(definition);
			buildScopesInTree(f.initializer());
			buildScopesInTree(f.test());
			buildScopesInTree(f.increment());
			buildScopesInTree(f.body());
			break;

		case	CATCH:
			ref<Ternary> tern = ref<Ternary>(definition);
			buildScopesInTree(tern.left());
			// Note: middle is always IDENTIFIER so no new scopes.
			buildScopesInTree(tern.right());
			break;

		case	LOOP:
			ref<Loop> loop = ref<Loop>(definition);
			buildScopesInTree(loop.aggregate());
			buildScopesInTree(loop.body());
			break;

		default:
			definition.print(0);
			assert(false);
			definition.add(MessageId.UNFINISHED_BUILD_SCOPE, _pool, "  "/*definition.class.name()*/, string(definition.op()));
			definition.type = errorType();
		}
		_current = outer;
	}

	private void clearDeclarationModifiers() {
		isStatic = false;
		isFinal = false;
		visibility = Operator.NAMESPACE;
		annotations = null;
	}
	
	private void buildScopesInTree(ref<Node> n) {
		n.traverse(Node.Traversal.PRE_ORDER, buildScopeInTree, this);
		// TODO: Add nested functions so this can be:
//		n.traverse(Node.Traversal.PRE_ORDER, TraverseAction (ref<Node> n) {
//				return buildScopes(n);
//			});
	}

	private static TraverseAction buildScopeInTree(ref<Node> n, address data) {
//		printf(">>>buildScope(%p %s,...)\n", n, string(n.op()));
		ref<CompileContext> context = ref<CompileContext>(data);
		TraverseAction t = context.buildScopes(n);
//		printf("<<<buildScope(%p %s,...)\n", n, string(n.op()));
		return t;
	}

	public TraverseAction buildScopes(ref<Node> n) {
		if (n.deferAnalysis())
			return TraverseAction.SKIP_CHILDREN;
		n.type = null;
		switch (n.op()) {
		case	ABSTRACT:
		case	ADD:
		case	ADD_ASSIGN:
		case	ADD_REDUCE:
		case	ADDRESS:
		case	AND:
		case	AND_ASSIGN:
		case	ANNOTATION:
		case	ARRAY_AGGREGATE:
		case	ASSIGN:
		case	BIT_COMPLEMENT:
		case	BREAK:
		case	BYTES:
		case	CALL_DESTRUCTOR:
		case	CASE:
		case	CAST:
		case	CHARACTER:
		case	CLASS_TYPE:
		case	CLASS_OF:
		case	CONDITIONAL:
		case	CONTINUE:
		case	DECLARE_NAMESPACE:
		case	DECREMENT_AFTER:
		case	DECREMENT_BEFORE:
		case	DEFAULT:
		case	DELETE:
		case	DIVIDE:
		case	DIVIDE_ASSIGN:
		case	DO_WHILE:
		case	DOT:
		case	DOT_DOT:
		case	ELLIPSIS:
		case	EMPTY:
		case	EQUALITY:
		case	EXCLUSIVE_OR:
		case	EXCLUSIVE_OR_ASSIGN:
		case	EXPRESSION:
		case	FALSE:
		case	FLOATING_POINT:
		case	FOR:
		case	GREATER:
		case	GREATER_EQUAL:
		case	IDENTIFIER:
		case	IDENTITY:
		case	IF:
		case	INCREMENT_AFTER:
		case	INCREMENT_BEFORE:
		case	INDIRECT:
		case	INITIALIZE:
		case	INTEGER:
		case	INTERNAL_LITERAL:
		case	LABEL:
		case	LEFT_SHIFT:
		case	LEFT_SHIFT_ASSIGN:
		case	LESS:
		case	LESS_EQUAL:
		case	LESS_GREATER:
		case	LESS_GREATER_EQUAL:
		case	LOGICAL_AND:
		case	LOGICAL_OR:
		case	MAP:
		case	MULTIPLY:
		case	MULTIPLY_ASSIGN:
		case	NAMESPACE:
		case	NEGATE:
		case	NEW:
		case	NOT:
		case	NOT_EQUAL:
		case	NOT_GREATER:
		case	NOT_GREATER_EQUAL:
		case	NOT_IDENTITY:
		case	NOT_LESS:
		case	NOT_LESS_EQUAL:
		case	NOT_LESS_GREATER:
		case	NOT_LESS_GREATER_EQUAL:
		case	NULL:
		case	OBJECT_AGGREGATE:
		case	OR:
		case	OR_ASSIGN:
		case	PLACEMENT_NEW:
		case	REMAINDER:
		case	REMAINDER_ASSIGN:
		case	RETURN:
		case	RIGHT_SHIFT:
		case	RIGHT_SHIFT_ASSIGN:
		case	SEQUENCE:
		case	STRING:
		case	SUBSCRIPT:
		case	SUBTRACT:
		case	SUBTRACT_ASSIGN:
		case	SUPER:
		case	SWITCH:
		case	SYNTAX_ERROR:
		case	TEMPLATE:
		case	TEMPLATE_INSTANCE:
		case	THIS:
		case	THROW:
		case	TRUE:
		case	TRY:
		case	UNARY_PLUS:
		case	UNSIGNED_RIGHT_SHIFT:
		case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
		case	UNWRAP_TYPEDEF:
		case	VECTOR_OF:
		case	WHILE:
		case	VACATE_ARGUMENT_REGISTERS:
		case	VARIABLE:
		case	VOID:
			break;

		case	STATIC:
			isStatic = true;
			break;

		case	FINAL:
			isFinal = true;
			break;

		case	PRIVATE:
		case	PROTECTED:
		case	PUBLIC:
			visibility = n.op();
			break;

		case	ANNOTATED:
			ref<Binary> b = ref<Binary>(n);
			annotations = b.left();
			break;
		
		case	IMPORT:
			ref<Import> i = ref<Import>(n);
			i.prepareImport(this);
			break;

		case	CALL:
			ref<Call> call = ref<Call>(n);
			for (ref<NodeList> nl = call.arguments(); nl != null; nl = nl.next) {
				switch (nl.node.op()) {
				case BIND:
				case FUNCTION:
					nl.node.register = 1;
				}
			}
			break;
			
		case	BIND:
			if (n.register == 1)
				n.register = 0;
			else {
				b = ref<Binary>(n);
				id = ref<Identifier>(b.right());
				id.bind(_current, b.left(), null, this);
			}
			break;

		case	LOCK:
			ref<Lock> k = ref<Lock>(n);
			k.scope = createLockScope(k);
			return TraverseAction.SKIP_CHILDREN;
			
		case	BLOCK:
			ref<Block> blk = ref<Block>(n);
			blk.scope = createScope(n, StorageClass.AUTO);
			return TraverseAction.SKIP_CHILDREN;

		case	SCOPED_FOR:
			ref<For> fr = ref<For>(n);
			fr.scope = createScope(n, StorageClass.AUTO);
			return TraverseAction.SKIP_CHILDREN;
			
		case	LOOP:
			ref<Loop> loop = ref<Loop>(n);
			loop.scope = createScope(n, StorageClass.AUTO);
			loop.declarator().bind(loop.scope, loop, null, this);
			return TraverseAction.SKIP_CHILDREN;
	
		case	CATCH:
			ref<Scope> s = createScope(n, StorageClass.AUTO);
			ref<Ternary> t = ref<Ternary>(n);
			ref<Identifier> id = ref<Identifier>(t.middle());
			id.bind(s, t.left(), null, this);
			return TraverseAction.SKIP_CHILDREN;
	
		case	ENUM:
			c = ref<ClassDeclarator>(n);
			id = c.className();
			ref<EnumScope> enumScope = createEnumScope(c, id);
			c.scope = enumScope;
			ref<Type> instanceType;
			if (isFinal)
				c.add(MessageId.UNEXPECTED_FINAL, _pool);
			if (id.bindEnumName(_current, c, this)) {
				enumScope.classType = enumScope.enumType = _pool.newEnumType(id.symbol(), c, enumScope);
				instanceType = _pool.newEnumInstanceType(enumScope);
				id.symbol().bindType(_pool.newTypedefType(TypeFamily.TYPEDEF, instanceType), this);
			} else
				instanceType = errorType();
			bindEnums(enumScope, instanceType, c.extendsClause());
			enumScope.enumType.instanceCount = enumScope.symbols().size();
			return TraverseAction.SKIP_CHILDREN;

		case	CLASS:
		case	MONITOR_CLASS:
			ref<ClassDeclarator> c = ref<ClassDeclarator>(n);
			ref<ClassScope> classScope = createClassScope(n, null);
			c.scope = classScope;
			classScope.classType = _pool.newClassType(c, isFinal, classScope);
			return TraverseAction.SKIP_CHILDREN;
		
		case	CLASS_DECLARATION:
			b = ref<Binary>(n);
			id = ref<Identifier>(b.left());
			if (b.right().op() == Operator.TEMPLATE) {
				ref<Template> t = ref<Template>(b.right());
				boolean isMonitor = t.classDef.op() == Operator.MONITOR_CLASS;
				id.bindTemplateOverload(visibility, isStatic, isFinal, annotations, _current, t, isMonitor, this);
			} else {
				ref<ClassDeclarator> c = ref<ClassDeclarator>(b.right());
				ref<ClassScope> classScope = createClassScope(c, id);
				c.scope = classScope;
				classScope.classType = _pool.newClassType(c, isFinal, classScope);
				id.bindClassName(_current, c, this);
			}
			return TraverseAction.SKIP_CHILDREN;

		case	INTERFACE_DECLARATION:
			b = ref<Binary>(n);
			id = ref<Identifier>(b.left());
			assert(b.right().op() == Operator.CLASS);
			c = ref<ClassDeclarator>(b.right());
			classScope = createClassScope(c, id);
			c.scope = classScope;
			ref<InterfaceType> iface = _pool.newInterfaceType(c, isFinal, classScope);
			classScope.classType = iface;
			_interfaces.append(iface);
			id.bindClassName(_current, c, this);
			return TraverseAction.SKIP_CHILDREN;
			
		case	FLAGS_DECLARATION:
			b = ref<Binary>(n);
			id = ref<Identifier>(b.left());
			id.bindFlagsName(_current, ref<Block>(b.right()), this);
			return TraverseAction.SKIP_CHILDREN;
			
		case	DECLARATION:
			b = ref<Binary>(n);
			bindDeclarators(b.left(), b.right());
			break;

		case	FUNCTION:
			if (n.register == 1) {
				n.register = 0;
				break;
			}
			ref<FunctionDeclaration> f = ref<FunctionDeclaration>(n);
			ParameterScope.Kind funcKind;
		
			ref<ParameterScope> functionScope = createParameterScope(f, ParameterScope.Kind.FUNCTION);
			if (f.name() != null) {
				switch (f.functionCategory()) {
				case	CONSTRUCTOR:
					if (isStatic) {
						f.add(MessageId.STATIC_DISALLOWED, _pool);
						f.type = errorType();
						break;
					}
					if (isFinal) {
						f.add(MessageId.UNEXPECTED_FINAL, _pool);
						f.type = errorType();
						break;
					}
					_current.defineConstructor(functionScope, _pool);
					functionScope.symbol = f.name().bindConstructor(visibility, _current, functionScope, this);
					break;

				case	DESTRUCTOR:
					if (isStatic) {
						f.add(MessageId.STATIC_DISALLOWED, _pool);
						f.type = errorType();
						break;
					}
					if (isFinal) {
						f.add(MessageId.UNEXPECTED_FINAL, _pool);
						f.type = errorType();
						break;
					}
					if (_current.defineDestructor(f, functionScope, _pool))
						f.name().bindDestructor(visibility, _current, functionScope, this);
					else
						f.name().add(MessageId.DUPLICATE_DESTRUCTOR, _pool);
					break;

				case	NORMAL:
					if (f.body == null)
						f.name().bind(_current, f, null, this);
					else {
						f.name().bindFunctionOverload(visibility, isStatic, isFinal, annotations, _current, functionScope, this);
						functionScope.symbol = ref<OverloadInstance>(f.name().symbol());
					}
					break;

				case	ABSTRACT:
					f.name().bindFunctionOverload(visibility, isStatic, isFinal, annotations, _current, functionScope, this);
					functionScope.symbol = ref<OverloadInstance>(f.name().symbol());
					break;

				default:
					f.add(MessageId.INTERNAL_ERROR, _pool);
				}
			}
			return TraverseAction.SKIP_CHILDREN;

		default:
			n.print(0);
			assert(false);
			n.add(MessageId.UNFINISHED_BUILD_SCOPE, _pool, /*n.class.name()*/"***", string(n.op()));
			n.type = errorType();
		}
		
		return TraverseAction.CONTINUE_TRAVERSAL;
	}

	public void checkForRPCs() {
		if (_forest.getSymbol("parasol", "rpc", this) != null) {
			for (i in _interfaces) {
				ref<InterfaceType> iface = _interfaces[i];
				_current = iface.scope();
				iface.makeRPCSymbols(this);
			}
		}
		_interfaces.clear();
	}

	public ref<Scope> createScope(ref<Node> n, StorageClass storageClass) {
		return _arena.createScope(_current, n, storageClass);
	}

	ref<ParameterScope> createParameterScope(ref<Node> n, ParameterScope.Kind kind) {
		return _arena.createParameterScope(_current, n, kind);
	}

	ref<ProxyMethodScope> createProxyMethodScope(ref<Scope> enclosing) {
		return _arena.createProxyMethodScope(enclosing);
	}

	public ref<ClassScope> createClassScope(ref<Node> n, ref<Identifier> className) {
		return _arena.createClassScope(_current, n, className);
	}

	public ref<EnumScope> createEnumScope(ref<Block> definition, ref<Identifier> className) {
		return _arena.createEnumScope(_current, definition, className);
	}

	public ref<FlagsScope> createFlagsScope(ref<Block> definition, ref<Identifier> className) {
		return _arena.createFlagsScope(_current, definition, className);
	}

	public ref<LockScope> createLockScope(ref<Lock> definition) {
		return _arena.createLockScope(_current, definition);
	}

	public ref<MonitorScope> createMonitorScope(ref<Node> definition, ref<Identifier> className) {
		return _arena.createMonitorScope(_current, definition, className);
	}

	void bindDeclarators(ref<Node> type, ref<Node> n) {
		switch (n.op()) {
		case	IDENTIFIER:
			ref<Identifier> id = ref<Identifier>(n);
			id.bind(_current, type, null, this);
			break;
						   
		case	INITIALIZE:
			ref<Binary> b = ref<Binary>(n);
			id = ref<Identifier>(b.left());
			id.bind(_current, type, b.right(), this);
			break;

		case	SEQUENCE:
			b = ref<Binary>(n);
			bindDeclarators(type, b.left());
			bindDeclarators(type, b.right());
			break;

		default:
			n.add(MessageId.UNFINISHED_BIND_DECLARATORS, _pool, "   "/*n.class.name()*/, string(n.op()));
			n.type = errorType();
		}
	}

	private void bindEnums(ref<Scope> instancesScope, ref<Type> instanceType, ref<Node> n) {
		switch (n.op()) {
		case SEQUENCE:
			ref<Binary> b = ref<Binary>(n);
			bindEnums(instancesScope, instanceType, b.left());
			bindEnums(instancesScope, instanceType, b.right());
			break;
			
		case	IDENTIFIER:
			ref<Identifier> id = ref<Identifier>(n);
			int offset = instancesScope.symbols().size();
			ref<Symbol> sym = id.bindEnumInstance(instancesScope, instanceType, null, this);
			if (sym != null)
				sym.offset = offset;
			break;

		case	CALL:
			ref<Call> c = ref<Call>(n);
			bindEnums(instancesScope, instanceType, c.target());
		}
	}

	void bindFlags(ref<Node> n) {
		switch (n.op()) {
		case SEQUENCE:
			ref<Binary> b = ref<Binary>(n);
			bindFlags(b.left());
			bindFlags(b.right());
			break;
			
		case	IDENTIFIER:
			ref<Identifier> id = ref<Identifier>(n);
			ref<FlagsScope> scope = ref<FlagsScope>(_current);
			long offset = long(1) << scope.symbols().size();
			ref<Symbol> sym = id.bindFlagsInstance(_current, scope.flagsType.wrappedType(), this);
			sym.offset = offset;
		}
	}

	public void assignTypes() {
		for (int i = 0; i < _arena.scopes().length(); i++) {
			_current = (*_arena.scopes())[i];

			if (_current.definition() == null)
				continue;
			switch (_current.definition().op()) {
			case UNIT:
				assignTypeToNode(_current.definition());
				_current.checkDefaultConstructorCalls(this);
				break;
				
			case FUNCTION:
				assignTypeToNode(_current.definition());
			}
		}
/*
		printf("Before computing reference closure\n");
		for (int i = 0; i < _arena.scopes().length(); i++) {
			_current = (*_arena.scopes())[i];

			_current.printStatus();
		}
 */
		boolean modified;
		do {
			modified = false;
			for (int i = 0; i < _arena.scopes().length(); i++) {
				_current = (*_arena.scopes())[i];
				
				if (_current.definition() != null && 
					_current.definition().op() == Operator.FUNCTION) {
					ref<FunctionDeclaration> func = ref<FunctionDeclaration>(_current.definition());
					if (func.type == null)
						assignTypeToNode(func);
					if ((func.referenced || !_current.isTemplateFunction()) && func.body != null && func.body.type == null) {
						modified = true;
						assignTypes(func.body);
						_current.checkDefaultConstructorCalls(this);
					}
				}
			}
		} while (modified);
/*
		printf("Before assigning control flow\n");
		for (int i = 0; i < _arena.scopes().length(); i++) {
			_current = (*_arena.scopes())[i];

			printf("[%d] ", i);
			_current.printStatus();
		}
 */
		for (int i = 0; i < _arena.scopes().length(); i++) {
			_current = (*_arena.scopes())[i];
			if (_current.definition() != null) {
//				printf("[%d] ", i);
//				_current.printStatus();
				switch (_current.definition().op()) {
				case	FUNCTION:
					if (_current.definition().class != FunctionDeclaration) {
						printf("not FunctionDeclaration class\n");
						break;
					}
					ref<FunctionDeclaration> f = ref<FunctionDeclaration>(_current.definition());
					if (f.body != null && f.body.type != null)
						assignControlFlow(f.body, _current);
					break;

				case UNIT:
					assignControlFlow(_current.definition(), _current);
				}
			}
		}
 	}

	public void assignTypes(ref<Scope> scope, ref<Node> n) {
		ref<Scope> outer = _current;
		_current = scope;
		assignTypeToNode(n);
		_current = outer;
	}

	public void assignTypes(ref<Node> n) {
		if (!n.assignTypesBoundary())
			assignTypeToNode(n);
	}

	public void assignDeclarationTypes(ref<Scope> scope, ref<Node> n) {
		if (n.type == null) {
			ref<Scope> outer = _current;
			_current = scope;
			n.assignDeclarationTypes(this);
			_current = outer;
		}
	}

	public void assignTypeToNode(ref<Node> n) {
		if (n.type == null) {
			if (verbose()) {
				printf("-----  assignTypes %s ---------\n", _current != null ? _current.sourceLocation(n.location()) : "<null>");
			}
			n.assignTypes(this);
			if (n.type == null) {
				n.add(MessageId.NO_EXPRESSION_TYPE, _pool);
				n.type = errorType();
				n.print(0);
				assert(false);
			}
			if (verbose()) {
				n.print(4);
				printf("=====  assignTypes %s =========\n", _current != null ? _current.sourceLocation(n.location()) : "<null>");
			}
		}
	}
	
	public void assignControlFlow(ref<Node> n, ref<Scope> scope) {
		switch (n.op()) {
		case	LOCK:
			ref<Lock> k = ref<Lock>(n);
			if (k.scope != null)
				scope = k.scope;
			assignControlFlow(k.lockReference(), scope);
			assignControlFlow(k.body(), scope);
			break;

		case	UNIT:
		case	BLOCK:
			ref<Block> block = ref<Block>(n);
			if (block.scope != null)
				scope = block.scope;
			for (ref<NodeList> nl = block.statements(); nl != null; nl = nl.next)
				assignControlFlow(nl.node, scope);
			break;

		case	IF:
			ref<Ternary> t = ref<Ternary>(n);
			assignControlFlow(t.middle(), scope);
			assignControlFlow(t.right(), scope);
			break;

		case	ANNOTATED:
			ref<Binary> b = ref<Binary>(n);
			assignControlFlow(b.right(), scope);
			break;
			
		case	WHILE:
		case	SWITCH:
			b = ref<Binary>(n);
			{
				FlowContext flowContext(b, scope, _flowContext);
				pushFlowContext(&flowContext);
				assignControlFlow(b.right(), scope);
				popFlowContext();
			}
			break;

		case	DO_WHILE:
			b = ref<Binary>(n);
			{
				FlowContext flowContext(b, scope, _flowContext);
				pushFlowContext(&flowContext);
				assignControlFlow(b.left(), scope);
				popFlowContext();
			}
			break;

		case	CASE:
			b = ref<Binary>(n);
			assignControlFlow(b.right(), scope);
			ref<Binary> swit = enclosingSwitch();
			if (swit == null) {
				b.add(MessageId.INVALID_CASE, _pool);
				b.left().type = errorType();
				break;
			}
			if (swit.left().deferAnalysis()) {
				b.left().type = swit.left().type;
				break;
			}
			ref<Type> switchType = swit.left().type;
			if (switchType == null)
				swit.print(0);
			switch (switchType.family()) {
			case ENUM:
				if (b.left().op() != Operator.IDENTIFIER) {
					b.left().add(MessageId.NOT_ENUM_INSTANCE, _pool);
					b.left().type = errorType();
					break;
				}
				ref<Identifier> id = ref<Identifier>(b.left());
				id.resolveAsEnum(ref<EnumInstanceType>(switchType), this);
				break;
				
			case STRING:
			case STRING16:
			case SUBSTRING:
			case SUBSTRING16:
				if (b.left().op() == Operator.STRING) 
					b.left().type = switchType;
				else {
					b.left().add(MessageId.STRING_LITERAL_EXPECTED, _pool);
					b.left().type = errorType();
				}
				break;
				
			default:
				assignTypes(ref<Block>(swit.right()).scope, b.left());
				if (b.left().deferAnalysis())
					break;
				b.assignCaseExpression(switchType, this);
			}
			break;

		case	DEFAULT:
			swit = enclosingSwitch();
			if (swit == null) {
				n.add(MessageId.INVALID_DEFAULT, _pool);
				n.type = errorType();
				break;
			}
			ref<Unary> u = ref<Unary>(n);
			assignControlFlow(u.operand(), scope);
			break;

		case	SCOPED_FOR:
		case	FOR:
			ref<For> f = ref<For>(n);
			{
				FlowContext flowContext(f, scope, _flowContext);
				pushFlowContext(&flowContext);
				if (n.op() == Operator.SCOPED_FOR)
					scope = f.scope;
				assignControlFlow(f.body(), scope);
				popFlowContext();
			}
			break;

		case LOOP:
			ref<Loop> loop = ref<Loop>(n);
			{
				FlowContext flowContext(loop, scope, _flowContext);
				pushFlowContext(&flowContext);
				scope = loop.scope;
				assignControlFlow(loop.body(), scope);
				popFlowContext();
			}
			break;

		case TRY:
			ref<Try> tr = ref<Try>(n);
			assignControlFlow(tr.body(), scope);
			if (tr.finallyClause() != null)
				assignControlFlow(tr.finallyClause(), scope);
			for (ref<NodeList> nl = tr.catchList(); nl != null; nl = nl.next)
				assignControlFlow(nl.node, scope);
			break;
			
		case	CATCH:
			t = ref<Ternary>(n);
			assignControlFlow(t.right(), scope);
			break;
			
		case	ABSTRACT:
		case	INTERFACE_DECLARATION:
		case	CLASS_DECLARATION:
		case	ENUM:
		case	FLAGS_DECLARATION:
		case	MONITOR_CLASS:
		case	DECLARATION:
		case	DECLARE_NAMESPACE:
		case	EXPRESSION:
		case	RETURN:
		case	EMPTY:
		case	FUNCTION:
		case	IMPORT:
		case	PUBLIC:
		case	PRIVATE:
		case	PROTECTED:					// comes up in error scenarios (seen in a mismatched curly brace)
		case	FINAL:
		case	STATIC:
		case	THROW:
			break;

		case	BREAK:
			if (enclosingSwitch() == null &&
				enclosingLoop() == null) {
				n.add(MessageId.INVALID_BREAK, _pool);
				break;
			}
			ref<Jump> j = ref<Jump>(n);
			j.assignJumpScopes(enclosingJumpTargetScope(), scope);
			break;

		case	CONTINUE:
			if (enclosingLoop() == null) {
				n.add(MessageId.INVALID_CONTINUE, _pool);
				break;
			}
			j = ref<Jump>(n);
			j.assignJumpScopes(enclosingLoopScope(), scope);
			break;

		case	SYNTAX_ERROR:
			break;

		default:
			n.print(0);
			assert(false);
			n.add(MessageId.UNFINISHED_CONTROL_FLOW, _pool, "  "/*n.class.name()*/, string(n.op()));
			n.type = errorType();
		}
	}

	public ref<Node> fold(ref<Node> node, ref<Unit> unit) {
		int outerBaseLive = _baseLiveSymbol;
		_baseLiveSymbol = _liveSymbols.length();
//		printf("Folding:\n");
//		node.print(0);
		ref<Node> n = node.fold(unit.tree(), false, this);
		_liveSymbols.resize(_baseLiveSymbol);
		_liveSymbolScopes.resize(_baseLiveSymbol);
		_baseLiveSymbol = outerBaseLive;
		return n;
	}
	
	public ref<ParameterScope> dispatchExceptionScope() {
		if (_dispatchException == null) {
			ref<Symbol> re = _forest.getSymbol("parasol", "exception.dispatchException", this);
			if (re == null || re.class != Overload)
				assert(false);
			ref<Overload> o = ref<Overload>(re);
			if ((*o.instances()).length() == 0)
				assert(false);
			ref<Type> tp = (*o.instances())[0].assignType(this);
			_dispatchException = ref<ParameterScope>(tp.scope());
		}
		return _dispatchException;
	}

	public ref<ParameterScope> throwExceptionScope() {
		if (_throwException == null) {
			ref<Symbol> re = _forest.getSymbol("parasol", "exception.throwException", this);
			if (re != null && re.class == Overload) {
				ref<Overload> o = ref<Overload>(re);
				ref<Type> tp = (*o.instances())[0].assignType(this);
				_throwException = ref<ParameterScope>(tp.scope());
			}
		}
		return _throwException;
	}

	public ref<Type> memoryAllocatorType() {
		if (_memoryAllocator == null) {
			ref<Symbol> sym = _forest.getSymbol("parasol", "memory.Allocator", this);
			if (sym.assignType(this).family() != TypeFamily.TYPEDEF)
				assert(false);
			_memoryAllocator = ref<TypedefType>(sym.type()).wrappedType();
		}
		return _memoryAllocator;
	}

	public ref<Type> compilerTypeType() {
		if (_compilerType == null) {
			ref<Symbol> sym = _forest.getSymbol("parasol", "compiler.Type", this);
			if (sym == null) {
				printf("    FAIL: Could not obtain symbol for compiler.Type\n");
				_forest.printSymbolTable();
				assert(false);
			}
			if (sym.assignType(this).family() != TypeFamily.TYPEDEF)
				assert(false);
			_compilerType = ref<TypedefType>(sym.type()).wrappedType();
		}
		return _compilerType;
	}

	public ref<ClassType> getClassType(string symbol) {
		ref<Symbol> sym = _forest.getSymbol("parasol", symbol, this);
		if (sym == null || sym.class != PlainSymbol)
			return null;
		ref<PlainSymbol> ps = ref<PlainSymbol>(sym);
		ref<Type> t = ps.assignType(this).wrappedType();
		if (t.class == ClassType)
			return ref<ClassType>(t);
		else
			return null;
	}

	public void sortUnitInitializationOrder(ref<ref<Unit>[]> units) {
		if (verbose()) {
			printf("sortUnitInitializationOrder:\n");
			printf("before:\n");
			for (i in *units)
				printf("    [%3d] %s\n", i, (*units)[i].filename());
			for (i in _packages) {
				printf("    %s @ %s first:\n", _packages[i].name(), _packages[i].directory());
				string[] u = _packages[i].initFirst();
				for (j in u)
					printf("        [%2d] %s\n", j, u[j]);
				printf("    %s last:\n", _packages[i].name());
				u = _packages[i].initLast();
				for (j in u)
					printf("        [%2d] %s\n", j, u[j]);
			}
		}
		int firstPackageIndex = -1;
		for (i in *units)
			if ((*units)[i].imported()) {
				firstPackageIndex = i;
				break;
			}
		if (firstPackageIndex == 0)
			return;

		int[string] unitMap;
		for (i in  *units)
			unitMap[(*units)[i].filename()] = i;
		for (i in _packages) {
			ref<context.Package> p = _packages[i];
			int nextPackageIndex;

			for (nextPackageIndex = firstPackageIndex; nextPackageIndex < units.length(); nextPackageIndex++)
				if (!(*units)[nextPackageIndex].filename().startsWith(p.directory()))
					break;

			if (verbose())
				printf("[%d] %s [%d - %d]\n", i, _packages[i].name(), firstPackageIndex, nextPackageIndex);

			// First, go through the init - first unit names to move them to the top of the
			// unit list (for the current package).
			string[] u = p.initFirst();

			for (j in u) {
				if (unitMap.contains(u[j])) {
					int where = unitMap[u[j]];
					if (where > firstPackageIndex) {
						ref<Unit> swap = (*units)[firstPackageIndex];
						unitMap[swap.filename()] = where;
						(*units)[firstPackageIndex] = (*units)[where];
						(*units)[where] = swap;
						unitMap[(*units)[firstPackageIndex].filename()] = firstPackageIndex;
						firstPackageIndex++;
					} else if (where == firstPackageIndex)
						firstPackageIndex++;
					else {
						(*units)[where].tree().root().add(MessageId.DUPLICATE_INIT_ENTRY, _pool);
					}
				}
			}
		
			u = p.initLast();

			int finalIndex = nextPackageIndex - 1;
			for (int j = u.length() - 1; j >= 0; j--) {
				if (unitMap.contains(u[j])) {
					int where = unitMap[u[j]];
					if (where >= firstPackageIndex && where < finalIndex) {
						ref<Unit> swap = (*units)[finalIndex];
						unitMap[swap.filename()] = where;
						(*units)[finalIndex] = (*units)[where];
						(*units)[where] = swap;
						unitMap[(*units)[finalIndex].filename()] = finalIndex;
						finalIndex--;
					} else if (where == finalIndex)
						finalIndex--;
					else
						(*units)[where].tree().root().add(MessageId.DUPLICATE_INIT_ENTRY, _pool);
				}
			}

			firstPackageIndex = nextPackageIndex;
		}
		if (verbose()) {
			printf("after:\n");
			for (i in *units)
				printf("    [%3d] %s\n", i, (*units)[i].filename());
		}
	}

	public void markLiveSymbol(ref<Node> n) {
		if (n == null || n.type == null)
			return;
		if (n.type.hasDestructor()) {
			if (n.op() == Operator.VARIABLE)
				for (i in _liveSymbols)
					assert(!n.conforms(_liveSymbols[i]));
			_liveSymbols.push(n);
			_liveSymbolScopes.push(_current);
		}
	}
	/**
	 * Remove a live symbol.
	 *
	 * In a multi-return the logic will assign out each returned value. For
	 * a string or string16 return value, the value is transferred without making a copy.
	 * So the live symbol entry must be removed.
	 *
	 * Note that the use of this function relies on the fact that the parameter node
	 * being 'removed' is a Reference and is unique to the current expression, no matter how
	 * many nested live symbol contexts are currently in the stack.
	 *
	 * @param n The node (a Reference) that will not need to be destroyed.
	 */
	public void unmarkLiveSymbol(ref<Node> n) {
		for (i in _liveSymbols) {
			if (n.conforms(_liveSymbols[i])) {
				_liveSymbols.remove(i);
				_liveSymbolScopes.remove(i);
			}
		}
	}

	public void markActiveLock(ref<Node> n) {
		if (n == null || n.type == null)
			return;
		_liveSymbols.push(n);
		_liveSymbolScopes.push(_current);
	}

	public int liveSymbolCount() {
		return _liveSymbols.length() - _baseLiveSymbol;
	}
	
	public ref<Node> getLiveSymbol(int index) {
		return _liveSymbols[index + _baseLiveSymbol];
	}
	
	public ref<Scope> getLiveSymbolScope(int index) {
		return _liveSymbolScopes[index + _baseLiveSymbol];
	}
	
	public ref<Node> popLiveSymbol(ref<Scope> scope) {
		if (_liveSymbols.length() <= _baseLiveSymbol)
			return null;
		ref<Node> result = _liveSymbols.peek();
		if (result.enclosing() == scope) {
			_liveSymbolScopes.pop();
			return _liveSymbols.pop();
		} else
			return null;
	}
	
	public ref<Node> popLiveTemp(int priorLength) {
		if (_liveSymbols.length() - _baseLiveSymbol <= priorLength)
			return null;
		if (_liveSymbols.peek().op() == Operator.VARIABLE) {
			_liveSymbolScopes.pop();
			return _liveSymbols.pop();
		} else
			return null;
	}
	
	public ref<Type> convertToAnyBuiltIn(ref<Type> t) {
		for (int i = 0; i < int(TypeFamily.BUILTIN_TYPES); i++) {
			ref<Type> b = _builtInType[TypeFamily(i)];
			if (b != null && b.equals(t))
				return b;
		}
		return t;
	}
	
	public ref<runtime.Arena> arena() { 
		return _arena; 
	}

	public StorageClass blockStorageClass() {
		if (_current == null)
			return StorageClass.STATIC;
		else if (_current.storageClass() == StorageClass.PARAMETER)
			return StorageClass.AUTO;
		else
			return _current.storageClass();
	}

	public void rememberStaticSymbol(ref<PlainSymbol> staticSymbol) {
		_staticSymbols.append(staticSymbol);
	}
	
	public ref<ref<PlainSymbol>[]> staticSymbols() {
		return &_staticSymbols;
	}
	
	public ref<Type> makeTypedef(ref<Type> underlyingType) {
		return _pool.newTypedefType(TypeFamily.TYPEDEF, underlyingType);
	}

	public ref<Type> errorType() {
		return builtInType(TypeFamily.ERROR);
	}

	ref<Scope> enclosingJumpTargetScope() {
		if (_flowContext == null)
			return null;
		return _flowContext.enclosingJumpTargetScope();
	}

	ref<Scope> enclosingLoopScope() {
		if (_flowContext == null)
			return null;
		return _flowContext.enclosingLoopScope();
	}

	ref<Binary> enclosingSwitch() {
		if (_flowContext == null)
			return null;
		return _flowContext.enclosingSwitch();
	}

	ref<Node> enclosingLoop() {
		if (_flowContext == null)
			return null;
		return _flowContext.enclosingLoop();
	}

	public void pushFlowContext(ref<FlowContext> context) {
		_flowContext = context;
	}

	public ref<FlowContext> flowContext() {
		return _flowContext;
	}

	public void popFlowContext() {
		_flowContext = _flowContext.next();
	}

	public ref<TemplateInstanceType> newTemplateInstanceType(ref<TemplateType> templateType, var[] args, ref<Template> concreteDefinition, ref<Unit> definingFile, ref<ClassScope> scope, ref<TemplateInstanceType> next) {
		ref<TemplateInstanceType> t = _pool.newTemplateInstanceType(templateType, args, concreteDefinition, definingFile, scope, next);
		_arena.declare(t);
		return t;
	}

	public ref<Variable> newVariable(ref<Type> type) {
		ref<Variable> v = _pool new Variable;
		v.type = type;
		v.enclosing = _current;
		_variables.append(v);
		return v;
	}

	public ref<Variable> newVariable(pointer<ref<Type>> returns, int returnCount) {
		ref<Variable> v = _pool new Variable;
		v.returns = returns;
		v.returnCount = returnCount;
		v.type = returns[0];
		v.enclosing = _current;
		_variables.append(v);
		return v;
	}
	
	public int variableCount() {
		return _variables.length();
	}
	
	public void resetVariables(int originalCount) {
		_variables.resize(originalCount);
	}
	
	public ref<ref<Variable>[]> variables() {
		return &_variables;
	}
	
	public ref<Scope> setCurrent(ref<Scope> scope) {
		assert(scope != null);
		ref<Scope> old = _current;
		_current = scope;
		return old;
	}
	
	public ref<Scope> current() {
		return _current;
	}

	public void printSymbolTable() {
		_arena.printSymbolTable();
		_forest.printSymbolTable();
	}

	public ref<Type> monitorClass() {
		if (_monitorClass == null) {
			ref<Symbol> m = _forest.getSymbol("parasol", "thread.Monitor", this);
			if (m == null || m.class != PlainSymbol) {
				printf("Couldn't find parasol:thread.Monitor\n");
				if (m != null)
					m.print(0, false);
				assert(false);
			} else {
				ref<Type> type = m.assignType(this);
				if (type.family() == TypeFamily.TYPEDEF) {		// if (type == TypedefType)
					ref<TypedefType> tp = ref<TypedefType>(type);
					_monitorClass = tp.wrappedType();
				} else {
					m.print(0, false);
					assert(false);
				}
			}
		}
		return _monitorClass;
	}

	boolean isLockable(ref<Type> type) {
		if (type.isLockable())
			return true;
		return type == monitorClass();
	}

	boolean isMonitor(ref<Type> type) {
		if (type.isMonitor())
			return true;
		return type == monitorClass();
	}
	
	public ref<BuiltInType> builtInType(TypeFamily family) {
		return _builtInType[family];
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

	public ref<Type> newRef(ref<Type> target) {
		if (_ref != null)
			return _ref.createAddressInstance(target, this);
		else
			return errorType();
	}

	public ref<Type> newPointer(ref<Type> target) {
		if (_pointer != null)
			return _pointer.createAddressInstance(target, this);
		else
			return errorType();
	}

	public ref<Type> newVectorType(ref<Type> element, ref<Type> index) {
		if (index == null)
			index = _builtInType[TypeFamily.SIGNED_32];
		else {
			switch (index.family()) {
			case	ENUM:
				return _enumVector.createVectorInstance(element, index, this);

			default:
				if (validMapIndex(index))
					return _map.createVectorInstance(element, index, this);
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
		return _vector.createVectorInstance(element, index, this);
	}

	public boolean validMapIndex(ref<Type> index) {
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
			if (index.compareMethod(this) == null)
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

	public ref<MemoryPool> pool() {
		return _pool;
	}
	
	public ref<DomainForest> forest() {
		return _forest;
	}

	public ref<Scope> root() {
		return _root;
	}

	public ref<SyntaxTree> tree() {
		return _current.unit().tree();
	}

	public boolean logImports() {
		return _logImports;
	}
}

public class MemoryPool extends memory.NoReleasePool {
	
	public MemoryPool() {
	}

	public ~MemoryPool() {
		clear();
	}
	
	public substring newCompileString(string s) {
		if (s == null)
			return substring(s);
		else {
			pointer<byte> data = pointer<byte>(alloc(s.length()));
			C.memcpy(data, &s[0], s.length());
			return substring(data, s.length());
		}
	}
	
	public substring newCompileString(substring s) {
		pointer<byte> data = pointer<byte>(alloc(s.length()));
		C.memcpy(data, s.c_str(), s.length());
		return substring(data, s.length());
	}
	
	public ref<Symbol> newPlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, substring name, ref<Node> source, ref<Node> type, ref<Node> initializer) {
		return super new PlainSymbol(visibility, storageClass, enclosing, annotations, this, name, source, type, initializer);
	}

	public ref<Symbol> newPlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, substring name, ref<Node> source, ref<Type> type, ref<Node> initializer) {
		return super new PlainSymbol(visibility, storageClass, enclosing, annotations, this, name, source, type, initializer);
	}

	public ref<Symbol> newDelegateSymbol(ref<Scope> enclosing, ref<PlainSymbol> delegate) {
		return super new DelegateSymbol(enclosing, delegate, this);
	}
	
	public ref<Overload> newOverload(ref<Scope> enclosing, substring name, Operator kind) {
		return super new Overload(enclosing, null, this, name, kind);
	}

	public ref<OverloadInstance> newOverloadInstance(ref<Overload> overload, Operator visibility, boolean isStatic, boolean isFinal, ref<Scope> enclosing, ref<Node> annotations, substring name, ref<Node> source, ref<ParameterScope> functionScope) {
		return super new OverloadInstance(overload, visibility, isStatic, isFinal, enclosing, annotations, this, name, source, functionScope);
	}

	public ref<OverloadInstance> newOverloadInstance(ref<Overload> overload, boolean isFinal, substring name, ref<Type> type, ref<ParameterScope> functionScope) {
		return super new OverloadInstance(overload, isFinal, this, name, type, functionScope);
	}

	public ref<OverloadInstance> newDelegateOverload(ref<Overload> overloadSym, ref<OverloadInstance> delegate) {
		return super new DelegateOverload(overloadSym, delegate, this);
	}
	
	public ref<ProxyOverload> newProxyOverload(ref<InterfaceType> interfaceType, ref<Overload> overload, ref<ParameterScope> functionScope) {
		return super new ProxyOverload(interfaceType, overload, this, functionScope);
	}

	public ref<StubOverload> newStubOverload(ref<InterfaceType> interfaceType, ref<Overload> overload, ref<ParameterScope> functionScope) {
		return super new StubOverload(interfaceType, overload, this, functionScope);
	}

	public ref<Namespace> newNamespace(string domain, ref<Node> namespaceNode, ref<Scope> enclosing, 
									ref<Node> annotations, substring name, ref<runtime.Arena> arena) {
		return super new Namespace(newCompileString(domain), namespaceNode, enclosing, annotations, name, arena, this);
	}

	public ref<Commentary> newCommentary(ref<Commentary> next, MessageId messageId, substring message) {
		return super new Commentary(next, messageId, message);
	}

	public ref<Type> newType(TypeFamily family) {
		return super new Type(family);
	}

	public ref<ClassType> newClassType(ref<ClassDeclarator> definition, boolean isFinal, ref<ClassScope> scope) {
		return super new ClassType(definition, isFinal, scope);
	}

	public ref<ClassType> newClassType(ref<Type> base, boolean isFinal, ref<ClassScope> scope) {
		return super new ClassType(base, isFinal, scope);
	}

	public ref<ClassType> newClassType(TypeFamily effectiveFamily, ref<Type> base, ref<ClassScope> scope) {
		return super new ClassType(effectiveFamily, base, scope);
	}

	public ref<InterfaceType> newInterfaceType(ref<ClassDeclarator> definition, boolean isFinal, ref<ClassScope> scope) {
		return super new InterfaceType(definition, isFinal, scope);
	}

	public ref<EnumType> newEnumType(ref<Symbol> symbol, ref<ClassDeclarator> definition, ref<EnumScope> scope) {
		return super new EnumType(symbol, definition, scope);
	}

	public ref<EnumInstanceType> newEnumInstanceType(ref<EnumScope> scope) {
		return super new EnumInstanceType(scope);
	}

	public ref<FlagsType> newFlagsType(ref<Block> definition, ref<Scope> scope, ref<FlagsInstanceType> flagsInstanceType) {
		return super new FlagsType(definition, scope, flagsInstanceType);
	}

	public ref<FlagsInstanceType> newFlagsInstanceType(ref<Symbol> symbol, ref<FlagsScope> scope, ref<ClassType> instanceClass) {
		return super new FlagsInstanceType(symbol, scope, instanceClass);
	}

	public ref<TemplateType> newTemplateType(ref<Symbol> symbol, ref<Template> definition, ref<Unit> definingFile,
						ref<Overload> overload, ref<ParameterScope> templateScope, boolean isMonitor) {
		return super new TemplateType(symbol, definition, definingFile, overload, templateScope, isMonitor);
	}

	public ref<BuiltInType> newBuiltInType(TypeFamily family) {
		return super new BuiltInType(family);
	}

	public ref<TypedefType> newTypedefType(TypeFamily family, ref<Type> wrappedType) {
		return super new TypedefType(family, wrappedType);
	}

	public ref<TemplateInstanceType> newTemplateInstanceType(ref<TemplateType> templateType, var[] args, ref<Template> concreteDefinition, ref<Unit> definingFile, ref<ClassScope> scope, ref<TemplateInstanceType> next) {
		return super new TemplateInstanceType(templateType, args, concreteDefinition, definingFile, scope, next, this);
	}

	public ref<FunctionType> newFunctionType(ref<Type>[] returnTypes, ref<ParameterScope> functionScope) {
		ref<ref<Symbol>[]> parameters = functionScope.parameters();
		int types = returnTypes.length() + parameters.length();
		pointer<ref<Type>> t = pointer<ref<Type>>(alloc(types * Type.bytes + (*parameters).length()));
		for (i in returnTypes)
			t[i] = returnTypes[i];
		pointer<ref<Type>> tPtr = t + returnTypes.length();
		for (i in *parameters) {
			ref<Symbol> sym = (*parameters)[i];
			tPtr[i] = sym.type();
		}
		return super new FunctionType(t, returnTypes.length(), functionScope);
	}
	/**
	 * This is a function type as one might encounter with a function object declaration. 
	 */
	public ref<FunctionType> newFunctionType(ref<Type>[] returnTypes, ref<Type>[] parameterTypes, boolean hasEllipsis) {
		int types = returnTypes.length() + parameterTypes.length();
		pointer<ref<Type>> t = pointer<ref<Type>>(alloc(types * Type.bytes + parameterTypes.length()));
		for (i in returnTypes)
			t[i] = returnTypes[i];
		pointer<ref<Type>> tPtr = t + returnTypes.length();
		for (i in parameterTypes)
			tPtr[i] = parameterTypes[i];
		return super new FunctionType(t, returnTypes.length(), parameterTypes.length(), hasEllipsis);
	}
}

private monitor class VolatileDomainForest {
	enum ManifestState {
		NOT_LOADED,
		LOADING,
		LOADED,
		FAILED
	}

	 protected ManifestState _manifestState;
}

/**
 * This class defines a Parasol global symbol table and is the core of the runtime support for
 * reflection. You can browse any defined symbol through this object. One is created for each Arena
 */
public class DomainForest extends VolatileDomainForest {
	private ref<Namespace> _anonymous;
	private MemoryPool _pool;
	private ref<Scope>[string] _domains;
	private string[] _initFirst;
	private string[] _initLast;
	private ref<Unit>[] _units;

	~DomainForest() {
//		printf("~DomainForest() %p\n", this);
		_units.deleteAll();
	}

	public ref<Scope> createDomain(string domain, ref<CompileContext> compileContext) {
		ref<Scope> s = _domains[domain];
		if (s == null) {
//			printf("Creating domain for '%s'\n", domain);
			ref<Namespace> nm;
			if (domain.length() == 0)
				nm = anonymous(compileContext);
			else
				nm = _pool.newNamespace(domain, null, null, null, null, null);
			s = nm.symbols();
			_domains[domain] = s;
		}
		return s;
	}

	public ref<Namespace> anonymous(ref<CompileContext> compileContext) {
		if (_anonymous == null)
			_anonymous = _pool.newNamespace(null, null, null, null, null, compileContext.arena());
		return _anonymous;
	}
	/**
	 * Retrieve a list of units that are members of the namespace referenced by the 
	 * function argument.
	 *
	 * @param namespaceNode A compiler namespace parse tree node containing the namespace
	 * that must be fetched.
	 *
	 * @return A list of zero of more filenames where the units assigned to that namespace
	 * can be found. If the length of the array is zero, this package does not contain
	 * any units in that namespace.
	 */
	public string[], boolean getNamespaceUnits(ref<context.Package> package, ref<Ternary> namespaceNode, ref<CompileContext> compileContext) {
		string[] a;

		if (!loadManifest(package, compileContext))
			return a, false;

		string domain;
		boolean result;
		
		(domain, result) = namespaceNode.left().dottedName();
//		string name;
			
//		if (namespaceNode.middle().op() == Operator.EMPTY)
//			(name, result) = namespaceNode.right().dottedName();
//		else
//			(name, result) = namespaceNode.middle().dottedName();
		ref<Scope> s = _domains.get(domain);
		if (s != null) {
//			printf("name %s:%s\n", domain, name);
			ref<Namespace> nm;
			ref<ref<Unit>[]> units;
			if (namespaceNode.middle().op() == Operator.EMPTY) {
				nm = namespaceNode.right().getNamespace(s, compileContext);
//				printf("    middle empty %p\n", nm);
			} else {
				nm = namespaceNode.middle().getNamespace(s, compileContext);
				if (nm != null) {
					ref<Symbol> sym = nm.findImport(namespaceNode, compileContext);
					if (sym != null && sym.class <= Namespace)
						nm = ref<Namespace>(sym);
				}
//				printf("    middle occupied %p\n", nm);
			}
			if (nm != null) {
//				nm.print(4, false);
				units = nm.includedUnits();
				for (i in *units)
					a.append((*units)[i].packageFilename());
			}
		}
		return a, true;
	}
	
	public boolean loadManifest(ref<context.Package> package, ref<CompileContext> compileContext) {
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
		string manifestFile = storage.constructPath(package.directory(), context.PACKAGE_MANIFEST);
		ref<Reader> r = storage.openTextFile(manifestFile);
		if (r != null) {
			ref<SyntaxTree> tree = new SyntaxTree();
			string domain;
			ref<Scope> currentScope;
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
					currentScope = createDomain(domain, compileContext);
					break;
	
				case 'N':
					nm = currentScope.defineNamespace(domain, null, _pool.newCompileString(line.substr(1)), &_pool, null, null);
					currentScope = nm.symbols();
					break;
	
				case 'U':
					string unitFilename = storage.constructPath(package.directory(), line.substr(1));
					ref<Unit> u = new Unit(unitFilename, package.directory());
					_units.append(u);
					nm.includeUnit(u);
					break;
	
				case 'X':
					currentScope = currentScope.enclosing();
					nm = currentScope.getNamespace();
					break;

				case 'F':
					unitFilename = storage.constructPath(package.directory(), line.substr(1));
					_initFirst.append(unitFilename);
					break;

				case 'L':
					unitFilename = storage.constructPath(package.directory(), line.substr(1));
					_initLast.append(unitFilename);
					break;

				default:
					printf("        FAILED: unexpected content in manifest for package %s: %s\n", package.name(), manifestFile);
					success = false;
				}
			}
			delete r;
		} else
			printf("        FAILED: to open manifest for package %s: %s\n", package.name(), manifestFile);
		lock (*this) {
			if (success) {
				_manifestState = ManifestState.LOADED;
				notifyAll();
//				for (domain in _domains) {
//					printf("Domain %s\n", domain);
//					_domains[domain].print(4, true);
//				}
				return true;
			} else {
				_manifestState = ManifestState.FAILED;
				notifyAll();
				return false;
			}
		}
	}
	/**
	 * Get a domain Scope from a provided name.
	 *
	 * @param domain The domain name.
	 *
	 * @return The Scope defined for the supplied domain, if any. If the domain name is not defined, the return value is null.
	 */
	public ref<Scope> getDomain(string domain) {
		return _domains.get(domain);
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

	public ref<Symbol> getImport(ref<Ternary> namespaceNode, ref<CompileContext> compileContext) {
		string domain;
		boolean result;
		
		(domain, result) = namespaceNode.left().dottedName();
		if (compileContext.logImports()) {
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

	public string[] initFirst() {
		return _initFirst;
	}

	public string[] initLast() {
		return _initLast;
	}

	public boolean generateManifest(string filename, string[] initFirst, string[] initLast) {
		ref<Writer> w = storage.createTextFile(filename);
		if (w == null) {
			printf("        FAIL: Couldn't create %s\n", filename);
			return false;
		}
		for (key in _domains) {
			ref<Scope> domain = _domains[key];
			if (domain.class != NamespaceScope)
				continue;
			ref<NamespaceScope> nm = ref<NamespaceScope>(domain);
			if (!nm.hasIncludedUnits())
				continue;
			w.printf("D%s\n", key);
			spewNamespaces(w, domain, 0);
		}
		for (i in initFirst)
			w.printf("F%s\n", initFirst[i]);
		for (i in initLast)
			w.printf("L%s\n", initLast[i]);
		delete w;
		return true;
	}

	private void spewNamespaces(ref<Writer> w, ref<Scope> enclosing, int chopPrefix) {
		ref<ref<Scope>[]> nms = enclosing.enclosed();
		for (i in *nms) {
			ref<Scope> nm_candidate = (*nms)[i];
			if (nm_candidate.class !<= NamespaceScope)
				continue;
			ref<NamespaceScope> nm = ref<NamespaceScope>(nm_candidate);
			if (!nm.hasIncludedUnits())
				continue;
			ref<Namespace> nameSpace = nm.getNamespace();
			string dottedName = nameSpace.dottedName();
			if (chopPrefix > 0)
				dottedName = dottedName.substr(chopPrefix);
			w.printf("N%s\n", dottedName);
			ref<ref<Unit>[]> units = nameSpace.includedUnits();
			for (j in *units)
				w.printf("U%s\n", (*units)[j].packageFilename());
			spewNamespaces(w, nm, chopPrefix + dottedName.length() + 1);
			w.printf("X\n");
		}
	}

	public boolean writeHeader(ref<Writer> header) {
		for (key in _domains)
			if (!_domains[key].writeHeader(header))
				return false;
		return true;
	}

	public void printSymbolTable() {
		for (key in _domains) {
			printf("\nDomain %s:\n", key);
			_domains[key].print(INDENT, true);
		}
	}

	public ref<MemoryPool> pool() {
		return &_pool;
	}
}

/**
 */
public class Unit {
	private string	_filename;
	private int _prefixLength;			// The portion of the filename that contains the package directory (including the trailing slash)
	private boolean _parsed;
	private boolean _imported;

	private ref<Namespace> _namespaceSymbol;
	private ref<Ternary> _namespaceNode;

	private ref<UnitScope> _scope;
	private ref<SyntaxTree> _tree;
	private boolean _scopesBuilt;
	private boolean _staticsInitialized;
	private string _source;
	private ref<Scanner> _scanner;

	public Unit(string f, string packageDir) {
		_filename = f;
		_prefixLength = packageDir.length() + 1;
	}

	public Unit(string f, string packageDir, boolean imported) {
		_filename = f;
		_prefixLength = packageDir.length() + 1;
		_imported = imported;
	}

	public Unit() {
	}

	~Unit() {
		delete _tree;
		delete _scanner;
	}
/*	
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
	*/
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

	public boolean parse(ref<CompileContext> compileContext) {
		if (_parsed)
			return false;
		_parsed = true;
		compileContext.definingFile = this;
		_tree = new SyntaxTree();
		_tree.parse(this, compileContext);
		for (ref<NodeList> nl = _tree.root().statements(); nl != null; nl = nl.next) {
			if (nl.node.op() == Operator.DECLARE_NAMESPACE) {
				if (_namespaceNode == null) {
					ref<Unary> u = ref<Unary>(nl.node);
					_namespaceNode = ref<Ternary>(u.operand());
				} else
					nl.node.add(MessageId.NON_UNIQUE_NAMESPACE, _tree.pool());
			}
		}
		return true;
	}
/*
	public void noNamespaceError(ref<CompileContext> compileContext) {
		_tree.root().add(MessageId.NO_NAMESPACE_DEFINED, compileContext.pool());
	}
*/
	public boolean matches(ref<Ternary> importNode) {
		if (_namespaceNode == null)
			return false;
		return _namespaceNode.namespaceConforms(importNode);
	}
 
	public boolean buildScopes(ref<CompileContext> compileContext) {
		if (_scopesBuilt)
			return false;
		_scopesBuilt = true;
		_scope = compileContext.arena().createUnitScope(compileContext.root(), _tree.root(), this);
//		printf("    %d createUnitScope returned\n", thread.currentThread().id());
		_tree.root().scope = _scope;
		compileContext.buildScopes();
		if (_namespaceNode != null) {
			string domain = _namespaceNode.left().dottedName();
			ref<Scope> domainScope = compileContext.forest().createDomain(domain, compileContext);
//			printf("    %d createDomain returned\n", thread.currentThread().id());

			_namespaceSymbol = _namespaceNode.middle().makeNamespaces(domainScope, domain, compileContext);
//			printf("    %d makeNamespaces returned\n", thread.currentThread().id());
			ref<Doclet> doclet = _tree.getDoclet(_namespaceNode);
			if (doclet != null) {
				if (_namespaceSymbol._doclet == null)
					_namespaceSymbol._doclet = doclet;
				else
					_namespaceNode.add(MessageId.REDUNDANT_DOCLET, compileContext.pool());
			}
			if (!_imported)
				_namespaceSymbol.includeUnit(this);
			_scope.mergeIntoNamespace(_namespaceSymbol, compileContext);
//			printf("    %d mergeIntoNamespace returned\n", thread.currentThread().id());
		} else
			_namespaceSymbol = compileContext.forest().anonymous(compileContext);

		return true;
	}

	public boolean collectStaticInitializers(ref<Target> target) {
		if (_staticsInitialized)
			return false;
		if (!_scopesBuilt)
			return false;
		target.declareStaticBlock(this);
		_staticsInitialized = true;
		return true;
	}
 
	public void clearStaticInitializers() {
		_staticsInitialized = false;
	}

	public string getNamespaceString() {
		if (_namespaceNode != null) {
			string domain;
			string name;
			boolean x;
			
			(domain, x) = _namespaceNode.left().dottedName();
			(name, x) = _namespaceNode.middle().dottedName();
			return domain + ":" + name;
		} else
			return "<anonymous>";
	}
/*
	public ref<SyntaxTree> swapTree(ref<SyntaxTree> replacement) {
		ref<SyntaxTree> original = _tree;
		_tree = replacement;
		return original;
	}
 */
	public ref<SyntaxTree> tree() {
		return _tree; 
	}

	public ref<Namespace> namespaceSymbol() {
		return _namespaceSymbol;
	}

	public boolean hasNamespace() { 
		return _namespaceNode != null; 
	}

	public ref<Ternary> namespaceNode() {
		return _namespaceNode;
	}
/*
	public string domain() {
		return _domain;
	}
*/
	public boolean parsed() {
		return _parsed;
	}

	public string filename() {
		return _filename; 
	}

	public string packageFilename() {
		if (_filename == null)
			return null;
		else
			return _filename.substr(_prefixLength);
	}

	public string source() {
		return _source;
	}

	public ref<UnitScope> scope() {
		return _scope;
	}

	public void printMessages(ref<TemplateInstanceType>[] instances) {
		if (_tree != null) {
			dumpMessages(this, _tree.root());
		}
		for (int j = 0; j < instances.length(); j++) {
			ref<TemplateInstanceType> instance = instances[j];
			if (instance.definingFile() == this) {
				if (instance.concreteDefinition().countMessages() > 0) {
					printf("Messages for %s:\n", instance.signature());
					dumpMessages(this, instance.concreteDefinition());
				}
			}
		}
	}

	public void allNodes(ref<TemplateInstanceType>[] instances, 
                         void(ref<Unit>, ref<Node>, ref<Commentary>, address) callback, address arg) {
		if (_tree != null) {
			allNodes(this, _tree.root(), callback, arg);
		}
		for (j in instances) {
			ref<TemplateInstanceType> instance = instances[j];
			if (instance.definingFile() == this) {
				if (instance.concreteDefinition().countMessages() > 0) {
					callback(null, ref<Node>(instance), null, arg); 
					allNodes(this, instance.concreteDefinition(), callback, arg);
				}
			}
		}
	}
	/*
	public boolean scopesBuilt() {
		return _scopesBuilt;
	}
*/
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

	public int countMessages() {
		if (_tree != null)
			return _tree.root().countMessages();
		else
			return 0;
	}

	public boolean imported() {
		return _imported;
	}

	public void printSymbolTable() {
	}

	public void print() {
		printf("%s %s\n", _parsed ? "parsed" : "      ", _filename);
	}
}

void dumpMessages(ref<Unit> file, ref<Node> n) {
	Message[] messages;
	n.getMessageList(&messages);
	if (messages.length() > 0) {
		for (int j = 0; j < messages.length(); j++) {
			ref<Commentary> comment = messages[j].commentary;
			file.dumpMessage(messages[j].node, comment);
		}
	}
}

void allNodes(ref<Unit> file, ref<Node> n, void(ref<Unit>, ref<Node>, ref<Commentary>, address) callback, address arg) {
	Message[] messages;
	n.getMessageList(&messages);
	if (messages.length() > 0) {
		for (j in messages) {
			callback(file, messages[j].node, messages[j].commentary, arg);
		}
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


