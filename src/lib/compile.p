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
import parasol:memory;

int INDENT = 4;

public class CompileContext {
	public Operator visibility;
	public boolean isStatic;
	public boolean isFinal;
	public ref<Node> annotations;
	public ref<FileStat> definingFile;
	public ref<Target> target;
	public ref<PlainSymbol> compileTarget;		// Special 'compileTarget' variable that is used to
												// implement conditional compilation

	private ref<FlowContext> _flowContext;
	private ref<MemoryPool> _pool;
	private ref<Arena> _arena;
	private ref<Scope> _current;
	private int _importedScopes;
	private ref<Variable>[] _variables;
	private ref<PlainSymbol>[] _staticSymbols;	// Populated when assigning storage
	private ref<Node>[] _liveSymbols;			// Populated during fold actions with the set of live symbols that
												// need destructor calls and locks the need unlocked.
	private ref<Scope>[] _liveSymbolScopes;		// Populated during fold actions with the scopes of the live symbols
												// that need destructor calls and locks that need unlocked.
	private int _baseLiveSymbol;				// >= 0, index of first symbol live in this function.
	private ref<Type> _monitorClass;
	private boolean _verbose;
	
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

	CompileContext(ref<Arena> arena, ref<MemoryPool> pool, boolean verbose) {
		_arena = arena;
		_pool = pool;
		_verbose = verbose;
		clearDeclarationModifiers();
	}
	/*
	 * Compile a parasol source file
	 * string.
	 */
	void compileFile() {
//		printf("before assignTypes\n");
		assignTypes();
//		printf("after assignTypes\n");
		for (int i = 0; i < _arena.scopes().length(); i++) {
			ref<Scope> scope = (*_arena.scopes())[i];
			scope.checkForDuplicateMethods(this);
			scope.assignMethodMaps(this);
			scope.createPossibleDefaultConstructor(this);
		}
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
			_arena.builtScopes++;
/*
			string label;
			if (s.definition() != null) {
				label = string(s.definition().op());
				if (s.definition().op() == Operator.CLASS) {
					ref<Class> c = ref<Class>(s.definition());
					if (c.name() != null) {
						label.printf(" %s", c.name().identifier().asString());
					}
				}
			} else
				label = "<null>";
			printf(" --- buildScopes %d/%d %s\n", _arena.builtScopes, _arena.scopes().length(), label);
 */
 	 	 	clearDeclarationModifiers();
			if (s.definition() != null &&
				s.storageClass() != StorageClass.TEMPLATE_INSTANCE)
				buildUnderScope(s);
		}
		annotations = null;
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
			t.type = _arena.builtInType(TypeFamily.VOID);
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
			definition.add(MessageId.UNFINISHED_BUILD_SCOPE, _pool, CompileString("  "/*definition.class.name()*/), CompileString(string(definition.op())));
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
			c = ref<Class>(n);
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
			ref<Class> c = ref<Class>(n);
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
				ref<Class> c = ref<Class>(b.right());
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
			c = ref<Class>(b.right());
			classScope = createClassScope(c, id);
			c.scope = classScope;
			classScope.classType = _pool.newInterfaceType(c, isFinal, classScope);
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
					f.name().bindConstructor(visibility, _current, functionScope, this);
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
					if (_current.defineDestructor(functionScope, _pool))
						f.name().bindDestructor(visibility, _current, functionScope, this);
					else
						f.name().add(MessageId.DUPLICATE_DESTRUCTOR, _pool);
					break;

				case	NORMAL:
					if (f.body == null)
						f.name().bind(_current, f, null, this);
					else
						f.name().bindFunctionOverload(visibility, isStatic, isFinal, annotations, _current, functionScope, this);
					break;

				case	ABSTRACT:
					f.name().bindFunctionOverload(visibility, isStatic, isFinal, annotations, _current, functionScope, this);
					break;

				default:
					f.add(MessageId.INTERNAL_ERROR, _pool);
				}
			}
			return TraverseAction.SKIP_CHILDREN;

		default:
			n.print(0);
			assert(false);
			n.add(MessageId.UNFINISHED_BUILD_SCOPE, _pool, CompileString(/*n.class.name()*/"***"), CompileString(string(n.op())));
			n.type = errorType();
		}
		
		return TraverseAction.CONTINUE_TRAVERSAL;
	}

	public ref<Scope> createScope(ref<Node> n, StorageClass storageClass) {
		return _arena.createScope(_current, n, storageClass);
	}

	ref<ParameterScope> createParameterScope(ref<Node> n, ParameterScope.Kind kind) {
		return _arena.createParameterScope(_current, n, kind);
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
			n.add(MessageId.UNFINISHED_BIND_DECLARATORS, _pool, CompileString("   "/*n.class.name()*/), CompileString(string(n.op())));
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
			int offset = 1 << scope.symbols().size();
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
			if (_verbose) {
				printf("-----  assignTypes %s ---------\n", _current != null ? _current.sourceLocation(n.location()) : "<null>");
			}
			n.assignTypes(this);
			if (n.type == null) {
				n.add(MessageId.NO_EXPRESSION_TYPE, _pool);
				n.type = errorType();
				n.print(0);
				assert(false);
			}
			if (_verbose) {
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
				if (b.left().op() != Operator.STRING) {
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
			n.add(MessageId.UNFINISHED_CONTROL_FLOW, _pool, CompileString("  "/*n.class.name()*/), CompileString(string(n.op())));
			n.type = errorType();
		}
	}

	public ref<Node> fold(ref<Node> node, ref<FileStat> file) {
		int outerBaseLive = _baseLiveSymbol;
		_baseLiveSymbol = _liveSymbols.length();
//		printf("Folding:\n");
//		node.print(0);
		ref<Node> n = node.fold(file.tree(), false, this);
		_liveSymbols.resize(_baseLiveSymbol);
		_liveSymbolScopes.resize(_baseLiveSymbol);
		_baseLiveSymbol = outerBaseLive;
		return n;
	}
	
	public void markLiveSymbol(ref<Node> n) {
		if (n == null || n.type == null)
			return;
//		printf("hasDestructor? %s\n", n.type.hasDestructor() ? "true" : "false");
//		n.print(4);
		if (n.type.hasDestructor()) {
			_liveSymbols.push(n);
			_liveSymbolScopes.push(_current);
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
			ref<Type> b = _arena.builtInType(TypeFamily(i));
			if (b != null && b.equals(t)) {
				return b;
			}
		}
		return t;
	}
	
	public ref<Arena> arena() { 
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
		return _arena.builtInType(TypeFamily.ERROR);
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

	public ref<TemplateInstanceType> newTemplateInstanceType(ref<TemplateType> templateType, var[] args, ref<Template> concreteDefinition, ref<FileStat> definingFile, ref<Scope> scope, ref<TemplateInstanceType> next) {
		ref<TemplateInstanceType> t = _pool.newTemplateInstanceType(templateType, args, concreteDefinition, definingFile, scope, next);
		_arena.declare(t);
		return t;
	}

	public ref<Variable> newVariable(ref<Type> type) {
		ref<Variable> v = new Variable;
		v.type = type;
		v.enclosing = _current;
		_variables.append(v);
		return v;
	}

	public ref<Variable> newVariable(ref<NodeList> returns) {
		ref<Variable> v = new Variable;
		v.returns = returns;
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

	public ref<Type> monitorClass() {
		if (_monitorClass == null) {
			ref<Symbol> m = _arena.getSymbol("parasol", "thread.Monitor", this);
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
	
	public ref<MemoryPool> pool() {
		return _pool;
	}
	
	public ref<SyntaxTree> tree() {
		return _current.file().tree();
	}

	boolean verbose() {
		return _verbose;
	}
}

public class MemoryPool extends memory.NoReleasePool {
	
	public MemoryPool() {
	}

	public ~MemoryPool() {
		clear();
	}
	
	public CompileString newCompileString(string s) {
		pointer<byte> data = pointer<byte>(alloc(s.length()));
		C.memcpy(data, &s[0], s.length());
		return CompileString(data, s.length());
	}
	
	public CompileString newCompileString(CompileString s) {
		pointer<byte> data = pointer<byte>(alloc(s.length));
		C.memcpy(data, s.data, s.length);
		return CompileString(data, s.length);
	}
	
	public ref<Symbol> newPlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<Node> type, ref<Node> initializer) {
		return super new PlainSymbol(visibility, storageClass, enclosing, annotations, this, name, source, type, initializer);
	}

	public ref<Symbol> newPlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<Type> type, ref<Node> initializer) {
		return super new PlainSymbol(visibility, storageClass, enclosing, annotations, this, name, source, type, initializer);
	}

	public ref<Symbol> newDelegateSymbol(ref<Scope> enclosing, ref<PlainSymbol> delegate) {
		return super new DelegateSymbol(enclosing, delegate, this);
	}
	
	public ref<Overload> newOverload(ref<Scope> enclosing, ref<CompileString> name, Operator kind) {
		return super new Overload(enclosing, null, this, name, kind);
	}

	public ref<OverloadInstance> newOverloadInstance(ref<Overload> overload, Operator visibility, boolean isStatic, boolean isFinal, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<ParameterScope> functionScope) {
		return super new OverloadInstance(overload, visibility, isStatic, isFinal, enclosing, annotations, this, name, source, functionScope);
	}

	public ref<OverloadInstance> newDelegateOverload(ref<Overload> overloadSym, ref<OverloadInstance> delegate) {
		return super new DelegateOverload(overloadSym, delegate, this);
	}
	
	public ref<Namespace> newNamespace(string domain, ref<Node> namespaceNode, ref<Scope> enclosing, 
									ref<Node> annotations, ref<CompileString> name, ref<Arena> arena) {
		return super new Namespace(domain, namespaceNode, enclosing, annotations, name, arena, this);
	}

	public ref<Commentary> newCommentary(ref<Commentary> next, MessageId messageId, string message) {
		return super new Commentary(next, messageId, message);
	}

	public ref<Type> newType(TypeFamily family) {
		return super new Type(family);
	}

	public ref<ClassType> newClassType(ref<Class> definition, boolean isFinal, ref<Scope> scope) {
		return super new ClassType(definition, isFinal, scope);
	}

	public ref<ClassType> newClassType(TypeFamily effectiveFamily, ref<Type> base, ref<Scope> scope) {
		return super new ClassType(effectiveFamily, base, scope);
	}

	public ref<InterfaceType> newInterfaceType(ref<Class> definition, boolean isFinal, ref<Scope> scope) {
		return super new InterfaceType(definition, isFinal, scope);
	}

	public ref<EnumType> newEnumType(ref<Symbol> symbol, ref<Class> definition, ref<EnumScope> scope) {
		return super new EnumType(symbol, definition, scope);
	}

	public ref<EnumInstanceType> newEnumInstanceType(ref<EnumScope> scope) {
		return super new EnumInstanceType(scope);
	}

	public ref<FlagsType> newFlagsType(ref<Block> definition, ref<Scope> scope, ref<Type> wrappedType) {
		return super new FlagsType(definition, scope, wrappedType);
	}

	public ref<FlagsInstanceType> newFlagsInstanceType(ref<Symbol> symbol, ref<Scope> scope, ref<ClassType> instanceClass) {
		return super new FlagsInstanceType(symbol, scope, instanceClass);
	}

	public ref<TemplateType> newTemplateType(ref<Symbol> symbol, ref<Template> definition, ref<FileStat> definingFile,
						ref<Overload> overload, ref<ParameterScope> templateScope, boolean isMonitor) {
		return super new TemplateType(symbol, definition, definingFile, overload, templateScope, isMonitor);
	}

	public ref<BuiltInType> newBuiltInType(TypeFamily family, ref<ClassType> classType) {
		return super new BuiltInType(family, classType);
	}

	public ref<TypedefType> newTypedefType(TypeFamily family, ref<Type> wrappedType) {
		return super new TypedefType(family, wrappedType);
	}

	public ref<TemplateInstanceType> newTemplateInstanceType(ref<TemplateType> templateType, var[] args, ref<Template> concreteDefinition, ref<FileStat> definingFile, ref<Scope> scope, ref<TemplateInstanceType> next) {
		return super new TemplateInstanceType(templateType, args, concreteDefinition, definingFile, scope, next, this);
	}

	public ref<FunctionType> newFunctionType(ref<NodeList> returnType, ref<NodeList> parameters, ref<Scope> functionScope) {
		return super new FunctionType(returnType, parameters, functionScope);
	}
}
