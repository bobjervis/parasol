namespace parasol:compiler;

int INDENT = 4;

class CompileContext {
	public Operator visibility;
	public boolean isStatic;
	public ref<Node> annotations;
	public ref<FileStat> definingFile;
	public ref<Target> target;

	private ref<FlowContext> _flowContext;
	private ref<MemoryPool> _pool;
	private ref<Arena> _arena;
	private ref<Scope> _current;
	private int _importedScopes;
	private ref<SyntaxTree> _tree;
	private ref<Variable>[] _variables;
	
	public class FlowContext {
		private ref<FlowContext> _next;
		private ref<Node> _controller;
		
		public FlowContext(ref<Node> controller, ref<FlowContext> next) {
			_next = next;
			_controller = controller;
		}

		public ref<FlowContext> next() {
			return _next;
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

	CompileContext(ref<Arena> arena, ref<MemoryPool> pool) {
		_arena = arena;
		_pool = pool;
		clearDeclarationModifiers();
	}
	/*
	 * Compile a parasol source file
	 * string.
	 */
	void compileFile() {
		_arena.cacheRootObjects(_arena.root());
		for (int i = 0; i < _arena.scopes().length(); i++)
			_arena.scopes()[i].assignMethodMaps(this);
//		printf("before assignTypes\n");
		assignTypes();
//		printf("after assignTypes\n");
		for (int i = 0; i < _arena.scopes().length(); i++) {
			_arena.scopes()[i].checkForDuplicateMethods(this);
			_arena.scopes()[i].assignMethodMaps(this);
		}
		for (int i = 0; i < _arena.scopes().length(); i++)
			_arena.scopes()[i].checkVariableStorage(this);
	}

	public void resolveImports() {
//		printf("preps done\n");
		while (_importedScopes < _arena.scopes().length()) {
			ref<Scope> s = _arena.scopes()[_importedScopes];
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
			ref<Scope> s = _arena.scopes()[_arena.builtScopes];
			_arena.builtScopes++;
//			printf(" --- buildScopes %d/%d\n", _arena.builtScopes, _arena.scopes().length());
			clearDeclarationModifiers();
			if (s.definition() != null &&
				s.storageClass() != StorageClass.TEMPLATE_INSTANCE)
				buildUnderScope(s);
		}
	}
	
	private void buildUnderScope(ref<Scope> s) {
		ref<Node> definition = s.definition();
		ref<Scope> outer = _current;
		_current = s;
		switch (definition.op()) {
		case	FUNCTION:{
			ref<Function> f = ref<Function>(definition);
			boolean outer = isStatic;
			isStatic = false;
			for (ref<NodeList> nl = f.arguments(); nl != null; nl = nl.next) {
				buildScopesInTree(nl.node);
			}
			isStatic = outer;
			if (f.body != null)
				buildScopesInTree(f.body);
		}break;

		case	BLOCK:
		case	CLASS:
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
				clearDeclarationModifiers();
				buildScopesInTree(nl.node);
			}
		break;
		
		case	ENUM:
			b = ref<Block>(definition);
			ref<NodeList> nl = b.statements();
			bindEnums(nl.node);
			nl = nl.next;
			for (; nl != null; nl = nl.next) {
				// Reset these state conditions accumulated from the traversal so far.
				clearDeclarationModifiers();
				buildScopesInTree(nl.node);
			}
		break;

		case	TEMPLATE:
			ref<Template> t = ref<Template>(definition);
			for (ref<NodeList> nl = t.templateParameters(); nl != null; nl = nl.next)
				buildScopesInTree(nl.node);
			buildScopesInTree(t.classDef);
			t.type = _arena.builtInType(TypeFamily.VOID);
		break;

		case	SCOPED_FOR:{
			ref<For> f = ref<For>(definition);
			buildScopesInTree(f.initializer());
			buildScopesInTree(f.test());
			buildScopesInTree(f.increment());
			buildScopesInTree(f.body());
		}break;

		default:
			definition.add(MessageId.UNFINISHED_BUILD_SCOPE, _pool, CompileString("  "/*definition.class.name()*/), CompileString(operatorMap.name[definition.op()]));
			definition.type = errorType();
		}
		_current = outer;
	}

	private void clearDeclarationModifiers() {
		isStatic = false;
		visibility = Operator.UNIT;
		annotations = null;
	}
	
	private void buildScopesInTree(ref<Node> n) {
		n.traverse(Node.Traversal.PRE_ORDER, buildScopeInTree, this);
		// TODO: Add nested functions so this can be:
//		n.traverse(Node.Traversal.PRE_ORDER, TraverseAction (ref<Node> n, address data) {
//				return buildScopes(n);
//			}, this);
	}

	private static TraverseAction buildScopeInTree(ref<Node> n, address data) {
//		printf(">>>buildScope(%p %s,...)\n", n, operatorMap.name[n.op()]);
		ref<CompileContext> context = ref<CompileContext>(data);
		TraverseAction t = context.buildScopes(n);
//		printf("<<<buildScope(%p %s,...)\n", n, operatorMap.name[n.op()]);
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
		case	ADDRESS:
		case	AND:
		case	AND_ASSIGN:
		case	ANNOTATION:
		case	ASSIGN:
		case	BIT_COMPLEMENT:
		case	BREAK:
		case	BYTES:
		case	CALL:
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
		case	OR:
		case	OR_ASSIGN:
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
		case	TRUE:
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

		case	PRIVATE:
		case	PROTECTED:
		case	PUBLIC:
			visibility = n.op();
			break;

		case	ANNOTATED:{
			ref<Binary> b = ref<Binary>(n);
			annotations = b.left();
			break;
		}
		case	IMPORT:{
			ref<Import> i = ref<Import>(n);
			i.prepareImport(this);
		}break;

		case	BIND:{
			ref<Binary> b = ref<Binary>(n);
			ref<Identifier> id = ref<Identifier>(b.right());
			id.bind(_current, b.left(), null, this);
		}break;

		case	BLOCK:{
			ref<Block> b = ref<Block>(n);
			b.scope = createScope(n, StorageClass.AUTO);
			return TraverseAction.SKIP_CHILDREN;
		}
		case	SCOPED_FOR:
		case	LOOP:
			createScope(n, StorageClass.AUTO);
			return TraverseAction.SKIP_CHILDREN;
			
		case	ENUM_DECLARATION:{
			ref<Binary> b = ref<Binary>(n);
			ref<Identifier> id = ref<Identifier>(b.left());
			id.bindEnumName(_current, ref<Block>(b.right()), this);
			return TraverseAction.SKIP_CHILDREN;
		}

		case	CLASS:{
			ref<Class> c = ref<Class>(n);
			ref<ClassScope> classScope = createClassScope(n, null);
			classScope.classType = _pool.newClassType(c, classScope);
			return TraverseAction.SKIP_CHILDREN;
		}
		case	CLASS_DECLARATION:{
			ref<Binary> b = ref<Binary>(n);
			ref<Identifier> id = ref<Identifier>(b.left());
			if (b.right().op() == Operator.TEMPLATE) {
				ref<Template> t = ref<Template>(b.right());
				id.bindTemplateOverload(visibility, isStatic, annotations, _current, t, this);
			} else {
				ref<Class> c = ref<Class>(b.right());
				id.bindClassName(_current, c, this);
			}
			return TraverseAction.SKIP_CHILDREN;
		}

		case	DECLARATION:{
			ref<Binary> b = ref<Binary>(n);
			bindDeclarators(b.left(), b.right());
		}break;

		case	FUNCTION:{
			ref<Function> f = ref<Function>(n);
			ref<ParameterScope> functionScope = createParameterScope(f, StorageClass.PARAMETER);
			if (f.name() != null) {
				switch (f.functionCategory()) {
				case	CONSTRUCTOR:
					if (isStatic) {
						f.add(MessageId.STATIC_DISALLOWED, _pool);
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
					if (_current.defineDestructor(functionScope, _pool))
						f.name().bindDestructor(visibility, _current, functionScope, this);
					else
						f.name().add(MessageId.DUPLICATE_DESTRUCTOR, _pool);
					break;

				case	NORMAL:
					if (f.body == null)
						f.name().bind(_current, f, null, this);
					else
						f.name().bindFunctionOverload(visibility, isStatic, annotations, _current, functionScope, this);
					break;

				case	ABSTRACT:
					f.name().bindFunctionOverload(visibility, isStatic, annotations, _current, functionScope, this);
					break;

				default:
					f.add(MessageId.INTERNAL_ERROR, _pool);
				}
			}
			return TraverseAction.SKIP_CHILDREN;
		}

		default:
			n.add(MessageId.UNFINISHED_BUILD_SCOPE, _pool, CompileString(/*n.class.name()*/"***"), CompileString(operatorMap.name[n.op()]));
			n.type = errorType();
		}
		return TraverseAction.CONTINUE_TRAVERSAL;
	}

	public ref<Scope> createScope(ref<Node> n, StorageClass storageClass) {
		return _arena.createScope(_current, n, storageClass);
	}

	ref<ParameterScope> createParameterScope(ref<Node> n, StorageClass storageClass) {
		return _arena.createParameterScope(_current, n, storageClass);
	}

	public ref<ClassScope> createClassScope(ref<Node> n, ref<Identifier> className) {
		return _arena.createClassScope(_current, n, className);
	}

	public ref<EnumScope> createEnumScope(ref<Block> definition, ref<Identifier> className) {
		return _arena.createEnumScope(_current, definition, className);
	}

	void bindDeclarators(ref<Node> type, ref<Node> n) {
		switch (n.op()) {
		case	IDENTIFIER:{
			ref<Identifier> id = ref<Identifier>(n);
			id.bind(_current, type, null, this);
		}break;
						   
		case	INITIALIZE:{
			ref<Binary> b = ref<Binary>(n);
			ref<Identifier> id = ref<Identifier>(b.left());
			id.bind(_current, type, b.right(), this);
		}break;

		case	SEQUENCE:{
			ref<Binary> b = ref<Binary>(n);
			bindDeclarators(type, b.left());
			bindDeclarators(type, b.right());
		}break;

		default:
			n.add(MessageId.UNFINISHED_BIND_DECLARATORS, _pool, CompileString("   "/*n.class.name()*/), CompileString(operatorMap.name[n.op()]));
			n.type = errorType();
		}
	}

	void bindEnums(ref<Node> n) {
		switch (n.op()) {
		case SEQUENCE:
			ref<Binary> b = ref<Binary>(n);
			bindEnums(b.left());
			bindEnums(b.right());
			break;
			
		case	IDENTIFIER:
			ref<Identifier> id = ref<Identifier>(n);
			ref<EnumScope> scope = ref<EnumScope>(_current);
			int offset = scope.symbols().size();
			ref<Symbol> sym = id.bindEnumInstance(_current, scope.enumType.wrappedType(), null, this);
			sym.offset = offset;
		}
	}

	public void assignTypes() {
		for (int i = 0; i < _arena.scopes().length(); i++) {
			_current = _arena.scopes()[i];
			if (_current.definition() != null) // && !_current.isInTemplateInstance())
				_current.definition().assignTypesAtScope(this);
		}
		for (int i = 0; i < _arena.scopes().length(); i++) {
			_current = _arena.scopes()[i];
			if (_current.definition() != null) {
				switch (_current.definition().op()) {
				case	FUNCTION:{
					if (_current.definition().class != Function) {
						printf("not Function class\n");
						break;
					}
					ref<Function> f = ref<Function>(_current.definition());
					if (f.body != null)
						assignControlFlow(f.body);
					break;
				}
				case UNIT:
					assignControlFlow(_current.definition());
				}
			}
		}
 	}

	public void assignTypes(ref<Scope> scope, ref<Node> n) {
		ref<Scope> outer = _current;
		_current = scope;
		assignTypes(n);
		_current = outer;
	}

	public void assignTypesAtScope(ref<Scope> scope, ref<Node> n) {
		ref<Scope> outer = _current;
		_current = scope;
		n.assignTypesAtScope(this);
		_current = outer;
	}

	public void assignTypes(ref<Node> n) {
		if (n.type == null && !n.definesScope()) {
//			printf("%s\n", OperatorMap.name[n.op()]);
			n.assignTypes(this);
			if (n.type == null) {
				n.add(MessageId.NO_EXPRESSION_TYPE, _pool);
				n.type = errorType();
			}
		}
	}

	public void assignControlFlow(ref<Node> n) {
		switch (n.op()) {
		case	UNIT:
		case	BLOCK:{
			ref<Block> b = ref<Block>(n);
			for (ref<NodeList> nl = b.statements(); nl != null; nl = nl.next)
				assignControlFlow(nl.node);
			break;
		}
		case	IF:{
			ref<Ternary> t = ref<Ternary>(n);
			assignControlFlow(t.middle());
			assignControlFlow(t.right());
			break;
		}
		case	ANNOTATED:{
			ref<Binary> b = ref<Binary>(n);
			assignControlFlow(b.right());
			break;
		}
		case	WHILE:
		case	SWITCH:{
			ref<Binary> b = ref<Binary>(n);
			FlowContext flowContext(b, _flowContext);
			pushFlowContext(&flowContext);
			assignControlFlow(b.right());
			popFlowContext();
			break;
		}
		case	DO_WHILE:{
			ref<Binary> b = ref<Binary>(n);
			FlowContext flowContext(b, _flowContext);
			pushFlowContext(&flowContext);
			assignControlFlow(b.left());
			popFlowContext();
			break;
		}
		case	CASE:{
			ref<Binary> b = ref<Binary>(n);
			assignControlFlow(b.right());
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
			if (switchType.family() == TypeFamily.ENUM) {
				if (b.left().op() != Operator.IDENTIFIER) {
					b.left().add(MessageId.NOT_ENUM_INSTANCE, _pool);
					b.left().type = errorType();
					break;
				}
				ref<Identifier> id = ref<Identifier>(b.left());
				id.resolveAsEnum(switchType, this);
				if (b.left().deferAnalysis())
					break;
			} else {
				assignTypes(b.left());
				if (b.left().deferAnalysis())
					break;
				b.left().coerce(_tree, switchType, false, this);
				if (!b.left().isConstant())
					b.left().add(MessageId.NOT_CONSTANT, _pool);
			}
			break;
		}
		case	DEFAULT:{
			ref<Binary> swit = enclosingSwitch();
			if (swit == null) {
				n.add(MessageId.INVALID_DEFAULT, _pool);
				n.type = errorType();
				break;
			}
			ref<Unary> u = ref<Unary>(n);
			assignControlFlow(u.operand());
			break;
		}
		case	FOR:
		case	SCOPED_FOR:{
			ref<For> f = ref<For>(n);
			FlowContext flowContext(f, _flowContext);
			pushFlowContext(&flowContext);
			assignControlFlow(f.body());
			popFlowContext();
			break;
		}
		case	ABSTRACT:
		case	CLASS_DECLARATION:
		case	ENUM_DECLARATION:
		case	DECLARATION:
		case	DECLARE_NAMESPACE:
		case	EXPRESSION:
		case	RETURN:
		case	EMPTY:
		case	FUNCTION:
		case	IMPORT:
		case	PUBLIC:
		case	PRIVATE:
		case	STATIC:
			break;

		case	BREAK:
			if (enclosingSwitch() == null &&
				enclosingLoop() == null) {
				n.add(MessageId.INVALID_BREAK, _pool);
			}
			break;

		case	CONTINUE:
			if (enclosingLoop() == null) {
				n.add(MessageId.INVALID_CONTINUE, _pool);
			}
			break;

		case	SYNTAX_ERROR:
			break;

		default:
			n.add(MessageId.UNFINISHED_CONTROL_FLOW, _pool, CompileString("  "/*n.class.name()*/), CompileString(operatorMap.name[n.op()]));
			n.type = errorType();
		}
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
/*
	void print();
*/
	public ref<Type> makeTypedef(ref<Type> underlyingType) {
		return _pool.newTypedefType(TypeFamily.TYPEDEF, underlyingType);
	}

	public ref<Type> errorType() {
		return _arena.builtInType(TypeFamily.ERROR);
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

	ref<Variable> newVariable(ref<Type> type) {
		ref<Variable> v = new Variable;
		v.type = type;
		_variables.append(v);
		return v;
	}

	ref<Variable> newVariable(ref<NodeList> returns) {
		ref<Variable> v = new Variable;
		v.returns = returns;
		_variables.append(v);
		return v;
	}
	
	int variableCount() {
		return _variables.length();
	}
	
	void resetVariables(int originalCount) {
		_variables.resize(originalCount);
	}
	
	ref<Variable>[] variables() {
		return _variables;
	}
	
	public ref<Scope> setCurrent(ref<Scope> scope) {
		ref<Scope> old = _current;
		_current = scope;
		return old;
	}
	
	public ref<Scope> current() {
		return _current;
	}

	ref<MemoryPool> pool() {
		return _pool;
	}
	
	ref<SyntaxTree> tree() {
		return _tree;
	}
}

class MemoryPool {
	private static int BLOCK_SIZE = (4096) * 4;

	private int _remaining;
	private pointer<byte> _freeSpace;
	private pointer<byte>[] _blocks;
	
	public MemoryPool() {
	}
/*
public:

	~MemoryPool();

	ref<ScopeList> newScopeList(ref<Scope> scope);
*/
	public ref<Symbol> newPlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<Node> type, ref<Node> initializer) {
		//void *block = alloc(sizeof (PlainSymbol));
		return new PlainSymbol(visibility, storageClass, enclosing, annotations, name, source, type, initializer);
	}

	public ref<Symbol> newPlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<Type> type, ref<Node> initializer) {
		//void *block = alloc(sizeof (PlainSymbol));
		return new PlainSymbol(visibility, storageClass, enclosing, annotations, name, source, type, initializer);
	}

	public ref<Overload> newOverload(ref<Scope> enclosing, ref<CompileString> name, Operator kind) {
		//void *block = alloc(sizeof (Overload));
		return new Overload(enclosing, null, name, kind);
	}

	public ref<OverloadInstance> newOverloadInstance(Operator visibility, boolean isStatic, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<ParameterScope> functionScope) {
		//void *block = alloc(sizeof (OverloadInstance));
		return new OverloadInstance(visibility, isStatic, enclosing, annotations, name, source, functionScope);
	}

	public ref<Namespace> newNamespace(ref<Node> namespaceNode, ref<Scope> enclosing, ref<Scope> symbols, ref<Node> annotations, ref<CompileString> name) {
		//void *block = alloc(sizeof (Namespace));
		return new Namespace(namespaceNode, enclosing, symbols, annotations, name);
	}

	public ref<Commentary> newCommentary(ref<Commentary> next, MessageId messageId, string message) {
		//void *block = alloc(sizeof (Commentary) + message.size());
		return new Commentary(next, messageId, message);
	}

	public ref<Type> newType(TypeFamily family) {
		//void *block = alloc(sizeof (Type));
		return new Type(family);
	}

	public ref<ClassType> newClassType(ref<Class> definition, ref<Scope> scope) {
		//void *block = alloc(sizeof (ClassType));
		return new ClassType(definition, scope);
	}

	public ref<ClassType> newClassType(ref<Type> base, ref<Scope> scope) {
		//void *block = alloc(sizeof (ClassType));
		return new ClassType(base, scope);
	}

	public ref<EnumType> newEnumType(ref<Block> definition, ref<Scope> scope, ref<Type> wrappedType) {
		//void *block = alloc(sizeof (EnumType));
		return new EnumType(definition, scope, wrappedType);
	}

	public ref<EnumInstanceType> newEnumInstanceType(ref<Symbol> symbol, ref<Scope> scope, ref<ClassType> instanceClass) {
		//void *block = alloc(sizeof (EnumInstanceType));
		return new EnumInstanceType(symbol, scope, instanceClass);
	}

	public ref<TemplateType> newTemplateType(ref<Template> definition, ref<FileStat> definingFile, ref<Overload> overload, ref<Scope> templateScope) {
		//void *block = alloc(sizeof (TemplateType));
		return new TemplateType(definition, definingFile, overload, templateScope);
	}

	public ref<BuiltInType> newBuiltInType(TypeFamily family, ref<ClassType> classType) {
		//void *block = alloc(sizeof (BuiltInType));
		return new BuiltInType(family, classType);
	}

	public ref<TypedefType> newTypedefType(TypeFamily family, ref<Type> wrappedType) {
//		assert(wrappedType.family() != TypeFamily.ERROR);
		//void *block = alloc(sizeof (TypedefType));
		return new TypedefType(family, wrappedType);
	}

	public ref<TemplateInstanceType> newTemplateInstanceType(ref<TemplateType> templateType, var[] args, ref<Template> concreteDefinition, ref<FileStat> definingFile, ref<Scope> scope, ref<TemplateInstanceType> next) {
		//void *block = alloc(sizeof (TemplateInstanceType));
		return new TemplateInstanceType(templateType, args, concreteDefinition, definingFile, scope, next);
	}

	public ref<FunctionType> newFunctionType(ref<NodeList> returnType, ref<NodeList> parameters, ref<Scope> functionScope) {
		//void *block = alloc(sizeof (FunctionType));
		return new FunctionType(returnType, parameters, functionScope);
	}

	address alloc(int n) {
		n = (n + (address.bytes - 1)) & ~(address.bytes - 1);		// round up to align
		if (n >= BLOCK_SIZE) {
			pointer<byte> megaBlock = pointer<byte>(allocz(n));
			_blocks.append(megaBlock);
			return megaBlock;
		} else if (n >= _remaining) {
			pointer<byte> block = pointer<byte>(allocz(BLOCK_SIZE));
			_blocks.append(block);
			_freeSpace = block + n;
			_remaining = BLOCK_SIZE - n;
			return block;
		} else {
			pointer<byte> block = _freeSpace;
			_freeSpace += n;
			_remaining -= n;
			return block;
		}
	}
}
