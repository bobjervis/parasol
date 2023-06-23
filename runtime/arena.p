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
namespace parasol:runtime;

import parasol:compiler;
import parasol:context;
import parasol:memory;
import parasol:storage;
import parasol:process;

public class Arena {
	private ref<compiler.Scope> _main;

	private ref<compiler.Unit>[] _units;
	private ref<compiler.Unit>[string] _unitNames;

	private ref<context.Context> _activeContext;

	private ref<compiler.Scope>[] _scopes;
	private ref<compiler.TemplateInstanceType>[]	_types;


	int builtScopes;
	boolean _deleteSourceCache;
	boolean verbose;
	boolean useContexts;
	/**
	 * This is set during configuration to true in order to decorate the parse trees with
	 * references to doclets (and of course to parse those doclets).
	 */
	public boolean paradoc;

	Target preferredTarget;

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

	public ref<compiler.Scope> createScope(ref<compiler.Scope> enclosing, ref<compiler.Node> definition, compiler.StorageClass storageClass) {
		ref<compiler.Scope> s = new compiler.Scope(enclosing, definition, storageClass, null);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.UnitScope> createUnitScope(ref<compiler.Scope> rootScope, ref<compiler.Node> definition, ref<compiler.Unit> file) {
		ref<compiler.UnitScope>  s = new compiler.UnitScope(rootScope, file, definition);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.NamespaceScope> createNamespaceScope(ref<compiler.Scope> enclosing, ref<compiler.Namespace> namespaceSymbol) {
		ref<compiler.NamespaceScope> s = new compiler.NamespaceScope(enclosing, namespaceSymbol);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.Scope> createRootScope(ref<compiler.Node> definition, ref<compiler.Unit> file) {
		ref<compiler.Scope>  s = new compiler.RootScope(file, definition);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.ParameterScope> createParameterScope(ref<compiler.Scope> enclosing, ref<compiler.Node> definition, compiler.ParameterScope.Kind kind) {
		ref<compiler.ParameterScope> s = new compiler.ParameterScope(enclosing, definition, kind);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.ProxyMethodScope> createProxyMethodScope(ref<compiler.Scope> enclosing) {
		ref<compiler.ProxyMethodScope> s = new compiler.ProxyMethodScope(enclosing);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.ClassScope> createClassScope(ref<compiler.Scope> enclosing, ref<compiler.Node> definition, ref<compiler.Identifier> className) {
		ref<compiler.ClassScope> s = new compiler.ClassScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.InterfaceImplementationScope> createInterfaceImplementationScope(ref<compiler.InterfaceType> definedInterface, ref<compiler.ClassType> implementingClass, int itableSlot) {
		ref<compiler.InterfaceImplementationScope> s = new compiler.InterfaceImplementationScope(definedInterface, implementingClass, itableSlot);
		_scopes.append(s);
		return s;
	}
	
	public ref<compiler.InterfaceImplementationScope> createInterfaceImplementationScope(ref<compiler.InterfaceType> definedInterface, ref<compiler.ClassType> implementingClass, ref<compiler.InterfaceImplementationScope> baseInterface, int firstNewMethod) {
		ref<compiler.InterfaceImplementationScope> s = new compiler.InterfaceImplementationScope(definedInterface, implementingClass, baseInterface, firstNewMethod);
		_scopes.append(s);
		return s;
	}
	
	public ref<compiler.ThunkScope> createThunkScope(ref<compiler.InterfaceImplementationScope> enclosing, ref<compiler.ParameterScope> func, boolean isDestructor) {
		ref<compiler.ThunkScope> s = new compiler.ThunkScope(enclosing, func, isDestructor);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.EnumScope> createEnumScope(ref<compiler.Scope> enclosing, ref<compiler.Block> definition, ref<compiler.Identifier> className) {
		ref<compiler.EnumScope> s = new compiler.EnumScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.FlagsScope> createFlagsScope(ref<compiler.Scope> enclosing, ref<compiler.Block> definition, ref<compiler.Identifier> className) {
		ref<compiler.FlagsScope> s = new compiler.FlagsScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.LockScope> createLockScope(ref<compiler.Scope> enclosing, ref<compiler.Lock> definition) {
		ref<compiler.LockScope> s = new compiler.LockScope(enclosing, definition);
		_scopes.append(s);
		return s;
	}

	public ref<compiler.MonitorScope> createMonitorScope(ref<compiler.Scope> enclosing, 
							ref<compiler.Node> definition, ref<compiler.Identifier> className) {
		ref<compiler.MonitorScope> s = new compiler.MonitorScope(enclosing, definition, className);
		_scopes.append(s);
		return s;
	}

	public void declare(ref<compiler.TemplateInstanceType> t) {
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

	public void allNodes(void(ref<compiler.Unit>, ref<compiler.Node>, ref<compiler.Commentary>, address) callback, address arg) {
		for (i in _units)
			_units[i].allNodes(_types, callback, arg);
	}

	public void printSymbolTable() {
		for (i in _units)
			_units[i].printSymbolTable();
		printf("\nMain scope:\n");
		if (_main != null)
			_main.print(compiler.INDENT, true);
//		printf("\nRoot scope:\n");
//		_root.print(compiler.INDENT, true);
		_activeContext.printSymbolTable();
	}
	
	public void print() {
		printSymbolTable();
		for (i in _units)
			_units[i].print();
		_activeContext.print();
	}
	
//	public ref<compiler.Scope> root() { 
//		return _root; 
//	}

	public ref<ref<compiler.Scope>[]> scopes() { 
		return &_scopes;
	}

	public ref<ref<compiler.TemplateInstanceType>[]> types() { 
		return &_types; 
	}

	public ref<context.Context> activeContext() {
		return _activeContext;
	}
	/**
	 * @ignore
	 */
	public ref<compiler.Unit> defineUnit(string name, string packageDir) {
		ref<compiler.Unit> u = _unitNames[name];
		if (u != null)
			return u;
		u = new compiler.Unit(name, packageDir);
		_units.append(u);
		_unitNames[name] = u;
		return u;
	}

	public ref<compiler.Unit> defineImportedUnit(string name, string packageDir) {
		ref<compiler.Unit> u = _unitNames[name];
		if (u != null)
			return u;
		u = new compiler.Unit(name, packageDir, true);
		_units.append(u);
		_unitNames[name] = u;
		return u;
	}
	/**
	 * @ignore
	 */
	public boolean defineUnit(ref<compiler.Unit> unit) {
		string name = unit.filename();
		if (name != null) {
			ref<compiler.Unit> u = _unitNames[name];
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
	public ref<compiler.Unit> getUnit(int i) {
		if (i >= 0 &&
			i < _units.length())
			return _units[i];
		else
			return null;
	}

	public ref<compiler.Unit>[] units() {
		return _units;
	}
}

