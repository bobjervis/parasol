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
	CLASS_VARIABLE,
	CLASS_DEFERRED,
	NAMESPACE,
	BUILTIN_TYPES,
	
	CLASS,
	ENUM,
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
		printf("%s %p(", TypeFamilyMap.name[family()], _classType);
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

	public ref<OverloadInstance> initialConstructor() {
		return _classType.initialConstructor();
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
		static boolean[TypeFamily][TypeFamily] widens;
		
		widens.resize(TypeFamily.BUILTIN_TYPES);
		for (int i = 0; i < int(TypeFamily.BUILTIN_TYPES); i++)
			widens[TypeFamily(i)].resize(TypeFamily.BUILTIN_TYPES);
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
		widens[TypeFamily.ADDRESS][TypeFamily.VAR] = true;
		widens[TypeFamily.ADDRESS][TypeFamily.ADDRESS] = true;
		widens[TypeFamily.CLASS_VARIABLE][TypeFamily.CLASS_VARIABLE] = true;
		widens[TypeFamily.CLASS_DEFERRED][TypeFamily.CLASS_DEFERRED] = true;

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
		// or as a special case, ERROR type has no underlying class, so it canonly
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
			address a = allocateImageData(target, BuiltInType.bytes);
			ref<BuiltInType> t = ref<BuiltInType>(a);
//			*t = *this;
//			*ref<long>(t) = 0;
//			t._classType = null;
			// TODO: patch up the _classType
		}
		return _ordinal;
	}
	
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
		printf("%s(%p) %p scope %p", TypeFamilyMap.name[family()], pa[1], _definition, _scope);
	}

	public ref<OverloadInstance> initialConstructor() {
		for (int i = 0; i < _scope.constructors().length(); i++) {
			ref<ParameterScope> scope = ref<ParameterScope>(_scope.constructors()[i]);
			if (scope.parameters().length() == 1) {
				ref<Type> paramType = scope.parameters()[0].type();
				if (paramType.class == BuiltInType)
					paramType = ref<BuiltInType>(paramType).classType();
				if (paramType == this) {
					ref<Function> f = ref<Function>(scope.definition());
					return ref<OverloadInstance>(f.name().symbol());
				}
			}
		}
		return null;
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

	public boolean isConcrete() {
		return _scope.isConcrete();
	}

	public boolean hasVtable() {
		return _scope.hasVtable();
	}

	public ref<Class> definition() {
		return _definition;
	}
/*
protected:


	vector<InterfaceType*> _implements;

*/
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
				_extends = base.unwrapTypedef(compileContext);
			}
			_scope.createPossibleDefaultConstructor(compileContext);
		}
	}

	public int copyToImage(ref<Target> target) {
		if (_ordinal == 0) {
			address a = allocateImageData(target, ClassType.bytes);
			ref<ClassType> t = ref<ClassType>(a);
//			*t = *this;
//			*ref<long>(t) = 0;
//			t._scope = null;
//			t._extends = null;
//			t._definition = null;
			// TODO: patch up _scope and _extends
			// Definition is left empty.
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
		printf("%s %p", TypeFamilyMap.name[family()], _definition);
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

	protected EnumInstanceType(ref<Symbol> symbol, ref<Scope> scope, ref<ClassType> instanceClass) {
		super(TypeFamily.ENUM);
		_symbol = symbol;
		_scope = scope;
		_instanceClass = instanceClass;
	}

	public void print() {
		printf("%s %p", TypeFamilyMap.name[family()], _instanceClass);
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
			ref<Type> t = _functionScope.parameters()[i].type();
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
		printf("%s %d <- %d", TypeFamilyMap.name[family()], returnCount(), parameterCount());
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
		printf("%s %p scope %p", TypeFamilyMap.name[family()], _definition, _templateScope);
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
			_extends = base.unwrapTypedef(compileContext);
		}
	}
}

class TemplateInstanceType extends ClassType {
	private ref<TemplateInstanceType> _next;
	private ref<Template> _concreteDefinition;
	private ref<FileStat> _definingFile;
	private var[] _arguments;
	private ref<TemplateType> _templateType;

	TemplateInstanceType(ref<TemplateType> templateType, var[] args, ref<Template> concreteDefinition, ref<FileStat> definingFile, ref<Scope> scope, ref<TemplateInstanceType> next) {
		super(templateType.definingSymbol().effectiveFamily(), ref<Type>(null), scope);
		for (int i = 0; i < args.length(); i++)
			_arguments.append(args[i]);
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

	// Map sub-types

	public ref<Type> keyType(ref<CompileContext> compileContext) {
		return ref<Type>(_arguments[0]);
	}

	public ref<Type> valueType(ref<CompileContext> compileContext) {
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
	
	public  ref<Type> assignSuper(ref<CompileContext> compileContext) {
		resolve(compileContext);
		return _extends;
	}

	public ref<Type> getSuper() {
		return _extends;
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
			_extends = base.unwrapTypedef(compileContext);
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
		printf("TemplateInstanceType %s %p<", TypeFamilyMap.name[family()], definition());
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
		printf("%s ", TypeFamilyMap.name[family()]);
		if (_wrappedType != null)
			_wrappedType.print();
		else
			printf("<null>");
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
		return true;
	}
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
		printf("%s", TypeFamilyMap.name[_family]);
		if (_ordinal != 0)
			printf(" ord [0x%x]", _ordinal);
	}

	public string name() {
		return TypeFamilyMap.name[_family];
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
		return TypeFamilyMap.size[_family];
	}

	public int stackSize() {
		return (size() + address.bytes - 1) & ~(address.bytes - 1);
	}

	public int alignment() {
		return TypeFamilyMap.alignment[_family];
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
				ref<OverloadInstance> oi = o.instances()[i];
				if (oi.parameterCount() != 1)
					continue;
				if (oi.parameterScope().parameters()[0].type() == this)
					return oi;
			}
		}
		return null;
	}

	public ref<OverloadInstance> copyConstructor(ref<CompileContext> compileContext) {
		if (scope() == null)
			return null;
		for (int i = 0; i < scope().constructors().length(); i++) {
			ref<Function> f = ref<Function>(scope().constructors()[i].definition());
			ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
			if (oi.parameterCount() != 1)
				continue;
			if (oi.parameterScope().parameters()[0].type() == this)
				return oi;
		}
		return null;
	}

	public ref<OverloadInstance> initialConstructor() {
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

	public ref<Type> keyType(ref<CompileContext> compileContext) {
		assert(false);
		return null;
	}

	public ref<Type> valueType(ref<CompileContext> compileContext) {
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

	public boolean hasVtable() {
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
				ref<Symbol> sym = current.scope().lookup(name);
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
			if (!isPointer(compileContext) &&
				other.isPointer(compileContext))
				return false;
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

	public boolean isConcrete() {
		return true;
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

class TypeFamilyMap {
	TypeFamilyMap() {
		name.resize(TypeFamily.MAX_TYPES);
		name[TypeFamily.SIGNED_8] = "SIGNED_8";
		name[TypeFamily.SIGNED_16] = "SIGNED_16";
		name[TypeFamily.SIGNED_32] = "SIGNED_32";
		name[TypeFamily.SIGNED_64] = "SIGNED_64";
		name[TypeFamily.UNSIGNED_8] = "UNSIGNED_8";
		name[TypeFamily.UNSIGNED_16] = "UNSIGNED_16";
		name[TypeFamily.UNSIGNED_32] = "UNSIGNED_32";
		name[TypeFamily.UNSIGNED_64] = "UNSIGNED_64";
		name[TypeFamily.FLOAT_32] = "FLOAT_32";
		name[TypeFamily.FLOAT_64] = "FLOAT_64";
		name[TypeFamily.BOOLEAN] = "BOOLEAN";
		name[TypeFamily.STRING] = "STRING";
		name[TypeFamily.VAR] = "VAR";
		name[TypeFamily.ADDRESS] = "ADDRESS",
		name[TypeFamily.VOID] = "VOID";
		name[TypeFamily.ERROR] = "ERROR";
		name[TypeFamily.BUILTIN_TYPES] = "BUILTIN_TYPES";
		name[TypeFamily.CLASS] = "CLASS";
		name[TypeFamily.ENUM] = "ENUM";
		name[TypeFamily.TYPEDEF] = "TYPEDEF";
		name[TypeFamily.SHAPE] = "SHAPE";
		name[TypeFamily.REF] = "REF";
		name[TypeFamily.POINTER] = "POINTER";
		name[TypeFamily.FUNCTION] = "FUNCTION";
		name[TypeFamily.TEMPLATE] = "TEMPLATE";
		name[TypeFamily.TEMPLATE_INSTANCE] = "TEMPLATE_INSTANCE";
		name[TypeFamily.NAMESPACE] = "NAMESPACE";
		name[TypeFamily.CLASS_VARIABLE] = "CLASS_VARIABLE";
		name[TypeFamily.CLASS_DEFERRED] = "CLASS_DEFERRED";
		size.resize(TypeFamily.MAX_TYPES);
		size[TypeFamily.SIGNED_8] = 1;
		size[TypeFamily.SIGNED_16] = 2;
		size[TypeFamily.SIGNED_32] = 4;
		size[TypeFamily.SIGNED_64] = 8;
		size[TypeFamily.UNSIGNED_8] = 1;
		size[TypeFamily.UNSIGNED_16] = 2;
		size[TypeFamily.UNSIGNED_32] = 4;
		size[TypeFamily.UNSIGNED_64] = 8;
		size[TypeFamily.FLOAT_32] = 4;
		size[TypeFamily.FLOAT_64] = 8;
		size[TypeFamily.BOOLEAN] = 1;
		size[TypeFamily.ADDRESS] = 8;
		size[TypeFamily.STRING] = size[TypeFamily.ADDRESS];
		size[TypeFamily.VAR] = 16;
		size[TypeFamily.VOID] = -1;
		size[TypeFamily.ERROR] = -1;
		size[TypeFamily.BUILTIN_TYPES] = -1;
		size[TypeFamily.CLASS] = -1;
		size[TypeFamily.ENUM] = size[TypeFamily.ADDRESS];
		size[TypeFamily.TYPEDEF] = size[TypeFamily.ADDRESS];
		size[TypeFamily.SHAPE] = -1;
		size[TypeFamily.REF] = size[TypeFamily.ADDRESS];
		size[TypeFamily.POINTER] = size[TypeFamily.ADDRESS];
		size[TypeFamily.FUNCTION] = size[TypeFamily.ADDRESS];
		size[TypeFamily.TEMPLATE] = -1;
		size[TypeFamily.TEMPLATE_INSTANCE] = -1;
		size[TypeFamily.NAMESPACE] = -1;
		size[TypeFamily.CLASS_VARIABLE] = size[TypeFamily.ADDRESS];
		size[TypeFamily.CLASS_DEFERRED] = -1;

		alignment.resize(TypeFamily.MAX_TYPES);
		alignment[TypeFamily.ADDRESS] = 8;

		alignment[TypeFamily.SIGNED_8] = 1;
		alignment[TypeFamily.SIGNED_16] = 2;
		alignment[TypeFamily.SIGNED_32] = 4;
		alignment[TypeFamily.SIGNED_64] = 8;
		alignment[TypeFamily.UNSIGNED_8] = 1;
		alignment[TypeFamily.UNSIGNED_16] = 2;
		alignment[TypeFamily.UNSIGNED_32] = 4;
		alignment[TypeFamily.UNSIGNED_64] = 8;
		alignment[TypeFamily.FLOAT_32] = 4;
		alignment[TypeFamily.FLOAT_64] = 8;
		alignment[TypeFamily.BOOLEAN] = 1;
		alignment[TypeFamily.STRING] = alignment[TypeFamily.ADDRESS];
		alignment[TypeFamily.VAR] = alignment[TypeFamily.ADDRESS];
		alignment[TypeFamily.VOID] = -1;
		alignment[TypeFamily.ERROR] = -1;
		alignment[TypeFamily.BUILTIN_TYPES] = -1;
		alignment[TypeFamily.CLASS] = -1;
		alignment[TypeFamily.ENUM] = alignment[TypeFamily.ADDRESS];
		alignment[TypeFamily.TYPEDEF] = alignment[TypeFamily.ADDRESS];
		alignment[TypeFamily.SHAPE] = -1;
		alignment[TypeFamily.REF] = -1;
		alignment[TypeFamily.POINTER] = -1;
		alignment[TypeFamily.FUNCTION] = alignment[TypeFamily.ADDRESS];
		alignment[TypeFamily.TEMPLATE] = -1;
		alignment[TypeFamily.TEMPLATE_INSTANCE] = -1;
		alignment[TypeFamily.NAMESPACE] = -1;
		alignment[TypeFamily.CLASS_VARIABLE] = alignment[TypeFamily.ADDRESS];
		alignment[TypeFamily.CLASS_DEFERRED] = -1;
		string last = "<none>";
		int lastI = -1;
		for (int i = 0; i < int(TypeFamily.MAX_TYPES); i++)
			if (name[TypeFamily(i)] == null || size[TypeFamily(i)] == 0 || alignment[TypeFamily(i)] == 0) {
				printf("ERROR: Type %d has no name entry (last defined entry: %s %d)\n", i, last, lastI);
			} else {
				last = name[TypeFamily(i)];
				lastI = i;
			}
	}

	static string[TypeFamily] name;
	static int[TypeFamily] size;
	static int[TypeFamily] alignment;
}

TypeFamilyMap typeFamilyMap;