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

import parasol:runtime;

public class Binary extends Node {
	private ref<Node> _left;
	private ref<Node> _right;

	Binary(Operator op, ref<Node> left, ref<Node> right, SourceOffset location) {
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
		case	INTERFACE_DECLARATION:
		case	CLASS_DECLARATION:
		case	FLAGS_DECLARATION:
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
		if (compileContext.verbose()) {
			printf("-----  fold %s context %s ---------\n", voidContext ? "void" : "value", compileContext.current().sourceLocation(location()));
			print(4);
		}
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
			return this;
		if (type.family() == runtime.TypeFamily.SHAPE) {
			switch (op()) {
			case	DECLARATION:
				markLiveSymbols(_right, StorageClass.AUTO, compileContext);
				
			case	BIND:
				_left = _left.fold(tree, false, compileContext);
				_right = _right.foldDeclarator(tree, compileContext);
				return this;
				
			case	DEF_ASSIGN:
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
					ref<Node> n = vectorize(tree, operation, compileContext);
					if (op() == Operator.INITIALIZE) {
						n = tree.newBinary(Operator.INITIALIZE_WRAPPER, _left, n, location());
						n.type = type;
					}
					return n;
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
			_right = _right.foldDeclarator(tree, compileContext);
			return this;

		case	FLAGS_DECLARATION:
		case	CLASS_DECLARATION:
		case	INTERFACE_DECLARATION:
		case	SWITCH:
		case	LEFT_SHIFT:
		case	BIND:
		case	DELETE:
		case	LABEL:
			break;

		case	SWITCH:
			if (_left.type.isString()) {
				type = _left.type;
				if (!_left.isLvalue()) {
					ref<Variable> temp = compileContext.newVariable(type);
					ref<Reference> r = tree.newReference(temp, true, location());
					compileContext.markLiveSymbol(r);
					ref<Node> call = tree.newBinary(Operator.STORE_TEMP, r, _left, location());
					call.type = type;
					call = call.fold(tree, true, compileContext);
					r = tree.newReference(temp, false, location());
					ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, location());
					adr.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
					ref<Node> seq = tree.newBinary(Operator.SEQUENCE, call, adr, location());
					seq.type = type;
					_left = seq;
				} else {
					_left = _left.fold(tree, false, compileContext);
					_left = tree.newUnary(Operator.ADDRESS, _left, location());
					_left.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
				}
				_right = _right.fold(tree, true, compileContext);
				return this;
			}
			break;

		// A CASE statement can arrive here in situations where the compiler is trying to recover
		// from other errors, such as syntax errors in a method declaration. The type of a CASE expression
		// is assigned during assignControlFlow and that doesn't visit every possible combination of
		// questionable code.
		case	CASE:
			if (_left.type == null)
				_left.type = compileContext.errorType();
			break;

		case	LOGICAL_AND:
		case	LOGICAL_OR:
			_right = _right.foldConditional(tree, compileContext);
			if (_right.type.family() == runtime.TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _right.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _right, right, location());
				op.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
				_right = op;
			}
			_left = _left.foldConditional(tree, compileContext);
			if (_left.type.family() == runtime.TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _left.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _left, right, location());
				op.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
				_left = op;
			}
			return this;
			
		case	WHILE:
			_right = _right.fold(tree, true, compileContext);
			_left = _left.foldConditional(tree, compileContext);
			if (_left.type.family() == runtime.TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _left.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _left, right, location());
				op.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
				_left = op;
			}
			return this;
			
		case	DO_WHILE:
			_left = _left.fold(tree, true, compileContext);
			_right = _right.foldConditional(tree, compileContext);
			if (_right.type.family() == runtime.TypeFamily.FLAGS) {
				ref<Node> right = tree.newConstant(0, location());
				right.type = _right.type;
				ref<Node> op = tree.newBinary(Operator.NOT_EQUAL, _right, right, location());
				op.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
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
			if (type.family() == runtime.TypeFamily.VAR)
				return processAssignmentOp(tree, voidContext, compileContext);
			if (_left.op() == Operator.SUBSCRIPT) {
				ref<Node> element = ref<Binary>(_left).subscriptModify(tree, compileContext);
				if (element != null)
					_left = element;
			}
			break;

		case	LEFT_SHIFT:
			if (type.family() == runtime.TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left, "leftShift", tree, compileContext, _right);
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	RIGHT_SHIFT:
			if (type.family() == runtime.TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "rightShift", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	UNSIGNED_RIGHT_SHIFT:
			if (type.family() == runtime.TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "unsignedRightShift", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	AND:
			if (type.family() == runtime.TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "and", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	DIVIDE:
			if (type.family() == runtime.TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "divide", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	REMAINDER:
			if (type.family() == runtime.TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "remainder", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	EXCLUSIVE_OR:
			if (type.family() == runtime.TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "exclusiveOr", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	OR:
			if (type.family() == runtime.TypeFamily.VAR) {
				ref<Node> call = createMethodCall(_left.fold(tree, false, compileContext), "or", tree, compileContext, _right.fold(tree, false, compileContext));
				call.type = type;
				return call.fold(tree, voidContext, compileContext);
			}
			break;

		case	INITIALIZE:
			int liveCount = compileContext.liveSymbolCount();
			ref<Node> foldedInit = foldInitialization(tree, compileContext);
			if (foldedInit != this && _left.op() != Operator.VARIABLE) {
				foldedInit = tree.newBinary(Operator.INITIALIZE_WRAPPER, _left, foldedInit, location());
				foldedInit.type = type;
			}
			if (compileContext.liveSymbolCount() == liveCount)
				return foldedInit;
			ref<Node> d = attachLiveTempDestructors(tree, liveCount, compileContext);
			return tree.newBinary(Operator.SEQUENCE, foldedInit, d, foldedInit.location());
			
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
				seq.type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
				arg.type = compileContext.builtInType(runtime.TypeFamily.SIGNED_64);
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
					_right.type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
				ref<Node> seq = tree.newBinary(Operator.SEQUENCE, defn, constructor.fold(tree, true, compileContext), location());
				seq.type = compileContext.builtInType(runtime.TypeFamily.VOID);
				if (voidContext)
					return seq;
				r = tree.newReference(temp, false, location());
				seq = tree.newBinary(Operator.SEQUENCE, seq, r, location());
				seq.type = type;
				return seq;
			} else {
				if (allocation == this) {
					_right = tree.newLeaf(Operator.EMPTY, location());
					_right.type = compileContext.builtInType(runtime.TypeFamily.VOID);
				}
				if (defaultConstructor != null) // This must have been a late-created constructor.
					return foldDefaultConstructor(defaultConstructor, allocation, tree, voidContext, compileContext);
				else
					return defaultNewInitialization(allocation, tree, voidContext, compileContext);
			}
			break;
			
		case	DELETE:
			ref<Node> defn;
			ref<Node> value;
			(defn, value) = cloneDefnValue(tree, _right, compileContext);
			ref<Node> completion;
			if (_left.op() == Operator.EMPTY) {
				_right = value.fold(tree, false, compileContext);
				completion = this;
			} else {
				ref<Node> allocator = _left;
				ref<Type> allocatorType = _left.type.indirectType(compileContext);
				if (allocatorType != null) {
					allocator = tree.newUnary(Operator.INDIRECT, _left, location());
					allocator.type = allocatorType;
				}
				ref<Node> call = createMethodCall(allocator.fold(tree, false, compileContext), "free", tree, compileContext, value);
				call.type = type;
				completion = call.fold(tree, true, compileContext);
			}
			ref<Type> objType = value.type.indirectType(compileContext);
			if (value.type.family() == runtime.TypeFamily.INTERFACE)
				objType = value.type;
			else
				objType = value.type.indirectType(compileContext);
			if (objType != null && objType.hasDestructor()) {
				ref<ParameterScope> des = objType.scope().destructor();
				ref<Call> call = tree.newCall(des, CallCategory.DESTRUCTOR, value, null, location(), compileContext);
				value = value.clone(tree);
				call.type = type;			// We know this is VOID
				completion = tree.newBinary(Operator.SEQUENCE, call.fold(tree, false, compileContext), completion, location());
				completion.type = type;
				ref<Node> con = tree.newConstant(0, location());
				con.type = value.type;
				ref<Node> compare = tree.newBinary(Operator.NOT_EQUAL, value, con, location());
				compare.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
				ref<Node> nullPath = tree.newLeaf(Operator.EMPTY, location());
				nullPath.type = call.type;
				completion = tree.newTernary(Operator.CONDITIONAL, compare, completion, nullPath, location());
				completion.type = call.type;
			}
			if (defn != null) {
				completion = tree.newBinary(Operator.SEQUENCE, defn.fold(tree, true, compileContext), completion, location());
				completion.type = type;
			}
			return completion;
			
		case	MULTIPLY:
			if (type.family() == runtime.TypeFamily.VAR) {
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
					x.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
					return x;
				} else {
					ref<Node> x = tree.newLeaf(Operator.FALSE, location());
					x.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
					return x;
				}
			} else if (isCompileTarget(_right, _left)) {
				if (matchesCompileTarget(op(), _left, compileContext.target)) {
					ref<Node> x = tree.newLeaf(Operator.TRUE, location());
					x.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
					return x;
				} else {
					ref<Node> x = tree.newLeaf(Operator.FALSE, location());
					x.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
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
			if ((nodeFlags & USE_COMPARE_METHOD) != 0) {
				break;
			}
			switch (_left.type.family()) {
			case	TYPEDEF:
			case	CLASS_VARIABLE:
				ref<Type> t = compileContext.runtimeClassType();
				ref<OverloadInstance> compareMethod = getOverloadInstance(t, "compare", compileContext);
				if (compareMethod == null)
					return this;
				switch (op()) {
				case	EQUALITY:
				case	NOT_EQUAL:
					break;
					
				case	LESS:
				case	GREATER:
				case	LESS_EQUAL:
				case	GREATER_EQUAL:
				case	LESS_GREATER:
				case	LESS_GREATER_EQUAL:
				case	NOT_LESS:
				case	NOT_GREATER:
				case	NOT_LESS_EQUAL:
				case	NOT_GREATER_EQUAL:
				case	NOT_LESS_GREATER:
				case	NOT_LESS_GREATER_EQUAL:
					ref<Selection> method = tree.newSelection(_left, compareMethod, true, location());
					method.type = compareMethod.type();
					call = tree.newCall(compareMethod.parameterScope(), CallCategory.METHOD_CALL, method, 
														tree.newNodeList(_right), location(), compileContext);
					call.type = compileContext.builtInType(runtime.TypeFamily.FLOAT_32);
					_left = call.fold(tree, voidContext, compileContext);
					_right = tree.newConstant(Operator.FLOATING_POINT, "0.0", location());
					_right.type = call.type;
					return this;
					
				default:
					print(0);
					assert(false);
				}
				break;
				
			case	STRING:
			case	STRING16:
				if (_left.op() == Operator.SUBSCRIPT) {
					ref<Variable> temp = compileContext.newVariable(_left.type);
					ref<Node> r = tree.newReference(temp, true, location());
					compileContext.markLiveSymbol(r);
					ref<Node> x = tree.newBinary(Operator.ASSIGN_TEMP, r, _left, location());
					x.type = _left.type;
					ref<Node> y = tree.newReference(temp, false, location());
					ref<Node> call = createMethodCall(y, "compare", tree, compileContext, _right);
					call.type = compileContext.builtInType(runtime.TypeFamily.SIGNED_32);
					_left = tree.newBinary(Operator.SEQUENCE, x, call, location());
					_left.type = call.type;
					_left = _left.fold(tree, false, compileContext);
					_right = tree.newConstant(0, location());
					_right.type = _left.type;
					break;
				}

			case	VAR:
				ref<Node> call = createMethodCall(_left, "compare", tree, compileContext, _right);
				call.type = compileContext.builtInType(runtime.TypeFamily.SIGNED_32);
				_left = call.fold(tree, voidContext, compileContext);
				_right = tree.newConstant(0, location());
				_right.type = _left.type;
				break;

			case SIGNED_8:
			case SIGNED_16:
			case SIGNED_32:
			case SIGNED_64:
			case UNSIGNED_8:
			case UNSIGNED_16:
			case UNSIGNED_32:
			case UNSIGNED_64:
			case BOOLEAN:
			case FLOAT_32:
			case FLOAT_64:
				if (_left.isConstantLiteral()) {
					if (_right.isConstantLiteral())
						return foldConstantCompare(tree, compileContext);
					n := tree.newBinary(op().reversedCompare(), _right.fold(tree, false, compileContext), 
										_left.fold(tree, false, compileContext), location());
					n.type = type;
					return n;
				}
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
					b.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
					ref<Unary> u = tree.newUnary(Operator.INDIRECT, b, location());
					u.type = type;
					return u;
				}
			} else {
				switch (_left.type.family()) {
				case STRING:
				case STRING16:
				case OBJECT_AGGREGATE:
				case ARRAY_AGGREGATE:
					substring ename("elementAddress");
					
					ref<Symbol> sym = _left.type.lookup(ename, compileContext);
					if (sym == null || sym.class != Overload) {
						add(MessageId.UNDEFINED, compileContext.pool(), ename);
						break;
					}
					ref<Overload> o = ref<Overload>(sym);
					ref<OverloadInstance> oi = (*o.instances())[0];
					ref<Selection> method = tree.newSelection(_left, oi, false, location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
					call.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
					ref<Unary> u = tree.newUnary(Operator.INDIRECT, call.fold(tree, false, compileContext), location());
					u.type = type;
					return u;

				case SUBSTRING:
				case SUBSTRING16:
				case SHAPE:
					substring name("get");
					
					sym = _left.type.lookup(name, compileContext);
					if (sym == null || sym.class != Overload) {
						add(MessageId.UNDEFINED, compileContext.pool(), name);
						break;
					}
					o = ref<Overload>(sym);
					oi = (*o.instances())[0];
					method = tree.newSelection(_left, oi, false, location());
					method.type = oi.type();
					args = tree.newNodeList(_right);
					call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
					call.type = type;
					return call.fold(tree, false, compileContext);
				}
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
				
			case STRING:
			case STRING16:
				return foldStringAppend(this, tree, voidContext, compileContext);

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
			case	STRING16:
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
			
		case	DEF_ASSIGN:
			_left.type = type;
			ref<Node> assignment = tree.newBinary(Operator.ASSIGN, _left, _right, location());
			assignment.type = type;
			return assignment.fold(tree, voidContext, compileContext);

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
				
			case	STRING16:
			case	STRING:
				if (_right.op() == Operator.CALL && ref<Call>(_right).category() != CallCategory.CONSTRUCTOR && !_right.multiReturnCall()) {
					ref<OverloadInstance> oi;
					ref<Type> storeType;
					if (op() == Operator.ASSIGN_TEMP) {
						oi = type.tempAssignmentMethod(compileContext);
						storeType = compileContext.builtInType(runtime.TypeFamily.VOID);
					} else if (op() == Operator.STORE_TEMP) {
						string methodName;
						if (voidContext) {
							methodName = "storeTemp";
							storeType = compileContext.builtInType(runtime.TypeFamily.VOID);
						} else {
							methodName = "storeTemp_nv";
							storeType = type;
						}
						oi = getMethodSymbol(_right, methodName, type, compileContext);
					} else {
						string methodName;
						if (voidContext) {
							methodName = "store";
							storeType = compileContext.builtInType(runtime.TypeFamily.VOID);
						} else {
							methodName = "store_nv";
							storeType = type;
						}
						oi = getMethodSymbol(_right, methodName, type, compileContext);
					}
					if (oi == null) {
						type = compileContext.errorType();
						return this;
					}
					// This is the assignment method for this class!!!
					// (all strings go through here).
					ref<Selection> method = tree.newSelection(_left, oi, false, _left.location());
					method.type = oi.type();
					ref<Node> nestedCall = _right.fold(tree, false, compileContext);
					nestedCall.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
					ref<NodeList> args = tree.newNodeList(nestedCall);
					ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
					call.type = storeType;
					return call.fold(tree, voidContext, compileContext);
				}

			case	SUBSTRING:
			case	SUBSTRING16:
			case	CLASS:
			case	SHAPE:
				ref<OverloadInstance> oi;
				if (op() == Operator.ASSIGN_TEMP)
					oi = type.tempAssignmentMethod(compileContext);
				else
					oi = type.assignmentMethod(compileContext);
				if (oi != null) {
					// This is the assignment method for this class!!!
					ref<Selection> method = tree.newSelection(_left, oi, false, _left.location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(_right);
					ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
					call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
					return call.fold(tree, voidContext, compileContext);
				} else {
					ref<Node> result = foldClassCopy(tree, false, compileContext);
					if (result != null)
						return result;
				}
				break;
				
			case	VAR:
				if (op() == Operator.ASSIGN_TEMP)
					oi = type.tempAssignmentMethod(compileContext);
				else
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
					call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
	
	public ref<Node> foldConstantCompare(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		long i, j;
		boolean success;
		switch (_left.op()) {
		case FLOATING_POINT:
			x := ref<Constant>(_left).floatValue();
			y := ref<Constant>(_right).floatValue();
			switch (op()) {
			case	EQUALITY:					success = x == y; break;
			case	NOT_EQUAL:					success = x != y; break;
			case	LESS:						success = x < y; break;
			case	LESS_EQUAL:					success = x <= y; break;
			case	LESS_GREATER_EQUAL:			success = x <>= y; break;
			case	NOT_LESS:					success = x !< y; break;
			case	NOT_LESS_EQUAL:				success = x !<= y; break;
			case	NOT_LESS_GREATER_EQUAL:		success = x !<>= y; break;
			case	GREATER:					success = x > y; break;
			case	GREATER_EQUAL:				success = x >= y; break;
			case	NOT_GREATER:				success = x !> y; break;
			case	NOT_GREATER_EQUAL:			success = x !>= y; break;
			case	LESS_GREATER:				success = x <> y; break;
			case	NOT_LESS_GREATER:			success = x !<> y; break;

			default:
				return this;
			}
			if (success)
				n := tree.newLeaf(Operator.TRUE, location());
			else
				n = tree.newLeaf(Operator.FALSE, location());
			n.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
			return n;

		case CHARACTER:
			i = ref<Constant>(_left).charValue();
			j = ref<Constant>(_right).charValue();
			break;

		case INTEGER:
		case INTERNAL_LITERAL:
			i = ref<Constant>(_left).intValue();
			j = ref<Constant>(_right).intValue();
			break;

		case FALSE:
			i = 0;
			if (_right.op() == Operator.TRUE)
				j = 1;
			break;

		case TRUE:
			i = 1;
			if (_right.op() == Operator.TRUE)
				j = 1;
			break;

		default:
			return this;
		}
		switch (op()) {
		case	EQUALITY:
		case	NOT_LESS_GREATER:			success = i == j; break;
		case	NOT_EQUAL:
		case	LESS_GREATER:				success = i != j; break;
		case	LESS:
		case	NOT_GREATER_EQUAL:			success = i < j; break;
		case	LESS_EQUAL:
		case	NOT_GREATER:				success = i <= j; break;
		case	GREATER_EQUAL:
		case	NOT_LESS:					success = i >= j; break;
		case	GREATER:
		case	NOT_LESS_EQUAL:				success = i > j; break;
		case	LESS_GREATER_EQUAL:			success = true; break;
		case	NOT_LESS_GREATER_EQUAL:		success = false; break;

		default:
			return this;
		}
		if (success)
			n := tree.newLeaf(Operator.TRUE, location());
		else
			n = tree.newLeaf(Operator.FALSE, location());
		n.type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
		return n;
	}

	public ref<Node> foldDeclarator(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		if (op() == Operator.SEQUENCE) {
			_left = _left.foldDeclarator(tree, compileContext);
			_right = _right.foldDeclarator(tree, compileContext);
			return this;
		} else
			return fold(tree, false, compileContext);
	}

	public ref<Node> foldInitialization(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		if (_right.op() == Operator.CALL) {
			ref<Call> constructor = ref<Call>(_right);
			if (constructor.category() == CallCategory.CONSTRUCTOR) {
				// This is the case of a constructor for a class that has no
				// constructors declared.
				if (constructor.overload() == null) {
					_right = tree.newLeaf(Operator.EMPTY, _right.location());
					return this;
				}
				ref<Node> adr = tree.newUnary(Operator.ADDRESS, _left, _left.location());
				adr.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
				constructor.setConstructorMemory(adr, tree);
				return constructor.fold(tree, true, compileContext);
			}
		}
		_right = _right.fold(tree, false, compileContext);
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
		case	ARRAY_AGGREGATE:
		case	EXCEPTION:
		case	CLASS:
		case	VAR:
		case	SUBSTRING:
		case	SUBSTRING16:
			ref<ParameterScope> copyConstructor = type.copyConstructor();
			if (copyConstructor != null) {
				ref<Node> adr = tree.newUnary(Operator.ADDRESS, _left, location());
				adr.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
				ref<NodeList> args = tree.newNodeList(_right);
				ref<Call> constructor = tree.newCall(copyConstructor, CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
				constructor.type = compileContext.builtInType(runtime.TypeFamily.VOID);
				return constructor.fold(tree, true, compileContext);
			} else {
				ref<Node> result = foldClassCopy(tree, true, compileContext);
				if (result != null)
					return result;
			}
			break;
			
		case	STRING16:
		case	STRING:
			if (_right.op() == Operator.CALL) {
				ref<OverloadInstance> oi = type.stringAllocationConstructor(compileContext);
				if (oi == null) {
					_right.add(MessageId.INTERNAL_ERROR, compileContext.pool());
					type = compileContext.errorType();
					return this;
				}
				ref<Selection> method = tree.newSelection(_left, oi, false, _left.location());
				method.type = oi.type();
				_right.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
				ref<NodeList> args = tree.newNodeList(_right);
				ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
				call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
				return call.fold(tree, true, compileContext);
			}
			copyConstructor = type.copyConstructor();
			if (copyConstructor != null) {
				ref<Node> adr = tree.newUnary(Operator.ADDRESS, _left, location());
				adr.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
				ref<NodeList> args = tree.newNodeList(_right);
				ref<Call> constructor = tree.newCall(copyConstructor, CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
				constructor.type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
			constructor.type = compileContext.builtInType(runtime.TypeFamily.VOID);
		}
		ref<Node> seq = tree.newBinary(Operator.SEQUENCE, defn, constructor, location());
		seq.type = compileContext.builtInType(runtime.TypeFamily.VOID);
		if (voidContext)
			return seq;
		r = tree.newReference(temp, false, location());
		seq = tree.newBinary(Operator.SEQUENCE, seq, r, location());
		seq.type = type;
		return seq;
	}
	
	private ref<Node> defaultNewInitialization(ref<Node> allocation, ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		ref<Type> objType = type.indirectType(compileContext);
		if (objType.hasVtable(compileContext) || objType.interfaceCount() > 0) {
			ref<Variable> temp = compileContext.newVariable(type);
			ref<Reference> r = tree.newReference(temp, true, location());
			ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, allocation, location());
			defn.type = type;
			r = tree.newReference(temp, false, location());
			ref<Node> constructor = tree.newUnary(Operator.STORE_V_TABLE, r, location());
			constructor.type = objType;
			ref<Node> seq = tree.newBinary(Operator.SEQUENCE, defn, constructor, location());
			seq.type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
			seq.type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
			ref<Node> left = tree.newUnary(Operator.ADDRESS, _left.fold(tree, false, compileContext), location());
			left.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
			_right = _right.fold(tree, false, compileContext);
			if (_right.op() != Operator.CLASS_COPY) {
				_right = tree.newUnary(Operator.ADDRESS, _right, location());
				_right.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
			}
			ref<Variable> dest = compileContext.newVariable(left.type);
			ref<Variable> src = compileContext.newVariable(left.type);
			ref<Reference> destR = tree.newReference(dest, true, location());
			ref<Reference> srcR = tree.newReference(src, true, location());
			ref<Node> da = tree.newBinary(Operator.ASSIGN, destR, left, location());
			da.type = left.type;
			ref<Node> sa = tree.newBinary(Operator.ASSIGN, srcR, _right, location());
			sa.type = left.type;
			ref<Node> seq = tree.newBinary(Operator.SEQUENCE, da, sa, location());
			seq.type = left.type;
			if (initializer) {
				destR = tree.newReference(dest, false, location());
				da = tree.newUnary(Operator.CLASS_CLEAR, destR, location());
				da.type = type;
				seq = tree.newBinary(Operator.SEQUENCE, seq, da, location());
				seq.type = left.type;
				if (left.type.hasVtable(compileContext)) {
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
			ref<Node> n = tree.newUnary(Operator.ADDRESS, _left.fold(tree, false, compileContext), location());
			n.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
			_right = _right.fold(tree, false, compileContext);
			if (_right.op() != Operator.CLASS_COPY) {
				_right = tree.newUnary(Operator.ADDRESS, _right, location());
				_right.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
			}
			ref<Binary> copy = tree.newBinary(Operator.CLASS_COPY, n, _right, location());
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
		case	VARIABLE:
			return _left, _left.clone(tree);
			
		default:
			ref<Node> addr = tree.newUnary(Operator.ADDRESS, _left, location());
			addr.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
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
		type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
		_right = tree.newCast(type, _right);
	}
	
	private ref<Node> subscriptAssign(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		ref<Binary> subscript = ref<Binary>(_left);
		if (subscript.left().type.isVector(compileContext) ||
			subscript.left().type.isMap(compileContext) ||
			subscript.left().type.family() == runtime.TypeFamily.SHAPE) {
			substring name("set");
			
			ref<Symbol> sym = subscript.left().type.lookup(name, compileContext);
			if (sym == null || sym.class != Overload) {
				subscript.add(MessageId.UNDEFINED, compileContext.pool(), name);
				return null;
			}
			ref<Overload> over = ref<Overload>(sym);
			ref<OverloadInstance> oi = (*over.instances())[0];
			ref<Selection> method = tree.newSelection(subscript.left(), oi, false, subscript.location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(subscript.right(), _right);
			ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, location(), compileContext);
			call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
			return call;
		} else
			return null;
	}
	
	ref<Node> subscriptModify(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		if (_left.type.isVector(compileContext) ||
			_left.type.isMap(compileContext) ||
			_left.type.family() == runtime.TypeFamily.SHAPE) {
			substring name("elementAddress");
			
			ref<Symbol> sym = _left.type.lookup(name, compileContext);
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
			call.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
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

		case	DIVIDE:
			x = _left.foldInt(target, compileContext);
			y = _right.foldInt(target, compileContext);
			return x / y;

		case	LEFT_SHIFT:
			x = _left.foldInt(target, compileContext);
			y = _right.foldInt(target, compileContext);
			return x << y;

		case	RIGHT_SHIFT:
			if (type.isSigned()) {
				x = _left.foldInt(target, compileContext);
				y = _right.foldInt(target, compileContext);
				return x >> y;
			}

		case	UNSIGNED_RIGHT_SHIFT:
			x = _left.foldInt(target, compileContext);
			y = _right.foldInt(target, compileContext);
			return x >>> y;

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
		case	DIVIDE:
		case	LEFT_SHIFT:
		case	RIGHT_SHIFT:
		case	UNSIGNED_RIGHT_SHIFT:
			if (_left.isConstant() && _right.isConstant())
				return true;
		}
		return false;
	}
	
	public void assignClassVariable(ref<CompileContext> compileContext) {
		assert(op() == Operator.INITIALIZE);
		compileContext.assignTypes(_right);
		if (_right.type.family() != runtime.TypeFamily.TYPEDEF) {
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
			type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
					call.assignConstructorDeclarator(t, compileContext);
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
				compileContext.assignTypes(aggregate);
				if (aggregate.deferAnalysis())
					type = _right.type;
				else {
					if (!aggregate.canCoerce(_left.type, false, compileContext)) { 
						aggregate.add(MessageId.CANNOT_CONVERT, compileContext.pool());
						aggregate.type = compileContext.errorType();
						type = aggregate.type;
						return;
					}
					if (aggregate.coerceAggregateType(_left.type, compileContext)) 
						type = _left.type;
					else
						type = _right.type;
				}
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
			switch (_left.type.family()) {
			case SUBSTRING:
				if (_right.type.family() == runtime.TypeFamily.STRING) {
					if (!_right.isLvalue()) {
						_right.add(MessageId.LVALUE_REQUIRED, compileContext.pool());
						type = compileContext.errorType();
						return;
					}
				}
				break;

			case SUBSTRING16:
				if (_right.type.family() == runtime.TypeFamily.STRING16) {
					if (!_right.isLvalue()) {
						_right.add(MessageId.LVALUE_REQUIRED, compileContext.pool());
						type = compileContext.errorType();
						return;
					}
				}
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
			if (_left.type.family() == runtime.TypeFamily.TYPEDEF)
				arrayDeclaration(compileContext);
			else {
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
		} else if (_right.type.family() == runtime.TypeFamily.TYPEDEF) {
			ref<Type> keyType = _right.unwrapTypedef(Operator.CLASS, compileContext);
			ref<Type> vectorType = compileContext.newVectorType(_left.unwrapTypedef(Operator.CLASS, compileContext), keyType);
			if (vectorType == null) { // Not an allowed combination.
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
		case	ANNOTATED:
			compileContext.assignTypes(_left);
			if (_left.deferAnalysis()) {
				type = _left.type;
				return;
			}

		case	INTERFACE_DECLARATION:
		case	CLASS_DECLARATION:
		case	FLAGS_DECLARATION:
			compileContext.assignTypes(_right);
			type = compileContext.builtInType(runtime.TypeFamily.VOID);
			break;

		case	DECLARATION:
			switch (_left.op()) {
			case ELLIPSIS:
				_left.add(MessageId.BAD_ELLIPSIS, compileContext.pool());
				type = compileContext.errorType();
				break;
				
			case EMPTY:	// A class alias
				type = compileContext.builtInType(runtime.TypeFamily.CLASS_VARIABLE);
				_right.assignClassVariable(compileContext);
				break;
				
			default:
				type = _left.unwrapTypedef(Operator.CLASS, compileContext);
				if (deferAnalysis())
					break;
				if (type.family() == runtime.TypeFamily.TEMPLATE) {
					_left.add(MessageId.TEMPLATE_NAME_DISALLOWED, compileContext.pool());
					type = compileContext.errorType();
					break;
				} else if (type.family() == runtime.TypeFamily.VOID) {
					_left.add(MessageId.INVALID_VOID, compileContext.pool());
					type = compileContext.errorType();
					break;
				}
				_right.markupDeclarator(type, true, compileContext);
			}
			break;

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
				ref<Call>(_right).forceCallToConstructor();
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
			if (!_left.canCoerce(compileContext.builtInType(runtime.TypeFamily.ADDRESS), false, compileContext)) { 
				_left.add(MessageId.CANNOT_CONVERT, compileContext.pool());
				_left.type = compileContext.errorType();
				type = _left.type;
				break;
			}
			type = compileContext.newRef(type);
			break;

		case	NEW:
			if (_left.op() != Operator.EMPTY) {
				compileContext.assignTypes(_left);
				if (_left.deferAnalysis()) {
					type = _left.type;
					break;
				}
				ref<Type> t = compileContext.memoryAllocatorType();
				if (!_left.type.extendsFormally(t, compileContext)) {
					ref<Type> indirect = _left.type.indirectType(compileContext);
					if (indirect == null ||
						!indirect.extendsFormally(t, compileContext)) {
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
				ref<Call>(_right).forceCallToConstructor();
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
			type = compileContext.newRef(type);
			break;

		case	DELETE:
			if (_left.op() != Operator.EMPTY) {
				compileContext.assignTypes(_left);
				if (_left.deferAnalysis()) {
					type = _left.type;
					break;
				}
				ref<Type> t = compileContext.memoryAllocatorType();
				if (!_left.type.extendsFormally(t, compileContext)) {
					ref<Type> indirect = _left.type.indirectType(compileContext);
					if (indirect == null ||
						!indirect.extendsFormally(t, compileContext)) {
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
			if (_right.type.family() == runtime.TypeFamily.INTERFACE)
				type = compileContext.builtInType(runtime.TypeFamily.VOID);
			else if (_right.canCoerce(compileContext.builtInType(runtime.TypeFamily.ADDRESS), false, compileContext)) 
				type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
			runtime.TypeFamily stringAddition = runtime.TypeFamily.VOID;
			switch (_left.type.family()) {
			case POINTER:
				compileContext.assignTypes(_right);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_64, false, compileContext);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				type = _left.type;
				break;

			case STRING:
			case SUBSTRING:
				stringAddition = runtime.TypeFamily.STRING;
				break;

			case STRING16:
			case SUBSTRING16:
				stringAddition = runtime.TypeFamily.STRING16;
			}
			if (stringAddition == runtime.TypeFamily.VOID) {
				compileContext.assignTypes(_right);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				switch (_right.type.family()) {
				case STRING:
				case SUBSTRING:
					stringAddition = runtime.TypeFamily.STRING;
					break;

				case STRING16:
				case SUBSTRING16:
					stringAddition = runtime.TypeFamily.STRING16;
				}
			}
			// Process string addition here.
			if (stringAddition != runtime.TypeFamily.VOID) {
				compileContext.assignTypes(_right);
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				_left = _left.coerceStringAdditionOperand(compileContext.tree(), stringAddition, false, compileContext);
				_right = _right.coerceStringAdditionOperand(compileContext.tree(), stringAddition, false, compileContext);
				if (_left.deferAnalysis()) {
					type = _left.type;
					break;
				}
				if (_right.deferAnalysis()) {
					type = _right.type;
					break;
				}
				type = _left.type;
				break;
			}
			if (type != null)
				break;
			if (!balance(compileContext))
				break;
			switch (_left.type.scalarFamily(compileContext)) {
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
			if (_left.type.family() == runtime.TypeFamily.STRING ||
				_left.type.family() == runtime.TypeFamily.STRING16) {
				switch (_right.type.family()) {
				case	STRING:
				case	STRING16:
				case	SUBSTRING:
				case	SUBSTRING16:
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
				_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_64, false, compileContext);
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

		case	DEF_ASSIGN:
			compileContext.assignTypes(_right);
			compileContext.assignTypes(_left);
			if (_left.op() != Operator.IDENTIFIER) {
				_left.add(MessageId.ID_REQUIRED, compileContext.pool());
				type = compileContext.errorType();
			} else if (_left.deferAnalysis())
				type = _left.type;
			else
				type = _right.type;
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
					_left.assignMultiReturn(true, funcType.returnTypes(), funcType.returnCount(), compileContext);
					if (_left.deferAnalysis())
						type = _left.type;
					else
						type = compileContext.builtInType(runtime.TypeFamily.VOID);
				}
			} else {
				if (!_left.isLvalue()) {
					add(MessageId.LVALUE_REQUIRED, compileContext.pool());
					type = compileContext.errorType();
					break;
				}
				coerceRight(_left.type, false, compileContext);
				if (_right.type != null) {
					
					type = _right.type;
				} else {
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
				type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
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
			if (_left.type.canCheckEquality(compileContext)) {
				switch (_left.type.family()) {
				case	REF:
				case	POINTER:
				case	INTERFACE:
					break;

				case SUBSTRING:
				case SUBSTRING16:
					nodeFlags |= USE_COMPARE_METHOD;
					break;
					
				default:
					if (_left.type.class <= ClassType)
						nodeFlags |= USE_COMPARE_METHOD;
				}
				type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
			} else {
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
			if (_left.type.canCheckOrder(compileContext)) {
				switch (_left.type.family()) {
				case	REF:
				case	POINTER:
					break;

				case SUBSTRING:
				case SUBSTRING16:
					nodeFlags |= USE_COMPARE_METHOD;
					break;
					
				default:
					if (_left.type.class <= ClassType)
						nodeFlags |= USE_COMPARE_METHOD;
				}
				type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
			} else {
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	LESS_GREATER_EQUAL:
		case	NOT_LESS_GREATER_EQUAL:
			if (!balance(compileContext))
				break;
			if (_left.type.canCheckPartialOrder(compileContext)) {
				switch (_left.type.family()) {
				case	REF:
				case	POINTER:
					break;

				default:
					if (_left.type.class <= ClassType)
						nodeFlags |= USE_COMPARE_METHOD;
				}
				type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
			} else {
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	BIND:
			type = _left.unwrapTypedef(Operator.CLASS, compileContext);
			if (type.family() == runtime.TypeFamily.VOID) {
				_left.add(MessageId.INVALID_VOID, compileContext.pool());
				type = compileContext.errorType();
			}
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
			if (_left.type.family() == runtime.TypeFamily.TYPEDEF) {
				arrayDeclaration(compileContext);
				break;
			}
			if (_left.type.isPointer(compileContext)) {
				_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_64, false, compileContext);
				type = _left.type.indirectType(compileContext);
			} else if (_left.type.isVector(compileContext) || 
					   _left.type.isMap(compileContext) ||
					   _left.type.family() == runtime.TypeFamily.SHAPE) {
				_right = _right.coerce(compileContext.tree(), _left.type.indexType(), false, compileContext);
				if (_right.deferAnalysis()) {
					type = _right.type;
					return;
				}
				type = _left.type.elementType();
			} else if (_left.type.isString()) {
				_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_32, false, compileContext);
				runtime.TypeFamily elementFamily = runtime.TypeFamily.UNSIGNED_8;
				switch (_left.type.family()) {
				case STRING16:
				case SUBSTRING16:
					elementFamily = runtime.TypeFamily.UNSIGNED_16;
				}
				type = compileContext.builtInType(elementFamily);
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
			if (_left.type.scalarFamily(compileContext) == runtime.TypeFamily.POINTER && _right.type.scalarType(compileContext).isIntegral()) {
				_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_64, false, compileContext);
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
				type = compileContext.builtInType(runtime.TypeFamily.SIGNED_64);
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
				_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_64, false, compileContext);
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
			if ((_left.type.family() == runtime.TypeFamily.BOOLEAN ||
				 _left.type.family() == runtime.TypeFamily.FLAGS) &&
				(_right.type.family() == runtime.TypeFamily.BOOLEAN ||
				 _right.type.family() == runtime.TypeFamily.FLAGS))
				type = compileContext.builtInType(runtime.TypeFamily.BOOLEAN);
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
				case	STRING16:
				case	SUBSTRING:
				case	SUBSTRING16:
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
			type = compileContext.builtInType(runtime.TypeFamily.VOID);
			break;

		case	CASE:
			compileContext.assignTypes(_right);
			type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
			if (_right.type.family() != runtime.TypeFamily.BOOLEAN &&
				_right.type.family() != runtime.TypeFamily.FLAGS) {
				_right.add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			}
			type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
			if (_left.type.family() != runtime.TypeFamily.BOOLEAN &&
				_left.type.family() != runtime.TypeFamily.FLAGS) {
				_left.add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			}
			type = compileContext.builtInType(runtime.TypeFamily.VOID);
			break;
		}
	}

	public void assignCaseExpression(ref<Type> switchType, ref<CompileContext> compileContext) {
		if (_left.isConstant()) {
			if (_left.type.equals(switchType))
				return;
			ref<SyntaxTree> tree = compileContext.current().unit().tree();
			switch (switchType.family()) {
			case SIGNED_8:
			case UNSIGNED_8:
			case SIGNED_16:
			case UNSIGNED_16:
				switchType = compileContext.builtInType(runtime.TypeFamily.SIGNED_32);
			}
			if (_left.canCoerce(switchType, false, compileContext))
				_left = tree.newCast(switchType, _left);
			else {
				_left.add(MessageId.CANNOT_CONVERT, compileContext.pool());
				type = compileContext.errorType();
			}
		} else {
			_left.add(MessageId.NOT_CONSTANT, compileContext.pool());
			type = compileContext.errorType();
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
			_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.VAR, false, compileContext);
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
			_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_32, false, compileContext);
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
			_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.VAR, false, compileContext);
			if (_right.deferAnalysis()) {
				type = _right.type;
				return false;
			}
			return true;

		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	SIGNED_16:
			_left = _left.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_32, false, compileContext);
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
			_right = _right.coerce(compileContext.tree(), runtime.TypeFamily.SIGNED_32, false, compileContext);
			break;

		case	VAR:
			_left = _left.coerce(compileContext.tree(), runtime.TypeFamily.VAR, false, compileContext);
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
			ref<Reference> r = tree.newReference(variable, false, addNode.location());				
			ref<Node> appender = appendString(r, addNode, tree, compileContext);
			ref<Node> seq = tree.newBinary(Operator.SEQUENCE, leftHandle, appender, addNode.location());
			seq.type = compileContext.builtInType(runtime.TypeFamily.VOID);
			return seq, variable;
		} else {
			variable = compileContext.newVariable(addNode.type);
			ref<Reference> r = tree.newReference(variable, true, addNode.location());
			compileContext.markLiveSymbol(r);
			ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, addNode.location());
			adr.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
			ref<OverloadInstance> constructor = addNode.type.initialConstructor();
			assert(constructor != null);
			ref<NodeList> args = tree.newNodeList(addNode);
			ref<Call> call = tree.newCall(constructor.parameterScope(), CallCategory.CONSTRUCTOR, adr, args, addNode.location(), compileContext);
			call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
			return call, variable;
		}
	}
}

private ref<Node> foldStringAppend(ref<Binary> node, ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
	ref<Node> addTree = addOperand(node.right());
	if (addTree == null)			// There's no string additions on the right, just append to the left.
		return appendString(node.left(), node.right(), tree, compileContext);

	ref<Node> lhs, leftHandle;
	if (node.left().isSimpleLvalue()) {
		lhs = node.left();
		leftHandle = null;
	} else {
		ref<Variable> variable = compileContext.newVariable(node.type);
		ref<Reference> r = tree.newReference(variable, true, node.location());
		ref<Node> adr = tree.newUnary(Operator.ADDRESS, node.left(), node.location());
		adr.type = r.type;
		leftHandle = tree.newBinary(Operator.ASSIGN, r, adr, node.location());
		leftHandle.type = r.type;
		lhs = tree.newReference(variable, false, node.location());				
	}
	ref<Node> n = foldAddOperands(lhs, leftHandle, addTree, tree, compileContext); 
	if (!voidContext) {
		n = tree.newBinary(Operator.SEQUENCE, n, lhs, node.location());
		n.type = lhs.type;
	}
	return n;
}

private ref<Node> foldAddOperands(ref<Node> lvalue, ref<Node> leftHandle, ref<Node> addNode, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
	if (addNode.op() == Operator.ADD) {
		ref<Binary> b = ref<Binary>(addNode);
		leftHandle = foldAddOperands(lvalue, leftHandle, b.left(), tree, compileContext);
		leftHandle = foldAddOperands(lvalue, leftHandle, b.right(), tree, compileContext);
		return leftHandle;
	} else {
		ref<Node> bare = unconvertedString(addNode);
		if (bare != null)
			addNode = bare;
		ref<Node> n = appendString(lvalue.clone(tree), addNode, tree, compileContext);
		if (leftHandle != null) {
			leftHandle = tree.newBinary(Operator.SEQUENCE, leftHandle, n, lvalue.location());
			leftHandle.type = n.type;
		} else
			leftHandle = n;
		return leftHandle;
	}
}

private ref<Node> addOperand(ref<Node> rhs) {
	switch (rhs.op()) {
	case CAST:												// The add could have been done 
		return addOperand(ref<Unary>(rhs).operand());

	case ADD:
		return rhs;
	}
	return null;
}

private ref<Node> unconvertedString(ref<Node> rhs) {
	if (rhs.op() == Operator.CAST)												// The add could have been done 
		return unconvertedString(ref<Unary>(rhs).operand());

	if (rhs.type.isString())
		return rhs;
	else
		return null;
}

private ref<Node> appendString(ref<Node> destination, ref<Node> value, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
	substring name("append");
	
	ref<Symbol> sym = destination.type.lookup(name, compileContext);
	if (sym == null || sym.class != Overload) {
		destination.add(MessageId.UNDEFINED, compileContext.pool(), name);
		return destination;
	}
	ref<Overload> over = ref<Overload>(sym);
	ref<OverloadInstance> oi = null;
	ref<ParameterScope> scope = null;
	for (int i = 0; i < over.instances().length(); i++) {
		ref<OverloadInstance> noi = (*over.instances())[i];
		scope = noi.parameterScope();
		if (scope.parameters().length() != 1)
			continue;
		if ((*scope.parameters())[0].type() == value.type) {
			oi = noi;
			break;
		}
	}
	if (oi == null) {
		destination.add(MessageId.UNDEFINED, compileContext.pool(), name);
		return destination;
	}
	assert(scope != null);
	ref<Selection> method = tree.newSelection(destination, oi, false, value.location());
	method.type = oi.type();
	ref<NodeList> args = tree.newNodeList(value);
	ref<Call> call = tree.newCall(scope, null, method, args, value.location(), compileContext);
	call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
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
						ref<Type> common = findCommonType(left.type, right.type);
						if (common == null) {
							parent.print(0);
							parent.add(MessageId.TYPE_MISMATCH, compileContext.pool());
							parent.type = compileContext.errorType();
							return false;
						}
						*leftp = left.coerce(compileContext.tree(), common, false, compileContext);
						*rightp = right.coerce(compileContext.tree(), common, false, compileContext);
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
	if ((*rightp).type.family() == runtime.TypeFamily.SHAPE)
		parent.type = (*rightp).type;
	else
		parent.type = (*leftp).type;
	return true;
}

ref<Type> findCommonType(ref<Type> left, ref<Type> right) {
	switch (left.family()) {
	case STRING:
		switch (right.family()) {
		case STRING:
		case STRING16:
		case SUBSTRING16:
			return left;

		case SUBSTRING:
			return right;
		}
		break;

	case STRING16:
		switch (right.family()) {
		case STRING:
		case STRING16:
		case SUBSTRING:
			return left;

		case SUBSTRING16:
			return right;
		}
		break;

	case SUBSTRING:
		switch (right.family()) {
		case STRING:
		case SUBSTRING:
			return left;

		case STRING16:
			return right;
		}
		break;

	case SUBSTRING16:
		switch (right.family()) {
		case STRING:
			return right;

		case STRING16:
		case SUBSTRING16:
			return left;
		}
	}
	return null;
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
			if (id.symbol().enclosing().inSwitch()) {
				if (id.symbol().initializedWithConstructor())
					compileContext.markLiveSymbol(id);
			} else
				compileContext.markLiveSymbol(id);
		}
		break;
		
	case	INITIALIZE_WRAPPER:
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
		
	case	ENUM:
		compileContext.markLiveSymbol(declarator);
		break;

	case	CLASS_CLEAR:
	case	ASSIGN:
	case	DESTRUCTOR_LIST:
	case	EMPTY:
	case	SYNTAX_ERROR:
	case	INTERNAL_LITERAL:
	case	ARRAY_AGGREGATE:
		break;
		
	default:
		declarator.print(0);
		assert(false);
	}
}

ref<OverloadInstance> getMethodSymbol(ref<Node> parent, string name, ref<Type> type, ref<CompileContext> compileContext) {
	ref<Symbol> sym = type.lookup(name, compileContext);
	if (sym == null || sym.class != Overload) {
		parent.add(MessageId.UNDEFINED, compileContext.pool(), name);
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
	int constantIndex = int(constant.symbol().offset);
	int targetIndex = int(target.sectionType());
	
	switch (op) {
	case EQUALITY:
		return constantIndex == targetIndex;
		
	case NOT_EQUAL:
		return constantIndex != targetIndex;
	}
	return false;
}
