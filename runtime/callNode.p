/*
   Copyright 2015 Robert Jervis

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

import parasol:math;
import parasol:process;
import parasol:runtime;

public enum CallCategory {
	ERROR,
	COERCION,
	CONSTRUCTOR,
	DESTRUCTOR,
	FUNCTION_CALL,
	METHOD_CALL,
	DECLARATOR,			// type1(type2, type3, ...) ,_ if all expressions have 'class' type, then this must be a function type
}

public class Call extends ParameterBag {
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
	
	Call(Operator op, ref<Node> target, ref<NodeList> arguments, runtime.SourceOffset location) {
		super(op, arguments, location);
		_target = target;
		_category = CallCategory.ERROR;
	}
	
	Call(ref<ParameterScope> overload, CallCategory category, ref<Node> target, ref<NodeList> arguments, runtime.SourceOffset location, ref<CompileContext> compileContext) {
		super(Operator.CALL, arguments, location);
		_target = target;
		_overload = overload;
		if (category != null)
			_category = category;
		else if (overload == null)
			_category = CallCategory.ERROR;
		else if (overload.enclosing().storageClass() == StorageClass.MEMBER || 
				 overload.enclosing().storageClass() == StorageClass.LOCK)
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
			if (_stackArguments != null && !_stackArguments.traverse(t, func, data))
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
			if (_stackArguments != null && !_stackArguments.traverse(t, func, data))
				return false;
			break;

		case	POST_ORDER:
			if (_target != null && !_target.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.traverse(t, func, data))
				return false;
			if (_stackArguments != null && !_stackArguments.traverse(t, func, data))
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
			if (_stackArguments != null && !_stackArguments.traverse(t, func, data))
				return false;
			if (_arguments != null && !_arguments.reverse(t, func, data))
				return false;
			if (_target != null && !_target.traverse(t, func, data))
				return false;
			break;

		case	REVERSE_IN_ORDER:
			if (_stackArguments != null && !_stackArguments.traverse(t, func, data))
				return false;
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
			if (_stackArguments != null && !_stackArguments.traverse(t, func, data))
				return false;
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

	public ref<Node> foldMultiReturnOfMultiCall(ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
		return foldInternal(tree, true, true, compileContext);
	}
	
	public ref<Node> fold(ref<SyntaxTree> tree, boolean voidContext, ref<CompileContext> compileContext) {
		return foldInternal(tree, voidContext, false, compileContext);
	}
	
	private ref<Node> foldInternal(ref<SyntaxTree> tree, boolean voidContext, boolean multiReturnOfMultiCall, ref<CompileContext> compileContext) {
		if (deferGeneration())
			return this;
		switch (op()) {
		case	CALL:
			if (_folded)
				return this;
			_folded = true;
			if (_category == CallCategory.COERCION) {
				ref<Node> source = _arguments.node;
				return tree.newCast(type, source).fold(tree, voidContext, compileContext);
			}
			ref<NodeList> ellipArgs = getEllipsisArguments();
			if (ellipArgs != null) {
				// Cap each of the ellipsis arguments for subsequent processing (BEFORE folding because
				// we want the ellipsis arguments to have the proper context when they get folded..
				for (ref<NodeList> nl = ellipArgs; nl != null; nl = nl.next) {
					ref<Type> t = nl.node.type;
					nl.node = tree.newUnary(Operator.ELLIPSIS_ARGUMENT, nl.node, nl.node.location());
					nl.node.type = t;
				}
			}
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
			case	DECLARATOR:
				return this;
				
			case	COERCION:
				break;

			case	CONSTRUCTOR:
				if (_overload == null) {
					// This is the case of a constructor with no arguments on an object
					// declaration for a type that has no constructor at all. (if such a
					// declaration had been given for a class that has only-non default
					// constructors, that would be flagged as an error and would not get
					// here.

					// Just leave it alone.
					return this;
				}
				if (_overload.type != null && _overload.type.deferAnalysis()) {
					type = _overload.type;
					return this;
				}
				functionType = ref<FunctionType>(_overload.type);
				if (voidContext) {
					thisParameter = _target;
					// we see INDIRECT nodes here for enum constructors.
					if (thisParameter.op() == Operator.INDIRECT)
						thisParameter = ref<Unary>(thisParameter).operand();
				} else {
					ref<Variable> temp = compileContext.newVariable(type);
					thisParameter = tree.newReference(temp, true, location());
					compileContext.markLiveSymbol(thisParameter);
					thisParameter = tree.newUnary(Operator.ADDRESS, thisParameter, location());
					thisParameter.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
//					ref<Node> n = tree.newStackArgumentAddress(0, location());
//					n.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
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
				switch (_target.op()) {
				case DOT:
					ref<Selection> dot = ref<Selection>(_target);
					if (dot.indirect()) {
						thisParameter = dot.left();
					} else {
						if (dot.left().isLvalue()) {
							thisParameter = tree.newUnary(Operator.ADDRESS, dot.left(), dot.left().location());
							thisParameter.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
						} else {
							ref<Variable> temp = compileContext.newVariable(dot.left().type);
							ref<Reference> r = tree.newReference(temp, true, dot.left().location());
							compileContext.markLiveSymbol(r);
							ref<Node> defn = tree.newBinary(Operator.INITIALIZE, r, dot.left(), dot.left().location());
							defn.type = dot.left().type;
							r = tree.newReference(temp, false, dot.left().location());
							ref<Unary> adr = tree.newUnary(Operator.ADDRESS, r, dot.left().location());
							adr.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
							ref<Node> pair = tree.newBinary(Operator.SEQUENCE, defn.fold(tree, true, compileContext), adr, dot.left().location());
							pair.type = defn.type;
							_target = tree.newSelection(pair, dot.symbol(), false, dot.location());
							_target.type = dot.type;
							thisParameter = pair;
						}
					}
					break;

				case SUBSCRIPT:
					ref<Binary> b = ref<Binary>(_target);
					if (b.left().type.family() != runtime.TypeFamily.POINTER) {
						_target = tree.newUnary(Operator.ADDRESS, _target, _target.location());
						_target.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);					
					}
					break;

				default:
					thisParameter = tree.newLeaf(Operator.THIS, location());
					thisParameter.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
				}
				
			default:
				if (_overload == null) {
					functionObject = _target;
					// All other calls can rely on the LHS expression type to be the correct function,
					// but for LHS expressions that are function objects (i.e. function pointers), there is
					// no overloaded symbol, so we can't use that.
					if (_target == null && _target.type.deferAnalysis()) {
						type = _target.type;
						return this;
					}
					functionType = ref<FunctionType>(_target.type);
				} else
					functionType = _overload.type;
				ref<Variable> temp;
				if (multiReturnOfMultiCall) {
					outParameter = tree.newLeaf(Operator.MY_OUT_PARAMETER, location());
					outParameter.type = functionType;
				} else {
					boolean makeLive;
					if (functionType != null && functionType.returnCount() > 1) {
						pointer<ref<Type>> t = functionType.returnTypes();
						temp = compileContext.newVariable(t, functionType.returnCount());
						int offset;
						for (int i = 0; i < functionType.returnCount(); i++) {
							ref<Type> tp = t[i];
							if (tp.hasDestructor()) {
								ref<Reference> r = tree.newReference(temp, offset, true, location());
								compileContext.markLiveSymbol(r);
							}
							offset += tp.stackSize();
						}
					} else if (type != null && type.returnsViaOutParameter(compileContext)) {
						temp = compileContext.newVariable(type);
						makeLive = true;
					} else
						break;
					outParameter = tree.newReference(temp, true, location());
					if (makeLive)
						compileContext.markLiveSymbol(outParameter);
				}
				if (!voidContext) {
					nodeFlags |= PUSH_OUT_PARAMETER;
					result = encapsulateCallInTemp(temp, tree);
				}
			}
			// Now promote the 'hidden' parameters, so code gen is simpler.
			int registerArgumentIndex = 0;
			if (thisParameter != null) {
				thisParameter.register = compileContext.target.registerValue(registerArgumentIndex, runtime.TypeFamily.ADDRESS);
				if (thisParameter.register == 0) {
					printf("---\n");
					print(0);
					assert(thisParameter.register != 0);
				}
				registerArgumentIndex++;
			}
			if (outParameter != null) {
				if (multiReturnOfMultiCall)
					outParameter.register = compileContext.target.registerValue(registerArgumentIndex, runtime.TypeFamily.ADDRESS);
				else {
					outParameter = tree.newUnary(Operator.ADDRESS, outParameter, outParameter.location());
					outParameter.register = compileContext.target.registerValue(registerArgumentIndex, runtime.TypeFamily.ADDRESS);
					outParameter.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
				}
			}
			
			if (_arguments != null) {
				
				// The goal of this patch of code is to deal with the possibility of needing to call a destructor.
				// The way to achieve this in a reliable way is to generate a temp and call markLiveSymbol to get it
				// cleaned up.

				for (ref<NodeList> args = _arguments; args != null; args = args.next) {
					switch (args.node.type.family()) {
					case STRING:
					case STRING16:
						switch (args.node.op()) {
						case CALL:
							if (ref<Call>(args.node).target().type.family() != runtime.TypeFamily.FUNCTION)
								break;
							ref<FunctionType> argumentFunctionType = ref<FunctionType>(ref<Call>(args.node).target().type);
							ref<Type> t = args.node.type;
							args.node.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
							if (argumentFunctionType.returnCount() == 1) {
								ref<Variable> temp = compileContext.newVariable(t);
								ref<Reference> r = tree.newReference(temp, true, location());
								compileContext.markLiveSymbol(r);
								ref<Node> call = tree.newBinary(Operator.STORE_TEMP, r, args.node, location());
								call.type = t;
								call = call.fold(tree, true, compileContext);
								r = tree.newReference(temp, false, location());
								ref<Node> seq = tree.newBinary(Operator.SEQUENCE, call, r, location());
								seq.type = t;
								args.node = seq;
							}
						}
					}
				}

				if (functionType == null) {
					print(0);
				}
				functionType.assignRegisterArguments(compileContext);
				pointer<ref<Type>> params = functionType.parameters();
				int paramsCount = functionType.parameterCount();
				int ellipsisArgument;
				if (functionType.hasEllipsis())
					ellipsisArgument = paramsCount - 1;
				else
					ellipsisArgument = -1;
				ref<NodeList> registerArguments;
				ref<NodeList> lastRegisterArgument;
				
				// TODO: Ensure plain stack arguments are in 'correct' order.
				ref<NodeList> argsNext = null;
				ref<NodeList> args = _arguments;
				for (int i = 0; i < paramsCount; args = argsNext, params++, i++) {
					if (i == ellipsisArgument) {
						ref<EllipsisArguments> ea = null;			// TODO: Remove this initializer to test implied re-initialization.
						if (args == null) {
							ea = tree.newEllipsisArguments(null, location());
							ea.type = (*params).elementType();
							args = tree.newNodeList(ea);
						} else if (args.next == null && args.node.type.equals(*params)) {
							args.node = tree.newUnary(Operator.STACK_ARGUMENT, args.node, args.node.location());
							args.node.type = *params;
						} else {
							ea = tree.newEllipsisArguments(args, location());
							ea.type = (*params).elementType();
							args = tree.newNodeList(ea);
						}
						args.next = _stackArguments;
						_stackArguments = args;
						break;
					}
					if (args == null)
						break;					// This indicates a call args/params mismatch error, so don't fold this.
					argsNext = args.next;
					
					// Thread each argument onto the appropriate list: stack or register
					byte r = functionType.parameterRegister(i);
					if (r == 0) {
						ref<Type> t = args.node.type;
						args.node = tree.newUnary(Operator.STACK_ARGUMENT, args.node, args.node.location());
						args.node.type = t;
						args.next = _stackArguments;
						_stackArguments = args;
					} else {
						args.node.register = r;
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
			n.type = compileContext.builtInType(runtime.TypeFamily.VOID);;
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
			
		case	ARRAY_AGGREGATE:
			if (compileContext.target.verbose()) {
				printf("--- fold: %s ---------\n", compileContext.current().sourceLocation(location()));
				print(4);
			}
			// Is this a ref<Array> type ARRAY_AGGREGATE?
			Interval[] intervals;
			ref<Type> indexType, elementType;

			if (type.family() == runtime.TypeFamily.REF) {						// it's a ref<Array>, convert accordingly
				indexType = compileContext.builtInType(runtime.TypeFamily.SIGNED_32);
				elementType = compileContext.builtInType(runtime.TypeFamily.VAR);
			} else {
				indexType = type.indexType();
				elementType = type.elementType();
			}
			for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
				nl.node = nl.node.fold(tree, false, compileContext);
				if (indexType.family() == runtime.TypeFamily.STRING)
					continue;
				if (nl.node.op() == Operator.LABEL) {
					ref<Binary> b = ref<Binary>(nl.node);
					long v = b.left().foldInt(compileContext.target, compileContext);
					InternalLiteral il(indexType.family() == runtime.TypeFamily.ENUM ? v : v + 1, runtime.SourceOffset());
					if (v < 0 || !il.representedBy(indexType)) {
						b.left().add(MessageId.INITIALIZER_BEYOND_RANGE, compileContext.pool());
						type = compileContext.errorType();
					}
					Interval interval = { start: v, end: v, first: nl };
					intervals.append(interval);
				} else {
					if (intervals.length() == 0) {
						Interval i = { start: 0, end: 0, first: nl };
						intervals.append(i);
					} else {
						ref<Interval> i = &intervals[intervals.length() - 1];
						i.end++;
						InternalLiteral il(indexType.family() == runtime.TypeFamily.ENUM ? i.end : i.end + 1, runtime.SourceOffset());
						if (i.end < 0 || !il.representedBy(indexType)) {
							nl.node.add(MessageId.INITIALIZER_BEYOND_RANGE, compileContext.pool());
							type = nl.node.type = compileContext.errorType();
						}
					}
				}
			}
			if (type.family() == runtime.TypeFamily.REF) {
				ref<Variable> temp = compileContext.newVariable(type);
				ref<Reference> r = tree.newReference(temp, true, location());
				ref<Node> o = tree.newIdentifier(compileContext.arrayClass(), location());
				o.type = o.symbol().assignType(compileContext);
				ref<Node> newObject = tree.newBinary(Operator.NEW, tree.newLeaf(Operator.EMPTY, location()),
								o, location());
				newObject.type = type;
				result = tree.newBinary(Operator.ASSIGN, r, newObject, location());
				result.type = type;

				ref<OverloadInstance> pushMethod = getOverloadInstance(type.indirectType(compileContext), "push", compileContext);
				for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
					r = tree.newReference(temp, false, location());
					ref<Selection> method = tree.newSelection(r, pushMethod, true, location());
					method.type = pushMethod.type();
					ref<Call> call = tree.newCall(pushMethod.parameterScope(), CallCategory.METHOD_CALL, method, tree.newNodeList(nl.node), location(), compileContext);
					call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
					result = tree.newBinary(Operator.SEQUENCE, result, call, location());
					result.type = call.type;
				}

				if (result.op() == Operator.SEQUENCE) {
					r = tree.newReference(temp, false, location());
					result = tree.newBinary(Operator.SEQUENCE, result, r, location());
					result.type = type;
				}
				return result.fold(tree, false, compileContext);
			}
			if (intervals.length() > 1) {
				intervals.sort();
				for (int i = 1; i < intervals.length(); i++) {
					if (intervals[i - 1].end >= intervals[i].start) {
						intervals[i].first.node.add(MessageId.DUPLICATE_INDEX, compileContext.pool());
						type = compileContext.errorType();
					}
				}
			}
			break;
			
		case	OBJECT_AGGREGATE:
			if (compileContext.target.verbose()) {
				printf("--- fold: %s ---------\n", compileContext.current().sourceLocation(location()));
				print(4);
			}
			ref<Variable> temp = compileContext.newVariable(type);
			result = null;
			if (type.family() == runtime.TypeFamily.REF) {
				ref<Reference> r = tree.newReference(temp, true, location());
				ref<Node> o = tree.newIdentifier(compileContext.objectClass(), location());
				o.type = o.symbol().assignType(compileContext);
				ref<Node> newObject = tree.newBinary(Operator.NEW, tree.newLeaf(Operator.EMPTY, location()),
								o, location());
				newObject.type = type;
				result = tree.newBinary(Operator.ASSIGN, r, newObject, location());
				result.type = type;

				ref<OverloadInstance> setMethod = getOverloadInstance(type.indirectType(compileContext), "set", compileContext);
				for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
					ref<Binary> b = ref<Binary>(nl.node);
					r = tree.newReference(temp, false, location());
					ref<Selection> method = tree.newSelection(r, setMethod, true, location());
					method.type = setMethod.type();
					ref<Node> label = tree.newConstant(Operator.STRING, ref<Identifier>(b.left()).identifier(), location());
					label.type = compileContext.builtInType(runtime.TypeFamily.STRING);
					ref<Node> value = b.right().coerce(tree, compileContext.builtInType(runtime.TypeFamily.VAR), false, compileContext);
					ref<Call> call = tree.newCall(setMethod.parameterScope(), CallCategory.METHOD_CALL, method, tree.newNodeList(label, value), location(), compileContext);
					call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
					result = tree.newBinary(Operator.SEQUENCE, result, call, location());
					result.type = call.type;
				}

				if (result.op() == Operator.SEQUENCE) {
					r = tree.newReference(temp, false, location());
					result = tree.newBinary(Operator.SEQUENCE, result, r, location());
					result.type = type;
				}
				return result.fold(tree, false, compileContext);
			} else {
				ref<ParameterScope> constructor = type.defaultConstructor();
				if (constructor != null) {
					ref<Reference> r = tree.newReference(temp, true, location());
					compileContext.markLiveSymbol(r);
					ref<Node> adr = tree.newUnary(Operator.ADDRESS, r, location());
					adr.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
					ref<Call> call = tree.newCall(constructor, CallCategory.CONSTRUCTOR, adr, null, location(), compileContext);
					call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
					result = call.fold(tree, true, compileContext);
				} else if (type.hasDestructor()) {
					ref<Reference> r = tree.newReference(temp, true, location());
					compileContext.markLiveSymbol(r);
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
					ref<Node> init = tree.newBinary(Operator.ASSIGN, member, value, nl.node.location());
					init.type = member.type;
					init = init.fold(tree, true, compileContext);
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
			}
			
		default:
			print(0);
			assert(false);
		}
		return this;
	}

	public boolean multiReturnCall() {
		if (deferGeneration())
			return false;
		if (op() != Operator.CALL)
			return false;
		switch (_category) {
		case FUNCTION_CALL:
		case METHOD_CALL:
			ref<FunctionType> functionType = ref<FunctionType>(_target.type);
			return functionType != null && functionType.returnCount() > 1;
		}
		return false;
	}
	/**
	 * Get the first ellipsis argument, if any.
	 *
	 * @return null if this call has no ellipsis arguments or a non-null
	 * NodeList reference of the first such argument.
	 */
	private ref<NodeList> getEllipsisArguments() {
		ref<FunctionType> functionType;
		switch (_category) {
		case DECLARATOR:
		case COERCION:
		case DESTRUCTOR:
			return null;

		case CONSTRUCTOR:
			if (_overload == null)
				return null;
			functionType = ref<FunctionType>(_overload.type);
			break;

		default:
			if (_target.deferGeneration())
				return null;
			functionType = ref<FunctionType>(_target.type);
		}
		if (functionType == null)
			return null;
		int parameterCount = functionType.parameterCount();
		if (functionType.hasEllipsis()) {
			ref<NodeList> args = _arguments;
			int ellipsisArgument = parameterCount - 1;

			for (int i = 0; i < parameterCount; args = args.next, i++) {
				if (i == ellipsisArgument) {
					if (args != null && args.next == null && args.node.type.equals(functionType.parameters()[i]))
						return null;
					return args;
				}
			}
		}
		return null;
	}

	public long foldInt(ref<Target> target, ref<CompileContext> compileContext) {
		if (_category != CallCategory.COERCION) {
			print(0);
			assert(false);
		}
		long x = _arguments.node.foldInt(target, compileContext);
		int sz = type.size();
		if (sz > 4)
			return x;

		if (type.isSigned())
			return (x << sz * 8) >> sz * 8;
		else
			return x & ((1 << (sz * 8)) - 1);
	}

	public void setConstructorMemory(ref<Node> placement, ref<SyntaxTree> tree) {
		if (_category == CallCategory.CONSTRUCTOR)
			_target = placement;
	}
	/**
	 * Sort the register arguments (if any) by sethi number.
	 *
	 * Of course, this assumes that a sethi number has been calculated already.
	 */	
	public void sortRegisterArguments() {
		// If there are fewer than 2 arguments, don't bother to sort
		if (_arguments == null || _arguments.next == null)
			return;
		ref<NodeList>[] args;

		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			args.append(nl);
		args.sort(sethiComparator, false);
		_arguments = args[0];
		for (i in args) {
			if (i > 0)
				args[i - 1].next = args[i];
		}
		args[args.length() - 1].next = null;
	}

	private static int sethiComparator(ref<NodeList> nl1, ref<NodeList> nl2) {
		return math.abs(nl1.node.sethi) - math.abs(nl2.node.sethi);
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
	
	public boolean isConstant() {
		if (_category != CallCategory.COERCION)
			return false;
		return _arguments.node.isConstant();
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

	public void checkCompileTimeConstant(long minimumIndex, long maximumIndex, ref<CompileContext> compileContext) {
		if (op() != Operator.CALL || _category != CallCategory.COERCION)
			return;
		if (deferAnalysis())
			return;
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
		_arguments.node.checkCompileTimeConstant(minimumIndex, maximumIndex, compileContext);
		if (_arguments.node.deferAnalysis())
			type = _arguments.node.type;
	}
	
	void assignDeclarationTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	CALL:
			if (!assignSub(Operator.FUNCTION, compileContext))
				break;
			if (!assignFunctionType(compileContext)) {
				add(MessageId.NOT_A_TYPE, compileContext.pool());
				type = compileContext.errorType();
			}
			return;
			
		default:
			assignTypes(compileContext);
		}
	}
	
	private boolean assignFunctionType(ref<CompileContext> compileContext) {
		ref<Type>[] returnTypes;

		switch (_target.op()) {
		case VOID:
			break;

		case SEQUENCE:
			if (!gatherReturnTypes(true, &returnTypes, _target))
				return false;
			break;
			
		default:
			if (!gatherReturnTypes(false, &returnTypes, _target))
				return false;

			boolean gatherReturnTypes(boolean leftSide, ref<ref<Type>[]> returnTypes, ref<Node> n) {
				if (leftSide && n.op() == Operator.SEQUENCE) {
					ref<Binary> b = ref<Binary>(n);
					if (!gatherReturnTypes(true, returnTypes, b.left()))
						return false;
					if (!gatherReturnTypes(false, returnTypes, b.right()))
						return false;
				} else if (_target.type.family() == runtime.TypeFamily.TYPEDEF)
					returnTypes.append(_target.unwrapTypedef(Operator.CLASS, compileContext));
				else
					return false;
				return true;
			}
		}
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			if (nl.node.op() == Operator.BIND)
				continue;
			if (nl.node.type.family() != runtime.TypeFamily.TYPEDEF)
				return false;
		}
		ref<Type>[] parameterTypes;
		boolean hasEllipsis;
		// This is a 'good' function type declaration, clean it up. 
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			if (nl.node.op() == Operator.BIND) {
				ref<Identifier> id = ref<Identifier>(ref<Binary>(nl.node).right());
				nl.node.add(MessageId.INVALID_BINDING, compileContext.pool(), id.identifier());
				type = compileContext.errorType();
			} else {
				nl.node.type = nl.node.unwrapTypedef(Operator.CLASS, compileContext);
				parameterTypes.append(nl.node.type);
				if (nl.next == null)
					hasEllipsis = nl.node.getProperEllipsis() != null;
			}
		}
		if (type == null) {
			type = compileContext.pool().newFunctionType(returnTypes, parameterTypes, hasEllipsis);
			type = compileContext.pool().newTypedefType(runtime.TypeFamily.TYPEDEF, type);
		}
		_category = CallCategory.DECLARATOR;
		return true;
	}
	
	public void forceCallToConstructor() {
		_category = CallCategory.CONSTRUCTOR;
	}

	private void assignTypes(ref<CompileContext> compileContext) {
		switch (op()) {
		case	ARRAY_AGGREGATE:
			if (assignArguments(LabelStatus.OPTIONAL_LABELS, compileContext))
				type = compileContext.builtInType(runtime.TypeFamily.ARRAY_AGGREGATE);
			else
				type = compileContext.errorType();
			break;
			
		case	OBJECT_AGGREGATE:
			if (assignArguments(LabelStatus.REQUIRED_LABELS, compileContext))
				type = compileContext.builtInType(runtime.TypeFamily.OBJECT_AGGREGATE);
			else
				type = compileContext.errorType();
			break;
			
		case	ANNOTATION:
			type = compileContext.builtInType(runtime.TypeFamily.VOID);
			break;

		case	TEMPLATE_INSTANCE:
			if (!assignSub(Operator.TEMPLATE, compileContext))
				break;
			if (_target.type.family() == runtime.TypeFamily.TYPEDEF) {
				ref<TypedefType> t = ref<TypedefType>(_target.type);
				if (t.wrappedType().family() == runtime.TypeFamily.TEMPLATE) {
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
			for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
				if (nl.node.op() == Operator.BIND) {
					ref<Identifier> id = ref<Identifier>(ref<Binary>(nl.node).right());
					nl.node.add(MessageId.INVALID_BINDING, compileContext.pool(), id.identifier());
					type = compileContext.errorType();
				}
			}
			if (deferAnalysis())
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
				// First, check that we are within the function's main fody.
				ref<Node> def = compileContext.current().enclosing().definition();
				if (def.op() != Operator.FUNCTION) {
					_target.add(MessageId.INVALID_SUPER, compileContext.pool());
					type = compileContext.errorType();
					break;
				}
				ref<FunctionDeclaration> func = ref<FunctionDeclaration>(def);

				if (func.functionCategory() != FunctionDeclaration.Category.CONSTRUCTOR) {
					_target.add(MessageId.INVALID_SUPER, compileContext.pool());
					type = compileContext.errorType();
					break;
				}

				ref<NodeList> stmt1 = func.body.statements();
				while (stmt1 != null) {
					if (hasCode(stmt1))
						break;
					stmt1 = stmt1.next;
				}
				if (stmt1 == null || stmt1.node.op() != Operator.EXPRESSION ||
					ref<Unary>(stmt1.node).operand() != this) {
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
			} else if (_target.op() == Operator.VOID) {
				assignFunctionType(compileContext);
				break;
			}
			if (_target.type == null)
				print(0);
			switch (_target.type.family()) {
			case	VAR:
				type = _target.type;
				break;

			case	TYPEDEF:
				ref<Type> t = _target.unwrapTypedef(Operator.CLASS, compileContext);
				if (_arguments != null && assignFunctionType(compileContext))
					break;
				// a new or placement new expression will set the category to CONSTRUCTOR				
				if (_category != CallCategory.CONSTRUCTOR && builtInCoercion(compileContext))
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
				convertArguments(ref<FunctionType>(_target.type), compileContext);
				_category = CallCategory.FUNCTION_CALL;
				ref<Symbol> symbol = _target.symbol();
				if (symbol != null) {
					if (symbol.class !<= OverloadInstance)
						symbol = null;
					else {
						_overload = ref<OverloadInstance>(symbol).parameterScope();
						if (symbol.storageClass() == StorageClass.MEMBER || 
							symbol.storageClass() == StorageClass.LOCK)
							_category = CallCategory.METHOD_CALL;
					}
				}
				ref<FunctionType> ft = ref<FunctionType>(_target.type);
				// Verify that this corresponds to a function overload
				pointer<ref<Type>> returns = ft.returnTypes();
				for (int i = 0; i < ft.returnCount(); i++) {
					if (returns[i].family() == runtime.TypeFamily.CLASS_VARIABLE) {
						type = compileContext.builtInType(runtime.TypeFamily.CLASS_DEFERRED);
						return;
					}
				}
				type = ft.returnValueType();
				if (type == null)
					type = compileContext.builtInType(runtime.TypeFamily.VOID);
				break;

			default:
				_target.add(MessageId.NOT_A_FUNCTION, compileContext.pool());
				type = compileContext.errorType();
			}
			break;
		}
	}

	private boolean hasCode(ref<NodeList> stmt) {
		switch (stmt.node.op()) {
		case STATIC:
			return false;
		}
		return true;
	}

	private boolean assignSub(Operator kind, ref<CompileContext> compileContext) {
		if (!assignArguments(LabelStatus.NO_LABELS, compileContext))
			return false;
		if (_overload == null) {
			_target.assignOverload(_arguments, kind, compileContext);
			if (_target.deferAnalysis()) {
				type = _target.type;
				return false;
			}
			if (_target.type.family() == runtime.TypeFamily.VAR) {
				type = compileContext.errorType();
				_target.add(MessageId.UNFINISHED_VAR_CALL, compileContext.pool());
				return false;
			}
		} else
			_target.type = _overload.type;
		return true;
	}

	public void assignConstructorDeclarator(ref<Type> classType, ref<CompileContext> compileContext) {
		if (assignArguments(LabelStatus.NO_LABELS, compileContext))
			assignConstructorCall(classType, compileContext);
	}

	private void assignConstructorCall(ref<Type> classType, ref<CompileContext> compileContext) {
		OverloadOperation operation(Operator.FUNCTION, this, null, _arguments, compileContext);
		if (classType.deferAnalysis()) {
			type = classType;
			return;
		}
		// EnumInstanceTypes report the scope of the underlying class object, but a constructor
		// for an EnumInstanceType should always default to a simple default constructor.
		if (classType.family() == runtime.TypeFamily.ENUM) {
			if (_arguments != null) {
				add(MessageId.NO_MATCHING_CONSTRUCTOR, compileContext.pool());
				type = compileContext.errorType();
				return;
			}
			type = classType;
			_overload = ref<EnumInstanceType>(classType).instanceConstructor(compileContext.pool());
			_category = CallCategory.CONSTRUCTOR;
			return;
		}
		type = operation.includeConstructors(classType, compileContext);
		if (type != null)
			return;
		ref<Type> match;
		ref<Symbol> oi;
		(match, oi) = operation.result();
		if (match.deferAnalysis()) {
			type = match;
		} else {
			type = classType;
			if (oi != null) {
				_overload = ref<OverloadInstance>(oi).parameterScope();
				convertArguments(_overload.type, compileContext);
			}
			_category = CallCategory.CONSTRUCTOR;
		}
	}

	public boolean coerceAggregateType(ref<Type> newType, ref<CompileContext> compileContext) {
//		printf("coerceAggregateType to %s\n", newType.signature());
		ref<Type> indexType;
		ref<Type> elementType;
		switch (newType.family()) {
		case REF:						// it's a ref<Array>, convert accordingly
		case VAR:						// it's a var, it's going to be a ref<Array> on the way in.
			indexType = compileContext.builtInType(runtime.TypeFamily.SIGNED_32);
			elementType = compileContext.builtInType(runtime.TypeFamily.VAR);
			break;

		default:
			indexType = newType.indexType();
			elementType = newType.elementType();
		}
		boolean success = true;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			if (nl.node.op() == Operator.LABEL) {
				ref<Binary> b = ref<Binary>(nl.node);
				ref<Node> lbl;
				if (indexType.family() == runtime.TypeFamily.ENUM) {
					ref<Identifier> id = ref<Identifier>(b.left());
					id.resolveAsEnum(ref<EnumInstanceType>(indexType), compileContext);
					lbl = b.left();
				} else {
					if (!b.left().isConstant()) {
						b.left().add(MessageId.NOT_CONSTANT, compileContext.pool());
						success = false;
					}
					lbl = b.left().coerce(compileContext.tree(), indexType, true, compileContext);
					if (lbl.deferAnalysis())
						success = false;
				}
				ref<Node> x = b.right().coerce(compileContext.tree(), elementType, true, compileContext);
				if (x.deferAnalysis())
					success = false;
				if (lbl != b.left() || x != b.right()) {
					b = compileContext.tree().newBinary(Operator.LABEL, lbl, x, b.location());
					b.type = nl.node.type;
					nl.node = b;
				}
			} else {
				nl.node = nl.node.coerce(compileContext.tree(), elementType, true, compileContext);
				if (nl.node.deferAnalysis())
					success = false;
			}
		}
		if (success)
			type = newType;
		else
			type = compileContext.errorType();
		return success;
	}

	void convertArguments(ref<FunctionType> funcType, ref<CompileContext> compileContext) {
		boolean processingEllipsis = false;
		pointer<ref<Type>> param = funcType.parameters();
		int paramCount = funcType.parameterCount();
		ref<NodeList> arguments = _arguments;
		int ellipsisArgument;
		if (funcType.hasEllipsis())
			ellipsisArgument = paramCount - 1;
		else
			ellipsisArgument = -1;
		for (int i = 0; arguments != null; arguments = arguments.next) {
			if (param[i] == null || param[i].deferAnalysis())
				return;
			ref<Type> t = param[i];
			if (i == ellipsisArgument) {
				// in this case t is a vector type
				// Check for the special case that the argument has type t
				if (arguments.node.type.equals(t))
					return;
				// If there are more arguments, then this parameter must be an ellipsis parameter
				// okay, we need to actually check the element type
				t = t.elementType();
				do {
					arguments.node = arguments.node.coerce(compileContext.tree(), t, false, compileContext);
					arguments = arguments.next;
				} while (arguments != null);
				return;
			}
			if (compileContext.verbose()) {
				printf("Coerce to %s\n", t.signature());
				arguments.node.print(4);
			}
			arguments.node = arguments.node.coerce(compileContext.tree(), t, false, compileContext);
			i++;
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

	boolean assignArguments(LabelStatus status, ref<CompileContext> compileContext) {
//		long nextIndex = 0;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			compileContext.assignTypes(nl.node);
			switch (status) {
			case	NO_LABELS:
				if (nl.node.op() == Operator.LABEL) {
					// This path way should not occur, because the parser context should constrain the
					// argument expressions.
					nl.node.print(0);
					assert(false);
//					nl.node.add(MessageId.NOT_A_FUNCTION, compileContext.pool());
//					nl.node.type = compileContext.errorType();
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
/*
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
 */
		return true;
	}

	ref<Node> rewriteDeclarators(ref<SyntaxTree> syntaxTree) {
//		if (op() == Operator.CALL)
//			return syntaxTree.newFunctionDeclaration(FunctionDeclaration.Category.DECLARATOR, _target, null, _arguments, location());
//		else
			return this;
	}

	public boolean canCoerce(ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
		switch (op()) {
		case	ARRAY_AGGREGATE:
			newType = newType.classType();
			switch (newType.family()) {
			case	VAR:
				return true;
				
			case	SHAPE:
				boolean isMap = newType.isMap(compileContext);
				ref<Type> indexType = newType.indexType();
				ref<Type> elementType = newType.elementType();
				for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
					if (nl.node.op() == Operator.LABEL) {
						ref<Binary> b = ref<Binary>(nl.node);
						if (indexType.family() == runtime.TypeFamily.ENUM) {
							if (b.left().op() != Operator.IDENTIFIER)
								return false;
							if (!ref<EnumInstanceType>(indexType).hasInstance(ref<Identifier>(b.left())))
								return false;
						} else {
							if (b.left().op() == Operator.IDENTIFIER) {
								compileContext.assignTypes(b.left());
								if (b.left().deferAnalysis() ||
									!b.left().canCoerce(indexType, false, compileContext)) {
									b.left().type = null;
									return false;
								}
								b.left().type = null;
							} else {
								compileContext.assignTypes(b.left());
								if (b.left().deferAnalysis())
									return false;
								if (!b.left().canCoerce(indexType, false, compileContext))
									return false;
							}
						}
						if (!b.right().canCoerce(elementType, false, compileContext))
							return false;
					} else {
						if (isMap)
							return false;
						if (!nl.node.canCoerce(elementType, false, compileContext))
							return false;
					}
				}
				return true;

			case REF:
//				printf("canCoerce ARRAY_AGGREGATE: %s -> %s? %s\n", 
//					compileContext.builtInType(runtime.TypeFamily.ARRAY_AGGREGATE).signature(),
//					newType.indirectType(compileContext).signature(),
//					string(newType.indirectType(compileContext) == 
//						compileContext.builtInType(runtime.TypeFamily.ARRAY_AGGREGATE)));
				if (newType.indirectType(compileContext) != 
						compileContext.builtInType(runtime.TypeFamily.ARRAY_AGGREGATE))
					return false;
					// it's a ref<Array>, convert accordingly
				indexType = compileContext.builtInType(runtime.TypeFamily.SIGNED_32);
				elementType = compileContext.builtInType(runtime.TypeFamily.VAR);
				for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
					if (nl.node.op() == Operator.LABEL) {
						ref<Binary> b = ref<Binary>(nl.node);
						if (b.left().op() == Operator.IDENTIFIER) {
							compileContext.assignTypes(b.left());
							if (b.left().deferAnalysis() ||
								!b.left().canCoerce(indexType, false, compileContext)) {
								b.left().type = null;
								return false;
							}
							b.left().type = null;
						} else {
							compileContext.assignTypes(b.left());
							if (b.left().deferAnalysis())
								return false;
							if (!b.left().canCoerce(indexType, false, compileContext))
								return false;
						}
						if (!b.right().canCoerce(elementType, false, compileContext))
							return false;
					} else {
						if (!nl.node.canCoerce(elementType, false, compileContext))
							return false;
					}
				}
				return true;

			default:
				printf("\nnewType: (%s) ", newType.signature());
				newType.print();
				printf("\n");
				print(0);
				assert(false);
			}
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

			case REF:
				if (newType.indirectType(compileContext) == type)
					return true;

			default:
				return false;
			}
		}
		return super.canCoerce(newType, explicitCast, compileContext);
	}
	
	public ref<Node> coerce(ref<SyntaxTree> tree, ref<Type> newType, boolean explicitCast, ref<CompileContext> compileContext) {
		if (op() == Operator.ARRAY_AGGREGATE) {
			ref<Type> tp = type;
			coerceAggregateType(newType, compileContext);
			if (newType.family() == runtime.TypeFamily.VAR) {
				ref<Node> n = tree.newCast(newType, this);
				type = tp;
				return n;
			}
			return this;
		}
		return super.coerce(tree, newType, explicitCast, compileContext);
	}

	public ref<Node> target() {
		return _target;
	}
 
	public pointer<ref<Type>>, int getParameterList() {
		ref<FunctionType> ft = ref<FunctionType>(_target.type);
		return ft.parameters(), ft.parameterCount();
	}

	public ref<NodeList> stackArguments() {
		return _stackArguments;
	}
	/**
	 * Called when this CALL is an operand of a return statement. If this is a multi-value return, then
	 * we have to process the return value in toto to preserve the semantics correctly.
	 */
	public boolean isNestedMultiReturn() {
		if (_target.deferAnalysis())
			return false;
		return ref<FunctionType>(_target.type).returnCount() > 1;
	}
	
	private boolean builtInCoercion(ref<CompileContext> compileContext) {
		if (_arguments == null ||
			_arguments.next != null)
			return false;
		ref<Type> newType = _target.unwrapTypedef(Operator.CLASS, compileContext);
		return newType.builtInCoercionFrom(_arguments.node, compileContext);
	}
	
	public CallCategory category() {
		return _category;
	}
}

public class FunctionDeclaration extends ParameterBag {
	public enum Category {
		NORMAL,
		CONSTRUCTOR,
		DESTRUCTOR,
		ABSTRACT,
		DECLARATOR			// occurs 
	}
	private Category _functionCategory;
	private ref<NodeList> _returnType;
	private ref<Identifier> _name;

	public ref<Block> body;
	public boolean referenced;			// The function in question has been referenced, so it should be typed checked
										// and have code generated.
	
	FunctionDeclaration(Category functionCategory, ref<Node> returnType, ref<Identifier> name, ref<NodeList> arguments, 
				ref<SyntaxTree> tree, runtime.SourceOffset location) {
		super(Operator.FUNCTION, arguments, location);
		_functionCategory = functionCategory;
		if (returnType != null) {
			_returnType = returnType.treeToList(null, tree);
			if (returnType.op() != Operator.VOID) {
				for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next)
					nl.node = tree.newUnary(Operator.UNWRAP_TYPEDEF, nl.node, nl.node.location());
			}
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
	
	public ref<FunctionDeclaration> clone(ref<SyntaxTree> tree) {
		ref<NodeList> returnType = _returnType != null ? _returnType.clone(tree) : null;
		ref<Identifier> name = _name != null ? _name.clone(tree) : null;
		ref<NodeList> arguments = _arguments != null ? _arguments.clone(tree) : null;
		ref<FunctionDeclaration> f = tree.newFunctionDeclaration(_functionCategory, null, name, arguments, location());
		f._returnType = returnType;
		if (body != null)
			f.body = body.clone(tree);
		return ref<FunctionDeclaration>(f.finishClone(this, tree.pool()));
	}

	public ref<FunctionDeclaration> cloneRaw(ref<SyntaxTree> tree) {
		ref<NodeList> returnType = _returnType != null ? _returnType.cloneRaw(tree) : null;
		ref<Identifier> name = _name != null ? _name.cloneRaw(tree) : null;
		ref<NodeList> arguments = _arguments != null ? _arguments.cloneRaw(tree) : null;
		ref<FunctionDeclaration> f = tree.newFunctionDeclaration(_functionCategory, null, name, arguments, location());
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

	public ref<NodeList> returnType() {
		return _returnType;
	}
/*
	ref<NodeList> returnType() { return _returnType; }

 */

	boolean definesScope() {
		if (_functionCategory == FunctionDeclaration.Category.ABSTRACT ||
			body != null)
			return true;
		else
			return false;
	}
 
	public void assignTypes(ref<CompileContext> compileContext) {
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			compileContext.assignTypes(nl.node);
		ref<Type>[] retType;
		if (_returnType != null) {
			if (_returnType.next != null ||
				_returnType.node.op() != Operator.VOID) {
				for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next)
					compileContext.assignTypes(nl.node);
				for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next) {
					if (nl.node.deferAnalysis()) {
						type = nl.node.type;
						retType.append(nl.node.type);
						continue;
					}
					if (nl.node.type.canCopy(compileContext))
						retType.append(nl.node.type);
					else {
						nl.node.add(MessageId.CANNOT_COPY_RETURN, compileContext.pool(), nl.node.type.signature());
						type = nl.node.type = compileContext.errorType();
					}
				}
			}
		}
		ref<Type>[] params;
		boolean hasEllipsis;
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			if (nl.node.deferAnalysis()) {
				type = nl.node.type;
				continue;
			}
			if (nl.node.type != null && nl.node.type.family() == runtime.TypeFamily.TYPEDEF) {
				ref<Type> t = nl.node.type.wrappedType();
				if (!t.canCopy(compileContext)) {
					nl.node.add(MessageId.CANNOT_COPY_ARGUMENT, compileContext.pool(), t.signature());
					type = nl.node.type = compileContext.errorType();
				}
			}
			params.append(nl.node.type);
			if (nl.next == null)
				hasEllipsis = nl.node.getProperEllipsis() != null;
		}
		ref<ParameterScope> scope;
		if (definesScope()) {
			scope = ref<ParameterScope>(compileContext.current());
			ref<ref<Symbol>[]> parameters = scope.parameters();
			for (i in *parameters) {
				(*parameters)[i].assignType(compileContext);
			}
			type = compileContext.pool().newFunctionType(retType, scope);
		} else
			type = compileContext.pool().newFunctionType(retType, params, hasEllipsis);
		if (_name != null && _name.symbol() != null) {
			_name.type = type;
		}
		if (body == null)
			return;
		if (retType.length() == 0)
			return;
		Test t = body.fallsThrough();
		if (t == Test.PASS_TEST) {
			ref<Block> b = ref<Block>(body);
			body.endOfBlockStatement(body.scope.unit().tree()).add(MessageId.RETURN_VALUE_REQUIRED, compileContext.pool());
		}
	}
	
	boolean assignTypesBoundary() {
		return _functionCategory != Category.DECLARATOR;
	}
}

public class DestructorList extends ParameterBag {
	DestructorList(ref<NodeList> destructors, runtime.SourceOffset location) {
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
	
	ParameterBag(Operator op, ref<NodeList> arguments, runtime.SourceOffset location) {
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

public class StackArgumentAddress extends Node {
	int	_offset;
	
	StackArgumentAddress(int offset, runtime.SourceOffset location) {
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

public class EllipsisArguments extends ParameterBag {
	EllipsisArguments(ref<NodeList> args, runtime.SourceOffset location) {
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

public class Return extends ParameterBag {
	private ref<NodeList> _liveSymbols;
	private boolean _multiReturnOfMultiCall;
	
	Return(ref<NodeList> expressions, runtime.SourceOffset location) {
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
		if (deferAnalysis())
			return this;
		if (_multiReturnOfMultiCall) {
			// This is the special case of a multi-return 'return' statement matching a call to another multi-return function.
			_arguments.node = ref<Call>(_arguments.node).foldMultiReturnOfMultiCall(tree, compileContext);
			return this;
		}
		int beforeLive = compileContext.liveSymbolCount();
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
			nl.node = nl.node.fold(tree, false, compileContext);
		int n = compileContext.liveSymbolCount();
		// Returning an object by value that has a destructor requires care. If the instance
		// being returned is about to be destroyed, we can just do a quick bit-wise copy. Of course, there
		// must be a copy constructor to do the return if there is a destructor.
		ref<Node>[] referencedLvalues;
		for (int i = 0; i < n; i++) {
			ref<Node> n = compileContext.getLiveSymbol(i);
			if (beingReturned(n)) {
				referencedLvalues.append(n);
				continue;
			}
			// We know that 'live' symbols have a scope with a destructor
			ref<NodeList> nl = tree.newNodeList(n);
			nl.next = _liveSymbols;
			_liveSymbols = nl;
//			ref<Node> thisParameter = tree.newUnary(Operator.ADDRESS, id, id.location());
//			thisParameter.type = compileContext.builtInType(runtime.TypeFamily.ADDRESS);
//			ref<Call> c = tree.newCall(destructor, CallCategory.DESTRUCTOR, thisParameter, null, location(), compileContext);
//			c.type = compileContext.builtInType(runtime.TypeFamily.VOID);
//			ref<Node> folded = c.fold(tree, true, compileContext);
//			output = tree.newBinary(Operator.SEQUENCE, folded, output, location());
		}
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			if (nl.node.type == null || nl.node.deferAnalysis())
				continue;
			if (nl.node.op() == Operator.CALL)
				continue;
			if (nl.node.type.hasDestructor()) {
				boolean skipCopy;
				ref<Node> arg = simpleReturnVariable(nl.node);
				if (arg != null) {
					for (i in referencedLvalues) {
						if (referencedLvalues[i] == null)
							continue;
						if (arg.conforms(referencedLvalues[i])) {
							referencedLvalues[i] = null;
							skipCopy = true;
							break;
						}
					}
				}
				if (!skipCopy) {
					ref<Variable> temp = compileContext.newVariable(nl.node.type);
					ref<Reference> r = tree.newReference(temp, true, nl.node.location());
					ref<Node> defn = tree.newBinary(Operator.ASSIGN_TEMP, r, nl.node, nl.node.location());
					defn.type = nl.node.type;
					r = tree.newReference(temp, false, nl.node.location());
					nl.node = tree.newBinary(Operator.SEQUENCE, defn.fold(tree, true, compileContext), r, nl.node.location());
					nl.node.type = defn.type;
				}
			}
		}
		while (compileContext.liveSymbolCount() > beforeLive) {
			compileContext.popLiveTemp(beforeLive);
		}
		return this;
	}

	private boolean beingReturned(ref<Node> n) {
		for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next) {
			ref<Node> arg = simpleReturnVariable(nl.node);
			if (arg != null && arg.conforms(n))
				return true;
		}
		return false;
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

	public boolean multiReturnOfMultiCall() {
		return _multiReturnOfMultiCall;
	}
	
	public void print(int indent) {
		printBasic(indent);
		if (_multiReturnOfMultiCall)
			printf(" multi-return-of-multi-call");
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
				nl.node.printTerse(indent + INDENT);
			}
		}
	}
 
	private void assignTypes(ref<CompileContext> compileContext) {
		ref<ParameterScope> func = compileContext.current().enclosingFunction();
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
		ref<FunctionType> functionType = func.type;
		if (functionType == null) {
			add(MessageId.NOT_A_TYPE, compileContext.pool());
			type = compileContext.errorType();
			return;
		}
		type = functionType;
		if (type.deferAnalysis())
			return;

		pointer<ref<Type>> returnTypes = functionType.returnTypes();
		int count = functionType.returnCount();
		type = compileContext.builtInType(runtime.TypeFamily.VOID);
		if (_arguments != null) {
			if (count <= 0) {
				add(MessageId.RETURN_VALUE_DISALLOWED, compileContext.pool());
				type = compileContext.errorType();
			} else {
				if (_arguments.next == null && count > 1) {
					// This is a special case that can only be valid if the one argument is a call to a function returning the same set of types.
					if (_arguments.node.op() == Operator.CALL) {
						ref<Call> call = ref<Call>(_arguments.node);
						if (call.category() != CallCategory.COERCION) {
							ref<Type> tt = call.target().type;
							if (tt.family() == runtime.TypeFamily.FUNCTION) {
								ref<FunctionType> ft = ref<FunctionType>(tt);
								if (ft.returnCount() == count) {
									pointer<ref<Type>> rtCall = ft.returnTypes();
									for (int i = 0; i < count; i++) {
										if (!rtCall[i].equals(returnTypes[i])) {
											_arguments.node.add(MessageId.CANNOT_CONVERT, compileContext.pool());
											type = compileContext.errorType();
											return;
										}
									}
								}
								_arguments.node.type = type;		// Make the called function a 'void' function for now.
								type = ft;
								_multiReturnOfMultiCall = true;
								return;								
							}
						}
					}
				}
				int i = 0;
				for (ref<NodeList> arg = _arguments; arg != null; arg = arg.next, i++)
					if (i >= count) {
						arg.node.add(MessageId.INCORRECT_RETURN_COUNT, compileContext.pool());
						type = compileContext.errorType();
						break;
					}
				if (i < count) {
					_arguments.node.add(MessageId.INCORRECT_RETURN_COUNT, compileContext.pool());
					type = compileContext.errorType();
				}
				type = returnTypes[0];
				i = 0;
				for (ref<NodeList> arg = _arguments; i < count && arg != null; arg = arg.next, i++) {
					if (returnTypes[i].deferAnalysis())
						continue;
					arg.node = arg.node.coerce(compileContext.tree(), returnTypes[i], false, compileContext);
				}
				for (ref<NodeList> arg = _arguments; arg != null; arg = arg.next) {
					if (arg.node.deferAnalysis())
						return;
				}
			}
		} else if (count > 0) {
			add(MessageId.RETURN_VALUE_REQUIRED, compileContext.pool());
			type = compileContext.errorType();
		}
	}

	public ref<NodeList> liveSymbols() {
		return _liveSymbols;
	}
}

ref<Node> simpleReturnVariable(ref<Node> argument) {
	switch (argument.op()) {
	case SEQUENCE:
		return simpleReturnVariable(ref<Binary>(argument).right());

	case VARIABLE:
	case IDENTIFIER:
		return argument;
	}
	return null;
}		

ref<Node>, int foldMultiReturn(ref<Node> leftHandle, ref<Node> destinations, ref<Variable> intermediate, int offset, ref<SyntaxTree> tree, ref<CompileContext> compileContext) {
	ref<Node> result;
	if (destinations.op() == Operator.SEQUENCE) {
		ref<Binary> b = ref<Binary>(destinations);
		ref<Node> lh;
		
		(lh, offset) = foldMultiReturn(leftHandle, b.left(), intermediate, offset, tree, compileContext);
		(result, offset) = foldMultiReturn(lh, b.right(), intermediate, offset, tree, compileContext);
	} else {
		ref<Reference> r = tree.newReference(intermediate, offset, false, destinations.location());
		r.type = destinations.type;
		ref<Node> assignment;
		if (r.type.family() == runtime.TypeFamily.STRING ||
			r.type.family() == runtime.TypeFamily.STRING16) {
			compileContext.unmarkLiveSymbol(r);
			ref<OverloadInstance> oi = getMethodSymbol(destinations, "store", r.type, compileContext);
			if (oi == null) {
				destinations.type = compileContext.errorType();
				return destinations, 0;
			}
			ref<Selection> method = tree.newSelection(destinations, oi, false, destinations.location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(r);
			ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, destinations.location(), compileContext);
			call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
			assignment = call.fold(tree, true, compileContext);
		} else {
//			compileContext.markLiveSymbol(r);
			assignment = tree.newBinary(Operator.ASSIGN, destinations, r, destinations.location());
			assignment.type = r.type;
			assignment = assignment.fold(tree, true, compileContext);
		}
		result = tree.newBinary(Operator.SEQUENCE, leftHandle, assignment, destinations.location());
		offset += destinations.type.stackSize();
	}
	result.type = compileContext.builtInType(runtime.TypeFamily.VOID);
	return result, offset;
}

ref<Node> assignOne(ref<SyntaxTree> tree, ref<Node> dest, ref<Reference> r, ref<CompileContext> compileContext) {
	if (r.type.family() == runtime.TypeFamily.STRING ||
		r.type.family() == runtime.TypeFamily.STRING16) {
		ref<OverloadInstance> oi = getMethodSymbol(dest, "store", r.type, compileContext);
		if (oi == null)
			return null;
		ref<Selection> method = tree.newSelection(dest, oi, false, dest.location());
		method.type = oi.type();
		ref<NodeList> args = tree.newNodeList(r);
		ref<Call> call = tree.newCall(oi.parameterScope(), null, method, args, dest.location(), compileContext);
		call.type = compileContext.builtInType(runtime.TypeFamily.VOID);
		return call.fold(tree, true, compileContext);
	} else {
		ref<Node> assignment = tree.newBinary(Operator.ASSIGN, dest, r, dest.location());
		assignment.type = r.type;
		return assignment.fold(tree, true, compileContext);
	}
}

