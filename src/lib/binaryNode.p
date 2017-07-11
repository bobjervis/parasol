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
		case	PLACEMENT_NEW:
		case	MONITOR_DECLARATION:
		case	INTERFACE_DECLARATION:
		case	CLASS_DECLARATION:
		case	FLAGS_DECLARATION:
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
		if (voidContext) {
			switch (op()) {
			case SUBSCRIPT:
				_left = _left.fold(tree, true, compileContext);
				_right = _right.fold(tree, true, compileContext);
				if (_left.op() == Operator.EMPTY)
					return _right;
				if (_right.op() == Operator.EMPTY)
					return _left;
				ref<Node> n = tree.newBinary(Operator.SEQUENCE, _left, _right, location());
				n.type = _right.type;
				return n;
			}
		}
		if (type == null)
			print(0);
		if (type.family() == TypeFamily.SHAPE) {
			switch (op()) {
			case	DECLARATION:
				markLiveSymbols(_right, StorageClass.AUTO, compileContext);
				
			case	BIND:
				_left = _left.fold(tree, false, compileContext);
				_right = _right.fold(tree, false, compileContext);		// Call this context not void, because if it were
																		// folded as truly voidContext it would erase
																		// simple identifier declarators.
				return this;
				
			case	SUBSCRIPT:
			case	SEQUENCE:
			case	LABEL:
				break;
				
			case	INITIALIZE:
				voidContext = true;
			case	ASSIGN:
			case	ASSIGN_TEMP:
				if (shouldVectorize(_right)) {
					// Now, we've done it. We've got a vectorized assignment.
					ref<Binary> operation;
					if (voidContext) 
						operation = this;
					else {
						ref<Variable> v = compileContext.newVariable(type);
						operation = tree.newBinary(Operator.ASSIGN, tree.newReference(v, true, location()), this, location());
						operation.type = type;
						print(0);
						assert(false);
					}
					return vectorize(tree, operation, compileContext);
				}
				break;
				
			default:
				printf("fold %s\n", voidContext ? "void context" : "value context");
				print(4);
				assert(false);
			}
		}
		switch (op()) {
		case	ANNOTATED:
			_right = _right.fold(tree, false, compileContext);
			return this;
			
		case	DECLARATION:
			_left = _left.fold(tree, false, compileContext);
			markLiveSymbols(_right, StorageClass.AUTO, compileContext);
			_right = _right.fold(tree, false, compileContext);			//Need to mark this as NOT a voidContext to avoid erasing a simple identifier
			return this;

		case	FLAGS_DECLARATION:
		case	MONITOR_DECLARATION:
		case	ENUM_DECLARATION:
		case	CLASS_DECLARATION:
		case	INTERFACE_DECLARATION:
		case	SWITCH:
		case	CASE:
		case	LEFT_SHIFT:
		case	BIND:
		case	DELETE:
		case	LABEL:
			break;
			
		case	LOGICAL_AND:
		case	LOGICAL_OR:
			_right = _right.foldConditional(tree, compileContext);
			if (_right.type.family() == TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _right.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _right, right, location());
				op.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				_right = op;
			}
			_left = _left.foldConditional(tree, compileContext);
			if (_left.type.family() == TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _left.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _left, right, location());
				op.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				_left = op;
			}
			return this;
			
		case	WHILE:
			_right = _right.fold(tree, true, compileContext);
			_left = _left.foldConditional(tree, compileContext);
			if (_left.type.family() == TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _left.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _left, right, location());
				op.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				_left = op;
			}
			return this;
			
		case	DO_WHILE:
			_left = _left.fold(tree, true, compileContext);
			_right = _right.foldConditional(tree, compileContext);
			if (_right.type.family() == TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _right.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _right, right, location());
				op.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				_right = op;
			}
			return this;

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
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	ENUM:
			case	FLAGS:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	TYPEDEF:
			case	INTERFACE:
				break;
				
			case	SHAPE:
				if (shouldVectorize(_right)) {
					print(0);
					assert(false);
				}
				
			case	EXCEPTION:
			case	CLASS:
			case	VAR:
				ref<ParameterScope> copyConstructor = type.copyConstructor();
				if (copyConstructor != null) {
					ref<Node> adr = tree.newUnary(Operator.ADDRESS, _left, location());
					adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> constructor = tree.newCall(copyConstructor, CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
					constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
					return constructor.fold(tree, true, compileContext);
				} else {
					ref<Node> result = foldClassCopy(tree, true, compileContext);
					if (result != null)
						return result;
				}
				break;
				
			case	STRING:
				if (_right.op() == Operator.CALL) {
					ref<OverloadInstance> oi = type.stringAllocationConstructor(compileContext);
					if (oi == null) {
						type = compileContext.errorType();
						return this;
					}
					ref<Selection> method = tree.newSelection(_left, oi, false, _left.location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
					call.type = compileContext.arena().builtInType(TypeFamily.VOID);
					return call.fold(tree, true, compileContext);
				}
				copyConstructor = type.copyConstructor();
				if (copyConstructor != null) {
					ref<Node> adr = tree.newUnary(Operator.ADDRESS, _left, location());
					adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> constructor = tree.newCall(copyConstructor, CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
					constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
					return constructor.fold(tree, true, compileContext);
				} else {
					ref<Node> result = foldClassCopy(tree, true, compileContext);
					if (result != null)
						return result;
				}
				break;
				
			default:
				print(0);
				assert(false);
			}
			break;
			
		case	PLACEMENT_NEW:
			entityType = type.indirectType(compileContext);
			defaultConstructor = entityType.defaultConstructor();
			if (_right.op() == Operator.CALL) {
				ref<Call> constructor = ref<Call>(_right);
				if (constructor.overload() == null) {
					if (defaultConstructor != null) // This must have been a late-created constructor.
						return foldDefaultConstructor(defaultConstructor, _left.fold(tree, false, compileContext), tree, voidContext, compileContext);
					else
						return defaultPlacementNewInitialization(_left, tree, voidContext, compileContext);
				}
				if (voidContext) {
					constructor.setConstructorMemory(_left.fold(tree, false, compileContext), tree);
					return constructor.fold(tree, true, compileContext);
				}
				ref<Variable> temp = compileContext.newVariable(type);
				ref<Reference> r = tree.newReference(temp, true, location());
				ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, _left.fold(tree, false, compileContext), location());
				defn.type = type;
				r = tree.newReference(temp, false, location());
				constructor.setConstructorMemory(r, tree);
				ref<Node> seq = tree.newBinary(Operator.SEQUENCE, defn, constructor, location());
				seq.type = compileContext.arena().builtInType(TypeFamily.VOID);
				r = tree.newReference(temp, false, location());
				seq = tree.newBinary(Operator.SEQUENCE, seq, r, location());
				seq.type = type;
				ref<Node> result = seq.fold(tree, false, compileContext);
				return result;
			} else {
				if (defaultConstructor != null) // This must have been a late-created constructor.
					return foldDefaultConstructor(defaultConstructor, _left.fold(tree, false, compileContext), tree, voidContext, compileContext);
				else
					return defaultPlacementNewInitialization(_left, tree, voidContext, compileContext);
			}
			break;
			
		case	NEW:
			ref<Node> allocation;
			if (_left.op() == Operator.EMPTY)
				allocation = this;
			else {
				ref<Node> basis = tree.newLeaf(Operator.EMPTY, location());
				basis.type = type.indirectType(compileContext);
				ref<Node> arg = tree.newUnary(Operator.BYTES, basis, location());
				arg.type = compileContext.arena().builtInType(TypeFamily.SIGNED_64);
				ref<Node> allocator = _left;
				ref<Type> allocatorType = _left.type.indirectType(compileContext);
				if (allocatorType != null) {
					allocator = tree.newUnary(Operator.INDIRECT, _left, location());
					allocator.type = allocatorType;
				}
				ref<Node> call = createMethodCall(allocator.fold(tree, false, compileContext), "alloc", tree, compileContext, arg);
				call.type = type;
				allocation = call.fold(tree, voidContext, compileContext);
			}
			ref<Type> entityType = type.indirectType(compileContext);
			ref<ParameterScope> defaultConstructor = entityType.defaultConstructor();
			if (_right.op() == Operator.CALL) {
				ref<Call> constructor = ref<Call>(_right);
				if (allocation == this) {
					_right = tree.newLeaf(Operator.EMPTY, location());
					_right.type = compileContext.arena().builtInType(TypeFamily.VOID);
				}
				if (constructor.overload() == null) {
					if (defaultConstructor != null) // This must have been a late-created constructor.
						return foldDefaultConstructor(defaultConstructor, allocation, tree, voidContext, compileContext);
					else
						return defaultNewInitialization(allocation, tree, voidContext, compileContext);
				}
				ref<Variable> temp = compileContext.newVariable(type);
				ref<Reference> r = tree.newReference(temp, true, location());
				ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, allocation, location());
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
				if (allocation == this) {
					_right = tree.newLeaf(Operator.EMPTY, location());
					_right.type = compileContext.arena().builtInType(TypeFamily.VOID);
				}
				if (defaultConstructor != null) // This must have been a late-created constructor.
					return foldDefaultConstructor(defaultConstructor, allocation, tree, voidContext, compileContext);
				else
					return defaultNewInitialization(allocation, tree, voidContext, compileContext);
			}
			break;
			
		case	DELETE:
			ref<Type> objType = _right.type.indirectType(compileContext);
			ref<Node> destructors = null;
			ref<Node> completion;
			if (_left.op() == Operator.EMPTY)
				completion = this;
			else {
				ref<Node> allocator = _left;
				ref<Type> allocatorType = _left.type.indirectType(compileContext);
				if (allocatorType != null) {
					allocator = tree.newUnary(Operator.INDIRECT, _left, location());
					allocator.type = allocatorType;
				}
				ref<Node> call = createMethodCall(allocator.fold(tree, false, compileContext), "free", tree, compileContext, _right);
				call.type = type;
				completion = call.fold(tree, true, compileContext);
			}
			if (objType.hasDestructor()) {
				ref<Node> defn;
				ref<Node> value;
				(defn, value) = cloneDefnValue(tree, _right, compileContext);
				_right = value.clone(tree);
				ref<ParameterScope> des = objType.scope().destructor();
				ref<Call> call = tree.newCall(des, CallCategory.DESTRUCTOR, value, null, location(), compileContext);
				call.type = type;			// We know this is VOID
				value = value.clone(tree);
				ref<Node> con = tree.newConstant(0, location());
				con.type = value.type;
				ref<Node> compare = tree.newBinary(Operator.NOT_EQUAL, value, con, location());
				compare.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				ref<Node> nullPath = tree.newLeaf(Operator.EMPTY, location());
				nullPath.type = call.type;
				completion = tree.newBinary(Operator.SEQUENCE, call.fold(tree, false, compileContext), completion, location());
				completion.type = type;
				ref<Node> choice = tree.newTernary(Operator.CONDITIONAL, compare, completion, nullPath, location());
				choice.type = call.type;
				if (defn != null) {
					destructors = tree.newBinary(Operator.SEQUENCE, defn.fold(tree, true, compileContext), choice, location());
					destructors.type = choice.type;
				} else
					destructors = choice;
				return destructors;
			} else
				return completion;
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
		case	NOT_EQUAL:
			if (isCompileTarget(_left, _right)) {
				if (matchesCompileTarget(op(), _right, compileContext.target)) {
					ref<Node> x = tree.newLeaf(Operator.TRUE, location());
					x.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					return x;
				} else {
					ref<Node> x = tree.newLeaf(Operator.FALSE, location());
					x.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					return x;
				}
			} else if (isCompileTarget(_right, _left)) {
				if (matchesCompileTarget(op(), _left, compileContext.target)) {
					ref<Node> x = tree.newLeaf(Operator.TRUE, location());
					x.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					return x;
				} else {
					ref<Node> x = tree.newLeaf(Operator.FALSE, location());
					x.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					return x;
				}
				break;
			}
			
		case	LESS:
		case	LESS_EQUAL:
		case	LESS_GREATER_EQUAL:
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
			case	TYPEDEF:
			case	CLASS_VARIABLE:
				ref<Symbol> typeType = compileContext.arena().getSymbol("parasol", "compiler.Type", compileContext);
				if (typeType == null || typeType.class != PlainSymbol) {
					print(0);
					assert(false);
				}
				ref<Type> t = typeType.assignType(compileContext);
				assert(t.family() == TypeFamily.TYPEDEF);
				t = ref<TypedefType>(t).wrappedType();
				ref<OverloadInstance> isSubtypeMethod = getOverloadInstance(t, "isSubtype", compileContext);
				if (isSubtypeMethod == null)
					return this;
				switch (op()) {
				case	EQUALITY:
				case	NOT_EQUAL:
					break;
					
				case	LESS:
					ref<Selection> method = tree.newSelection(_left, isSubtypeMethod, true, location());
					method.type = isSubtypeMethod.type();
					call = tree.newCall(isSubtypeMethod.parameterScope(), CallCategory.METHOD_CALL, method, tree.newNodeList(_right), location(), compileContext);
					call.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					return call.fold(tree, voidContext, compileContext);
					
				case	GREATER:
					method = tree.newSelection(_right, isSubtypeMethod, true, location());
					method.type = isSubtypeMethod.type();
					call = tree.newCall(isSubtypeMethod.parameterScope(), CallCategory.METHOD_CALL, method, tree.newNodeList(_left), location(), compileContext);
					call.type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
					return call.fold(tree, voidContext, compileContext);
					
				case	LESS_EQUAL:
					ref<Node> defnRight;
					ref<Node> valueRight;
					(defnRight, valueRight) = cloneDefnValue(tree, _right, compileContext);
					ref<Node> defnLeft;
					ref<Node> valueLeft;
					(defnLeft, valueLeft) = cloneDefnValue(tree, _left, compileContext);
					ref<Node> equalsTest = tree.newBinary(Operator.EQUALITY, valueLeft, valueRight, location());
					equalsTest.type = type;
					ref<Node> lessTest = tree.newBinary(Operator.LESS, valueLeft.clone(tree), valueRight.clone(tree), location());
					lessTest.type = type;
					ref<Node> orTogether = tree.newBinary(Operator.LOGICAL_OR, equalsTest, lessTest, location());
					orTogether.type = type;
					return sequenceNodes(tree, defnLeft, defnRight, orTogether).fold(tree, voidContext, compileContext);
					
				case	GREATER_EQUAL:
					(defnRight, valueRight) = cloneDefnValue(tree, _right, compileContext);
					(defnLeft, valueLeft) = cloneDefnValue(tree, _left, compileContext);
					equalsTest = tree.newBinary(Operator.EQUALITY, valueLeft, valueRight, location());
					equalsTest.type = type;
					lessTest = tree.newBinary(Operator.LESS, valueRight.clone(tree), valueLeft.clone(tree), location());
					lessTest.type = type;
					orTogether = tree.newBinary(Operator.LOGICAL_OR, equalsTest, lessTest, location());
					orTogether.type = type;
					return sequenceNodes(tree, defnLeft, defnRight, orTogether).fold(tree, voidContext, compileContext);
					
				case	LESS_GREATER:
					(defnRight, valueRight) = cloneDefnValue(tree, _right, compileContext);
					(defnLeft, valueLeft) = cloneDefnValue(tree, _left, compileContext);
					equalsTest = tree.newBinary(Operator.LESS, valueLeft, valueRight, location());
					equalsTest.type = type;
					lessTest = tree.newBinary(Operator.LESS, valueRight.clone(tree), valueLeft.clone(tree), location());
					lessTest.type = type;
					orTogether = tree.newBinary(Operator.LOGICAL_OR, equalsTest, lessTest, location());
					orTogether.type = type;
					return sequenceNodes(tree, defnLeft, defnRight, orTogether).fold(tree, voidContext, compileContext);
					
				case	LESS_GREATER_EQUAL:
					(defnRight, valueRight) = cloneDefnValue(tree, _right, compileContext);
					(defnLeft, valueLeft) = cloneDefnValue(tree, _left, compileContext);
					equalsTest = tree.newBinary(Operator.EQUALITY, valueLeft, valueRight, location());
					equalsTest.type = type;
					lessTest = tree.newBinary(Operator.LESS, valueLeft.clone(tree), valueRight.clone(tree), location());
					lessTest.type = type;
					orTogether = tree.newBinary(Operator.LOGICAL_OR, equalsTest, lessTest, location());
					orTogether.type = type;
					lessTest = tree.newBinary(Operator.LESS, valueRight.clone(tree), valueLeft.clone(tree), location());
					lessTest.type = type;
					orTogether = tree.newBinary(Operator.LOGICAL_OR, orTogether, lessTest, location());
					orTogether.type = type;
					return sequenceNodes(tree, defnLeft, defnRight, orTogether).fold(tree, voidContext, compileContext);
					
				case	NOT_LESS:
					lessTest = tree.newBinary(Operator.LESS, _left, _right, location());
					lessTest.type = type;
					orTogether = tree.newUnary(Operator.NOT, lessTest, location());
					orTogether.type = type;
					return orTogether.fold(tree, voidContext, compileContext);
					
				case	NOT_GREATER:
					lessTest = tree.newBinary(Operator.GREATER, _left, _right, location());
					lessTest.type = type;
					orTogether = tree.newUnary(Operator.NOT, lessTest, location());
					orTogether.type = type;
					return orTogether.fold(tree, voidContext, compileContext);
					
				case	NOT_LESS_EQUAL:
					lessTest = tree.newBinary(Operator.LESS_EQUAL, _left, _right, location());
					lessTest.type = type;
					orTogether = tree.newUnary(Operator.NOT, lessTest, location());
					orTogether.type = type;
					return orTogether.fold(tree, voidContext, compileContext);
					
				case	NOT_GREATER_EQUAL:
					lessTest = tree.newBinary(Operator.GREATER_EQUAL, _left, _right, location());
					lessTest.type = type;
					orTogether = tree.newUnary(Operator.NOT, lessTest, location());
					orTogether.type = type;
					return orTogether.fold(tree, voidContext, compileContext);
					
				case	NOT_LESS_GREATER:
					lessTest = tree.newBinary(Operator.LESS_GREATER, _left, _right, location());
					lessTest.type = type;
					orTogether = tree.newUnary(Operator.NOT, lessTest, location());
					orTogether.type = type;
					return orTogether.fold(tree, voidContext, compileContext);
					
				case	NOT_LESS_GREATER_EQUAL:
					lessTest = tree.newBinary(Operator.LESS_GREATER_EQUAL, _left, _right, location());
					lessTest.type = type;
					orTogether = tree.newUnary(Operator.NOT, lessTest, location());
					orTogether.type = type;
					return orTogether.fold(tree, voidContext, compileContext);
					
				default:
					print(0);
					assert(false);
				}
				break;
				
			case	STRING:
			case	VAR:
				ref<Node> call = createMethodCall(_left, "compare", tree, compileContext, _right);
				call.type = compileContext.arena().builtInType(TypeFamily.SIGNED_32);
				_left = call.fold(tree, voidContext, compileContext);
				_right = tree.newConstant(0, location());
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
					ref<Constant> c = tree.newConstant(t.size(), location());
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
					   _left.type.isMap(compileContext) ||
					   _left.type.family() == TypeFamily.SHAPE) {
				CompileString name("get");
				
				ref<Symbol> sym = _left.type.lookup(&name, compileContext);
				if (sym == null || sym.class != Overload) {
					add(MessageId.UNDEFINED, compileContext.pool(), name);
					break;
				}
				ref<Overload> o = ref<Overload>(sym);
				ref<OverloadInstance> oi = (*o.instances())[0];
				ref<Selection> method = tree.newSelection(_left, oi, false, location());
				method.type = oi.type();
				ref<NodeList> args = tree.newNodeList(_right);
				ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
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
			case	POINTER:
				rewritePointerArithmetic(tree, compileContext);
				break;
				
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
			case	POINTER:
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
				
			case	POINTER:
				rewritePointerArithmetic(tree, compileContext);
				break;
				
			case	VAR:
				ref<Node> call = createMethodCall(_left, "add", tree, compileContext, _right);
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;
			
		case	STORE_TEMP:
		case	ASSIGN_TEMP:
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
			case	FLAGS:
			case	ADDRESS:
			case	FUNCTION:
			case	TYPEDEF:
			case	CLASS_VARIABLE:
			case	REF:
			case	POINTER:
			case	INTERFACE:
				break;
				
			case	STRING:
				if (_right.op() == Operator.CALL && ref<Call>(_right).category() != CallCategory.CONSTRUCTOR) {
					ref<OverloadInstance> oi;
					if (op() == Operator.ASSIGN_TEMP)
						oi = type.tempAssignmentMethod(compileContext);
					else if (op() == Operator.STORE_TEMP)
						oi = getMethodSymbol(_right, "storeTemp", type, compileContext);
					else
						oi = getMethodSymbol(_right, "store", type, compileContext);
					if (oi == null) {
						type = compileContext.errorType();
						return this;
					}
					// This is the assignment method for this class!!!
					// (all strings go through here).
					ref<Selection> method = tree.newSelection(_left, oi, false, _left.location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
					call.type = compileContext.arena().builtInType(TypeFamily.VOID);
					return call.fold(tree, voidContext, compileContext);
				}
				
			case	CLASS:
			case	SHAPE:
				ref<OverloadInstance> oi;
				if (op() == Operator.ASSIGN_TEMP)
					oi = type.tempAssignmentMethod(compileContext);
				else
					oi = type.assignmentMethod(compileContext);
				if (oi != null) {
					// This is the assignment method for this class!!!
					// (all strings go through here).
					ref<Selection> method = tree.newSelection(_left, oi, false, _left.location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
					call.type = compileContext.arena().builtInType(TypeFamily.VOID);
					return call.fold(tree, voidContext, compileContext);
				} else {
					ref<Node> result = foldClassCopy(tree, false, compileContext);
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
					ref<Selection> method = tree.newSelection(load, oi, false, _left.location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
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
	
	public ref<Node> foldConditional(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		switch (op()) {
		case	LOGICAL_AND:
		case	LOGICAL_OR:
			return fold(tree, false, compileContext);
		}
		return super.foldConditional(tree, compileContext);
	}
	
	ref<Node>, ref<Node> cloneDefnValue(ref<SyntaxTree> tree, ref<Node> n, ref<CompileContext> compileContext) {
		ref<Node> defn;
		ref<Node> value;
		if (n.isSimpleLvalue())
			value = n.clone(tree);
		else {
			ref<Variable> temp = compileContext.newVariable(n.type);
			ref<Reference> r = tree.newReference(temp, true, location());
			defn = tree.newBinary(Operator.ASSIGN, r, n, location());
			defn.type = n.type;
			value = tree.newReference(temp, false, location());
		}
		return defn, value;
	}	
	
	private ref<Node> foldDefaultConstructor(ref<ParameterScope> defaultConstructor, ref<Node> allocation, ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		ref<Variable> temp = compileContext.newVariable(type);
		ref<Reference> r = tree.newReference(temp, true, location());
		ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, allocation, location());
		defn.type = type;
		ref<Type> objType = type.indirectType(compileContext);
		ref<Node> storeVtable = null;
		if (objType.hasVtable(compileContext) || objType.interfaceCount() > 0) {
			r = tree.newReference(temp, false, location());
			storeVtable = tree.newUnary(Operator.STORE_V_TABLE, r, location());
			storeVtable.type = objType;
		}
		r = tree.newReference(temp, false, location());
		ref<Node> constructor = tree.newCall(defaultConstructor, CallCategory.CONSTRUCTOR, r, null, location(), compileContext);
		constructor.type = type;
		constructor = constructor.fold(tree, true, compileContext);
		if (storeVtable != null) {
			constructor = tree.newBinary(Operator.SEQUENCE, storeVtable, constructor, location());
			constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
		}
		ref<Node> seq = tree.newBinary(Operator.SEQUENCE, defn, constructor, location());
		seq.type = compileContext.arena().builtInType(TypeFamily.VOID);
		if (voidContext)
			return seq;
		r = tree.newReference(temp, false, location());
		seq = tree.newBinary(Operator.SEQUENCE, seq, r, location());
		seq.type = type;
		return seq;
	}
	
	private ref<Node> defaultNewInitialization(ref<Node> allocation, ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		ref<Type> objType = type.indirectType(compileContext);
		if (objType.hasVtable(compileContext)) {
			ref<Variable> temp = compileContext.newVariable(type);
			ref<Reference> r = tree.newReference(temp, true, location());
			ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, allocation, location());
			defn.type = type;
			r = tree.newReference(temp, false, location());
			ref<Node> constructor = tree.newUnary(Operator.STORE_V_TABLE, r, location());
			constructor.type = objType;
			ref<Node> seq = tree.newBinary(Operator.SEQUENCE, defn, constructor, location());
			seq.type = compileContext.arena().builtInType(TypeFamily.VOID);
			if (voidContext)
				return seq;
			r = tree.newReference(temp, false, location());
			seq = tree.newBinary(Operator.SEQUENCE, seq, r, location());
			seq.type = type;
			return seq;
		} else
			return allocation;
	}
	
	private ref<Node> defaultPlacementNewInitialization(ref<Node> target, ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		ref<Type> objType = type.indirectType(compileContext);
		if (objType.hasVtable(compileContext)) {
			target = target.fold(tree, false, compileContext);
			ref<Variable> temp = compileContext.newVariable(type);
			ref<Reference> r = tree.newReference(temp, true, location());
			ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, target, location());
			defn.type = type;
			r = tree.newReference(temp, false, location());
			ref<Node> constructor = tree.newUnary(Operator.STORE_V_TABLE, r, location());
			constructor.type = objType;
			ref<Node> seq = tree.newBinary(Operator.SEQUENCE, defn, constructor, location());
			seq.type = compileContext.arena().builtInType(TypeFamily.VOID);
			if (voidContext)
				return seq;
			r = tree.newReference(temp, false, location());
			seq = tree.newBinary(Operator.SEQUENCE, seq, r, location());
			seq.type = type;
			return seq;
		} else
			return target.fold(tree, voidContext, compileContext);
	}
	
	private ref<Node> foldClassCopy(ref<SyntaxTree> tree, boolean initializer, ref<CompileContext> compileContext) {
		boolean hasAssignmentMethods = false;
		for (ref<Symbol>[Scope.SymbolKey].iterator i = type.scope().symbols().begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.class == PlainSymbol && sym.storageClass() == StorageClass.MEMBER && sym.type().assignmentMethod(compileContext) != null) {
				hasAssignmentMethods = true;
				break;
			}
		}

		if (hasAssignmentMethods) {
			_left = tree.newUnary(Operator.ADDRESS, _left.fold(tree, false, compileContext), location());
			_left.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			_right = _right.fold(tree, false, compileContext);
			if (_right.op() != Operator.CLASS_COPY) {
				_right = tree.newUnary(Operator.ADDRESS, _right, location());
				_right.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			}
			ref<Variable> dest = compileContext.newVariable(_left.type);
			ref<Variable> src = compileContext.newVariable(_left.type);
			ref<Reference> destR = tree.newReference(dest, true, location());
			ref<Reference> srcR = tree.newReference(src, true, location());
			ref<Node> da = tree.newBinary(Operator.ASSIGN, destR, _left, location());
			da.type = _left.type;
			ref<Node> sa = tree.newBinary(Operator.ASSIGN, srcR, _right, location());
			sa.type = _left.type;
			ref<Node> seq = tree.newBinary(Operator.SEQUENCE, da, sa, location());
			seq.type = _left.type;
			if (initializer) {
				destR = tree.newReference(dest, false, location());
				da = tree.newUnary(Operator.CLASS_CLEAR, destR, location());
				da.type = type;
				seq = tree.newBinary(Operator.SEQUENCE, seq, da, location());
				seq.type = _left.type;
				if (_left.type.hasVtable(compileContext)) {
					destR = tree.newReference(dest, false, location());
					srcR = tree.newReference(src, false, location());
					da = tree.newUnary(Operator.INDIRECT, destR, location());
					da.type = destR.type;
					sa = tree.newUnary(Operator.INDIRECT, srcR, location());
					sa.type = destR.type;
					ref<Node> asg = tree.newBinary(Operator.ASSIGN, da, sa, location());
					asg.type = destR.type;
					seq = tree.newBinary(Operator.SEQUENCE, seq, asg, location());
					seq.type = asg.type;
				}
			}
			for (ref<Symbol>[Scope.SymbolKey].iterator i = type.scope().symbols().begin(); i.hasNext(); i.next()) {
				ref<Symbol> sym = i.get();
				if (sym.class != PlainSymbol || sym.storageClass() != StorageClass.MEMBER)
					continue;
				destR = tree.newReference(dest, false, location());
				srcR = tree.newReference(src, false, location());
				da = tree.newSelection(destR, sym, true, location());
				da.type = sym.type();
				sa = tree.newSelection(srcR, sym, true, location());
				sa.type = sym.type();
				ref<Node> asg = tree.newBinary(Operator.ASSIGN, da, sa, location());
				asg.type = sym.type();
				asg = asg.fold(tree, false, compileContext);
				seq = tree.newBinary(Operator.SEQUENCE, seq, asg, location());
				seq.type = asg.type;
			}
			return seq;
		} else {
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
			ref<Constant> c = tree.newConstant(t.size(), location());
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
			subscript.left().type.isMap(compileContext) ||
			subscript.left().type.family() == TypeFamily.SHAPE) {
			CompileString name("set");
			
			ref<Symbol> sym = subscript.left().type.lookup(&name, compileContext);
			if (sym == null || sym.class != Overload) {
				subscript.add(MessageId.UNDEFINED, compileContext.pool(), name);
				return this;
			}
			ref<Overload> over = ref<Overload>(sym);
			ref<OverloadInstance> oi = (*over.instances())[0];
			ref<Selection> method = tree.newSelection(subscript.left(), oi, false, subscript.location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(subscript.right(), _right);
			ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
			call.type = compileContext.arena().builtInType(TypeFamily.VOID);
			return call;
		} else
			return null;
	}
	
	ref<Node> subscriptModify(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		if (_left.type.isVector(compileContext) ||
			_left.type.isMap(compileContext) ||
			_left.type.family() == TypeFamily.SHAPE) {
			CompileString name("elementAddress");
			
			ref<Symbol> sym = _left.type.lookup(&name, compileContext);
			if (sym == null || sym.class != Overload) {
				add(MessageId.UNDEFINED, compileContext.pool(), name);
				return this;
			}
			ref<Overload> over = ref<Overload>(sym);
			ref<OverloadInstance> oi = (*over.instances())[0];
			ref<Selection> method = tree.newSelection(_left, oi, false, location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(_right);
			ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
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
		case	MONITOR_DECLARATION:
		case	CLASS_DECLARATION:
		case	ENUM_DECLARATION:
		case	FLAGS_DECLARATION:
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

	public long foldInt(ref<Target> target, ref<CompileContext> compileContext) {
		switch (op()) {
		case	ADD:
			long x = _left.foldInt(target, compileContext);
			long y = _right.foldInt(target, compileContext);
			return x + y;

		case	SUBTRACT:
			x = _left.foldInt(target, compileContext);
			y = _right.foldInt(target, compileContext);
			return x - y;

		case	MULTIPLY:
			x = _left.foldInt(target, compileContext);
			y = _right.foldInt(target, compileContext);
			return x * y;

		default:
			print(0);
			assert(false);
		}
		return 0;
	}

	public boolean isConstant() {
		switch (op()) {
		case	ADD:
		case	SUBTRACT:
		case	MULTIPLY:
			if (_left.isConstant() && _right.isConstant())
				return true;
		}
		return false;
	}
	
	public void assignClassVariable(ref<CompileContext> compileContext) {
		assert(op() == Operator.INITIALIZE);
		compileContext.assignTypes(_right);
		if (_right.type.family() != TypeFamily.TYPEDEF) {
			_right.add(MessageId.NOT_A_TYPE, compileContext.pool());
			type = compileContext.errorType();
			return;
		}
		_left.markupDeclarator(_right.type, false, compileContext);
		type = _right.type;
	}

	public  void markupDeclarator(ref<Type> t, boolean needsDefaultConstructor, ref<CompileContext> compileContext) {
		switch (op()) {
		case	SEQUENCE:
			_left.markupDeclarator(t, true, compileContext);
			_right.markupDeclarator(t, true, compileContext);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	INITIALIZE:
			_left.markupDeclarator(t, false, compileContext);
			switch (_right.op()) {
			case	CALL:
				if (_left.deferAnalysis()) {
					type = _left.type;
					return;
				}
				ref<Call> call = ref<Call>(_right);

				// A constructor initializer!!!
				if (call.target() == null) {
					// Must be a constructor, or else an error.
					call.assignConstructorCall(t, compileContext);
					type = t;
					return;
				}
				break;
				
			case	ARRAY_AGGREGATE:
				if (_left.deferAnalysis()) {
					type = _left.type;
					return;
				}
				ref<Call> aggregate = ref<Call>(_right);
				ref<EnumInstanceType> enumType;
				long maxIndex;
				if (_left.type.family() == TypeFamily.SHAPE) {
					ref<Type> indexType = _left.type.indexType(compileContext);
					switch (indexType.family()) {
					case	BOOLEAN:
						enumType = null;
						maxIndex = 1;
						break;
						
					case	SIGNED_8:
						enumType = null;
						maxIndex = 127;
						break;
						
					case	SIGNED_16:
						enumType = null;
						maxIndex = short.MAX_VALUE;
						break;
						
					case	SIGNED_32:
						enumType = null;
						maxIndex = int.MAX_VALUE;
						break;
						
					case	UNSIGNED_8:
						enumType = null;
						maxIndex = byte.MAX_VALUE;
						break;
						
					case	UNSIGNED_16:
						enumType = null;
						maxIndex = char.MAX_VALUE;
						break;
						
					case	UNSIGNED_32:
						enumType = null;
						maxIndex = unsigned.MAX_VALUE;
						break;
						
					case	ENUM:
						enumType = ref<EnumInstanceType>(indexType);
						ref<EnumScope> enumScope = ref<EnumScope>(enumType.scope());
						maxIndex = enumScope.instances().length() - 1;
						break;
						
					default:
						enumType = null;
						maxIndex = long.MAX_VALUE;
					}
				}
				aggregate.assignArrayAggregateTypes(enumType, maxIndex, compileContext);
				type = _right.type;
				return;
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
			super.markupDeclarator(t, needsDefaultConstructor, compileContext);
		}
	}

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

	void assignDeclarationTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	SUBSCRIPT:
			_left.assignDeclarationTypes(compileContext);
			compileContext.assignTypes(_right);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}
			if (_right.deferAnalysis()) {
				type = _right.type;
				return;
			}
			if (_left.type == null)
				print(0);
			if (_left.type.family() == TypeFamily.TYPEDEF)
				arrayDeclaration(compileContext);
			else {
				print(0);
				_left.add(MessageId.NOT_A_TYPE, compileContext.pool());
				type = compileContext.errorType();
			}
			return;
			
		default:
			assignTypes(compileContext);
		}
	}
	
	private void arrayDeclaration(ref<CompileContext> compileContext) {
		if (_right.type.isIntegral()) {
			add(MessageId.UNFINISHED_FIXED_ARRAY, compileContext.pool());
			type = compileContext.errorType();
		} else if (_right.type.family() == TypeFamily.TYPEDEF) {
			ref<Type> keyType = _right.unwrapTypedef(Operator.CLASS, compileContext);
			ref<Type> vectorType = compileContext.arena().buildVectorType(_left.unwrapTypedef(Operator.CLASS, compileContext), keyType, compileContext);
			if (vectorType == null) { // Not an allowed combination.
				print(0);
				_right.add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}else
				type = compileContext.makeTypedef(vectorType);
		} else {
			add(typeNotAllowed[op()], compileContext.pool());
			type = compileContext.errorType();
		}
	}
	
	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	MONITOR_DECLARATION:
			type = _right.type;
			_right.type = null;
			compileContext.assignTypes(_right);
			_right.type = type;
//			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	ANNOTATED:
			compileContext.assignTypes(_left);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}

		case	INTERFACE_DECLARATION:
		case	CLASS_DECLARATION:
		case	FLAGS_DECLARATION:
		case	ENUM_DECLARATION:
			compileContext.assignTypes(_right);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	DECLARATION:
			switch (_left.op()) {
			case ELLIPSIS:
				_left.add(MessageId.BAD_ELLIPSIS, compileContext.pool());
				type = compileContext.errorType();
				break;
				
			case EMPTY:	// A class alias
				type = compileContext.arena().builtInType(TypeFamily.CLASS_VARIABLE);
				_right.assignClassVariable(compileContext);
				break;
				
			default:
				type = _left.unwrapTypedef(Operator.CLASS, compileContext);
				if (!deferAnalysis())
					_right.markupDeclarator(type, true, compileContext);
			}
			break;

			// This case arises when static initializers have to be 
		case	INITIALIZE:
			ref<Symbol> sym = ref<Identifier>(_left).symbol();
			_left.type = sym.assignType(compileContext);
			if (_left.deferAnalysis()) {
				type = _left.type;
				break;
			}
			markupDeclarator(_left.type, true, compileContext);
			break;
			
		case	LABEL:
			// assign and propagate the value type, let higher-level code decide what to do with the label
			// portion.
			compileContext.assignTypes(_right);
			type = _right.type;
			break;
			
		case	PLACEMENT_NEW:
			compileContext.assignTypes(_left);
			if (_left.deferAnalysis()) {
				type = _left.type;
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
				type = call.target().unwrapTypedef(Operator.CLASS, compileContext);
			} else {
				type = _right.unwrapTypedef(Operator.CLASS,compileContext);
				if (deferAnalysis())
					break;
				// So it's a valid type, what if it has non-default constructors only?
				if (type.hasConstructors() && !type.hasDefaultConstructor()) {
					add(MessageId.NO_DEFAULT_CONSTRUCTOR, compileContext.pool());
					break;
				}
			}
			if (!_left.canCoerce(compileContext.arena().builtInType(TypeFamily.ADDRESS), false, compileContext)) { 
				_left.add(MessageId.CANNOT_CONVERT, compileContext.pool());
				_left.type = compileContext.errorType();
				type = _left.type;
				break;
			}
			if (!type.isConcrete(compileContext))
				_right.add(MessageId.ABSTRACT_INSTANCE_DISALLOWED, compileContext.pool());
			type = compileContext.arena().createRef(type, compileContext);
			break;

		case	NEW:
			if (_left.op() != Operator.EMPTY) {
				compileContext.assignTypes(_left);
				if (_left.deferAnalysis()) {
					type = _left.type;
					break;
				}
				ref<Symbol> re = compileContext.arena().getSymbol("parasol", "memory.Allocator", compileContext);
				if (re.type().family() != TypeFamily.TYPEDEF) {
					print(4);
					assert(false);
				}
				ref<TypedefType> t = ref<TypedefType>(re.type());
				if (!_left.type.extendsFormally(t.wrappedType(), compileContext)) {
					ref<Type> indirect = _left.type.indirectType(compileContext);
					if (indirect == null ||
						!indirect.extendsFormally(t.wrappedType(), compileContext)) {
						_left.add(MessageId.NOT_AN_ALLOCATOR, compileContext.pool());
						type = compileContext.errorType();
						break;
					}
				}
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
				type = call.target().unwrapTypedef(Operator.CLASS, compileContext);
			} else {
				type = _right.unwrapTypedef(Operator.CLASS, compileContext);
				if (deferAnalysis())
					break;
				// So it's a valid type, what if it has non-default constructors only?
				if (type.hasConstructors() && !type.hasDefaultConstructor()) {
					add(MessageId.NO_DEFAULT_CONSTRUCTOR, compileContext.pool());
					break;
				}
			}
			if (!type.isConcrete(compileContext))
				_right.add(MessageId.ABSTRACT_INSTANCE_DISALLOWED, compileContext.pool());
			type = compileContext.arena().createRef(type, compileContext);
			break;

		case	DELETE:
			if (_left.op() != Operator.EMPTY) {
				compileContext.assignTypes(_left);
				if (_left.deferAnalysis()) {
					type = _left.type;
					break;
				}
				ref<Symbol> re = compileContext.arena().getSymbol("parasol", "memory.Allocator", compileContext);
				if (re.type().family() != TypeFamily.TYPEDEF) {
					print(4);
					assert(false);
				}
				ref<TypedefType> t = ref<TypedefType>(re.type());
				if (!_left.type.extendsFormally(t.wrappedType(), compileContext)) {
					ref<Type> indirect = _left.type.indirectType(compileContext);
					if (indirect == null ||
						!indirect.extendsFormally(t.wrappedType(), compileContext)) {
						_left.add(MessageId.NOT_AN_ALLOCATOR, compileContext.pool());
						type = compileContext.errorType();
						break;
					}
				}
			}
			compileContext.assignTypes(_right);
			if (_right.deferAnalysis()) {
				type = _right.type;
				break;
			}
			if (_right.canCoerce(compileContext.arena().builtInType(TypeFamily.ADDRESS), false, compileContext)) 
				type = compileContext.arena().builtInType(TypeFamily.VOID);
			else {
				_right.add(MessageId.CANNOT_CONVERT, compileContext.pool());
				_right.type = compileContext.errorType();
				type = _right.type;
			}
			break;

		case	ADD:
			compileContext.assignTypes(_left);
			if (_left.deferAnalysis()) {
				type = _left.type;
				break;
			}
			if (_left.type.family() == TypeFamily.POINTER) {
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
			switch (_left.type.scalarFamily(compileContext)) {
			case	STRING:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	VAR:
				break;

			case	BOOLEAN:
			default:
				add(typeNotAllowed[op()], compileContext.pool());
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
			ref<Symbol> lvalue = _left.symbol();
			if (lvalue != null && lvalue.accessFlags() & Access.CONSTANT) {
				add(MessageId.BAD_WRITE_ATTEMPT, compileContext.pool());
				type = compileContext.errorType();
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
				case	SIGNED_16:
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
					add(typeNotAllowed[op()], compileContext.pool());
					type = compileContext.errorType();
				}
				break;
			}

			if (_left.type.isPointer(compileContext)) {
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_64, false, compileContext);
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
			case	SIGNED_16:
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
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	AND:
		case	OR:
		case	EXCLUSIVE_OR:
			if (!balance(compileContext))
				break;
			switch (_left.type.scalarFamily(compileContext)) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	BOOLEAN:
			case	VAR:
			case	FLAGS:
				break;

			default:
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	AND_ASSIGN:
		case	OR_ASSIGN:
		case	EXCLUSIVE_OR_ASSIGN:
			if (!assignOp(compileContext))
				break;
			lvalue = _left.symbol();
			if (lvalue != null && lvalue.accessFlags() & Access.CONSTANT) {
				add(MessageId.BAD_WRITE_ATTEMPT, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			switch (_left.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	BOOLEAN:
			case	FLAGS:
			case	VAR:
				if (_left.isLvalue()) 
					type = _left.type;
				else {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
				}
				break;

			default:
				add(typeNotAllowed[op()], compileContext.pool());
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
			lvalue = _left.symbol();
			if (lvalue != null && lvalue.accessFlags() & Access.CONSTANT) {
				add(MessageId.BAD_WRITE_ATTEMPT, compileContext.pool());
				type = compileContext.errorType();
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
			switch (_left.type.scalarFamily(compileContext)) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	VAR:
			case	FLOAT_32:
			case	FLOAT_64:
				break;

			default:
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	REMAINDER:
			if (!balance(compileContext))
				break;
			switch (_left.type.scalarFamily(compileContext)) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	VAR:
				break;

			case	BOOLEAN:
			default:
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
		break;
/*
 * 		TODO: Figure out what the semantics of these operators should be. 
		case	IDENTITY:
		case	NOT_IDENTITY:
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
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	ENUM:
			case	FLAGS:
			case	VAR:
			case	CLASS_VARIABLE:
			case	TYPEDEF:
				type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				break;

			default:
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;
 */			
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
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	ENUM:
			case	FLAGS:
			case	VAR:
			case	CLASS_VARIABLE:
			case	TYPEDEF:
				type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				break;

			default:
				add(typeNotAllowed[op()], compileContext.pool());
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
			case	POINTER:
			case	STRING:
			case	CLASS_VARIABLE:
			case	TYPEDEF:
				type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				break;

			case	BOOLEAN:
			default:
				add(typeNotAllowed[op()], compileContext.pool());
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
			case	CLASS_VARIABLE:
			case	TYPEDEF:
				type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				break;

			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	BOOLEAN:
			default:
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	BIND:
			type = _left.unwrapTypedef(Operator.CLASS, compileContext);
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
			if (_left.type == null)
				print(0);
			if (_left.type.family() == TypeFamily.TYPEDEF)
				arrayDeclaration(compileContext);
			else if (_left.type.isPointer(compileContext)) {
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_64, false, compileContext);
				type = _left.type.indirectType(compileContext);
			} else if (_left.type.isVector(compileContext) || 
					   _left.type.isMap(compileContext) ||
					   _left.type.family() == TypeFamily.SHAPE) {
				_right = _right.coerce(compileContext.tree(), _left.type.indexType(compileContext), false, compileContext);
				if (_right.deferAnalysis()) {
					type = _right.type;
					return;
				}
				type = _left.type.elementType(compileContext);
			} else if (_left.type.family() == TypeFamily.STRING) {
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_32, false, compileContext);
				type = compileContext.arena().builtInType(TypeFamily.UNSIGNED_8);
			} else {
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	SUBTRACT:
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
			if (_left.type.scalarFamily(compileContext) == TypeFamily.POINTER && _right.type.scalarType(compileContext).isIntegral()) {
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
			switch (_left.type.scalarFamily(compileContext)) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_32:
			case	FLOAT_32:
			case	FLOAT_64:
			case	VAR:
				break;

			case	POINTER:
				type = compileContext.arena().builtInType(TypeFamily.SIGNED_64);
				break;

			default:
				add(typeNotAllowed[op()], compileContext.pool());
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
				_right = _right.coerce(compileContext.tree(), TypeFamily.SIGNED_64, false, compileContext);
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
			lvalue = _left.symbol();
			if (lvalue != null && lvalue.accessFlags() & Access.CONSTANT) {
				add(MessageId.BAD_WRITE_ATTEMPT, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			switch (_left.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
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
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	REMAINDER_ASSIGN:
			if (!assignOp(compileContext))
				break;
			lvalue = _left.symbol();
			if (lvalue != null && lvalue.accessFlags() & Access.CONSTANT) {
				add(MessageId.BAD_WRITE_ATTEMPT, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			switch (_left.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
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
				add(typeNotAllowed[op()], compileContext.pool());
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
			lvalue = _left.symbol();
			if (lvalue != null && lvalue.accessFlags() & Access.CONSTANT) {
				add(MessageId.BAD_WRITE_ATTEMPT, compileContext.pool());
				type = compileContext.errorType();
				break;
			}
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
			if ((_left.type.family() == TypeFamily.BOOLEAN ||
				 _left.type.family() == TypeFamily.FLAGS) &&
				(_right.type.family() == TypeFamily.BOOLEAN ||
				 _right.type.family() == TypeFamily.FLAGS))
				type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
			else {
				add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	SWITCH:
			compileContext.assignTypes(_left);
			if (!_left.deferAnalysis()) {
				switch (_left.type.family()) {
				case	STRING:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
				case	ENUM:
					break;

				default:
					add(typeNotAllowed[op()], compileContext.pool());
					_left.type = compileContext.errorType();
				}
			}
			compileContext.assignTypes(_right);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	CASE:
			compileContext.assignTypes(_right);
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	DO_WHILE:
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
			if (_right.type.family() != TypeFamily.BOOLEAN &&
				_right.type.family() != TypeFamily.FLAGS) {
				_right.add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			}
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;

		case	WHILE:
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
			if (_left.type.family() != TypeFamily.BOOLEAN &&
				_left.type.family() != TypeFamily.FLAGS) {
				_left.add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			}
			type = compileContext.arena().builtInType(TypeFamily.VOID);
			break;
		}
	}

	public void assignCaseExpression(ref<Type> switchType, ref<CompileContext> compileContext) {
		if (_left.isConstant()) {
			if (_left.type.equals(switchType))
				return;
			ref<SyntaxTree> tree = compileContext.current().file().tree();
			if (_left.canCoerce(switchType, false, compileContext))
				_left = tree.newCast(switchType, _left);
			else {
				// TODO: Create a CAST_IF_FITS toswitchType that checks at compile time, after the expression has been
				// folded to remove constant symbols and such.
				_left = tree.newCast(switchType, _left);
			}
		} else
			_left.add(MessageId.NOT_CONSTANT, compileContext.pool());
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
		case	SIGNED_16:
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

		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
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
		switch (_left.type.scalarFamily(compileContext)) {
		case	VAR:
			_right = _right.coerce(compileContext.tree(), TypeFamily.VAR, false, compileContext);
			if (_right.deferAnalysis()) {
				type = _right.type;
				return false;
			}
			return true;

		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	SIGNED_16:
			_left = _left.coerce(compileContext.tree(), TypeFamily.SIGNED_32, false, compileContext);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return false;
			}
			break;
			
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
		switch (_right.type.scalarFamily(compileContext)) {
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

		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
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
			ref<Call> call = tree.newCall(constructor.parameterScope(), CallCategory.CONSTRUCTOR, adr, args, addNode.location(), compileContext);
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
	ref<ParameterScope> scope = null;
	for (int i = 0; i < over.instances().length(); i++) {
		oi = (*over.instances())[i];
		scope = oi.parameterScope();
		if (scope.parameters().length() != 1)
			continue;
		if ((*scope.parameters())[0].type() == value.type)
			break;
	}
	assert(scope != null);
	ref<Selection> method = tree.newSelection(r, oi, false, value.location());
	method.type = oi.type();
	ref<NodeList> args = tree.newNodeList(value);
	ref<Call> call = tree.newCall(scope, null, method, args, value.location(), compileContext);
	call.type = compileContext.arena().builtInType(TypeFamily.VOID);
	return call.fold(tree, true, compileContext);
}


boolean balancePair(ref<Node> parent, ref<ref<Node>> leftp, ref<ref<Node>> rightp, ref<CompileContext> compileContext) {
	ref<Node> left = *leftp;
	ref<Node> right = *rightp;
	if (!left.type.equals(right.type)) {
		if (left.canCoerce(right.type, false, compileContext)) {
			if (right.canCoerce(left.type, false, compileContext)) {
				if (left.type.widensTo(right.type, compileContext)) {
					if (right.type.widensTo(left.type, compileContext)) {
						parent.add(MessageId.UNFINISHED_ASSIGN_TYPE, compileContext.pool(), CompileString("  "/*parent.class.name()*/), CompileString(string(parent.op())));
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
				
				// If the scalar-types agree, one must be a shape the other a scalar.
				
			} else if (!left.type.scalarType(compileContext).equals(right.type.scalarType(compileContext))) {
				parent.add(MessageId.TYPE_MISMATCH, compileContext.pool());
				parent.type = compileContext.errorType();
				return false;
			}
		}
	}
	if ((*rightp).type.family() == TypeFamily.SHAPE)
		parent.type = (*rightp).type;
	else
		parent.type = (*leftp).type;
	return true;
}

ref<Type> findCommonType(ref<Type> left, ref<Type> right, ref<CompileContext> compileContext) {
	if (left.equals(right))
		return left;
	else if (left.widensTo(right, compileContext))
		return right;
	else if (right.widensTo(left, compileContext))
		return left;
	else
		return left.greatestCommonBase(right);
}

private Operator stripAssignment(Operator op) {
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

public void markLiveSymbols(ref<Node> declarator, StorageClass storageClass, ref<CompileContext> compileContext) {
	switch (declarator.op()) {
	case	IDENTIFIER:
		ref<Identifier> id = ref<Identifier>(declarator);
		if (id.deferAnalysis())
			break;
		if (id.symbol().storageClass() == storageClass) {
			ref<Scope> scope = id.symbol().enclosing();
			if (!id.symbol().enclosing().inSwitch())
				compileContext.markLiveSymbol(id);
		}
		break;
		
	case	INITIALIZE:
		ref<Binary> b = ref<Binary>(declarator);
		markLiveSymbols(b.left(), storageClass, compileContext);
		break;
		
	case	SEQUENCE:
		b = ref<Binary>(declarator);
		markLiveSymbols(b.left(), storageClass, compileContext);
		markLiveSymbols(b.right(), storageClass, compileContext);
		break;
		
	case	CLASS_COPY:
		b = ref<Binary>(declarator);
		u = ref<Unary>(b.left());
		if (u.op() != Operator.ADDRESS) {
			declarator.print(0);
			assert(false);
		}
		markLiveSymbols(u.operand(), storageClass, compileContext);
		break;
		
	case	CALL:
		// It's a constructor initializer
		ref<Call> call = ref<Call>(declarator);
		if (call.category() != CallCategory.CONSTRUCTOR)
			break;
//		declarator.print(0);
		ref<Unary> u = ref<Unary>(call.target());
		if (u.op() != Operator.ADDRESS) {
			declarator.print(0);
			assert(false);
		}
		markLiveSymbols(u.operand(), storageClass, compileContext);
		break;
		
	case	EMPTY:
		break;
		
	default:
		declarator.print(0);
		assert(false);
	}
}

ref<OverloadInstance> getMethodSymbol(ref<Node> parent, string name, ref<Type> type, ref<CompileContext> compileContext) {
	CompileString csName(name);
	
	ref<Symbol> sym = type.lookup(&csName, compileContext);
	if (sym == null || sym.class != Overload) {
		parent.add(MessageId.UNDEFINED, compileContext.pool(), csName);
		return null;
	}
	ref<Overload> over = ref<Overload>(sym);
	return (*over.instances())[0];
}

ref<Node> sequenceNodes(ref<SyntaxTree> tree, ref<Node>... n) {
	ref<Node> result;
	for (int i = 0; i < n.length(); i++) {
		if (n[i] != null) {
			if (result != null) {
				ref<Binary> seq = tree.newBinary(Operator.SEQUENCE, result, n[i], n[i].location());
				seq.type = seq.right().type;
				result = seq;
			} else
				result = n[i];
		}
	}
	return result;
}

private boolean isCompileTarget(ref<Node> n, ref<Node> constant) {
	ref<Symbol> sym = n.symbol();
	if (sym == null)
		return false;
	if (sym.class != PlainSymbol)
		return false;
	if (ref<PlainSymbol>(sym).accessFlags() & Access.COMPILE_TARGET) {
		sym = constant.symbol();
		if (sym == null)
			return false;
		if (sym.storageClass() != StorageClass.ENUMERATION)
			return false;
	} else
		return false;
	return true;
}

private boolean matchesCompileTarget(Operator op, ref<Node> constant, ref<Target> target) {
	int constantIndex = constant.symbol().offset;
	int targetIndex = int(target.sectionType());
	
	switch (op) {
	case EQUALITY:
		return constantIndex == targetIndex;
		
	case NOT_EQUAL:
		return constantIndex != targetIndex;
	}
	return false;
}