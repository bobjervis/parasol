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

	Identifier(ref<Symbol> symbol, Location location) {
		super(Operator.IDENTIFIER, location);
		_symbol = symbol;
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
//			if (_annotation != null && !_annotation.traverse(t, func, data))
//				return false;
			break;

		case	IN_ORDER:
		case	POST_ORDER:
//			if (_annotation != null && !_annotation.traverse(t, func, data))
//				return false;
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
//			if (_annotation != null && !_annotation.traverse(t, func, data))
//				return false;
			break;

		case	REVERSE_POST_ORDER:
//			if (_annotation != null && !_annotation.traverse(t, func, data))
//				return false;
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
		C.memcpy(&value[0], _value.data, _value.length);
		CompileString cs(&value);
		ref<Identifier> id = tree.newIdentifier(/*_annotation, */cs, location());
		id._annotation = _annotation;
		id._symbol = _symbol;
		id._definition = _definition;
		return ref<Identifier>(id.finishClone(this, tree.pool()));
	}

	public ref<Identifier> cloneRaw(ref<SyntaxTree> tree) {
		byte[] value;
		value.resize(_value.length);
		C.memcpy(&value[0], _value.data, _value.length);
		CompileString cs(&value);
		ref<Identifier> id = tree.newIdentifier(/*_annotation, */cs, location());
		id._annotation = _annotation;
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
			printf(" %s", string(_symbol.storageClass()));
		printf("\n");
	}

	public void markupDeclarator(ref<Type> t, boolean needsDefaultConstructor, ref<CompileContext> compileContext) {
		if (_symbol != null) {
			if (!_symbol.bindType(t, compileContext)) {
				add(MessageId.UNFINISHED_MARKUP_DECLARATOR, compileContext.pool(), CompileString("  "/*this.class.name()*/), CompileString(string(op())));
				type = compileContext.errorType();
				return;
			}
			assignTypes(compileContext);
			if (needsDefaultConstructor && t.hasConstructors()) {
				if (t.defaultConstructor() == null)
					add(MessageId.NO_DEFAULT_CONSTRUCTOR, compileContext.pool());
			}
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
			_symbol.bindType(t, compileContext);
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
			ref<ClassType> c = compileContext.pool().newClassType(TypeFamily.CLASS, ref<Type>(null), enumScope);
			ref<Type> t = compileContext.pool().newEnumInstanceType(_symbol, enumScope, c);
			enumScope.enumType = compileContext.pool().newEnumType(body, enumScope, t);
			_symbol.bindType(enumScope.enumType, compileContext);
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
		ref<ParameterScope> templateScope = compileContext.createParameterScope(templateDef, ParameterScope.Kind.TEMPLATE);
		ref<Overload> o = enclosing.defineOverload(&_value, Operator.TEMPLATE, compileContext.pool());
		if (o != null) {
			_symbol = o.addInstance(visibility, isStatic, annotations, this, templateScope, compileContext);
			if (_symbol == null)
				return;
			ref<Type> t = compileContext.makeTypedef(compileContext.pool().newTemplateType(_symbol, templateDef, templateScope.file(), o, templateScope));
			_symbol.bindType(t, compileContext);
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

	ref<Symbol> resolveAsMember(ref<Type> classType, ref<CompileContext>  compileContext) {
		_symbol = classType.scope().lookup(&_value);
		if (_symbol == null) {
			type = compileContext.errorType();
			add(MessageId.UNDEFINED, compileContext.pool(), _value);
		} else
			type = _symbol.assignType(compileContext);
		return _symbol;
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
							_symbol = (*o.instances())[0];
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
	
	ref<Node> annotation() {
		return _annotation;
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
					_symbol = (*o.instances())[0];
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