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

import parasol:storage.File;

public enum StorageClass {
	ERROR,
	AUTO,
	PARAMETER,
	MEMBER,
	STATIC,
	TEMPLATE,
	TEMPLATE_INSTANCE,
	ENUMERATION,
	FLAGS,
	ENCLOSING,
	LOCK,
	MAX_STORAGE_CLASS
}

enum Callable {
	DEFER,
	NO,
	YES
}

int NOT_PARAMETERIZED_TYPE = -1000000;

public int FIRST_USER_METHOD = 2;

public class ClassScope extends ClasslikeScope {
	public ClassScope(ref<Scope> enclosing, ref<Node> definition, ref<Identifier> className) {
		super(enclosing, definition, className);
	}

	protected ClassScope(ref<Scope> enclosing, ref<Node> definition, StorageClass storageClass, ref<Identifier> className) {
		super(enclosing, definition, storageClass, className);
	}

	protected void visitAll(ref<Target> target, int offset, ref<CompileContext> compileContext) {
		for (int i = 0; i < _members.length(); i++) {
			ref<Symbol> sym = _members[i];
			target.assignStorageToObject(sym, this, offset, compileContext);
		}
	}

	public boolean isMonitor() {
		return _definition != null && _definition.op() == Operator.MONITOR_CLASS;
	}
}

class MonitorScope extends ClassScope {
	public MonitorScope(ref<Scope> enclosing, ref<Node> definition, ref<Identifier> className) {
		super(enclosing, definition, className);
	}
	
}

public class LockScope extends Scope {
	private ref<Node> _monitor;
	
	public ref<Variable> lockTemp;			// The temp used to hold the reference to the monitor being locked.
	
	public LockScope(ref<Scope> enclosing, ref<Node> definition) {
		super(enclosing, definition, StorageClass.LOCK, null);
		ref<Block> b = ref<Block>(definition);
		if (b.statements().node.op() != Operator.EMPTY) {
			ref<Unary> u = ref<Unary>(b.statements().node);
			_monitor = u.operand();
		}
	}

	public ref<Symbol> lookup(ref<CompileString> name, ref<CompileContext> compileContext) {
		ref<Symbol> sym = super.lookup(name, compileContext);
		if (sym != null)
			return sym;
		if (_monitor != null) {
			if (_monitor.type == null || _monitor.type.family() == TypeFamily.ERROR)
				return null;
			sym = _monitor.type.lookup(name, compileContext);
//			printf("Looking for %s in %s found %p\n", name.asString(), _monitor.type.signature(), sym);
			if (sym == null) {
				if (_monitor.type.baseChainDeferAnalysis())
					return definePlaceholderDelegate(name, compileContext.arena().builtInType(TypeFamily.CLASS_DEFERRED), compileContext.pool());
				else
					return null;
			}
			return defineDelegate(sym, compileContext.pool());
		}
		return null;
	}

	void printDetails() {
		printf(" lockTemp %p", lockTemp);
	}
}

class ClasslikeScope extends Scope {
	public ref<ClassType> classType;
	
	private ref<OverloadInstance>[] _methods;
	private ref<InterfaceImplementationScope>[] _interfaces;
	private int _reservedInterfaceSlots;
	protected ref<Symbol>[] _members;
	private boolean _methodsBuilt;
	private boolean _defaultConstructorChecked;
	
	public address vtable;				// scratch area for code generators.

	public ClasslikeScope(ref<Scope> enclosing, ref<Node> definition, ref<Identifier> className) {
		super(enclosing, definition, StorageClass.MEMBER, className);
	}

	ClasslikeScope(ref<Scope> enclosing, ref<Node> definition, StorageClass storageClass, ref<Identifier> className) {
		super(enclosing, definition, storageClass, className);
	}

	public ref<Scope> base(ref<CompileContext> compileContext) {
		if (classType == null)
			return null;
		ref<Type> base = classType.assignSuper(compileContext);
		if (base != null)
			return base.scope();
		else
			return null;
	}

	public  ref<Type> assignSuper(ref<CompileContext> compileContext) {
		if (classType != null)
			return classType.assignSuper(compileContext);
		return null;
	}

	public ref<Type> getSuper() {
		if (classType != null)
			return classType.getSuper();
		return null;
	}

	ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> source, ref<Node> declaration, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		ref<Symbol> sym = super.define(visibility, storageClass, annotations, source, declaration, initializer, memoryPool);
		if (sym != null)
			_members.append(sym);
		return sym;
	}

	public void createPossibleDefaultConstructor(ref<CompileContext> compileContext) {
		if (_defaultConstructorChecked)
			return;
		_defaultConstructorChecked = true;
		if (constructors().length() == 0) {
			if (hasBaseConstructor(compileContext) || hasMembersNeedingInitialization(compileContext)) {
				ref<ParameterScope> functionScope = compileContext.arena().createParameterScope(this, null, ParameterScope.Kind.DEFAULT_CONSTRUCTOR);
//				printf("scope = %p ", this);
//				printf("functionScope = %p\n---\n", functionScope);
				defineConstructor(functionScope, compileContext.pool());
				if (compileContext.arena().verbose) {
					ref<Scope> baseClass = base(compileContext);
					if (baseClass != null)
						printf("current %p tree = %p base constructors %d constructors %d\n", compileContext.current(), compileContext.tree(), baseClass.constructors().length(), constructors().length());
					else
						printf("current %p tree = %p constructors %d\n", compileContext.current(), compileContext.tree(), constructors().length());
					print(4, false);
					printf("=== End default constructor check ===\n");
				}
	//			assert(false);
			}
		}
	}
	
	private boolean hasBaseConstructor(ref<CompileContext> compileContext) {
		// We know this is called after the class itself is largely resolved.
		// In particular, we know that any value for the base class is already correctly set.
		ref<Type> baseType = getSuper();
		if (baseType == null)
			return false;
		ref<Scope> baseClass = baseType.scope();
		if (baseClass == null)
			return false;
		baseClass.createPossibleDefaultConstructor(compileContext);
		if (baseClass.constructors().length() == 0)
			return false;
		else
			return true;
	}
	
	private boolean hasMembersNeedingInitialization(ref<CompileContext> compileContext) {
		for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.class != PlainSymbol || sym.storageClass() != StorageClass.MEMBER)
				continue;
//			printf("hasVtable? %s hasDefaultConstructor? %s\n", sym.type().hasVtable(compileContext) ? "true" : "false", sym.type().defaultConstructor() != null ? "true" : "false");
//			sym.print(0, false);
			sym.assignType(compileContext);
			switch (sym.type().family()) {
			case	POINTER:
			case	REF:
			case	ADDRESS:
			case	ENUM:
			case	BOOLEAN:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	FLOAT_32:
			case	FLOAT_64:
			case	STRING:
			case	FUNCTION:
			case	OBJECT_AGGREGATE:
			case	ARRAY_AGGREGATE:
			case	INTERFACE:
				return true;
				
			case	SHAPE:
			case	CLASS:
				if (sym.type().hasVtable(compileContext))
					return true;
				else if (sym.type().hasDefaultConstructor())
					return true;
				break;
				
			case	CLASS_DEFERRED:
			case	ERROR:
			case	TYPEDEF:
			case	VOID:				// This would be an error, but that will be flagged elsewhere.
				return false;
				
			default:
				sym.print(0, false);
				assert(false);
			}
		}
		return false;
	}
	
	public boolean createPossibleImpliedDestructor(ref<CompileContext> compileContext) {
		if (needsImpliedDestructor(compileContext)) {
			ref<ParameterScope> functionScope = compileContext.arena().createParameterScope(this, null, ParameterScope.Kind.IMPLIED_DESTRUCTOR);
			defineDestructor(functionScope, compileContext.pool());
			return true;
		} else
			return false;
	}
	/**
	 * TODO: This decision function is not quite complete. If there is a class hierarchy in which any sub-class has an
	 * explicit, or implied, destructor, then the common base class must have a Vtable.
	 * 
	 * On the other hand, if you have a class hierarchy in which there are no destructors anywhere in the entire tree,
	 * there is no need to generate a bunch of implied destructors for no reason whatsoever.
	 */
	private boolean needsImpliedDestructor(ref<CompileContext> compileContext) {
		if (destructor() == null) {
			if (hasVtable(compileContext))
				return true;
			for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
				ref<Symbol> sym = i.get();
				if (sym.type() == null)
					continue;
				if (sym.type().hasDestructor())
					return true;
			}
			// We know this is called after the class itself is largely resolved.
			// In particular, we know that any value for the base class is already correctly set.
			ref<Type> baseType = getSuper();
			if (baseType == null)
				return false;
			if (baseType.hasDestructor())
				return true;
		}
		return false;
	}		
	
	public void checkVariableStorage(ref<CompileContext> compileContext) {
		if (storageClass() == StorageClass.MEMBER) {
			if (enclosing() != null && enclosing().storageClass() == StorageClass.TEMPLATE)
				return;
			int baseOffset = 0;
			if (hasVtable(compileContext))
				baseOffset += address.bytes;
			checkStorage(compileContext);
		} else
			super.checkVariableStorage(compileContext);
	}
	
	public void assignVariableStorage(ref<Target> target, ref<CompileContext> compileContext) {
		if (storageClass() == StorageClass.MEMBER) {
			if (enclosing() != null && enclosing().storageClass() == StorageClass.TEMPLATE)
				return;
			int baseOffset = 0;
			if (hasVtable(compileContext))
				baseOffset += address.bytes;
			int interfaceArea = _reservedInterfaceSlots * address.bytes;
			assignStorage(target, baseOffset, interfaceArea, compileContext);
		} else
			super.assignVariableStorage(target, compileContext);
	}

	protected void assignStorage(ref<Target> target, int offset, int interfaceArea, ref<CompileContext> compileContext) {
		if (variableStorage == -1) {
			super.assignStorage(target, offset, interfaceArea, compileContext);
			int thunkOffset = interfaceOffset(compileContext);
			for (int i = 0; i < _interfaces.length(); i++) {
				if (_interfaces[i].baseInterface() != null)
					_interfaces[i].thunkOffset = _interfaces[i].baseInterface().thunkOffset;
				else {
					_interfaces[i].thunkOffset = thunkOffset;
					thunkOffset += 8;
				}
			}
		}
	}

	public int interfaceOffset(ref<CompileContext> compileContext) {
		ref<Type> base = assignSuper(compileContext);
		if (base != null)
			return base.size();
		else if (hasVtable(compileContext))
			return address.bytes;
		else
			return 0;
	}

	public int firstMemberOffset(ref<CompileContext> compileContext) {
		int reservedSpace = _reservedInterfaceSlots * address.bytes;
		ref<Type> base = assignSuper(compileContext);
		if (base != null)
			reservedSpace += base.size();
		else if (hasVtable(compileContext))
			reservedSpace += address.bytes;
		return reservedSpace;
	}
	
	public void checkForDuplicateMethods(ref<CompileContext> compileContext) {
		for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.class == Overload)
				ref<Overload>(sym).checkForDuplicateMethods(compileContext);
		}
	}

	public void assignMethodMaps(ref<CompileContext> compileContext) {
		// method map must be built out here
		if (!_methodsBuilt) {
			_methodsBuilt = true;
			ref<Type> base = assignSuper(compileContext);
			if (base != null) {
				// Seed the method table with the base class method table.
				ref<Scope> baseScope = base.scope();
				if (baseScope != null && baseScope.storageClass() == StorageClass.MEMBER) {
					baseScope.assignMethodMaps(compileContext);
					ref<ClassScope> baseClass = ref<ClassScope>(baseScope);
					for (int i = 0; i < baseClass._methods.length(); i++)
						_methods.append(baseClass._methods[i]);
				}
			}
			int maxMatchableMethod = _methods.length();
			for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
				ref<Symbol> sym = i.get();
				if (sym.class == Overload) {
					ref<Overload> o = ref<Overload>(sym);
					for (int i = 0; i < o.instances().length(); i++) {
						ref<OverloadInstance> oi = (*o.instances())[i];
//						printf("methods in map: %d\n", _methods.length());
						oi.assignType(compileContext);
						int index = matchingMethod(oi, maxMatchableMethod);
						if (index >= 0) {
							oi.offset = index + FIRST_USER_METHOD;
							_methods[index].overrideMethod();
							_methods[index] = oi;
						} else {
							oi.offset = _methods.length() + FIRST_USER_METHOD;
							_methods.append(oi);
						}
					}
				}
			}
			if (classType != null) {
				// First, copy in the base-class interface implementations.
				if (base != null) {
					ref<Scope> baseScope = base.scope();
					if (baseScope != null && baseScope.storageClass() == StorageClass.MEMBER) {
						ref<ClassScope> baseClass = ref<ClassScope>(baseScope);
						ref<ref<InterfaceImplementationScope>[]> interfaces = baseClass.interfaces();
						for (int i = 0; i < interfaces.length(); i++) {
							ref<InterfaceImplementationScope> iface = (*interfaces)[i];
							if (iface.implementingClass().destructor() != classType.destructor()) {
								iface = compileContext.arena().createInterfaceImplementationScope(iface.iface(), classType, iface, 0);
								iface.defineDestructor(compileContext.arena().createThunkScope(iface, destructor(), true), compileContext.pool());
							} else
								iface = mergeNovelImplementationMethods(iface, compileContext);
							iface.makeThunks(compileContext);
							_interfaces.append(iface);
						}
					}
				}
				assert(definition() != null);
				compileContext.assignTypes(this, definition());
				// Now build out the InterfaceImplementationScope objects (for their vtables).
				ref<ref<InterfaceType>[]> interfaces = classType.interfaces();
				if (interfaces != null) {
					for (int i = 0; i < interfaces.length(); i++) {
						ref<InterfaceType> iface = (*interfaces)[i];
						iface.scope().assignMethodMaps(compileContext);
						for (int j = 0; ; j++) {
							if (j >= _interfaces.length()) {
								ref<InterfaceImplementationScope> impl = compileContext.arena().createInterfaceImplementationScope(iface, classType, _reservedInterfaceSlots);
								impl.defineDestructor(compileContext.arena().createThunkScope(impl, destructor(), true), compileContext.pool());
								_reservedInterfaceSlots++;
								impl.makeThunks(compileContext);
								_interfaces.append(impl);
								break;
							}
							if (_interfaces[j].iface() == iface)
								break;
						}
					}
				}
			}
		}
	}
	
	public ref<InterfaceImplementationScope> mergeNovelImplementationMethods(ref<InterfaceImplementationScope> iface, ref<CompileContext> compileContext) {
		ref<InterfaceType> ifaceDefinition = iface.iface();
		ref<Scope> scope = ifaceDefinition.scope();
		if (scope.storageClass() == StorageClass.MEMBER){
			ref<ClassScope> interfaceClass = ref<ClassScope>(scope);
			ref<ref<OverloadInstance>[]> methods = interfaceClass.methods();
			for (int j = 0; j < methods.length(); j++) {
				for (int k = 0; k < _methods.length(); k++) {
					if (_methods[k].overrides((*methods)[j])) {
						// Bingo, we need a new interface implementation for this particular class, and we need to populate it.
						ref<InterfaceImplementationScope> impl = compileContext.arena().createInterfaceImplementationScope(ifaceDefinition, classType, iface, j);
						impl.defineDestructor(compileContext.arena().createThunkScope(impl, destructor(), true), compileContext.pool());
						return impl;
					}
				}
			}
		}
		return iface;
	}

	public boolean isBaseScope(ref<Scope> derived, ref<CompileContext> compileContext) {
		for (;;) {
			ref<Scope> base = derived.base(compileContext);
			if (base == null)
				return false;
			if (base == this)
				return true;
			derived = base;
		}
	}

	public boolean isConcrete(ref<CompileContext> compileContext) {
		assignMethodMaps(compileContext);
		for (int i = 0; i < _methods.length(); i++)
			if (!_methods[i].isConcrete(compileContext)) {
				return false;
			}
		return true;
	}

	public ref<OverloadInstance> firstAbstractMethod(ref<CompileContext> compileContext) {
		assignMethodMaps(compileContext);
		for (int i = 0; i < _methods.length(); i++)
			if (!_methods[i].isConcrete(compileContext)) {
				return _methods[i];
			}
		return null;
	}
	/**
	 * Note: the vtable member is set by code generators and is set late in the process.
	 * 
	 *  
	 */
	public boolean hasVtable(ref<CompileContext> compileContext) {
		if (vtable != null)
			return true;
		ref<Type> base = getSuper();
		if (base != null &&
			base.hasVtable(compileContext))
			return true;
		assignMethodMaps(compileContext);
		for (int i = 0; i < _methods.length(); i++)
			if (_methods[i].overridden() || !_methods[i].isConcrete(compileContext))
				return true;
		return false;
	}

	public boolean hasThis() {
		return true;
	}

	public ref<ref<OverloadInstance>[]> methods() {
		return &_methods;
	}

	private int matchingMethod(ref<OverloadInstance> candidate, int maxMatchableMethod) {
		for (int i = 0; i < maxMatchableMethod; i++) {
			if (candidate.overrides(_methods[i])) {
				switch (_methods[i].visibility()) {
				case PRIVATE:
					if (!_methods[i].enclosing().encloses(this))	// If the existing method's scope does not enclose this scope, 
																	// it is not visible and the candidate does not override.
						continue;
					break;

				case NAMESPACE:
					ref<Namespace> nm = _methods[i].enclosingNamespace();
					if (nm == null) {								// Only methods in the same namespace can override
						if (enclosingUnit() != _methods[i].enclosingUnit())
							continue;
					} else if (nm != getNamespace())
						continue;
				}
				return i;
			}
		}
		return -1;
	}
	
	public ref<ref<Symbol>[]> members() {
		return &_members;
	}

	public boolean isInterface() {
		return classType != null && classType.class == InterfaceType;
	}
	
	public int interfaceCount() {
		return _interfaces.length();
	}
	
	public ref<ref<InterfaceImplementationScope>[]> interfaces() {
		return &_interfaces;
	}
	
	void printDetails() {
		if (classType != null)
			printf(" classType %s", classType.signature());
	}
}

public class InterfaceImplementationScope extends ClassScope {
	public int thunkOffset;

	private ref<InterfaceType> _interface;
	private ref<ClassType> _implementingClass;
	private ref<OverloadInstance>[] _methods;
	private ref<ThunkScope>[] _thunks;
	private ref<InterfaceImplementationScope> _baseInterface;
	private int _itableSlot;
	
	InterfaceImplementationScope(ref<InterfaceType> definedInterface, ref<ClassType> implementingClass, int itableSlot) {
		super(implementingClass.scope(), null, StorageClass.STATIC, null);
		_interface = definedInterface;
		classType = _interface;
		_implementingClass = implementingClass;
		_itableSlot = itableSlot;
		populateFromBase(null, 0);
	}
	
	InterfaceImplementationScope(ref<InterfaceType> definedInterface, ref<ClassType> implementingClass, ref<InterfaceImplementationScope> baseInterface, int firstNewMethod) {
		super(implementingClass.scope(), null, StorageClass.STATIC, null);
		_interface = definedInterface;
		classType = _interface;
		_implementingClass = implementingClass;
		_baseInterface = baseInterface;
		populateFromBase(baseInterface, firstNewMethod);
	}
	/**
	 * This populates the method table for this implementation based on the baseInterface.
	 *
	 * Note that the Number of methods matching does not have to equal the number of methods on the interface. Such an interface
	 * is missing a method in the class, so the class definition is broken. Any effort to use this InterfaceImplementation should fail
	 */
	private void populateFromBase(ref<InterfaceImplementationScope> baseInterface, int firstNewMethod) {
		for (int i = 0; i < firstNewMethod; i++)
			_methods.append(baseInterface._methods[i]);
		ref<ClassScope> scope = ref<ClassScope>(_interface.scope());
		ref<ref<OverloadInstance>[]> interfaceMethods = scope.methods();
		scope = ref<ClassScope>(_implementingClass.scope());
		ref<ref<OverloadInstance>[]> classMethods = scope.methods();
		
		for (int j = firstNewMethod; j < interfaceMethods.length(); j++) {
			for (int k = 0; k < classMethods.length(); k++) {
				if ((*classMethods)[k].overrides((*interfaceMethods)[j])) {
					_methods.append((*classMethods)[k]);
					break;
				}
			}
			if (_methods.length() != j + 1) {
				// TODO: Didn't get a match, substitute in a dummy entry point that throws an exception in case code gets that far.
			}
		}
	}
	/**
	 * Each new interface implementation must define a thunk for each method implemented for this interface.
	 *
	 * The constructor combined an InterfaceType with a ClassType to produce a list of methods from the class (that correspond
	 * exactly to the methods of the interface itself). For each such class method, there needs to be a thunk at runtime
	 * to adjust the 'this' pointer from the interface object passed in the call to the class object that the class method
	 * will be referring to.
	 *
	 * At this stage, creating a ThunkScope for each method is sufficient. Later stages of code generation will
	 * produce the machine code for each thunk.
	 */
	public void makeThunks(ref<CompileContext> compileContext) {
		for (int i = _thunks.length(); i < _methods.length(); i++)
			_thunks.append(compileContext.arena().createThunkScope(this, _methods[i].parameterScope(), false));
	}
	
	public ref<InterfaceType> iface() {
		return _interface;
	}
	
	public ref<ClassType> implementingClass() {
		return _implementingClass;
	}
	
	public ref<InterfaceImplementationScope> baseInterface() {
		return _baseInterface;
	}
	
	public ref<ref<ThunkScope>[]> thunks() {
		return &_thunks;
	}
	
	public ref<ref<OverloadInstance>[]> methods() {
		return &_methods;
	}

	public int itableOffset(ref<CompileContext> compileContext) {
		if (_baseInterface != null)
			return _baseInterface.itableOffset(compileContext);
		else
			return ref<ClassScope>(_implementingClass.scope()).interfaceOffset(compileContext) + _itableSlot * address.bytes;
	}
	
	public boolean hasVtable(ref<CompileContext> compileContext) {
		return true;
	}

	public boolean hasThis() {
		return true;
	}

	public boolean isInterface() {
		return true;
	}
	
	public void assignMethodMaps(ref<CompileContext> compileContext) {
	}

	public void createPossibleDefaultConstructor(ref<CompileContext> compileContext) {
	}

	void printDetails() {
		printf(" %s implemented by %s", _interface.signature(), _implementingClass.signature());
	}
}

public class EnumScope extends ClassScope {
	public ref<EnumType> enumType;
	
	private ref<Symbol>[] _instances;
	
	public EnumScope(ref<Scope> enclosing, ref<Block> definition, ref<Identifier> enumName) {
		super(enclosing, definition, StorageClass.MEMBER, enumName);
	}

	ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> source, ref<Type> type, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		ref<Symbol> sym = super.define(visibility, storageClass, annotations, source, type, initializer, memoryPool);
		if (sym != null)
			_instances.append(sym);
		return sym;
	}

	public ref<ref<Symbol>[]> instances() {
		return &_instances;
	}
	/*
	 * Given a symbol, return the index of the symbol within this enumscope. THis allows us to properly
	 * validate aggregate initializers by calculating the numeric index of that element (in a labeled
	 * initializer).
	 * 
	 * RETURN:
	 *   >= 0	The index of the given enumInstance symbol.
	 *   -1		The enumInstance argument was not a member of this EnumScope.
	 */
	public int indexOf(ref<Symbol> enumInstance) {
		for (int i = 0; i < _instances.length(); i++)
			if (_instances[i] == enumInstance)
				return i;
		return -1;
	}
}

class FlagsScope extends ClasslikeScope {
	public ref<FlagsType> flagsType;
	
	private ref<Symbol>[] _instances;
	
	public FlagsScope(ref<Scope> enclosing, ref<Block> definition, ref<Identifier> enumName) {
		super(enclosing, definition, StorageClass.STATIC, enumName);
	}

	ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> source, ref<Type> type, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		ref<Symbol> sym = super.define(visibility, storageClass, annotations, source, type, initializer, memoryPool);
		if (sym != null)
			_instances.append(sym);
		return sym;
	}

	public ref<ref<Symbol>[]> instances() {
		return &_instances;
	}
	/*
	 * Given a symbol, return the index of the symbol within this enumscope. THis allows us to properly
	 * validate aggregate initializers by calculating the numeric index of that element (in a labeled
	 * initializer).
	 * 
	 * RETURN:
	 *   >= 0	The index of the given enumInstance symbol.
	 *   -1		The enumInstance argument was not a member of this EnumScope.
	 */
	public int indexOf(ref<Symbol> enumInstance) {
		for (int i = 0; i < _instances.length(); i++)
			if (_instances[i] == enumInstance)
				return i;
		return -1;
	}
}
/*
 * ParameterScope - a.k.a functionScope
 * 
 * This scope contains the parameter symbols for a function.  Any auto scopes of the function will have
 * a parent chain that extends to this scope.
 * 
 * A ParamaeterScope will be enclosed by a UnitScope, a ClassScope, or an auto Scope.  Note that for
 * function parameters, there may be nested ParameterScope's, but they are not very interesting as there
 * will never be any body attached to the inner ParameterScope.
 * 
 * Symbol searches are limited to the local lookup results.  A ParameterScoep always has a null base
 * scope.
 * 
 * Each of the three enclosing cases represents differnet things:
 * 
 *  Enclosing				Description
 *  
 *  UnitScope			The static initializers of a unit, such as a source file. They also never have
 *  					a 'this' pointer.
 *  					
 *  ClassScope			A method.  If this is an overridden method, it will have to be assigned a vtable
 *  					slot.  If the function is explicitly STATIC, then there will be no 'this' pointer,
 *  					but otherwise the function will have a 'this'.
 *  					
 *  auto Scope			A nested-function.  If the address of this function is not passed out, then we
 *  					can use an efficient 'display' based scheme to manage the bindings of the outer
 *  					function's auto storage and parameters.
 *  					
 *  					However, if the function's address is passed out, then one must construct a
 *  					closure and return the address of the closure.  In order to support this, all
 *  					methods must have a prefix address (null for static functions).  Then, in order
 *  					to manage the lifetime of the closure, someone must 'delete' the function.  For
 *  					closures, the closure will consist of the prefix address, which will be the 
 *  					vtable of the closure itself, then a small thunk that mniges the stack to 
 *  					affix the closure data and calls the static function code.
 *  					
 *  					The vtable of a closure calls a destructor that does any necessary destruction of
 *  					the closure data.
 *  					
 * The ParameterScope is the Scope recorded with the FunctionType for a function declaration.
 */
public class ParameterScope extends Scope {
	public enum Kind {
		FUNCTION,				// any ordinary constructor, destructor, method or function
		TEMPLATE,				// any template
		DEFAULT_CONSTRUCTOR,	// a default constructor (no source code) generated when needed
		IMPLIED_DESTRUCTOR,		// an implied destructor (no source code) generated when needed
		ENUM_TO_STRING,			// a generated enum-to-string coercion method
		FLAGS_TO_STRING,		// a generate flags-to-string coercion method
		THUNK,					// This is a thunk. 
	}
	private Kind _kind;
	private ref<Symbol>[] _parameters;
	private boolean _hasEllipsis;
		
	public address value;				// scratch area for use by code generators
	public boolean nativeBinding;		// true if this is an nativebinding-annotated external function
	
	public ParameterScope(ref<Scope> enclosing, ref<Node> definition, Kind kind) {
		super(enclosing, definition, 
				kind == Kind.TEMPLATE ? StorageClass.TEMPLATE : StorageClass.PARAMETER, null);
		_kind = kind;
	}

	public ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> definition, ref<Node> declaration, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		ref<Symbol> sym = super.define(visibility, storageClass, annotations, definition, declaration, initializer, memoryPool);
		if (sym != null)
			_parameters.append(sym);
		if (declaration != null && declaration.getProperEllipsis() != null)
			_hasEllipsis = true;
		return sym;
	}

	public ref<ref<Symbol>[]> parameters() {
		return &_parameters;
	}

	public int functionAddress() {
		return int(value) - 1;
	}

	string label() {
		switch (_kind) {
		case	DEFAULT_CONSTRUCTOR:
			string enc = enclosing().label();
			return enc + ".";
			
		case	IMPLIED_DESTRUCTOR:
			enc = enclosing().label();
			return enc + ".~";
		}
		return super.label();
	}

	public Kind kind() {
		return _kind;
	}
	
	public boolean hasEllipsis() {
		return _hasEllipsis;
	}
	
	public boolean hasThis() {
		ref<FunctionDeclaration> func = ref<FunctionDeclaration>(definition());
		
		if (func == null)		// a generated default constructor has no 'definition'
			return true;		// but it does have 'this'
		if (func.op() == Operator.UNIT)
			return false;
		if (func.name() != null && func.name().symbol() != null)
			return func.name().symbol().storageClass() == StorageClass.MEMBER;
		else
			return false;
	}
	
	public boolean isDestructor() {
		if (_kind == Kind.IMPLIED_DESTRUCTOR)
			return true;
		ref<FunctionDeclaration> func = ref<FunctionDeclaration>(definition());
		
		if (func == null)		// a generated default constructor has no 'definition'
			return false;		// but it does have 'this'
		else
			return func.functionCategory() == FunctionDeclaration.Category.DESTRUCTOR;
	}

	public ref<FunctionType> type() {
		ref<FunctionDeclaration> func = ref<FunctionDeclaration>(definition());
		if (func == null || func.type.family() != TypeFamily.FUNCTION)		// a generated default constructor has no 'definition'
			return null;													// and no type and an error has errorType.
		return ref<FunctionType>(func.type);
		
	}
	
	public ref<OverloadInstance> symbol() {
		ref<FunctionDeclaration> func = ref<FunctionDeclaration>(definition());
		if (func == null)		// a generated default constructor has no 'definition'
			return null;		// and no type.
		if (func.deferAnalysis())
			return null;
		return ref<OverloadInstance>(func.name().symbol());
	}
	
	public boolean hasOutParameter(ref<CompileContext> compileContext) {
		ref<FunctionDeclaration> func = ref<FunctionDeclaration>(definition());
		if (func == null)		// a generate default constructor has no 'definition'
			return false;		// and no out parameter.
		if (func.deferAnalysis())
			return false;
		ref<Type> fType;
		if (func.type == null)
			compileContext.assignTypeToNode(func);
		if (func.type.family() == TypeFamily.TYPEDEF) {
			assert(false);
			ref<TypedefType> tp = ref<TypedefType>(func.type);
			fType = tp.wrappedType();
		} else
			fType = func.type;
		ref<FunctionType> functionType = ref<FunctionType>(fType);
		ref<NodeList> returnType = functionType.returnType();
		if (returnType == null)
			return false;
		if (returnType.next != null)
			return true;
		else
			return returnType.node.type.returnsViaOutParameter(compileContext);
	}
	
	public boolean usesVTable(ref<CompileContext> compileContext) {
		if (isDestructor()) {
			// There is no definition, but the vtable will have a slot for virtual destructors.
			return enclosing().hasVtable(compileContext);
		}
		ref<FunctionDeclaration> func = ref<FunctionDeclaration>(definition());
		if (func == null)		// a generated default constructor has no 'definition'
			return false;		// and no VTable.
		if (enclosing().isInterface())
			return true;
		enclosing().assignMethodMaps(compileContext);
		return ref<OverloadInstance>(func.name().symbol()).overridden();
	}
	
	public boolean equals(ref<ParameterScope> other, ref<CompileContext> compileContext) {
		if (_parameters.length() != other._parameters.length())
			return false;
		for (int i = 0; i < _parameters.length(); i++) {
			ref<Symbol> otherParam = other._parameters[i];
			ref<Type> otherType = otherParam.assignType(compileContext);
			ref<Type> thisType = _parameters[i].assignType(compileContext);
			
			if (otherType == null || otherType.deferAnalysis() ||
				thisType == null || thisType.deferAnalysis())
				return false;
			if (!thisType.equals(otherType))
				return false;
		}
		return true;
	}
}

public class ThunkScope extends ParameterScope {
	ref<ParameterScope> _function;
	boolean _isDestructor;
	
	public ThunkScope(ref<InterfaceImplementationScope> enclosing, ref<ParameterScope> func, boolean isDestructor) {
		super(enclosing, null, Kind.THUNK);
		_function = func;
		_isDestructor = isDestructor;
	}
	
	public ref<ParameterScope> func() {
		if (_isDestructor)
			return ref<InterfaceImplementationScope>(enclosing()).implementingClass().destructor();
		else
			return _function;
	}

	public int thunkOffset() {
		return ref<InterfaceImplementationScope>(enclosing()).thunkOffset;
	}
	
	public boolean hasEllipsis() {
		return _function.hasEllipsis();
	}
	
	public boolean hasThis() {
		return true;
	}
	
	public boolean isDestructor() {
		return _isDestructor || _function.isDestructor();
	}

	public ref<FunctionType> type() {
		return _function.type();
	}
	
	public ref<OverloadInstance> symbol() {
		return _function.symbol();
	}
	
	public boolean hasOutParameter(ref<CompileContext> compileContext) {
		return _function.hasOutParameter(compileContext);
	}
	
	public boolean usesVTable(ref<CompileContext> compileContext) {
		return true;
	}

	void printDetails() {
		printf(" ThunkScope -> %p\n", _function);
	}
}

class RootScope extends Scope {
	private ref<FileStat> _file;

	public RootScope(ref<FileStat> file, ref<Node> definition) {
		super(null, definition, StorageClass.STATIC, null);
		_file = file;
	}

	public ref<FileStat> file() {
		return _file;
	}
}

class UnitScope extends Scope {
	private ref<FileStat> _file;
	
	public UnitScope(ref<Scope> rootScope, ref<FileStat> file, ref<Node> definition) {
		super(rootScope, definition, StorageClass.STATIC, null);
		_file = file;
	}

	public int functionAddress() {
		return -1;
	}

	public void mergeIntoNamespace(ref<Namespace> nm, ref<CompileContext> compileContext) {
		ref<Scope> namespaceScope = nm.symbols();
		for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.visibility() == Operator.PRIVATE)
				continue;
			if (sym.class == PlainSymbol) {
				ref<Symbol> n = namespaceScope.lookup(sym.name(), compileContext);
				if (n != null) {
					if (n.definition().countMessages() == 0)
						n.definition().add(MessageId.DUPLICATE, compileContext.pool(), *n.name());
					sym.definition().add(MessageId.DUPLICATE, compileContext.pool(), *sym.name());
				} else
					namespaceScope.put(sym, compileContext.pool());
			} else if (sym.class == Overload) {
				ref<Overload> o = ref<Overload>(sym);

				ref<Symbol> n = namespaceScope.lookup(sym.name(), compileContext);
				if (n == null) {
					ref<Overload> no = namespaceScope.defineOverload(sym.name(), o.kind(), compileContext);
					no.merge(o, compileContext);
				} else if (n.class == Overload) {
					ref<Overload> no = ref<Overload>(n);
					no.merge(o, compileContext);
				} else {
					if (n.definition().countMessages() == 0)
						n.definition().add(MessageId.DUPLICATE, compileContext.pool(), *n.name());
					o.markAsDuplicates(compileContext.pool());
				}
			}
		}
	}
	/**
	 * The 'base' scope of a unit scope is the scope of the unit's namespace.
	 */
	public ref<Scope> base(ref<CompileContext> compileContext) {
		return _file.namespaceSymbol().symbols();
	}

	public ref<Namespace> getNamespace() {
		return _file.namespaceSymbol();
	}

	public ref<UnitScope> enclosingUnit() {
		return this;
	}

	public ref<FileStat> file() {
		return _file;
	}
}

public class NamespaceScope extends Scope {
	private ref<Namespace> _namespaceSymbol;

	public NamespaceScope(ref<Scope> enclosing, ref<Namespace> namespaceSymbol) {
		super(enclosing, null, StorageClass.STATIC, null);
		_namespaceSymbol = namespaceSymbol;
	}

	public ref<Namespace> getNamespace() {
		return _namespaceSymbol;
	}
}

public class Scope {

	// Class-specific information

	private ref<Scope> _enclosing;
	private ref<Scope>[] _enclosed;
	private ref<ParameterScope>[] _constructors;
	private ref<ParameterScope> _destructor;

	protected ref<Symbol>[SymbolKey] _symbols;

	public class SymbolKey {
		ref<CompileString> _key;
		
		public SymbolKey() {}
		
		SymbolKey(ref<CompileString> key) {
			_key = key;
		}
		
		int compare(SymbolKey other) {
			return _key.compare(*other._key);
		}
		
		int hash() {
			if (_key.length == 1)
				return _key.data[0];
			else
				return _key.data[0] + (_key.data[_key.length - 1] << 7);
		}
	}

	// General block information

	private StorageClass _storageClass;
	ref<Node> _definition;
	private ref<Identifier> _className;

	// Code generation information

	public int variableStorage;			// number of bytes in scope's storage block (including enclosing/extended blocks)
	public long reservedInScope;		// registers reserved (used) in the scope.
	
	private boolean _checked;
	private boolean _printed;

	public Scope(ref<Scope> enclosing, ref<Node> definition, StorageClass storageClass, ref<Identifier> className) {
		_definition = definition;
		_className = className;
		_storageClass = storageClass;
		_enclosing = enclosing;
		variableStorage = -1;
		if (enclosing != null)
			enclosing._enclosed.append(this);
	}
	
	public void mergeIntoNamespace(ref<Namespace> nm, ref<CompileContext> compileContext) {
	}

	public void collectAutoScopesUnderUnitScope(ref<UnitScope> fileScope) {
		for (int i = 0; i < fileScope._enclosed.length(); i++) {
			ref<Scope> s = fileScope._enclosed[i]; 
			if (s.storageClass() == StorageClass.AUTO)
				_enclosed.append(s);
		}
	}
	
	public void createPossibleDefaultConstructor(ref<CompileContext> compileContext) {
	}
		
	public boolean createPossibleImpliedDestructor(ref<CompileContext> compileContext) {
		return false;
	}
		
	boolean writeHeader(ref<Writer> header) {
		for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.deferAnalysis())
				continue;
			if (sym.class == Namespace) {
				ref<Namespace> nm = ref<Namespace>(sym);
				nm.symbols().writeHeader(header);
				continue;
			}
			ref<Call> annotation = sym.getAnnotation("Header");
			if (annotation == null)
				continue;
			ref<NodeList> arguments = annotation.arguments();
			string prefix;
			
			if (arguments != null && arguments.node.op() == Operator.STRING) {
				ref<Constant> str = ref<Constant>(arguments.node);
				prefix = str.value().asString();
			}
			ref<Type> t = sym.type();
			if (t.family() == TypeFamily.TYPEDEF) {
				ref<TypedefType> tt = ref<TypedefType>(t);
				t = tt.wrappedType();
				if (t.family() == TypeFamily.ENUM) {
					header.printf("enum %s {\n", sym.name().asString());
					ref<EnumScope> s = ref<EnumScope>(t.scope());
					for (int i = 0; i < s.instances().length(); i++) {
						ref<Symbol> c = (*s.instances())[i];
						header.printf("\t%s%s,\n", prefix, c.name().asString());
					}
					header.printf("};\n");
				}
			}
//			header.write();
		}
		return true;
	}
	
	void assignTypes(ref<CompileContext> compileContext) {
		for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			sym.assignType(compileContext);
		}
	}

	void print(int indent, boolean printChildren) {
		if (int(_storageClass) < 0)
			printf("%*.*cScope %p[%d] storageClass <%d>", indent, indent, ' ', this, variableStorage, int(_storageClass));
		else
			printf("%*.*cScope %p[%d] %s", indent, indent, ' ', this, variableStorage, string(_storageClass));
		printf(" %p", _definition);
		if (_definition != null) {
			switch (_definition.op()) {
			case	FUNCTION:
				if (_definition.class != FunctionDeclaration) {
					printf(" not FunctionDeclaration");
					break;
				}
				ref<FunctionDeclaration> f = ref<FunctionDeclaration>(_definition);
				if (f.name() != null)
					printf(" func %s", f.name().value().asString());
				ref<ParameterScope> p = ref<ParameterScope>(this);
				if (p.hasEllipsis())
					printf(" has ellipsis");
				break;
				
			case	CLASS:
				if (_definition.class != Class) {
					printf(" Not a Class %p", _definition);
					break;
				}
				ref<Class> c = ref<Class>(_definition);
				if (c.name() != null) {
//					printf(" c.name %p\n", c.name());
//					c.name().print(4);
//					printf(" c.name.value %p %d\n", c.name().value().data, c.name().value().length);
					printf(" class %s", c.name().value().asString());
				}
				break;
				
			case	TEMPLATE:
				if (_definition.class != Template) {
					printf(" Not a Template");
					_definition.print(4);
					break;
				}
				ref<Template> t = ref<Template>(_definition);
				if (t.name() != null)
					printf(" template %s", t.name().value().asString());
				break;
				
			default:
				printf(" %s", string(_definition.op()));
			}
		}
		printDetails();
		printf(":\n");
		for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.enclosing() == this)
				i.get().print(indent + INDENT, printChildren);
			else
				printf("%*.*c    %s (imported)\n", indent, indent, ' ', sym.name().asString());
		}
		for (int i = 0; i < _constructors.length(); i++) {
			printf("%*.*c  {Constructor} %p\n", indent, indent, ' ', _constructors[i].definition());
			if (printChildren)
				_constructors[i].print(indent + INDENT, printChildren);
		}
		if (_destructor != null ) {
			printf("%*.*c  {Destructor} %p\n", indent, indent, ' ', _destructor.definition());
			if (printChildren)
				_destructor.print(indent + INDENT, printChildren);
		}
		if (_storageClass == StorageClass.MEMBER) {
			if (this.class == ClassScope) {
				ref<ClassScope> c = ref<ClassScope>(this);
				ref<ref<InterfaceImplementationScope>[]> interfaceImplementations = c.interfaces();
				for (int i = 0; i < interfaceImplementations.length(); i++) {
					ref<InterfaceImplementationScope> iit = (*interfaceImplementations)[i];
					printf("%*.*c  (Interface) %s\n", indent, indent, ' ', iit.iface().signature());
					for (int j = 0; j < iit.methods().length(); j++) {
						(*iit.methods())[j].print(indent + INDENT, false);
					}
				}
				printf("%*.*c  (Methods)\n", indent, indent, ' ');
				for (int i = 0; i < c.methods().length(); i++) {
					if ((*c.methods())[i] != null)
						(*c.methods())[i].print(indent + INDENT, false);
					else
						printf("%*.*c    <null>\n", indent, indent, ' ');
				}
			} else
				printf("%*.*c  <not a ClassScope>\n", indent, indent, ' ');
		}
		if (printChildren) {
			for (int i = 0; i < _enclosed.length(); i++) {
				if (!_enclosed[i].printed()) {
					switch (_enclosed[i].storageClass()) {
					case	AUTO:
					case	LOCK:
						break;

					case	MEMBER:
						if (_storageClass == StorageClass.TEMPLATE ||
							_storageClass == StorageClass.TEMPLATE_INSTANCE)
							break;

					default:
						printf("%*.*c  {Orphan}:\n", indent, indent, ' ');
					}
					_enclosed[i].print(indent + INDENT, printChildren);
				}
			}
		}
		_printed = true;
	}

	void printDetails() {
	}
	
	public void printStatus() {
		printf("%p %s %s", this, string(_storageClass), isTemplateFunction() ? "template function " : "");
		if (_definition != null) {
			ref<FileStat> fs = file();
			printf("%s %d: ", fs.filename(), fs.scanner().lineNumber(_definition.location()) + 1);
			
			printf("%s %s", string(_definition.op()), _definition.assignTypesBoundary() ? "type boundary " : "");
			if (_definition.op() == Operator.FUNCTION) {
				ref<FunctionDeclaration> func = ref<FunctionDeclaration>(_definition);
				if (func.referenced)
					printf("referenced ");
			}
			if (_definition.type != null)
				_definition.type.print();
			else {
				printf("no type");
			}
		} else
			printf("<no definition>");
		printf("\n");
	}
	
	public string sourceLocation(Location loc) {
		string result;
		ref<FileStat> fs = file();
		result.printf("%s %d: ", fs.filename(), fs.scanner().lineNumber(loc) + 1);
		return result;
	}
	
	string label() {
		if (_definition != null) {
			switch (_definition.op()) {
			case	FUNCTION:
				ref<FunctionDeclaration> f = ref<FunctionDeclaration>(_definition);
				if (f.functionCategory() == FunctionDeclaration.Category.DESTRUCTOR) {
					if (f.name() != null)
						return _enclosing.label() + ".~" + f.name().value().asString();
				} else if (f.name() != null)
					return _enclosing.label() + "." + f.name().value().asString();
				break;
				
			case	CLASS:
				ref<Class> c = ref<Class>(_definition);
				if (c.name() != null)
					return _enclosing.label() + "." + c.name().value().asString();
				break;
				
			case	TEMPLATE:
				ref<Template> t = ref<Template>(_definition);
				if (t.name() != null)
					return _enclosing.label() + "." + t.name().value().asString();
				break;
			}
		}
		ref<Namespace> nm = getNamespace();
		if (nm != null)
			return nm.dottedName();
		else
			return "[" + file().filename() + "]";
	}

	boolean defineImport(ref<Identifier> id, ref<Symbol> definition, ref<MemoryPool> memoryPool) {
		SymbolKey key(id.identifier());
		if (_symbols.contains(key))
			return false;
		_symbols.insert(key, definition);
		return true;
	}

	ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> source, ref<Node> declaration, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		SymbolKey key(source.identifier());
		if (_symbols.contains(key))
			return null;
	//	printf("Define %s\n", source.identifier().asString());
		ref<Symbol> sym  = memoryPool.newPlainSymbol(visibility, storageClass, this, annotations, source.identifier(), source, declaration, initializer);
		_symbols.insert(key, sym);
		return sym;
	}

	public ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> source, ref<Type> type, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		ref<Symbol> sym  = memoryPool.newPlainSymbol(visibility, storageClass, this, annotations, source.identifier(), source, type, initializer);
		SymbolKey key(source.identifier());
		if (_symbols.contains(key))
			return null;
		_symbols.insert(key, sym);
		return sym;
	}

	public ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, string name, ref<Type> type, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		CompileString cs = memoryPool.newCompileString(name);
		ref<CompileString> pcs = memoryPool new CompileString(cs.data, cs.length);
		ref<Symbol> sym  = memoryPool.newPlainSymbol(visibility, storageClass, this, annotations, pcs, null, type, initializer);
		SymbolKey key(pcs);
		if (_symbols.contains(key))
			return null;
		_symbols.insert(key, sym);
		return sym;
	}

	public ref<Overload> defineOverload(ref<CompileString> name, Operator kind, ref<CompileContext> compileContext) {
		ref<Symbol> sym = lookup(name, compileContext);
		ref<Overload> o;
		if (sym != null) {
			if (sym.class != Overload)
				return null;
			o = ref<Overload>(sym);
			if (o.kind() != kind)
				return null;
		} else {
			SymbolKey key(name);
			o = compileContext.pool().newOverload(this, name, kind);
			_symbols.insert(key, o);
		}
		return o;
	}

	public ref<Symbol> defineSimpleMonitor(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> source, ref<Type> type, ref<MemoryPool> memoryPool) {
		SymbolKey key(source.identifier());
		if (_symbols.contains(key))
			return null;
	//	printf("Define %s\n", source.identifier().asString());
		ref<Symbol> sym  = memoryPool.newPlainSymbol(visibility, storageClass, this, annotations, source.identifier(), source, type, null);
		_symbols.insert(key, sym);
		return sym;
	}

	public void defineConstructor(ref<ParameterScope> constructor, ref<MemoryPool> memoryPool) {
		_constructors.append(constructor);
	}

	public boolean defineDestructor(ref<ParameterScope> destructor, ref<MemoryPool> memoryPool) {
		if (_destructor != null) {
			ref<FunctionDeclaration> func = ref<FunctionDeclaration>(_destructor.definition());
			if (func.name().commentary() == null)
				func.name().add(MessageId.DUPLICATE_DESTRUCTOR, memoryPool);
			return false;
		}
		_destructor = destructor;
		return true;
	}

	public ref<Namespace> defineNamespace(string domain, ref<Node> namespaceNode, ref<CompileString> name, ref<CompileContext> compileContext) {
		ref<Symbol> sym = lookup(name, compileContext);
		if (sym != null) {
			if (sym.class == Namespace)
				return ref<Namespace>(sym);
			else
				return null;
		}
		ref<Namespace> nm = compileContext.pool().newNamespace(domain, namespaceNode, this, compileContext.annotations, name, compileContext.arena()); 
		SymbolKey key(name);
		_symbols.insert(key, nm);
		return nm;
	}

	ref<Symbol> definePlaceholderDelegate(ref<CompileString> name, ref<Type> type, ref<MemoryPool> memoryPool) {
		SymbolKey key(name);
		if (_symbols.contains(key))
			return null;
		ref<Symbol> sym = memoryPool.newPlainSymbol(Operator.PRIVATE, StorageClass.STATIC, this, null, name, null, type, null);
//		printf("definePlaceholderDelegate(%s [%p,%d], ...) -> %p %p\n", name.asString(), name.data, name.length, sym, memoryPool);
		_symbols.insert(key, sym);
		return sym;
	}

	ref<Symbol> defineDelegate(ref<Symbol> delegate, ref<MemoryPool> memoryPool) {
		SymbolKey key(delegate.name());
		if (delegate.class == PlainSymbol) {
			if (_symbols.contains(key))
				return null;
			ref<Symbol> sym = memoryPool.newDelegateSymbol(this, ref<PlainSymbol>(delegate));
			_symbols.insert(key, sym);
			return sym;
		} else if (delegate.class == Overload) {
			ref<Overload> o = ref<Overload>(delegate);
			ref<Overload> newOverload = memoryPool.newOverload(this, o.name(), o.kind());
			newOverload.cloneDelegates(o, memoryPool);
			_symbols.insert(key, newOverload);
			return newOverload;
		} else {
			delegate.print(0, false);
			assert(false);
			return null;
		}
	}
	
	public void checkDefaultConstructorCalls(ref<CompileContext> compileContext) {
		if (_definition == null)
			return;
		if (_storageClass != StorageClass.MEMBER) {
			switch (_definition.op()) {
			case	LOCK:
			case	BLOCK:
			case	UNIT:
				break;
				
			default:
				return;
			}
		}
		for (ref<Symbol>[Scope.SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.class != PlainSymbol)
				continue;
			sym.assignType(compileContext);
			ref<ParameterScope> destructor = sym.type().destructor();
			if (destructor != null) {
				if (destructor != null && destructor.definition() != null) {
					ref<FunctionDeclaration> f = ref<FunctionDeclaration>(destructor.definition());
					ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
					oi.assignType(compileContext);
					oi.markAsReferenced(compileContext);
				}
			}
			if (sym.initializedWithConstructor())
				continue;
			ref<ParameterScope> defaultConstructor = sym.type().defaultConstructor();
			if (defaultConstructor == null) {
				if (sym.type().hasConstructors())
					sym.add(MessageId.NO_DEFAULT_CONSTRUCTOR, compileContext.pool());
				continue;
			}
			if (defaultConstructor != null && defaultConstructor.definition() != null) {
				ref<FunctionDeclaration> f = ref<FunctionDeclaration>(defaultConstructor.definition());
				ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
				oi.assignType(compileContext);
				oi.markAsReferenced(compileContext);
			}
		}
	}
	
	public void checkVariableStorage(ref<CompileContext> compileContext) {
		switch (_storageClass) {
		case	TEMPLATE:
//		case	AUTO:
			return;

		default:
//			printf("checkVariableStorage \n");
//			print(4, false);
			checkStorage(compileContext);
		}
	}
	
	public void assignVariableStorage(ref<Target> target, ref<CompileContext> compileContext) {
		assignStorage(target, 0, 0, compileContext);
		if (target.verbose()) {
			printf("assignVariableStorage %s:\n", string(_storageClass));
			print(4, false);
		}
	}
	
	public void checkForDuplicateMethods(ref<CompileContext> compileContext) {
	}

	public void assignMethodMaps(ref<CompileContext> compileContext) {
	}

	public void configureDefaultConstructors(ref<CompileContext> compileContext) {
		if (_symbols.size() == 0)
			return;
		if (_definition == null)
			return;
		if (_definition.class == Block || _definition.class == For) {
//			ref<Block> b = ref<Block>(_definition);
//			printf("Scope storage class %s operator %s inSwitch %s\n", string(_storageClass), string(b.op()), b.inSwitch() ? "true" : "false");
			boolean needsValidation = false;
			for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
				ref<Symbol> sym = i.get();
				boolean hasConstructorInitializer = sym.configureDefaultConstructors();
				if (hasConstructorInitializer)
					needsValidation = true;
				else if (sym.isFullyAnalyzed() && sym.type().hasConstructors() && !sym.type().hasDefaultConstructor())
					sym.definition().add(MessageId.NO_DEFAULT_CONSTRUCTOR, compileContext.pool());
			}
			if (needsValidation) {
//				printf("  Validating\n");
				_definition.traverse(Node.Traversal.IN_ORDER, checkAccesses, compileContext);
			}
		}
	}
	
	private static TraverseAction checkAccesses(ref<Node> n, address data) {
		switch (n.op()) {
		case IDENTIFIER:
		case DOT:
			ref<Symbol> sym = n.symbol();
			if (sym != null && sym.class == PlainSymbol) {
				ref<CompileContext> compileContext = ref<CompileContext>(data);
				if (compileContext.current() == sym.enclosing()) {
					ref<PlainSymbol> ps = ref<PlainSymbol>(sym);
					if (ps.definition() == n)
						ps.construct();
					else if (!((ps.accessFlags() & Access.CONSTRUCTED) != 0))
						n.add(MessageId.REFERENCE_PREMATURE, compileContext.pool());
				}
			}
			break;
			
		case FUNCTION:
		case CLASS_DECLARATION:
		case ENUM:
		case FLAGS_DECLARATION:
			return TraverseAction.SKIP_CHILDREN;
		}
		return TraverseAction.CONTINUE_TRAVERSAL;
	}
	
	public int parameterCount() {
		if (_storageClass == StorageClass.TEMPLATE)
			return _symbols.size();
		else if (_definition == null)
			return 0;
		else {
			if (_definition.deferAnalysis())
				return int.MIN_VALUE;
			if (_definition.type == null) {
				print(0, false);
				_definition.print(0);
			}
			return _definition.type.parameterCount();
		}
	}

	public int symbolCount() {
		return _symbols.size();
	}
	
	public boolean encloses(ref<Scope> inner) {
		while (inner != null) {
			if (inner == this)
				return true;
			inner = inner._enclosing;
		}
		return false;
	}
	/**
	 * Check whether this scope is a base scope of the derived scope.
	 *
	 * This is the method that determines whether a 'protected' modifier permits a symbol to be visible.
	 * This scope is the scope of the protected symbol. Derived is the scope containing the reference. It can
	 * therefore be any old kind of scope. If it is not a derived class scope of this, then this method returns
	 * false and the symbol reference is a compile-tmie error.
	 *
	 * @param derived Any scope.
	 *
	 * @param compileContext The context of the current compile. 
	 *
	 * @return true if this scope is the class scope of a base class of the class whose scope is in derived.
	 * If derived is not a class scope, the method returns false.
	 */
	public boolean isBaseScope(ref<Scope> derived, ref<CompileContext> compileContext) {
		return false;
	}

	public boolean inSwitch() {
		if (_definition == null)
			return false;
		if (_definition.op() != Operator.BLOCK)
			return false;
		ref<Block> block = ref<Block>(_definition);
		if (block.scope == null)
			return false;
		return block.inSwitch();
	}
	
	public boolean isMonitor() {
		return false;
	}

	public boolean isInterface() {
		return false;
	}
	
	public ref<FunctionDeclaration> enclosingFunction() {
		for (ref<Scope>  s = this; s != null; s = s._enclosing) {
			if (s._definition != null &&
				s._definition.op() == Operator.FUNCTION)
				return ref<FunctionDeclaration>(s._definition);
		}
		return null;
	}

	public boolean isStaticFunction() {
		// The _definition will be null for an implicit default constructor.
		if (_definition == null)
			return false;
		if (_definition.op() != Operator.FUNCTION)
			return false;
		ref<FunctionDeclaration> f = ref<FunctionDeclaration>(_definition);
		if (f.name() == null)
			return false;
		if (f.name().symbol() == null)
			return false;
		return f.name().symbol().storageClass() == StorageClass.STATIC;
	}

	public boolean isConcrete(ref<CompileContext> compileContext) {
		return true;
	}

	public ref<OverloadInstance> firstAbstractMethod(ref<CompileContext> compileContext) {
		return null;
	}

	public boolean hasVtable(ref<CompileContext> compileContext) {
		return false;
	}
	/*
	 * A base method that will be overridden by the classes that care about it.
	 */
	public int functionAddress() {
		assert(false);
		return 0;
	}
	
	public int maximumAlignment() {
		int max = 1;
		for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.storageClass() == StorageClass.STATIC)
				continue;
			if (sym.class == PlainSymbol) {
				ref<Type> type = sym.type();
				if (type == null)
					continue;
				if (type.family() == TypeFamily.TYPEDEF)
					continue;
				if (type.derivesFrom(TypeFamily.NAMESPACE))
					continue;
				int alignment = type.alignment();
				if (alignment > max)
					max = alignment;
			}
		}
		return max;
	}

	public void put(ref<Symbol> sym, ref<MemoryPool> memoryPool) {
		SymbolKey key(sym.name());
		_symbols.insert(key, sym);
	}

	public ref<Symbol> lookup(ref<CompileString> name, ref<CompileContext> compileContext) {
		SymbolKey key(name);
		ref<Symbol> sym = _symbols[key];
		return sym;
	}

	public ref<Symbol> lookup(string name, ref<CompileContext> compileContext) {
		CompileString cs(name);
		return lookup(&cs, compileContext);
	}

	public ref<Symbol> lookup(pointer<byte> name, ref<CompileContext> compileContext) {
		CompileString cs(name);
		return lookup(&cs, compileContext);
	}

	public ref<Type>, ref<Symbol> assignOverload(ref<Node> node, CompileString name, ref<NodeList> arguments, Operator kind, ref<CompileContext> compileContext) {
		OverloadOperation operation(kind, node, &name, arguments, compileContext);
		ref<Type> result;
		ref<Symbol> symbol;

		for (ref<Scope> s = compileContext.current(); s != null; s = s.enclosing()) {
			ref<Scope> available = s;
			do {
				ref<Type> type = operation.includeScope(s, available);
				if (type != null)
					return type, null;
				if (operation.done()) {
					(result, symbol) = operation.result();
					return result, symbol;
				}
				available = available.base(compileContext);
			} while (available != null);
		}
		(result, symbol) = operation.result();
		return result, symbol;
	}
	/**
	 * Retrieve the scope of the base class for this (class-like) scope.
	 *
	 * @param compileContext The compile context for the compile that is happening. It is needed to
	 * resolve any un-resolved symbol references in any 'extends' clause.
	 *
	 * @return If not null, the scope of the base class for this scope. If this scope has no meaningful
	 * base (such as for a function parameter scope), or if the declaration of the base was somehow in
	 * error, the method return null.
	 */
	public ref<Scope> base(ref<CompileContext> compileContext) {
		return null;
	}

	public  ref<Type> assignSuper(ref<CompileContext> compileContext) {
		return null;
	}

	public ref<Type> getSuper() {
		if (_enclosing != null)
			return _enclosing.getSuper();
		else
			return null;
	}

	public boolean hasThis() {
		return false;
	}

	public boolean isTemplateFunction() {
		if (_storageClass != StorageClass.PARAMETER)
			return false;
		ref<Type> type = enclosingClassType();
		if (type == null)
			return false;
		return type.class == TemplateInstanceType;
	}
	
	public ref<Type> enclosingClassType() {
		ref<ClasslikeScope> scope = enclosingClassScope();
		if (scope == null)
			return null;
		return scope.classType;
	}
	
	public ref<ClasslikeScope> enclosingClassScope() {
		ref<Scope> scope = this;
		while (scope != null && scope.storageClass() != StorageClass.MEMBER)
			scope = scope.enclosing();
		return ref<ClasslikeScope>(scope);
	}
	
	public boolean contextAllowsReferenceToThis() {
		ref<ClasslikeScope> classScope = enclosingClassScope();
		if (classScope == null)
			return false;

		// We are in a class. Verify that we are in a non-static function.

		ref<Scope> scope = this;
		for (;;) {
			// We are somehow nested directly under the classScope
			if (scope == classScope)
				return false;

			if (scope.class == ParameterScope)
				return !scope.isStaticFunction();
			scope = scope.enclosing();
		}
	}

	public ref<UnitScope> enclosingUnit() {
		if (_enclosing != null)
			return _enclosing.enclosingUnit();
		else
			return null;
	}

	public ref<Namespace> getNamespace() {
		if (_enclosing != null)
			return _enclosing.getNamespace();
		else
			return null;
	}

	public ref<FileStat> file() {
		if (_enclosing != null)
			return _enclosing.file();
		else
			return null;
	}

	public ref<ref<Symbol>[SymbolKey]> symbols() {
		return &_symbols;
	}

	public ref<Scope> enclosing() {
		return _enclosing;
	}

	public ref<ref<ParameterScope>[]> constructors() {
		return &_constructors;
	}

	public ref<ParameterScope> destructor() {
		return _destructor;
	}
	
	public ref<ParameterScope> defaultConstructor() {
		for (int i = 0; i < _constructors.length(); i++)
			if (_constructors[i].parameterCount() == 0) {
				if (_constructors[i].definition() != null &&
					_constructors[i].definition().type == null) {
					_constructors[i].definition().print(0);
					assert(false);
				}
				return _constructors[i];
			}
		return null;
	}
	
	public StorageClass storageClass() {
		return _storageClass;
	}

	public ref<Node> definition() {
		return _definition;
	}

	public ref<Identifier> className() {
		return _className;
	}

	public boolean printed() {
		return _printed;
	}
	
	protected void checkStorage(ref<CompileContext> compileContext) {
		if (!_checked) {
			_checked = true;
			for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
				ref<Symbol> sym = i.get();
				checkStorageOfObject(sym, compileContext);
			}
		}
	}

	private void checkStorageOfObject(ref<Symbol> symbol, ref<CompileContext> compileContext) {
		if (symbol.class == PlainSymbol) {
			ref<Type> type = symbol.assignType(compileContext);
			if (type == null)
				return;
			if (!type.requiresAutoStorage())
				return;
			type.checkSize(compileContext);
			switch (symbol.storageClass()) {
			case	STATIC:
			case	AUTO:
			case	MEMBER:
				if (!type.isConcrete(compileContext)) {
					ref<OverloadInstance> oi = type.firstAbstractMethod(compileContext);
					symbol.definition().add(MessageId.ABSTRACT_INSTANCE_DISALLOWED, compileContext.pool(), *oi.name());
//					assert(false);
				}
				break;

			case	PARAMETER:
			case	TEMPLATE_INSTANCE:
				break;

			case	ENUMERATION:
				ref<EnumInstanceType> eit = ref<EnumInstanceType>(type);
				ref<Symbol> typeDefinition = eit.typeSymbol();
				typeDefinition.enclosing().checkStorageOfObject(typeDefinition, compileContext);
				break;

			case	FLAGS:
				ref<FlagsInstanceType> fit = ref<FlagsInstanceType>(type);
				typeDefinition = fit.symbol();
				typeDefinition.enclosing().checkStorageOfObject(typeDefinition, compileContext);
				break;

			default:
				printf("Unexpected storageClass: %s\n", string(symbol.storageClass()));
				symbol.print(0, false);
				assert(false);
				symbol.add(MessageId.UNFINISHED_CHECK_STORAGE, compileContext.pool(), CompileString(string(symbol.storageClass())));
			}
		}
	}

	public int interfaceOffset(ref<CompileContext> compileContext) {
		return 0;
	}
	
	public int firstMemberOffset(ref<CompileContext> compileContext) {
		return 0;
	}
	
	protected void assignStorage(ref<Target> target, int offset, int interfaceArea, ref<CompileContext> compileContext) {
		if (variableStorage == -1) {
			int interfaceOffset = 0;
			ref<Type> base = assignSuper(compileContext);
			if (base != null) {
				base.assignSize(target, compileContext);
				interfaceOffset = base.size();
			} else
				interfaceOffset = offset;
			variableStorage = interfaceOffset + interfaceArea;
//			printf("Before assignStorage:\n");
//			print(0, false);
			visitAll(target, offset, compileContext);
//			printf("After assignStorage:\n");
//			print(0, false);
			int alignment = maximumAlignment();
			variableStorage = (variableStorage + alignment - 1) & ~(alignment - 1);
		}
	}

	protected void visitAll(ref<Target> target, int offset, ref<CompileContext> compileContext) {
		for (ref<Symbol>[SymbolKey].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			target.assignStorageToObject(sym, this, offset, compileContext);
		}
	}

	public int autoStorage(ref<Target> target, int offset, ref<CompileContext> compileContext) {
		if (_storageClass == StorageClass.AUTO) {
			assignStorage(target, offset, 0, compileContext);
			offset = variableStorage;
		}
		int maxStorage = offset;
		for (int i = 0; i < _enclosed.length(); i++) {
			if (_enclosed[i].storageClass() == StorageClass.AUTO ||
				_enclosed[i].storageClass() == StorageClass.LOCK)  {
				int thisStorage = _enclosed[i].autoStorage(target, offset, compileContext);
				if (thisStorage > maxStorage)
					maxStorage = thisStorage;
			}
		}
		return maxStorage;
	}
}
