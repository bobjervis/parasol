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
import parasol:memory;
import parasol:runtime;
import parasol:storage;
import parasol:process;

public class Arena {
	private ref<Scope> _main;

	private ref<Unit>[] _units;
	private ref<Unit>[string] _unitNames;

	private ref<context.Context> _activeContext;

	private ref<Scope>[] _scopes;
	private ref<TemplateInstanceType>[]	_types;


	int builtScopes;
	boolean _deleteSourceCache;
	boolean verbose;
	boolean useContexts;
	/**
	 * This is set during configuration to true in order to decorate the parse trees with
	 * references to doclets (and of course to parse those doclets).
	 */
	public boolean paradoc;

	runtime.Target preferredTarget;

	public Arena() {
		init();
	}
	
	public Arena(ref<context.Context> activeContext) {
		_activeContext = activeContext;
		init();
	}

	private void init() {
		if (_activeContext == null)
			_activeContext = context.getActiveContext();
	}
	
	~Arena() {
		_units.deleteAll();
//		for (i in _scopes)
//			printf("delete scope %p\n", _scopes[i]);
		_scopes.deleteAll();
	}

	public ref<Scope> createScope(ref<Scope> enclosing, ref<Node> definition, StorageClass storageClass) {
		ref<Scope> s = new Scope(enclosing, definition, storageClass, null);
		_scopes.append(s);
		return s;
	}

	public ref<UnitScope> createUnitScope(ref<Scope> rootScope, ref<Node> definition, ref<Unit> file) {
		ref<UnitScope>  s = new UnitScope(rootScope, file, definition);
		_scopes.append(s);
		return s;
	}

	public ref<NamespaceScope> createNamespaceScope(ref<Scope> enclosing, ref<Namespace> namespaceSymbol) {
		ref<NamespaceScope> s = new NamespaceScope(enclosing, namespaceSymbol);
		_scopes.append(s);
		return s;
	}

	public ref<Scope> createRootScope(ref<Node> definition, ref<Unit> file) {
		ref<Scope>  s = new RootScope(file, definition);
		_scopes.append(s);
		return s;
	}

	public ref<ParameterScope> createParameterScope(ref<Scope> enclosing, ref<Node> definition, ParameterScope.Kind kind) {
		ref<ParameterScope> s = new ParameterScope(enclosing, definition, kind);
		_scopes.append(s);
		return s;
	}

	public ref<ProxyMethodScope> createProxyMethodScope(ref<Scope> enclosing) {
		ref<ProxyMethodScope> s = new ProxyMethodScope(enclosing);
		_scopes.append(s);
		return s;
	}

	public ref<ClassScope> createClassScope(ref<Scope> enclosing, ref<Node> definition, ref<Identifier> className) {
		ref<ClassScope> s = new ClassScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<InterfaceImplementationScope> createInterfaceImplementationScope(ref<InterfaceType> definedInterface, ref<ClassType> implementingClass, int itableSlot) {
		ref<InterfaceImplementationScope> s = new InterfaceImplementationScope(definedInterface, implementingClass, itableSlot);
		_scopes.append(s);
		return s;
	}
	
	public ref<InterfaceImplementationScope> createInterfaceImplementationScope(ref<InterfaceType> definedInterface, ref<ClassType> implementingClass, ref<InterfaceImplementationScope> baseInterface, int firstNewMethod) {
		ref<InterfaceImplementationScope> s = new InterfaceImplementationScope(definedInterface, implementingClass, baseInterface, firstNewMethod);
		_scopes.append(s);
		return s;
	}
	
	public ref<ThunkScope> createThunkScope(ref<InterfaceImplementationScope> enclosing, ref<ParameterScope> func, boolean isDestructor) {
		ref<ThunkScope> s = new ThunkScope(enclosing, func, isDestructor);
		_scopes.append(s);
		return s;
	}

	public ref<EnumScope> createEnumScope(ref<Scope> enclosing, ref<Block> definition, ref<Identifier> className) {
		ref<EnumScope> s = new EnumScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<FlagsScope> createFlagsScope(ref<Scope> enclosing, ref<Block> definition, ref<Identifier> className) {
		ref<FlagsScope> s = new FlagsScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<LockScope> createLockScope(ref<Scope> enclosing, ref<Lock> definition) {
		ref<LockScope> s = new LockScope(enclosing, definition);
		_scopes.append(s);
		return s;
	}

	public ref<MonitorScope> createMonitorScope(ref<Scope> enclosing, 
							ref<Node> definition, ref<Identifier> className) {
		ref<MonitorScope> s = new MonitorScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public void declare(ref<TemplateInstanceType> t) {
		_types.append(t);
	}

	public int countMessages() {
		int count = 0;
		for (i in _units)
			count += _units[i].countMessages();
		for (int i = 0; i < _types.length(); i++)
			count += _types[i].concreteDefinition().countMessages();
		return count;
	}

	public void printMessages() {
		for (i in _units)
			_units[i].printMessages(_types);
	}

	public void allNodes(void(ref<Unit>, ref<Node>, ref<Commentary>, address) callback, address arg) {
		for (i in _units)
			_units[i].allNodes(_types, callback, arg);
	}

	public void printSymbolTable() {
		for (i in _units)
			_units[i].printSymbolTable();
		printf("\nMain scope:\n");
		if (_main != null)
			_main.print(INDENT, true);
//		printf("\nRoot scope:\n");
//		_root.print(INDENT, true);
		_activeContext.printSymbolTable();
	}
	
	public void print() {
		printSymbolTable();
		for (i in _units)
			_units[i].print();
		_activeContext.print();
	}
	
//	public ref<Scope> root() { 
//		return _root; 
//	}

	public ref<ref<Scope>[]> scopes() { 
		return &_scopes;
	}

	public ref<ref<TemplateInstanceType>[]> types() { 
		return &_types; 
	}

	public ref<context.Context> activeContext() {
		return _activeContext;
	}
	/**
	 * @ignore
	 */
	public ref<Unit> defineUnit(string name, string packageDir) {
		ref<Unit> u = _unitNames[name];
		if (u != null)
			return u;
		u = new Unit(name, packageDir);
		_units.append(u);
		_unitNames[name] = u;
		return u;
	}

	public ref<Unit> defineImportedUnit(string name, string packageDir) {
		ref<Unit> u = _unitNames[name];
		if (u != null)
			return u;
		u = new Unit(name, packageDir, true);
		_units.append(u);
		_unitNames[name] = u;
		return u;
	}
	/**
	 * @ignore
	 */
	public boolean defineUnit(ref<Unit> unit) {
		string name = unit.filename();
		if (name != null) {
			ref<Unit> u = _unitNames[name];
			if (u != null)
				return false;
			_unitNames[name] = unit;
		}
		_units.append(unit);
		return true;
	}
	/**
	 * @ignore
	 */
	public ref<Unit> getUnit(int i) {
		if (i >= 0 &&
			i < _units.length())
			return _units[i];
		else
			return null;
	}

	public ref<Unit>[] units() {
		return _units;
	}
}

