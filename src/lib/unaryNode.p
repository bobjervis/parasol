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

public class Unary extends Node {
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
		case	UNWRAP_TYPEDEF:
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
		if (voidContext) {
			switch (op()) {
			case	ADDRESS:
			case	NEGATE:
			case	CAST:
				return _operand.fold(tree, true, compileContext);
			}
		}
		switch (op()) {
		case	DECLARE_NAMESPACE:
			// No need to do anything for these sub-trees.
			return this;
			
		case	PUBLIC:
		case	PRIVATE:
		case	PROTECTED:
		case	FINAL:
		case	STATIC:
		case	ELLIPSIS:
		case	UNWRAP_TYPEDEF:
		case	VECTOR_OF:
		case	ABSTRACT:
		case	DEFAULT:

		case	UNARY_PLUS:
		case	DECREMENT_BEFORE:
		case	INCREMENT_BEFORE:
		case	DECREMENT_AFTER:
		case	INCREMENT_AFTER:
		case	NOT:
		case	INDIRECT:
		case	BYTES:
		case	LOAD:
		case	STORE_V_TABLE:
			break;

		case	CLASS_OF:
			if (_operand.type.indirectType(compileContext) == null) {
				if (_operand.type.hasVtable(compileContext)) {
					ref<Type> type = compileContext.arena().createRef(_operand.type, compileContext);
					_operand = tree.newUnary(Operator.ADDRESS, _operand, _operand.location());
					_operand.type = type;
					return this;
				} else if (_operand.op() == Operator.SUBSCRIPT && _operand.type.family() == TypeFamily.VAR) {
					ref<Type> type = compileContext.arena().createRef(_operand.type, compileContext);
					_operand = tree.newUnary(Operator.ADDRESS, _operand, _operand.location());
					_operand.type = type;					
				}
			}
			break;

		case	NEGATE:
			_operand = _operand.fold(tree, false, compileContext);
			switch (_operand.op()) {
			case INTERNAL_LITERAL:
				ref<InternalLiteral>(_operand).negate();
				return _operand;

			case INTEGER:
				ref<InternalLiteral> n = tree.newInternalLiteral(-ref<Constant>(_operand).intValue(), location());
				n.type = type;
				return n;

//			case FLOATING_POINT:
			}
			return this;

		case	BIT_COMPLEMENT:
			if (type.family() == TypeFamily.FLAGS) {
				int numberOfFlags = type.scope().symbols().size();
				switch (numberOfFlags) {
				case 8:
				case 16:
				case 32:
				case 64:
					break;
					
				default:		// This is a flag object with spare bits in the container, you can't let those bits
								// pollute the downstream value (a test for zero/non-zero is far more likely to be
								// done, instead of bit complement, so make bit complemennt a tiny bit slower). You can
								// always pad the definition if you are that concerned about the cost.
					long mask = (long(1) << numberOfFlags) - 1;
					ref<Node> m = tree.newConstant(mask, location());
					m.type = type;
					m = tree.newBinary(Operator.EXCLUSIVE_OR, _operand.fold(tree, false, compileContext), m, location());
					m.type = type;
					return m;
				}
			}
			break;

		case	ELLIPSIS_ARGUMENT:
			if (_operand.op() == Operator.CAST && type.family() == TypeFamily.VAR)
				_operand = ref<Unary>(_operand).foldCastToVar(true, tree, compileContext);
			else
				_operand = _operand.fold(tree, false, compileContext);
			break;

		case	CAST:
			switch (_operand.op()) {
			case OBJECT_AGGREGATE:
			case ARRAY_AGGREGATE:
				if (type.family() != TypeFamily.VAR) {
					_operand.type = type;
					return _operand.fold(tree, false, compileContext);
				}
				break;

			default:
				if (_operand.isLvalue() && _operand.type.extendsFormally(type, compileContext)) {
					_operand = _operand.fold(tree, false, compileContext);
					_operand.type = type;
					return _operand;
				}
			}
			switch (type.family()) {
			case	STRING:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "stringValue", tree, compileContext);
					return call.fold(tree, false, compileContext);

				case	ADDRESS:
					if (_operand.op() == Operator.NULL) {
						_operand.type = type;
						return _operand;
					}
				}
				return foldCastToConstructor(_operand.type, tree, voidContext, compileContext);
				
			case	STRING16:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "string16Value", tree, compileContext);
					return call.fold(tree, false, compileContext);

				case	ADDRESS:
					if (_operand.op() == Operator.NULL) {
						_operand.type = type;
						return _operand;
					}
				}
				return foldCastToConstructor(_operand.type, tree, voidContext, compileContext);
				
			case	SUBSTRING:
			case	SUBSTRING16:
				return foldCastToConstructor(_operand.type, tree, voidContext, compileContext);

			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	UNSIGNED_64:
			case	SIGNED_8:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "integerValue", tree, compileContext);
					return call.fold(tree, false, compileContext);

				case	BOOLEAN:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
					_operand = _operand.fold(tree, false, compileContext);
					switch (_operand.op()) {
					case INTERNAL_LITERAL:
					case INTEGER:
						long v = _operand.foldInt(compileContext.target, compileContext);
						long vBefore = v;
						if (type.size() < _operand.type.size()) {
							switch (type.family()) {
							case	SIGNED_16:
							case	SIGNED_32:
							case	SIGNED_64:
								int shift = 64 - type.size() * 8;
								v = (v << shift) >> shift;
								break;

							default:
								v &= (long(1) << (type.size() * 8)) - 1;
							}
						}
						if (v == vBefore) {
							_operand.type = type;
							return _operand;
						}
						ref<InternalLiteral> n = tree.newInternalLiteral(v, location());
						n.type = type;
						return n;
					}
				}
				break;
				
			case	FLOAT_32:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "floatValue", tree, compileContext);
					call.type = compileContext.arena().builtInType(TypeFamily.FLOAT_64);
					_operand = call.fold(tree, false, compileContext);
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
			case	ADDRESS:
				switch (_operand.type.family()) {
				case	VAR:
					ref<Node> call = createMethodCall(_operand, "integerValue", tree, compileContext);
					return call.fold(tree, false, compileContext);
				}
				break;

			case	INTERFACE:
				if (_operand.op() != Operator.NULL && _operand.type.indirectType(compileContext) == null) {
					ref<Node> adr = tree.newUnary(Operator.ADDRESS, _operand.fold(tree, false, compileContext), _operand.location());
					adr.type = compileContext.arena().createRef(_operand.type, compileContext);
					_operand = adr;
					return this;
				}
				break;
				
			case	CLASS:
				switch (_operand.type.family()) {
				case	VAR:
					if (type.size() <= 8) {
						ref<Variable> temp = compileContext.newVariable(type);
						ref<Reference> r = tree.newReference(temp, true, location());
						ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, location());
						adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
						ref<Node> opLen = tree.newInternalLiteral(type.size(), location());
						opLen.type = compileContext.arena().builtInType(TypeFamily.SIGNED_32);
						ref<Node> call = createMethodCall(_operand, "classValue", tree, compileContext, adr, opLen);
						if (call == null) {
							substring name("classValue");
							add(MessageId.UNDEFINED, compileContext.pool(), name);
							type = compileContext.errorType();
							return this;
						}
						call.type = compileContext.arena().builtInType(TypeFamily.VOID);
						r = tree.newReference(temp, false, location());
						ref<Binary> seq = tree.newBinary(Operator.SEQUENCE, call, r, location());
						seq.type = type;
						return seq.fold(tree, false, compileContext);
					}

				default:
					print(0);
					assert(false);
				}
				break;

			case	VAR:
				assert(type.scope() != null);
				return foldCastToVar(false, tree, compileContext);
			}
			break;

		case	THROW:
			ref<ParameterScope> tes = compileContext.throwExceptionScope();
			if (tes == null) {
				substring name("throwException");

				add(MessageId.UNDEFINED, compileContext.pool(), name);
				return this;
			}
			ref<Node> f = tree.newLeaf(Operator.FRAME_PTR, location());
			ref<Node> s = tree.newLeaf(Operator.STACK_PTR, location());
			ref<Node> x = tree.newLeaf(Operator.EMPTY, location());
			f.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			s.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			x.type = tes.type;
			ref<Node> excep = _operand;
			if (excep.type.indirectType(compileContext) == null) {
				excep = tree.newUnary(Operator.ADDRESS, _operand, _operand.location());
				excep.type = f.type;
			}
			ref<NodeList> args = tree.newNodeList(excep, f, s);
			ref<Call> call = tree.newCall(tes, null, x, args, location(), compileContext);
			call.type = compileContext.arena().builtInType(TypeFamily.VOID);
			f = tree.newUnary(Operator.EXPRESSION, call, location());
			f.type = call.type;
			return f.fold(tree, voidContext, compileContext);

		case	CALL_DESTRUCTOR:
			_operand = tree.newUnary(Operator.ADDRESS, _operand.fold(tree, false, compileContext), location());
			_operand.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
			return this;
			
		case	ADDRESS_OF_ENUM:
		case	ADDRESS:
			switch (_operand.op()) {
			case SUBSCRIPT:
				ref<Binary> b = ref<Binary>(_operand);
				switch (b.left().type.family()) {
				case STRING:
				case STRING16:
				case SUBSTRING:
				case SUBSTRING16:
				case SHAPE:
					substring name("elementAddress");
					
					ref<Symbol> sym = b.left().type.lookup(name, compileContext);
					if (sym == null || sym.class != Overload) {
						add(MessageId.UNDEFINED, compileContext.pool(), name);
						break;
					}
					ref<OverloadInstance> oi = (*ref<Overload>(sym).instances())[0];
					ref<Selection> method = tree.newSelection(b.left(), oi, false, location());
					method.type = oi.type();
					ref<NodeList> args = tree.newNodeList(b.right());
					ref<Call> call = tree.newCall(oi.parameterScope(), null,  method, args, location(), compileContext);
					call.type = type;
					return call.fold(tree, voidContext, compileContext);
				}
				break;
				
			case DOT:
			case IDENTIFIER:
				if (_operand.symbol() != null && _operand.symbol().storageClass() == StorageClass.ENUMERATION)
					return this;			// Avoid mapping enum constants to INTERNAL_LITERAL when the operand of a 
			}
			break;
			
		case	ADD_REDUCE:
			return reduce(op(), tree, _operand, compileContext);
			
		case	EXPRESSION:
			int liveCount = compileContext.liveSymbolCount();
			_operand = foldVoidContext(_operand, tree, compileContext);
			if (_operand.op() == Operator.IF)
				x = _operand;
			else
				x = this;
			if (compileContext.liveSymbolCount() > liveCount) {
				ref<Node> d = attachLiveTempDestructors(tree, liveCount, compileContext);
				x = tree.newBinary(Operator.SEQUENCE, x, d, x.location());
			}
			return x;
			
		default:
			print(0);
			assert(false);
		}
		_operand = _operand.fold(tree, false, compileContext);
		return this;
	}

	private ref<Node> foldCastToVar(boolean ellipsisArgument, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		switch (_operand.type.family()) {
		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	UNSIGNED_64:
		case	SIGNED_8:
		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
			return foldCastToConstructor(compileContext.arena().builtInType(TypeFamily.SIGNED_64), tree, false, compileContext);
					
		case	BOOLEAN:
			return foldCastToConstructor(compileContext.arena().builtInType(TypeFamily.BOOLEAN), tree, false, compileContext);
					
		case	FLOAT_32:
		case	FLOAT_64:
			return foldCastToConstructor(compileContext.arena().builtInType(TypeFamily.FLOAT_64), tree, false, compileContext);
					
		case	ADDRESS:
		case	INTERFACE:
			return foldCastToConstructor(compileContext.arena().builtInType(TypeFamily.ADDRESS), tree, false, compileContext);

		case	OBJECT_AGGREGATE:
		case	ARRAY_AGGREGATE:
			_operand.type = compileContext.arena().createRef(_operand.type.classType(), compileContext);	
		case	REF:
		case	POINTER:
			for (int i = 0; i < type.scope().constructors().length(); i++) {
				ref<FunctionDeclaration> f = ref<FunctionDeclaration>((*type.scope().constructors())[i].definition());
				ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
				if (oi.parameterCount() != 2)
					continue;
				if ((*oi.parameterScope().parameters())[0].type().family() == TypeFamily.ADDRESS &&
						(*oi.parameterScope().parameters())[1].type().family() == TypeFamily.SIGNED_64) {
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
					ref<Call> constructor = tree.newCall(oi.parameterScope(), CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
					constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
					r = tree.newReference(temp, false, location());
					ref<Binary> seq = tree.newBinary(Operator.SEQUENCE, constructor, r, location());
					seq.type = type;
					return seq.fold(tree, false, compileContext);
				}
			}

		case	STRING:
		case	STRING16:
			if (ellipsisArgument) {
				substring ename;

				if (_operand.type.family() == TypeFamily.STRING)
					ename = "stringEllip";
				else
					ename = "string16Ellip";
				ref<Reference> r = tree.newEllipsisReference(type, location());
				ref<Node> call = createMethodCall(r, ename, tree, compileContext, _operand);
				if (call == null) {
					type = compileContext.errorType();
					return this;
				}
				call.type = compileContext.arena().builtInType(TypeFamily.VOID);
				return call.fold(tree, false, compileContext);
			}
			return foldCastToConstructor(_operand.type, tree, false, compileContext);

		case	SUBSTRING:
		case	SUBSTRING16:
			if (ellipsisArgument) {
				substring ename;

				ref<Node> cast;
				if (_operand.type.family() == TypeFamily.SUBSTRING) {
					ename = "stringEllip";
					cast = tree.newCast(compileContext.arena().builtInType(TypeFamily.STRING), _operand);
				} else {
					ename = "string16Ellip";
					cast = tree.newCast(compileContext.arena().builtInType(TypeFamily.STRING16), _operand);
				}
				ref<Reference> r = tree.newEllipsisReference(type, location());
				ref<Node> call = createMethodCall(r, ename, tree, compileContext, cast);
				call.type = compileContext.arena().builtInType(TypeFamily.VOID);
				return call.fold(tree, false, compileContext);
			}
			return foldCastToConstructor(_operand.type, tree, false, compileContext);
					
		case	CLASS:
			// TODO: Make this more friendly for cross-compilation scenarios
			if (_operand.type.size() <= address.bytes) {
				for (int i = 0; i < type.scope().constructors().length(); i++) {
					ref<FunctionDeclaration> f = ref<FunctionDeclaration>((*type.scope().constructors())[i].definition());
					ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
					if (oi.parameterCount() != 3)
						continue;
					if ((*oi.parameterScope().parameters())[0].type().family() == TypeFamily.ADDRESS &&
						(*oi.parameterScope().parameters())[1].type().family() == TypeFamily.ADDRESS &&
						(*oi.parameterScope().parameters())[2].type().family() == TypeFamily.SIGNED_32) {
						ref<Variable> temp = compileContext.newVariable(type);
						_operand = _operand.fold(tree, false, compileContext);
						ref<Node> empty = tree.newLeaf(Operator.EMPTY, location());
						empty.type = _operand.type;
						ref<Node> typeOperand = tree.newUnary(Operator.CLASS_OF, empty, location());
						// The type of the CLASS_OF operand is irrelevant.
						typeOperand.type = compileContext.arena().builtInType(TypeFamily.VOID);
						ref<Node> opAdr = tree.newUnary(Operator.ADDRESS, _operand, location());
						opAdr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
						ref<Node> opLen = tree.newInternalLiteral(_operand.type.size(), location());
						opLen.type = compileContext.arena().builtInType(TypeFamily.SIGNED_32);
						ref<NodeList> args = tree.newNodeList(typeOperand, opAdr, opLen);
						ref<Reference> r = tree.newReference(temp, true, location());
						ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, location());
						adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
						ref<Call> constructor = tree.newCall(oi.parameterScope(), CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
						constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
						r = tree.newReference(temp, false, location());
						ref<Binary> seq = tree.newBinary(Operator.SEQUENCE, constructor, r, location());
						seq.type = type;
						return seq.fold(tree, false, compileContext);
					}
				}
			}

		case	ENUM:
		case	FLAGS:
			add(MessageId.UNFINISHED_VAR_CAST, compileContext.pool(), _operand.type.signature());
			break;

		default:
			print(0);
			assert(false);
		}
		return this;
	}

	private ref<Node> foldCastToConstructor(ref<Type> argumentType, ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		// As a special case, let the constant null cast to a constructor for any string type, but just
		// make sure the constructor you pick is the 'stringNN' constructor (they'll all have one and it's
		// as efficient as any other.
		switch (type.family()) {
		case STRING:
		case SUBSTRING:
			if (_operand.op() == Operator.NULL)
				_operand.type = argumentType = compileContext.arena().builtInType(TypeFamily.STRING);
			break;

		case STRING16:
		case SUBSTRING16:
			if (_operand.op() == Operator.NULL)
				_operand.type = argumentType = compileContext.arena().builtInType(TypeFamily.STRING16);
		}

		for (int i = 0; i < type.scope().constructors().length(); i++) {
			ref<FunctionDeclaration> f = ref<FunctionDeclaration>((*type.scope().constructors())[i].definition());
			ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
			if (oi.parameterCount() != 1)
				continue;
			if ((*oi.parameterScope().parameters())[0].type() == argumentType) {
				ref<Variable> temp = compileContext.newVariable(type);
				_operand = _operand.fold(tree, false, compileContext);
				if (_operand.type != argumentType)
					_operand = tree.newCast(argumentType, _operand);
				ref<NodeList> args = tree.newNodeList(_operand);
				ref<Reference> r = tree.newReference(temp, true, location());
				compileContext.markLiveSymbol(r);
//				printf("@%s:\n", tree.sourceLine(_operand.location()));
//				print(4);
//				for (int i = 0; i < compileContext.liveSymbolCount(); i++)
//					compileContext.getLiveSymbol(i).print(4);
				ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, location());
				adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
				ref<Call> constructor = tree.newCall(oi.parameterScope(), CallCategory.CONSTRUCTOR, adr, args, location(), compileContext);
				constructor.type = compileContext.arena().builtInType(TypeFamily.VOID);
				if (voidContext)
					return constructor.fold(tree, true, compileContext);
				r = tree.newReference(temp, false, location());
				ref<Binary> seq = tree.newBinary(Operator.SEQUENCE, constructor, r, location());
				seq.type = type;
				return seq.fold(tree, false, compileContext);
			}
		}
		_operand = _operand.fold(tree, false, compileContext);
		return this;
	}

	public ref<Node> foldConditional(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		if (op() == Operator.NOT) {
			_operand = _operand.foldConditional(tree, compileContext);
			return this;
		}
		return super.foldConditional(tree, compileContext);
	}

	public void checkCompileTimeConstant(long minimumIndex, long maximumIndex, ref<CompileContext> compileContext) {
		if (deferAnalysis())
			return;
		switch (op()) {
		case	NEGATE:
			_operand.checkCompileTimeConstant(-maximumIndex, -minimumIndex, compileContext);
			break;

		case	CAST:
			switch (type.family()) {
			case	UNSIGNED_8:
				if (maximumIndex >= byte.MAX_VALUE && minimumIndex <= 0)
					return;
				break;

			case	SIGNED_32:
				if (maximumIndex >= int.MAX_VALUE && minimumIndex <= int.MIN_VALUE)
					return;
				break;
				
			case	SIGNED_64:
				break;

			default:
				print(0);
				assert(false);
			}
			_operand.checkCompileTimeConstant(minimumIndex, maximumIndex, compileContext);
			break;
		}
		if (_operand.deferAnalysis())
			type = _operand.type;
	}

	public long foldInt(ref<Target> target, ref<CompileContext> compileContext) {
		switch (op()) {
		case	NEGATE:
			return -_operand.foldInt(target, compileContext);
			
		case	CAST:
			long v = _operand.foldInt(target, compileContext);
			switch (type.family()) {
			case	UNSIGNED_8:
				return v & 0xff;

			case	SIGNED_32:
				return (v << 32) >> 32;

			case	SIGNED_64:
				return v;
				
			default:
				print(0);
				assert(false);
			}
			break;
			
		case	BYTES:
			ref<Type> t = _operand.type;
			if (t.family() == TypeFamily.TYPEDEF) {
				ref<TypedefType> tt = ref<TypedefType>(t);
				t = tt.wrappedType();
			}
			t.assignSize(target, compileContext);
			return t.size();
		}
		printf("-----  generate %s ---------\n", compileContext.current().sourceLocation(location()));
		print(0);
		assert(false);
		return 0;
	}

	public boolean isConstant() {
		switch (op()) {
		case	NEGATE:
			return _operand.isConstant();
			
		case	CAST:
			if (!_operand.isConstant())
				return false;
			switch (type.family()) {
			case	SIGNED_16:
			case	SIGNED_64:
				return true;
				
			default:
				break;
			}
			break;
			
		case	BYTES:
			return true;
		}
		return false;
	}
	
	public void print(int indent) {
		printBasic(indent);
		printf("\n");
		_operand.print(indent + INDENT);
	}

	public ref<Node> operand() {
		return _operand; 
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	ABSTRACT:
		case	PRIVATE:
		case	PROTECTED:
		case	PUBLIC:
		case	FINAL:
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
				add(typeNotAllowed[op()], compileContext.pool());
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
				add(typeNotAllowed[op()], compileContext.pool());
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
				add(typeNotAllowed[op()], compileContext.pool());
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
				add(typeNotAllowed[op()], compileContext.pool());
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
			case	FLAGS:
				type = _operand.type;
				break;

			default:
				add(typeNotAllowed[op()], compileContext.pool());
				type = compileContext.errorType();
			}
			break;

		case	NOT:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				break;
			}
			if (_operand.type.scalarFamily(compileContext) != TypeFamily.BOOLEAN &&
				_operand.type.scalarFamily(compileContext) != TypeFamily.FLAGS) {
				add(MessageId.NOT_BOOLEAN, compileContext.pool());
				type = compileContext.errorType();
			} else {
				if (_operand.type == _operand.type.scalarType(compileContext))
					type = compileContext.arena().builtInType(TypeFamily.BOOLEAN);
				else
					type = _operand.type;
			}
			break;

		case	VECTOR_OF:{
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				return;
			}
			ref<Type> vectorType = compileContext.arena().buildVectorType(_operand.unwrapTypedef(Operator.CLASS, compileContext), null, compileContext);
			type = compileContext.makeTypedef(vectorType);
			break;
		}
		
		case	ELLIPSIS:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				break;
			}
			ref<Type> vectorType = compileContext.arena().buildVectorType(_operand.unwrapTypedef(Operator.CLASS, compileContext), null, compileContext);
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

		case	CALL_DESTRUCTOR:
			compileContext.assignTypes(_operand);
			if (_operand.deferAnalysis()) {
				type = _operand.type;
				break;
			}
			type = compileContext.arena().builtInType(TypeFamily.VOID);
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
			case	STRING:
			case	ADDRESS:
				type = compileContext.arena().builtInType(TypeFamily.CLASS_VARIABLE);
				break;

			default:
				print(4);
				assert(false);
				break;
			}
			break;

		case	UNWRAP_TYPEDEF:
			type = _operand.unwrapTypedef(Operator.EXPRESSION, compileContext);
			break;
			
		case	THROW:
			compileContext.assignTypes(_operand);
			type = _operand.type;
			if (_operand.deferAnalysis())
				break;
			if (!_operand.canCoerce(compileContext.arena().builtInType(TypeFamily.EXCEPTION), false, compileContext)) {
				ref<Type> t = _operand.type.indirectType(compileContext); 
				if (t == null || 
					!t.widensTo(compileContext.arena().builtInType(TypeFamily.EXCEPTION), compileContext)) {
					add(MessageId.NOT_AN_EXCEPTION, compileContext.pool());
					type = compileContext.errorType();
				}
			}
			break;
			
		default:
			print(0);
			assert(false);
		}
	}

	public Test fallsThrough() {
		if (op() == Operator.THROW)
			return Test.FAIL_TEST;
		else
			return Test.PASS_TEST;
	}

}
