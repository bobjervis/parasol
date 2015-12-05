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
			case	STRING:
			case	UNSIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "integerValue", tree, compileContext);
					return call.fold(tree, false, compileContext);
				}
				break;
				
			case	FLOAT_32:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "floatValue", tree, compileContext);
					call.type = compileContext.arena().builtInType(TypeFamily.FLOAT_64);
					_operand = call.fold(tree, false, compileContext);
					return this;
				}
				break;
				
			case	FLOAT_64:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "floatValue", tree, compileContext);
					return call.fold(tree, false, compileContext);
				}
				break;
				
			case	REF:
			case	POINTER:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "integerValue", tree, compileContext);
					return call.fold(tree, false, compileContext);
				}
				break;

			case	CLASS:
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
					
				case	REF:
				case	POINTER:
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
							ref<Call> constructor = tree.newCall(oi, CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
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

				case	STRING:
					targetType = compileContext.arena().builtInType(TypeFamily.STRING);
					break;
					
				case	ENUM:
					print(0);
					assert(false);

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
						ref<Call> constructor = tree.newCall(oi, CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
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
					ref<Call> call = tree.newCall(oi, null,  method, args, location(), compileContext);
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
			
		case	ADD_REDUCE:
			return reduce(op(), tree, _operand, compileContext);
			
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
		add(MessageId.UNFINISHED_GENERATE, compileContext.pool(), CompileString(" "/*this.class.name()*/), CompileString(string(op())), CompileString("Unary.foldInt"));
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

		case	ADD_REDUCE:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				break;
			}
			if (_operand.type.family() != TypeFamily.SHAPE) {
				add(OperatorMap.typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
				break;
			}
			type = _operand.type.scalarType(compileContext);
			switch (type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
				break;

			default:
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
			switch (_operand.type.scalarFamily(compileContext)) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
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
			switch (_operand.type.scalarFamily(compileContext)) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
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
			if (_operand.type.scalarFamily(compileContext) != TypeFamily.BOOLEAN) {
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
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FLOAT_32:
			case	FLOAT_64:
			case	POINTER:
				break;

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
			case	REF:
			case	POINTER:
			case	SHAPE:
			case	CLASS:
			case	VAR:
				type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
				break;

			default:
				print(4);
				assert(false);
				break;
			}
			break;

		case	UNWRAP_TYPEDEF:
			type = _operand.unwrapTypedef(compileContext);
			break;
		}
	}
}
