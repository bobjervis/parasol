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

import parasol:process;

enum Operator {
	// SyntaxError
	SYNTAX_ERROR,
	// Binary
	SUBSCRIPT,
	SEQUENCE,
	DIVIDE,
	REMAINDER,
	MULTIPLY,
	ADD,
	SUBTRACT,
	AND,
	OR,
	EXCLUSIVE_OR,
	ASSIGN,
	DIVIDE_ASSIGN,
	REMAINDER_ASSIGN,
	MULTIPLY_ASSIGN,
	ADD_ASSIGN,
	SUBTRACT_ASSIGN,
	AND_ASSIGN,
	OR_ASSIGN,
	EXCLUSIVE_OR_ASSIGN,
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
	WHILE,
	DO_WHILE,
	SWITCH,
	CASE,
	BIND,
	TEMPLATE_INSTANCE,
	DECLARATION,
	CLASS_DECLARATION,
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
	CLASS_OF,
	INCREMENT_BEFORE,
	DECREMENT_BEFORE,
	INCREMENT_AFTER,
	DECREMENT_AFTER,
	EXPRESSION,
	RETURN,
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
	THIS,
	TRUE,
	FALSE,
	NULL,
	CLASS_TYPE,
	ENUM_TYPE,
	VACATE_ARGUMENT_REGISTERS,
	// Constant
	INTEGER,
	FLOATING_POINT,
	CHARACTER,
	STRING,
	// Identifier
	IDENTIFIER,
	//Reference
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
	// Map
	MAP,
	// Ternary
	CONDITIONAL,
	IF,
	// Function
	FUNCTION,
	// Call
	CALL,
	ANNOTATION,
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

// Global 'flags' values
public byte BAD_CONSTANT = 0x01;
public byte PUSH_OUT_PARAMETER = 0x08;

class SyntaxTree {
	private ref<Block> _root;
	private ref<MemoryPool> _pool;
	private ref<Scanner> _scanner;
	private string _filename;
	
	public SyntaxTree() {
		_pool = new MemoryPool();
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
			_root = newBlock(Operator.UNIT, Location.OUT_OF_FILE);
			_root.add(MessageId.FILE_NOT_READ, _pool);
		}
	}

	public ref<Block> newBlock(Operator op, Location location) {
		//void *block = _pool.alloc(sizeof (Block));
		return new Block(op, location);
	}

	public ref<Class> newClass(ref<Identifier> name, ref<Node> extendsClause, Location location) {
		//void *block = _pool.alloc(sizeof (Class));
		return new Class(name, extendsClause, location);
	}

	public ref<Template> newTemplate(ref<Identifier> name, Location location) {
		//void *block = _pool.alloc(sizeof (Template));
		return new Template(name, this, location);
	}

	public ref<Reference> newReference(ref<Variable> v, boolean definition, Location location) {
		//void *block = _pool.alloc(sizeof (Reference));
		return new Reference(v, 0, definition, location);
	}
	
	public ref<Reference> newReference(ref<Variable> v, int offset, boolean definition, Location location) {
		//void *block = _pool.alloc(sizeof (Reference));
		return new Reference(v, offset, definition, location);
	}
	
	public ref<Identifier> newIdentifier(ref<Node> annotation, CompileString value, Location location) {
		//void *block = _pool.alloc(sizeof (Identifier) + value.size());
		pointer<byte> cp = pointer<byte>(allocz(value.length));
		memcpy(cp, value.data, value.length);
		CompileString v;
		v.data = cp;
		v.length = value.length;
		return new Identifier(annotation, v, location);
	}

	public ref<Import> newImport(ref<Identifier> importedSymbol, ref<Ternary> namespaceNode, Location location) {
		//void *block = _pool.alloc(sizeof (Import));
		return new Import(importedSymbol, namespaceNode, location);
	}

	public ref<Map> newMap(ref<Node> valueType, ref<Node> keyType, ref<Node> seed, Location location) {
		//void *block = _pool.alloc(sizeof (Map));
		return new Map(valueType, keyType, seed, location);
	}

	public ref<Binary> newDeclaration(ref<Node> left, ref<Node> right, Location location) {
		return newBinary(Operator.DECLARATION, left.rewriteDeclarators(this), right, location);
	}

	public ref<Binary> newBinary(Operator op, ref<Node> left, ref<Node> right, Location location) {
		//void *block = _pool.alloc(sizeof (Binary));
		return new Binary(op, left, right, location);
	}

	public ref<Unary> newUnary(Operator op, ref<Node> operand, Location location) {
		//void *block = _pool.alloc(sizeof (Unary));
		return new Unary(op, operand, location);
	}

	public ref<Unary> newCast(ref<Type> type, ref<Node> operand) {
		ref<Unary> u = newUnary(Operator.CAST, operand, operand.location());
		u.type = type;
		return u;
	}
	
	public ref<Ternary> newTernary(Operator op, ref<Node> left, ref<Node> middle, ref<Node> right, Location location) {
		//void *block = _pool.alloc(sizeof (Ternary));
		return new Ternary(op, left, middle, right, location);
	}

	public ref<Loop> newLoop(Location location) {
		//void *block = _pool.alloc(sizeof (Loop));
		return new Loop(location);
	}

	public ref<For> newFor(Operator op, ref<Node> initializer, ref<Node> test, ref<Node> increment, ref<Node> body, Location location) {
		//void *block = _pool.alloc(sizeof (For));
		return new For(op, initializer, test, increment, body, location);
	}

	public ref<Selection> newSelection(ref<Node> left, CompileString name, Location location) {
		//void *block = _pool.alloc(sizeof (Selection) + name.size());
		pointer<byte> cp = pointer<byte>(allocz(name.length));
		memcpy(cp, name.data, name.length);
		CompileString n;
		n.data = cp;
		n.length = name.length;
		return new Selection(left, n, location);
	}

	public ref<Selection> newSelection(ref<Node> left, ref<Symbol> symbol, Location location) {
		//void *block = _pool.alloc(sizeof (Selection) + name.size());
		return new Selection(left, symbol, location);
	}

	public ref<Return> newReturn(ref<NodeList> expressions, Location location) {
		//void *block = _pool.alloc(sizeof (Return));
		return new Return(expressions, location);
	}

	public ref<Function> newFunction(Function.Category functionCategory, ref<Node> returnType, ref<Identifier> name, ref<NodeList> arguments, Location location) {
		//void *block = _pool.alloc(sizeof (Function));
		return new Function(functionCategory, returnType, name, arguments, this, location);
	}

	public ref<Call> newCall(Operator op, ref<Node> target, ref<NodeList> arguments, Location location) {
		//void *block = _pool.alloc(sizeof (Call));
		return new Call(op, target, arguments, location);
	}

	public ref<Call> newCall(ref<OverloadInstance> symbol, CallCategory category, ref<Node> target, ref<NodeList> arguments, Location location) {
		//void *block = _pool.alloc(sizeof (Call));
		return new Call(symbol, category, target, arguments, location);
	}

	public ref<EllipsisArguments> newEllipsisArguments(ref<NodeList> arguments, Location location) {
		return new EllipsisArguments(arguments, location);
	}
	
	public ref<StackArgumentAddress> newStackArgumentAddress(int offset, Location location) {
		return new StackArgumentAddress(offset, location);
	}
	
	public ref<Leaf> newLeaf(Operator op, Location location) {
		//void *block = _pool.alloc(sizeof (Leaf));
		return new Leaf(op, location);
	}

	public ref<Constant> newConstant(Operator op, CompileString value, Location location) {
		//void *block = _pool.alloc(sizeof (Constant) + value.size());
		pointer<byte> cp = pointer<byte>(allocz(value.length));
		memcpy(cp, value.data, value.length);
		CompileString v;
		v.data = cp;
		v.length = value.length;
		return new Constant(op, v, location);
	}

	public ref<SyntaxError> newSyntaxError(Location location) {
		//void *block = _pool.alloc(sizeof (SyntaxError));
		return new SyntaxError(location);
	}

	public ref<NodeList> newNodeList(ref<Node>... nodes) {
		if (nodes.length() == 0)
			return null;
		ref<NodeList> list;
		for (int i = nodes.length() - 1; i >= 0; i--) {
			ref<NodeList> nl = ref<NodeList>(_pool.alloc(NodeList.bytes));
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

class Binary extends Node {
	private ref<Node> _left;
	private ref<Node> _right;

	Binary(Operator op, ref<Node> left, ref<Node> right, Location location) {
		super(op, location);
		_left = left;
		_right = right;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;

		// These operators are 'binary' but have slightly different traversal rules from the
		// ordinary binary operators

		Traversal t_this = t;
		switch (op()) {
		case	CASE:
		case	DO_WHILE:
		case	SWITCH:
		case	WHILE:
		case	DECLARATION:
		case	CLASS_DECLARATION:
		case	ENUM_DECLARATION:
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
			if (!_right.traverse(t, func, data))
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
			if (!_right.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (!_left.traverse(t, func, data))
				return false;
			if (!_right.traverse(t, func, data))
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
			if (!_right.traverse(t, func, data))
				return false;
			if (!_left.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
			if (!_right.traverse(t, func, data))
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
			if (!_right.traverse(t, func, data))
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
		case	ANNOTATED:
			_right = _right.fold(tree, false, compileContext);
			return this;
			
		case	DECLARATION:
		case	ENUM_DECLARATION:
		case	CLASS_DECLARATION:
		case	WHILE:
		case	DO_WHILE:
		case	SWITCH:
		case	CASE:
		case	LEFT_SHIFT:
		case	LOGICAL_AND:
		case	LOGICAL_OR:
		case	BIND:
		case	DELETE:
			break;

		case	SEQUENCE:
			_left = _left.fold(tree, true, compileContext);
			_right = _right.fold(tree, voidContext, compileContext);
			return this;
			
		case	AND_ASSIGN:
		case	OR_ASSIGN:
		case	EXCLUSIVE_OR_ASSIGN:
		case	MULTIPLY_ASSIGN:
		case	DIVIDE_ASSIGN:
		case	REMAINDER_ASSIGN:
		case	LEFT_SHIFT_ASSIGN:
		case	RIGHT_SHIFT_ASSIGN:
		case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
			if (type.family() == TypeFamily.VAR)
				return processAssignmentOp(tree, voidContext, compileContext);
			if (_left.op() == Operator.SUBSCRIPT) {
				ref<Node> element = ref<Binary>(_left).subscriptModify(tree, compileContext);
				if (element != null)
					_left = element;
			}
			break;

		case	LEFT_SHIFT:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left, "leftShift", tree, compileContext, _right);
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	RIGHT_SHIFT:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "rightShift", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	UNSIGNED_RIGHT_SHIFT:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "unsignedRightShift", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	AND:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "and", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	DIVIDE:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "divide", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	REMAINDER:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "remainder", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	EXCLUSIVE_OR:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "exclusiveOr", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	OR:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "or", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	INITIALIZE:
			if (_right.op() == Operator.CALL) {
				ref<Call> constructor = ref<Call>(_right);
				if (constructor.category() == CallCategory.CONSTRUCTOR) {
					ref<Node> adr = tree.newUnary(Operator.ADDRESS, _left, _left.location());
					adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
					constructor.setConstructorMemory(adr, tree);
					return constructor.fold(tree, true, compileContext);
				}
			}
			switch (type.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	ENUM:
			case	ADDRESS:
			case	FUNCTION:
				break;
				
			case	CLASS:
				if (type.indirectType(compileContext) != null)
					break;

			case	VAR:
			case	STRING:
				ref<OverloadInstance> oi = type.copyConstructor(compileContext);
				if (oi != null) {
					ref<Node> adr = tree.newUnary(Operator.ADDRESS, _left, location());
					adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> constructor = tree.newCall(oi, CallCategory.CONSTRUCTOR, adr, args, location());
					constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
					return constructor.fold(tree, true, compileContext);
				} else {
					ref<Node> result = foldClassCopy(tree, compileContext);
					if (result != null)
						return result;
				}
				break;
				
			default:
				print(0);
				assert(false);
			}
			break;
			
		case	NEW:
			assert(_left.op() == Operator.EMPTY);			// Don't allow memory allocators yet.
			if (_right.op() == Operator.CALL) {
				ref<Type> entityType = type.indirectType(compileContext);
				ref<Call> constructor = ref<Call>(_right);
				_right = tree.newLeaf(Operator.EMPTY, location());
				if (constructor.overload() == null)
					return this;
				ref<Variable> temp = compileContext.newVariable(type);
				ref<Reference> r = tree.newReference(temp, true, location());
				ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, this, location());
				defn.type = type;
				r = tree.newReference(temp, false, location());
				constructor.setConstructorMemory(r, tree);
				ref<Node> seq = tree.newBinary(Operator.SEQUENCE, defn, constructor, location());
				seq.type = compileContext.arena().builtInType(TypeFamily.VOID);
				if (voidContext)
					return seq.fold(tree, true, compileContext);
				r = tree.newReference(temp, false, location());
				seq = tree.newBinary(Operator.SEQUENCE, seq, r, location());
				seq.type = type;
				ref<Node> result = seq.fold(tree, false, compileContext);
				return result;
			} else {
				_right = tree.newLeaf(Operator.EMPTY, location());
				_right.type = compileContext.arena().builtInType(TypeFamily.VOID);
			}
			break;
			
		case	MULTIPLY:
			if (type.family() == TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "multiply", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			if (_left.class == Constant) {
				ref<Node> n = _right;
				_right = _left;
				_left = n;
			}
			break;
			
		case	EQUALITY:
		case	LESS:
		case	LESS_EQUAL:
		case	LESS_GREATER_EQUAL:
		case	NOT_EQUAL:
		case	NOT_LESS:
		case	NOT_LESS_EQUAL:
		case	NOT_LESS_GREATER_EQUAL:
		case	GREATER:
		case	GREATER_EQUAL:
		case	NOT_GREATER:
		case	NOT_GREATER_EQUAL:
		case	LESS_GREATER:
		case	NOT_LESS_GREATER:
			switch (_left.type.family()) {
			case	STRING:
			case	VAR:
				ref<Node> call = createMethodCall(_left, "compare", tree, compileContext, _right);
				call.type = compileContext.arena().builtInType(TypeFamily.SIGNED_32);
				_left = call.fold(tree, voidContext, compileContext);
				CompileString value("0");
				_right = tree.newConstant(Operator.INTEGER, value, location());
				_right.type = _left.type;
			}
			break;
			
		case	SUBSCRIPT:
			ref<Type> t = _left.type.indirectType(compileContext);
			if (t != null) {
				switch (t.size()) {
				case	1:
				case	2:
				case	4:
				case	8:
					break;
					
				default:
					string s;
					s.printf("%d", t.size());
					CompileString value(s);
					ref<Constant> c = tree.newConstant(Operator.INTEGER, value, location());
					ref<Binary> b = tree.newBinary(Operator.MULTIPLY, _right.fold(tree, false, compileContext), c, location());
					b.type = _right.type;
					c.type = _right.type;
					b = tree.newBinary(Operator.ADD, _left.fold(tree, false, compileContext), b, location());
					b.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
					ref<Unary> u = tree.newUnary(Operator.INDIRECT, b, location());
					u.type = type;
					return u;
				}
			} else if (_left.type.isVector(compileContext) ||
				_left.type.isMap(compileContext)) {
				CompileString name("get");
				
				ref<Symbol> sym = _left.type.lookup(&name, compileContext);
				if (sym == null || sym.class != Overload) {
					add(MessageId.UNDEFINED, compileContext.pool(), name);
					break;
				}
				ref<Overload> o = ref<Overload>(sym);
				ref<OverloadInstance> oi = o.instances()[0];
				ref<Selection> method = tree.newSelection(_left, oi, location());
				method.type = oi.type();
				ref<NodeList> args = tree.newNodeList(_right);
				ref<Call> call = tree.newCall(oi, null, method, args, location());
				call.type = type;
				return call.fold(tree, false, compileContext);
/*
			} else if (x.left().type.family() == TypeFamily.STRING) {
				generate(x.left(), target, compileContext);
				generate(x.right(), target, compileContext);
				target.byteCode(ByteCodes.CHAR_AT);
				target.popSp(address.bytes);
			} else {
				generateSubscript(x, target, compileContext);
				if (!loadIndirect(x.type, target, compileContext))
					target.unfinished(tree, "subscript", compileContext);
*/
			}
			break;

		case	ADD_ASSIGN:
		case	SUBTRACT_ASSIGN:
			switch (type.family()) {
			case	CLASS:
				if (type.indirectType(compileContext) != null) {
					rewritePointerArithmetic(tree, compileContext);
					break;
				}
				
			default:
				if (_left.op() == Operator.SUBSCRIPT) {
					ref<Node> element = ref<Binary>(_left).subscriptModify(tree, compileContext);
					if (element != null)
						_left = element;
				}
				break;
				
			case	VAR:
				return processAssignmentOp(tree, voidContext, compileContext);
			}
			break;
			
		case	SUBTRACT:
			switch (type.family()) {
			case	CLASS:
				if (type.indirectType(compileContext) != null)
					rewritePointerArithmetic(tree, compileContext);
				break;
				
			case	VAR:
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "subtract", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;
			
		case	ADD:
			switch (type.family()) {
			case	STRING:
				ref<Node> n;
				ref<Variable> v;
				
				(n, v) = foldStringAddition(null, null, this, tree, compileContext);
				n = n.fold(tree, voidContext, compileContext);
				if (voidContext)
					return n;
				ref<Reference> r = tree.newReference(v, false, location());
				n = tree.newBinary(Operator.SEQUENCE, n, r, location());
				n.type = type;
				return n;
				
			case	CLASS:
				if (type.indirectType(compileContext) != null)
					rewritePointerArithmetic(tree, compileContext);
				else {
					printf("non-pointer add\n");
					print(0);
				}
				break;
				
			case	VAR:
				ref<Node> call = createMethodCall(_left, "add", tree, compileContext, _right);
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;
			
		case	ASSIGN:
			if (_left.op() == Operator.SEQUENCE) {
				print(0);
				assert(false);
			}
			if (_left.op() == Operator.SUBSCRIPT) {
				ref<Node> call = subscriptAssign(tree, compileContext);
				if (call != null)
					return call.fold(tree, voidContext, compileContext);
			}
			if (type == null) {
				print(0);
				assert(type != null);
			}
			switch (type.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	ENUM:
			case	ADDRESS:
			case	FUNCTION:
			case	TYPEDEF:
				break;
				
			case	CLASS:
				if (type.indirectType(compileContext) != null)
					break;

			case	STRING:
				ref<OverloadInstance> oi = type.assignmentMethod(compileContext);
				if (oi != null) {
					// This is the assignment method for this class!!!
					// (all strings go through here).
					ref<Selection> method = tree.newSelection(_left, oi, _left.location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> call = tree.newCall(oi, null, method, args, location());
					call.type = compileContext.arena().builtInType(TypeFamily.VOID);
					return call.fold(tree, voidContext, compileContext);
				} else {
					ref<Node> result = foldClassCopy(tree, compileContext);
					if (result != null)
						return result;
				}
				break;
				
			case	VAR:
				oi = type.assignmentMethod(compileContext);
				if (oi != null) {
					// This is the assignment method for this class!!!
					ref<Node> load;
					ref<Node> store;
					(load, store) = getLoadStore(tree, compileContext);
					ref<Selection> method = tree.newSelection(load, oi, _left.location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> call = tree.newCall(oi, null, method, args, location());
					call.type = compileContext.arena().builtInType(TypeFamily.VOID);
					if (voidContext)
						return call.fold(tree, voidContext, compileContext);
					else {
						ref<Node> asg = tree.newBinary(Operator.SEQUENCE, call, store, location());
						asg.type = type;
						return asg.fold(tree, false, compileContext);;
					}
				}
				break;
				
			case	VOID:
				if (_left.op() == Operator.SEQUENCE) {
					// Must be a multi-value assignment.
					_right = _right.fold(tree, false, compileContext);
					break;
				}
				
			default:
				print(0);
				assert(false);
			}
			break;
			
		default:
			print(0);
			assert(false);
		}
		if (_left == null) {
			printBasic(0);
			printf("\n    <null>\n");
			_right.print(4);
			assert(false);
		}
		_left = _left.fold(tree, false, compileContext);
		_right = _right.fold(tree, false, compileContext);
		return this;
	}
	
	private ref<Node> foldClassCopy(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		switch (type.size()) {
		case	1:
		case	2:
		case	4:
		case	8:
			return null;
		}
		_left = tree.newUnary(Operator.ADDRESS, _left.fold(tree, false, compileContext), location());
		_left.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
		_right = _right.fold(tree, false, compileContext);
		if (_right.op() != Operator.CLASS_COPY) {
			_right = tree.newUnary(Operator.ADDRESS, _right, location());
			_right.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
		}
		ref<Binary> copy = tree.newBinary(Operator.CLASS_COPY, _left, _right, location());
		copy.type = type;
		return copy;
	}
	
	private ref<Node> processAssignmentOp(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		ref<Node> load;
		ref<Node> store;
		(load, store) = getLoadStore(tree, compileContext);
		ref<Binary> b = tree.newBinary(stripAssignment(op()), load, _right, location());
		b.type = type;
		ref<Binary> asg = tree.newBinary(Operator.ASSIGN, store, b, location());
		asg.type = type;
		return asg.fold(tree, voidContext, compileContext);
	}
	
	private ref<Node>, ref<Node> getLoadStore(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		ref<Node> load;
		ref<Node> store;
		switch (_left.op()) {
		case	IDENTIFIER:
			return _left, _left.clone(tree);
			
		default:
			ref<Node> addr = tree.newUnary(Operator.ADDRESS, _left, location());
			addr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			ref<Variable> temp = compileContext.newVariable(addr.type);
			ref<Reference> r = tree.newReference(temp, true, location());
			ref<Node> asgTemp = tree.newBinary(Operator.ASSIGN, r, addr, location());
			asgTemp.type = addr.type;
			load = tree.newUnary(Operator.INDIRECT, asgTemp, location());
			r = tree.newReference(temp, false, location());
			store = tree.newUnary(Operator.INDIRECT, r, location());
			load.type = type;
			store.type = type;
		}
		return load, store;
	}
	
	private void rewritePointerArithmetic(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		ref<Type> t = type.indirectType(compileContext);
		if (t.size() > 1) {
			string s;
			s.printf("%d", t.size());
			CompileString value(s);
			ref<Constant> c = tree.newConstant(Operator.INTEGER, value, location());
			ref<Binary> b = tree.newBinary(Operator.MULTIPLY, _right, c, location());
			b.type = _right.type;
			c.type = _right.type;
			_right = b;
		}
		type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
		_right = tree.newCast(type, _right);
	}
	
	private ref<Node> subscriptAssign(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		ref<Binary> subscript = ref<Binary>(_left);
		if (subscript.left().type.isVector(compileContext) ||
			subscript.left().type.isMap(compileContext)) {
			CompileString name("set");
			
			ref<Symbol> sym = subscript.left().type.lookup(&name, compileContext);
			if (sym == null || sym.class != Overload) {
				subscript.add(MessageId.UNDEFINED, compileContext.pool(), name);
				return this;
			}
			ref<Overload> over = ref<Overload>(sym);
			ref<OverloadInstance> oi = over.instances()[0];
			ref<Selection> method = tree.newSelection(subscript.left(), oi, subscript.location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(subscript.right(), _right);
			ref<Call> call = tree.newCall(oi, null, method, args, location());
			call.type = compileContext.arena().builtInType(TypeFamily.VOID);
			return call;
		} else
			return null;
	}
	
	ref<Node> subscriptModify(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		if (_left.type.isVector(compileContext) ||
			_left.type.isMap(compileContext)) {
			CompileString name("elementAddress");
			
			ref<Symbol> sym = _left.type.lookup(&name, compileContext);
			if (sym == null || sym.class != Overload) {
				add(MessageId.UNDEFINED, compileContext.pool(), name);
				return this;
			}
			ref<Overload> over = ref<Overload>(sym);
			ref<OverloadInstance> oi = over.instances()[0];
			ref<Selection> method = tree.newSelection(_left, oi, location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(_right);
			ref<Call> call = tree.newCall(oi, null, method, args, location());
			call.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			ref<Node> indirect = tree.newUnary(Operator.INDIRECT, call, location());
			indirect.type = type;
			return indirect;
		} else
			return null;
	}
	
	public ref<Binary> clone(ref<SyntaxTree> tree) {
		ref<Node> left = _left != null ? _left.clone(tree) : null;
		ref<Node> right = _right != null ? _right.clone(tree) : null;
		return ref<Binary>(tree.newBinary(op(), left, right, location()).finishClone(this, tree.pool()));
	}

	public ref<Binary> cloneRaw(ref<SyntaxTree> tree) {
		ref<Node> left = _left != null ? _left.cloneRaw(tree) : null;
		ref<Node> right = _right != null ? _right.cloneRaw(tree) : null;
		return tree.newBinary(op(), left, right, location());
	}

	public Test fallsThrough() {
		switch (op()) {
		case	CLASS_DECLARATION:
			return Test.INCONCLUSIVE_TEST;

		default:
			return Test.PASS_TEST;
		}
		return Test.PASS_TEST;
	}

	public void print(int indent) {
		_left.print(indent + INDENT);
		printBasic(indent);
		printf("\n");
		if (_right != null)
			_right.print(indent + INDENT);
	}

	public long foldInt(ref<CompileContext> compileContext) {
		switch (op()) {
		case	ADD: {
			long x = _left.foldInt(compileContext);
			long y = _right.foldInt(compileContext);
			return x + y;
		}

		default:
			add(MessageId.UNFINISHED_GENERATE, compileContext.pool(), CompileString(" "/*this.class.name()*/), CompileString(operatorMap.name[this.op()]), CompileString("Binary.foldInt"));
		}
		return 0;
	}

	public  void markupDeclarator(ref<Type> t, ref<CompileContext> compileContext) {
		switch (op()) {
		case	SEQUENCE:
			_left.markupDeclarator(t, compileContext);
			_right.markupDeclarator(t, compileContext);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	INITIALIZE:
			_left.markupDeclarator(t, compileContext);
			if (_right.op() == Operator.CALL) {
				if (_left.deferAnalysis()) {
					type = _left.type;
					break;
				}
				ref<Call> call = ref<Call>(_right);

				// A constructor initializer!!!
				if (call.target() == null) {
					// Must be a constructor, or else an error.
					call.assignConstructorCall(t, compileContext);
					type = t;
					break;
				}
			}
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				break;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				break;
			}
			_right = _right.coerce(compileContext.tree(), t, false, compileContext);
			type = _right.type;
			break;

		default:
			super.markupDeclarator(t, compileContext);
		}
	}
/*
	void coerceLeft(ref<Type> type, bool explicitCast, ref<CompileContext> compileContext);
*/
	public ref<Node> left() {
		return _left;
	}

	public ref<Node> right() {
		return _right;
	}
 
	ref<Node> rewriteDeclarators(ref<SyntaxTree> syntaxTree) {
		if (op() == Operator.SUBSCRIPT) {
			_left = _left.rewriteDeclarators(syntaxTree);
			_right = _right.rewriteDeclarators(syntaxTree);
		}
		return this;
	}

	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	ANNOTATED:{
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_right);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
		}

		case	CLASS_DECLARATION:
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	DECLARATION:
			if (_left.op() == Operator.ELLIPSIS)
				_left.add(MessageId.BAD_ELLIPSIS, compileContext.pool());
			type = _left.unwrapTypedef(compileContext);
			if (deferAnalysis())
				break;
			_right.markupDeclarator(type, compileContext);
			break;

		case	NEW:
			if (_left.op() != Operator.EMPTY) {
				// Will generate a 'missing type' error
				break;
			}
			if (_right.op() == Operator.CALL) {
				// It needs to be a proper constructor of the type.  So,
				// processing this as a plain constructor will do everything
				// necessary to bind the arguments to the correct constructor.
				compileContext.assignTypes(_right);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				ref<Call> call = ref<Call>(_right);
				type = call.target().unwrapTypedef(compileContext);
			} else {
				type = _right.unwrapTypedef(compileContext);
				if (deferAnalysis())
					break;
			}
			// TODO: Make this a method on Type with this as an override in ClassType
			if (type.family() == TypeFamily.CLASS) {
				ref<ClassScope> s = ref<ClassScope>(type.scope());
				ref<OverloadInstance>[] methods = s.methods();
				for (int i = 0; i < methods.length(); i++)
					methods[i].assignType(compileContext);
				s.assignMethodMaps(compileContext);
			}
			if (!type.isConcrete())
				_right.add(MessageId.ABSTRACT_INSTANCE_DISALLOWED, compileContext.pool());
			type = compileContext.arena().createRef(type, compileContext);
			break;

		case	DELETE:
			if (_left.op() != Operator.EMPTY) {
				// Will generate a 'missing type' error
				break;
			}
			compileContext.assignTypes(_right);
			if (_right.deferAnalysis()) {
				type = _right.type;
				break;
			}
			_right = _right.coerce(compileContext.tree(), TypeFamily.ADDRESS, false, compileContext);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	ADD:
			compileContext.assignTypes(_left);
			if (_left.deferAnalysis()) {
				type = _left.type;
				break;
			}
			if (_left.type.isPointer(compileContext)) {
				compileContext.assignTypes(_right);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_64, false, compileContext);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				type = _left.type;
				break;
			}
			if (!balance(compileContext))
				break;
			switch (_left.type.family()) {
			case	STRING:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	VAR:
				type = _left.type;
				break;

			case	BOOLEAN:
			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	ADD_ASSIGN:
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				break;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				break;
			}
			if (_left.type.family() == TypeFamily.STRING) {
				switch (_right.type.family()) {
				case	STRING:
					if (_left.isLvalue()) 
						type = _left.type;
					else {
						add(MessageId.LVALUE_REQUIRED, compileContext.pool());
						type = compileContext.errorType();
					}
					break;

				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_32:
				case	SIGNED_64:
					if (_right.op() == Operator.CHARACTER) {
						if (_left.isLvalue()) 
							type = _left.type;
						else {
							add(MessageId.LVALUE_REQUIRED, compileContext.pool());
							type = compileContext.errorType();
						}
						break;
					}

				default:
					add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
					type = compileContext.errorType();
				}
				break;
			}

			if (_left.type.isPointer(compileContext)) {
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_32, false, compileContext);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				if (_left.isLvalue()) 
					type = _left.type;
				else {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
				}
				break;
			}
			if (!assignOp(compileContext))
				break;
			switch (_left.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	VAR:
				if (_left.isLvalue()) 
					type = _left.type;
				else {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
				}
				break;

			case	BOOLEAN:
			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	AND:
		case	OR:
		case	EXCLUSIVE_OR:
			if (!balance(compileContext))
				break;
			switch (_left.type.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	BOOLEAN:
			case	VAR:
				type = _left.type;
				break;

			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	AND_ASSIGN:
		case	OR_ASSIGN:
		case	EXCLUSIVE_OR_ASSIGN:
			if (!assignOp(compileContext))
				break;
			switch (_left.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	BOOLEAN:
			case	VAR:
				if (_left.isLvalue()) 
					type = _left.type;
				else {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
				}
				break;

			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	ASSIGN:
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				break;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				break;
			}
			if (_left.op() == Operator.SEQUENCE) {
				if (_right.op() != Operator.CALL) {
					add(MessageId.BAD_MULTI_ASSIGN, compileContext.pool());
					type = compileContext.errorType();
				} else {
					ref<Call> call = ref<Call>(_right);
					ref<FunctionType> funcType = ref<FunctionType>(call.target().type);
					_left.assignMultiReturn(funcType.returnType(), compileContext);
					if (_left.deferAnalysis())
						type = _left.type;
					else
						type = compileContext.arena().builtInType(TypeFamily.VOID);
				}
			} else {
				if (!_left.isLvalue()) {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
					break;
				}
				coerceRight(_left.type, false, compileContext);
				if (_right.type != null)
					type = _right.type;
				else {
					add(MessageId.INTERNAL_ERROR, compileContext.pool());
					type = compileContext.errorType();
				}
			}
			break;

		case	DIVIDE:
		case	MULTIPLY:
			if (!balance(compileContext))
				break;
			switch (_left.type.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	VAR:
			case	FLOAT_32:
			case	FLOAT_64:
				type = _left.type;
				break;

			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	REMAINDER:
			if (!balance(compileContext))
				break;
			switch (_left.type.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	VAR:
				type = _left.type;
				break;

			case	BOOLEAN:
			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
		break;

		case	EQUALITY:
		case	NOT_EQUAL:
			if (!balance(compileContext))
				break;
			switch (_left.type.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	FLOAT_32:
			case	FLOAT_64:
			case	BOOLEAN:
			case	STRING:
			case	ADDRESS:
			case	FUNCTION:
			case	ENUM:
			case	VAR:
				type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				break;

			case	CLASS:
				if (_left.type.indirectType(compileContext) != null) {
					type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					break;
				}

			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	GREATER:
		case	GREATER_EQUAL:
		case	LESS:
		case	LESS_EQUAL:
		case	LESS_GREATER:
		case	NOT_LESS:
		case	NOT_GREATER:
		case	NOT_LESS_EQUAL:
		case	NOT_GREATER_EQUAL:
		case	NOT_LESS_GREATER:
			if (!balance(compileContext))
				break;
			switch (_left.type.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	FLOAT_32:
			case	FLOAT_64:
			case	VAR:
			case	STRING:
				type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				break;

			case	BOOLEAN:
			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	LESS_GREATER_EQUAL:
		case	NOT_LESS_GREATER_EQUAL:
			if (!balance(compileContext))
				break;
			switch (_left.type.family()) {
			case	FLOAT_32:
			case	FLOAT_64:
				type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				break;

			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	BOOLEAN:
			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	BIND:
			type = _left.unwrapTypedef(compileContext);
			break;

		case	SEQUENCE:
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_right);
			type = _right.type;
			break;
			
		case	SUBSCRIPT:
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				return;
			}
			if (_left.type.family() == TypeFamily.TYPEDEF) {
				if (_right.type.isIntegral()) {
					add(MessageId.UNFINISHED_FIXED_ARRAY, compileContext.pool());
					type = compileContext.errorType();
				} else if (_right.type.family() == TypeFamily.TYPEDEF) {
					ref<Type> keyType = _right.unwrapTypedef(compileContext);
					ref<Type> vectorType;
					ref<Type> mapType;
					switch (keyType.family()) {
					case	ENUM:
						vectorType = compileContext.arena().buildEnumVectorType(_left.unwrapTypedef(compileContext), keyType, compileContext);
						type = compileContext.makeTypedef(vectorType);
						break;

					case	STRING:
						mapType = compileContext.arena().buildMapType(keyType, _left.unwrapTypedef(compileContext), compileContext);
						type = compileContext.makeTypedef(mapType);
						break;

					default:
						_right.add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
						type = compileContext.errorType();
					}
				} else {
					add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
					type = compileContext.errorType();
				}
			} else if (_left.type.isPointer(compileContext)) {
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_64, false, compileContext);
				type = _left.type.indirectType(compileContext);
			} else if (_left.type.isVector(compileContext)) {
				_right = _right.coerce(compileContext.tree(), _left.type.indexType(compileContext), false, compileContext);
				if (_right.deferAnalysis()) {
					type = _right.type;
					return;
				}
				type = _left.type.elementType(compileContext);
			} else if (_left.type.isMap(compileContext)) {
				_right = _right.coerce(compileContext.tree(), _left.type.keyType(compileContext), false, compileContext);
				if (_right.deferAnalysis()) {
					type = _right.type;
					return;
				}
				type = _left.type.valueType(compileContext);
			} else if (_left.type.family() == TypeFamily.STRING) {
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_32, false, compileContext);
				type = compileContext.arena().builtInType(TypeFamily.UNSIGNED_8);
			} else {
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	SUBTRACT:
			if (!balance(compileContext))
				break;
			switch (_left.type.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	FLOAT_32:
			case	FLOAT_64:
			case	VAR:
				type = _left.type;
				break;

			case	CLASS:
				if (_left.type.isPointer(compileContext)) {
					type = compileContext.arena().builtInType(TypeFamily.SIGNED_64);
					break;
				}

			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	SUBTRACT_ASSIGN:
			compileContext.assignTypes(_left);
			if (_left.deferAnalysis()) {
				type = _left.type;
				break;
			}
			if (_left.type.isPointer(compileContext)) {
				compileContext.assignTypes(_right);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_32, false, compileContext);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				if (_left.isLvalue()) 
					type = _left.type;
				else {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
				}
				break;
			}
			// fall through
		case	DIVIDE_ASSIGN:
		case	MULTIPLY_ASSIGN:
			if (!assignOp(compileContext))
				break;
			switch (_left.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	VAR:
				if (_left.isLvalue()) 
					type = _left.type;
				else {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
				}
				break;

			case	BOOLEAN:
			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	REMAINDER_ASSIGN:
			if (!assignOp(compileContext))
				break;
			switch (_left.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	VAR:
				if (_left.isLvalue()) 
					type = _left.type;
				else {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
				}
				break;

			case	BOOLEAN:
			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	LEFT_SHIFT:
		case	RIGHT_SHIFT:
		case	UNSIGNED_RIGHT_SHIFT:
			if (!shift(compileContext))
				break;
			type = _left.type;
			break;

		case	LEFT_SHIFT_ASSIGN:
		case	RIGHT_SHIFT_ASSIGN:
		case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
			if (!assignShiftOp(compileContext))
				break;
			if (_left.isLvalue()) 
				type = _left.type;
			else {
				add(MessageId.LVALUE_REQUIRED, compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	LOGICAL_AND:
		case	LOGICAL_OR:
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				return;
			}
			if (_left.type.family() == TypeFamily.BOOLEAN &&
				_right.type.family() == TypeFamily.BOOLEAN)
				type = _left.type;
			else {
				add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	SWITCH:{
			compileContext.assignTypes(_left);
			if (!_left.deferAnalysis()) {
				switch (_left.type.family()) {
				case	UNSIGNED_8:
				case	UNSIGNED_32:
				case	SIGNED_32:
				case	SIGNED_64:
				case	ENUM:
					break;

				default:
					add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
					_left.type = compileContext.errorType();
				}
			}
			CompileContext.FlowContext flowContext(this, compileContext.flowContext());
			compileContext.pushFlowContext(&flowContext);
			compileContext.assignTypes(_right);
			compileContext.popFlowContext();
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
		}
		case	CASE:{
			compileContext.assignTypes(_right);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
		}
		case	DO_WHILE:{
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				return;
			}
			if (_right.type.family() != TypeFamily.BOOLEAN) {
				_right.add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			}
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
		}
		case	WHILE:{
			compileContext.assignTypes(_left);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				return;
			}
			if (_left.type.family() != TypeFamily.BOOLEAN) {
				_left.add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			}
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
		}
		case	ENUM_DECLARATION:
			ref<Identifier> id = ref<Identifier>(_left);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
		}
	}

	boolean balance(ref<CompileContext> compileContext) {
		compileContext.assignTypes(_left);
		compileContext.assignTypes(_right);
		if (_left.deferAnalysis()) {
			type = _left.type;
			return false;
		}
		if (_right.deferAnalysis()) {
			type = _right.type;
			return false;
		}
		_left = _left.convertSmallIntegralTypes(compileContext);
		_right = _right.convertSmallIntegralTypes(compileContext);
		return balancePair(this, &_left, &_right, compileContext);
	}

	boolean assignOp(ref<CompileContext> compileContext) {
		// Check for lvalue
		compileContext.assignTypes(_left);
		compileContext.assignTypes(_right);
		if (_left.deferAnalysis()) {
			type = _left.type;
			return false;
		}
		if (_right.deferAnalysis()) {
			type = _right.type;
			return false;
		}
		_right = _right.coerce(compileContext.tree(), _left.type, false, compileContext);
		if (_right.deferAnalysis()) {
			type = _right.type;
			return false;
		}
		return true;
	}

	boolean assignShiftOp(ref<CompileContext> compileContext) {
		// Check for lvalue
		compileContext.assignTypes(_left);
		compileContext.assignTypes(_right);
		if (_left.deferAnalysis()) {
			type = _left.type;
			return false;
		}
		if (_right.deferAnalysis()) {
			type = _right.type;
			return false;
		}
		switch (_left.type.family()) {
		case	VAR:
			_right = _right.coerce(compileContext.tree(), TypeFamily.VAR, false, compileContext);
			if (_right.deferAnalysis()) {
				type = _right.type;
				return false;
			}
			type = _left.type;
			return true;

		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	SIGNED_32:
		case	SIGNED_64:
			break;

		case	BOOLEAN:
		default:
			add(MessageId.LEFT_NOT_INT, compileContext.pool());
			type = compileContext.errorType();
			return false;
		}
		switch (_right.type.family()) {
		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
			_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_32, false, compileContext);
			break;

		case	SIGNED_32:
			break;

		case	BOOLEAN:
		default:
			add(MessageId.SHIFT_NOT_INT, compileContext.pool());
			type = compileContext.errorType();
			return false;
		}
		return true;
	}

	boolean shift(ref<CompileContext> compileContext) {
		compileContext.assignTypes(_left);
		compileContext.assignTypes(_right);
		if (_left.deferAnalysis()) {
			type = _left.type;
			return false;
		}
		if (_right.deferAnalysis()) {
			type = _right.type;
			return false;
		}
		switch (_left.type.family()) {
		case	VAR:
			_right = _right.coerce(compileContext.tree(), TypeFamily.VAR, false, compileContext);
			if (_right.deferAnalysis()) {
				type = _right.type;
				return false;
			}
			return true;

		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	SIGNED_32:
		case	SIGNED_64:
			break;

		case	BOOLEAN:
		default:
			add(MessageId.LEFT_NOT_INT, compileContext.pool());
			type = compileContext.errorType();
			return false;
		}
		switch (_right.type.family()) {
		case	UNSIGNED_8:
		case	UNSIGNED_16:
			_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_32, false, compileContext);
			break;

		case	VAR:
			_left = _left.coerce(compileContext.tree(), TypeFamily.VAR, false, compileContext);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return false;
			}
			break;

		case	SIGNED_32:
			break;

		case	BOOLEAN:
		default:
			add(MessageId.SHIFT_NOT_INT, compileContext.pool());
			type = compileContext.errorType();
			return false;
		}
		return true;
	}

	void coerceRight(ref<Type> type, boolean explicitCast, ref<CompileContext> compileContext) {
		_right = _right.coerce(compileContext.tree(), type, explicitCast, compileContext);
	}
}

private ref<Node>, ref<Variable> foldStringAddition(ref<Node> leftHandle, ref<Variable> variable, ref<Node> addNode, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
	if (addNode.op() == Operator.ADD) {
		ref<Binary> b = ref<Binary>(addNode);
		(leftHandle, variable) = foldStringAddition(leftHandle, variable, b.left(), tree, compileContext);
		(leftHandle, variable) = foldStringAddition(leftHandle, variable, b.right(), tree, compileContext);
		return leftHandle, variable;
	} else {
		addNode = addNode.fold(tree, false, compileContext);
		if (leftHandle != null) {
			ref<Node> appender = appendString(variable, addNode, tree, compileContext);
			ref<Node> seq = tree.newBinary(Operator.SEQUENCE, leftHandle, appender, addNode.location());
			seq.type = compileContext.arena().builtInType(TypeFamily.VOID);
			return seq, variable;
		} else {
			variable = compileContext.newVariable(addNode.type);
			ref<Reference> r = tree.newReference(variable, true, addNode.location());
			ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, addNode.location());
			adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			ref<OverloadInstance> constructor = addNode.type.initialConstructor();
			assert(constructor != null);
			ref<NodeList> args = tree.newNodeList(addNode);
			ref<Call> call = tree.newCall(constructor, CallCategory.CONSTRUCTOR, adr, args, addNode.location());
			call.type = compileContext.arena().builtInType(TypeFamily.VOID);
			return call, variable;
		}
	}
}
	
private ref<Node> appendString(ref<Variable> variable, ref<Node> value, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
	ref<Reference> r = tree.newReference(variable, false, value.location());				
	CompileString name("append");
	
	ref<Symbol> sym = value.type.lookup(&name, compileContext);
	if (sym == null || sym.class != Overload) {
		value.add(MessageId.UNDEFINED, compileContext.pool(), name);
		return value;
	}
	ref<Overload> over = ref<Overload>(sym);
	ref<OverloadInstance> oi = null;
	for (int i = 0; i < over.instances().length(); i++) {
		oi = over.instances()[i];
		ref<ParameterScope> scope = oi.parameterScope();
		if (scope.parameters().length() != 1)
			continue;
		if (scope.parameters()[0].type() == value.type)
			break;
	}
	assert(oi != null);
	ref<Selection> method = tree.newSelection(r, oi, value.location());
	method.type = oi.type();
	ref<NodeList> args = tree.newNodeList(value);
	ref<Call> call = tree.newCall(oi, null, method, args, value.location());
	call.type = compileContext.arena().builtInType(TypeFamily.VOID);
	return call.fold(tree, true, compileContext);
}

class Block extends Node {
	private ref<NodeList> _statements;
	private ref<NodeList> _last;
	public ref<Scope> scope;

	Block(Operator op, Location location) {
		super(op, location);
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
		for (ref<NodeList> nl = _statements; nl != null; nl = nl.next)
			nl.node = nl.node.fold(tree, false, compileContext);
		return this;
	}

	public ref<Block> clone(ref<SyntaxTree> tree) {
		ref<Block> b = tree.newBlock(op(), location());
		if (_statements != null)
			b._statements = _statements.clone(tree);
		b.scope = scope;
		return ref<Block>(b.finishClone(this, tree.pool()));
	}

	public ref<Block> cloneRaw(ref<SyntaxTree> tree) {
		ref<Block> b = tree.newBlock(op(), location());
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

	public void print(int indent) {
		printBasic(indent);
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

	public ref<NodeList> statements() {
		return _statements; 
	}
 
	protected void assignTypes(ref<CompileContext> compileContext) {
		for (ref<NodeList> nl = _statements; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
		type = compileContext.arena().builtInType(TypeFamily.VOID);
	}

	boolean definesScope() {
		return true;
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

enum CallCategory {
	ERROR,
	COERCION,
	CONSTRUCTOR,
	FUNCTION_CALL,
	METHOD_CALL,
	VIRTUAL_METHOD_CALL
}

private string[CallCategory] callCategories;

callCategories.append("ERROR");
callCategories.append("COERCION");
callCategories.append("CONSTRUCTOR");
callCategories.append("FUNCTION_CALL");
callCategories.append("METHOD_CALL");
callCategories.append("VIRTUAL_METHOD_CALL");

class Call extends ParameterBag {
	// Populated at parse time:
	private ref<Node> _target;						// the 'function' being called
													//   COERCION: the type expression of the new type
													//   CONSTRUCTOR: the type expression of the object type
													//	 FUNCTION_CALL: the function or function object being called
													//   METHOD_CALL, VIRTUAL_NETHOD_CALL: the simple identifier or object.method being called
	// Populated at type analysis:					
	private CallCategory _category;					// what kind of call it turned out to be after type analysis
	private ref<Symbol> _overload;					// For CONSTRUCTOR, some FUNCTION_CALL, METHOD_CALL and VIRTUAL_METHOD_CALL: 
													//   The symbol of the overload being called.
	
	// Populated by folding:
	// Note _arguments (from ParameterBag):			// A set of 'arguments' that must be inserted in the available register 
													// arguments (target dependent).  This will include the potential 'hidden'
													// arguments of 'this' and any 'out' parameter.
	private ref<NodeList> _stackArguments;			// Those call arguments that must be pushed on the stack (target dependent)
	private boolean _folded;						// Set to true if the call arguments have been folded
	
	Call(Operator op, ref<Node> target, ref<NodeList> arguments, Location location) {
		super(op, arguments, location);
		_target = target;
		_category = CallCategory.ERROR;
	}
	
	Call(ref<OverloadInstance> overload, CallCategory category, ref<Node> target, ref<NodeList> arguments, Location location) {
		super(Operator.CALL, arguments, location);
		_target = target;
		_overload = overload;
		if (category != null)
			_category = category;
		else if (overload == null)
			_category = CallCategory.ERROR;
		else if (overload.storageClass() == StorageClass.MEMBER) {
			if (isVirtualCall())
				_category = CallCategory.VIRTUAL_METHOD_CALL;
			else
				_category = CallCategory.METHOD_CALL;
		} else
			_category = CallCategory.FUNCTION_CALL;
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
			if (_target != null && !_target.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			break;

		case	IN_ORDER:
			if (_target != null && !_target.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (_target != null && !_target.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.traverse(t, func, data))
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
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			if (_target != null && !_target.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_target != null && !_target.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_POST_ORDER:
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			if (_target != null && !_target.traverse(t, func, data))
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
		case	CALL:
			if (_folded)
				return this;
			_folded = true;
			for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
				nl.node = nl.node.fold(tree, false, compileContext);
			if (_target != null)
				_target = _target.fold(tree, false, compileContext);
			ref<Node> result = this;
			ref<FunctionType> functionType;
			ref<Node> outParameter = null;
			ref<Node> thisParameter = null;
			ref<Node> functionObject = null;
			switch (_category) {
			case	COERCION:
				ref<Node> source = _arguments.node;
				return tree.newCast(type, source).fold(tree, voidContext, compileContext);
				
			case	CONSTRUCTOR:
				if (_overload == null) {
					print(0);
					assert(false);
				}
				functionType = ref<FunctionType>(_overload.type());
				if (voidContext)
					thisParameter = _target;
				else {
					ref<Variable> temp = compileContext.newVariable(type);
					thisParameter = tree.newReference(temp, true, location());
					thisParameter = tree.newUnary(Operator.ADDRESS, thisParameter, location());
					thisParameter.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
//					ref<Node> n = tree.newStackArgumentAddress(0, location());
//					n.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
//					thisParameter = n;
					flags |= PUSH_OUT_PARAMETER;
					result = encapsulateCallInTemp(temp, tree);
				}
				break;
				
			case	METHOD_CALL:
			case	VIRTUAL_METHOD_CALL:
				if (_target.op() == Operator.DOT) {
					ref<Selection> dot = ref<Selection>(_target);
					if (dot.indirect()) {
						thisParameter = dot.left();
					} else {
						if (dot.left().isLvalue()) {
							thisParameter = tree.newUnary(Operator.ADDRESS, dot.left(), dot.left().location());
							thisParameter.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
						} else {
							ref<Variable> temp = compileContext.newVariable(dot.left().type);
							ref<Reference> r = tree.newReference(temp, true, dot.left().location());
							ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, dot.left(), dot.left().location());
							defn.type = dot.left().type;
							r = tree.newReference(temp, false, dot.left().location());
							ref<Unary> adr = tree.newUnary(Operator.ADDRESS, r, dot.left().location());
							adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
							ref<Node> pair = tree.newBinary(Operator.SEQUENCE, defn.fold(tree, true, compileContext), adr, dot.left().location());
							pair.type = defn.type;
							_target = tree.newSelection(pair, dot.symbol(), dot.location());
							_target.type = dot.type;
							thisParameter = pair;
						}
					}
				} else {
					thisParameter = tree.newLeaf(Operator.THIS, location());
					thisParameter.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
				}
				
			default:
				if (_overload == null)
					functionObject = _target;
				// All other calls can rely on the LHS expression type to be the correct function,
				// but for LHS expressions that are function objects (i.e. function pointers), there is
				// no overloaded symbol, so we can't use that..
				functionType = ref<FunctionType>(_target.type);

				ref<Variable> temp;
				if (type.returnsViaOutParameter(compileContext))
					temp = compileContext.newVariable(type);
				else if (functionType.returnCount() > 1)
					temp = compileContext.newVariable(functionType.returnType());
				else
					break;
				outParameter = tree.newReference(temp, true, location());
				if (!voidContext) {
					flags |= PUSH_OUT_PARAMETER;
					result = encapsulateCallInTemp(temp, tree);
				}
			}
			// Now promote the 'hidden' parameters, so code gen is simpler.
			int registerArgumentIndex = 0;
			if (thisParameter != null) {
				thisParameter.register = compileContext.target.registerValue(registerArgumentIndex);
				if (thisParameter.register == 0) {
					printf("---\n");
					print(0);
					assert(thisParameter.register != 0);
				}
				registerArgumentIndex++;
			}
			if (outParameter != null) {
				outParameter = tree.newUnary(Operator.ADDRESS, outParameter, outParameter.location());
				outParameter.register = compileContext.target.registerValue(registerArgumentIndex);
				outParameter.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
				registerArgumentIndex++;
			}
			if (_arguments != null) {
				ref<NodeList> params = functionType.parameters();
				
				ref<NodeList> registerArguments;
				ref<NodeList> lastRegisterArgument;
				
				// TODO: Ensure plain stack arguments are in 'correct' order.
				ref<NodeList> argsNext = null;
				for (ref<NodeList> args = _arguments; params != null; args = argsNext, params = params.next) {
					if (params.node.getProperEllipsis() != null) {
						ref<EllipsisArguments> ea = null;			// TODO: Remove this initializer to test implied re-initialization.
						if (args == null) {
							ea = tree.newEllipsisArguments(null, location());
							ea.type = params.node.type.elementType(compileContext);
							args = tree.newNodeList(ea);
						} else if (args.next == null && args.node.type.equals(params.node.type)) {
							args.node = tree.newUnary(Operator.STACK_ARGUMENT, args.node, args.node.location());
							args.node.type = params.node.type;
						} else {
							ea = tree.newEllipsisArguments(args, location());
							ea.type = params.node.type.elementType(compileContext);
							args = tree.newNodeList(ea);
						}
						args.next = _stackArguments;
						_stackArguments = args;
						if (ea != null) {
							for (ref<NodeList> nl = ea.arguments(); nl != null; nl = nl.next) {
								ref<Type> t = nl.node.type;
								nl.node = tree.newUnary(Operator.ELLIPSIS_ARGUMENT, nl.node, nl.node.location());
								nl.node.type = t;
							}
//							ea.reverseArgumentOrder();
						}
						break;
					}
					argsNext = args.next;
					byte nextReg = compileContext.target.registerValue(registerArgumentIndex);
					
					// Thread each argument onto the appropriate list: stack or register
					if (nextReg == 0 || args.node.type.passesViaStack(compileContext)) {
						ref<Type> t = args.node.type;
						args.node = tree.newUnary(Operator.STACK_ARGUMENT, args.node, args.node.location());
						args.node.type = t;
						args.next = _stackArguments;
						_stackArguments = args;
					} else {
						args.node.register = nextReg;
						registerArgumentIndex++;
						if (lastRegisterArgument != null)
							lastRegisterArgument.next = args;
						else
							registerArguments = args;
						lastRegisterArgument = args;
						args.next = null;
					}
				}
				_arguments = registerArguments;
			}
			if (outParameter != null) {
				ref<NodeList> nl = tree.newNodeList(outParameter);
				nl.next = _arguments;
				_arguments = nl;
			}
			if (thisParameter != null) {
				ref<NodeList> nl = tree.newNodeList(thisParameter);
				nl.next = _arguments;
				_arguments = nl;
			}
			if (functionObject != null) {
				ref<NodeList> nl = tree.newNodeList(functionObject);
				nl.next = _arguments;
				_arguments = nl;
				functionObject.register = 0xff;
			}
			
			ref<Leaf> n = tree.newLeaf(Operator.VACATE_ARGUMENT_REGISTERS, location());
			n.type = compileContext.arena().builtInType(TypeFamily.VOID);;
			ref<NodeList> nl = tree.newNodeList(n);
			nl.next = _stackArguments;
			_stackArguments = nl;
			return result;
			
		case	TEMPLATE_INSTANCE:
			for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
				nl.node = nl.node.fold(tree, false, compileContext);
			if (_target != null)
				_target = _target.fold(tree, false, compileContext);
			break;
			
		default:
			print(0);
			assert(false);
		}
		return this;
	}
	
	public void setConstructorMemory(ref<Node> placement, ref<SyntaxTree> tree) {
		if (_category != CallCategory.CONSTRUCTOR)
			print(0);
		assert(_category == CallCategory.CONSTRUCTOR);
		_target = placement;
//		type = placement.type;
	}
	
	private ref<Node> encapsulateCallInTemp(ref<Variable> temp, ref<SyntaxTree> tree) {
		ref<Reference> r = tree.newReference(temp, false, location());
		ref<Node> pair = tree.newBinary(Operator.SEQUENCE, this, r, location());
		pair.type = type;
		r.type = type;
		return pair;
	}
	
	public ref<Call> clone(ref<SyntaxTree> tree) {
		ref<Node> target = _target != null ? _target.clone(tree) : null;
		ref<NodeList> arguments  = _arguments != null ? _arguments.clone(tree) : null;
		ref<Call> call = ref<Call>(tree.newCall(op(), target, arguments, location()).finishClone(this, tree.pool()));
		call._category = _category;
		call._overload = _overload;
		return call;
	}

	public ref<Call> cloneRaw(ref<SyntaxTree> tree) {
		ref<Node> target = _target != null ? _target.cloneRaw(tree) : null;
		ref<NodeList> arguments  = _arguments != null ? _arguments.cloneRaw(tree) : null;
		return tree.newCall(op(), target, arguments, location());
	}

	public ref<Symbol> overload() {
		return _overload;
	}
	
	public boolean folded() {
		return _folded;
	}
	
	public void print(int indent) {
		if (_target != null)
			_target.print(indent + INDENT);
		printBasic(indent);
		int args = 0;
		int stackArgs = 0;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			args++;
		for (ref<NodeList> nl = _stackArguments; nl != null; nl = nl.next)
			stackArgs++;
		printf(" %s args: reg %d stack %d %s\n", callCategories[_category], args, stackArgs, _folded ? "folded" : "");
		if (_overload != null)
			_overload.print(indent + 2 * INDENT, false);
		if (_stackArguments != null) {
			printf("%*.*cStack:\n", indent + INDENT, indent + INDENT, ' ');
			for (ref<NodeList> nl = _stackArguments; nl != null; nl = nl.next)
				nl.node.print(indent + 2 * INDENT);
		}
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			nl.node.print(indent + INDENT);
	}

	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	ANNOTATION:
			type = compileContext.arena().builtInType(TypeFamily.VOID);
		break;

		case	TEMPLATE_INSTANCE:
			if (!assignSub(Operator.TEMPLATE, compileContext))
				break;
			if (_target.type.family() == TypeFamily.TYPEDEF) {
				ref<TypedefType> t = ref<TypedefType>(_target.type);
				if (t.wrappedType().family() == TypeFamily.TEMPLATE) {
					ref<OverloadInstance> oi = ref<OverloadInstance>(_target.symbol());
					ref<Type> instanceType = oi.instantiateTemplate(this, compileContext);
					type = compileContext.makeTypedef(instanceType);
					break;
				}
			}
			_target.add(MessageId.NOT_A_TEMPLATE, compileContext.pool());
			type = compileContext.errorType();
			break;

		case	CALL:
			if (!assignSub(Operator.FUNCTION, compileContext))
				break;
			if (_target.op() == Operator.SUPER) {
				_category = CallCategory.CONSTRUCTOR;
				if (compileContext.current().storageClass() != StorageClass.AUTO ||
					compileContext.current().enclosing().storageClass() != StorageClass.PARAMETER ||
					compileContext.current().enclosing().enclosing().storageClass() != StorageClass.MEMBER) {
					_target.add(MessageId.INVALID_SUPER, compileContext.pool());
					type = compileContext.errorType();
					break;
				}
				// The SUPER call is in the right scope, is it the first statement of the
				// current block.
				ref<Node> def = compileContext.current().enclosing().definition();
				if (def.op() != Operator.FUNCTION) {
					_target.add(MessageId.INVALID_SUPER, compileContext.pool());
					type = compileContext.errorType();
					break;
				}
				ref<Function> func = ref<Function>(def);
				if (func.functionCategory() != Function.Category.CONSTRUCTOR ||
					func.body != compileContext.current().definition()) {
					_target.add(MessageId.INVALID_SUPER, compileContext.pool());
					type = compileContext.errorType();
					break;
				}
				ref<Type> t = compileContext.current().getSuper();
				if (t == null) {
					_target.add(MessageId.SUPER_NOT_ALLOWED, compileContext.pool());
					type = compileContext.errorType();
					break;
				}
				assignConstructorCall(t, compileContext);
				break;
			}
			switch (_target.type.family()) {
			case	VAR:
				type = _target.type;
				break;

			case	TYPEDEF:
				ref<Type> t = _target.unwrapTypedef(compileContext);
				if (builtInCoercion(compileContext))
					_category = CallCategory.COERCION;
				else {
					assignConstructorCall(t, compileContext);
					if (deferAnalysis())
						break;
					_category = CallCategory.CONSTRUCTOR;
				}
				type = t;
				break;

			case	FUNCTION:
				convertArguments(compileContext);
				_category = CallCategory.FUNCTION_CALL;
				_overload = _target.symbol();
				if (_overload != null) {
					if (_overload.class != OverloadInstance)
						_overload = null;
					else if (_overload.storageClass() == StorageClass.MEMBER) {
						if (isVirtualCall())
							_category = CallCategory.VIRTUAL_METHOD_CALL;
						else
							_category = CallCategory.METHOD_CALL;
					}
				}
				ref<FunctionType> ft = ref<FunctionType>(_target.type);
				// Verify that this corresponds to a function overload
				for (ref<NodeList> nl = ft.returnType(); nl != null; nl = nl.next) {
					if (nl.node.type.family() == TypeFamily.CLASS_VARIABLE) {
						type = compileContext.arena().builtInType(TypeFamily.CLASS_DEFERRED);
						return;
					}
				}
				type = ft.returnValueType();
				if (type == null)
					type = compileContext.arena().builtInType(TypeFamily.VOID);
				break;

			default:
				_target.add(MessageId.NOT_A_FUNCTION, compileContext.pool());
				type = compileContext.errorType();
			}
			break;
		}
	}

	private boolean isVirtualCall() {
		if (!_overload.usesVTable())
			return false;
		switch (_target.op()) {
		case	DOT:
			ref<Selection> dot = ref<Selection>(_target);
			return dot.left().op() != Operator.SUPER;

		case	IDENTIFIER:
			return true;
		}
		return false;
	}
	
	private boolean assignSub(Operator kind, ref<CompileContext> compileContext) {
		if (!assignArguments(compileContext))
			return false;
		_target.assignOverload(_arguments, kind, compileContext);
		if (_target.deferAnalysis()) {
			type = _target.type;
			return false;
		}
		return true;
	}

	void assignConstructorCall(ref<Type> classType, ref<CompileContext> compileContext) {
		if (!assignArguments(compileContext))
			return;
		OverloadOperation operation(Operator.FUNCTION, this, null, _arguments, compileContext);
		if (classType.deferAnalysis()) {
			type = classType;
			return;
		}
		type = operation.includeConstructors(classType, compileContext);
		if (type != null)
			return;
		ref<Type> match;
		(match, _overload) = operation.result();
		if (match.deferAnalysis())
			type = match;
		else {
			type = classType;
//			type = compileContext.arena().builtInType(TypeFamily.VOID);
			_category = CallCategory.CONSTRUCTOR;
		}
	}
		
	void convertArguments(ref<CompileContext> compileContext) {
		boolean processingEllipsis = false;
		ref<NodeList> param = ref<FunctionType>(_target.type).parameters();
		ref<NodeList> arguments = _arguments;
		while (arguments != null) {
			if (param.node.deferAnalysis())
				return;
			ref<Type> t = param.node.type;
			ref<Unary> ellipsis = param.node.getProperEllipsis();
			if (ellipsis != null) {
				// in this case t is a vector type
				// Check for the special case that the argument has type t
				if (!processingEllipsis && 
					arguments.node.type.equals(t))
					return;
				// okay, we need to actually check the element type
				t = t.elementType(compileContext);
			}
			arguments.node = arguments.node.coerce(compileContext.tree(), t, false, compileContext);
			if (ellipsis != null)
				// If there are more arguments, then this parameter must be an ellipsis parameter
				processingEllipsis = true;
			else
				param = param.next;
			arguments = arguments.next;
		}
	}

	boolean assignArguments(ref<CompileContext> compileContext) {
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			if (nl.node.deferAnalysis()) {
				type = nl.node.type;
				return false;
			}
		return true;
	}

	ref<Node> rewriteDeclarators(ref<SyntaxTree> syntaxTree) {
		if (op() == Operator.CALL)
			return syntaxTree.newFunction(Function.Category.DECLARATOR, _target, null, _arguments, location());
		else
			return this;
	}

	public ref<Node> target() {
		return _target;
	}
 
	public ref<NodeList> getParameterList() {
		return ref<FunctionType>(_target.type).parameters();
	}

	public ref<NodeList> stackArguments() {
		return _stackArguments;
	}
	
	private boolean builtInCoercion(ref<CompileContext> compileContext) {
		if (_arguments == null ||
			_arguments.next != null)
			return false;
		ref<Type> existingType = _arguments.node.type;
		ref<Type> newType = _target.unwrapTypedef(compileContext);
		if (newType.family() == TypeFamily.VAR)
			return true;
		switch (existingType.family()) {
		case	VAR:
			return true;

		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	UNSIGNED_64:
		case	SIGNED_8:
		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
		case	FLOAT_32:
		case	FLOAT_64:
		case	STRING:
		case	ADDRESS:
		case	BOOLEAN:
		case	ENUM:
		case	FUNCTION:
			switch (newType.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	UNSIGNED_64:
			case	SIGNED_8:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	STRING:
			case	ADDRESS:
			case	BOOLEAN:
			case	ENUM:
			case	FUNCTION:
				return true;

			case	CLASS:
				if (newType.indirectType(compileContext) != null)
					return true;
				break;
			}
			break;

		case	CLASS:
			if (existingType.indirectType(compileContext) != null) {
				switch (newType.family()) {
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	UNSIGNED_64:
				case	SIGNED_8:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
				case	FLOAT_32:
				case	FLOAT_64:
				case	STRING:
				case	ADDRESS:
				case	BOOLEAN:
				case	ENUM:
				case	FUNCTION:
					return true;

				case	CLASS:
					if (newType.indirectType(compileContext) != null)
						return true;
					break;
				}
			}
			break;
		}
		return false;
	}
	
	CallCategory category() {
		return _category;
	}
}

class Class extends Block {
	protected ref<Node> _extends;
	private ref<Identifier> _name;
	private ref<NodeList> _implements;
	private ref<NodeList> _last;
	
	Class(ref<Identifier> name, ref<Node> extendsClause, Location location) {
		super(Operator.CLASS, location);
		_name = name;
		_extends = extendsClause;
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
		printf("\n");
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
/*
	ref<NodeList> implements() { return _implements; }
*/

	boolean definesScope() {
		assert(false);
		return false;
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		if (_extends != null)
			compileContext.assignTypes(_extends);
		for (ref<NodeList> nl = _implements; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
		if (_extends != null &&
			_extends.deferAnalysis()) {
			type = _extends.type;
			return;
		}
		for (ref<NodeList> nl = _implements; nl != null; nl = nl.next)
			if (nl.node.deferAnalysis()) {
				type = nl.node.type;
				return;
			}
		super.assignTypes(compileContext);
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
		byte[] value;
		value.resize(_value.length);
		memcpy(&value[0], _value.data, _value.length);
		CompileString cs(&value);
		return ref<Constant>(tree.newConstant(op(), cs, location()).finishClone(this, tree.pool()));
	}

	public ref<Constant> cloneRaw(ref<SyntaxTree> tree) {
		byte[] value;
		value.resize(_value.length);
		memcpy(&value[0], _value.data, _value.length);
		CompileString cs(&value);
		return tree.newConstant(op(), cs, location());
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
			break;
			
		default:
			print(0);
			assert(false);
		}
		return this;
	}
	
	public long foldInt(ref<CompileContext> compileContext) {
		if ((flags & BAD_CONSTANT) != 0)
			return 0;						// We've already flagged this node with an error
		int x;
		boolean status;
		switch (op()) {
		case	INTEGER:
			return intValue();

		case	CHARACTER:
			(x, status) = charValue();
			if (status)
				return x;
			flags |= BAD_CONSTANT;
			add(MessageId.BAD_CHAR, compileContext.pool(), _value);
			return 0;

		default:
			add(MessageId.UNFINISHED_GENERATE, compileContext.pool(), CompileString(" "/*this.class.name()*/), CompileString(operatorMap.name[op()]), CompileString("Constant.foldInt"));
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
		if (_value.data[0] == '0') {
			if (_value.length == 1)
				return 0;
			if (_value.data[1] == 'x' || _value.data[1] == 'X') {
				for (int i = 2; i < _value.length; i++) {
					int digit;
					if (_value.data[i].isAlpha())
						digit = 10 + _value.data[i].toLowercase() - 'a';
					else
						digit = _value.data[i] - '0';
					v = v * 16 + digit;
				}
			} else {
				for (int i = 1; i < _value.length; i++)
					v = v * 8 + _value.data[i] - '0';
			}
		} else {
			for (int i = 0; i < _value.length; i++) {
//				printf("_value.data[%d] = %x\n", i, int(_value.data[i]));
				v = v * 10 + _value.data[i] - '0';
			}
			
		}
		return v;
	}

	int, boolean charValue() {
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
			if (_test != null)
				_test = _test.fold(tree, false, compileContext);
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

	public boolean definesScope() {
		return op() == Operator.SCOPED_FOR;
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	FOR:
		case	SCOPED_FOR:
			compileContext.assignTypes(_initializer);
			compileContext.assignTypes(_test);
			if (!_test.deferAnalysis() && _test.op() != Operator.EMPTY) {
				if (_test.type.family() != TypeFamily.BOOLEAN) {
					_test.add(MessageId.NOT_BOOLEAN, compileContext.pool());
					_test.type = compileContext.errorType();
				}
			}
			compileContext.assignTypes(_increment);
			compileContext.assignTypes(_body);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
		}
	}
}

class Function extends ParameterBag {
	public enum Category {
		NORMAL,
		CONSTRUCTOR,
		DESTRUCTOR,
		ABSTRACT,
		DECLARATOR
	}
	private Category _functionCategory;
	private ref<NodeList> _returnType;
	private ref<Identifier> _name;

	public ref<Block> body;
	
	Function(Category functionCategory, ref<Node> returnType, ref<Identifier> name, ref<NodeList> arguments, ref<SyntaxTree> tree, Location location) {
		super(Operator.FUNCTION, arguments, location);
		_functionCategory = functionCategory;
		if (returnType != null) {
			_returnType = returnType.treeToList(null, tree);
			for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next)
				nl.node = tree.newUnary(Operator.UNWRAP_TYPEDEF, nl.node, nl.node.location());
		}
		_name = name;
	}

	public Test fallsThrough() {
		return Test.INCONCLUSIVE_TEST;
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
			if (_returnType != null && !_returnType.traverse(t, func, data))
				return false;
			if (_name != null && !_name.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			if (body != null && !body.traverse(t, func, data))
				return false;
			break;

		case	IN_ORDER:
			if (_returnType != null && !_returnType.traverse(t, func, data))
				return false;
			if (_name != null && !_name.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			if (body != null && !body.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (_returnType != null && !_returnType.traverse(t, func, data))
				return false;
			if (_name != null && !_name.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			if (body != null && !body.traverse(t, func, data))
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
			if (body != null && !body.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			if (_name != null && !_name.traverse(t, func, data))
				return false;
			if (_returnType != null && !_returnType.reverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
			if (body != null && !body.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_name != null && !_name.traverse(t, func, data))
				return false;
			if (_returnType != null && !_returnType.reverse(t, func, data))
				return false;
			break;

		case	REVERSE_POST_ORDER:
			if (body != null && !body.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			if (_name != null && !_name.traverse(t, func, data))
				return false;
			if (_returnType != null && !_returnType.reverse(t, func, data))
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
		// Note: The body will be folded when the function code gets generated.  There are important side-effects
		// that must be delayed to that time.
//		if (body != null)
//			body = body.fold(tree, compileContext);
		for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next)
			nl.node = nl.node.fold(tree, false, compileContext);
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			nl.node = nl.node.fold(tree, false, compileContext);
		return this;
	}
	
	public ref<Function> clone(ref<SyntaxTree> tree) {
		ref<NodeList> returnType = _returnType != null ? _returnType.clone(tree) : null;
		ref<Identifier> name = _name != null ? _name.clone(tree) : null;
		ref<NodeList> arguments = _arguments != null ? _arguments.clone(tree) : null;
		ref<Function> f = tree.newFunction(_functionCategory, null, name, arguments, location());
		f._returnType = returnType;
		if (body != null)
			f.body = body.clone(tree);
		return ref<Function>(f.finishClone(this, tree.pool()));
	}

	public ref<Function> cloneRaw(ref<SyntaxTree> tree) {
		ref<NodeList> returnType = _returnType != null ? _returnType.cloneRaw(tree) : null;
		ref<Identifier> name = _name != null ? _name.cloneRaw(tree) : null;
		ref<NodeList> arguments = _arguments != null ? _arguments.cloneRaw(tree) : null;
		ref<Function> f = tree.newFunction(_functionCategory, null, name, arguments, location());
		f._returnType = returnType;
		if (body != null)
			f.body = body.cloneRaw(tree);
		return f;
	}

	public void print(int indent) {
		int i = 0;
		for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next, i++) {
			printf("%*.*c  {Return type %d}\n", indent, indent, ' ', i);
			nl.node.print(indent + INDENT);
		}
		printBasic(indent);
		int args = 0;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			args++;
		printf(" %s %d arguments\n", categoryNames[_functionCategory], args);
		printf("%*.*c  {Function name}\n", indent, indent, ' ');
		if (_name != null)
			_name.print(indent + INDENT);
		i = 0;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next, i++) {
			printf("%*.*c  {Function argument %d}\n", indent, indent, ' ', i);
			nl.node.print(indent + INDENT);
		}
		printf("%*.*c  {Function body}\n", indent, indent, ' ');
		if (body != null)
			body.print(indent + INDENT);
	}

	public Category functionCategory() {
		return _functionCategory;
	}

	public ref<Identifier> name() {
		return _name;
	}
/*
	ref<NodeList> returnType() { return _returnType; }

 */

	boolean definesScope() {
		if (_functionCategory == Function.Category.ABSTRACT ||
			body != null)
			return true;
		else
			return false;
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
		ref<NodeList> retType = _returnType;
		if (retType != null) {
			for (ref<NodeList> nl = retType; nl != null; nl = nl.next)
				compileContext.assignTypes(nl.node);
			for (ref<NodeList> nl = retType; nl != null; nl = nl.next) {
				if (nl.node.deferAnalysis()) {
					type = nl.node.type;
					return;
				}
			}
			if (retType.next == null &&
				retType.node.type.family() == TypeFamily.VOID)
				retType = null;
		}
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			if (nl.node.deferAnalysis()) {
				type = nl.node.type;
				return;
			}
		if (deferAnalysis())
			return;
		type = compileContext.pool().newFunctionType(retType, _arguments, definesScope() ? compileContext.current() : null);
		if (_functionCategory == Category.DECLARATOR)
			type = compileContext.makeTypedef(type);
		if (_name != null && _name.symbol() != null)
			_name.symbol().bindType(type);
		if (body == null || retType == null)
			return;
		Test t = body.fallsThrough();
		if (t == Test.PASS_TEST) {
			ref<Block> b = ref<Block>(body);
			if (b.statements() != null) {
				for (ref<NodeList> nl = b.statements(); ; nl = nl.next) {
					if (nl.next == null) {
						nl.node.add(MessageId.RETURN_VALUE_REQUIRED, compileContext.pool());
						break;
					}
				}
			} else
				b.add(MessageId.RETURN_VALUE_REQUIRED, compileContext.pool());
		}
	}
}

private string[Function.Category] categoryNames;
	categoryNames.append("NORMAL");
	categoryNames.append("CONSTRUCTOR");
	categoryNames.append("DESTRUCTOR");
	categoryNames.append("ABSTRACT");

class Reference extends Node {
	private ref<Variable> _variable;
	private boolean _definition;
	private int _offset;
	
	Reference(ref<Variable> v, int offset, boolean definition, Location location) {
		super(Operator.VARIABLE, location);
		type = v.type;
		_variable = v;
		_definition = definition;
		_offset = offset;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		return func(this, data) != TraverseAction.ABORT_TRAVERSAL;
	}
	
	ref<Reference> clone(ref<SyntaxTree> tree) {
		return ref<Reference>(tree.newReference(_variable, _definition, location()).finishClone(this, tree.pool()));
	}

	ref<Reference> cloneRaw(ref<SyntaxTree> tree) {
		return tree.newReference(_variable, _definition, location());
	}

	public ref<Reference> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return this;
	}
	
	public void print(int indent) {
		printBasic(indent);
		printf(" %s V%p", _definition ? "def" : "", _variable);
		if (_offset != 0)
			printf("%+d", _offset);
		printf("\n");
	}

	public ref<Variable> variable() {
		return _variable;
	}
	
	public int offset() {
		return _offset;
	}
}

class Identifier extends Node {
	private CompileString _value;
	private ref<Node> _annotation;
	private boolean _definition;
	private ref<Symbol> _symbol;

	Identifier(ref<Node> annotation, CompileString value, Location location) {
		super(Operator.IDENTIFIER, location);
		_annotation = annotation;
		_value = value;
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
			if (_annotation != null && !_annotation.traverse(t, func, data))
				return false;
			break;

		case	IN_ORDER:
		case	POST_ORDER:
			if (_annotation != null && !_annotation.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	REVERSE_PRE_ORDER:
		case	REVERSE_IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (_annotation != null && !_annotation.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_POST_ORDER:
			if (_annotation != null && !_annotation.traverse(t, func, data))
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

	public ref<Identifier> clone(ref<SyntaxTree> tree) {
		byte[] value;
		value.resize(_value.length);
		memcpy(&value[0], _value.data, _value.length);
		CompileString cs(&value);
		ref<Identifier> id = tree.newIdentifier(_annotation, cs, location());
		id._symbol = _symbol;
		id._definition = _definition;
		return ref<Identifier>(id.finishClone(this, tree.pool()));
	}

	public ref<Identifier> cloneRaw(ref<SyntaxTree> tree) {
		byte[] value;
		value.resize(_value.length);
		memcpy(&value[0], _value.data, _value.length);
		CompileString cs(&value);
		ref<Identifier> id = tree.newIdentifier(_annotation, cs, location());
		id._definition = _definition;
		return id;
	}

	public ref<Identifier> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return this;
	}
	
	public void print(int indent) {
		if (_annotation != null)
			_annotation.print(indent + INDENT);
		printBasic(indent);
		printf(" %s S%p '%s'", _definition ? "def" : "", _symbol, _value.asString());
		if (_symbol != null)
			printf(" %s", StorageClassMap.name[_symbol.storageClass()]);
		printf("\n");
	}

	public void markupDeclarator(ref<Type> t, ref<CompileContext> compileContext) {
		if (_symbol != null) {
			if (!_symbol.bindType(t)) {
				add(MessageId.UNFINISHED_MARKUP_DECLARATOR, compileContext.pool(), CompileString("  "/*this.class.name()*/), CompileString(operatorMap.name[op()]));
				type = compileContext.errorType();
				return;
			}
			assignTypes(compileContext);
			type = t;
		}
	}

	public void assignOverload(ref<NodeList> arguments, Operator kind, ref<CompileContext> compileContext) {
		(type, _symbol) = compileContext.current().assignOverload(this, _value, arguments, kind, compileContext);
	}

	public ref<Symbol> symbol() {
		return _symbol;
	}

	public boolean conforms(ref<Node> other) {
		if (other.op() != op())
			return false;
		ref<Identifier> id = ref<Identifier>(other);
		return _value.equals(id._value);
	}

	public ref<Namespace> makeNamespaces(ref<Scope> domainScope, ref<CompileContext> compileContext) {
		ref<Namespace> nm = domainScope.defineNamespace(this, &_value, compileContext);
		if (nm == null) {
			add(MessageId.DUPLICATE, compileContext.pool(), _value);
			return null;
		}
		nm.assignType(compileContext);
		_symbol = nm;
		return nm;
	}

	public ref<Namespace> getNamespace(ref<Scope> domainScope) {
		ref<Symbol> sym = domainScope.lookup(&_value);
		if (sym != null && sym.class == Namespace)
			return ref<Namespace>(sym);
		else
			return null;
	}

	public void bind(ref<Scope> enclosing, ref<Node> typeExpression, ref<Node> initializer, ref<CompileContext> compileContext) {
		_definition = true;
		_symbol = enclosing.define(compileContext.visibility, compileContext.isStatic ? StorageClass.STATIC : StorageClass.ENCLOSING, compileContext.annotations, this, typeExpression, initializer, compileContext.pool());
		if (_symbol == null) {
			add(MessageId.DUPLICATE, compileContext.pool(), _value);
			type = compileContext.errorType();
		}
	}
/*
	ref<Symbol> bind(ref<Scope> enclosing, ref<Type> type, ref<Node> initializer, ref<CompileContext> compileContext);
*/
	ref<Symbol> bindEnumInstance(ref<Scope> enclosing, ref<Type> type, ref<Node> initializer, ref<CompileContext> compileContext) {
		_definition = true;
		_symbol = enclosing.define(compileContext.visibility, StorageClass.ENUMERATION, compileContext.annotations, this, type, initializer, compileContext.pool());
		if (_symbol == null)
			add(MessageId.DUPLICATE, compileContext.pool(), _value);
		return _symbol;
	}

	ref<ClassScope> bindClassName(ref<Scope> enclosing, ref<Class> body, ref<CompileContext> compileContext) {
		_definition = true;
		ref<ClassScope> classScope = compileContext.createClassScope(body, this);
		_symbol = enclosing.define(compileContext.visibility, StorageClass.STATIC, compileContext.annotations, this, body, body, compileContext.pool());
		if (_symbol != null) {
			classScope.classType = compileContext.pool().newClassType(body, classScope);
			ref<Type> t = compileContext.makeTypedef(classScope.classType);
			_symbol.bindType(t);
			return classScope;
		} else {
			add(MessageId.DUPLICATE, compileContext.pool(), _value);
			return null;
		}
	}

	void bindEnumName(ref<Scope> enclosing, ref<Block> body, ref<CompileContext> compileContext) {
		_definition = true;
		ref<EnumScope> enumScope = compileContext.createEnumScope(body, this);
		_symbol = enclosing.define(compileContext.visibility, StorageClass.STATIC, compileContext.annotations, this, body, body, compileContext.pool());
		if (_symbol != null) {
			ref<ClassType> c = compileContext.pool().newClassType(ref<Type>(null), enumScope);
			ref<Type> t = compileContext.pool().newEnumInstanceType(_symbol, enumScope, c);
			enumScope.enumType = compileContext.pool().newEnumType(body, enumScope, t);
			_symbol.bindType(enumScope.enumType);
		} else
			add(MessageId.DUPLICATE, compileContext.pool(), _value);
	}

	void bindFunctionOverload(Operator visibility, boolean isStatic, ref<Node> annotations, ref<Scope> enclosing, ref<ParameterScope> funcScope, ref<CompileContext> compileContext) {
		_definition = true;
		ref<Overload> o = enclosing.defineOverload(&_value, Operator.FUNCTION, compileContext.pool());
		if (o != null)
			_symbol = o.addInstance(visibility, isStatic, annotations, this, funcScope, compileContext);
		else
			add(MessageId.OVERLOAD_DISALLOWED, compileContext.pool(), _value);
	}

	void bindTemplateOverload(Operator visibility, boolean isStatic, ref<Node> annotations, ref<Scope> enclosing, ref<Template> templateDef, ref<CompileContext> compileContext) {
		_definition = true;
		ref<ParameterScope> templateScope = compileContext.createParameterScope(templateDef, StorageClass.TEMPLATE);
		ref<Overload> o = enclosing.defineOverload(&_value, Operator.TEMPLATE, compileContext.pool());
		if (o != null) {
			_symbol = o.addInstance(visibility, isStatic, annotations, this, templateScope, compileContext);
			if (_symbol == null)
				return;
			ref<Type> t = compileContext.makeTypedef(compileContext.pool().newTemplateType(templateDef, compileContext.definingFile, o, templateScope));
			_symbol.bindType(t);
		} else
			add(MessageId.OVERLOAD_DISALLOWED, compileContext.pool(), _value);
	}

	void bindConstructor(Operator visibility, ref<Scope> enclosing, ref<ParameterScope> funcScope, ref<CompileContext> compileContext) {
		_definition = true;
		_symbol = compileContext.pool().newOverloadInstance(visibility, false, enclosing, compileContext.annotations, &_value, funcScope.definition(), funcScope);
	}

	void bindDestructor(Operator visibility, ref<Scope> enclosing, ref<ParameterScope> funcScope, ref<CompileContext> compileContext) {
		_definition = true;
		_symbol = compileContext.pool().newOverloadInstance(visibility, false, enclosing, compileContext.annotations, &_value, funcScope.definition(), funcScope);
	}

	void resolveAsEnum(ref<Type> enumType, ref<CompileContext>  compileContext) {
		_symbol = enumType.scope().lookup(&_value);
		if (_symbol == null) {
			type = compileContext.errorType();
			add(MessageId.UNDEFINED, compileContext.pool(), _value);
		} else
			type = enumType;
	}

	CompileString value() {
		return _value;
	}
/*
	bool definition() const { return _definition; }
*/
	public ref<CompileString> identifier() { 
		return &_value;
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		if (_definition) {
			if (_symbol.declaredStorageClass() == StorageClass.STATIC && _symbol.enclosing().storageClass() == StorageClass.STATIC) {
				add(MessageId.STATIC_DISALLOWED, compileContext.pool());
				type = compileContext.errorType();
			} else
				type = compileContext.arena().builtInType(TypeFamily.VOID);
			return;
		}
		for (ref<Scope> s = compileContext.current(); s != null; s = s.enclosing()) {
			ref<Scope> available = s;
			do {
				_symbol = available.lookup(&_value);
				if (_symbol != null) {
					// For non-lexical scopes (i.e. base classes), do not include private
					// variables.
					if (available != s && _symbol.visibility() == Operator.PRIVATE)
						break;
					if (_symbol.class == Overload) {
						ref<Overload> o = ref<Overload>(_symbol);
						if (o.instances().length() == 1)
							_symbol = o.instances()[0];
						else {
							add(MessageId.AMBIGUOUS_REFERENCE, compileContext.pool());
							type = compileContext.errorType();
							return;
						}
					}
					type = _symbol.assignType(compileContext);
					return;
				}
				available = available.base(compileContext);
			} while (available != null);
		}
		type = compileContext.errorType();
		add(MessageId.UNDEFINED, compileContext.pool(), _value);
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
					if (!_enclosingScope.defineImport(localName, symbol))
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
				return true;

			case	CLASS:
				if (newType.indirectType(compileContext) != null)
					return true;
				break;

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
			while (scope != null&& scope.storageClass() != StorageClass.MEMBER)
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
			for (int i = 0; i < int(TypeFamily.BUILTIN_TYPES); i++) {
				ref<Type> b = compileContext.arena().builtInType(TypeFamily(i));
				if (b != null && b.equals(t)) {
					t = b;
					break;
				}
			}
			type = compileContext.arena().createRef(t, compileContext);
			break;
		}
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

class ParameterBag extends Node {
	protected ref<NodeList> _arguments;
	
	ParameterBag(Operator op, ref<NodeList> arguments, Location location) {
		super(op, location);
		_arguments = arguments;
	}

	public ref<NodeList> arguments() {
		return _arguments;
	}
	

	public int argumentCount() {
		int i = 0;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			i++;
		return i;
	}

	public void reverseArgumentOrder() {
		ref<NodeList> list = null;
		ref<NodeList> nlNext;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nlNext) {
			nlNext = nl.next;
			nl.next = list;
			list = nl;
		}
		_arguments = list;
	}
}

class StackArgumentAddress extends Node {
	int	_offset;
	
	StackArgumentAddress(int offset, Location location) {
		super(Operator.STACK_ARGUMENT_ADDRESS, location);
		_offset = offset;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result = func(this, data);
		if (result == TraverseAction.ABORT_TRAVERSAL)
			return false;
		else
			return true;
	}

	public ref<StackArgumentAddress> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return this;
	}
	
	public ref<StackArgumentAddress> clone(ref<SyntaxTree> tree) {
		return ref<StackArgumentAddress>(tree.newStackArgumentAddress(_offset, location()).finishClone(this, tree.pool()));
	}

	public ref<StackArgumentAddress> cloneRaw(ref<SyntaxTree> tree) {
		return tree.newStackArgumentAddress(_offset, location());
	}

	public void print(int indent) {
		printBasic(indent);
		printf(" offset %d\n", _offset);
	}
}

class EllipsisArguments extends ParameterBag {
	EllipsisArguments(ref<NodeList> args, Location location) {
		super(Operator.ELLIPSIS_ARGUMENTS, args, location);
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
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (_arguments != null && !_arguments.traverse(t, func, data))
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
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (_arguments != null && !_arguments.reverse(t, func, data))
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

	public ref<EllipsisArguments> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			nl.node = nl.node.fold(tree, false, compileContext);
		return this;
	}
	
	public ref<EllipsisArguments> clone(ref<SyntaxTree> tree) {
		ref<NodeList> arguments = _arguments != null ? _arguments.clone(tree) : null;
		return ref<EllipsisArguments>(tree.newEllipsisArguments(arguments, location()).finishClone(this, tree.pool()));
	}

	public ref<EllipsisArguments> cloneRaw(ref<SyntaxTree> tree) {
		ref<NodeList> arguments = _arguments != null ? _arguments.cloneRaw(tree) : null;
		return tree.newEllipsisArguments(arguments, location());
	}

	public void print(int indent) {
		printBasic(indent);
		printf("\n");
		int i = 0;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next, i++) {
			printf("%*.*c  {Ellipsis Argument %d}\n", indent, indent, ' ', i);
			nl.node.print(indent + INDENT);
		}
	}
	
	public int stackConsumed() {
		int exact = argumentCount() * type.size();
		return (exact + (address.bytes - 1)) & ~(address.bytes - 1);
	}
}

class Return extends ParameterBag {
	Return(ref<NodeList> expressions, Location location) {
		super(Operator.RETURN, expressions, location);
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
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (_arguments != null && !_arguments.traverse(t, func, data))
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
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (_arguments != null && !_arguments.reverse(t, func, data))
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

	public ref<Return> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			nl.node = nl.node.fold(tree, false, compileContext);
		return this;
	}
	
	public ref<Return> clone(ref<SyntaxTree> tree) {
		ref<NodeList> arguments = _arguments != null ? _arguments.clone(tree) : null;
		return ref<Return>(tree.newReturn(arguments, location()).finishClone(this, tree.pool()));
	}

	public ref<Return> cloneRaw(ref<SyntaxTree> tree) {
		ref<NodeList> arguments = _arguments != null ? _arguments.cloneRaw(tree) : null;
		return tree.newReturn(arguments, location());
	}

	public Test fallsThrough() {
		return Test.FAIL_TEST;
	}

	public void print(int indent) {
		printBasic(indent);
		printf("\n");
		int i = 0;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next, i++) {
			printf("%*.*c  {Return expression %d}\n", indent, indent, ' ', i);
			nl.node.print(indent + INDENT);
		}
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		ref<Function> func = compileContext.current().enclosingFunction();
		if (func == null) {
			add(MessageId.RETURN_DISALLOWED, compileContext.pool());
			type = compileContext.errorType();
			return;
		}
		if (_arguments != null) {
			for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
				compileContext.assignTypes(nl.node);
			for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
				if (nl.node.deferAnalysis()) {
					type = nl.node.type;
					return;
				}
		}
		if (func.deferAnalysis()) {
			type = func.type;
			return;
		}
		ref<FunctionType> functionType = ref<FunctionType>(func.type);
		if (functionType == null) {
			add(MessageId.NOT_A_TYPE, compileContext.pool());
			type = compileContext.errorType();
			return;
		}
		ref<NodeList> returnType = functionType.returnType();
		if (_arguments != null) {
			if (returnType == null) {
				add(MessageId.RETURN_VALUE_DISALLOWED, compileContext.pool());
				type = compileContext.errorType();
			} else {
				type = returnType.node.type;
				for (ref<NodeList> arg = _arguments; arg != null; arg = arg.next, returnType = returnType.next)
					arg.node = arg.node.coerce(compileContext.tree(), returnType.node.type, false, compileContext);
				for (ref<NodeList> arg = _arguments; arg != null; arg = arg.next) {
					if (arg.node.deferAnalysis()) {
						type = arg.node.type;
						return;
					}
				}
			}
		} else {
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			if (returnType != null) {
				add(MessageId.RETURN_VALUE_REQUIRED, compileContext.pool());
				type = compileContext.errorType();
			}
		}
	}
}

class Selection extends Node {
	private ref<Node> _left;
	private CompileString _name;
	private ref<Symbol> _symbol;
	private boolean _indirect;

	Selection(ref<Node> left, CompileString name, Location location) {
		super(Operator.DOT, location);
		_left = left;
		_name = name;
	}

	Selection(ref<Node> left, ref<Symbol> symbol, Location location) {
		super(Operator.DOT, location);
		_left = left;
		_symbol = symbol;
		_name = *symbol.name();
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
			if (!_left.traverse(t, func, data))
				return false;
			break;

		case	IN_ORDER:
			if (!_left.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

		case	POST_ORDER:
			if (!_left.traverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			break;

		case	REVERSE_PRE_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_left.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_left.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_POST_ORDER:
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

	public ref<Selection> clone(ref<SyntaxTree> tree) {
		ref<Node> left = _left != null ? _left.clone(tree) : null;
		ref<Selection> copy = tree.newSelection(left, _name, location());
		copy._symbol = _symbol;
		return ref<Selection>(copy.finishClone(this, tree.pool()));
	}

	public ref<Selection> cloneRaw(ref<SyntaxTree> tree) {
		ref<Node> left = _left != null ? _left.cloneRaw(tree) : null;
		return tree.newSelection(left, _name, location());
	}

	public void assignOverload(ref<NodeList> arguments, Operator kind, ref<CompileContext> compileContext) {
		compileContext.assignTypes(_left);
		if (_left.deferAnalysis()) {
			type = _left.type;
			return;
		}
		OverloadOperation operation(kind, this, &_name, arguments, compileContext);
		ref<Type> t;
		switch (_left.type.family()) {
		case	VAR:
			type = _left.type;
			return;

		case	TYPEDEF:
			t = _left.unwrapTypedef(compileContext);
			type = operation.includeClass(t, compileContext);
			if (type != null)
				return;
			(type, _symbol) = operation.result();
			if (type.deferAnalysis())
				return;
			if (_symbol.storageClass() != StorageClass.STATIC) {
				add(MessageId.ONLY_STATIC_VARIABLE, compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		default:
			ref<Symbol> sym = _left.type.lookup(&_name, compileContext);
			if (sym != null && sym.class == PlainSymbol) {
				type = sym.assignType(compileContext);
				_symbol = sym;
				return;
			}
			type = operation.includeClass(_left.type, compileContext);
			if (type != null)
				return;
			if (operation.anyPotentialOverloads()) {
				(type, _symbol) = operation.result();
				return;
			}
			t = _left.type.indirectType(compileContext);
			operation.restart();
			if (t != null) {
				_indirect = true;
				type = operation.includeClass(t, compileContext);
				if (type != null)
					return;
			}
			(type, _symbol) = operation.result();
		}
	}

	public boolean conforms(ref<Node> other) {
		if (other.op() != Operator.DOT)
			return false;
		ref<Selection> sel = ref<Selection>(other);
		if (!_name.equals(sel._name))
			return false;
		return _left.conforms(sel._left);
	}

	public void print(int indent) {
		_left.print(indent + INDENT);
		printBasic(indent);
		printf(" '%s'", _name.asString());
		if (_indirect)
			printf(" indirect ");
		if (_symbol != null)
			printf(" S%p", _symbol);
		printf("\n");
	}

	public ref<CompileString> identifier() {
		return &_name;
	}

	public ref<Symbol> symbol() {
		return _symbol;
	}

	public ref<Namespace> makeNamespaces(ref<Scope> domainScope, ref<CompileContext> compileContext) {
		ref<Namespace> outer = _left.makeNamespaces(domainScope, compileContext);
		if (outer != null)
			return outer.symbols().defineNamespace(this, identifier(), compileContext);
		else
			return outer;
	}

	public ref<Namespace> getNamespace(ref<Scope> domainScope) {
		ref<Namespace> outer = _left.getNamespace(domainScope);
		if (outer != null) {
			ref<Symbol> sym = outer.symbols().lookup(identifier());
			if (sym != null && sym.class == Namespace)
				return ref<Namespace>(sym);
		}
		return null;
	}

	public ref<Node> left() {
		return _left; 
	}

	public CompileString name() {
		return _name; 
	}

	public boolean indirect() {
		return _indirect;
	}
 
	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		if (_left.op() == Operator.SUBSCRIPT) {
			ref<Node> element = ref<Binary>(_left).subscriptModify(tree, compileContext);
			if (element != null)
				_left = element;
		}
		_left = _left.fold(tree, false, compileContext);
		// Flatten an INDIRECT node to simplify code gen later.
		if (_left.op() == Operator.INDIRECT && !_indirect) {
			ref<Unary> u = ref<Unary>(_left);
			_left = u.operand();
			_indirect = true;
		}
		return this;
	}
	
	private void assignTypes(ref<CompileContext> compileContext) {
		compileContext.assignTypes(_left);
		if (_left.deferAnalysis()) {
			type = _left.type;
			return;
		}
		ref<Type> t;
		switch (_left.type.family()) {
		case	VAR:
			type = _left.type;
			return;

		case	TYPEDEF:
			if (lookupInType(_left.unwrapTypedef(compileContext), compileContext)) {
				if (deferAnalysis())
					return;
				switch (_symbol.storageClass()) {
				case	STATIC:
				case	ENUMERATION:
				case	MEMBER:
					break;

				default:
					add(MessageId.ONLY_STATIC_VARIABLE, compileContext.pool());
					type = compileContext.errorType();
				}
				return;
			}
			break;

		default:
			if (lookupInType(_left.type, compileContext))
				return;
			t = _left.type.indirectType(compileContext);
			if (t != null) {
				if (lookupInType(t, compileContext)) {
					_indirect = true;
					return;
				}
			}
		}
		add(MessageId.UNDEFINED, compileContext.pool(), _name);
		type = compileContext.errorType();
	}

	private boolean lookupInType(ref<Type> t, ref<CompileContext> compileContext) {
		ref<Symbol> sym = t.lookup(&_name, compileContext);
		if (sym != null) {
			if (sym.class == Overload) {
				ref<Overload> o = ref<Overload>(sym);
				if (o.instances().length() == 1) {
					_symbol = o.instances()[0];
					type = _symbol.assignType(compileContext);
				} else {
					add(MessageId.AMBIGUOUS_REFERENCE, compileContext.pool());
					type = compileContext.errorType();
				}
				return true;
			}
			if (sym.class != PlainSymbol) {
				add(MessageId.NOT_SIMPLE_VARIABLE, compileContext.pool(), _name);
				type = compileContext.errorType();
				return true;
			}
			type = sym.assignType(compileContext);
			_symbol = sym;
			return true;
		}
		return false;
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
		if (op() == Operator.IF) {
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
			_middle = tree.newUnary(Operator.LOAD, _middle, _middle.location());
			_middle.type = type;
			_right = tree.newUnary(Operator.LOAD, _right, _right.location());
			_right.type = type;
			
		case	IF:
			if (_left != null)
				_left = _left.fold(tree, false, compileContext);
			if (_middle != null)
				_middle = _middle.fold(tree, true, compileContext);
			if (_right != null)
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
			if (_left.type.family() != TypeFamily.BOOLEAN) {
				add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
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
			if (_left.type.family() != TypeFamily.BOOLEAN) {
				add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	NAMESPACE:
			type = compileContext.arena().builtInType(TypeFamily.VOID);
		}
	}
}

class Unary extends Node {
	private ref<Node> _operand;

	Unary(Operator op, ref<Node> operand, Location location) {
		super(op, location);
		_operand = operand;
	}

	public boolean traverse(Traversal t, TraverseAction func(ref<Node> n, address data), address data) {
		TraverseAction result;

		// These operators are 'unary' but have slightly different traversal rules from the
		// ordinary unary operators

		switch (op()) {
		case	INCREMENT_AFTER:
		case	DECREMENT_AFTER:
		case	ELLIPSIS:
		case	VECTOR_OF:
		case	BYTES:
		case	CLASS_OF:
			switch (t) {
			case	IN_ORDER:
				t = Traversal.POST_ORDER;
				break;

			case	REVERSE_IN_ORDER:
				t = Traversal.REVERSE_PRE_ORDER;
			}
		}
		switch (t) {
		case	PRE_ORDER:
		case	IN_ORDER:
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			if (result == TraverseAction.SKIP_CHILDREN)
				break;
			if (!_operand.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (!_operand.traverse(t, func, data))
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
			if (!_operand.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
		case	REVERSE_POST_ORDER:
			if (!_operand.traverse(t, func, data))
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

	public ref<Unary> clone(ref<SyntaxTree> tree) {
		ref<Node> operand = _operand != null ? _operand.clone(tree) : null;
		return ref<Unary>(tree.newUnary(op(), operand, location()).finishClone(this, tree.pool()));
	}

	public ref<Node> cloneRaw(ref<SyntaxTree> tree) {
		if (op() == Operator.CAST)
			return _operand.cloneRaw(tree);
		ref<Node> operand = _operand != null ? _operand.cloneRaw(tree) : null;
		return tree.newUnary(op(), operand, location());
	}

	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		if (deferGeneration())
			return this;
		switch (op()) {
		case	DECLARE_NAMESPACE:
			// No need to do anything for these sub-trees.
			return this;
			
		case	PUBLIC:
		case	PRIVATE:
		case	PROTECTED:
		case	STATIC:
		case	ELLIPSIS:
		case	UNWRAP_TYPEDEF:
		case	VECTOR_OF:
		case	ABSTRACT:
		case	DEFAULT:

		case	CLASS_OF:
		case	UNARY_PLUS:
		case	NEGATE:
		case	BIT_COMPLEMENT:
		case	DECREMENT_BEFORE:
		case	INCREMENT_BEFORE:
		case	DECREMENT_AFTER:
		case	INCREMENT_AFTER:
		case	NOT:
		case	INDIRECT:
		case	BYTES:
		case	LOAD:
			break;

		case	CAST:
			if (_operand.type.extendsFormally(type, compileContext)) {
				if (_operand.isLvalue()) {
					_operand = _operand.fold(tree, false, compileContext);
					_operand.type = type;
					return _operand;
				}
			}
			switch (type.family()) {
			case	UNSIGNED_16:
			case	SIGNED_32:
			case	STRING:
			case	SIGNED_64:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "integerValue", tree, compileContext);
					return call.fold(tree, false, compileContext);
				}
				break;
				
			case	FLOAT_32:
			case	FLOAT_64:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "floatValue", tree, compileContext);
					return call.fold(tree, false, compileContext);
				}
				break;
				
			case	CLASS:
				if (type.indirectType(compileContext) != null) {
					switch (_operand.type.family()) {
					case	VAR:
						ref<Node> call = createMethodCall(_operand, "integerValue", tree, compileContext);
						return call.fold(tree, false, compileContext);
					}
				}
				break;
				
			case	VAR:
				assert(type.scope() != null);
				ref<Type> targetType = null;
				switch (_operand.type.family()) {
				case	BOOLEAN:
					targetType = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					break;
					
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	UNSIGNED_64:
				case	SIGNED_8:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
					targetType = compileContext.arena().builtInType(TypeFamily.SIGNED_64);
					break;
					
				case	FLOAT_32:
				case	FLOAT_64:
					targetType = compileContext.arena().builtInType(TypeFamily.FLOAT_64);
					break;
					
				case	ADDRESS:
					targetType = compileContext.arena().builtInType(TypeFamily.ADDRESS);
					break;
					
				case	STRING:
					targetType = compileContext.arena().builtInType(TypeFamily.STRING);
					break;
					
				case	ENUM:
					print(0);
					assert(false);
					
				case	CLASS:
					if (_operand.type.indirectType(compileContext) != null) {
						for (int i = 0; i < type.scope().constructors().length(); i++) {
							ref<Function> f = ref<Function>(type.scope().constructors()[i].definition());
							ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
							if (oi.parameterCount() != 2)
								continue;
							if (oi.parameterScope().parameters()[0].type().family() == TypeFamily.ADDRESS &&
									oi.parameterScope().parameters()[1].type().family() == TypeFamily.SIGNED_64) {
								ref<Variable> temp = compileContext.newVariable(type);
								_operand = _operand.fold(tree, false, compileContext);
								ref<Node> empty = tree.newLeaf(Operator.EMPTY, location());
								empty.type = _operand.type;
								ref<Node> typeOperand = tree.newUnary(Operator.CLASS_OF, empty, location());
								// The type of the CLASS_OF operand is irrelevant.
								typeOperand.type = compileContext.arena().builtInType(TypeFamily.VOID);
								ref<NodeList> args = tree.newNodeList(typeOperand, _operand);
								ref<Reference> r = tree.newReference(temp, true, location());
								ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, location());
								adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
								ref<Call> constructor = tree.newCall(oi, CallCategory.CONSTRUCTOR, adr, args, location());
								constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
								if (voidContext)
									return constructor.fold(tree, true, compileContext);
								r = tree.newReference(temp, false, location());
								ref<Binary> seq = tree.newBinary(Operator.SEQUENCE, constructor, r, location());
								seq.type = type;
								return seq.fold(tree, false, compileContext);
							}
						}
						targetType = _operand.type;
						break;
					}
					
				default:
					print(0);
					assert(false);
				}
				for (int i = 0; i < type.scope().constructors().length(); i++) {
					ref<Function> f = ref<Function>(type.scope().constructors()[i].definition());
					ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
					if (oi.parameterCount() != 1)
						continue;
					if (oi.parameterScope().parameters()[0].type() == targetType) {
						ref<Variable> temp = compileContext.newVariable(type);
						_operand = _operand.fold(tree, false, compileContext);
						if (_operand.type != targetType)
							_operand = tree.newCast(targetType, _operand);
						ref<NodeList> args = tree.newNodeList(_operand);
						ref<Reference> r = tree.newReference(temp, true, location());
						ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, location());
						adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
						ref<Call> constructor = tree.newCall(oi, CallCategory.CONSTRUCTOR, adr, args, location());
						constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
						if (voidContext)
							return constructor.fold(tree, true, compileContext);
						r = tree.newReference(temp, false, location());
						ref<Binary> seq = tree.newBinary(Operator.SEQUENCE, constructor, r, location());
						seq.type = type;
						return seq.fold(tree, false, compileContext);
					}
				}
			}
			break;

		case	ADDRESS:
			if (_operand.op() == Operator.SUBSCRIPT) {
				ref<Binary> b = ref<Binary>(_operand);
				if (b.left().type.isVector(compileContext)) {
					CompileString name("elementAddress");
					
					ref<Symbol> sym = b.left().type.lookup(&name, compileContext);
					if (sym == null || sym.class != Overload) {
						add(MessageId.UNDEFINED, compileContext.pool(), name);
						break;
					}
					ref<OverloadInstance> oi = ref<Overload>(sym).instances()[0];
					ref<Selection> method = tree.newSelection(b.left(), oi, location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(b.right());
					ref<Call> call = tree.newCall(oi, null,  method, args, location());
					call.type = type;
					return call.fold(tree, voidContext, compileContext);
/*
				} else if (b.left().type.isMap(compileContext)) {
					ref<Symbol> sym = b.left().type.scope().lookup("createEmpty");
					if (sym.class != Overload) {
						target.unfinished(n, "createEmpty is not an Overloaded symbol", compileContext);
						break;
					}
					sym = ref<Overload>(sym).instances()[0];
					generate(b.right(), target, compileContext);
					pushAddress(b.left(), target, compileContext);
					if (sym.type().family() != TypeFamily.FUNCTION) {
						target.unfinished(n, "createEmpty not a function", compileContext);
						break;
					}
					ref<FunctionType> functionType = ref<FunctionType>(sym.type());
					checkStack(target);
					ref<Value>  value = target.unit().getCode(functionType.scope(), target, compileContext);
					target.byteCode(ByteCodes.CALL);
					target.byteCode(value.index());
					target.popSp(address.bytes);
				} else if (b.left().type.family() == TypeFamily.STRING) {
					generate(b.left(), target, compileContext);
					target.byteCode(ByteCodes.INT);
					target.byteCode(int(int.bytes));
					target.byteCode(ByteCodes.ADD);
					generate(b.right(), target, compileContext);
					target.byteCode(ByteCodes.ADD);
					target.popSp(address.bytes);
				} else {
					generate(b.left(), target, compileContext);
					generate(b.right(), target, compileContext);
					ref<Type> t = b.left().type.indirectType(compileContext);
					if (t != null && t.size() > 1) {
						target.byteCode(ByteCodes.INT);
						target.byteCode(t.size());
						target.byteCode(ByteCodes.MUL);
					}
					target.byteCode(ByteCodes.ADD);
					target.popSp(address.bytes);
*/
				}
			}
			break;
			
		case	EXPRESSION:
			_operand = foldVoidContext(_operand, tree, compileContext);
			if (_operand.op() == Operator.IF)
				return _operand;
			else
				return this;
			
		default:
			print(0);
			assert(false);
		}
		_operand = _operand.fold(tree, false, compileContext);
		return this;
	}
	
	public long foldInt(ref<CompileContext> compileContext) {
		switch (op()) {
		case	NEGATE:
			return -_operand.foldInt(compileContext);
		}
		add(MessageId.UNFINISHED_GENERATE, compileContext.pool(), CompileString(" "/*this.class.name()*/), CompileString(operatorMap.name[op()]), CompileString("Unary.foldInt"));
		return 0;
	}

	public void print(int indent) {
		printBasic(indent);
		printf("\n");
		_operand.print(indent + INDENT);
	}

	public ref<Node> operand() {
		return _operand; 
	}
 
	public boolean isConstant() {
		switch (op()) {
		case	NEGATE:
			return _operand.isConstant();

		default:
			return false;
		}
		return false;
	}

	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	ABSTRACT:
		case	PRIVATE:
		case	PROTECTED:
		case	PUBLIC:
		case	STATIC:
		case	DEFAULT:
		case	EXPRESSION:
			compileContext.assignTypes(_operand);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	ADDRESS:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				return;
			}
			if (!_operand.isLvalue()) {
				add(MessageId.NOT_ADDRESSABLE, compileContext.pool());
				type = compileContext.errorType();
			} else if (_operand.op() == Operator.SUBSCRIPT)
				type = compileContext.arena().createPointer(_operand.type, compileContext);
			else
				type = compileContext.arena().createRef(_operand.type, compileContext);
			break;

		case	DECLARE_NAMESPACE:
			compileContext.assignTypes(_operand);
			type = _operand.type;
			break;

		case	INDIRECT:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				return;
			}
			type = _operand.type.indirectType(compileContext);
			if (type == null) {
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	NEGATE:
		case	UNARY_PLUS:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				return;
			}
			switch (_operand.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
				type = _operand.type;
				break;

			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	BIT_COMPLEMENT:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				return;
			}
			switch (_operand.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
				type = _operand.type;
				break;

			default:
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	NOT:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				break;
			}
			if (_operand.type.family() != TypeFamily.BOOLEAN) {
				add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			} else
				type = _operand.type;
			break;

		case	VECTOR_OF:{
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				return;
			}
			ref<Type> vectorType = compileContext.arena().buildVectorType(_operand.unwrapTypedef(compileContext), null, compileContext);
			type = compileContext.makeTypedef(vectorType);
			break;
		}
		case	ELLIPSIS:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				break;
			}
			ref<Type> vectorType = compileContext.arena().buildVectorType(_operand.unwrapTypedef(compileContext), null, compileContext);
			type = compileContext.makeTypedef(vectorType);
			break;

		case	DECREMENT_BEFORE:
		case	INCREMENT_BEFORE:
		case	DECREMENT_AFTER:
		case	INCREMENT_AFTER:
			compileContext.assignTypes(_operand);
			type = _operand.type;
			if (_operand.deferAnalysis()) {
				break;
			}
			if (!_operand.isLvalue()) {
				add(MessageId.NOT_ADDRESSABLE, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			switch (type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
				break;

			case	CLASS:
				if (type.isPointer(compileContext)) {
					break;
				}

			default:
				add(MessageId.NOT_NUMERIC, compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	BYTES:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				break;
			}
			type = compileContext.arena().builtInType(TypeFamily.SIGNED_32);
			break;

		case	CLASS_OF:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				break;
			}
			switch (_operand.type.family()) {
			case	CLASS:
			case	VAR:
				type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
				break;

			default:
				break;
			}
			break;

		case	UNWRAP_TYPEDEF:
			type = _operand.unwrapTypedef(compileContext);
			break;
		}
	}
}

class Node {
	private Operator _op;
	private Location _location;
	private ref<Commentary> _commentary;

	public ref<Type> type;
	public byte register;
	public byte flags;
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
		flags = original.flags;
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

	public void markupDeclarator(ref<Type> type, ref<CompileContext> compileContext) {
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

	public Test fallsThrough() {
		return Test.PASS_TEST;
	}

	public Test containsBreak() {
		return Test.FAIL_TEST;
	}

	public boolean conforms(ref<Node> other) {
		return false;
	}

	public void assignTypesAtScope(ref<CompileContext> compileContext) {
		if (type == null) {
			assignTypes(compileContext);
			if (type == null) {
				add(MessageId.NO_EXPRESSION_TYPE, compileContext.pool());
				type = compileContext.errorType();
			}
		}
	}

	public abstract ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext);

	ref<Node> createMethodCall(ref<Node> object, string functionName, ref<SyntaxTree> tree, ref<CompileContext> compileContext, ref<Node>... arguments) {
		CompileString name(functionName);
		
		ref<Symbol> sym = object.type.lookup(&name, compileContext);
		if (sym == null || sym.class != Overload) {
			add(MessageId.UNDEFINED, compileContext.pool(), name);
			return this;
		}
		ref<OverloadInstance> oi = ref<Overload>(sym).instances()[0];
		ref<Selection> method = tree.newSelection(object, oi, location());
		method.type = oi.type();
		ref<NodeList> args = tree.newNodeList(arguments);
		ref<Call> call = tree.newCall(oi, null, method, args, location());
		call.type = type;
		return call;
	}
	
	public long foldInt(ref<CompileContext> compileContext) {
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

	public ref<Namespace> getNamespace(ref<Scope> domainScope) {
		assert(false);
		return null;
	}

	public ref<Type> unwrapTypedef(ref<CompileContext> compileContext) {
		compileContext.assignTypes(this);
		if (deferAnalysis())
			return type;
		if (_op == Operator.UNWRAP_TYPEDEF)
			return type;
		if (type.family() == TypeFamily.TYPEDEF) {		// if (type instanceof TypedefType)
			ref<TypedefType> tp = ref<TypedefType>(type);
			return tp.wrappedType();
		} else if (type.family() == TypeFamily.CLASS_VARIABLE) {
			return compileContext.arena().builtInType(TypeFamily.CLASS_DEFERRED);
		}
		add(MessageId.NOT_A_TYPE, compileContext.pool());
		type = compileContext.errorType();
		return type;
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
			case	STRING:
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	FLOAT_32:
			case	FLOAT_64:
			case	ENUM:
			case	TYPEDEF:
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
			b.left().assignMultiReturn(returnType, compileContext);
			if (b.left().deferAnalysis()) {
				type = b.left().type;
				return null;
			}
			if (returnType == null) {
				add(MessageId.TOO_MANY_RETURN_ASSIGNMENTS, compileContext.pool());
				type = compileContext.errorType();
				return null;
			}
		} else {
			if (!isLvalue()) {
				add(MessageId.LVALUE_REQUIRED, compileContext.pool());
				type = compileContext.errorType();
				return null;
			}
		}
		return returnType.next;
	}

	public boolean canCoerce(ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
		return type.widensTo(newType, compileContext);
	}

	public ref<Node> coerce(ref<SyntaxTree> tree, TypeFamily newType, boolean explicitCast, ref<CompileContext> compileContext) {
		return coerce(tree, compileContext.arena().builtInType(newType), explicitCast, compileContext);
	}

	public ref<Node> coerce(ref<SyntaxTree> tree, ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
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
		string message = messageMap.format(messageId, args);
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
	
	// Debugging API
	
	public void print(int indent) {
		assert(false);
	}

	public void printBasic(int indent) {
		string name = " ";//this.class.name();

		for (ref<Commentary> comment = _commentary; comment != null; comment = comment.next())
			comment.print(indent + INDENT);
		printf("%*.*c%p %s::%s", indent, indent, ' ', this, name, operatorMap.name[_op]);
		if (type != null) {
			printf(" ");
			type.print();
		}
		if (register != 0)
			printf(" reg %d", int(register));
		if (flags != 0)
			printf(" flags %x", int(flags));
		if (sethi != 0)
			printf(" sethi %d", sethi);
	}


	public Location location() { 
		return _location; 
	}
	
	public ref<Commentary> commentary() {
		return _commentary; 
	}

	boolean definesScope() {
		return false;
	}
 
	public boolean isConstant() {
		return false;
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
	
	void print(int indent) {
		for (ref<NodeList> nl = this; nl != null; nl = nl.next)
			nl.node.print(indent);
	}
}

public OperatorMap operatorMap;

class OperatorMap {
	public OperatorMap() {
		name.resize(Operator.MAX_OPERATOR);
		typeNotAllowed.resize(Operator.MAX_OPERATOR);
		name[Operator.ADD] = "ADD";
		name[Operator.ADD_ASSIGN] = "ADD_ASSIGN";
		name[Operator.AND] = "AND";
		name[Operator.AND_ASSIGN] = "AND_ASSIGN";
		name[Operator.ASSIGN] = "ASSIGN";
		name[Operator.BIT_COMPLEMENT] = "BIT_COMPLEMENT";
		name[Operator.BREAK] = "BREAK";
		name[Operator.CALL] = "CALL";
		name[Operator.CAST] = "CAST";
		name[Operator.CLASS] = "CLASS";
		name[Operator.INTERFACE] = "INTERFACE";
		name[Operator.CONDITIONAL] = "CONDITIONAL";
		name[Operator.CONTINUE] = "CONTINUE";
		name[Operator.DECREMENT_AFTER] = "DECREMENT_AFTER";
		name[Operator.DECREMENT_BEFORE] = "DECREMENT_BEFORE";
		name[Operator.DELETE] = "DELETE";
		name[Operator.DIVIDE] = "DIVIDE";
		name[Operator.DIVIDE_ASSIGN] = "DIVIDE_ASSIGN";
		name[Operator.DOT] = "DOT";
		name[Operator.DOT_DOT] = "DOT_DOT";
		name[Operator.ELLIPSIS] = "ELLIPSIS";
		name[Operator.ELLIPSIS_ARGUMENT] = "ELLIPSIS_ARGUMENT";
		name[Operator.ELLIPSIS_ARGUMENTS] = "ELLIPSIS_ARGUMENTS";
		name[Operator.EQUALITY] = "EQUALITY";
		name[Operator.EXCLUSIVE_OR] = "EXCLUSIVE_OR";
		name[Operator.EXCLUSIVE_OR_ASSIGN] = "EXCLUSIVE_OR_ASSIGN";
		name[Operator.FOR] = "FOR";
		name[Operator.SCOPED_FOR] = "SCOPED_FOR";
		name[Operator.GREATER] = "GREATER";
		name[Operator.GREATER_EQUAL] = "GREATER_EQUAL";
		name[Operator.INCREMENT_AFTER] = "INCREMENT_AFTER";
		name[Operator.INCREMENT_BEFORE] = "INCREMENT_BEFORE";
		name[Operator.ADDRESS] = "ADDRESS";
		name[Operator.INDIRECT] = "INDIRECT";
		name[Operator.BYTES] = "BYTES";
		name[Operator.CLASS_OF] = "CLASS_OF";
		name[Operator.IDENTITY] = "IDENTITY";
		name[Operator.LESS] = "LESS";
		name[Operator.LESS_EQUAL] = "LESS_EQUAL";
		name[Operator.LESS_GREATER] = "LESS_GREATER";
		name[Operator.LESS_GREATER_EQUAL] = "LESS_GREATER_EQUAL";
		name[Operator.LEFT_SHIFT] = "LEFT_SHIFT";
		name[Operator.LEFT_SHIFT_ASSIGN] = "LEFT_SHIFT_ASSIGN";
		name[Operator.LOAD] = "LOAD";
		name[Operator.LOGICAL_AND] = "LOGICAL_AND";
		name[Operator.LOGICAL_OR] = "LOGICAL_OR";
		name[Operator.MULTIPLY] = "MULTIPLY";
		name[Operator.MULTIPLY_ASSIGN] = "MULTIPLY_ASSIGN";
		name[Operator.NEGATE] = "NEGATE";
		name[Operator.NEW] = "NEW";
		name[Operator.NOT] = "NOT";
		name[Operator.NOT_EQUAL] = "NOT_EQUAL";
		name[Operator.NOT_GREATER] = "NOT_GREATER";
		name[Operator.NOT_GREATER_EQUAL] = "NOT_GREATER_EQUAL";
		name[Operator.NOT_IDENTITY] = "NOT_IDENTITY";
		name[Operator.NOT_LESS] = "NOT_LESS";
		name[Operator.NOT_LESS_EQUAL] = "NOT_LESS_EQUAL";
		name[Operator.NOT_LESS_GREATER] = "NOT_LESS_GREATER";
		name[Operator.NOT_LESS_GREATER_EQUAL] = "NOT_LESS_GREATER_EQUAL";
		name[Operator.OR] = "OR";
		name[Operator.OR_ASSIGN] = "OR_ASSIGN";
		name[Operator.REMAINDER] = "REMAINDER";
		name[Operator.REMAINDER_ASSIGN] = "REMAINDER_ASSIGN";
		name[Operator.RIGHT_SHIFT] = "RIGHT_SHIFT";
		name[Operator.RIGHT_SHIFT_ASSIGN] = "RIGHT_SHIFT_ASSIGN";
		name[Operator.SEQUENCE] = "SEQUENCE";
		name[Operator.STACK_ARGUMENT] = "STACK_ARGUMENT";
		name[Operator.STACK_ARGUMENT_ADDRESS] = "STACK_ARGUMENT_ADDRESS";
		name[Operator.SUBSCRIPT] = "SUBSCRIPT";
		name[Operator.SUBTRACT] = "SUBTRACT";
		name[Operator.SUBTRACT_ASSIGN] = "SUBTRACT_ASSIGN";
		name[Operator.SYNTAX_ERROR] = "SYNTAX_ERROR";
		name[Operator.UNSIGNED_RIGHT_SHIFT] = "UNSIGNED_RIGHT_SHIFT";
		name[Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN] = "UNSIGNED_RIGHT_SHIFT_ASSIGN";
		name[Operator.UNARY_PLUS] = "UNARY_PLUS";
		name[Operator.DECLARE_NAMESPACE] = "DECLARE_NAMESPACE";
		name[Operator.INTEGER] = "INTEGER";
		name[Operator.FLOATING_POINT] = "FLOATING_POINT";
		name[Operator.CHARACTER] = "CHARACTER";
		name[Operator.STRING] = "STRING";
		name[Operator.IDENTIFIER] = "IDENTIFIER";
		name[Operator.EMPTY] = "EMPTY";
		name[Operator.EXPRESSION] = "EXPRESSION";
		name[Operator.WHILE] = "WHILE";
		name[Operator.DO_WHILE] = "DO_WHILE";
		name[Operator.LOOP] = "LOOP";
		name[Operator.SWITCH] = "SWITCH";
		name[Operator.RETURN] = "RETURN";
		name[Operator.CASE] = "CASE";
		name[Operator.DEFAULT] = "DEFAULT";
		name[Operator.BLOCK] = "BLOCK";
		name[Operator.VECTOR_OF] = "VECTOR_OF";
		name[Operator.MAP] = "MAP";
		name[Operator.ENUM] = "ENUM";
		name[Operator.BIND] = "BIND";
		name[Operator.TEMPLATE] = "TEMPLATE";
		name[Operator.TEMPLATE_INSTANCE] = "TEMPLATE_INSTANCE";
		name[Operator.FUNCTION] = "FUNCTION";
		name[Operator.UNIT] = "UNIT";
		name[Operator.DECLARATION] = "DECLARATION";
		name[Operator.CLASS_DECLARATION] = "CLASS_DECLARATION";
		name[Operator.ENUM_DECLARATION] = "ENUM_DECLARATION";
		name[Operator.INITIALIZE] = "INITIALIZE";
		name[Operator.ABSTRACT] = "ABSTRACT";
		name[Operator.ANNOTATION] = "ANNOTATION";
		name[Operator.ANNOTATED] = "ANNOTATED";
		name[Operator.CLASS_TYPE] = "CLASS_TYPE";
		name[Operator.CLASS_COPY] = "CLASS_COPY";
		name[Operator.ENUM_TYPE] = "ENUM_TYPE";
		name[Operator.FALSE] = "FALSE";
		name[Operator.FINAL] = "FINAL";
		name[Operator.IF] = "IF";
		name[Operator.IMPORT] = "IMPORT";
		name[Operator.NAMESPACE] = "NAMESPACE";
		name[Operator.NULL] = "NULL";
		name[Operator.PRIVATE] = "PRIVATE";
		name[Operator.PROTECTED] = "PROTECTED";
		name[Operator.PUBLIC] = "PUBLIC";
		name[Operator.STATIC] = "STATIC";
		name[Operator.SUPER] = "SUPER";
		name[Operator.THIS] = "THIS";
		name[Operator.TRUE] = "TRUE";
		name[Operator.UNWRAP_TYPEDEF] = "UNWRAP_TYPEDEF";
		name[Operator.VACATE_ARGUMENT_REGISTERS] = "VACATE_ARGUMENT_REGISTERS";
		name[Operator.VARIABLE] = "VARIABLE";
		typeNotAllowed[Operator.ADD] = MessageId.INVALID_ADD;
		typeNotAllowed[Operator.ADD_ASSIGN] = MessageId.INVALID_ADD;
		typeNotAllowed[Operator.AND] = MessageId.INVALID_AND;
		typeNotAllowed[Operator.AND_ASSIGN] = MessageId.INVALID_AND;
		typeNotAllowed[Operator.ASSIGN] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.BIT_COMPLEMENT] = MessageId.INVALID_BIT_COMPLEMENT;
		typeNotAllowed[Operator.BREAK] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.BYTES] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CALL] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CAST] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CLASS] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CLASS_COPY] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CONDITIONAL] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CONTINUE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DECLARE_NAMESPACE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DECREMENT_AFTER] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DECREMENT_BEFORE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DELETE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DIVIDE] = MessageId.INVALID_DIVIDE;
		typeNotAllowed[Operator.DIVIDE_ASSIGN] = MessageId.INVALID_DIVIDE;
		typeNotAllowed[Operator.DOT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DOT_DOT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ELLIPSIS] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ELLIPSIS_ARGUMENT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ELLIPSIS_ARGUMENTS] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.EQUALITY] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.EXCLUSIVE_OR] = MessageId.INVALID_XOR;
		typeNotAllowed[Operator.EXCLUSIVE_OR_ASSIGN] = MessageId.INVALID_XOR;
		typeNotAllowed[Operator.FOR] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.GREATER] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.GREATER_EQUAL] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.INCREMENT_AFTER] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.INCREMENT_BEFORE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ADDRESS] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.INDIRECT] = MessageId.INVALID_INDIRECT;
		typeNotAllowed[Operator.CLASS_OF] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.IDENTITY] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.INTEGER] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.INTERFACE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.LESS] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.LESS_EQUAL] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.LESS_GREATER] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.LESS_GREATER_EQUAL] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.LEFT_SHIFT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.LEFT_SHIFT_ASSIGN] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.LOAD] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.LOGICAL_AND] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.LOGICAL_OR] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.MULTIPLY] = MessageId.INVALID_MULTIPLY;
		typeNotAllowed[Operator.MULTIPLY_ASSIGN] = MessageId.INVALID_MULTIPLY;
		typeNotAllowed[Operator.NEGATE] = MessageId.INVALID_NEGATE;
		typeNotAllowed[Operator.NEW] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.NOT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.NOT_EQUAL] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.NOT_GREATER] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.NOT_GREATER_EQUAL] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.NOT_IDENTITY] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.NOT_LESS] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.NOT_LESS_EQUAL] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.NOT_LESS_GREATER] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.NOT_LESS_GREATER_EQUAL] = MessageId.INVALID_COMPARE;
		typeNotAllowed[Operator.OR] = MessageId.INVALID_OR;
		typeNotAllowed[Operator.OR_ASSIGN] = MessageId.INVALID_OR;
		typeNotAllowed[Operator.REMAINDER] = MessageId.INVALID_REMAINDER;
		typeNotAllowed[Operator.REMAINDER_ASSIGN] = MessageId.INVALID_REMAINDER;
		typeNotAllowed[Operator.RIGHT_SHIFT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.RIGHT_SHIFT_ASSIGN] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.SCOPED_FOR] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.SEQUENCE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.STACK_ARGUMENT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.STACK_ARGUMENT_ADDRESS] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.SUBSCRIPT] = MessageId.INVALID_SUBSCRIPT;
		typeNotAllowed[Operator.SUBTRACT] = MessageId.INVALID_SUBTRACT;
		typeNotAllowed[Operator.SUBTRACT_ASSIGN] = MessageId.INVALID_SUBTRACT;
		typeNotAllowed[Operator.SYNTAX_ERROR] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.UNSIGNED_RIGHT_SHIFT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.UNARY_PLUS] = MessageId.INVALID_UNARY_PLUS;
		typeNotAllowed[Operator.VARIABLE] = MessageId.INVALID_UNARY_PLUS;
		typeNotAllowed[Operator.FLOATING_POINT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CHARACTER] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.STRING] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.IDENTIFIER] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.EMPTY] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.EXPRESSION] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.WHILE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DO_WHILE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.LOOP] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.SWITCH] = MessageId.INVALID_SWITCH;
		typeNotAllowed[Operator.RETURN] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CASE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DEFAULT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.BLOCK] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.VECTOR_OF] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.MAP] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ENUM] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.BIND] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.TEMPLATE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.TEMPLATE_INSTANCE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.FUNCTION] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.UNIT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.DECLARATION] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CLASS_DECLARATION] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ENUM_DECLARATION] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.INITIALIZE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ANNOTATION] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ANNOTATED] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.IF] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.THIS] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.SUPER] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.TRUE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.FALSE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.NULL] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.PUBLIC] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.PRIVATE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.PROTECTED] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.STATIC] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.FINAL] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ABSTRACT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.CLASS_TYPE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.ENUM_TYPE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.UNWRAP_TYPEDEF] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.IMPORT] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.NAMESPACE] = MessageId.MAX_MESSAGE;
		typeNotAllowed[Operator.VACATE_ARGUMENT_REGISTERS] = MessageId.MAX_MESSAGE;

		string last = "<none>";
		int lastI = -1;
		for (int i = 0; i < int(Operator.MAX_OPERATOR); i++) {
			if (name[Operator(i)] == null) {
				printf("ERROR: Operator %d has no name entry (last defined entry: %s %d)\n", i, last, lastI);
			} else {
				last = name[Operator(i)];
				lastI = i;
			}
			if (typeNotAllowed[Operator(i)] == MessageId(0))
				printf("ERROR: Operator %s has no typeNotAllowed message.\n", name[Operator(i)]);
		}
	}

	static string[Operator] name;
	static MessageId[Operator] typeNotAllowed;
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

boolean balancePair(ref<Node> parent, ref<ref<Node>> leftp, ref<ref<Node>> rightp, ref<CompileContext> compileContext) {
	ref<Node> left = *leftp;
	ref<Node> right = *rightp;
	if (!left.type.equals(right.type)) {
		if (left.canCoerce(right.type, false, compileContext)) {
			if (right.canCoerce(left.type, false, compileContext)) {
				if (left.type.widensTo(right.type, compileContext)) {
					if (right.type.widensTo(left.type, compileContext)) {
						parent.add(MessageId.UNFINISHED_ASSIGN_TYPE, compileContext.pool(), CompileString("  "/*parent.class.name()*/), CompileString(operatorMap.name[parent.op()]));
						parent.type = compileContext.errorType();
						return false;
					} else
						*rightp = right.coerce(compileContext.tree(), left.type, false, compileContext);
				} else
					*leftp = left.coerce(compileContext.tree(), right.type, false, compileContext);
			} else
				*leftp = left.coerce(compileContext.tree(), right.type, false, compileContext);
		} else if (right.canCoerce(left.type, false, compileContext))
			*rightp = right.coerce(compileContext.tree(), left.type, false, compileContext);
		else {
			ref<Type> gcb = left.type.greatestCommonBase(right.type);
			if (gcb != null) {
				*leftp = left.coerce(compileContext.tree(), gcb, false, compileContext);
				*rightp = right.coerce(compileContext.tree(), gcb, false, compileContext);
			} else {
				parent.add(MessageId.TYPE_MISMATCH, compileContext.pool());
				parent.type = compileContext.errorType();
				return false;
			}
		}
	}
	parent.type = left.type;
	return true;
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
		break;
		
	case	ASSIGN:
		b = ref<Binary>(expression);
		if (b.left().op() == Operator.SEQUENCE) {
			ref<Node> destinations = b.left().fold(tree, false, compileContext);
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
		
	case	CONDITIONAL:
		ref<Ternary> t = ref<Ternary>(expression);
		ref<Node> middle = tree.newUnary(Operator.EXPRESSION, t.middle(), t.middle().location());
		middle.type = compileContext.arena().builtInType(TypeFamily.VOID);
		ref<Node> right = tree.newUnary(Operator.EXPRESSION, t.right(), t.right().location());
		right.type = middle.type;
		expression = tree.newTernary(Operator.IF, t.left(), middle, right, t.location()).fold(tree, false, compileContext);
		expression.type = right.type;
		break;
		
	case	INTEGER:
		expression = tree.newLeaf(Operator.EMPTY, expression.location());
		expression.type = compileContext.arena().builtInType(TypeFamily.VOID);
		return expression;
		
	case	SEQUENCE:
		ref<Binary> b = ref<Binary>(expression);
		ref<Node> left = foldVoidContext(b.left(), tree, compileContext);
		right = foldVoidContext(b.right(), tree, compileContext);
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

ref<Node>, int foldMultiReturn(ref<Node> leftHandle, ref<Node> destinations, ref<Variable> intermediate, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
	ref<Node> result;
	int offset;
	if (destinations.op() == Operator.SEQUENCE) {
		ref<Binary> b = ref<Binary>(destinations);
		ref<Node> lh;
		
		(lh, offset) = foldMultiReturn(leftHandle, b.left(), intermediate, tree, compileContext);
		ref<Reference> r = tree.newReference(intermediate, offset, false, destinations.location());
		r.type = b.right().type;
		ref<Node> assignment = tree.newBinary(Operator.ASSIGN, b.right(), r, destinations.location());
		assignment.type = r.type;
		assignment = assignment.fold(tree, false, compileContext);
		offset += b.right().type.stackSize();
		result = tree.newBinary(Operator.SEQUENCE, lh, assignment, destinations.location());
	} else {
		ref<Reference> r = tree.newReference(intermediate, false, destinations.location());
		r.type = destinations.type;
		ref<Node> assignment = tree.newBinary(Operator.ASSIGN, destinations, r, destinations.location());
		assignment.type = r.type;
		assignment = assignment.fold(tree, false, compileContext);
		result = tree.newBinary(Operator.SEQUENCE, leftHandle, assignment, destinations.location());
		offset = destinations.type.stackSize();
	}
	result.type = compileContext.arena().builtInType(TypeFamily.VOID);
	return result, offset;
}

Operator stripAssignment(Operator op) {
	switch (op) {
	case	ADD_ASSIGN:						return Operator.ADD;
	case	SUBTRACT_ASSIGN:				return Operator.SUBTRACT;
	case	AND_ASSIGN:						return Operator.AND;
	case	OR_ASSIGN:						return Operator.OR;
	case	EXCLUSIVE_OR_ASSIGN:			return Operator.EXCLUSIVE_OR;
	case	MULTIPLY_ASSIGN:				return Operator.MULTIPLY;
	case	DIVIDE_ASSIGN:					return Operator.DIVIDE;
	case	REMAINDER_ASSIGN:				return Operator.REMAINDER;
	case	LEFT_SHIFT_ASSIGN:				return Operator.LEFT_SHIFT;
	case	RIGHT_SHIFT_ASSIGN:				return Operator.RIGHT_SHIFT;
	case	UNSIGNED_RIGHT_SHIFT_ASSIGN:	return Operator.UNSIGNED_RIGHT_SHIFT;
	default:
		assert(false);
	}
	return Operator.SYNTAX_ERROR;
}