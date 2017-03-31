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

import native:C;
import parasol:text;
import parasol:stream.Utf8Reader;

enum Operator {
	// SyntaxError
	SYNTAX_ERROR,
	// Binary
	SUBSCRIPT,
	SEQUENCE,
	LEFT_COMMA,			// like SEQUENCE, but with the left operand supplyng the result. Evalute left, then right always.
	DIVIDE,
	REMAINDER,
	MULTIPLY,
	ADD,
	SUBTRACT,
	AND,
	OR,
	EXCLUSIVE_OR,
	STORE_TEMP,
	ASSIGN_TEMP,		// Handles the special case of assignment to a string temp 
	ASSIGN,
	DIVIDE_ASSIGN,
	REMAINDER_ASSIGN,
	MULTIPLY_ASSIGN,
	ADD_ASSIGN,
	SUBTRACT_ASSIGN,
	AND_ASSIGN,
	OR_ASSIGN,
	EXCLUSIVE_OR_ASSIGN,
	ADD_REDUCE,
	LABEL,
	EQUALITY,
	IDENTITY,
	LESS,
	GREATER,
	LESS_EQUAL,
	GREATER_EQUAL,
	LESS_GREATER,
	LESS_GREATER_EQUAL,
	NOT_EQUAL,
	NOT_IDENTITY,
	NOT_LESS,
	NOT_GREATER,
	NOT_LESS_EQUAL,
	NOT_GREATER_EQUAL,
	NOT_LESS_GREATER,
	NOT_LESS_GREATER_EQUAL,
	LEFT_SHIFT,
	RIGHT_SHIFT,
	UNSIGNED_RIGHT_SHIFT,
	LEFT_SHIFT_ASSIGN,
	RIGHT_SHIFT_ASSIGN,
	UNSIGNED_RIGHT_SHIFT_ASSIGN,
	LOGICAL_AND,
	LOGICAL_OR,
	DOT_DOT,
	DELETE,
	NEW,
	PLACEMENT_NEW,
	WHILE,
	DO_WHILE,
	SWITCH,
	CASE,
	BIND,
	TEMPLATE_INSTANCE,
	DECLARATION,
	CLASS_DECLARATION,
	INTERFACE_DECLARATION,
	MONITOR_DECLARATION,
	FLAGS_DECLARATION,
	ENUM_DECLARATION,
	INITIALIZE,
	ANNOTATED,
	CLASS_COPY,
	// Unary
	ELLIPSIS,
	DECLARE_NAMESPACE,
	UNARY_PLUS,
	NEGATE,
	BIT_COMPLEMENT,
	NOT,
	ADDRESS,
	INDIRECT,
	BYTES,
	CALL_DESTRUCTOR,
	CLASS_OF,
	INCREMENT_BEFORE,
	DECREMENT_BEFORE,
	INCREMENT_AFTER,
	DECREMENT_AFTER,
	EXPRESSION,
	RETURN,
	THROW,
	DEFAULT,
	VECTOR_OF,
	PUBLIC,
	PRIVATE,
	PROTECTED,
	STATIC,
	FINAL,
	ABSTRACT,
	UNWRAP_TYPEDEF,
	NAMESPACE,
	CAST,
	ELLIPSIS_ARGUMENT,
	STACK_ARGUMENT,
	LOAD,
	STORE_V_TABLE,
	CLASS_CLEAR,
	LOCK,
	// EllipsisArguments
	ELLIPSIS_ARGUMENTS,
	// StackArgumentAddress
	STACK_ARGUMENT_ADDRESS,
	// Import
	IMPORT,
	// Selection
	DOT,
	// Leaf
	EMPTY,
	BREAK,
	CONTINUE,
	SUPER,
	SELF,
	THIS,
	TRUE,
	FALSE,
	NULL,
	CLASS_TYPE,
	ENUM_TYPE,
	VACATE_ARGUMENT_REGISTERS,
	FRAME_PTR,
	STACK_PTR,
	// Constant
	INTEGER,
	FLOATING_POINT,
	CHARACTER,
	STRING,
	// Identifier
	IDENTIFIER,
	// Reference
	VARIABLE,
	// Class
	CLASS,
	INTERFACE,
	// Template
	TEMPLATE,
	// Loop
	LOOP,
	// For
	FOR,
	SCOPED_FOR,
	// Block
	BLOCK,
	UNIT,
	ENUM,
	FLAGS,
	// Map
	MAP,
	// Ternary
	CONDITIONAL,
	IF,
	CATCH,
	// FunctionDeclaration
	FUNCTION,
	// DestructorList
	DESTRUCTOR_LIST,
	// Call
	CALL,
	ANNOTATION,
	OBJECT_AGGREGATE,
	ARRAY_AGGREGATE,
	// Try
	TRY,
	MAX_OPERATOR
}

enum TraverseAction {
	CONTINUE_TRAVERSAL,
	ABORT_TRAVERSAL,
	SKIP_CHILDREN
}

enum Test {
	PASS_TEST,			// Returned if a test passes
	FAIL_TEST,			// Returned if a test fails
	IGNORE_TEST,		// Returned if the test result should be ignored (due to other errors)
	INCONCLUSIVE_TEST	// Returned if the test result should be regarded as inconclusive.  The
						// remediation in this case depends on the test.
}

// Global 'nodeFlags' values
public byte BAD_CONSTANT = 0x01;
public byte VECTOR_LVALUE = 0x02;
public byte VECTOR_OPERAND = 0x04;
public byte PUSH_OUT_PARAMETER = 0x08;

class SyntaxTree {
	private ref<Block> _root;
	private ref<MemoryPool> _pool;
	private ref<Scanner> _scanner;
	private string _filename;
	
	public SyntaxTree() {
		_pool = new MemoryPool();
	}

	~SyntaxTree() {
		delete _pool;
	}
	
	public ref<SyntaxTree> clone() {
		ref<SyntaxTree> copy = new SyntaxTree();
		copy._root = _root.clone(this);
		copy._scanner = _scanner;
		copy._filename = _filename;
		return copy;
	}
	
	void parse(ref<FileStat> file, ref<CompileContext> compileContext) {
		_filename = file.filename();
		ref<Scanner> scanner = file.scanner();
		if (scanner.opened()) {
			_scanner = scanner;
			Parser parser(this, _scanner);
			_root = parser.parseFile();
		} else {
			_scanner = null;
			_root = newBlock(Operator.UNIT, false, Location.OUT_OF_FILE);
			_root.add(MessageId.FILE_NOT_READ, _pool);
		}
	}

	public ref<Block> newBlock(Operator op, boolean inSwitch, Location location) {
		return _pool new Block(op, inSwitch, location);
	}

	public ref<Class> newClass(ref<Identifier> name, ref<Node> extendsClause, Location location) {
		return _pool new Class(name, extendsClause, location);
	}

	public ref<Template> newTemplate(ref<Identifier> name, Location location) {
		return _pool new Template(name, this, location);
	}

	public ref<Reference> newReference(ref<Variable> v, boolean definition, Location location) {
		return _pool new Reference(v, 0, definition, location);
	}
	
	public ref<Reference> newReference(ref<Variable> v, int offset, boolean definition, Location location) {
		return _pool new Reference(v, offset, definition, location);
	}
	
	public ref<Identifier> newIdentifier(CompileString value, Location location) {
		return _pool new Identifier(_pool.newCompileString(value), location);
	}

	public ref<Identifier> newIdentifier(ref<Symbol> symbol, Location location) {
		return _pool new Identifier(symbol, location);
	}

	public ref<Import> newImport(ref<Identifier> importedSymbol, ref<Ternary> namespaceNode, Location location) {
		return _pool new Import(importedSymbol, namespaceNode, location);
	}

	public ref<Map> newMap(ref<Node> valueType, ref<Node> keyType, ref<Node> seed, Location location) {
		return _pool new Map(valueType, keyType, seed, location);
	}

	public ref<Binary> newDeclaration(ref<Node> left, ref<Node> right, Location location) {
		return newBinary(Operator.DECLARATION, left.rewriteDeclarators(this), right, location);
	}

	public ref<Binary> newBinary(Operator op, ref<Node> left, ref<Node> right, Location location) {
		return _pool new Binary(op, left, right, location);
	}

	public ref<Unary> newUnary(Operator op, ref<Node> operand, Location location) {
		return _pool new Unary(op, operand, location);
	}

	public ref<Unary> newCast(ref<Type> type, ref<Node> operand) {
		ref<Unary> u = newUnary(Operator.CAST, operand, operand.location());
		u.type = type;
		return u;
	}
	
	public ref<Ternary> newTernary(Operator op, ref<Node> left, ref<Node> middle, ref<Node> right, Location location) {
		return _pool new Ternary(op, left, middle, right, location);
	}

	public ref<Try> newTry(ref<Node> body, ref<Node> finallyClause, ref<NodeList> catchList, Location location) {
		return _pool new Try(body, finallyClause, catchList, location);
	}
	
	public ref<Loop> newLoop(Location location) {
		return _pool new Loop(location);
	}

	public ref<For> newFor(Operator op, ref<Node> initializer, ref<Node> test, ref<Node> increment, ref<Node> body, Location location) {
		return _pool new For(op, initializer, test, increment, body, location);
	}

	public ref<Selection> newSelection(ref<Node> left, CompileString name, Location location) {
		return _pool new Selection(left, _pool.newCompileString(name), location);
	}

	public ref<Selection> newSelection(ref<Node> left, ref<Symbol> symbol, boolean indirect, Location location) {
		return _pool new Selection(left, symbol, indirect, location);
	}

	public ref<Return> newReturn(ref<NodeList> expressions, Location location) {
		return _pool new Return(expressions, location);
	}

	public ref<FunctionDeclaration> newFunctionDeclaration(FunctionDeclaration.Category functionCategory, ref<Node> returnType, ref<Identifier> name, ref<NodeList> arguments, Location location) {
		return _pool new FunctionDeclaration(functionCategory, returnType, name, arguments, this, location);
	}

	public ref<Call> newCall(Operator op, ref<Node> target, ref<NodeList> arguments, Location location) {
		return _pool new Call(op, target, arguments, location);
	}

	public ref<Call> newCall(ref<ParameterScope> overloadScope, CallCategory category, ref<Node> target, ref<NodeList> arguments, Location location, ref<CompileContext> compileContext) {
		return _pool new Call(overloadScope, category, target, arguments, location, compileContext);
	}

	public ref<DestructorList> newDestructorList(ref<NodeList> destructors, Location location) {
		return _pool new DestructorList(destructors, location);
	}
	
	public ref<EllipsisArguments> newEllipsisArguments(ref<NodeList> arguments, Location location) {
		return _pool new EllipsisArguments(arguments, location);
	}
	
	public ref<StackArgumentAddress> newStackArgumentAddress(int offset, Location location) {
		return _pool new StackArgumentAddress(offset, location);
	}
	
	public ref<Leaf> newLeaf(Operator op, Location location) {
		return _pool new Leaf(op, location);
	}

	public ref<Constant> newConstant(long value, Location location) {
		string s;
		s.printf("%d", value);
		CompileString v(s);
		return newConstant(Operator.INTEGER, v, location);
	}
	
	public ref<Constant> newConstant(Operator op, CompileString value, Location location) {
		return _pool new Constant(op, _pool.newCompileString(value), location);
	}

	public ref<SyntaxError> newSyntaxError(Location location) {
		return _pool new SyntaxError(location);
	}

	public ref<NodeList> newNodeList(ref<Node>... nodes) {
		if (nodes.length() == 0)
			return null;
		ref<NodeList> list;
		for (int i = nodes.length() - 1; i >= 0; i--) {
			ref<NodeList> nl = _pool new NodeList;
			nl.next = list;
			nl.node = nodes[i];
			list = nl;
		}
		return list;
	}
	
	public ref<Block> root() { 
		return _root; 
	}

	public ref<MemoryPool> pool() { 
		return _pool; 
	}
}

class Block extends Node {
	private ref<NodeList> _statements;
	private ref<NodeList> _last;
	private boolean _inSwitch;
	public ref<Scope> scope;
	public Location closeCurlyLocation;

	Block(Operator op, boolean inSwitch, Location location) {
		super(op, location);
		_inSwitch = inSwitch;
	}

	public void statement(ref<NodeList> stmt) {
		if (_last != null)
			_last.next = stmt;
		else
			_statements = stmt;
		_last = stmt;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		switch (t) {
		case	PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_statements != null && !_statements.traverse(t, func, data))
				return false;
			break;

		case	IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_statements != null && !_statements.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (_statements != null && !_statements.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_statements != null && !_statements.reverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
			if (_statements != null && !_statements.reverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			break;

		case	REVERSE_POST_ORDER:
			if (_statements != null && !_statements.reverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			break;

		default:
			return false;
		}
		return true;
	}
	
	public ref<Block> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		ref<Scope> outer;
		if (scope != null)
			outer = compileContext.setCurrent(scope);
		if (op() == Operator.LOCK) {
			if (deferAnalysis()) {
				_statements.next.node = _statements.next.node.fold(tree, true, compileContext);
				if (scope != null)
					compileContext.setCurrent(outer);
				return this;
			}
			ref<NodeList> nl = _statements;
			if (nl.node.op() == Operator.EXPRESSION) {
				ref<Unary> expression = ref<Unary>(nl.node);
				ref<Node> monitorName = expression.operand();
				ref<Variable> temp = compileContext.newVariable(compileContext.arena().builtInType(TypeFamily.ADDRESS));
				ref<LockScope> lockScope = ref<LockScope>(scope);
				lockScope.lockTemp = temp;
				ref<Node> defn = tree.newReference(temp, true, expression.location());
				ref<Node> adr = tree.newUnary(Operator.ADDRESS, monitorName, monitorName.location());
				adr.type = defn.type;
				defn = tree.newBinary(Operator.ASSIGN, defn, adr, expression.location());
				defn.type = adr.type;
				nl.node = tree.newUnary(Operator.EXPRESSION, defn, defn.location());
				nl.node.type = compileContext.arena().builtInType(TypeFamily.VOID);

				ref<NodeList> nln = callMonitorMethod(monitorName, monitorName.type, temp, "take", tree, compileContext);
				if (nln == null) {
					if (scope != null)
						compileContext.setCurrent(outer);
					return this;
				}
				nln.next = nl.next;
				nl.next = nln;

				nl = nln.next;
				nl.node = nl.node.fold(tree, true, compileContext);

				ref<NodeList> nlr = callMonitorMethod(monitorName, monitorName.type, temp, "release", tree, compileContext);
				if (nlr == null) {
					if (scope != null)
						compileContext.setCurrent(outer);
					return this;
				}

				nl.next = nlr;
			} else {
				// TODO: Handle the case for anonymous locks.
			}
		} else if (_statements != null) {
			for (ref<NodeList> nl = _statements;; nl = nl.next) {
				nl.node = nl.node.fold(tree, true, compileContext);
				if (nl.next == null) {
					ref<Node>[] destructors;
					for (;;) {
						ref<Node> n = compileContext.popLiveSymbol(scope);
						if (n == null)
							break;
						destructors.append(n);
					}		
					if (destructors.length() > 0) {
						ref<NodeList> destructorList = tree.newNodeList(destructors);
						ref<Node> n = tree.newDestructorList(destructorList, closeCurlyLocation);
						nl.next = tree.newNodeList(n);
					}
					break;
				}
			}
		}
		if (scope != null)
			compileContext.setCurrent(outer);
		return this;
	}
	
	private ref<NodeList> callMonitorMethod(ref<Node> errorMarker, ref<Type> monitorType, ref<Variable> temp, string methodName, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		ref<Node> call = callMethod(errorMarker, monitorType, temp, methodName, tree, compileContext);
		if (call == null)
			return null;
		ref<NodeList> nl = compileContext.pool() new NodeList;
		nl.node = tree.newUnary(Operator.EXPRESSION, call, location());
		nl.node.type = type;
		return nl;
	}

	public ref<Node> callMethod(ref<Node> errorMarker, ref<Type> monitorType, ref<Variable> temp, string methodName, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		ref<Node> defn;
		if (temp != null)
			defn = tree.newReference(temp, false, location());
		else {
			defn = tree.newLeaf(Operator.THIS, location());
			defn.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
		}
		ref<OverloadInstance> oi = getMethodSymbol(errorMarker, methodName, monitorType, compileContext);
		if (oi == null)
			return null;
		// This is the assignment method for this class!!!
		// (all strings go through here).
		ref<Selection> method = tree.newSelection(defn, oi, true, location());
		method.type = oi.type();
		ref<Call> call = tree.newCall(oi.parameterScope(), null, method, null, location(), compileContext);
		call.type = compileContext.arena().builtInType(TypeFamily.VOID);
		return call.fold(tree, true, compileContext);
	}
	
	public ref<Block> clone(ref<SyntaxTree> tree) {
		ref<Block> b = tree.newBlock(op(), _inSwitch, location());
		if (_statements != null)
			b._statements = _statements.clone(tree);
		b.scope = scope;
		return ref<Block>(b.finishClone(this, tree.pool()));
	}

	public ref<Block> cloneRaw(ref<SyntaxTree> tree) {
		ref<Block> b = tree.newBlock(op(), _inSwitch, location());
		if (_statements != null)
			b._statements = _statements.cloneRaw(tree);
		return b;
	}

	public ref<Identifier> className() {
		return null;
	}

	public Test fallsThrough() {
		Test t = blockFallsThrough(_statements);
		if (t == Test.INCONCLUSIVE_TEST)
			return Test.PASS_TEST;
		else
			return t;
	}

	public Test containsBreak() {
		for (ref<NodeList> nl = _statements; nl != null; nl = nl.next)
			if (nl.node.containsBreak() == Test.PASS_TEST)
				return Test.PASS_TEST;
		return Test.FAIL_TEST;
	}

	public void print(int indent) {
		printBasic(indent);
		if (_inSwitch)
			printf(" in switch");
		printf("\n");
		boolean firstTime = true;
		for (ref<NodeList> nl = _statements; nl != null; nl = nl.next) {
			if (!firstTime)
				firstTime = false;
			else
				printf("%*c  {BLOCK}\n", indent, ' ');
			nl.node.print(indent + INDENT);
		}
	}

	public ref<Node> endOfBlockStatement(ref<SyntaxTree> tree) {
		if (_last == null || _last.node.location().compare(closeCurlyLocation) != 0) {
			ref<Node> eob = tree.newLeaf(Operator.EMPTY, closeCurlyLocation);
			statement(tree.newNodeList(eob));
		}
		return _last.node;
	}
	
	public ref<NodeList> statements() {
		return _statements; 
	}
 
	protected void assignTypes(ref<CompileContext> compileContext) {
		ref<Scope> outer;
		if (scope != null)
			outer = compileContext.setCurrent(scope);
		for (ref<NodeList> nl = _statements; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
		type = compileContext.arena().builtInType(TypeFamily.VOID);
		if (op() == Operator.LOCK) {
			if (!_statements.node.deferAnalysis()) {
				ref<Unary> u = ref<Unary>(_statements.node);
				if (_statements.node.op() != Operator.EMPTY && !compileContext.isMonitor(u.operand().type)) {
					add(MessageId.NEEDS_MONITOR, compileContext.pool());
					type = compileContext.errorType();
				}
			}
		}
		if (scope != null)
			scope.checkDefaultConstructorCalls(compileContext);
		if (outer != null)
			compileContext.setCurrent(outer);
	}

	boolean definesScope() {
		return true;
	}
	
	boolean inSwitch() {
		return _inSwitch;
	}
}

private Test blockFallsThrough(ref<NodeList> nl) {
	if (nl == null)
		return Test.INCONCLUSIVE_TEST;
	Test t = blockFallsThrough(nl.next);
	if (t == Test.INCONCLUSIVE_TEST)
		return nl.node.fallsThrough();
	else
		return t;
}

class Class extends Block {
	protected ref<Node> _extends;
	private ref<Identifier> _name;
	private ref<NodeList> _implements;
	private ref<NodeList> _last;
	private TypeFamily _effectiveFamily;		// Set by annotations (@Shape, @Ref, @Pointer)
	
	Class(ref<Identifier> name, ref<Node> extendsClause, Location location) {
		super(Operator.CLASS, false, location);
		_name = name;
		_extends = extendsClause;
		_effectiveFamily = TypeFamily.CLASS;
	}
	
	public void addInterface(ref<NodeList> impl) {
		if (_last != null)
			_last.next = impl;
		else
			_implements = impl;
		_last = impl;
	}

	public Test fallsThrough() {
		assert(false);
		return Test.FAIL_TEST;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		switch (t) {
		case	PRE_ORDER:
		case	IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_extends != null && !_extends.traverse(t, func, data))
				return false;
			if (_implements != null && !_implements.traverse(t, func, data))
				return false;
			if (statements() != null && !statements().traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (_extends != null && !_extends.traverse(t, func, data))
				return false;
			if (_implements != null && !_implements.traverse(t, func, data))
				return false;
			if (statements() != null && !statements().traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (statements() != null && !statements().reverse(t, func, data))
				return false;
			if (_implements != null && !_implements.reverse(t, func, data))
				return false;
			if (_extends != null && !_extends.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (statements() != null && !statements().reverse(t, func, data))
				return false;
			if (_implements != null && !_implements.reverse(t, func, data))
				return false;
			if (_extends != null && !_extends.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		default:
			return false;
		}
		return true;
	}

	public ref<Class> clone(ref<SyntaxTree> tree) {
		ref<Identifier> name = _name != null ? _name.clone(tree) : null;
		ref<Node> extendsClause = _extends != null ? _extends.clone(tree) : null;
		ref<Class> result = tree.newClass(name, extendsClause, location());
		if (statements() != null)
			result.statement(statements().clone(tree));
		result.scope = scope;
		return ref<Class>(result.finishClone(this, tree.pool()));
	}

	public ref<Class> cloneRaw(ref<SyntaxTree> tree) {
		ref<Identifier> name = _name != null ? _name.cloneRaw(tree) : null;
		ref<Node> extendsClause = _extends != null ? _extends.cloneRaw(tree) : null;
		ref<Class> result = tree.newClass(name, extendsClause, location());
		if (statements() != null)
			result.statement(statements().cloneRaw(tree));
		return result;
	}

	public ref<Class> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		super.fold(tree, voidContext, compileContext);
		return this;
	}
	
	public ref<Identifier> className() {
		return _name;
	}

	public void print(int indent) {
		printBasic(indent);
		if (scope != null)
			printf(" scope %p", scope);
		printf("\n");
		if (_name != null)
			_name.print(indent + INDENT);
		printf("%*c  {CLASS extends}\n", indent, ' ');
		if (_extends != null)
			_extends.print(indent + INDENT);
		printf("%*c  {CLASS implements}\n", indent, ' ');
		for (ref<NodeList> nl = _implements; nl != null; nl = nl.next)
			nl.node.print(indent + INDENT);
		for (ref<NodeList> nl = statements(); nl != null; nl = nl.next) {
			printf("%*c  {CLASS body}\n", indent, ' ');
			nl.node.print(indent + INDENT);
		}
	}

	public ref<Identifier> name() {
		return _name;
	}

	public ref<Node> extendsClause() {
		return _extends;
	}

	boolean definesScope() {
		assert(false);
		return false;
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		if (_extends != null)
			compileContext.assignTypes(_extends);
		for (ref<NodeList> nl = _implements; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
		if (_extends != null) {
			if (_extends.deferAnalysis()) {
				type = _extends.type;
				return;
			}
		}
		for (ref<NodeList> nl = _implements; nl != null; nl = nl.next)
			if (nl.node.deferAnalysis()) {
				type = nl.node.type;
				return;
			}
		super.assignTypes(compileContext);
		for (ref<NodeList> nl = _implements; nl != null; nl = nl.next) {
			ref<Type> tp = nl.node.unwrapTypedef(Operator.INTERFACE, compileContext);
			if (tp.deferAnalysis()) {
				type = tp;
				continue;
			}
			if (nl.node.op() != Operator.IDENTIFIER) {
				nl.node.print(0);
			}
			if (scope != null) {
				ref<ClassType> classType = ref<ClassScope>(scope).classType;
				classType.implement(tp);
			}
			assert(nl.node.op() == Operator.IDENTIFIER);
			ref<Identifier> nm = ref<Identifier>(nl.node);
			for (ref<Symbol>[Scope.SymbolKey].iterator i = tp.scope().symbols().begin(); i.hasNext(); i.next()) {
				ref<Overload> o = ref<Overload>(i.get());
				ref<Symbol> sym = scope.lookup(o.name(), compileContext);
				if (sym != null && sym.class == Overload) {
					ref<Overload> classMethods = ref<Overload>(sym);
					for (int i = 0; i < classMethods.instances().length(); i++) {
						ref<OverloadInstance> oi = (*classMethods.instances())[i];
						oi.assignType(compileContext);
					}
					for (int i = 0; i < o.instances().length(); i++) {
						ref<OverloadInstance> oi = (*o.instances())[i];
						// oi is the interface method, classFunctions are the class' methods of the same name
						if (!classMethods.doesImplement(oi))
							add(MessageId.CLASS_MISSING_METHOD_FROM_INTERFACE, compileContext.pool(), *oi.name(), *nm.identifier());
					}
				} else {
					for (int i = 0; i < o.instances().length(); i++) {
						ref<OverloadInstance> oi = (*o.instances())[i];
//						printf("nm = {%x:%x} '%s'\n", nm.identifier().data, nm.identifier().length, (*nm.identifier()).asString());
//						printf("oi = {%x:%x} '%s'\n", oi.name().data, nm.identifier().length, (*oi.name()).asString());
						add(MessageId.CLASS_MISSING_METHOD_FROM_INTERFACE, compileContext.pool(), *oi.name(), *nm.identifier());
					}
				}
			}
		}

		if (scope != null) {
			// should read for (ref<Symbol> sym : scope.symbols()) {
			for (ref<Symbol>[Scope.SymbolKey].iterator i = scope.symbols().begin(); i.hasNext(); i.next()) {
				ref<Symbol> sym = i.get();
				if (sym.class != Overload)
					continue;
				ref<Overload> o = ref<Overload>(sym);
				if (o.kind() != Operator.FUNCTION)
					continue;
				for (int i = 0; i < o.instances().length(); i++) {
					ref<OverloadInstance> oi = (*o.instances())[i];
					oi.assignType(compileContext);
					ref<ParameterScope> parameterScope = oi.parameterScope();
					if (!parameterScope.isTemplateFunction()) {
						ref<FunctionDeclaration> func = ref<FunctionDeclaration>(parameterScope.definition());
						if (func != null && func.body != null)
							compileContext.assignTypes(func.body);
					}
				}
			}
		}
	}
}
/*
 * This class is constructed only during code-generation during folding for constants where
 * it would be pointlessly expensive to construct a string for use in a 'Constant', but defer
 * implementation to some future date.  For now, it is easier to just use the existing Constant
 * class.
 */
class InternalLiteral { // extends Node {
	
}

class Constant extends Node {
	private CompileString _value;
	
	public int offset;					// For constants that get stored out-of-line, like FP data,
										// this records the offset into the data section where the data was assigned.
	
	Constant(Operator op, CompileString value, Location location) {
		super(op, location);
		_value = value;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		return func(this, data) != TraverseAction.ABORT_TRAVERSAL;
	}
	
	public ref<Constant> clone(ref<SyntaxTree> tree) {
		return ref<Constant>(tree.newConstant(op(), _value, location()).finishClone(this, tree.pool()));
	}

	public ref<Constant> cloneRaw(ref<SyntaxTree> tree) {
		return tree.newConstant(op(), _value, location());
	}

	public void print(int indent) {
		printBasic(indent);
		printf(" '%s'", _value.asString());
		if (offset != 0)
			printf(" offset %x", offset);
		printf("\n");
	}

	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		switch (op()) {
		case	INTEGER:
		case	STRING:
		case	CHARACTER:
		case	FLOATING_POINT:
			if (voidContext) {
				ref<Node> n = tree.newLeaf(Operator.EMPTY, location());
				n.type = type;
				return n;
			}
			break;
			
		default:
			print(0);
			assert(false);
		}
		return this;
	}
	
	public long foldInt(ref<Target> target, ref<CompileContext> compileContext) {
		if ((nodeFlags & BAD_CONSTANT) != 0)
			return 0;						// We've already flagged this node with an error
		long x;
		boolean status;
		switch (op()) {
		case	INTEGER:
			return intValue();

		case	CHARACTER:
			(x, status) = charValue();
			if (status)
				return x;
			nodeFlags |= BAD_CONSTANT;
			add(MessageId.BAD_CHAR, compileContext.pool(), _value);
			return 0;

		default:
			print(0);
			assert(false);
			add(MessageId.UNFINISHED_GENERATE, compileContext.pool(), CompileString(" "/*this.class.name()*/), CompileString(string(op())), CompileString("Constant.foldInt"));
		}
		return 0;
	}

	public boolean isConstant() {
		switch (op()) {
		case	INTEGER:
		case	CHARACTER:
			return true;
		}
		return false;
	}

	public boolean canCoerce(ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
		if (type.widensTo(newType, compileContext))
			return true;
		switch (op()) {
		case	INTEGER:
		case	CHARACTER:
			if (representedBy(newType))
				return true;
		}
		return false;
	}

	boolean representedBy(ref<Type> newType) {
		long v;
		boolean status;
		switch (op()) {
		case	CHARACTER:
			(v, status) = charValue();
			if (!status)
				return false;
			break;

		case	INTEGER:
			v = intValue();
			break;

		default:
			return false;
		}
		switch (newType.family()) {
		case	UNSIGNED_8:
//			printf("v = %d byte.MAX_VALUE=%d\n", v, int(byte.MAX_VALUE));
			return v >= 0 && v <= byte.MAX_VALUE;

		case	UNSIGNED_16:
//			printf("v = %d char.MAX_VALUE=%d\n", v, int(char.MAX_VALUE));
			return v >= 0 && v <= char.MAX_VALUE;

		case	SIGNED_16:
//			printf("v = %d char.MAX_VALUE=%d\n", v, int(char.MAX_VALUE));
//			return v >= short.MIN_VALUE && v <= short.MAX_VALUE;

		case	SIGNED_32:
			return v >= int.MIN_VALUE && v <= int.MAX_VALUE;

		case	UNSIGNED_32:
			return v >= 0 && v <= unsigned.MAX_VALUE;

		case	SIGNED_64:
			return true;
			
		case	FLAGS:
			if (v == 0)
				return true;
			else
				return false;
/*
	 	 	 Note: Allowing an integer zero to be considered to 'represent' a valid pointer value,
	 	 	 means that 0 is interchangeable with null.  This seems to violate the spirit of having
	 	 	 null at all.

		case	CLASS:
			return v == 0 && newType.indirectType(compileContext) != null;
 */

		default:
			return false;
		}
		return false;
	}

	long intValue() {
		long v = 0;
		if (_value.length == 0)
			return -1;
		CompileStringReader r(_value);
		Utf8Reader ur(&r);
		
		int c = ur.read();
		if (codePointClass(c) == 0) {
			c = ur.read();
			if (c < 0)
				return 0;			// the constant is just a '0' (or alternate decimal zero)
			if (c == 'x' || c == 'X') {
				for (;;) {
					int digit;
					c = ur.read();
					if (c < 0)
						break;
					if (codePointClass(c) == CPC_LETTER)
						digit = 10 + byte(c).toLowercase() - 'a';
					else
						digit = codePointClass(c);
					v = v * 16 + digit;
				}
			} else {
				do {
					v = v * 8 + codePointClass(c);
					c = ur.read();
				} while (c >= 0);
			}
		} else {
			do {
				v = v * 10 + codePointClass(c);
				c = ur.read();
			} while (c >= 0);
		}
		return v;
	}

	long, boolean charValue() {
		string s(_value.data, _value.length);
		int output;
		boolean status;
		(output, status) = unescapeParasolCharacter(s);
		return output, status;
	}

	CompileString value() {
		return _value;
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	STRING:
			type = compileContext.arena().builtInType(TypeFamily.STRING);
			break;

		case	CHARACTER:
			type = compileContext.arena().builtInType(TypeFamily.UNSIGNED_16);
			break;

		case	INTEGER:
			type = compileContext.arena().builtInType(TypeFamily.SIGNED_32);
			if (!representedBy(type)) 
				type = compileContext.arena().builtInType(TypeFamily.SIGNED_64);
			break;
			
		case	FLOATING_POINT:
			if (_value.length > 0 && _value.data[_value.length - 1].toLowercase() == 'f')
				type = compileContext.arena().builtInType(TypeFamily.FLOAT_32);
			else
				type = compileContext.arena().builtInType(TypeFamily.FLOAT_64);
		}
	}
}

class For extends Node {
	private ref<Node> _initializer;
	private ref<Node> _test;
	private ref<Node> _increment;
	private ref<Node> _body;
	public ref<Scope> scope;
	
	For(Operator op, ref<Node> initializer, ref<Node> test, ref<Node> increment, ref<Node> body, Location location) {
		super(op, location);
		_initializer = initializer;
		_test = test;
		_increment = increment;
		_body = body;
	}
	
	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		switch (t) {
		case	PRE_ORDER:
		case	IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_initializer.traverse(t, func, data))
				return false;
			if (!_test.traverse(t, func, data))
				return false;
			if (!_increment.traverse(t, func, data))
				return false;
			if (!_body.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (!_initializer.traverse(t, func, data))
				return false;
			if (!_test.traverse(t, func, data))
				return false;
			if (!_increment.traverse(t, func, data))
				return false;
			if (!_body.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_body.traverse(t, func, data))
				return false;
			if (!_increment.traverse(t, func, data))
				return false;
			if (!_test.traverse(t, func, data))
				return false;
			if (!_initializer.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (!_body.traverse(t, func, data))
				return false;
			if (!_increment.traverse(t, func, data))
				return false;
			if (!_test.traverse(t, func, data))
				return false;
			if (!_initializer.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		default:
			return false;
		}
		return true;
	}

	public ref<For> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		if (deferGeneration())
			return this;
		switch (op()) {
		case	SCOPED_FOR:
		case	FOR:
			if (_initializer != null)
				_initializer = foldVoidContext(_initializer, tree, compileContext);
			if (_test != null) {
				_test = _test.fold(tree, false, compileContext);
				if (_test.type.family() == TypeFamily.FLAGS) {
					ref<Node> right = tree.newConstant(0, location());
					right.type = _test.type;
					ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _test, right, location());
					op.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					_test = op;
				}
			}
			if (_increment != null)
				_increment = foldVoidContext(_increment, tree, compileContext);
				
			if (_body != null)
				_body = _body.fold(tree, true, compileContext);
			break;
			
		default:
			print(0);
			assert(false);
		}
		return this;
	}
	
	public ref<For> clone(ref<SyntaxTree> tree) {
		ref<Node> initializer = _initializer != null ? _initializer.clone(tree) : null;
		ref<Node> test = _test != null ? _test.clone(tree) : null;
		ref<Node> increment = _increment != null ? _increment.clone(tree) : null;
		ref<Node> body = _body != null ? _body.clone(tree) : null;
		return ref<For>(tree.newFor(op(), initializer, test, increment, body, location()).finishClone(this, tree.pool()));
	}

	public ref<For> cloneRaw(ref<SyntaxTree> tree) {
		ref<Node> initializer = _initializer != null ? _initializer.cloneRaw(tree) : null;
		ref<Node> test = _test != null ? _test.cloneRaw(tree) : null;
		ref<Node> increment = _increment != null ? _increment.cloneRaw(tree) : null;
		ref<Node> body = _body != null ? _body.cloneRaw(tree) : null;
		return tree.newFor(op(), initializer, test, increment, body, location());
	}

	public void print(int indent) {
		_initializer.print(indent + INDENT);
		printBasic(indent);
		printf("\n");
		_test.print(indent + INDENT);
		printf("%*c  {FOR}\n", indent, ' ');
		_increment.print(indent + INDENT);
		printf("%*c  {FOR}\n", indent, ' ');
		_body.print(indent + INDENT);
	}

	public Test fallsThrough() {
		if (_test.op() == Operator.EMPTY)
			return _body.containsBreak();
		else
			return Test.PASS_TEST;
	}

	public ref<Node> initializer() {
		return _initializer;
	}

	public ref<Node> test() {
		return _test;
	}

	public ref<Node> increment() {
		return _increment;
	}

	public ref<Node> body() {
		return _body;
	}

	boolean definesScope() {
		return op() == Operator.SCOPED_FOR;
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	SCOPED_FOR:
			ref<Scope> outer = compileContext.setCurrent(scope);
		case	FOR:
			compileContext.assignTypes(_initializer);
			compileContext.assignTypes(_test);
			if (!_test.deferAnalysis() && _test.op() != Operator.EMPTY) {
				if (_test.type.family() != TypeFamily.BOOLEAN &&
					_test.type.family() != TypeFamily.FLAGS) {
					_test.add(MessageId.NOT_BOOLEAN, compileContext.pool());
					_test.type = compileContext.errorType();
				}
			}
			compileContext.assignTypes(_increment);
			compileContext.assignTypes(_body);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			if (op() == Operator.SCOPED_FOR)
				compileContext.setCurrent(outer);
			break;
		}
	}
}

class Import extends Node {
	private ref<Identifier> _localIdentifier;
	private ref<Scope> _enclosingScope;
	private boolean _importResolved;
	private ref<Ternary> _namespaceNode;

	Import(ref<Identifier> localIdentifier, ref<Ternary> namespaceNode, Location location) {
		super(Operator.IMPORT, location);
		_localIdentifier = localIdentifier;
		_namespaceNode = namespaceNode;
	}
	
	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		switch (t) {
		case	PRE_ORDER:
		case	IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_localIdentifier != null && !_localIdentifier.traverse(t, func, data))
				return false;
			if (!_namespaceNode.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (_localIdentifier != null && !_localIdentifier.traverse(t, func, data))
				return false;
			if (!_namespaceNode.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_namespaceNode.traverse(t, func, data))
				return false;
			if (_localIdentifier != null && !_localIdentifier.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (!_namespaceNode.traverse(t, func, data))
				return false;
			if (_localIdentifier != null && !_localIdentifier.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		default:
			return false;
		}
		return true;
	}

	public ref<Import> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		// Import statements don't fold to anything interesting.
		return this;
	}
	
	public ref<Import> clone(ref<SyntaxTree> tree) {
		ref<Identifier> id;
		if (_localIdentifier != null)
			id = _localIdentifier.clone(tree);
		ref<Import> i = tree.newImport(id, _namespaceNode.clone(tree), location());
		i._enclosingScope = _enclosingScope;
		return ref<Import>(i.finishClone(this, tree.pool()));
	}

	public ref<Import> cloneRaw(ref<SyntaxTree> tree) {
		ref<Identifier> id;
		if (_localIdentifier != null)
			id = _localIdentifier.cloneRaw(tree);
		return tree.newImport(id, _namespaceNode.cloneRaw(tree), location());
	}

	public void print(int indent) {
		printBasic(indent);
		if (_importResolved)
			printf(" RESOLVED");
		printf("\n");
		if (_localIdentifier != null)
			_localIdentifier.print(indent + INDENT);
		printf("%*c  {IMPORT namespace}\n", indent, ' ');
		_namespaceNode.print(indent + INDENT);
	}
	/*
	 * In order to properly handle cyclic imports (A imports B while B imports A), we have to do import
	 * processing in two stages.  First, we have to process the import far enough to trigger the load of
	 * the imported namespace.  Later, we will look up the symbol.
	 */
	public void prepareImport(ref<CompileContext> compileContext) {
		string domain;
		boolean result;
		
		(domain, result) = _namespaceNode.left().dottedName();
		ref<Symbol> symbol = compileContext.arena().getImport(true, domain, _namespaceNode, compileContext);
		if (symbol == null)
			compileContext.arena().conjureNamespace(domain, _namespaceNode, compileContext);
		_enclosingScope = compileContext.current();
	}

	public void lookupImport(ref<CompileContext> compileContext) {
		if (!_importResolved) {
			ref<Identifier> localName;
			string domain;
			boolean result;
			
			(domain, result) = _namespaceNode.left().dottedName();
			ref<Symbol> symbol = compileContext.arena().getImport(true, domain, _namespaceNode, compileContext);
			if (_localIdentifier != null)
				localName = _localIdentifier;
			else
				localName = ref<Identifier>(_namespaceNode.right());
			if (symbol != null) {
				if (isAllowedImport(symbol)) {
					if (!_enclosingScope.defineImport(localName, symbol, compileContext.pool()))
						_namespaceNode.add(MessageId.DUPLICATE, compileContext.pool(), localName.value());
				} else
					_namespaceNode.add(MessageId.INVALID_IMPORT, compileContext.pool());
			} else
				_namespaceNode.add(MessageId.UNDEFINED, compileContext.pool(), ref<Identifier>(_namespaceNode.right()).value());
			_importResolved = true;
		}
	}

	private boolean isAllowedImport(ref<Symbol> symbol) {
		if (symbol.class == Namespace) {
			if (symbol == _enclosingScope.getNamespace())
				return false;
		} else if (symbol.enclosing().getNamespace() == _enclosingScope.getNamespace())
			return false;
		return true;
	}
	
	private void assignTypes(ref<CompileContext> compileContext) {
		type = compileContext.arena().builtInType(TypeFamily.VOID);
	}
}

class Leaf extends Node {
	Leaf(Operator op, Location location) {
		super(op, location);
	}

	public Leaf(byte register, ref<Type> type) {
		super(register, type);
	}
	
	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		return func(this, data) != TraverseAction.ABORT_TRAVERSAL;
	}

	public ref<Leaf> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		switch (op()) {
		case	BREAK:
		case	CONTINUE:
		case	EMPTY:
		case	TRUE:
		case	FALSE:
		case	THIS:
		case	SUPER:
		case	NULL:
		case	FRAME_PTR:
		case	STACK_PTR:
			break;
			
		default:
			print(0);
			assert(false);
		}
		return this;
	}
	
	public ref<Leaf> clone(ref<SyntaxTree> tree) {
		return ref<Leaf>(tree.newLeaf(op(), location()).finishClone(this, tree.pool()));
	}

	public ref<Leaf> cloneRaw(ref<SyntaxTree> tree) {
		return tree.newLeaf(op(), location());
	}

	public void print(int indent) {
		printBasic(indent);
		printf("\n");
	}
	
	public boolean canCoerce(ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
		switch (op()) {
		case	NULL:
			switch (newType.family()) {
			case	STRING:
			case	ENUM:
			case	FUNCTION:
			case	REF:
			case	POINTER:
			case	INTERFACE:
				return true;

			case	SIGNED_32:
			case	SIGNED_64:
				return explicitCast;

			default:
				break;
			}
			break;
		}
		return super.canCoerce(newType, explicitCast, compileContext);
	}
/*
private:
	Leaf(Operator op, Location location);
*/
 
	private void assignTypes(ref<CompileContext> compileContext) {
		ref<ClassScope> classScope;
		ref<Type> t;
		ref<Scope> scope;
		switch (op()) {
		case	EMPTY:
		case	BREAK:
		case	CONTINUE:
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	NULL:
			type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			break;

		case	FALSE:
		case	TRUE:
			type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
			break;

		case	CLASS_TYPE:
			type = compileContext.makeTypedef(compileContext.arena().builtInType(TypeFamily.CLASS_VARIABLE));
			break;

		case	THIS:
			t = compileContext.current().enclosingClassType();
			if (t == null) {
				add(MessageId.THIS_NOT_ALLOWED, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			t = compileContext.convertToAnyBuiltIn(t);
			type = compileContext.arena().createRef(t, compileContext);
			break;

		case	SUPER:
			scope = compileContext.current();
			while (scope != null && scope.storageClass() != StorageClass.MEMBER)
				scope = scope.enclosing();
			if (scope == null) {
				add(MessageId.SUPER_NOT_ALLOWED, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			classScope = ref<ClassScope>(scope);
			t = classScope.classType;
			if (t == null) {
				add(MessageId.INTERNAL_ERROR, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			t = t.getSuper();
			if (t == null) {
				add(MessageId.SUPER_NOT_ALLOWED, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			t = compileContext.convertToAnyBuiltIn(t);
			type = compileContext.arena().createRef(t, compileContext);
			break;
		}
	}
	
	public Test containsBreak() {
		if (op() == Operator.BREAK)
			return Test.PASS_TEST;
		else
			return Test.FAIL_TEST;
	}
}

class Loop extends Node {
	private ref<Node> _declarator;
	private ref<Node> _aggregate;
	private ref<Node> _body;
	
	Loop(Location location) {
		super(Operator.LOOP, location);
	}
	
	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		switch (t) {
		case	PRE_ORDER:
		case	IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_declarator.traverse(t, func, data))
				return false;
			if (!_aggregate.traverse(t, func, data))
				return false;
			if (!_body.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (!_declarator.traverse(t, func, data))
				return false;
			if (!_aggregate.traverse(t, func, data))
				return false;
			if (!_body.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_body.traverse(t, func, data))
				return false;
			if (!_aggregate.traverse(t, func, data))
				return false;
			if (!_declarator.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (!_body.traverse(t, func, data))
				return false;
			if (!_aggregate.traverse(t, func, data))
				return false;
			if (!_declarator.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		default:
			return false;
		}
		return true;
	}	

	public ref<Loop> clone(ref<SyntaxTree> tree) {
		assert(false);
		return null;
	}

	public ref<Loop> cloneRaw(ref<SyntaxTree> tree) {
		assert(false);
		return null;
	}

	public ref<Loop> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return this;
	}
	
	public void print(int indent) {
		assert(false);
	}

	public void attachParts(ref<Node> declarator, ref<Node> aggregate, ref<Node> body) {
		_declarator = declarator;
		_aggregate = aggregate;
		_body = body;
	}

	boolean definesScope() {
		assert(false);
		return false;
	}
}

class Map extends Node {
	private ref<Node> _valueType;
	private ref<Node> _keyType;
	private ref<Node> _seed;

	Map(ref<Node> valueType, ref<Node> keyType, ref<Node> seed, Location location) {
		super(Operator.MAP, location);
		_valueType = valueType;
		_keyType = keyType;
		_seed = seed;	
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		switch (t) {
		case	PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_valueType.traverse(t, func, data))
				return false;
			if (!_keyType.traverse(t, func, data))
				return false;
			if (!_seed.traverse(t, func, data))
				return false;
			break;

		case	IN_ORDER:
			if (!_valueType.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_keyType.traverse(t, func, data))
				return false;
			if (!_seed.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (!_valueType.traverse(t, func, data))
				return false;
			if (!_keyType.traverse(t, func, data))
				return false;
			if (!_seed.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_seed.traverse(t, func, data))
				return false;
			if (!_keyType.traverse(t, func, data))
				return false;
			if (!_valueType.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
			if (!_seed.traverse(t, func, data))
				return false;
			if (!_keyType.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_valueType.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_POST_ORDER:
			if (!_seed.traverse(t, func, data))
				return false;
			if (!_keyType.traverse(t, func, data))
				return false;
			if (!_valueType.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			break;

		default:
			return false;
		}
		return true;
	}

	public ref<Map> clone(ref<SyntaxTree> tree) {
		assert(false);
		return null;
	}

	public ref<Map> cloneRaw(ref<SyntaxTree> tree) {
		assert(false);
		return null;
	}

	public ref<Map> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return this;
	}
	
	public void print(int indent) {
		assert(false);
	}
}

class SyntaxError extends Node {
	SyntaxError(Location location) {
		super(Operator.SYNTAX_ERROR, location);
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		return func(this, data) != TraverseAction.ABORT_TRAVERSAL;
	}

	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return this;
	}
	
	public ref<SyntaxError> clone(ref<SyntaxTree> tree) {
		return ref<SyntaxError>(tree.newSyntaxError(location()).finishClone(this, tree.pool()));
	}

	public ref<SyntaxError> cloneRaw(ref<SyntaxTree> tree) {
		return tree.newSyntaxError(location());
	}

	public Test fallsThrough() {
		return Test.IGNORE_TEST;
	}

	public void print(int indent) {
		printBasic(indent);
		printf("\n");
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		type = compileContext.errorType();
	}
}

class Template extends Node {
	private ref<Identifier> _name;
	private ref<SyntaxTree> _tree;
	private ref<NodeList> _templateParameters;
	private ref<NodeList> _last;

	public ref<Class> classDef;

	Template(ref<Identifier> name, ref<SyntaxTree> tree, Location location) {
		super(Operator.TEMPLATE, location);
		_name = name;
		_tree = tree;
	}
	
	public void templateArgument(ref<NodeList> declaration) {
		if (_last != null)
			_last.next = declaration;
		else
			_templateParameters = declaration;
		_last = declaration;
	}

/*
	void setExtends(ref<Node> extends);
*/
	public Test fallsThrough() {
		assert(false);
		return Test.FAIL_TEST;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		switch (t) {
		case	PRE_ORDER:
		case	IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_templateParameters.traverse(t, func, data))
				return false;
			if (!classDef.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (!_templateParameters.traverse(t, func, data))
				return false;
			if (!classDef.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!classDef.traverse(t, func, data))
				return false;
			if (!_templateParameters.reverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (!classDef.traverse(t, func, data))
				return false;
			if (!_templateParameters.reverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		default:
			return false;
		}
		return true;
	}

	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return this;
	}
	
	public ref<Template> cloneRaw() {
		return cloneRaw(_tree);
	}

	public ref<Template> clone(ref<SyntaxTree> tree) {
		ref<Identifier> name = _name != null ? _name.clone(tree) : null;
		ref<Template> templateNode = tree.newTemplate(name, location());
		templateNode._templateParameters = _templateParameters != null ? _templateParameters.clone(tree) : null;
		templateNode.classDef = classDef.clone(tree);
		templateNode._tree = tree;
		return ref<Template>(templateNode.finishClone(this, tree.pool()));
	}

	public ref<Template> cloneRaw(ref<SyntaxTree> tree) {
		ref<Identifier> name = _name != null ? _name.cloneRaw(tree) : null;
		ref<Template> templateNode = tree.newTemplate(name, location());
		templateNode._templateParameters = _templateParameters != null ? _templateParameters.cloneRaw(tree) : null;
		templateNode.classDef = classDef.cloneRaw(tree);
		templateNode._tree = tree;
		return templateNode;
	}

	public void print(int indent) {
		printBasic(indent);
		printf("\n");

		printf("%*c  {TEMPLATE args}\n", indent, ' ');
		for (ref<NodeList> nl = _templateParameters; nl != null; nl = nl.next)
			nl.node.print(indent + INDENT);
		if (classDef != null) {
			printf("%*c  {TEMPLATE class}\n", indent, ' ');
			classDef.print(indent + INDENT);
		}
	}
/*
	ref<SyntaxTree> tree() { return _tree; }
*/
	public ref<Identifier> name() {
		return _name;
	}

	public ref<NodeList> templateParameters() {
		return _templateParameters;
	}

	boolean definesScope() {
		print(0);
		assert(false);
		return false;
	}
	
	private void assignTypes(ref<CompileContext> compileContext) {
		compileContext.assignTypes(_name);
		if (_name.deferAnalysis()) {
			type = _name.type;
			return;
		}
		for (ref<NodeList> nl = _templateParameters; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
		for (ref<NodeList> nl = _templateParameters; nl != null; nl = nl.next)
			if (nl.node.deferAnalysis()) {
				type = nl.node.type;
				return;
			}
		type = compileContext.arena().builtInType(TypeFamily.VOID);
	}
}


class Ternary extends Node {
	ref<Node>	_left;
	ref<Node>	_middle;
	ref<Node>	_right;

	Ternary(Operator op, ref<Node> left, ref<Node> middle, ref<Node> right, Location location) {
		super(op, location);
		_left = left;
		_middle = middle;
		_right = right;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		Traversal t_this = t;
		if (op() == Operator.IF || op() == Operator.CATCH) {
			switch (t) {
			case	IN_ORDER:
				t_this = Traversal.PRE_ORDER;
				break;

			case	REVERSE_IN_ORDER:
				t_this = Traversal.REVERSE_POST_ORDER;
			}
		}
		switch (t_this) {
		case	PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_left.traverse(t, func, data))
				return false;
			if (!_middle.traverse(t, func, data))
				return false;
			if (_right != null && !_right.traverse(t, func, data))
				return false;
			break;

		case	IN_ORDER:
			if (!_left.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_middle.traverse(t, func, data))
				return false;
			if (_right != null && !_right.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (!_left.traverse(t, func, data))
				return false;
			if (!_middle.traverse(t, func, data))
				return false;
			if (_right != null && !_right.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_right != null && !_right.traverse(t, func, data))
				return false;
			if (!_middle.traverse(t, func, data))
				return false;
			if (!_left.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
			if (_right != null && !_right.traverse(t, func, data))
				return false;
			if (!_middle.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_left.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_POST_ORDER:
			if (_right != null && !_right.traverse(t, func, data))
				return false;
			if (!_middle.traverse(t, func, data))
				return false;
			if (!_left.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		default:
			return false;
		}
		return true;
	}

	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		if (deferGeneration())
			return this;
		switch (op()) {
		case	NAMESPACE:
			break;
			
		case	CONDITIONAL:
			if (!voidContext) {
				_middle = tree.newUnary(Operator.LOAD, _middle, _middle.location());
				_middle.type = type;
				_right = tree.newUnary(Operator.LOAD, _right, _right.location());
				_right.type = type;
			}
			
		case	IF:
			if (_left != null) {
				_left = _left.foldConditional(tree, compileContext);
				switch (_left.op()) {
				case TRUE:
					return _middle.fold(tree, voidContext, compileContext);
					
				case FALSE:
					return _right.fold(tree, voidContext, compileContext);
				}
			}
			if (_middle != null)
				_middle = _middle.fold(tree, voidContext, compileContext);
			if (_right != null)
				_right = _right.fold(tree, voidContext, compileContext);
			if (_left.type != null && _left.type.family() == TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _left.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _left, right, location());
				op.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				_left = op;
			}
			break;
			
		case	CATCH:
			_right = _right.fold(tree, true, compileContext);
			break;
			
		default:
			print(0);
			assert(false);
		}
		return this;
	}
	
	public ref<Ternary> clone(ref<SyntaxTree> tree) {
		ref<Node> left = _left != null ? _left.clone(tree) : null;
		ref<Node> middle = _middle != null ? _middle.clone(tree) : null;
		ref<Node> right = _right != null ? _right.clone(tree) : null;
		return ref<Ternary>(tree.newTernary(op(), left, middle, right, location()).finishClone(this, tree.pool()));
	}

	public ref<Ternary> cloneRaw(ref<SyntaxTree> tree) {
		ref<Node> left = _left != null ? _left.cloneRaw(tree) : null;
		ref<Node> middle = _middle != null ? _middle.cloneRaw(tree) : null;
		ref<Node> right = _right != null ? _right.cloneRaw(tree) : null;
		return tree.newTernary(op(), left, middle, right, location());
	}

	public Test fallsThrough() {
		if (op() == Operator.IF) {
			Test t = _middle.fallsThrough();
			if (t == Test.INCONCLUSIVE_TEST)
				return Test.PASS_TEST;
			if (t == Test.PASS_TEST || t == Test.IGNORE_TEST)
				return t;
			t = _right.fallsThrough();
			if (t == Test.INCONCLUSIVE_TEST)
				return Test.PASS_TEST;
			else
				return t;
		} else
			return Test.PASS_TEST;
	}

	public boolean namespaceConforms(ref<Ternary> importNode) {
		if (_middle.conforms(importNode.middle()))
			return true;
		// This situation will arise if the 'importNode' is actually the namespace node of
		// a file.
		if (importNode.right() == null)
			return false;
		if (!_middle.identifier().equals(*importNode.right().identifier()))
			return false;
		if (_middle.op() == Operator.IDENTIFIER)
			return importNode.middle().op() == Operator.EMPTY;
		ref<Selection> sel = ref<Selection>(_middle);
		return sel.left().conforms(importNode.middle());
	}

	public void print(int indent) {
		_left.print(indent + INDENT);
		printBasic(indent);
		printf("\n");
		_middle.print(indent + INDENT);
		printf("%*c  {Ternary}\n", indent, ' ');
		if (_right != null)
			_right.print(indent + INDENT);
		else
			printf("%*c<null>\n", indent + INDENT, ' ');
	}

	public ref<Node> left() { 
		return _left; 
	}

	public ref<Node> middle() {
		return _middle;
	}

	public ref<Node> right() {
		return _right;
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	CONDITIONAL:
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_middle);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}
			if (_middle.deferAnalysis()) {
				type = _middle.type;
				return;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				return;
			}
			if (_left.type.family() != TypeFamily.BOOLEAN &&
				_left.type.family() != TypeFamily.FLAGS) {
				add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			if (_right.op() == Operator.EMPTY)
				type = _left.type;
			else
				balancePair(this, &_middle, &_right, compileContext);
			break;

		case	IF:
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_middle);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}
			if (_left.type.family() != TypeFamily.BOOLEAN &&
				_left.type.family() != TypeFamily.FLAGS) {
				add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	NAMESPACE:
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
			
		case	CATCH:
			compileContext.assignTypes(_left);
			if (_left.deferAnalysis()) {
				type = _left.type;
				break;
			}
			compileContext.assignTypes(_right);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
			
		default:
			print(0);
			assert(false);
		}
	}
}

class Try extends Node {
	ref<Node>		_body;
	ref<Node>		_finally;
	ref<NodeList>	_catchList;
	
	Try(ref<Node> body, ref<Node> finallyClause, ref<NodeList> catchList, Location location) {
		super(Operator.TRY, location);
		_body = body;
		_finally = finallyClause;
		_catchList = catchList;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;
		switch (t) {
		case	PRE_ORDER:
		case	IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_body.traverse(t, func, data))
				return false;
			if (_catchList != null && !_catchList.traverse(t, func, data))
				return false;
			if (_finally != null && !_finally.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (!_body.traverse(t, func, data))
				return false;
			if (_catchList != null && !_catchList.traverse(t, func, data))
				return false;
			if (_finally != null && !_finally.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_finally != null && !_finally.traverse(t, func, data))
				return false;
			if (_catchList != null && !_catchList.reverse(t, func, data))
				return false;
			if (!_body.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (_finally != null && !_finally.traverse(t, func, data))
				return false;
			if (_catchList != null && !_catchList.reverse(t, func, data))
				return false;
			if (!_body.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		default:
			return false;
		}
		return true;
	}

	void assignTypes(ref<CompileContext> compileContext) {
		type = compileContext.arena().builtInType(TypeFamily.VOID);
		compileContext.assignTypes(_body);
		if (_finally != null)
			compileContext.assignTypes(_finally);
		for (ref<NodeList> nl = _catchList; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
	}

	public ref<Try> clone(ref<SyntaxTree> tree) {
		ref<Node> body = _body.clone(tree);
		ref<Node> finallyClause = _finally != null ? _finally.clone(tree) : null;
		ref<NodeList> nl = _catchList != null ? _catchList.clone(tree) : null;
		return ref<Try>(tree.newTry(body, finallyClause, nl, location()).finishClone(this, tree.pool()));
	}

	public ref<Try> cloneRaw(ref<SyntaxTree> tree) {
		ref<Node> body = _body.cloneRaw(tree);
		ref<Node> finallyClause = _finally != null ? _finally.cloneRaw(tree) : null;
		ref<NodeList> nl = _catchList != null ? _catchList.cloneRaw(tree) : null;
		return tree.newTry(body, finallyClause, nl, location());
	}

	private static int compareTypes(ref<Node> a, ref<Node> b) {
		ref<Binary> ab = ref<Binary>(a);
		ref<Binary> bb = ref<Binary>(b);
		ref<Type> at = ref<TypedefType>(ab.left().type).wrappedType();
		ref<Type> bt = ref<TypedefType>(bb.left().type).wrappedType();
		if (at.isSubtype(bt))
			return -1;
		else if (bt.isSubtype(at))
			return 1;
		else
			return 0;
	}
	
	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		_body = _body.fold(tree, true, compileContext);
		if (_finally != null)
			_finally = _finally.fold(tree, true, compileContext);
		ref<Node>[] catches;
		for (ref<NodeList> nl = _catchList; nl != null; nl = nl.next) {
			nl.node = nl.node.fold(tree, true, compileContext);
			catches.append(nl.node);
		}
		// Sort catches from most specific to most general.
		if (catches.length() > 1) {
			catches.sort(compareTypes, true);
			int i = 0;
			for (ref<NodeList> nl = _catchList; nl != null; nl = nl.next, i++)
				nl.node = catches[i];
		}
		ref<Variable> temp = compileContext.newVariable(compileContext.arena().builtInType(TypeFamily.ADDRESS));
		ref<Reference> r = tree.newReference(temp, true, _body.location());
		ref<NodeList> extra = tree.newNodeList(r);
		extra.next = _catchList;
		_catchList = extra;
		return this;
	}

	public void print(int indent) {
		printBasic(indent);
		printf("\n");
		_body.print(indent + INDENT);
		if (_catchList != null) {
			for (ref<NodeList> nl = _catchList; nl != null; nl = nl.next) {
				printf("%*c  {catch}\n", indent, ' ');
				nl.node.print(indent + INDENT);
			}
		}
		if (_finally != null) {
			printf("%*c  {finally}\n", indent, ' ');
			_finally.print(indent + INDENT);
		}
	}
	
	public ref<Node> body() {
		return _body;
	}

	public ref<Node> finallyClause() {
		return _finally;
	}
	
	public ref<NodeList> catchList() {
		return _catchList;
	}
}

class Node {
	private Operator _op;
	private Location _location;
	private ref<Commentary> _commentary;

	public ref<Type> type;
	public byte register;
	public byte nodeFlags;
	public int sethi;
	
	Node(Operator op, Location location) {
		_op = op;
		_location = location;
	}

	protected Node(byte register, ref<Type> type) {
		this.register = register;
		this.type = type;
	}
	
	public Operator op() { 
		return _op; 
	}

	protected ref<Node> finishClone(ref<Node> original, ref<MemoryPool> pool) {
		type = original.type;
		register = original.register;
		nodeFlags = original.nodeFlags;
		sethi = original.sethi;
		if (original._commentary != null)
			_commentary = original._commentary.clone(pool);
		return this;
	}
	
	enum Traversal {
		PRE_ORDER,
		IN_ORDER,
		POST_ORDER,
		REVERSE_PRE_ORDER,
		REVERSE_IN_ORDER,
		REVERSE_POST_ORDER
	}
 
	public abstract boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data);
	
	public abstract ref<Node> clone(ref<SyntaxTree> tree);

	public abstract ref<Node> cloneRaw(ref<SyntaxTree> tree);

	public void markupDeclarator(ref<Type> type, boolean needsDefaultConstructor, ref<CompileContext> compileContext) {
		assert(false);
	}

	public void assignClassVariable(ref<CompileContext> compileContext) {
		assert(false);
	}
	
	public void assignOverload(ref<NodeList> arguments, Operator kind, ref<CompileContext> compileContext) {
		compileContext.assignTypes(this);			// needs to be 'function'
	}

	public ref<Node> rewriteDeclarators(ref<SyntaxTree> syntaxTree) {
		return this;
	}

	public ref<CompileString> identifier() {
		return null;
	}

	public ref<Symbol> symbol() {
		return null;
	}

	public ref<Scope> enclosing() {
		ref<Symbol> sym = symbol();
		if (sym != null)
			return sym.enclosing();
		else
			return null;
	}

	public Test fallsThrough() {
		return Test.PASS_TEST;
	}

	public Test containsBreak() {
		return Test.FAIL_TEST;
	}

	public boolean conforms(ref<Node> other) {
		return false;
	}

	public abstract ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext);

	public ref<Node> foldConditional(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		int priorLength = compileContext.liveSymbolCount();
		ref<Node> n = fold(tree, false, compileContext);
		if (priorLength < compileContext.liveSymbolCount()) {
			ref<Node>[] destructors;
			for (;;) {
				ref<Node> n = compileContext.popLiveTemp(priorLength);
				if (n == null)
					break;
				destructors.append(n);
			}
			if (destructors.length() > 0) {
				ref<NodeList> destructorList = tree.newNodeList(destructors);
				ref<Node> d = tree.newDestructorList(destructorList, _location);
				ref<Node> resolution = tree.newBinary(Operator.LEFT_COMMA, n, d, _location);
				resolution.type = n.type;
				return resolution;
			}
		}
		return n;
	}
	
	ref<Node> createMethodCall(ref<Node> object, string functionName, ref<SyntaxTree> tree, ref<CompileContext> compileContext, ref<Node>... arguments) {
		CompileString name(functionName);
		ref<Type> objType = object.type.indirectType(compileContext);
		
		if (objType == null)
			objType = object.type;
		ref<Symbol> sym = objType.lookup(&name, compileContext);
		if (sym == null || sym.class != Overload) {
			add(MessageId.UNDEFINED, compileContext.pool(), name);
			return this;
		}
		ref<OverloadInstance> oi = (*ref<Overload>(sym).instances())[0];
		ref<Selection> method = tree.newSelection(object, oi, false, location());
		method.type = oi.type();
		ref<NodeList> args = tree.newNodeList(arguments);
		ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
		call.type = type;
		return call;
	}
	
	ref<OverloadInstance> getOverloadInstance(ref<Type> objType, string functionName, ref<CompileContext> compileContext) {
		CompileString name(functionName);
		ref<Symbol> sym = objType.lookup(&name, compileContext);
		if (sym == null || sym.class != Overload) {
			add(MessageId.UNDEFINED, compileContext.pool(), name);
			return null;
		}
		return (*ref<Overload>(sym).instances())[0];
	}
	
	public long foldInt(ref<Target> target, ref<CompileContext> compileContext) {
		print(0);
		assert(false);
		return 0;
	}

	public ref<NodeList> treeToList(ref<NodeList> next, ref<SyntaxTree> tree) {
		if (_op == Operator.SEQUENCE) {
			ref<Binary> seq = ref<Binary>(this);
			return seq.left().treeToList(seq.right().treeToList(next, tree), tree);
		} else {
			ref<NodeList> nl = tree.newNodeList(this);
			nl.next = next;
			return nl;
		}
	}

	public string, boolean dottedName() {
		string output;
		boolean result;
		ref<CompileString> identifier;
		switch (_op) {
		case	DOT:
			ref<Selection> s = ref<Selection>(this);
			(output, result) = s.left().dottedName();
			if (!result)
				return null, false;
			output.append(".");
			identifier = s.identifier();
			break;
			
		case	IDENTIFIER:
			ref<Identifier> id = ref<Identifier>(this);
			identifier = id.identifier();
			break;

		default:
			return null, false;
		}
		output.append(identifier.data, identifier.length);
		return output, true;
	}

	public ref<Namespace> makeNamespaces(ref<Scope> domainScope, ref<CompileContext> compileContext) {
		return null;
	}

	public ref<Namespace> getNamespace(ref<Scope> domainScope, ref<CompileContext> compileContext) {
		assert(false);
		return null;
	}

	public ref<Type> unwrapTypedef(Operator context, ref<CompileContext> compileContext) {
		if (type == null)
			assignDeclarationTypes(compileContext);
		if (deferAnalysis())
			return type;
		if (_op == Operator.UNWRAP_TYPEDEF)
			return type;
		if (type == null)
			print(0);
		if (type.family() == TypeFamily.TYPEDEF) {		// if (type instanceof TypedefType)
			ref<TypedefType> tp = ref<TypedefType>(type);
			if (context != Operator.INTERFACE || tp.wrappedType().family() == TypeFamily.INTERFACE)
				return tp.wrappedType();
		} else if (type.family() == TypeFamily.CLASS_VARIABLE) {
			return compileContext.arena().builtInType(TypeFamily.CLASS_DEFERRED);
		}
		switch (context) {
		case CLASS:
			add(MessageId.NOT_A_TYPE, compileContext.pool());
			break;
			
		case INTERFACE:
			add(MessageId.NOT_AN_INTERFACE, compileContext.pool());
			break;
			
		default:
			print(0);
			assert(false);
		}
		return compileContext.errorType();
	}

	public boolean widensTo(ref<Type> other, ref<CompileContext> compileContext) {
		assert(false);
		return false;
	}

	public ref<Node> convertSmallIntegralTypes(ref<CompileContext> compileContext) {
		if (!deferAnalysis()) {
			ref<Type> t;
			switch (type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	SIGNED_16:
				t = compileContext.arena().builtInType(TypeFamily.SIGNED_32);
				return coerce(compileContext.tree(), t, false, compileContext);

			case	VAR:
			case	BOOLEAN:
			case	ADDRESS:
			case	FUNCTION:
			case	CLASS:
			case	REF:
			case	POINTER:
			case	STRING:
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	FLOAT_32:
			case	FLOAT_64:
			case	ENUM:
			case	FLAGS:
			case	TYPEDEF:
			case	SHAPE:
			case	CLASS_VARIABLE:
				break;

			default:
				print(0);
				assert(false);
			}
		}
		return this;
	}

	public ref<NodeList> assignMultiReturn(ref<NodeList> returnType, ref<CompileContext> compileContext) {
		if (_op == Operator.SEQUENCE) {
			ref<Binary> b = ref<Binary>(this);
			ref<NodeList> nl = b.left().assignMultiReturn(returnType, compileContext);
			if (b.left().deferAnalysis()) {
				type = b.left().type;
				return null;
			}
			if (nl == null) {
				add(MessageId.TOO_MANY_RETURN_ASSIGNMENTS, compileContext.pool());
				type = compileContext.errorType();
				return null;
			}
			b.right().assignMultiReturn(nl, compileContext);
			return nl.next;
		} else {
			if (!isLvalue()) {
				add(MessageId.LVALUE_REQUIRED, compileContext.pool());
				type = compileContext.errorType();
				return null;
			}
			if (!returnType.node.type.equals(type)) {
				add(MessageId.CANNOT_CONVERT, compileContext.pool());
			}
			return returnType.next;
		}
	}

	public boolean canCoerce(ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
		return type.widensTo(newType, compileContext);
	}

	public ref<Node> coerce(ref<SyntaxTree> tree, TypeFamily newType, boolean explicitCast, ref<CompileContext> compileContext) {
		return coerce(tree, compileContext.arena().builtInType(newType), explicitCast, compileContext);
	}

	public ref<Node> coerce(ref<SyntaxTree> tree, ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
		if (type == null)
			print(0);
		if (type.equals(newType))
			return this;
		if (canCoerce(newType, explicitCast, compileContext))
			return tree.newCast(newType, this);
		else {
			add(MessageId.CANNOT_CONVERT, compileContext.pool());
			type = compileContext.errorType();
			return this;
		}
	}

	public ref<Unary> getProperEllipsis() {
		if (op() == Operator.ELLIPSIS)
			return ref<Unary>(this);
		if (op() == Operator.BIND) {
			ref<Binary> bind = ref<Binary>(this);
			return bind.left().getProperEllipsis();
		}
		return null;
	}

	public void add(MessageId messageId, ref<MemoryPool> pool, CompileString... args) {
		string message = formatMessage(messageId, args);
		_commentary = pool.newCommentary(_commentary, messageId, message);
	}

	public void getMessageList(ref<Message[]> output) {
		traverse(Traversal.IN_ORDER, getMessage, output);
	}

	public int countMessages() {
		int count = 0;
		traverse(Traversal.PRE_ORDER, countMessage, &count);
		return count;
	}

	public boolean deferGeneration() {
		if (deferAnalysis())
			return true;
		return _commentary != null;
	}
	
	public boolean deferAnalysis() {
		if (type == null)
			return false;
		return type.deferAnalysis();
	}

	public boolean isLvalue() {
		switch (_op) {
		case	IDENTIFIER:
		case	DOT:
		case	INDIRECT:
		case	SUBSCRIPT:
		case	VARIABLE:
			return true;

		default:
			return false;
		}
		return false;
	}
	
	public boolean isSimpleLvalue() {
		switch (_op) {
		case	IDENTIFIER:
		case	VARIABLE:
		case	ARRAY_AGGREGATE:
			return true;

		default:
			return false;
		}
		return false;
	}
	
	// Debugging API
	
	public void print(int indent) {
		assert(false);
	}

	public void printBasic(int indent) {
		string name = " ";//this.class.name();

		for (ref<Commentary> comment = _commentary; comment != null; comment = comment.next())
			comment.print(indent + INDENT);
		printf("%*.*c%p %s::%s", indent, indent, ' ', this, name, string(_op));
		if (type != null)
			printf(" type %s", type.signature());
		if (register != 0)
			printf(" reg %d", int(register));
		if (nodeFlags != 0)
			printf(" nodeFlags %x", int(nodeFlags));
		if (sethi != 0)
			printf(" sethi %d", sethi);
	}


	public Location location() { 
		return _location; 
	}
	
	public ref<Commentary> commentary() {
		return _commentary; 
	}

	boolean assignTypesBoundary() {
		switch (_op) {
		case	ABSTRACT:
		case	ADD:
		case	ADD_ASSIGN:
		case	ADD_REDUCE:
		case	ADDRESS:
		case	AND:
		case	AND_ASSIGN:
		case	ANNOTATED:
		case	ANNOTATION:
		case	ASSIGN:
		case	BIND:
		case	BIT_COMPLEMENT:
		case	BLOCK:
		case	BREAK:
		case	BYTES:
		case	CALL:
		case	CALL_DESTRUCTOR:
		case	CASE:
		case	CAST:
		case	CATCH:
		case	CHARACTER:
		case	CLASS:
		case	CLASS_DECLARATION:
		case	CLASS_OF:
		case	CLASS_TYPE:
		case	CONDITIONAL:
		case	CONTINUE:
		case	DECLARATION:
		case	DECLARE_NAMESPACE:
		case	DECREMENT_AFTER:
		case	DECREMENT_BEFORE:
		case	DEFAULT:
		case	DELETE:
		case	DIVIDE:
		case	DIVIDE_ASSIGN:
		case	DO_WHILE:
		case	DOT:
		case	ELLIPSIS:
		case	EMPTY:
		case	ENUM:
		case	ENUM_DECLARATION:
		case	EQUALITY:
		case	EXCLUSIVE_OR:
		case	EXCLUSIVE_OR_ASSIGN:
		case	EXPRESSION:
		case	FALSE:
		case	FLAGS:
		case	FLAGS_DECLARATION:
		case	FLOATING_POINT:
		case	FOR:
		case	GREATER:
		case	GREATER_EQUAL:
		case	IDENTIFIER:
		case	IF:
		case	IMPORT:
		case	INCREMENT_AFTER:
		case	INCREMENT_BEFORE:
		case	INDIRECT:
		case	INITIALIZE:
		case	INTEGER:
		case	INTERFACE_DECLARATION:
		case	LABEL:
		case	LEFT_SHIFT:
		case	LEFT_SHIFT_ASSIGN:
		case	LESS:
		case	LESS_EQUAL:
		case	LESS_GREATER:
		case	LESS_GREATER_EQUAL:
		case	LOCK:
		case	LOGICAL_AND:
		case	LOGICAL_OR:
		case	MONITOR_DECLARATION:
		case	MULTIPLY:
		case	MULTIPLY_ASSIGN:
		case	NAMESPACE:
		case	NEGATE:
		case	NEW:
		case	NOT:
		case	NOT_EQUAL:
		case	NOT_GREATER:
		case	NOT_GREATER_EQUAL:
		case	NOT_LESS:
		case	NOT_LESS_EQUAL:
		case	NOT_LESS_GREATER:
		case	NOT_LESS_GREATER_EQUAL:
		case	NULL:
		case	OBJECT_AGGREGATE:
		case	OR:
		case	OR_ASSIGN:
		case	PLACEMENT_NEW:
		case	PRIVATE:
		case	PROTECTED:
		case	PUBLIC:
		case	REMAINDER:
		case	REMAINDER_ASSIGN:
		case	RETURN:
		case	RIGHT_SHIFT:
		case	RIGHT_SHIFT_ASSIGN:
		case	SCOPED_FOR:
		case	SEQUENCE:
		case	STATIC:
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
		case	VARIABLE:
		case	VECTOR_OF:
		case	WHILE:
			break;
			
		case	UNIT:
			return true;
			
		default:
			print(0);
			assert(false);
		}
		return false;
	}
	
	boolean definesScope() {
		return false;
	}
 
	public boolean isConstant() {
		return false;
	}

	void assignDeclarationTypes(ref<CompileContext> compileContext) {
		assignTypes(compileContext);
	}
	
	void assignTypes(ref<CompileContext> compileContext) {
		assert(false);
	}
}

private TraverseAction countMessage(ref<Node> n, address data) {
	if (n.commentary() != null) {
		ref<int> countp = ref<int>(data);
		for (ref<Commentary> c = n.commentary(); c != null; c = c.next())
			(*countp)++;
	}
	return TraverseAction.CONTINUE_TRAVERSAL;
}

private TraverseAction getMessage(ref<Node> n, address data) {
	ref<Message[]> output = ref<Message[]>(data);
	Message m;

	m.location = n.location();
	for (ref<Commentary> comment = n.commentary(); comment != null; comment = comment.next()) {
		m.commentary = comment;
		output.append(m);
	}
	return TraverseAction.CONTINUE_TRAVERSAL;
}

class NodeList {
	public ref<NodeList> next;
	public ref<Node> node;

	boolean traverse(Node.Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		for (ref<NodeList> nl = this; nl != null; nl = nl.next)
			if (!nl.node.traverse(t, func, data))
				return false;
		return true;
	}

	public ref<NodeList> last() {
		for (ref<NodeList> nl = this; ; nl = nl.next) {
			if (nl.next == null)
				return nl;
		}
	}
	
	public ref<NodeList> clone(ref<SyntaxTree> tree) {
		ref<Node> n = node != null ? node.clone(tree) : null;
		ref<NodeList> nl = tree.newNodeList(n);
		if (next != null)
			nl.next = next.clone(tree);
		return nl;
	}

	public ref<NodeList> cloneRaw(ref<SyntaxTree> tree) {
		ref<Node> n = node != null ? node.cloneRaw(tree) : null;
		ref<NodeList> nl = tree.newNodeList(n);
		if (next != null)
			nl.next = next.cloneRaw(tree);
		return nl;
	}

	boolean reverse(Node.Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		if (next != null) {
			if (!next.reverse(t, func, data))
				return false;
		}
		return node.traverse(t, func, data);
	}
	
	boolean hasBindings() {
		for (ref<NodeList> nl = this; nl != null; nl = nl.next)
			if (nl.node.op() == Operator.BIND || nl.node.op() == Operator.FUNCTION)
				return true;
		return false;
	}
	
	void markErroneousBindings(ref<CompileContext> compileContext) {
		for (ref<NodeList> nl = this; nl != null; nl = nl.next) {
			if (nl.node.op() == Operator.BIND) {
				ref<Identifier> id = ref<Identifier>(ref<Binary>(nl.node).right());
				nl.node.add(MessageId.INVALID_BINDING, compileContext.pool(), id.value());
				nl.node.type = compileContext.errorType();
			} else if (nl.node.op() == Operator.FUNCTION) {
				ref<Identifier> id = ref<FunctionDeclaration>(nl.node).name();
				nl.node.add(MessageId.INVALID_BINDING, compileContext.pool(), id.value());
				nl.node.type = compileContext.errorType();
			}
		}
	}
	
	void print(int indent) {
		for (ref<NodeList> nl = this; nl != null; nl = nl.next)
			nl.node.print(indent);
	}
}

MessageId[Operator] typeNotAllowed = [
	ADD: 					MessageId.INVALID_ADD,
	ADD_ASSIGN: 			MessageId.INVALID_ADD,
	ADD_REDUCE: 			MessageId.INVALID_ADD,
	AND: 					MessageId.INVALID_AND,
	AND_ASSIGN: 			MessageId.INVALID_AND,
	BIT_COMPLEMENT: 		MessageId.INVALID_BIT_COMPLEMENT,
	DIVIDE: 				MessageId.INVALID_DIVIDE,
	DIVIDE_ASSIGN: 			MessageId.INVALID_DIVIDE,
	EQUALITY: 				MessageId.INVALID_COMPARE,
	EXCLUSIVE_OR: 			MessageId.INVALID_XOR,
	EXCLUSIVE_OR_ASSIGN:	MessageId.INVALID_XOR,
	GREATER: 				MessageId.INVALID_COMPARE,
	GREATER_EQUAL: 			MessageId.INVALID_COMPARE,
	INDIRECT: 				MessageId.INVALID_INDIRECT,
	IDENTITY:				MessageId.INVALID_COMPARE,
	LESS: 					MessageId.INVALID_COMPARE,
	LESS_EQUAL: 			MessageId.INVALID_COMPARE,
	LESS_GREATER: 			MessageId.INVALID_COMPARE,
	LESS_GREATER_EQUAL:		MessageId.INVALID_COMPARE,
	MULTIPLY: 				MessageId.INVALID_MULTIPLY,
	MULTIPLY_ASSIGN:		MessageId.INVALID_MULTIPLY,
	NEGATE: 				MessageId.INVALID_NEGATE,
	NOT_EQUAL: 				MessageId.INVALID_COMPARE,
	NOT_GREATER:			MessageId.INVALID_COMPARE,
	NOT_GREATER_EQUAL: 		MessageId.INVALID_COMPARE,
	NOT_IDENTITY: 			MessageId.INVALID_COMPARE,
	NOT_LESS: 				MessageId.INVALID_COMPARE,
	NOT_LESS_EQUAL: 		MessageId.INVALID_COMPARE,
	NOT_LESS_GREATER: 		MessageId.INVALID_COMPARE,
	NOT_LESS_GREATER_EQUAL: MessageId.INVALID_COMPARE,
	OR: 					MessageId.INVALID_OR,
	OR_ASSIGN: 				MessageId.INVALID_OR,
	REMAINDER: 				MessageId.INVALID_REMAINDER,
	REMAINDER_ASSIGN: 		MessageId.INVALID_REMAINDER,
	SUBSCRIPT: 				MessageId.INVALID_SUBSCRIPT,
	SUBTRACT: 				MessageId.INVALID_SUBTRACT,
	SUBTRACT_ASSIGN:		MessageId.INVALID_SUBTRACT,
	UNARY_PLUS: 			MessageId.INVALID_UNARY_PLUS,
	VARIABLE:				MessageId.INVALID_UNARY_PLUS,
	SWITCH: 				MessageId.INVALID_SWITCH,
];

fill();

private void fill() {
//	text.memDump(&typeNotAllowed, typeNotAllowed.bytes);
	typeNotAllowed.resize(Operator.MAX_OPERATOR);
	for (int i = 0; i < int(Operator.MAX_OPERATOR); i++) {
		if (typeNotAllowed[Operator(i)] == MessageId(0))
			typeNotAllowed[Operator(i)] = MessageId.MAX_MESSAGE;
	}
}

int, boolean unescapeParasolCharacter(string str) {
	if (str.length() == 0)
		return 0, false;
	int i = 0;
	if (str[i] == '\\') {
		if (i == str.length() - 1)
			return 0, false;
		else {
			int v;
			i++;
			switch (str[i]) {
			case 'a':	return '\a', ++i >= str.length();
			case 'b':	return '\b', ++i >= str.length();
			case 'f':	return '\f', ++i >= str.length();
			case 'n':	return '\n', ++i >= str.length();
			case 'r':	return '\r', ++i >= str.length();
			case 't':	return '\t', ++i >= str.length();
			case 'u':
			case 'U':
				return 0, false;	// temporarily reject these.
			case 'v':	return '\v', ++i >= str.length();
			case 'x':
			case 'X':
				i++;;
				if (i >= str.length())
					return 0, false;
				if (!str[i].isHexDigit())
					return 0, false;
				v = 0;
				do {
					v <<= 4;
					if (v > 0xff)
						return 0, false;
					if (str[i].isDigit())
						v += str[i] - '0';
					else
						v += 10 + str[i].toLowercase() - 'a';
					i++;
				} while (i < str.length() && str[i].isHexDigit());
				return v, ++i >= str.length();

			case '0':
				i++;
				if (i >= str.length())
					return 0, false;
				if (!str[i].isOctalDigit())
					return 0, false;
				v = 0;
				do {
					v <<= 3;
					if (v > 0xff)
						return 0, false;
					v += str[i] - '0';
					i++;
				} while (i < str.length() && str[i].isOctalDigit());
				return v, true;

			default:	
				return str[i], ++i >= str.length();
			}
			return 0, false;
		}
	} else
		return str[i], ++i >= str.length();
}

ref<Node> foldVoidContext(ref<Node> expression, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
	if (expression.deferAnalysis())
		return expression;
	switch (expression.op()) {
	case	CALL:
	case	AND_ASSIGN:
	case	OR_ASSIGN:
	case	EXCLUSIVE_OR_ASSIGN:
	case	ADD_ASSIGN:
	case	SUBTRACT_ASSIGN:
	case	MULTIPLY_ASSIGN:
	case	DIVIDE_ASSIGN:
	case	REMAINDER_ASSIGN:
	case	LEFT_SHIFT_ASSIGN:
	case	RIGHT_SHIFT_ASSIGN:
	case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
	case	INCREMENT_BEFORE:
	case	DECREMENT_BEFORE:
	case	DECLARATION:
	case	EMPTY:
	case	DELETE:
	case	CONDITIONAL:
	case	PLACEMENT_NEW:
	case	CALL_DESTRUCTOR:
	case	IF:
		break;
		
	case	ASSIGN:
		b = ref<Binary>(expression);
		if (b.left().op() == Operator.SEQUENCE) {
			ref<Node> destinations = foldMultiValueReturn(b.left(), tree, compileContext);
			ref<Node> x = b.right().fold(tree, false, compileContext);
			assert(x.op() == Operator.SEQUENCE);
			b = ref<Binary>(x);
			if (b.right().op() != Operator.VARIABLE) {
				if (expression.deferGeneration())
					break;
				expression.print(0);
				printf("---- x:\n");
				x.print(4);
				printf("----destinations:\n");
				destinations.print(4);
			}
			assert(b.right().op() == Operator.VARIABLE);
			ref<Reference> r = ref<Reference>(b.right());
			ref<Variable> v = r.variable();
			return foldMultiReturn(b.left(), destinations, v, tree, compileContext);
		}
		break;
		
	case	INCREMENT_AFTER:
		ref<Unary> u = ref<Unary>(expression);
		expression = tree.newUnary(Operator.INCREMENT_BEFORE, u.operand(), u.operand().location());
		expression.type = u.operand().type;
		break;
		
	case	DECREMENT_AFTER:
		u = ref<Unary>(expression);
		expression = tree.newUnary(Operator.DECREMENT_BEFORE, u.operand(), u.operand().location());
		expression.type = u.operand().type;
		break;
		
	case	INTEGER:
		expression = tree.newLeaf(Operator.EMPTY, expression.location());
		expression.type = compileContext.arena().builtInType(TypeFamily.VOID);
		return expression;
		
	case	SEQUENCE:
		ref<Binary> b = ref<Binary>(expression);
		ref<Node> left = foldVoidContext(b.left(), tree, compileContext);
		ref<Node> right = foldVoidContext(b.right(), tree, compileContext);
		expression = tree.newBinary(Operator.SEQUENCE, left, right, b.location());
		expression.type = b.type;
		return expression;
		
	default:
		expression.print(0);
		assert(false);
	}
//	expression.print(0);
	return expression.fold(tree, true, compileContext);
}

private ref<Node> foldMultiValueReturn(ref<Node> left, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
	if (left.op() == Operator.SEQUENCE) {
		ref<Binary> b = ref<Binary>(left);
		left = foldMultiValueReturn(b.left(), tree, compileContext);
		ref<Node> right = foldMultiValueReturn(b.right(), tree, compileContext);
		if (left != b.left() || right != b.right()) {
			ref<Binary> n = tree.newBinary(Operator.SEQUENCE, left, right, b.location());
			n.type = b.type;
			return n;
		} else
			return b;
	} else
		return left.fold(tree, false, compileContext);
}
