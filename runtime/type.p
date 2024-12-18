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

import parasol:context;
import parasol:runtime;

public class BuiltInType extends Type {
	private ref<Type> _classType;

	BuiltInType(runtime.TypeFamily family) {
		super(family);
	}

	void setClassType(ref<Type> classType) {
		_classType = classType;
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
		if (other.isBuiltIn())
			return widens[family()][other.family()];
		else
			return super.widensTo(other, compileContext);
	}

	public ref<Type> classType() {
		return _classType;
	}

	public ref<Type> elementType() {
		return _classType.elementType();
	}
	
	public ref<Type> indexType() {
		return _classType.indexType();
	}


	public boolean equals(ref<Type> other) {
		// A built in type is unique, so one is always equal to itself...
		if (this == other)
			return true;
		// CLASS_VARIABLE has one special case: these match TYPEDEF
		if (family() == runtime.TypeFamily.CLASS_VARIABLE && other.family() == runtime.TypeFamily.TYPEDEF)
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
		switch (family()) {
		case VAR:
		case SUBSTRING:
		case SUBSTRING16:
			return true;
		}
		return false;
	}
	
	public boolean passesViaStack(ref<CompileContext> compileContext) {
		switch (family()) {
		case VAR:
		case SUBSTRING:
		case SUBSTRING16:
			return true;
		}
		return false;
	}
	/**
	 * The runtime type of a built-in type is the underlying classtype of the built-in.
	 * We may want to treat built-in types inside the compiler like they are magic, but
	 * The runtime info has to show the class as the actual type of the object.
	 */
	public int copyToImage(ref<Target> target, runtime.TypeFamily preferredFamily) {
		if (_ordinal == 0 && _classType != null)
			_ordinal = _classType.copyToImage(target, family());
		return _ordinal;
	}
	
	public boolean isVector(ref<CompileContext> compileContext) {
		return family() == runtime.TypeFamily.ARRAY_AGGREGATE;
	}

	public boolean isMap(ref<CompileContext> compileContext) {
		return family() == runtime.TypeFamily.OBJECT_AGGREGATE;
	}
	
	public boolean isLockable() {
		return family() == runtime.TypeFamily.CLASS_DEFERRED;
	}

	public string signature() {
		return builtinName[family()];
	}

	boolean canCheckEquality(ref<CompileContext> compileContext) {
		switch (family()) {
		case	SIGNED_8:
		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	UNSIGNED_64:
		case	FLOAT_32:
		case	FLOAT_64:
		case	BOOLEAN:
		case	CLASS_VARIABLE:
		case	VAR:
		case	STRING:
		case	STRING16:
		case	SUBSTRING:
		case	SUBSTRING16:
		case	ADDRESS:
		case	REF:
		case	POINTER:
			return true;
		}
		return false;
	}

	boolean canCheckOrder(ref<CompileContext> compileContext) {
		switch (family()) {
		case	SIGNED_8:
		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	UNSIGNED_64:
		case	FLOAT_32:
		case	FLOAT_64:
		case	CLASS_VARIABLE:
		case	VAR:
		case	STRING:
		case	STRING16:
		case	SUBSTRING:
		case	SUBSTRING16:
		case	POINTER:
			return true;
		}
		return false;
	}

	boolean canCheckPartialOrder(ref<CompileContext> compileContext) {
		switch (family()) {
		case	FLOAT_32:
		case	FLOAT_64:
		case	CLASS_VARIABLE:
		case	VAR:
			return true;
		}
		return false;
	}
}

public class TemplateClassType extends BuiltInType {
	private ref<PlainSymbol> _name;

	public TemplateClassType(ref<PlainSymbol> name, ref<Type> classType) {
		super(runtime.TypeFamily.CLASS_DEFERRED);
		setClassType(classType);
		_name = name;
	}

	public string signature() {
		return _name.name();
	}
}

boolean[runtime.TypeFamily][runtime.TypeFamily] widens;

widens.resize(runtime.TypeFamily.BUILTIN_TYPES);
fill();
private void fill() {
	for (int i = 0; i < int(runtime.TypeFamily.BUILTIN_TYPES); i++)
		widens[runtime.TypeFamily(i)].resize(runtime.TypeFamily.BUILTIN_TYPES);
}
widens[runtime.TypeFamily.SIGNED_8][runtime.TypeFamily.SIGNED_8] = true;
widens[runtime.TypeFamily.SIGNED_8][runtime.TypeFamily.SIGNED_16] = true;
widens[runtime.TypeFamily.SIGNED_8][runtime.TypeFamily.SIGNED_32] = true;
widens[runtime.TypeFamily.SIGNED_8][runtime.TypeFamily.SIGNED_64] = true;
widens[runtime.TypeFamily.SIGNED_8][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.SIGNED_8][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.SIGNED_8][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.SIGNED_16][runtime.TypeFamily.SIGNED_16] = true;
widens[runtime.TypeFamily.SIGNED_16][runtime.TypeFamily.SIGNED_32] = true;
widens[runtime.TypeFamily.SIGNED_16][runtime.TypeFamily.SIGNED_64] = true;
widens[runtime.TypeFamily.SIGNED_16][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.SIGNED_16][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.SIGNED_16][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.SIGNED_32][runtime.TypeFamily.SIGNED_32] = true;
widens[runtime.TypeFamily.SIGNED_32][runtime.TypeFamily.SIGNED_64] = true;
widens[runtime.TypeFamily.SIGNED_32][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.SIGNED_32][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.SIGNED_32][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.SIGNED_64][runtime.TypeFamily.SIGNED_64] = true;
widens[runtime.TypeFamily.SIGNED_64][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.SIGNED_64][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.SIGNED_64][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.SIGNED_16] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.SIGNED_32] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.SIGNED_64] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.UNSIGNED_8] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.UNSIGNED_16] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.UNSIGNED_32] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.UNSIGNED_64] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.UNSIGNED_8][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.UNSIGNED_16][runtime.TypeFamily.SIGNED_32] = true;
widens[runtime.TypeFamily.UNSIGNED_16][runtime.TypeFamily.SIGNED_64] = true;
widens[runtime.TypeFamily.UNSIGNED_16][runtime.TypeFamily.UNSIGNED_16] = true;
widens[runtime.TypeFamily.UNSIGNED_16][runtime.TypeFamily.UNSIGNED_32] = true;
widens[runtime.TypeFamily.UNSIGNED_16][runtime.TypeFamily.UNSIGNED_64] = true;
widens[runtime.TypeFamily.UNSIGNED_16][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.UNSIGNED_16][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.UNSIGNED_16][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.UNSIGNED_32][runtime.TypeFamily.SIGNED_64] = true;
widens[runtime.TypeFamily.UNSIGNED_32][runtime.TypeFamily.UNSIGNED_32] = true;
widens[runtime.TypeFamily.UNSIGNED_32][runtime.TypeFamily.UNSIGNED_64] = true;
widens[runtime.TypeFamily.UNSIGNED_32][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.UNSIGNED_32][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.UNSIGNED_32][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.UNSIGNED_64][runtime.TypeFamily.UNSIGNED_64] = true;
widens[runtime.TypeFamily.UNSIGNED_64][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.UNSIGNED_64][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.UNSIGNED_64][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.FLOAT_32][runtime.TypeFamily.FLOAT_32] = true;
widens[runtime.TypeFamily.FLOAT_32][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.FLOAT_32][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.FLOAT_64][runtime.TypeFamily.FLOAT_64] = true;
widens[runtime.TypeFamily.FLOAT_64][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.BOOLEAN][runtime.TypeFamily.BOOLEAN] = true;
widens[runtime.TypeFamily.BOOLEAN][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.STRING][runtime.TypeFamily.STRING] = true;
widens[runtime.TypeFamily.STRING][runtime.TypeFamily.STRING16] = true;
widens[runtime.TypeFamily.STRING][runtime.TypeFamily.SUBSTRING] = true;
widens[runtime.TypeFamily.STRING][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.STRING16][runtime.TypeFamily.STRING] = true;
widens[runtime.TypeFamily.STRING16][runtime.TypeFamily.STRING16] = true;
widens[runtime.TypeFamily.STRING16][runtime.TypeFamily.SUBSTRING16] = true;
widens[runtime.TypeFamily.STRING16][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.SUBSTRING][runtime.TypeFamily.STRING] = true;
widens[runtime.TypeFamily.SUBSTRING][runtime.TypeFamily.STRING16] = true;
widens[runtime.TypeFamily.SUBSTRING][runtime.TypeFamily.SUBSTRING] = true;
widens[runtime.TypeFamily.SUBSTRING][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.SUBSTRING16][runtime.TypeFamily.STRING] = true;
widens[runtime.TypeFamily.SUBSTRING16][runtime.TypeFamily.STRING16] = true;
widens[runtime.TypeFamily.SUBSTRING16][runtime.TypeFamily.SUBSTRING16] = true;
widens[runtime.TypeFamily.SUBSTRING16][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.VAR][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.EXCEPTION][runtime.TypeFamily.EXCEPTION] = true;
widens[runtime.TypeFamily.ADDRESS][runtime.TypeFamily.VAR] = true;
widens[runtime.TypeFamily.ADDRESS][runtime.TypeFamily.ADDRESS] = true;
widens[runtime.TypeFamily.CLASS_VARIABLE][runtime.TypeFamily.CLASS_VARIABLE] = true;
widens[runtime.TypeFamily.CLASS_DEFERRED][runtime.TypeFamily.CLASS_DEFERRED] = true;

public class InterfaceType extends ClassType {
	InterfaceType(ref<ClassDeclarator> definition, boolean isFinal, ref<ClassScope> scope) {
		super(runtime.TypeFamily.INTERFACE, definition, isFinal, scope);
	}
	
	public boolean isConcrete(ref<CompileContext> compileContext) {
		return true;
	}
	
	public boolean isInterface() {
		return true;
	}

	public int size() {
		return 8;
	}

	public int alignment() {
		return 8;
	}

	public boolean hasVtable(ref<CompileContext> compileContext) {
		return true;
	}

	boolean canCheckEquality(ref<CompileContext> compileContext) {
		return true;
	}

	boolean canCheckOrder(ref<CompileContext> compileContext) {
		return false;
	}

	boolean canCheckPartialOrder(ref<CompileContext> compileContext) {
		return false;
	}

	public boolean returnsViaOutParameter(ref<CompileContext> compileContext) {
		return false;
	}

	public void makeRPCSymbols(ref<CompileContext> compileContext) {
		ref<Overload> o = scope().defineOverload("proxy", Operator.FUNCTION, compileContext);
		if (o != null) {
			ref<ParameterScope> funcScope = compileContext.createParameterScope(null, ParameterScope.Kind.PROXY_CLIENT);
			ref<ProxyOverload> proxy = compileContext.pool().newProxyOverload(this, o, funcScope);
			o.addSpecialInstance(proxy, compileContext);
		}
		o = scope().defineOverload("stub", Operator.FUNCTION, compileContext);
		if (o != null) {
			ref<ParameterScope> funcScope = compileContext.createParameterScope(null, ParameterScope.Kind.STUB_FUNCTION);
			ref<StubOverload> stub = compileContext.pool().newStubOverload(this, o, funcScope);
			funcScope.symbol = stub;
			o.addSpecialInstance(stub, compileContext);
		}
	}
}

public class ClassType extends Type {
	protected ref<ClassScope> _scope;
	protected ref<Type> _extends;
	protected ref<InterfaceType>[] _implements;
	protected ref<ClassDeclarator> _definition;
	protected boolean _isMonitor;
	protected boolean _final;

	protected ClassType(runtime.TypeFamily family, ref<ClassDeclarator> definition, boolean isFinal, ref<ClassScope> scope) {
		super(family);
		_definition = definition;
		_scope = scope;
		_isMonitor = definition.op() == Operator.MONITOR_CLASS;
		_final = isFinal;
	}

	ClassType(ref<ClassDeclarator> definition, boolean isFinal, ref<ClassScope> scope) {
		super(runtime.TypeFamily.CLASS);
		_definition = definition;
		_scope = scope;
		_isMonitor = definition.op() == Operator.MONITOR_CLASS;
		_final = isFinal;
	}

	ClassType(ref<Type> base, boolean isFinal, ref<ClassScope> scope) {
		super(runtime.TypeFamily.CLASS);
		_scope = scope;

		_extends = base;
		_final = isFinal;
	}

	ClassType(runtime.TypeFamily effectiveFamily, ref<Type> base, ref<ClassScope> scope) {
		super(effectiveFamily);
		_scope = scope;
		_extends = base;
	}

	public boolean allowedInRPCs(ref<CompileContext> compileContext) {
		switch (family()) {
		case SHAPE:
			if (isMap(compileContext) || isVector(compileContext))
				return elementType().allowedInRPCs(compileContext) &&
						indexType().allowedInRPCs(compileContext);

		case CLASS:
		case TEMPLATE_INSTANCE:
			ref<ref<Symbol>[]> psym = _scope.members();
			for (i in *psym) {
				ref<Symbol> sym = (*psym)[i];
				if (sym.storageClass() == StorageClass.STATIC)
					continue;
				ref<Type> tp = sym.assignType(compileContext);
				if (tp.deferAnalysis())
					continue;
				if (!tp.allowedInRPCs(compileContext))
					return false;
			}
			return true;
		}
		return false;
	}

	public void print() {
		pointer<address> pa = pointer<address>(this);
		printf("%s%s%s(%p) %p scope %p", _final ? "final " : "", _isMonitor? "monitor " : "", string(family()), pa[1], _definition, _scope);
		if (_extends != null)
			printf(" extends %p", _extends);
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

	public void assignMethodMaps(ref<CompileContext> compileContext) {
		_scope.assignMethodMaps(compileContext);
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
	
	public ref<ClassType> classType() {
		return this;
	}

	public ref<Scope> scope() {
		return _scope;
	}
	
	public void implement(ref<InterfaceType> interfaceType) {
		_implements.append(interfaceType);
	}

	public boolean doesImplement(ref<Type> interfaceType, ref<CompileContext> compileContext) {
		if (_definition != null) {
			compileContext.assignTypes(_scope.enclosing(), _definition);
		}
		assert(_definition == null || _definition.type != null);
		for (int i = 0; i < _implements.length(); i++)
			if (_implements[i] == interfaceType)
				return true;
		if (_extends != null)
			return _extends.doesImplement(interfaceType, compileContext);
		return false;
	}

	public int interfaceOffset(ref<Type> interfaceType, ref<CompileContext> compileContext) {
		for (int i = 0; i < _implements.length(); i++)
			if (_implements[i] == interfaceType)
				return _scope.interfaceOffset(compileContext) + i * address.bytes;
		if (_extends != null)
			return _extends.interfaceOffset(interfaceType, compileContext);
		return -1;
	}

	public int interfaceCount() {
		return _implements.length();
	}
	
	public ref<ref<InterfaceType>[]> interfaces() {
		return &_implements;
	}
	
	public int interfaceOffset(int implementsIndex, ref<CompileContext> compileContext) {
		return _scope.interfaceOffset(compileContext) + implementsIndex * address.bytes;
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

	public boolean isLockable() {
		if (_isMonitor)
			return true;
		if (_extends != null)
			return _extends.isLockable();
		else
			return false;
	}

	boolean isMonitorClass() {
		return _isMonitor;
	}

	public ref<Type> assignSuper(ref<CompileContext> compileContext) {
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

	public boolean isFinal() {
		return _final;
	}

	public ref<OverloadInstance> firstAbstractMethod(ref<CompileContext> compileContext) {
		return _scope.firstAbstractMethod(compileContext);
	}

	public boolean hasVtable(ref<CompileContext> compileContext) {
		return _scope.hasVtable(compileContext);
	}

	public ref<ClassDeclarator> definition() {
		return _definition;
	}

	public string signature() {
		if (_definition != null && _definition.name() != null) {
			if (_final)
				return "final " + _definition.name().identifier();
			else
				return _definition.name().identifier();
		} else
			return "<anonymous class>";
	}
	
	protected boolean sameAs(ref<Type> other) {
		// 'other' in this case has already been checked for identity, so this != other.
		// Two classes are considered the same only
		// if they have the same declaration site, which
		// is equivalent to object identity on the type
		// object.
		return false;
	}

	protected void doResolve(ref<CompileContext> compileContext) {
		if (_definition != null) {
			string s = _definition.name().identifier();
//			_definition.assignImplementsClause(compileContext);
			ref<Node> base = _definition.extendsClause();
			if (base != null) {
				compileContext.assignTypes(_scope.enclosing(), base);
				if (base.deferAnalysis())
					_extends = base.type;
				else {
					_extends = base.unwrapTypedef(family() == runtime.TypeFamily.INTERFACE ? Operator.INTERFACE : Operator.CLASS, compileContext);
					if (_extends.family() == runtime.TypeFamily.ENUM)
						base.add(MessageId.CANNOT_EXTEND_ENUM, compileContext.pool());
					else if (_extends.isFinal()) {
						_definition.add(isInterface() ? MessageId.FINAL_BASE_INTERFACE : 
													MessageId.FINAL_BASE_CLASS, compileContext.pool());
					}
				}
			} else if (_definition.op() == Operator.MONITOR_CLASS) 
				_extends = compileContext.monitorClass();
			_isMonitor = _definition.op() == Operator.MONITOR_CLASS;
		}
	}

	public int copyToImage(ref<Target> target, runtime.TypeFamily preferredFamily) {
		if (_ordinal == 0) {
			int baseOrdinal;

			if (_extends != null)
				baseOrdinal = _extends.copyToImage(target, runtime.TypeFamily.VOID);
			_ordinal = target.copyClassToImage(this, 
											   baseOrdinal,
											   preferredFamily == runtime.TypeFamily.VOID ? family() : 
														preferredFamily);
//			printf("copyToImage %s: -> %d\n", signature(), _ordinal);
		}
		return _ordinal;
	}
	
	public boolean widensTo(ref<Type> other, ref<CompileContext> compileContext) {
		if (other.family() == runtime.TypeFamily.INTERFACE) {
			ref<Type> t = this;
			do {
				t = t.assignSuper(compileContext); 
			} while (t != null);
			if (doesImplement(other, compileContext))
				return true;
			ref<Type> ind = indirectType(compileContext);
			if (ind != null) {
				t = ind;
				do {
					t = t.assignSuper(compileContext); 
				} while (t != null);
				if (ind.doesImplement(other, compileContext))
					return true;
			}
		}
		return super.widensTo(other, compileContext);
	}

	boolean canCheckEquality(ref<CompileContext> compileContext) {
		switch (family()) {
		case	REF:
		case	POINTER:
			return true;
		}
		ref<Type> t = getCompareReturnType(compileContext);
		if (t == null)
			return false;
		// Don't complain if we can't be sure
		if (t.deferAnalysis())
			return true;
		switch (t.family()) {
		case	BOOLEAN:
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
			return true;
		}
		return false;
	}

	boolean canCheckOrder(ref<CompileContext> compileContext) {
		switch (family()) {
		case	POINTER:
			return true;
		}
		ref<Type> t = getCompareReturnType(compileContext);
		if (t == null)
			return false;
		// Don't complain if we can't be sure
		if (t.deferAnalysis())
			return true;
		switch (t.family()) {
		case	SIGNED_8:
		case	SIGNED_16:
		case	SIGNED_32:
		case	SIGNED_64:
		case	FLOAT_32:
		case	FLOAT_64:
			return true;
		}
		return false;
	}

	boolean canCheckPartialOrder(ref<CompileContext> compileContext) {
		ref<Type> t = getCompareReturnType(compileContext);
		if (t == null)
			return false;
		// Don't complain if we can't be sure
		if (t.deferAnalysis())
			return true;
		switch (t.family()) {
		case	FLOAT_32:
		case	FLOAT_64:
			return true;
		}
		return false;
	}

	ref<Type> getCompareReturnType(ref<CompileContext> compileContext) {
		ref<OverloadInstance> oi = compareMethod(compileContext);
		if (oi != null)
			return oi.parameterScope().type.returnValueType();
		else
			return null;
	}
}

public class EnumType extends ClassType {
	public int instanceCount;
	private ref<Symbol> _symbol;

	EnumType(ref<Symbol> symbol, ref<ClassDeclarator> definition, ref<EnumScope> scope) {
		super(runtime.TypeFamily.CLASS, definition, false, scope);
		_symbol = symbol;
	}

	boolean requiresAutoStorage() {
		return false;
	}

	public int interfaceCount() {
		return 0;
	}
	
	public ref<ref<InterfaceType>[]> interfaces() {
		return null;
	}

	public void print() {
		printf("CLASS/enum %p %p", _definition, _scope);
	}

	public boolean equals(ref<Type> other) {
		if (this == other)
			return true;
		else
			return false;
	}

	protected boolean sameAs(ref<Type> other) {
		assert(false);
		return false;
	}

	public ref<Symbol> symbol() {
		return _symbol;
	}

	public runtime.TypeFamily instanceFamily() {
		if (instanceCount <= 256)
			return runtime.TypeFamily.UNSIGNED_8;
		else if (instanceCount <= 65536)
			return runtime.TypeFamily.UNSIGNED_16;
		else
			return runtime.TypeFamily.UNSIGNED_32;
	}

	public int copyToImage(ref<Target> target, runtime.TypeFamily preferredFamily) {
		if (_ordinal == 0) {
			assert(false);
			address a = null;//allocateImageData(target, EnumType.bytes);
			ref<Type> t = ref<Type>(a);
//			*t = *this;
//			*ref<long>(t) = 0;
		}
		print();
		assert(false);
		return _ordinal;
	}

	protected void doResolve(ref<CompileContext> compileContext) {
	}
}

public class EnumInstanceType extends Type {
	private ref<EnumScope> _scope;

	private ref<ParameterScope> _toStringMethod;
	private ref<ParameterScope> _fromStringMethod;
	private ref<ParameterScope> _instanceConstructor;

	protected EnumInstanceType(ref<EnumScope> scope) {
		super(runtime.TypeFamily.ENUM);
		_scope = scope;
	}

	public void print() {
		printf("%s %p", string(family()), _scope);
	}

	public ref<Scope> scope() {
		return _scope;
	}

	public boolean hasConstructors() {
		return false;						// The constructors in the _scope are not for us, so ignore it and always report false.
	}

	public boolean hasDestructor() {
		return false;						// The destructor in the _scope is not for us, so ignore it and always report false.
	}

	public ref<ParameterScope> instanceConstructor(ref<MemoryPool> pool) {
		if (_instanceConstructor == null)
			_instanceConstructor = pool new ParameterScope(_scope, null, ParameterScope.Kind.ENUM_INSTANCE_CONSTRUCTOR);
		return _instanceConstructor;
	}

	public int instanceCount() {
		return _scope.enumType.instanceCount;
	}

	public ref<EnumType> enumType() {
		return _scope.enumType;
	}

	public boolean equals(ref<Type> other) {
		// An enum type is unique, so one is always equal to itself...
		return this == other;
	}

	public ref<Symbol> typeSymbol() {
		return _scope.enumType.symbol();
	}

	public boolean hasInstance(ref<Identifier> id) {
		return _scope.hasInstance(id.identifier());
	}

	protected boolean sameAs(ref<Type> other) {
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

	public ref<ParameterScope> fromStringMethod(ref<Target> target, ref<CompileContext> compileContext) {
		if (_fromStringMethod == null)
			_fromStringMethod = target.generateEnumFromStringMethod(this, compileContext);
		return _fromStringMethod;
	}

	public int size() {
		long numberOfEnums = _scope.enumType.instanceCount;
		
		if (numberOfEnums <= byte.MAX_VALUE)
			return byte.bytes;
		else if (numberOfEnums <= char.MAX_VALUE)
			return short.bytes;
		else if (numberOfEnums <= unsigned.MAX_VALUE)
			return int.bytes;
		else
			return long.bytes;
	}

	public int alignment() {
		long numberOfEnums = _scope.enumType.instanceCount;
		
		if (numberOfEnums <= byte.MAX_VALUE)
			return byte.bytes;
		else if (numberOfEnums <= char.MAX_VALUE)
			return char.bytes;
		else if (numberOfEnums <= unsigned.MAX_VALUE)
			return unsigned.bytes;
		else
			return long.bytes;
	}

	boolean canCheckEquality(ref<CompileContext> compileContext) {
		return true;
	}

	boolean canCheckOrder(ref<CompileContext> compileContext) {
		return true;
	}

	public int copyToImage(ref<Target> target, runtime.TypeFamily preferredFamily) {
		if (_ordinal == 0) {
			assert(false);
			address a = null;//allocateImageData(target, EnumInstanceType.bytes);
			ref<Type> t = ref<Type>(a);
//			*t = *this;
//			*ref<long>(t) = 0;
		}
		print();
		assert(false);
		return _ordinal;
	}

	public string signature() {
		return _scope.enumType.signature();
	}
}
/**
 * The type of a Flags declaration.
 *
 * This uses a trick to make the type analysis a little easier. Where enums use
 * a simple TypedefType to wrap the instance type, because the EnumType has to be
 * the description of the members and methods of the enum (if any), flags don't have
 * that capability, so this small extension of the TypedefType can serve as the
 * type of the flags declaration itself.
 */
class FlagsType extends TypedefType {
	private ref<Block> _definition;
	private ref<Scope> _scope;

	FlagsType(ref<Block> definition, ref<Scope> scope, ref<Type> flagsInstanceType) {
		super(runtime.TypeFamily.TYPEDEF, flagsInstanceType);
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

	protected boolean sameAs(ref<Type> other) {
		assert(false);
		return false;
	}
}

public class FlagsInstanceType extends Type {
	private ref<Symbol> _symbol;
	private ref<FlagsScope> _scope;
	private ref<ClassType> _instanceClass;
	
	private ref<ParameterScope> _toStringMethod;

	FlagsInstanceType(ref<Symbol> symbol, ref<FlagsScope> scope, ref<ClassType> instanceClass) {
		super(runtime.TypeFamily.FLAGS);
		_symbol = symbol;
		_scope = scope;
		_instanceClass = instanceClass;
	}

	public void print() {
		printf("%s %p", string(family()), _instanceClass);
	}

	public ref<FlagsScope> scope() {
		return _scope;
	}

	public runtime.TypeFamily instanceFamily() {
		int numberOfFlags = _scope.symbols().size();

		if (numberOfFlags <= 8)
			return runtime.TypeFamily.UNSIGNED_8;
		else if (numberOfFlags <= 16)
			return runtime.TypeFamily.UNSIGNED_16;
		else if (numberOfFlags <= 32)
			return runtime.TypeFamily.UNSIGNED_32;
		else
			return runtime.TypeFamily.SIGNED_64;		// don't have an unsigned 64 marshaller. use the signed one.
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
		if (other.family() == runtime.TypeFamily.BOOLEAN)
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

	protected boolean sameAs(ref<Type> other) {
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

	boolean canCheckEquality(ref<CompileContext> compileContext) {
		return true;
	}

	public string signature() {
		return _scope.className().identifier();
	}
}

public class FunctionType extends Type {
	private pointer<ref<Type>> _t;
	private int _returnTypes;
	private int _parameters;
	private boolean _hasEllipsis;
	private ref<ParameterScope> _functionScope;
	private boolean _registerArgumentsAssigned;
	
	FunctionType(pointer<ref<Type>> t, int returnTypes, ref<Scope> functionScope) {
		super(runtime.TypeFamily.FUNCTION);
		_t = t;
		_returnTypes = returnTypes;
		_functionScope = ref<ParameterScope>(functionScope);
		_parameters = _functionScope.parameters().length();
		_hasEllipsis = _functionScope.hasEllipsis();
		_functionScope.type = this;
		int max = _returnTypes + _parameters;
		for (int i = 0; i < max; i++)
			assert(_t[i] != null);
	}

	FunctionType(pointer<ref<Type>> t, int returnTypes, int parameterTypes, boolean hasEllipsis) {
		super(runtime.TypeFamily.FUNCTION);
		_t = t;
		_returnTypes = returnTypes;
		_parameters = parameterTypes;
		_hasEllipsis = hasEllipsis;
		int max = _returnTypes + _parameters;
		for (int i = 0; i < max; i++)
			assert(_t[i] != null);
	}

	public int parameterCount() {
		return _parameters;
	}

	public boolean hasEllipsis() {
		return _hasEllipsis;
	}

	public int returnCount() {
		return _returnTypes;
	}
	
	public boolean widensTo(ref<Type> other, ref<CompileContext> compileContext) {
		if (this == other)
			return true;
		if (other == compileContext.builtInType(runtime.TypeFamily.VAR))
			return false;								// TODO: Fix the code gen for this.
		if (other.family() != runtime.TypeFamily.FUNCTION)
			return false;
		return equals(other);
	}

	public void assignRegisterArguments(ref<CompileContext> compileContext) {
		if (_registerArgumentsAssigned)
			return;
		_registerArgumentsAssigned = true;
		int hiddenParams = 0;
		if (_functionScope != null) {
			if (_functionScope.hasThis())
				hiddenParams++;
			if (_functionScope.hasOutParameter(compileContext))
				hiddenParams++;
		}
		pointer<byte> registerArray = pointer<byte>(_t + _returnTypes + _parameters);
		compileContext.target.assignRegisterArguments(hiddenParams, _t + _returnTypes, _parameters, registerArray, compileContext);
	}

	public byte parameterRegister(int i) {
		assert(i >= 0 && i < _parameters);
		pointer<byte> registerArray = pointer<byte>(_t + _returnTypes + _parameters);
		return registerArray[i];
	}
	
	public int fixedArgsSize(ref<Target> target, ref<CompileContext> compileContext) {
		int size = 0;

		for (int i = 0; i < _parameters; i++) {
			ref<Type> t = _t[_returnTypes + i];
			t.assignSize(target, compileContext);
			size += t.stackSize();
		}
		return size;
	}

	public int returnSize(ref<Target> target, ref<CompileContext> compileContext) {
		if (_returnTypes == 0)
			return 0;
		int returnBytes = 0;
		for (int i = 0; i < _returnTypes; i++) {
			ref<Type> t = _t[i];
			_t[i].assignSize(target, compileContext);
			returnBytes += _t[i].stackSize();
		}
		return returnBytes;
	}

	public ref<Scope> scope() {
		return _functionScope;
	}
	
	public pointer<ref<Type>> parameters() {
		return _t + _returnTypes;
	}

	public pointer<ref<Type>> returnTypes() {
		return _t;
	}

	public ref<Type> returnValueType() {	// type of this function call when used in an expression
		if (_returnTypes == 0)
			return null;
		else
			return _t[0];
	}
	
	public boolean canBeRPCMethod(ref<CompileContext> compileContext) {
		int max = _returnTypes + _parameters;
		for (int i = 0; i < max; i++)
			if (!_t[i].allowedInRPCs(compileContext))
				return false;
		return true;
	}

	protected boolean sameAs(ref<Type> other) {
		ref<FunctionType> otherFunction = ref<FunctionType>(other);

		if (_hasEllipsis != otherFunction._hasEllipsis)
			return false;
		if (_returnTypes != otherFunction._returnTypes)
			return false;
		if (_parameters != otherFunction._parameters)
			return false;
		int max = _returnTypes + _parameters;
		for (int i = 0; i < max; i++)
			if (!_t[i].equals(otherFunction._t[i]))
				return false;
		return true;
	}

	public boolean canOverride(ref<Type> other, ref<CompileContext> compileContext) {
		ref<FunctionType> otherFunction = ref<FunctionType>(other);

		if (_hasEllipsis != otherFunction._hasEllipsis)
			return false;
		if (_returnTypes != otherFunction._returnTypes)
			return false;
		if (_parameters != otherFunction._parameters)
			return false;
		pointer<ref<Type>> t = _t;
		pointer<ref<Type>> otherT = otherFunction._t;
		int max = _returnTypes + _parameters;
		for (int i = 0; i < max; i++) {
			if (!t[i].equals(otherT[i])) {
				if (i < _returnTypes) {
					// A pointer return type can point to a narrower type than the base method
					if (t[i].indirectType(compileContext) != null &&
						otherT[i].indirectType(compileContext) != null &&
						t[i].widensTo(otherT[i], compileContext))
						continue;
				} else {
					// A pointer parameter type can point to a wider type than the base method
					if (t[i].indirectType(compileContext) != null &&
						otherT[i].indirectType(compileContext) != null &&
						otherT[i].widensTo(t[i], compileContext))
						continue;
				}
				return false;
			}
		}
		return true;
	}

	public boolean extendsFormally(ref<Type> other, ref<CompileContext> compileContext) {
//		assert(false);
		return false;
	}

	boolean canCheckEquality(ref<CompileContext> compileContext) {
		return true;
	}

	public void print() {
		printf("%s %d <- %d%s", string(family()), _returnTypes, _parameters);
	}

	public string signature() {
		string sig;
		// First, format the return type(s).
		if (_returnTypes == 0)
			sig = "void";
		else if (_returnTypes == 1)
			sig = _t[0].signature();
		else {
			sig = "(";
			for (int i = 0; i < _returnTypes; i++) {
				sig.append(_t[i].signature());
				if (i < _returnTypes - 1)
					sig.append(',');
				else
					sig.append(')');
			}
		}
		sig.append('(');
		if (_parameters == 0)
			sig.append(')');
		else {
			int max = _returnTypes + _parameters;
			for (int i = _returnTypes; i < max; i++) {
				if (_t[i] == null)
					sig.append("<null>");
				else
					sig.append(_t[i].signature());
				if (i < max - 1)
					sig.append(',');
				else {
					if (_hasEllipsis)
						sig.append("...");
					sig.append(')');
				}
			}
		}
		return sig;
	}

	public ref<ParameterScope> functionScope() {
		return _functionScope;
	}
}

public class TemplateType extends Type {
	private ref<Template> _definition;
	private ref<Unit> _definingFile;
	private ref<Overload> _overload;
	private ref<ParameterScope> _templateScope;
	private ref<Type> _extends;
	private ref<Symbol> _definingSymbol;
	private boolean _isMonitor;

	TemplateType(ref<Symbol> symbol, ref<Template> definition, ref<Unit>  definingFile, ref<Overload> overload, ref<ParameterScope> templateScope, boolean isMonitor) {
		super(runtime.TypeFamily.TEMPLATE);
		_definingSymbol = symbol;
		_definition = definition;
		_definingFile = definingFile;
		_overload = overload;
		_templateScope = templateScope;
		_isMonitor = isMonitor;
	}

	public void print() {
		printf("%s%s %p scope %p", _isMonitor ? "monitor " : "", string(family()), _definition, _templateScope);
	}

	public int parameterCount() {
		assert(false);
		return 0;
	}

	public ref<Scope> scope() {
		return _templateScope;
	}

	public  ref<Type> assignSuper(ref<CompileContext> compileContext) {
		printf("assignSuper for %s\n", signature());
		assert(false);
		return null;
	}

	public ref<Type> getSuper() {
		return _extends;
	}

	public ref<Unit> definingFile() {
		return _definingFile;
	}

	public ref<Template> definition() {
		return _definition;
	}

	public ref<Symbol> definingSymbol() {
		return _definingSymbol;
	}

	public boolean isMonitorTemplate() {
		return _isMonitor;
	}

	public string signature() {
		return "Template " + definingSymbol().name();
	}
	
	public string templateName() {
		return definingSymbol().name();
	}

	protected boolean sameAs(ref<Type> other) {
		assert(false);
		return false;
	}	
	/**
	 * For a TemplateType, canOverride is used to decide when multiple template's can be 
	 * applied to the same template declaration.
	 */
	public boolean canOverride(ref<Type> other, ref<CompileContext> compileContext) {
		ref<TemplateType> tt = ref<TemplateType>(other);
		ref<ref<Symbol>[]> thisParams = _templateScope.parameters();
		ref<ref<Symbol>[]> otherParams = tt._templateScope.parameters();
		for (i in (*thisParams)) {
			ref<PlainSymbol> thisSym = ref<PlainSymbol>((*thisParams)[i]);
			ref<PlainSymbol> otherSym = ref<PlainSymbol>((*otherParams)[i]);
			if (thisSym.typeDeclarator().deferAnalysis() || otherSym.typeDeclarator().deferAnalysis())
				continue;
			if (!thisSym.typeDeclarator().type.equals(otherSym.typeDeclarator().type))
				return false;
		}
		return true;
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

public class TemplateInstanceType extends ClassType {
	private ref<TemplateInstanceType> _next;
	private ref<Template> _concreteDefinition;
	private ref<Unit> _definingFile;
	private var[] _arguments;
	private ref<TemplateType> _templateType;

	TemplateInstanceType(ref<TemplateType> templateType, var[] args, ref<Template> concreteDefinition, ref<Unit> definingFile, ref<ClassScope> scope, ref<TemplateInstanceType> next, ref<MemoryPool> pool) {
		super(templateType.definingSymbol().effectiveFamily(), ref<Type>(null), scope);
		for (int i = 0; i < args.length(); i++)
			_arguments.append(args[i], pool);
		_definingFile = definingFile;
		_templateType = templateType;
		_next = next;
		_concreteDefinition = concreteDefinition;
		_isMonitor = templateType.isMonitorTemplate();
	}

	public ref<Type> indirectType(ref<CompileContext> compileContext) {
		if (!_templateType.extendsFormally(compileContext.builtInType(runtime.TypeFamily.ADDRESS), compileContext))
			return null;
		if (_arguments.length() != 1)
			return null;
		return ref<Type>(_arguments[0]);
	}

	// Vector sub-types
	
	public ref<Type> elementType() {
		if (_arguments.length() > 1)
			return ref<Type>(_arguments[0]);
		else
			return null;
	}
	
	public ref<Type> indexType() {
		if (_arguments.length() > 1)
			return ref<Type>(_arguments[1]);
		else if (_arguments.length() == 1 && family() == runtime.TypeFamily.SHAPE)
			return ref<Type>(_arguments[0]);
		else
			return null;
	}

	public boolean isPointer(ref<CompileContext> compileContext) {
		if (!_templateType.extendsFormally(compileContext.builtInType(runtime.TypeFamily.ADDRESS), compileContext))
			return false;
		if (_arguments.length() != 1)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(compileContext.pointerTemplate().type());
		return tt.wrappedType() == _templateType;
	}

	public boolean isVector(ref<CompileContext> compileContext) {
		if (_arguments.length() != 2)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(compileContext.vectorTemplate().type());
		return tt.wrappedType() == _templateType;
	}

	public boolean isMap(ref<CompileContext> compileContext) {
		if (_arguments.length() != 2)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(compileContext.mapTemplate().type());
		return tt.wrappedType() == _templateType;
	}

	public ref<Type> mapIterator(ref<CompileContext> compileContext) {
		ref<Symbol> sym = scope().lookup("iterator", compileContext);
		if (sym == null) {
			printf("iterator not defined\n");
			return null;
		}
		if (sym.class != PlainSymbol) {
			printf("iterator is not a PlainSymbol\n");
			return null;
		}
		ref<PlainSymbol> ps = ref<PlainSymbol>(sym);
		ref<Type> tp = ps.assignType(compileContext);
		if (tp.family() != runtime.TypeFamily.TYPEDEF) {
			printf("iterator is not a type: %s\n", tp.signature());
			return null;
		}
		tp = ref<TypedefType>(tp).wrappedType();
		if (tp == null) {
			printf("Cannot unwrap iterator type: %s\n", ps.type().signature());
			return null;
		}
		if (tp.family() != runtime.TypeFamily.CLASS) {
			printf("iterator's type is not a CLASS: %s\n", tp.signature());
			return null;
		}
		return tp;

	}

	public boolean isLockable() {
		if (_templateType.isMonitorTemplate())
			return true;
		else
			return super.isLockable();
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
		} else if (_templateType.isMonitorTemplate())
			_extends = compileContext.monitorClass();
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

	public int copyToImage(ref<Target> target, runtime.TypeFamily preferredFamily) {
		if (_ordinal == 0) {
			super.copyToImage(target, preferredFamily == runtime.TypeFamily.VOID ? family() : preferredFamily);
			// Add specific stuff to the package
		}
		return _ordinal;
	}
	
	public void print() {
		printf("%sTemplateInstanceType %s <", _isMonitor ? "monitor " : "", string(family()));
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
		string sig = _templateType.templateName();
		sig.append('<');
		
		for (int i = 0; i < _arguments.length(); i++) {
			if (i > 0)
				sig.append(", ");
			ref<Type> t = ref<Type>(_arguments[i]);
			sig.append(t.signature());
		}
		sig.append(">");
		return sig;
	}
	
	public ref<TemplateInstanceType> next() {
		return _next;
	}

	public ref<Template> concreteDefinition() { 
		return _concreteDefinition; 
	}

	public ref<Unit> definingFile() { 
		return _definingFile; 
	}

	protected boolean sameAs(ref<Type> other) {
		return false;
	}

	public ref<var[]> arguments() {
		return &_arguments;
	}

	public ref<TemplateType> templateType() {
		return _templateType;
	}
}

public class TypedefType extends Type {
	private ref<Type> _wrappedType;

	protected TypedefType(runtime.TypeFamily family, ref<Type> wrappedType) {
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
		if (other.family() == runtime.TypeFamily.TYPEDEF ||
			other.family() == runtime.TypeFamily.CLASS_VARIABLE)
			return true;
		else
			return false;
	}

	boolean canCheckEquality(ref<CompileContext> compileContext) {
		return true;
	}

	boolean canCheckOrder(ref<CompileContext> compileContext) {
		return true;
	}

	boolean canCheckPartialOrder(ref<CompileContext> compileContext) {
		return true;
	}

	/**
	 * For a TypedefType, canOverride is used to decide when multiple template's can be 
	 * applied to the same template declaration. For non-Template's this is false.
	 */
	public boolean canOverride(ref<Type> other, ref<CompileContext> compileContext) {
		if (other.family() != runtime.TypeFamily.TYPEDEF)
			return false;
		if (_wrappedType.family() != runtime.TypeFamily.TEMPLATE)
			return false;
		ref<TypedefType> tt = ref<TypedefType>(other);
		if (tt._wrappedType.family() != runtime.TypeFamily.TEMPLATE)
			return false;
		return _wrappedType.canOverride(tt._wrappedType, compileContext);
	}
}

public enum CompareMethodCategory {
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
	
public class Type {
	private runtime.TypeFamily _family;
	private boolean _resolved;
	private boolean _resolving;
	private ref<OverloadInstance> _compareMethod;
	public boolean busy;				// Used when checking for circular extends clauses.

	protected int _ordinal;				// Assigned by type-refs: first one gets the 'real' value
	
	Type(runtime.TypeFamily family) {
		_family = family;
		if (this.class != BuiltInType)
			assert(family != runtime.TypeFamily.ERROR);
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
	
	public runtime.TypeFamily scalarFamily(ref<CompileContext> compileContext) {
		if (_family == runtime.TypeFamily.SHAPE) {
			ref<Type> t = elementType();
			if (t == null)
				return runtime.TypeFamily.ERROR;
			else
				return t.family();
		} else
			return _family;
	}
	
	public ref<Type> scalarType(ref<CompileContext> compileContext) {
		if (_family == runtime.TypeFamily.SHAPE)
			return elementType();
		else
			return this;	
	}
	
	public ref<Type> shapeType() {
		if (_family == runtime.TypeFamily.SHAPE)
			return this;
		else
			return null;	
	}
	
	public ref<Type> classType() {
		assert(false);
		return null;
	}

	public void assignSize(ref<Target> target, ref<CompileContext> compileContext) {
	}

	public void assignMethodMaps(ref<CompileContext> compileContext) {
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
		ref<Symbol> sym = lookup("copy", compileContext);
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
		ref<Symbol> sym = lookup("copyTemp", compileContext);
		if (sym != null && sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			for (int i = 0; i < o.instances().length(); i++) {
				ref<OverloadInstance> oi = (*o.instances())[i];
				if (oi.parameterCount() != 1)
					continue;
				if ((*oi.parameterScope().parameters())[0].assignType(compileContext) == this)
					return oi;
			}
		}
		return null;
	}

	public ref<OverloadInstance> storeMethod(ref<CompileContext> compileContext) {
		ref<Symbol> sym = lookup("store", compileContext);
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

	public boolean canCopy(ref<CompileContext> compileContext) {
//		if (hasConstructors()) {
//			if (copyConstructor() != null)
//				return true;
//			else {
//				printf("type %s has constructors, no copy constructor, default? %p assignment? %p\n", 
//								signature(), defaultConstructor(), assignmentMethod(compileContext));
//				return defaultConstructor() != null && assignmentMethod(compileContext) != null;
//			}
//		} else
			return true;
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
		if (scope() == null || scope().constructors().length() < 1)
			return null;
		ref<FunctionDeclaration> f = ref<FunctionDeclaration>((*scope().constructors())[0].definition());
		ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
		if (oi.parameterCount() != 1)
			return null;
		ref<Type> parameterType = (*oi.parameterScope().parameters())[0].type();
		ref<Type> allocationType = parameterType.indirectType(compileContext);
		if (allocationType == null)
			return null;
		return oi;
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
		if (_compareMethod != null)
			return _compareMethod;
		ref<Symbol> sym = lookup("compare", compileContext);
		if (sym != null && sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			if (o.kind() != Operator.FUNCTION)
				return null;
			for (i in *o.instances()) {
				ref<OverloadInstance> oi = (*o.instances())[i];
				if (oi.parameterCount() != 1)
					continue;
				oi.assignType(compileContext);
				ref<ParameterScope> scope = oi.parameterScope();
				ref<Symbol> param = (*scope.parameters())[0];
				ref<Type> t = param.type();
				if (t.deferAnalysis())
					continue;
				// You have to compare to T or ref<T> to be the 'compare' method of a type.
				if (t.classType() != this) {
					if (t.family() != runtime.TypeFamily.REF)
						continue;
					if (this != t.indirectType(compileContext).classType())
						continue;
				}
				if (scope.type.returnCount() != 1)
					continue;
				_compareMethod = oi;
				// we have a compare method on T that takes a single T or ref<T> parameter and returns a single value, close enough.
				return oi;
			}
		}
		return null;
	}


	public ref<OverloadInstance> stringConstantCompareMethod(ref<CompileContext> compileContext) {
		ref<Symbol> sym = lookup("compare", compileContext);
		if (sym != null && sym.class == Overload) {
			ref<Overload> o = ref<Overload>(sym);
			for (int i = 0; i < o.instances().length(); i++) {
				ref<OverloadInstance> oi = (*o.instances())[i];
				oi.assignType(compileContext);
				if (oi.parameterCount() != 1)
					continue;
				if ((*oi.parameterScope().parameters())[0].type() == 
							compileContext.builtInType(runtime.TypeFamily.STRING))
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
		return copyToImage(target, runtime.TypeFamily.VOID);
	}

	public int copyToImage(ref<Target> target, runtime.TypeFamily preferredFamily) {
		if (_ordinal == 0) {
//			address a = allocateImageData(target, Type.bytes);
//			ref<Type> t = ref<Type>(a);
//			*t = *this;
//			*ref<long>(t) = 0;
		}
		print();
		assert(false);
		return _ordinal;
	}
	
	protected void transferBase(ref<Type> copy) {
		copy._family = _family;
		copy._resolved = _resolved;
	}
/*	
	protected void copyClassToImage(ref<Target> target, ref<runtime.Class> template) {
		_ordinal = target.copyClassToImage(this, template);
	}
	
	protected void copyInterfaceToImage(ref<Target> target, ref<runtime.Interface> template) {
		_ordinal = target.copyInterfaceToImage(this, template);
	}
 */
	public boolean equals(ref<Type> other) {
		if (this == other)
			return true;
		if (this.class != other.class)
			return false;
		if (_family != other._family)
			return false;
		return sameAs(other);
	}
	/**
	 * This is the implementation method for class <. This is a subtype of other if other is one of the base class chain.
	 * 
	 * @param other The possible base class of this.
	 *
	 * @return true if other is a base class of this, false otherwise.
	 */
	public boolean isSubtype(ref<Type> other) {
		ref<Type> base = getSuper();
		if (base == null)
			return false;
		if (base.equals(other))
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

	public int interfaceCount() {
		return 0;
	}
	
	public ref<ref<InterfaceType>[]> interfaces() {
		return null;
	}
	/**
	 * Returns the offset of the interface in the type
	 * 
	 * If the implementsIndex >= interfaceCount() for the type, the behavior is undefined.
	 */
	public int interfaceOffset(int implementsIndex, ref<CompileContext> compileContext) {
		return -1;
	}

	public boolean allowedInRPCs(ref<CompileContext> compileContext) {
		switch (_family) {
		case ENUM:
		case FLAGS:
			return true;

		default:
			if (_family.hasMarshaller())
				break;
//			printf("Not allowed: %s %s\n", signature(), string(_family));
		}
		return _family.hasMarshaller();
	}
	/**
	 * Return the indirect type pointed to by a ref/pointer type.
	 *
	 * @param compileContext The current compile context. This may be needed to resolve 
	 * the current compilation's 'address' type.
	 *
	 * @return The type of the object pointed to, if any. This method returns null for
	 * types that are not reference types.
	 */
	public ref<Type> indirectType(ref<CompileContext> compileContext) {
		return null;
	}
	
	public ref<Type> elementType() {
		printf("elementType of %s\n", signature());
		assert(false);
		return null;
	}
	
	public ref<Type> indexType() {
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
	
	public ref<Type> mapIterator(ref<CompileContext> compileContext) {
		return null;
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

	boolean isLockable() {
		return false;
	}
	
	public boolean isMonitorClass() {
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

	boolean isSigned() {
		switch (_family) {
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

	boolean canCheckEquality(ref<CompileContext> compileContext) {
		return false;
	}

	boolean canCheckOrder(ref<CompileContext> compileContext) {
		return false;
	}

	boolean canCheckPartialOrder(ref<CompileContext> compileContext) {
		return false;
	}

	string myType() {
		if (this.class == Type)
			return "Type";
		else if (this.class == BuiltInType)
			return "BuiltInType";
		else if (this.class == InterfaceType)
			return "InterfaceType";
		else if (this.class == ClassType)
			return "ClassType";
		else if (this.class == EnumInstanceType)
			return "EnumInstanceType";
		else if (this.class == FlagsInstanceType)
			return "FlagsInstanceType";
		else if (this.class == FunctionType)
			return "FunctionType";
		else if (this.class == TemplateType)
			return "TemplateType";
		else if (this.class == TemplateInstanceType)
			return "TemplateInstanceType";
		else if (this.class == TypedefType)
			return "TypedefType";
		else if (this.class == EnumType)
			return "EnumType";
		else if (this.class == FlagsType)
			return "FlagsType";
		else
			return "???Type";
	}

	public boolean isString() {
		switch (family()) {
		case STRING:
		case STRING16:
		case SUBSTRING:
		case SUBSTRING16:
			return true;

		default:
			return false;
		}
		return false;
	}

	public boolean isFloat() {
		switch (_family) {
		case	FLOAT_32:
		case	FLOAT_64:
			return true;
			
		default:
			return false;
		}
		return false;
	}
	
	public ref<Type> wrappedType() {
		return null;
	}

	public boolean requiresAutoStorage() {
		switch (_family) {
		case	TYPEDEF:
		case	ERROR:
		case	CLASS_DEFERRED:
			return false;

		default:
			return !derivesFrom(runtime.TypeFamily.NAMESPACE);
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
			printf("resolve error %s\n", signature());
			assert(false);
			_family = runtime.TypeFamily.ERROR;
		} else {
			_resolving = true;
			doResolve(compileContext);
		}
		_resolving = false;
		_resolved = true;
	}
	/**
	 * This method assumes it is being called for an 'extends' clause expression.
	 */
	public boolean isCircularExtension(ref<Scope> derivedScope, ref<CompileContext> compileContext) {
		if (scope() == derivedScope)
			return true;
		if (busy)				// Hitting a busy loop means somebody else is circular, can this happen?
			return false;
		ref<Type> base = assignSuper(compileContext);
		if (base == null)
			return false;		// We hit bottom and didn't see the same class again, woo hoo!
		busy = true;
		boolean result = base.isCircularExtension(derivedScope, compileContext);
		busy = false;
		return result;
	}
	
	public boolean monitorCanExtend(ref<CompileContext> compileContext) {
		if (isMonitor())
			return true;
		ref<Type> base = assignSuper(compileContext);
		if (base == null)
			return false;		// We hit bottom and didn't see a monitor, so no dice.
		return base.monitorCanExtend(compileContext);
	}

	public ref<Symbol> lookup(substring name, ref<CompileContext> compileContext) {
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
		if (other == compileContext.builtInType(runtime.TypeFamily.VAR)){
			return true;
		}
		if (extendsFormally(other, compileContext))
			return true;
		ref<Type> ind = indirectType(compileContext);
		if (ind != null) {
			ref<Type> otherInd = other.indirectType(compileContext);
			if (otherInd == null)
				return false;
			if (family() != runtime.TypeFamily.POINTER &&
				other.family() == runtime.TypeFamily.POINTER)
				return false;
			if (ind == otherInd)
				return true;
			return ind.extendsFormally(otherInd, compileContext);
		}
		return false;
	}

	public boolean builtInCoercionFrom(ref<Node> n, ref<CompileContext> compileContext) {
		if (_family == runtime.TypeFamily.VAR)
			return true;
		if (n.op() == Operator.OBJECT_AGGREGATE)
			return true;
		switch (n.type._family) {
		case	VAR:
			return true;

		case	POINTER:
			switch (_family) {
			case	STRING:
			case	STRING16:
				ref<Type> object = n.type.indirectType(compileContext);
				if (object != null && object.family() == runtime.TypeFamily.UNSIGNED_8)
					return false;									// This is a string/string16 constructor
				else
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
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	BOOLEAN:
			case	ENUM:
			case	FLAGS:
			case	FUNCTION:
			case	INTERFACE:
				return true;
			}
			break;
			
		case	FUNCTION:
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
		case	ADDRESS:
		case	REF:
		case	BOOLEAN:
		case	FLAGS:
		case	INTERFACE:
			switch (_family) {
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
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	BOOLEAN:
			case	ENUM:
			case	FLAGS:
			case	FUNCTION:
			case	INTERFACE:
				return true;

			case STRING:
			case STRING16:
				if (n.op() == Operator.NULL)
					return true;
			}
			break;

		case	CLASS:
			if (_family == runtime.TypeFamily.INTERFACE)
				return true;
			break;

		case	ENUM:
			switch (_family) {
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
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	BOOLEAN:
			case	ENUM:
			case	STRING:
			case	STRING16:
			case	FLAGS:
			case	FUNCTION:
			case	INTERFACE:
				return true;
			}
			break;
		}
		return false;
	}

	public boolean derivesFrom(runtime.TypeFamily family) {
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
		return int(_family) < int(runtime.TypeFamily.BUILTIN_TYPES);
	}

	public boolean isException() {
		if (_family == runtime.TypeFamily.EXCEPTION)
			return true;
		ref<Type> sup = getSuper();
		if (sup == null)
			return false;
		else
			return sup.isException();
	}

	public boolean isConcrete(ref<CompileContext> compileContext) {
		return true;
	}

	public boolean isInterface() {
		return false;
	}

	public boolean isFinal() {
		return false;
	}

	public ref<OverloadInstance> firstAbstractMethod(ref<CompileContext> compileContext) {
		return null;
	}


	/**
	 * Note: If the interfaceType is not actually an interface, or is null, this function
	 * will always return false.
	 * 
	 * RETURNS: True if this type implements the named interface. False otherwise.
	 */
	public boolean doesImplement(ref<Type> interfaceType, ref<CompileContext> compileContext) {
		return false;
	}
	/**
	 * Note: If the interfaceType is not actually an interface, or is null, this function
	 * will always return -1.
	 * 
	 * RETURNS: an offset >= 0 if this type implements the named interface. -1 otherwise.
	 */
	public int interfaceOffset(ref<Type> interfaceType, ref<CompileContext> compileContext) {
		return -1;
	}
	
	public boolean deferAnalysis() {
		return _family == runtime.TypeFamily.ERROR || _family == runtime.TypeFamily.CLASS_DEFERRED;
	}

	public boolean baseChainDeferAnalysis() {
		if (deferAnalysis())
			return true;
		ref<Type> sup = getSuper();
		if (sup != null)
			return sup.baseChainDeferAnalysis();
		else
			return false;
	}

	public runtime.TypeFamily family() {
		return _family;
	}

	protected void doResolve(ref<CompileContext> compileContext) {
		assert(false);
	}

	protected boolean sameAs(ref<Type> other) {
		// runtime.TypeFamily.ERROR is a unique type, so it is unclear
		// how we could get here, but they should not be 'the same'
		return false;
	}
}
/*
public class ClassTemplate {
	runtime.Class template;
	int ordinal;
}

public class InterfaceTemplate {
	runtime.Interface template;
	int ordinal;
}

public int getOrdinal(ref<runtime.Class> template) {
	return *ref<int>(pointer<runtime.Class>(template) + 1);
}

public int getOrdinal(ref<runtime.Interface> template) {
	return *ref<int>(pointer<runtime.Interface>(template) + 1);
}
 */
int[runtime.TypeFamily] familySize = [
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
	STRING16: 			 8,
	SUBSTRING: 			16,
	SUBSTRING16: 		16,
	VAR: 				16,
	VOID: 				-1,
	ERROR: 				-1,
	BUILTIN_TYPES: 		-1,
	CLASS: 				-1,
	INTERFACE:			 8,
	ARRAY_AGGREGATE: 	16,
	OBJECT_AGGREGATE: 	24,
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

int[runtime.TypeFamily] familyAlignment = [
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
	STRING16: 			 8,
	SUBSTRING: 			 8,
	SUBSTRING16: 		 8,
	VAR: 				 8,
	VOID: 				-1,
	ERROR: 				-1,
	BUILTIN_TYPES: 		-1,
	CLASS: 				-1,
	INTERFACE:			 8,
	ARRAY_AGGREGATE: 	 8,
	OBJECT_AGGREGATE: 	 8,
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

string[runtime.TypeFamily] builtinName = [
  	SIGNED_8:			"Signed<8>",
  	SIGNED_16:			"short",
  	SIGNED_32:			"int",
  	SIGNED_64:			"long",
  	UNSIGNED_8:			"byte",
  	UNSIGNED_16:		"char",
  	UNSIGNED_32:		"unsigned",
  	UNSIGNED_64:		"Unsigned<64>",
  	FLOAT_32:			"float",
  	FLOAT_64:			"double",
  	BOOLEAN:			"boolean",
  	ADDRESS:			"address",
  	STRING: 			"string",
  	STRING16: 			"string16",
  	SUBSTRING: 			"substring",
  	SUBSTRING16: 		"substring16",
  	VAR: 				"var",
  	VOID: 				"void",
  	ERROR: 				"<error>",
	EXCEPTION:			"Exception",
	CLASS_VARIABLE:		"ref<runtime.Class>",
	CLASS_DEFERRED:		"<deferred class>",
	NAMESPACE:			"namespace",
	ARRAY_AGGREGATE:	"Array",
	OBJECT_AGGREGATE:	"Object"
  ];

