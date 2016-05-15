/*
   Copyright 2015 Rovert Jervis

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, softwareL404
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */
namespace parasol:compiler;

enum CallCategory {
	ERROR,
	COERCION,
	CONSTRUCTOR,
	DESTRUCTOR,
	FUNCTION_CALL,
	METHOD_CALL,
}

class Call extends ParameterBag {
	// Populated at parse time:
	private ref<Node> _target;						// the 'function' being called
													//   COERCION: the type expression of the new type
													//   CONSTRUCTOR: the type expression of the object type
													//	 FUNCTION_CALL: the function or function object being called
													//   METHOD_CALL, VIRTUAL_NETHOD_CALL: the simple identifier or object.method being called
	// Populated at type analysis:					
	private CallCategory _category;					// what kind of call it turned out to be after type analysis
	private ref<ParameterScope> _overload;			// For CONSTRUCTOR, some FUNCTION_CALL, METHOD_CALL and VIRTUAL_METHOD_CALL: 
													//   The scope of the overload being called.
	
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
	
	Call(ref<ParameterScope> overload, CallCategory category, ref<Node> target, ref<NodeList> arguments, Location location, ref<CompileContext> compileContext) {
		super(Operator.CALL, arguments, location);
		_target = target;
		_overload = overload;
		if (category != null)
			_category = category;
		else if (overload == null)
			_category = CallCategory.ERROR;
		else if (overload.enclosing().storageClass() == StorageClass.MEMBER)
			_category = CallCategory.METHOD_CALL;
		else
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
					compileContext.markLiveSymbol(thisParameter);
					thisParameter = tree.newUnary(Operator.ADDRESS, thisParameter, location());
					thisParameter.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
//					ref<Node> n = tree.newStackArgumentAddress(0, location());
//					n.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
//					thisParameter = n;
					nodeFlags |= PUSH_OUT_PARAMETER;
					result = encapsulateCallInTemp(temp, tree);
				}
				break;

			case	DESTRUCTOR:
				if (_overload == null) {
					print(0);
					assert(false);
				}
				thisParameter = _target;
				break;

			case	METHOD_CALL:
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
							compileContext.markLiveSymbol(r);
							ref<Node> defn = tree.newBinary(Operator.INITIALIZE, r, dot.left(), dot.left().location());
							defn.type = dot.left().type;
							r = tree.newReference(temp, false, dot.left().location());
							ref<Unary> adr = tree.newUnary(Operator.ADDRESS, r, dot.left().location());
							adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
							ref<Node> pair = tree.newBinary(Operator.SEQUENCE, defn.fold(tree, true, compileContext), adr, dot.left().location());
							pair.type = defn.type;
							_target = tree.newSelection(pair, dot.symbol(), false, dot.location());
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
					nodeFlags |= PUSH_OUT_PARAMETER;
					result = encapsulateCallInTemp(temp, tree);
				}
			}
			// Now promote the 'hidden' parameters, so code gen is simpler.
			int registerArgumentIndex = 0;
			if (thisParameter != null) {
				thisParameter.register = compileContext.target.registerValue(registerArgumentIndex, TypeFamily.ADDRESS);
				if (thisParameter.register == 0) {
					printf("---\n");
					print(0);
					assert(thisParameter.register != 0);
				}
				registerArgumentIndex++;
			}
			if (outParameter != null) {
				outParameter = tree.newUnary(Operator.ADDRESS, outParameter, outParameter.location());
				outParameter.register = compileContext.target.registerValue(registerArgumentIndex, TypeFamily.ADDRESS);
				outParameter.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
				registerArgumentIndex++;
			}
			int floatingArgumentIndex = 0;
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
					byte nextReg = compileContext.target.registerValue(registerArgumentIndex, args.node.type.family());
					
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
		case	ARRAY_AGGREGATE:
			for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
				nl.node = nl.node.fold(tree, false, compileContext);
			if (_target != null)
				_target = _target.fold(tree, false, compileContext);
			break;
			
		case	OBJECT_AGGREGATE:
			ref<Variable> temp = compileContext.newVariable(type);
			result = null;
			ref<ParameterScope> constructor = type.defaultConstructor();
			if (constructor != null) {
				ref<Reference> r = tree.newReference(temp, true, location());
				ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, location());
				adr.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
				ref<Call> call = tree.newCall(constructor, CallCategory.CONSTRUCTOR, adr, null, location(), compileContext);
				call.type = compileContext.arena().builtInType(TypeFamily.VOID);
				result = call.fold(tree, true, compileContext);
			}
			for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
				ref<Binary> b = ref<Binary>(nl.node);		// We know this must be a LABEL node.
				ref<Identifier> id = ref<Identifier>(b.left());	// and the left is an identifier.
				ref<Node> value = b.right();
				ref<Symbol> sym = id.symbol();
				ref<Reference> r = tree.newReference(temp, false, nl.node.location());
				ref<Selection> member = tree.newSelection(r, sym, false, nl.node.location());
				member.type = sym.type();
				value = value.coerce(tree, member.type, false, compileContext);
				ref<Binary> init = tree.newBinary(Operator.ASSIGN, member, value.fold(tree, false, compileContext), nl.node.location());
				init.type = member.type;
				if (result != null) {
					result = tree.newBinary(Operator.SEQUENCE, result, init, location());
					result.type = init.type;
				} else
					result = init;
			}
			if (result == null)
				return tree.newReference(temp, false, location());
			else {
				ref<Reference> r = tree.newReference(temp, false, location());
				result = tree.newBinary(Operator.SEQUENCE, result, r, location());
				result.type = r.type;
				return result;
			}
			
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
		call._folded = _folded;
		return call;
	}

	public ref<Call> cloneRaw(ref<SyntaxTree> tree) {
		ref<Node> target = _target != null ? _target.cloneRaw(tree) : null;
		ref<NodeList> arguments  = _arguments != null ? _arguments.cloneRaw(tree) : null;
		return tree.newCall(op(), target, arguments, location());
	}

	public ref<ParameterScope> overload() {
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
		printf(" %s reg args %d stack args %d %s\n", string(_category), args, stackArgs, _folded ? "folded" : "");
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

	public void assignArrayAggregateTypes(ref<EnumInstanceType> enumType, long maximumIndex, ref<CompileContext> compileContext) {
		if (assignArguments(LabelStatus.OPTIONAL_LABELS, enumType, maximumIndex, compileContext)) {
			ref<Type> indexType = null;
			boolean indexTypeValid = true;
			boolean anyUnlabeled = false;
			ref<Type> scalarType = null;
			if (_arguments != null) {
				scalarType = _arguments.node.type;
				if (_arguments.node.op() == Operator.LABEL) {
					indexType = ref<Binary>(_arguments.node).left().type;
					indexTypeValid = indexType != null;
				} else
					anyUnlabeled = true;
				for (ref<NodeList> nl = _arguments; nl.next != null; nl = nl.next) {
					scalarType = findCommonType(scalarType, nl.next.node.type, compileContext);
					if (scalarType == null) {
						nl.next.node.add(MessageId.TYPE_MISMATCH, compileContext.pool());
						nl.next.node.type = compileContext.errorType();
						break;
					}
					if (indexType != null && nl.next.node.op() == Operator.LABEL) {
						ref<Binary> b = ref<Binary>(nl.next.node);
						indexType = findCommonType(indexType, b.left().type, compileContext);
						if (indexType == null) {
							indexTypeValid = false;
							b.left().add(MessageId.TYPE_MISMATCH, compileContext.pool());
							b.left().type = compileContext.errorType();
						}
					} else
						anyUnlabeled = true;
				}
				if (scalarType == null || !indexTypeValid) {
					type = compileContext.errorType();
					return;
				}
				if (indexType != null) {
					boolean anyFailed = false;
					if (!indexType.isCompactIndexType()) {
						for (ref<NodeList> nl = _arguments; nl.next != null; nl = nl.next) {
							if (nl.node.op() != Operator.LABEL) {
								nl.node.add(MessageId.LABEL_MISSING, compileContext.pool());
								nl.node.type = compileContext.errorType();
								anyFailed = true;
							}
						}
					}
					if (anyFailed) {
						type = compileContext.errorType();
						return;
					}
				}
				for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
					if (scalarType != nl.node.type)
						nl.node = nl.node.coerce(compileContext.tree(), scalarType, false, compileContext);
			}
			if (scalarType != null) {
				if (indexType == null)
					indexType = compileContext.arena().builtInType(TypeFamily.SIGNED_32);
				type = compileContext.arena().buildVectorType(scalarType, indexType, compileContext);
			} else // This is the class-less empty array initializer [ ]
				type = compileContext.arena().builtInType(TypeFamily.ARRAY_AGGREGATE);
		} else
			type = compileContext.errorType();
	}
	
	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	ARRAY_AGGREGATE:
			assignArrayAggregateTypes(null, long.MAX_VALUE, compileContext);
			break;
			
		case	OBJECT_AGGREGATE:
			if (assignArguments(LabelStatus.REQUIRED_LABELS, null, long.MAX_VALUE, compileContext))
				type = compileContext.arena().builtInType(TypeFamily.OBJECT_AGGREGATE);
			else
				type = compileContext.errorType();
			break;
			
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
				ref<Symbol> symbol = _target.symbol();
				if (symbol != null) {
					if (symbol.class != OverloadInstance)
						symbol = null;
					else {
						_overload = ref<OverloadInstance>(symbol).parameterScope();
						if (symbol.storageClass() == StorageClass.MEMBER)
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

	private boolean assignSub(Operator kind, ref<CompileContext> compileContext) {
		if (!assignArguments(LabelStatus.NO_LABELS, null, long.MAX_VALUE, compileContext))
			return false;
		_target.assignOverload(_arguments, kind, compileContext);
		if (_target.deferAnalysis()) {
			type = _target.type;
			return false;
		}
		return true;
	}

	void assignConstructorCall(ref<Type> classType, ref<CompileContext> compileContext) {
		if (!assignArguments(LabelStatus.NO_LABELS, null, long.MAX_VALUE, compileContext))
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
		ref<Symbol> oi;
		(match, oi) = operation.result();
		if (match.deferAnalysis())
			type = match;
		else {
			type = classType;
			if (oi != null)
				_overload = ref<OverloadInstance>(oi).parameterScope();
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

	enum LabelStatus {
		NO_LABELS,
		OPTIONAL_LABELS,
		REQUIRED_LABELS
	}
	
	private class Interval {
		long start;
		long end;
		ref<NodeList> first;
		
		public int compare(Interval i) {
			if (i.start > start)
				return -1;
			else if (i.start < start)
				return 1;
			else
				return 0;
		}
	}
	
	boolean assignArguments(LabelStatus status, ref<EnumInstanceType> enumType, long maximumIndex, ref<CompileContext> compileContext) {
		Interval[] intervals;
		long nextIndex = 0;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			compileContext.assignTypes(nl.node);
			switch (status) {
			case	NO_LABELS:
				if (nl.node.op() == Operator.LABEL) {
					// This path way should not occur, because the parser context should constrain the
					// argument expressions.
					nl.node.print(0);
					assert(false);
					nl.node.add(MessageId.NOT_A_FUNCTION, compileContext.pool());
					nl.node.type = compileContext.errorType();
				}
				break;
				
			case	OPTIONAL_LABELS:		// An array aggregate
				if (nl.node.op() == Operator.LABEL) {
					ref<Binary> b = ref<Binary>(nl.node);
					if (enumType != null) {
						ref<EnumScope> scope = ref<EnumScope>(enumType.scope());
						if (b.left().op() == Operator.IDENTIFIER) {
							ref<Identifier> id = ref<Identifier>(b.left());
							id.resolveAsEnum(enumType, compileContext);
							if (b.left().deferAnalysis()) {
								nl.node.type = compileContext.errorType();
								break;
							}
							int i = scope.indexOf(id.symbol()); 
							Interval in = { start: i, end: i, first: nl };
							intervals.append(in);
						} else {
							b.left().add(MessageId.LABEL_NOT_IDENTIFIER, compileContext.pool());
							b.left().type = compileContext.errorType();
						}
					} else
						compileContext.assignTypes(b.left());
				} else {
					if (intervals.length() == 0) {
						Interval i = { start: 0, end: 0, first: nl };
						intervals.append(i);
					} else {
						ref<Interval> i = &intervals[intervals.length() - 1];
						if (i.end < maximumIndex)
							i.end++;
						else {
							nl.node.add(MessageId.INITIALIZER_BEYOND_RANGE, compileContext.pool());
							nl.node.type = compileContext.errorType();
						}
					}
				}
				break;

			case	REQUIRED_LABELS:
				if (nl.node.op() == Operator.LABEL) {
					ref<Binary> b = ref<Binary>(nl.node);
					if (b.left().op() != Operator.IDENTIFIER) {
						nl.node.add(MessageId.LABEL_NOT_IDENTIFIER, compileContext.pool());
						nl.node.type = compileContext.errorType();
					}
				} else {
					nl.node.add(MessageId.LABEL_REQUIRED, compileContext.pool());
					nl.node.type = compileContext.errorType();
				}
			}
		}
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			if (nl.node.deferAnalysis()) {
				type = nl.node.type;
				return false;
			}
		if (status == LabelStatus.OPTIONAL_LABELS && intervals.length() > 1) {
			intervals.sort();
			for (int i = 1; i < intervals.length(); i++) {
				if (intervals[i - 1].end >= intervals[i].start) {
					intervals[i].first.node.add(MessageId.DUPLICATE_INDEX, compileContext.pool());
					type = compileContext.errorType();
					return false;
				}
			}
		}
		return true;
	}

	ref<Node> rewriteDeclarators(ref<SyntaxTree> syntaxTree) {
		if (op() == Operator.CALL)
			return syntaxTree.newFunction(Function.Category.DECLARATOR, _target, null, _arguments, location());
		else
			return this;
	}

	public boolean canCoerce(ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
		switch (op()) {
		case	ARRAY_AGGREGATE:
			printf("\nnewType: ");
			newType.print();
			printf("\n");
			print(0);
			assert(false);
			break;
			
		case	OBJECT_AGGREGATE:
			switch (newType.family()) {
			case	VAR:
				return true;
				
			case	CLASS:
			case	TEMPLATE_INSTANCE:
				boolean success = true;
				for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
					ref<Binary> b = ref<Binary>(nl.node);		// We know this must be a LABEL node.
					ref<Identifier> id = ref<Identifier>(b.left());	// and the left is an identifier.
					ref<Node> value = b.right();
					ref<Symbol> sym = id.resolveAsMember(newType, compileContext);
					if (sym == null) {
						value.type = compileContext.errorType();
						b.type = value.type;
						success = false;
					} else if (!value.canCoerce(id.type, false, compileContext)) {
						value.add(MessageId.CANNOT_CONVERT, compileContext.pool());
						value.type = compileContext.errorType();
						b.type = value.type;
						success = false;
					}
				}
				return success;

			default:
				return false;
			}
		}
		return super.canCoerce(newType, explicitCast, compileContext);
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
		case	REF:
		case	POINTER:
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
			case	REF:
			case	POINTER:
			case	BOOLEAN:
			case	ENUM:
			case	FUNCTION:
				return true;
			}
			break;
		}
		return false;
	}
	
	CallCategory category() {
		return _category;
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
		printf(" %s %d arguments\n", string(_functionCategory), args);
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
			_name.symbol().bindType(type, compileContext);
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

class DestructorList extends ParameterBag {
	DestructorList(ref<NodeList> destructors, Location location) {
		super(Operator.DESTRUCTOR_LIST, destructors, location);
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
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			break;

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
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			result = func(this, data);
			if (result == TraverseAction.ABORT_TRAVERSAL)
				return false;
			break;

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

	public ref<DestructorList> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return this;
	}
	
	public ref<DestructorList> clone(ref<SyntaxTree> tree) {
		return ref<DestructorList>(tree.newDestructorList(_arguments.clone(tree), location()).finishClone(this, tree.pool()));
	}

	public ref<DestructorList> cloneRaw(ref<SyntaxTree> tree) {
		return tree.newDestructorList(_arguments.cloneRaw(tree), location());
	}

	public void print(int indent) {
		printBasic(indent);
		printf("\n");
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			printf("%*.*c  {Destructor for}\n", indent, indent, ' ');
			nl.node.print(indent + INDENT);
		}
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
	ref<NodeList> _liveSymbols;
	
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

	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			nl.node = nl.node.fold(tree, false, compileContext);
		int n = compileContext.liveSymbolCount();
//		ref<Node> output = this;
		for (int i = 0; i < n; i++) {
			ref<Node> n = compileContext.getLiveSymbol(i);
			// We know that 'live' symbols have a scope with a destructor
			ref<NodeList> nl = tree.newNodeList(n);
			nl.next = _liveSymbols;
			_liveSymbols = nl;
//			ref<Node> thisParameter = tree.newUnary(Operator.ADDRESS, id, id.location());
//			thisParameter.type = compileContext.arena().builtInType(TypeFamily.ADDRESS);
//			ref<Call> c = tree.newCall(destructor, CallCategory.DESTRUCTOR, thisParameter, null, location(), compileContext);
//			c.type = compileContext.arena().builtInType(TypeFamily.VOID);
//			ref<Node> folded = c.fold(tree, true, compileContext);
//			output = tree.newBinary(Operator.SEQUENCE, folded, output, location());
		}
		// Returning a string by value, we have to make a copy.
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			if (nl.node.type == null || nl.node.deferAnalysis())
				continue;
			if ((nl.node.type.family() == TypeFamily.STRING && nl.node.op() != Operator.CALL) ||
				nl.node.type.returnsViaOutParameter(compileContext)) {
				// TODO: Add a check for the return value being one of the live symbols to be destroyed.
				ref<Variable> temp = compileContext.newVariable(nl.node.type);
				ref<Reference> r = tree.newReference(temp, true, nl.node.location());
				ref<Node> defn = tree.newBinary(Operator.ASSIGN, r, nl.node, nl.node.location());
				defn.type = nl.node.type;
				r = tree.newReference(temp, false, nl.node.location());
				nl.node = tree.newBinary(Operator.SEQUENCE, defn.fold(tree, true, compileContext), r, nl.node.location());
				nl.node.type = defn.type;
			}
		}
		return this;
	}
	
	public ref<Return> clone(ref<SyntaxTree> tree) {
		ref<NodeList> arguments = _arguments != null ? _arguments.clone(tree) : null;
		ref<Return> copy = tree.newReturn(arguments, location()); 
		if (_liveSymbols != null)
			copy._liveSymbols = _liveSymbols.clone(tree); 
		return ref<Return>(copy.finishClone(this, tree.pool()));
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
		if (_liveSymbols != null) {
			i = 0;
			printf("%*.*c  Destructors:\n", indent, indent, ' ');
			for (ref<NodeList> nl = _liveSymbols; nl != null; nl = nl.next, i++) {
				printf("%*.*c    {destructor %d}\n", indent, indent, ' ', i);
				nl.node.print(indent + INDENT);
			}
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
	
	ref<NodeList> liveSymbols() {
		return _liveSymbols;
	}
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
		ref<Node> assignment;
		if (r.type.family() == TypeFamily.STRING) {
			ref<OverloadInstance> oi = getMethodSymbol(b.right(), "store", r.type, compileContext);
			if (oi == null) {
				destinations.type = compileContext.errorType();
				return destinations;
			}
			// This is the assignment method for this class!!!
			// (all strings go through here).
			ref<Selection> method = tree.newSelection(b.right(), oi, false, destinations.location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(r);
			ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, destinations.location(), compileContext);
			call.type = compileContext.arena().builtInType(TypeFamily.VOID);
			assignment = call.fold(tree, true, compileContext);
		} else {
			assignment = tree.newBinary(Operator.ASSIGN, b.right(), r, destinations.location());
			assignment.type = r.type;
			assignment = assignment.fold(tree, true, compileContext);
		}
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

