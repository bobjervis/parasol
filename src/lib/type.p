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

enum TypeFamily {
	// numeric types
	
	SIGNED_8,
	SIGNED_16,
	SIGNED_32,
	SIGNED_64,
	UNSIGNED_8,
	UNSIGNED_16,
	UNSIGNED_32,
	UNSIGNED_64,
	FLOAT_32,
	FLOAT_64,
	
	BOOLEAN,
	
	STRING,
	VAR,
	ADDRESS,
	VOID,
	ERROR,
	EXCEPTION,
	CLASS_VARIABLE,
	CLASS_DEFERRED,
	NAMESPACE,
	ARRAY_AGGREGATE,
	OBJECT_AGGREGATE,
	BUILTIN_TYPES,
	
	CLASS,
	ENUM,
	FLAGS,
	TYPEDEF,
	FUNCTION,
	SHAPE,
	REF,
	POINTER,
	TEMPLATE,
	TEMPLATE_INSTANCE,
	MAX_TYPES
//	MIN_TYPE = SIGNED_8
}

class BuiltInType extends Type {
	private ref<ClassType> _classType;

	BuiltInType(TypeFamily family, ref<ClassType> classType) {
		super(family);
		_classType = classType;
//		print();
//		printf("\n");
	}

	public void print() {
		printf("%s %p(", string(family()), _classType);
		if (_classType == null)
			printf("<null>");
		else
			_classType.print();
		printf(")");
	}

	public int parameterCount() {
		assert(false);
		return 0;
	}

	public ref<Scope> scope() {
		if (_classType == null)
			return null;
		else
			return _classType.scope();
	}

	public boolean hasVtable(ref<CompileContext> compileContext) {
		if (_classType == null)
			return false;
		else
			return _classType.hasVtable(compileContext);
	}

	public ref<OverloadInstance> initialConstructor() {
		if (_classType == null)
			return null;
		else
			return _classType.initialConstructor();
	}

	public boolean hasDefaultConstructor() {
		if (_classType == null)
			return false;
		else
			return _classType.hasDefaultConstructor();
	}
	
	public ref<ParameterScope> defaultConstructor() {
		if (_classType == null)
			return null;
		else
			return _classType.defaultConstructor();
	}
	
	public ref<Type> assignSuper(ref<CompileContext> compileContext) {
		if (_classType == null)
			return null;
		else
			return _classType.assignSuper(compileContext);
	}

	public ref<Type> getSuper() {
		if (_classType == null)
			return null;
		else
			return _classType.getSuper();
	}

	public boolean widensTo(ref<Type> other, ref<CompileContext> compileContext) {
		if (int(other.family()) >= int(TypeFamily.BUILTIN_TYPES))
			return super.widensTo(other, compileContext);
		else
			return widens[family()][other.family()];
	}

	public ref<ClassType> classType() {
		return _classType;
	}

	public boolean equals(ref<Type> other) {
		// A built in type is unique, so one is always equal to itself...
		if (this == other)
			return true;
		// CLASS_VARIABLE has one special case: these match TYPEDEF
		if (family() == TypeFamily.CLASS_VARIABLE && other.family() == TypeFamily.TYPEDEF)
			return true;
		// or as a special case, ERROR type has no underlying class, so it can only
		// equal itself.
		if (_classType == null)
			return false;
		// or the class type it was created from.
		return _classType.equals(other);
	}

	public boolean extendsFormally(ref<Type> other, ref<CompileContext> compileContext) {
		// A built in type is unique, so one is always equal to itself...
		if (this == other)
			return true;
		if (_classType == null)
			return false;
		// or the class type it was created from.
		return _classType.extendsFormally(other, compileContext);
	}
	
	public boolean returnsViaOutParameter(ref<CompileContext> compileContext) {
		return family() == TypeFamily.VAR;
	}
	
	public boolean passesViaStack(ref<CompileContext> compileContext) {
		return family() == TypeFamily.VAR;
	}
	
	public int copyToImage(ref<Target> target) {
		if (_ordinal == 0) {
			allocateImageData(target, BuiltInType.bytes);
			target.fixupVtable(_ordinal, target.builtInType());
			_classType.copyToImage(target);
			target.fixupType(_ordinal + int(&ref<BuiltInType>(null)._classType), _classType);
		}
		return _ordinal;
	}
	
	public string signature() {
		return builtinName[family()];
	}
}

boolean[TypeFamily][TypeFamily] widens;

widens.resize(TypeFamily.BUILTIN_TYPES);
fill();
void fill() {
	for (int i = 0; i < int(TypeFamily.BUILTIN_TYPES); i++)
		widens[TypeFamily(i)].resize(TypeFamily.BUILTIN_TYPES);
}
widens[TypeFamily.SIGNED_8][TypeFamily.SIGNED_8] = true;
widens[TypeFamily.SIGNED_8][TypeFamily.SIGNED_16] = true;
widens[TypeFamily.SIGNED_8][TypeFamily.SIGNED_32] = true;
widens[TypeFamily.SIGNED_8][TypeFamily.SIGNED_64] = true;
widens[TypeFamily.SIGNED_8][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.SIGNED_8][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.SIGNED_8][TypeFamily.VAR] = true;
widens[TypeFamily.SIGNED_16][TypeFamily.SIGNED_16] = true;
widens[TypeFamily.SIGNED_16][TypeFamily.SIGNED_32] = true;
widens[TypeFamily.SIGNED_16][TypeFamily.SIGNED_64] = true;
widens[TypeFamily.SIGNED_16][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.SIGNED_16][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.SIGNED_16][TypeFamily.VAR] = true;
widens[TypeFamily.SIGNED_32][TypeFamily.SIGNED_32] = true;
widens[TypeFamily.SIGNED_32][TypeFamily.SIGNED_64] = true;
widens[TypeFamily.SIGNED_32][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.SIGNED_32][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.SIGNED_32][TypeFamily.VAR] = true;
widens[TypeFamily.SIGNED_64][TypeFamily.SIGNED_64] = true;
widens[TypeFamily.SIGNED_64][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.SIGNED_64][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.SIGNED_64][TypeFamily.VAR] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.SIGNED_16] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.SIGNED_32] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.SIGNED_64] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.UNSIGNED_8] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.UNSIGNED_16] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.UNSIGNED_32] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.UNSIGNED_64] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.UNSIGNED_8][TypeFamily.VAR] = true;
widens[TypeFamily.UNSIGNED_16][TypeFamily.SIGNED_32] = true;
widens[TypeFamily.UNSIGNED_16][TypeFamily.SIGNED_64] = true;
widens[TypeFamily.UNSIGNED_16][TypeFamily.UNSIGNED_16] = true;
widens[TypeFamily.UNSIGNED_16][TypeFamily.UNSIGNED_32] = true;
widens[TypeFamily.UNSIGNED_16][TypeFamily.UNSIGNED_64] = true;
widens[TypeFamily.UNSIGNED_16][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.UNSIGNED_16][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.UNSIGNED_16][TypeFamily.VAR] = true;
widens[TypeFamily.UNSIGNED_32][TypeFamily.SIGNED_64] = true;
widens[TypeFamily.UNSIGNED_32][TypeFamily.UNSIGNED_32] = true;
widens[TypeFamily.UNSIGNED_32][TypeFamily.UNSIGNED_64] = true;
widens[TypeFamily.UNSIGNED_32][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.UNSIGNED_32][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.UNSIGNED_32][TypeFamily.VAR] = true;
widens[TypeFamily.UNSIGNED_64][TypeFamily.UNSIGNED_64] = true;
widens[TypeFamily.UNSIGNED_64][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.UNSIGNED_64][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.UNSIGNED_64][TypeFamily.VAR] = true;
widens[TypeFamily.FLOAT_32][TypeFamily.FLOAT_32] = true;
widens[TypeFamily.FLOAT_32][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.FLOAT_32][TypeFamily.VAR] = true;
widens[TypeFamily.FLOAT_64][TypeFamily.FLOAT_64] = true;
widens[TypeFamily.FLOAT_64][TypeFamily.VAR] = true;
widens[TypeFamily.BOOLEAN][TypeFamily.BOOLEAN] = true;
widens[TypeFamily.BOOLEAN][TypeFamily.VAR] = true;
widens[TypeFamily.STRING][TypeFamily.STRING] = true;
widens[TypeFamily.STRING][TypeFamily.VAR] = true;
widens[TypeFamily.VAR][TypeFamily.VAR] = true;
widens[TypeFamily.EXCEPTION][TypeFamily.EXCEPTION] = true;
widens[TypeFamily.ADDRESS][TypeFamily.VAR] = true;
widens[TypeFamily.ADDRESS][TypeFamily.ADDRESS] = true;
widens[TypeFamily.CLASS_VARIABLE][TypeFamily.CLASS_VARIABLE] = true;
widens[TypeFamily.CLASS_DEFERRED][TypeFamily.CLASS_DEFERRED] = true;

class MonitorType extends ClassType {
	MonitorType(ref<Class> definition, ref<Scope> scope) {
		super(definition, scope);
	}

	public  ref<Type> assignSuper(ref<CompileContext> compileContext) {
		if (_extends == null)
			_extends = compileContext.monitorClass();
		return _extends;
	}
	
	public boolean isMonitor() {
		return true;
	}	
}

class InterfaceType extends ClassType {
	InterfaceType(ref<Class> definition, ref<Scope> scope) {
		super(definition, scope);
	}
	
	public boolean isInterface() {
		return true;
	}

//	public string signature() {
//		return "interface " + super.signature();
//	}	
}

class ClassType extends Type {
	protected ref<Scope> _scope;
	protected ref<Type> _extends;
	protected ref<Class> _definition;

	ClassType(ref<Class> definition, ref<Scope> scope) {
		super(TypeFamily.CLASS);
		_definition = definition;
		_scope = scope;
	}

	ClassType(TypeFamily effectiveFamily, ref<Type> base, ref<Scope> scope) {
		super(effectiveFamily);
		_scope = scope;
		_extends = base;
	}

	public void print() {
		pointer<address> pa = pointer<address>(this);
		printf("%s(%p) %p scope %p", string(family()), pa[1], _definition, _scope);
	}

	public ref<OverloadInstance> initialConstructor() {
		for (int i = 0; i < _scope.constructors().length(); i++) {
			ref<ParameterScope> scope = ref<ParameterScope>((*_scope.constructors())[i]);
			if (scope.parameters().length() == 1) {
				ref<Type> paramType = (*scope.parameters())[0].type();
				if (paramType.class == BuiltInType)
					paramType = ref<BuiltInType>(paramType).classType();
				if (paramType == this) {
					ref<FunctionDeclaration> f = ref<FunctionDeclaration>(scope.definition());
					return ref<OverloadInstance>(f.name().symbol());
				}
			}
		}
		return null;
	}
	
	public ref<ParameterScope> defaultConstructor() {
		for (int i = 0; i < _scope.constructors().length(); i++) {
			ref<ParameterScope> scope = ref<ParameterScope>((*_scope.constructors())[i]);
			if (scope.parameters().length() == 0)
				return scope;
		}
		return null;
	}
	
	public boolean hasDefaultConstructor() {
		for (int i = 0; i < _scope.constructors().length(); i++) {
			ref<ParameterScope> scope = ref<ParameterScope>((*_scope.constructors())[i]);
			if (scope.parameters().length() == 0)
				return true;
		}
		return false;
	}
	
	public void assignSize(ref<Target> target, ref<CompileContext> compileContext) {
		_scope.assignVariableStorage(target, compileContext);
		ref<Type> base = assignSuper(compileContext);
	}

	public void checkSize(ref<CompileContext> compileContext) {
		_scope.checkVariableStorage(compileContext);
		assignSuper(compileContext);
	}

	public int size() {
		return _scope.variableStorage;
	}

	public int alignment() {
		int baseAlignment = 1;
		if (_extends != null)
			baseAlignment = _extends.alignment();
		int internalAlignment = _scope.maximumAlignment();
		if (baseAlignment > internalAlignment)
			return baseAlignment;
		else
			return internalAlignment;
	}

	public boolean returnsViaOutParameter(ref<CompileContext> compileContext) {
		return indirectType(compileContext) == null;
	}
	
	public boolean passesViaStack(ref<CompileContext> compileContext) {
		return indirectType(compileContext) == null;
	}
	
	public ref<Scope> scope() {
		return _scope;
	}

	public boolean equals(ref<Type> other) {
		// A class type is unique, so one is always equal to itself...
		if (this == other)
			return true;
		// or the built-in type created from it.
		if (other.isBuiltIn()) {
			ref<BuiltInType> b = ref<BuiltInType>(other);
			return this == b.classType();
		} else
			return false;
	}

	public  ref<Type> assignSuper(ref<CompileContext> compileContext) {
		resolve(compileContext);
		return _extends;
	}

	public ref<Type> getSuper() {
		return _extends;
	}
	
	public boolean extendsFormally(ref<Type> other, ref<CompileContext> compileContext) {
		if (this == other)
			return true;
		if (_definition != null)
			resolve(compileContext);
		if (_extends == null)
			return false;
		if (_extends.equals(other) || 
			_extends.extendsFormally(other, compileContext))
			return true;
		else
			return false;
	}

	public boolean isConcrete(ref<CompileContext> compileContext) {
		return _scope.isConcrete(compileContext);
	}

	public boolean hasVtable(ref<CompileContext> compileContext) {
		return _scope.hasVtable(compileContext);
	}

	public ref<Class> definition() {
		return _definition;
	}

	public string signature() {
		if (_definition != null && _definition.name() != null)
			return _definition.name().identifier().asString();
		else
			return super.signature();
	}
	
	private boolean sameAs(ref<Type> other) {
		// Two classes are considered the same only
		// if they have the same declaration site, which
		// is equivalent to object identity on the type
		// object.
		return false;
	}

	protected void doResolve(ref<CompileContext> compileContext) {
		if (_definition != null) {
			ref<Node> base = _definition.extendsClause();
			if (base != null) {
				compileContext.assignTypes(_scope.enclosing(), base);
				_extends = base.unwrapTypedef(isInterface() ? Operator.INTERFACE : Operator.CLASS, compileContext);
			}
		}
	}

	public int copyToImage(ref<Target> target) {
		if (_ordinal == 0) {
			allocateImageData(target, ClassType.bytes);
			target.fixupVtable(_ordinal, target.classType());
			if (_extends != null)
				_extends.copyToImage(target);
			target.fixupType(_ordinal + int(&ref<ClassType>(null)._extends), _extends);
		}
		return _ordinal;
	}
	
}

class EnumType extends TypedefType {
	private ref<Block> _definition;
	private ref<Scope> _scope;

	EnumType(ref<Block> definition, ref<Scope> scope, ref<Type> wrappedType) {
		super(TypeFamily.TYPEDEF, wrappedType);
		_definition = definition;
		_scope = scope;
	}

	public int size() {
		if (family() == TypeFamily.TYPEDEF) {
			return int.bytes * _scope.symbols().size();
		} else
			return int.bytes;
	}

	boolean requiresAutoStorage() {
		return true;
	}

	public void print() {
		printf("%s %p", string(family()), _definition);
	}

	public ref<Scope> scope() {
		return _scope;
	}

	public boolean equals(ref<Type> other) {
		assert(false);
		return false;
	}

	private boolean sameAs(ref<Type> other) {
		assert(false);
		return false;
	}
}

class EnumInstanceType extends Type {
	private ref<Symbol> _symbol;
	private ref<Scope> _scope;
	private ref<ClassType> _instanceClass;
	
	private ref<ParameterScope> _toStringMethod;

	protected EnumInstanceType(ref<Symbol> symbol, ref<Scope> scope, ref<ClassType> instanceClass) {
		super(TypeFamily.ENUM);
		_symbol = symbol;
		_scope = scope;
		_instanceClass = instanceClass;
	}

	public void print() {
		printf("%s %p", string(family()), _instanceClass);
	}

	public ref<Scope> scope() {
		return _scope;
	}

	public boolean equals(ref<Type> other) {
		// An enum type is unique, so one is always equal to itself...
		return this == other;
	}

	public ref<Symbol> symbol() {
		return _symbol;
	}

	private boolean sameAs(ref<Type> other) {
		// Two enums are considered the same only
		// if they have the same declaration site, which
		// is equivalent to object identity on the type
		// object.
		return false;
	}
	
	public ref<ParameterScope> toStringMethod(ref<Target> target, ref<CompileContext> compileContext) {
		if (_toStringMethod == null)
			_toStringMethod = target.generateEnumToStringMethod(this, compileContext);
		return _toStringMethod;
	}
}

class FlagsType extends TypedefType {
	private ref<Block> _definition;
	private ref<Scope> _scope;

	FlagsType(ref<Block> definition, ref<Scope> scope, ref<Type> wrappedType) {
		super(TypeFamily.TYPEDEF, wrappedType);
		_definition = definition;
		_scope = scope;
	}

	boolean requiresAutoStorage() {
		return true;
	}

	public void print() {
		printf("%s %p", string(family()), _definition);
	}

	public ref<Scope> scope() {
		return _scope;
	}

	public boolean equals(ref<Type> other) {
		assert(false);
		return false;
	}

	private boolean sameAs(ref<Type> other) {
		assert(false);
		return false;
	}
}

class FlagsInstanceType extends Type {
	private ref<Symbol> _symbol;
	private ref<Scope> _scope;
	private ref<ClassType> _instanceClass;
	
	private ref<ParameterScope> _toStringMethod;

	protected FlagsInstanceType(ref<Symbol> symbol, ref<Scope> scope, ref<ClassType> instanceClass) {
		super(TypeFamily.FLAGS);
		_symbol = symbol;
		_scope = scope;
		_instanceClass = instanceClass;
	}

	public void print() {
		printf("%s %p", string(family()), _instanceClass);
	}

	public ref<Scope> scope() {
		return _scope;
	}

	public int size() {
		int numberOfFlags = _scope.symbols().size();
		
		if (numberOfFlags <= 8)
			return byte.bytes;
		else if (numberOfFlags <= 16)
			return short.bytes;
		else if (numberOfFlags <= 32)
			return int.bytes;
		else
			return long.bytes;
	}

	public int alignment() {
		int numberOfFlags = _scope.symbols().size();
		
		if (numberOfFlags <= 8)
			return byte.bytes;
		else if (numberOfFlags <= 16)
			return short.bytes;
		else if (numberOfFlags <= 32)
			return int.bytes;
		else
			return long.bytes;
	}
	
	public boolean widensTo(ref<Type> other, ref<CompileContext> compileContext) {
		if (other.family() == TypeFamily.BOOLEAN)
			return true;
		else
			return super.widensTo(other, compileContext);
	}

	public boolean equals(ref<Type> other) {
		// An enum type is unique, so one is always equal to itself...
		return this == other;
	}

	public ref<Symbol> symbol() {
		return _symbol;
	}

	private boolean sameAs(ref<Type> other) {
		// Two enums are considered the same only
		// if they have the same declaration site, which
		// is equivalent to object identity on the type
		// object.
		return false;
	}
	
	public ref<ParameterScope> toStringMethod(ref<Target> target, ref<CompileContext> compileContext) {
		if (_toStringMethod == null)
			_toStringMethod = target.generateFlagsToStringMethod(this, compileContext);
		return _toStringMethod;
	}
}

class FunctionType extends Type {
	private ref<NodeList> _returnType;
	private ref<NodeList> _parameters;
	private ref<ParameterScope> _functionScope;

	FunctionType(ref<NodeList> returnType, ref<NodeList> parameters, ref<Scope> functionScope) {
		super(TypeFamily.FUNCTION);
		_returnType = returnType;
		_parameters = parameters;
		_functionScope = ref<ParameterScope>(functionScope);
	}

	public int parameterCount() {
		if (_functionScope != null) {
			if (_functionScope.hasEllipsis())
				return -_functionScope.parameters().length();
			else
				return _functionScope.parameters().length();
		} else {
			int count = 0;
			for (ref<NodeList> nl = _parameters; nl != null; nl = nl.next)
				count++;
			return count;
		}
	}

	public int returnCount() {
		int i = 0;
		for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next)
			i++;
		return i;
	}
	
	public boolean widensTo(ref<Type> other, ref<CompileContext> compileContext) {
		if (this == other)
			return true;
		if (other == compileContext.arena().builtInType(TypeFamily.VAR))
			return true;
		if (other.family() != TypeFamily.FUNCTION)
			return false;
		return equals(other);
	}

	public int fixedArgsSize(ref<Target> target, ref<CompileContext> compileContext) {
		int size = 0;

		for (int i = 0; i < _functionScope.parameters().length(); i++) {
			ref<Type> t = (*_functionScope.parameters())[i].type();
			t.assignSize(target, compileContext);
			size += t.stackSize();
		}
		return size;
	}

	public int returnSize(ref<Target> target, ref<CompileContext> compileContext) {
		if (_returnType == null)
			return 0;
		int returnBytes = 0;
		for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next) {
			nl.node.type.assignSize(target, compileContext);
			returnBytes += nl.node.type.stackSize();
		}
		return returnBytes;
	}

	public ref<Scope> scope() {
		return _functionScope;
	}
	
	public ref<NodeList> parameters() {
		return _parameters;
	}

	public ref<NodeList> returnType() {
		return _returnType;
	}

	public ref<Type> returnValueType() {	// type of this function call when used in an expression
		if (_returnType == null)
			return null;
		else
			return _returnType.node.type;
	}
	
	private boolean sameAs(ref<Type> other) {
		ref<NodeList> nlThis;
		ref<NodeList> nlOther;
		ref<FunctionType> otherFunction = ref<FunctionType>(other);

		for (nlThis = _returnType, nlOther = otherFunction._returnType; ; nlThis = nlThis.next, nlOther = nlOther.next) {
			if (nlThis == null) {
				if (nlOther != null)
					return false;
				else
					break;
			} else if (nlOther == null)
				return false;
			
			if (!nlThis.node.type.equals(nlOther.node.type))
				return false;
		}
		return sameParameters(otherFunction);
	}

	public boolean canOverride(ref<Type> other, ref<CompileContext> compileContext) {
		ref<NodeList> nlThis;
		ref<NodeList> nlOther;
		ref<FunctionType> otherFunction = ref<FunctionType>(other);

		for (nlThis = _returnType, nlOther = otherFunction._returnType; ; nlThis = nlThis.next, nlOther = nlOther.next) {
			if (nlThis == null) {
				if (nlOther != null)
					return false;
				else
					break;
			} else if (nlOther == null)
				return false;
			if (!nlThis.node.type.equals(nlOther.node.type)) {
				// A pointer return type can point to 
				if (nlThis.node.type.indirectType(compileContext) != null &&
					nlOther.node.type.indirectType(compileContext) != null &&
					nlThis.node.type.widensTo(nlOther.node.type, compileContext))
					continue;
				return false;
			}
		}
		return sameParameters(otherFunction);
	}

	private boolean sameParameters(ref<FunctionType> other) {
		ref<NodeList> nlThis;
		ref<NodeList> nlOther;

		for (nlThis = _parameters, nlOther = other._parameters; ; nlThis = nlThis.next, nlOther = nlOther.next) {
			if (nlThis == null) {
				return nlOther == null;
			} else if (nlOther == null)
				return false;
			if (!nlThis.node.type.equals(nlOther.node.type))
				return false;
		}
		return true;
	}

	public boolean extendsFormally(ref<Type> other, ref<CompileContext> compileContext) {
//		assert(false);
		return false;
	}

	public void print() {
		printf("%s %d <- %d", string(family()), returnCount(), parameterCount());
	}

	public string signature() {
		string sig;
		// First, format the return type(s).
		if (_returnType == null)
			sig = "<void>";
		else if (_returnType.next == null)
			sig = _returnType.node.type.signature();
		else {
			sig = "(";
			for (ref<NodeList> nl = _returnType; nl != null; nl = nl.next) {
				sig.append(nl.node.type.signature());
				if (nl.next != null)
					sig.append(',');
				else
					sig.append(')');
			}
		}
		sig.append('(');
		if (_parameters == null)
			sig.append(')');
		else {
			for (ref<NodeList> nl = _parameters; nl != null; nl = nl.next) {
				if (nl.node == null)
					sig.append("<node:null>");
				else if (nl.node.type == null)
					sig.append("<null>");
				else
					sig.append(nl.node.type.signature());
				if (nl.next != null)
					sig.append(',');
				else
					sig.append(')');
			}
		}
		return sig;
	}
}

class TemplateType extends Type {
	private ref<Template> _definition;
	private ref<FileStat> _definingFile;
	private ref<Overload> _overload;
	private ref<Scope> _templateScope;
	private ref<Type> _extends;
	private ref<Symbol> _definingSymbol;

	TemplateType(ref<Symbol> symbol, ref<Template> definition, ref<FileStat>  definingFile, ref<Overload> overload, ref<Scope> templateScope) {
		super(TypeFamily.TEMPLATE);
		_definingSymbol = symbol;
		_definition = definition;
		_definingFile = definingFile;
		_overload = overload;
		_templateScope = templateScope;
	}

	public void print() {
		printf("%s %p scope %p", string(family()), _definition, _templateScope);
	}

	public int parameterCount() {
		assert(false);
		return 0;
	}

	public ref<Scope> scope() {
		return _templateScope;
	}

	public  ref<Type> assignSuper(ref<CompileContext> compileContext) {
		assert(false);
		return null;
	}

	public ref<Type> getSuper() {
		assert(false);
		return null;
	}

	public ref<FileStat> definingFile() {
		return _definingFile;
	}

	public ref<Template> definition() {
		return _definition;
	}
	
	public ref<Symbol> definingSymbol() {
		return _definingSymbol;
	}

	public string signature() {
		return definingSymbol().name().asString();
	}
	
	private boolean sameAs(ref<Type> other) {
		assert(false);
		return false;
	}	

	public boolean extendsFormally(ref<Type> other, ref<CompileContext> compileContext) {
		resolve(compileContext);
		if (_extends == null)
			return false;
		return _extends.extendsFormally(other, compileContext);
	}

	protected void doResolve(ref<CompileContext> compileContext) {
		ref<Node> base = _definition.classDef.extendsClause();
		if (base != null) {
			compileContext.assignTypes(_templateScope, base);
			_extends = base.unwrapTypedef(Operator.CLASS, compileContext);
		}
	}
}

class TemplateInstanceType extends ClassType {
	private ref<TemplateInstanceType> _next;
	private ref<Template> _concreteDefinition;
	private ref<FileStat> _definingFile;
	private var[] _arguments;
	private ref<TemplateType> _templateType;

	TemplateInstanceType(ref<TemplateType> templateType, var[] args, ref<Template> concreteDefinition, ref<FileStat> definingFile, ref<Scope> scope, ref<TemplateInstanceType> next, ref<MemoryPool> pool) {
		super(templateType.definingSymbol().effectiveFamily(), ref<Type>(null), scope);
		for (int i = 0; i < args.length(); i++)
			_arguments.append(args[i], pool);
		_definingFile = definingFile;
		_templateType = templateType;
		_next = next;
		_concreteDefinition = concreteDefinition;
	}

	public ref<Type> indirectType(ref<CompileContext> compileContext) {
		if (!_templateType.extendsFormally(compileContext.arena().builtInType(TypeFamily.ADDRESS), compileContext))
			return null;
		if (_arguments.length() != 1)
			return null;
		return ref<Type>(_arguments[0]);
	}

	// Vector sub-types
	
	public ref<Type> elementType(ref<CompileContext> compileContext) {
		return ref<Type>(_arguments[0]);
	}
	
	public ref<Type> indexType(ref<CompileContext> compileContext) {
		return ref<Type>(_arguments[1]);
	}

	public boolean isPointer(ref<CompileContext> compileContext) {
		if (!_templateType.extendsFormally(compileContext.arena().builtInType(TypeFamily.ADDRESS), compileContext))
			return false;
		if (_arguments.length() != 1)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(compileContext.arena().pointerTemplate().type());
		return tt.wrappedType() == _templateType;
	}

	public boolean isVector(ref<CompileContext> compileContext) {
		if (_arguments.length() != 2)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(compileContext.arena().vectorTemplate().type());
		return tt.wrappedType() == _templateType;
	}

	public boolean isMap(ref<CompileContext> compileContext) {
		if (_arguments.length() != 2)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(compileContext.arena().mapTemplate().type());
		return tt.wrappedType() == _templateType;
	}

	public ref<Type> shapeType() {
		return null;
	}

	public boolean extendsFormally(ref<Type> other, ref<CompileContext> compileContext) {
		ref<Type> base = assignSuper(compileContext);
		if (base != null)
			return base.equals(other) || base.extendsFormally(other, compileContext);
		else
			return false;
	}

	protected void doResolve(ref<CompileContext> compileContext) {
		ref<Node> base = _concreteDefinition.classDef.extendsClause();
		if (base != null) {
			compileContext.assignTypes(_scope.enclosing(), base);
			_extends = base.unwrapTypedef(Operator.CLASS, compileContext);
		}
	}

	public boolean match(var[] args) {
		if (args.length() != _arguments.length())
			return false;
		for (int i = 0; i < args.length(); i++) {
			ref<Type> a1 = ref<Type>(args[i]);
			ref<Type> a2 = ref<Type>(_arguments[i]);
			if (!a1.equals(a2))
				return false;
		}
		return true;
	}

	public int copyToImage(ref<Target> target) {
		if (_ordinal == 0) {
			address a = allocateImageData(target, TemplateInstanceType.bytes);
			ref<TemplateInstanceType> t = ref<TemplateInstanceType>(a);
//			*t = *this;
//			*ref<long>(t) = 0;
//			t._concreteDefinition = null;
//			t._definingFile = null;
//			t._next = null;
//			memset(&t._arguments, 0, t._arguments.bytes);
//			t._arguments.clear();
//			t._templateType = null;
//			t._extends = null;
//			t._scope = null;
//			t._definition = null;
			// TODO: patch up the _arguments, _templateType, _next, etc.
			// TODO: patchup _extends, _scope, _definition
		}
		return _ordinal;
	}
	
	public void print() {
		printf("TemplateInstanceType %s <", string(family()));
		for (int i = 0; i < _arguments.length(); i++) {
			if (i > 0)
				printf(", ");
			ref<Type> t = ref<Type>(_arguments[i]);
			t.print();
		}
		printf(">");
		if (_extends != null) {
			printf(" extends ");
			_extends.print();
		}
	}

	public string signature() {
		string sig = _templateType.signature();
		sig.append('<');
		
		for (int i = 0; i < _arguments.length(); i++) {
			if (i > 0)
				sig.append(", ");
			ref<Type> t = ref<Type>(_arguments[i]);
			sig.append(t.signature());
		}
		sig.append(">");
		if (_extends != null) {
			sig.append(" extends ");
			sig.append(_extends.signature());
		}
		return sig;
	}
	
	public ref<TemplateInstanceType> next() {
		return _next;
	}

	public ref<Template> concreteDefinition() { 
		return _concreteDefinition; 
	}

	public ref<FileStat> definingFile() { 
		return _definingFile; 
	}

	private boolean sameAs(ref<Type> other) {
		return false;
	}
}

class TypedefType extends Type {
	private ref<Type> _wrappedType;

	protected TypedefType(TypeFamily family, ref<Type> wrappedType) {
		super(family);
		_wrappedType = wrappedType;
	}

	public void print() {
		printf("%s ", string(family()));
		if (_wrappedType != null)
			_wrappedType.print();
		else
			printf("<null>");
	}

	public string signature() {
		if (_wrappedType != null)
			return "class (" + _wrappedType.signature() + ")";
		else
			return "class";
	}
	
	public ref<Type> wrappedType() {
		return _wrappedType;
	}

	public boolean equals(ref<Type> other) {
		// All TypedefType's have the same type, the wrapped type is actually the (compile time) value of the
		// type.
		return true;
	}

	public boolean extendsFormally(ref<Type> other, ref<CompileContext> compileContext) {
		if (other.family() == TypeFamily.TYPEDEF ||
			other.family() == TypeFamily.CLASS_VARIABLE)
			return true;
		else
			return false;
	}
}

enum CompareMethodCategory {
	ORDERED,
	PARTIALLY_ORDERED,
	UNORDERED,
	NOT_COMPARABLE
}

boolean comparable(CompareMethodCategory category) {
	return category != CompareMethodCategory.NOT_COMPARABLE;
}

public CompareMethodCategory compareMethodCategory(ref<Type> type, ref<CompileContext> compileContext) {
	ref<OverloadInstance> sym = type.compareMethod(compileContext);
	if (sym == null)
		return CompareMethodCategory.NOT_COMPARABLE;
	// TODO: Finish this for code gen.
	assert(false);
	return CompareMethodCategory.ORDERED;
}
	
class Type {
	private TypeFamily _family;
	private boolean _resolved;
	private boolean _resolving;

	protected int _ordinal;				// Assigned by type-refs: first one gets the 'real' value
	
	Type(TypeFamily family) {
		_family = family;
		if (this.class != BuiltInType)
			assert(family != TypeFamily.ERROR);
	}

	public void print() {
		printf("%s", string(_family));
		if (_ordinal != 0)
			printf(" ord [0x%x]", _ordinal);
	}

	public string name() {
		return string(_family);
	}
	
	public string signature() {
		return string(_family);
	}
	
	public TypeFamily scalarFamily(ref<CompileContext> compileContext) {
		if (_family == TypeFamily.SHAPE) {
			ref<Type> t = elementType(compileContext);
			if (t == null)
				return TypeFamily.ERROR;
			else
				return t.family();
		} else
			return _family;
	}
	
	public ref<Type> scalarType(ref<CompileContext> compileContext) {
		if (_family == TypeFamily.SHAPE)
			return elementType(compileContext);
		else
			return this;	
	}
	
	public ref<Type> shapeType() {
		if (_family == TypeFamily.SHAPE)
			return this;
		else
			return null;	
	}
	
	public void assignSize(ref<Target> target, ref<CompileContext> compileContext) {
	}

	public void checkSize(ref<CompileContext> compileContext) {
	}

	public int size() {
		return familySize[_family];
	}

	public int stackSize() {
		return (size() + address.bytes - 1) & ~(address.bytes - 1);
	}

	public int alignment() {
		return familyAlignment[_family];
	}
	
	public int parameterCount() {
		assert(false);
		return 0;
	}

	public ref<OverloadInstance> assignmentMethod(ref<CompileContext> compileContext) {
		CompileString name("copy");
		
		ref<Symbol> sym = lookup(&name, compileContext);
		if (sym != null && sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			for (int i = 0; i < o.instances().length(); i++) {
				ref<OverloadInstance> oi = (*o.instances())[i];
				if (oi.parameterCount() != 1)
					continue;
				if ((*oi.parameterScope().parameters())[0].type() == this)
					return oi;
			}
		}
		return null;
	}

	public ref<OverloadInstance> tempAssignmentMethod(ref<CompileContext> compileContext) {
		CompileString name("copyTemp");
		
		ref<Symbol> sym = lookup(&name, compileContext);
		if (sym != null && sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			for (int i = 0; i < o.instances().length(); i++) {
				ref<OverloadInstance> oi = (*o.instances())[i];
				if (oi.parameterCount() != 1)
					continue;
				if ((*oi.parameterScope().parameters())[0].type() == this)
					return oi;
			}
		}
		return null;
	}

	public ref<OverloadInstance> storeMethod(ref<CompileContext> compileContext) {
		CompileString name("store");
		
		ref<Symbol> sym = lookup(&name, compileContext);
		if (sym != null && sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			for (int i = 0; i < o.instances().length(); i++) {
				ref<OverloadInstance> oi = (*o.instances())[i];
				if (oi.parameterCount() != 1)
					continue;
				if ((*oi.parameterScope().parameters())[0].type() == this)
					return oi;
			}
		}
		return null;
	}

	public ref<ParameterScope> copyConstructor() {
		if (scope() == null)
			return null;
		for (int i = 0; i < scope().constructors().length(); i++) {
			ref<FunctionDeclaration> f = ref<FunctionDeclaration>((*scope().constructors())[i].definition());
			if (f == null)
				continue; // default constructors should be ignored.
			ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
			if (oi.parameterCount() != 1)
				continue;
			if ((*oi.parameterScope().parameters())[0].type() == this)
				return oi.parameterScope();
		}
		return null;
	}

	public ref<OverloadInstance> initialConstructor() {
		return null;
	}
	
	public boolean hasDefaultConstructor() {
		return false;
	}
	
	public ref<ParameterScope> defaultConstructor() {
		return null;
	}
	
	public ref<OverloadInstance> stringAllocationConstructor(ref<CompileContext> compileContext) {
		if (scope() == null)
			return null;
		for (int i = 0; i < scope().constructors().length(); i++) {
			ref<FunctionDeclaration> f = ref<FunctionDeclaration>((*scope().constructors())[i].definition());
			ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
			if (oi.parameterCount() != 1)
				continue;
			ref<Type> parameterType = (*oi.parameterScope().parameters())[0].type();
			ref<Type> allocationType = parameterType.indirectType(compileContext);
			if (allocationType == null)
				continue;
			ref<Scope> allocationClass = allocationType.scope();
			if (allocationClass == null)
				continue;
			if (allocationClass.enclosing() == scope())
				return oi;
		}
		return null;
	}
	
	public boolean hasConstructors() {
		if (scope() == null)
			return false;
		return scope().constructors().length() > 0;
	}

	public ref<ParameterScope> destructor() {
		if (scope() == null)
			return null;
		return scope().destructor();
	}
	
	public boolean hasDestructor() {
		if (scope() == null)
			return false;
		return scope().destructor() != null;
	}
	
	public ref<OverloadInstance> compareMethod(ref<CompileContext> compileContext) {
		CompileString name("compare");
		
		ref<Symbol> sym = lookup(&name, compileContext);
		if (sym != null && sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			for (int i = 0; i < o.instances().length(); i++) {
				ref<OverloadInstance> oi = (*o.instances())[i];
				oi.assignType(compileContext);
				if (oi.parameterCount() != 1)
					continue;
				if ((*oi.parameterScope().parameters())[0].type() == this)
					return oi;
			}
		}
		return null;
	}

	public int ordinal(int maxOrdinal) {
		if (_ordinal == 0)
			_ordinal = maxOrdinal + 1;
		return _ordinal;
	}
	
	public int copyToImage(ref<Target> target) {
		if (_ordinal == 0) {
			address a = allocateImageData(target, Type.bytes);
			ref<Type> t = ref<Type>(a);
//			*t = *this;
//			*ref<long>(t) = 0;
		}
		print();
		assert(false);
		return _ordinal;
	}
	
	protected address allocateImageData(ref<Target> target, int size) {
		address a;
		(a, _ordinal) = target.allocateImageData(size, address.bytes);
		return a;
	}
	
	public boolean equals(ref<Type> other) {
		if (this == other)
			return true;
		if (this.class != other.class)
			return false;
		if (_family != other._family)
			return false;
		return sameAs(other);
	}
	/*
	 * This is the implementation method for class <. This is a subtype of other if other is one of the base class chain.
	 * 
	 * RETURNS
	 *     true if other is a base class of this, false otherwise.
	 */
	public boolean isSubtype(ref<Type> other) {
//		printf("this = %p other = %p\n", this, other);
//		text.memDump(this, ClassType.bytes);
		ref<Type> base = getSuper();
		if (base == null)
			return false;
		else if (base == other)
			return true;
		else
			return base.isSubtype(other);
	}
	
	boolean canOverride(ref<Type> other, ref<CompileContext> compileContext) {
		return false;
	}

	public ref<Scope> scope() {
		return null;
	}

	public  ref<Type> assignSuper(ref<CompileContext> compileContext) {
		return null;
	}

	public ref<Type> getSuper() {
		return null;
	}

	public ref<Type> indirectType(ref<CompileContext> compileContext) {
		return null;
	}
	
	public ref<Type> elementType(ref<CompileContext> compileContext) {
		assert(false);
		return null;
	}
	
	public ref<Type> indexType(ref<CompileContext> compileContext) {
		assert(false);
		return null;
	}

	public boolean isPointer(ref<CompileContext> compileContext) {
		return false;
	}

	public boolean isVector(ref<CompileContext> compileContext) {
		return false;
	}

	public boolean isMap(ref<CompileContext> compileContext) {
		return false;
	}
	
	boolean isCompactIndexType() {
		switch (_family) {
		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	UNSIGNED_64:
		case	SIGNED_8:
		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
			
		case	BOOLEAN:
		case	ENUM:
			return true;

		default:
			return false;
		}
		return false;
	}

	boolean isMonitor() {
		return false;
	}
	
	boolean isIntegral() {
		switch (_family) {
		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	UNSIGNED_64:
		case	SIGNED_8:
		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
			return true;

		default:
			return false;
		}
		return false;
	}

	boolean isFloat() {
		switch (_family) {
		case	FLOAT_32:
		case	FLOAT_64:
			return true;
			
		default:
			return false;
		}
		return false;
	}
	
	boolean requiresAutoStorage() {
		switch (_family) {
		case	TYPEDEF:
		case	ERROR:
		case	CLASS_DEFERRED:
			return false;

		default:
			return !derivesFrom(TypeFamily.NAMESPACE);
		}
		return false;
	}

	public boolean hasVtable(ref<CompileContext> compileContext) {
		return false;
	}

	public boolean returnsViaOutParameter(ref<CompileContext> compileContext) {
		return false;
	}
	
	public boolean passesViaStack(ref<CompileContext> compileContext) {
		return false;
	}
	
	void resolve(ref<CompileContext> compileContext) {
		if (_resolved)
			return;
		if (_resolving) {
			printf("resolve error ");
			print();
			printf("\n");
			assert(false);
			_family = TypeFamily.ERROR;
		} else {
			_resolving = true;
			doResolve(compileContext);
		}
		_resolving = false;
		_resolved = true;
	}

	public ref<Symbol> lookup(ref<CompileString> name, ref<CompileContext> compileContext) {
		for (ref<Type> current = this; current != null; current = current.assignSuper(compileContext)) {
			if (current.scope() != null) {
				ref<Symbol> sym = current.scope().lookup(name, compileContext);
				if (sym != null) {
					if (sym.visibility() != Operator.PRIVATE || 
						current.scope().encloses(compileContext.current()))
						return sym;
				}
			}
		}
		return null;
	}

	public boolean widensTo(ref<Type> other, ref<CompileContext> compileContext) {
		if (this == other)
			return true;
		if (other == compileContext.arena().builtInType(TypeFamily.VAR))
			return true;
		if (extendsFormally(other, compileContext))
			return true;
		ref<Type> ind = indirectType(compileContext);
		if (ind != null) {
			ref<Type> otherInd = other.indirectType(compileContext);
			if (otherInd == null)
				return false;
			if (family() != TypeFamily.POINTER &&
				other.family() == TypeFamily.POINTER)
				return false;
			if (ind == otherInd)
				return true;
			return ind.extendsFormally(otherInd, compileContext);
		}
		return false;
	}

	public boolean derivesFrom(TypeFamily family) {
		if (_family == family)
			return true;
		ref<Type> sup = getSuper();
		if (sup != null)
			return sup.derivesFrom(family);
		else
			return false;
	}

	public boolean extendsFormally(ref<Type> other, ref<CompileContext> compileContext) {
		// TF_ERROR should not get here, but if it does, this should report
		// false.
		return false;
	}

	public ref<Type> greatestCommonBase(ref<Type> other) {
		if (this == other)
			return other;
		return null;
	}

	public boolean isBuiltIn() {
		return int(_family) < int(TypeFamily.BUILTIN_TYPES);
	}

	public boolean isConcrete(ref<CompileContext> compileContext) {
		return true;
	}
	
	public boolean isInterface() {
		return false;
	}

	public boolean deferAnalysis() {
		return _family == TypeFamily.ERROR || _family == TypeFamily.CLASS_DEFERRED;
	}

	public TypeFamily family() {
		return _family;
	}

	protected void doResolve(ref<CompileContext> compileContext) {
		assert(false);
	}

	private boolean sameAs(ref<Type> other) {
		// TypeFamily.ERROR is a unique type, so it is unclear
		// how we could get here, but they should not be 'the same'
		return false;
	}
}

int[TypeFamily] familySize = [
	SIGNED_8:			 1,
	SIGNED_16:			 2,
	SIGNED_32:			 4,
	SIGNED_64:			 8,
	UNSIGNED_8:			 1,
	UNSIGNED_16:		 2,
	UNSIGNED_32:		 4,
	UNSIGNED_64:		 8,
	FLOAT_32:			 4,
	FLOAT_64:			 8,
	BOOLEAN:			 1,
	ADDRESS:			 8,
	STRING: 			 8,
	VAR: 				16,
	VOID: 				-1,
	ERROR: 				-1,
	BUILTIN_TYPES: 		-1,
	CLASS: 				-1,
	ARRAY_AGGREGATE: 	-1,
	OBJECT_AGGREGATE: 	-1,
	ENUM:				 8,
	TYPEDEF: 			 8,
	SHAPE: 				-1,
	REF: 				 8,
	POINTER: 			 8,
	FUNCTION: 			 8,
	FLAGS:				-1,
	TEMPLATE: 			-1,
	TEMPLATE_INSTANCE:	-1,
	NAMESPACE: 			-1,
	CLASS_VARIABLE: 	 8,
	EXCEPTION:			 24,
	CLASS_DEFERRED: 	-1,
];

int[TypeFamily] familyAlignment = [
	ADDRESS:			 8,
	
	SIGNED_8:			 1,
	SIGNED_16:			 2,
	SIGNED_32:			 4,
	SIGNED_64:			 8,
	UNSIGNED_8:			 1,
	UNSIGNED_16:		 2,
	UNSIGNED_32:		 4,
	UNSIGNED_64:		 8,
	FLOAT_32:			 4,
	FLOAT_64:			 8,
	BOOLEAN: 			 1,
	STRING: 			 8,
	VAR: 				 8,
	VOID: 				-1,
	ERROR: 				-1,
	BUILTIN_TYPES: 		-1,
	CLASS: 				-1,
	ARRAY_AGGREGATE: 	-1,
	OBJECT_AGGREGATE: 	-1,
	ENUM: 				 8,
	TYPEDEF: 			 8,
	SHAPE: 				-1,
	REF: 				-1,
	POINTER: 			-1,
	FUNCTION: 			 8,
	FLAGS:				-1,
	TEMPLATE: 			-1,
	TEMPLATE_INSTANCE:	-1,
	NAMESPACE: 			-1,
	CLASS_VARIABLE: 	 8,
	EXCEPTION:			 8,
	CLASS_DEFERRED: 	-1,
];

string[TypeFamily] builtinName = [
  	SIGNED_8:			"signed<8>",
  	SIGNED_16:			"short",
  	SIGNED_32:			"int",
  	SIGNED_64:			"long",
  	UNSIGNED_8:			"byte",
  	UNSIGNED_16:		"char",
  	UNSIGNED_32:		"unsigned",
  	UNSIGNED_64:		"unsigned<64>",
  	FLOAT_32:			"float",
  	FLOAT_64:			"double",
  	BOOLEAN:			"boolean",
  	ADDRESS:			"address",
  	STRING: 			"string",
  	VAR: 				"var",
  	VOID: 				"void",
  	ERROR: 				"<error>",
	EXCEPTION:			"Exception",
	CLASS_VARIABLE:		"class",
	CLASS_DEFERRED:		"<deferred class>",
	NAMESPACE:			"namespace",
	ARRAY_AGGREGATE:	"Array",
	OBJECT_AGGREGATE:	"Object"
  ];

