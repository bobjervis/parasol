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

class OverloadOperation {
	private boolean _done;
	private boolean _hadConstructors;
	private ref<Node> _node;
	private substring _name;
	private Operator _kind;
	private ref<Overload> _overload;
	private ref<NodeList> _arguments;
	private ref<CompileContext> _compileContext;
	private boolean _anyPotentialOverloads;
	private int _argCount;
	private ref<Symbol>[] _best;		// The set of the best matches so far.
										// If there is more than one here, it
										// means the various overloads are unordered
										// with respect to one another.

	public OverloadOperation(Operator kind, ref<Node> node, substring name, ref<NodeList> arguments, ref<CompileContext> compileContext) {
		_name = name;
//		if (_name != null)
//			printf("Overloading %s\n", _name.asString());
		_kind = kind;
		_node = node;
		_arguments = arguments;
		_compileContext = compileContext;
		for (ref<NodeList> nl = arguments; nl != null; nl = nl.next)
			_argCount++;
	}

	public ref<Type> includeClass(ref<Type>  classType, ref<CompileContext> compileContext) {
		for (ref<Type> current = classType; current != null; current = current.assignSuper(compileContext)) {
			if (current.scope() != null) {
				ref<Type> type = includeScope(compileContext.current(), current.scope());
				if (type != null)
					return type;
				if (_done)
					break;
			}
		}
		return null;
	}

	public ref<Type> includeScope(ref<Scope> lexicalScope, ref<Scope> symbolScope) {
//		string ts = "Unit";
//		if (ts == _name.asString()) {
//			printf("Looking for Unit...\n");
//			s.print(0, false);
//		}
		ref<Symbol> sym = symbolScope.lookup(_name, _compileContext);
		if (sym == null)
			return null;
//		if (ts == _name.asString())
//			sym.print(0, false);
		if (sym.class == PlainSymbol) {
			// If we see a plain symbol before any possible overloads,
			// then choose the plain symbol, and let the caller decide
			// whether that one is good enough.  Function pointers, for
			// example follow this code path.
			if (_kind == Operator.FUNCTION && !_anyPotentialOverloads) {
				_best.clear();
				_best.append(sym);
			}
			_done = true;
			// If we did see some overloads, this plain symbol must be
			// located at least one scope 'outside' the overloads and
			// so, treat the set of already seen overloads as 'masking' 
			// the plain symbol.
			return null;
		}
		// The symbol must be an 'Overload' object
		ref<Overload> o = ref<Overload>(sym);
		// If we are seeking a TEMPLATE, then an Overload full of FUNCTION's
		// are not only uninteresting, they mask any outer potential overloaded
		// definitions we might otherwise care about.
		if (o.kind() != _kind) {
			_done = true;
			return null;
		}
		if (_overload == null)
			_overload = o;
		for (int i = 0; i < o.instances().length(); i++) {
			ref<OverloadInstance> oi = (*o.instances())[i];
			_anyPotentialOverloads = true;
//			printf("Potential overload: ");
//			oi.print(0, false);
			if (!oi.isVisibleIn(lexicalScope, _compileContext))
				continue;
			ref<Type> t = includeOverload(oi);
			if (t != null)
				return t;
		}
		return null;
	}

	public ref<Type> includeOverload(ref<OverloadInstance> oi) {
		oi.assignType(_compileContext);
		if (oi.deferAnalysis())
			return oi.type();
		int count = oi.parameterCount();
//		printf("%s parameter count = %d vs %d\n", oi.name(), count, _argCount);
		if (count == int.MIN_VALUE) {
			_node.add(MessageId.NO_FUNCTION_TYPE, _compileContext.pool(), _name);
			return _compileContext.errorType();
		}
		if (count == NOT_PARAMETERIZED_TYPE) {
			_node.add(MessageId.NOT_PARAMETERIZED_TYPE, _compileContext.pool(), _name);
			return _compileContext.errorType();
		}
		boolean hasEllipsis;
		if (count < 0) {
			if (_argCount < -count - 1) 
				return null;
			hasEllipsis = true;
		} else {
			if (_argCount != count)
				return null;
			hasEllipsis = false;
		}
		// Does this overload apply to the argument list at all?
		Callable c = oi.callableWith(_arguments, hasEllipsis, _compileContext);
		if (c == Callable.DEFER)
			return _compileContext.arena().builtInType(TypeFamily.CLASS_DEFERRED);

		if (c == Callable.YES) {
			// Check against the best array.  If this is better than
			// one of the current best list, remove that one.
			// If one of the overloads is actually better than this one,
			// then discard this one.
			boolean includeOi = true;
			for (int i = 0; i < _best.length();) {
				if (oi == _best[i] ||
					_best[i].type().canOverride(oi.type(), _compileContext)) {
					includeOi = false;
					break;
				}
				int partialOrder = _best[i].partialOrder(oi, _arguments, _compileContext);
				if (partialOrder < 0) {
					if (i < _best.length() - 1)
						_best[i] = _best[_best.length() - 1];
					_best.resize(_best.length() - 1);
				} else {
					if (partialOrder > 0) {
						includeOi = false;
						break;
					}
					i++;
				}
			}
			if (includeOi)
				_best.append(oi);
		}
		return null;
	}

	public ref<Type> includeConstructors(ref<Type> classType, ref<CompileContext> compileContext) {
		if (classType.scope() != null) {
			for (int i = 0; i < classType.scope().constructors().length(); i++) {
				ref<ParameterScope> constructor = (*classType.scope().constructors())[i];
				if (constructor.kind() != ParameterScope.Kind.DEFAULT_CONSTRUCTOR)
					_hadConstructors = true;
				ref<FunctionDeclaration> f = ref<FunctionDeclaration>(constructor.definition());
				if (f == null || f.name() == null)
					continue;
				ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
				ref<Type> t = includeOverload(oi);
				if (t != null)
					return t;
			}
		}
		return null;
	}

	public ref<Type>, ref<Symbol> result() {
		// After looking at all applicable scopes, success depends on how many 'best'
		// symbols we have.
		switch (_best.length()) {
		case	1:
			return _best[0].assignType(_compileContext), _best[0];

		case	0:
//			printf("_name = %p _arguments = %p _argCount = %d _hadConstructors %s\n", _name, _arguments, _argCount, _hadConstructors ? "true" : "false");
			if (_name != null) {
				_node.add(_anyPotentialOverloads ? MessageId.NO_MATCHING_OVERLOAD : MessageId.UNDEFINED, _compileContext.pool(), _name);
//				_node.print(2);
//				for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
//					nl.node.print(6);
			} else if (_arguments == null && !_hadConstructors)
				return _compileContext.arena().builtInType(TypeFamily.VOID), null;
			else
				_node.add(MessageId.NO_MATCHING_CONSTRUCTOR, _compileContext.pool());
			break;

		default:
			if (_name != null)
				_node.add(MessageId.AMBIGUOUS_OVERLOAD, _compileContext.pool(), _name);
			else
				_node.add(MessageId.AMBIGUOUS_CONSTRUCTOR, _compileContext.pool());
		}
		return _compileContext.errorType(), null;
	}

	public boolean anyPotentialOverloads() {
		return _anyPotentialOverloads;
	}

	public void restart() {
		_done = false;
		_best.clear();
		_anyPotentialOverloads = false;
	}

	public boolean done() {
		return _done;
	}
}
