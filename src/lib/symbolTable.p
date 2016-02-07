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

import parasol:file.File;

enum StorageClass {
	ERROR,
	AUTO,
	PARAMETER,
	MEMBER,
	STATIC,
	CONSTANT,
	TEMPLATE,
	TEMPLATE_INSTANCE,
	ENUMERATION,
	ENCLOSING,
	MAX_STORAGE_CLASS
}

enum Callable {
	DEFER,
	NO,
	YES
}

int NOT_PARAMETERIZED_TYPE = -1000000;

class ClassScope extends ClasslikeScope {
	public ClassScope(ref<Scope> enclosing, ref<Node> definition, ref<Identifier> className) {
		super(enclosing, definition, className);
	}

	ClassScope(ref<Scope> enclosing, ref<Node> definition, StorageClass storageClass, ref<Identifier> className) {
		super(enclosing, definition, storageClass, className);
	}

	protected void visitAll(ref<Target> target, int offset, ref<CompileContext> compileContext) {
		for (int i = 0; i < _members.length(); i++) {
			ref<Symbol> sym = _members[i];
			target.assignStorageToObject(sym, this, offset, compileContext);
		}
	}
}

class ClasslikeScope extends Scope {
	private static int FIRST_USER_METHOD = 1;

	public ref<ClassType> classType;
	private ref<OverloadInstance>[] _methods;
	protected ref<Symbol>[] _members;
	private boolean _methodsBuilt;
	
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
		if (constructors().length() == 0) {
			// We know this is called after the class itself is largely resolved.
			// In particular, we know that any value for the base class is already correctly set.
			ref<Type> baseType = getSuper();
			if (baseType == null)
				return;
			ref<Scope> baseClass = baseType.scope();
			if (baseClass == null)
				return;
			if (baseClass.constructors().length() == 0)
				return;
			ref<ParameterScope> functionScope = compileContext.arena().createParameterScope(this, null, ParameterScope.Kind.DEFAULT_CONSTRUCTOR);
			defineConstructor(functionScope, compileContext.pool());
			if (compileContext.arena().verbose) {
				printf("current %p tree = %p base constructors %d constructors %d\n", compileContext.current(), compileContext.tree(), baseClass.constructors().length(), constructors().length());
				print(4, false);
				printf("=== End default constructor check ===\n");
			}
//			assert(false);
		}
	}
	
	public void createPossibleImpliedDestructor(ref<CompileContext> compileContext) {
		if (needsImpliedDestructor(compileContext)) {
			ref<ParameterScope> functionScope = compileContext.arena().createParameterScope(this, null, ParameterScope.Kind.IMPLIED_DESTRUCTOR);
			defineDestructor(functionScope, compileContext.pool());
		}
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
			for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
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
			assignStorage(target, baseOffset, compileContext);
		} else
			super.assignVariableStorage(target, compileContext);
	}

	public void checkForDuplicateMethods(ref<CompileContext> compileContext) {
		for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
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
			for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
				ref<Symbol> sym = i.get();
				if (sym.class == Overload) {
					ref<Overload> o = ref<Overload>(sym);
					for (int i = 0; i < o.instances().length(); i++) {
						ref<OverloadInstance> oi = (*o.instances())[i];
						for (int i = 0; i < oi.parameterScope().parameters().length(); i++) {
							ref<Symbol> par = (*oi.parameterScope().parameters())[i];
							par.assignType(compileContext);
						}
						int index = matchingMethod(oi);
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

	private int matchingMethod(ref<OverloadInstance> candidate) {
		for (int i = 0; i < _methods.length(); i++) {
			if (candidate.overrides(_methods[i]))
				return i;
		}
		return -1;
	}
	
	public ref<ref<Symbol>[]> members() {
		return &_members;
	}
}

class EnumScope extends ClasslikeScope {
	public ref<EnumType> enumType;
	
	private ref<Symbol>[] _instances;
	
	public EnumScope(ref<Scope> enclosing, ref<Block> definition, ref<Identifier> enumName) {
		super(enclosing, definition, StorageClass.ENUMERATION, enumName);
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
class ParameterScope extends Scope {
	public enum Kind {
		FUNCTION,				// any ordinary constructor, destructor, method or function
		TEMPLATE,				// any template
		DEFAULT_CONSTRUCTOR,	// a default constructor (no source code) generated when needed
		IMPLIED_DESTRUCTOR,		// an implied destructor (no source code) generated when needed
		ENUM_TO_STRING,			// a generated enum-to-string coercion method
	}
	private Kind _kind;
	private ref<Symbol>[] _parameters;
	private boolean _hasEllipsis;
		
	public address value;				// scratch area for use by code generators
	
	public ParameterScope(ref<Scope> enclosing, ref<Node> definition, Kind kind) {
		super(enclosing, definition, 
				kind == Kind.TEMPLATE ? StorageClass.TEMPLATE : StorageClass.PARAMETER, null);
		_kind = kind;
	}

	ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> definition, ref<Node> declaration, ref<Node> initializer, ref<MemoryPool> memoryPool) {
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

	public Kind kind() {
		return _kind;
	}
	
	public boolean hasEllipsis() {
		return _hasEllipsis;
	}
	
	public boolean hasThis() {
		ref<Function> func = ref<Function>(definition());
		
		if (func == null)		// a generated default constructor has no 'definition'
			return true;		// but it does have 'this'
		if (func.name() != null && func.name().symbol() != null)
			return func.name().symbol().storageClass() == StorageClass.MEMBER;
		else
			return false;
	}
	
	public ref<FunctionType> type() {
		ref<Function> func = ref<Function>(definition());
		if (func == null)		// a generate default constructor has no 'definition'
			return null;		// and no type.
		return ref<FunctionType>(func.type);
		
	}
	
	public ref<OverloadInstance> symbol() {
		ref<Function> func = ref<Function>(definition());
		if (func == null)		// a generate default constructor has no 'definition'
			return null;		// and no type.
		if (func.deferAnalysis())
			return null;
		return ref<OverloadInstance>(func.name().symbol());
	}
	
	public boolean hasOutParameter(ref<CompileContext> compileContext) {
		ref<Function> func = ref<Function>(definition());
		if (func == null)		// a generate default constructor has no 'definition'
			return false;		// and no out parameter.
		if (func.deferAnalysis())
			return false;
		ref<Type> fType;
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
		if (_kind == Kind.IMPLIED_DESTRUCTOR) {
			// There is no definition, but
			return enclosing().hasVtable(compileContext);
		}
		ref<Function> func = ref<Function>(definition());
		if (func == null)		// a generated default constructor has no 'definition'
			return false;		// and no VTable, .
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

	public void mergeIntoNamespace(ref<Namespace> nm, ref<CompileContext> compileContext) {
		ref<Scope> namespaceScope = nm.symbols();
		for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.class == PlainSymbol) {
				ref<Symbol> n = namespaceScope.lookup(sym.name());
				if (n != null) {
					if (n.definition().countMessages() == 0)
						n.definition().add(MessageId.DUPLICATE, compileContext.pool(), *n.name());
					sym.definition().add(MessageId.DUPLICATE, compileContext.pool(), *sym.name());
				} else
					namespaceScope.put(sym);
			} else if (sym.class == Overload) {
				ref<Overload> o = ref<Overload>(sym);

				ref<Symbol> n = namespaceScope.lookup(sym.name());
				if (n == null) {
					ref<Overload> no = namespaceScope.defineOverload(sym.name(), o.kind(), compileContext.pool());
					no.merge(o);
				} else if (n.class == Overload) {
					ref<Overload> no = ref<Overload>(n);
					no.merge(o);
				} else {
					if (n.definition().countMessages() == 0)
						n.definition().add(MessageId.DUPLICATE, compileContext.pool(), *n.name());
					o.markAsDuplicates(compileContext.pool());
				}
			}
		}
	}

	public ref<Scope> base(ref<CompileContext> compileContext) {
		return _file.namespaceSymbol().symbols();
	}

	public ref<Namespace> getNamespace() {
		return _file.namespaceSymbol();
	}

	public ref<FileStat> file() {
		return _file;
	}
}

class Scope {

	// Class-specific information

	private ref<Scope> _enclosing;
	private ref<Scope>[] _enclosed;
	private ref<ParameterScope>[] _constructors;
	private ref<ParameterScope> _destructor;

	protected ref<Symbol>[string] _symbols;


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
		
	public void createPossibleImpliedDestructor(ref<CompileContext> compileContext) {
	}
		
	boolean writeHeader(File header) {
		for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
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
					ref<Scope> s = t.scope();
					for (ref<Symbol>[string].iterator i = s.symbols().begin(); i.hasNext(); i.next()) {
						ref<Symbol> c = i.get();
						header.printf("\t%s%s,\n", prefix, c.name().asString());
					}
					header.printf("};\n");
				}
			}
//			header.write();
		}
		return true;
	}
	
	void print(int indent, boolean printChildren) {
		printf("%*.*cScope %p[%d] %s", indent, indent, ' ', this, variableStorage, string(_storageClass));
		printf(" %p", _definition);
		if (_definition != null) {
			switch (_definition.op()) {
			case	FUNCTION:
				if (_definition.class != Function) {
					printf(" not Function");
					break;
				}
				ref<Function> f = ref<Function>(_definition);
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
			}
		}
		printf(":\n");
		for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
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


	string label() {
		if (_definition != null) {
			switch (_definition.op()) {
			case	FUNCTION:{
				ref<Function> f = ref<Function>(_definition);
				if (f.name() != null) {
					string enc = _enclosing.label();
					return enc + "." + f.name().value().asString();
				}
			}break;
			case	CLASS:{
				ref<Class> c = ref<Class>(_definition);
				if (c.name() != null)
					return "class " + c.name().value().asString();
			}break;
			case	TEMPLATE:{
				ref<Template> t = ref<Template>(_definition);
				if (t.name() != null)
					return "template " + t.name().value().asString();
			}break;
			}
		}
		return "<anonymous>";
	}

	boolean defineImport(ref<Identifier> id, ref<Symbol> definition) {
		string name = id.identifier().asString();
		if (_symbols.contains(name))
			return false;
		_symbols[name] = definition;
		return true;
	}

	ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> source, ref<Node> declaration, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		string name = source.identifier().asString();
		if (_symbols.contains(name))
			return null;
	//	printf("Define %s\n", source.identifier().asString());
		ref<Symbol> sym  = memoryPool.newPlainSymbol(visibility, storageClass, this, annotations, source.identifier(), source, declaration, initializer);
		_symbols[name] = sym;
		return sym;
	}

	ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, ref<Node> source, ref<Type> type, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		ref<Symbol> sym  = memoryPool.newPlainSymbol(visibility, storageClass, this, annotations, source.identifier(), source, type, initializer);
		string name = source.identifier().asString();
		if (_symbols.contains(name))
			return null;
		_symbols[name] = sym;
		return sym;
	}

	ref<Symbol> define(Operator visibility, StorageClass storageClass, ref<Node> annotations, string name, ref<Type> type, ref<Node> initializer, ref<MemoryPool> memoryPool) {
		CompileString cs = memoryPool.newCompileString(name);
		ref<CompileString> pcs = memoryPool new CompileString(cs.data, cs.length);
		ref<Symbol> sym  = memoryPool.newPlainSymbol(visibility, storageClass, this, annotations, pcs, null, type, initializer);
		if (_symbols.contains(name))
			return null;
		_symbols[name] = sym;
		return sym;
	}

	public ref<Overload> defineOverload(ref<CompileString> name, Operator kind, ref<MemoryPool> memoryPool) {
		ref<Symbol> sym = lookup(name);
		ref<Overload> o;
		if (sym != null) {
			if (sym.class != Overload)
				return null;
			o = ref<Overload>(sym);
			if (o.kind() != kind)
				return null;
		} else {
			string n = name.asString();
			o = memoryPool.newOverload(this, name, kind);
			_symbols[n] = o;
		}
		return o;
	}

	public void defineConstructor(ref<ParameterScope> constructor, ref<MemoryPool> memoryPool) {
		_constructors.append(constructor);
	}

	public boolean defineDestructor(ref<ParameterScope> destructor, ref<MemoryPool> memoryPool) {
		if (_destructor != null) {
			ref<Function> func = ref<Function>(_destructor.definition());
			if (func.name().commentary() == null)
				func.name().add(MessageId.DUPLICATE_DESTRUCTOR, memoryPool);
			return false;
		}
		_destructor = destructor;
		return true;
	}

	public ref<Namespace> defineNamespace(ref<Node> namespaceNode, ref<CompileString> name, ref<CompileContext> compileContext) {
		ref<Symbol> sym = lookup(name);
		if (sym != null) {
			if (sym.class == Namespace)
				return ref<Namespace>(sym);
			else
				return null;
		}
		ref<Scope> scope = compileContext.arena().createScope(null, null, StorageClass.STATIC);
		ref<Namespace> nm = compileContext.pool().newNamespace(namespaceNode, this, scope, compileContext.annotations, name);
		_symbols[name.asString()] = nm;
		return nm;
	}

	public void checkVariableStorage(ref<CompileContext> compileContext) {
		switch (_storageClass) {
		case	TEMPLATE:
		case	AUTO:
			return;

		default:
			checkStorage(compileContext);
		}
	}
	
	public void assignVariableStorage(ref<Target> target, ref<CompileContext> compileContext) {
		assignStorage(target, 0, compileContext);
		if (target.verbose()) {
			printf("assignVariableStorage %s:\n", string(_storageClass));
			print(4, false);
		}
	}
	
	public void checkForDuplicateMethods(ref<CompileContext> compileContext) {
	}

	public void assignMethodMaps(ref<CompileContext> compileContext) {
	}

	public int parameterCount() {
		if (_storageClass == StorageClass.TEMPLATE)
			return _symbols.size();
		else if (_definition == null)
			return 0;
		else {
			if (_definition.deferAnalysis())
				return int.MIN_VALUE;
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

	public ref<Function> enclosingFunction() {
		for (ref<Scope>  s = this; s != null; s = s._enclosing) {
			if (s._definition != null &&
				s._definition.op() == Operator.FUNCTION)
				return ref<Function>(s._definition);
		}
		return null;
	}

	public boolean isStaticFunction() {
		// The _definition will be null for an implicit default constructor.
		if (_definition == null)
			return false;
		if (_definition.op() != Operator.FUNCTION)
			return false;
		ref<Function> f = ref<Function>(_definition);
		if (f.name() == null)
			return false;
		if (f.name().symbol() == null)
			return false;
		return f.name().symbol().storageClass() == StorageClass.STATIC;
	}

	public boolean isConcrete(ref<CompileContext> compileContext) {
		return true;
	}

	public boolean hasVtable(ref<CompileContext> compileContext) {
		return false;
	}

	public int maximumAlignment() {
		int max = 1;
		for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.storageClass() == StorageClass.STATIC ||
				sym.storageClass() == StorageClass.CONSTANT)
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

	public void put(ref<Symbol> sym) {
		_symbols[sym.name().asString()] = sym;
	}

	public ref<Symbol> lookup(ref<CompileString> name) {
		return _symbols[name.asString()];
	}

	public ref<Symbol> lookup(string name) {
		return _symbols[name];
	}

	public ref<Symbol> lookup(pointer<byte> name) {
		string s(name);
		return _symbols[s];
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

	public boolean isInTemplateFunction() {
		if (_storageClass != StorageClass.AUTO)
			return false;
		ref<Type> type = enclosingClassType();
		if (type == null)
			return false;
		return type.class == TemplateInstanceType;
	}
	
	public ref<Type> enclosingClassType() {
		ref<Scope> scope = this;
		while (scope != null && scope.storageClass() != StorageClass.MEMBER)
			scope = scope.enclosing();
		if (scope == null)
			return null;
		ref<ClassScope> classScope = ref<ClassScope>(scope);
		return classScope.classType;
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

	ref<ref<Symbol>[string]> symbols() {
		return &_symbols;
	}

	public ref<Scope> enclosing() {
		return _enclosing;
	}

	ref<ref<ParameterScope>[]> constructors() {
		return &_constructors;
	}

	ref<ParameterScope> destructor() {
		return _destructor;
	}
	
	ref<ParameterScope> defaultConstructor() {
		for (int i = 0; i < _constructors.length(); i++)
			if (_constructors[i].parameterCount() == 0)
				return _constructors[i];
		return null;
	}
	
	StorageClass storageClass() {
		return _storageClass;
	}

	public ref<Node> definition() {
		return _definition;
	}

	public boolean printed() {
		return _printed;
	}
	
	protected void checkStorage(ref<CompileContext> compileContext) {
		if (!_checked) {
			_checked = true;
			for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
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
			case	CONSTANT:
			case	STATIC:
			case	AUTO:
			case	MEMBER:
				if (!type.isConcrete(compileContext))
					symbol.definition().add(MessageId.ABSTRACT_INSTANCE_DISALLOWED, compileContext.pool());
				break;

			case	PARAMETER:
			case	TEMPLATE_INSTANCE:
				break;

			case	ENUMERATION:
				ref<EnumInstanceType> eit = ref<EnumInstanceType>(type);
				ref<Symbol> typeDefinition = eit.symbol();
				typeDefinition.enclosing().checkStorageOfObject(typeDefinition, compileContext);
				break;

			default:
				symbol.print(0, false);
				assert(false);
				symbol.add(MessageId.UNFINISHED_CHECK_STORAGE, compileContext.pool(), CompileString(string(symbol.storageClass())));
			}
		}
	}

	protected void assignStorage(ref<Target> target, int offset, ref<CompileContext> compileContext) {
		if (variableStorage == -1) {
			ref<Type> base = assignSuper(compileContext);
			if (base != null) {
				base.assignSize(target, compileContext);
				variableStorage = base.size();
			} else
				variableStorage = offset;
//			printf("Before assignStorage:\n");
//			print(0, false);
			visitAll(target, offset, compileContext);
//			printf("After assignStorage:\n");
//			print(0, false);
		}
	}

	protected void visitAll(ref<Target> target, int offset, ref<CompileContext> compileContext) {
		for (ref<Symbol>[string].iterator i = _symbols.begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			target.assignStorageToObject(sym, this, offset, compileContext);
		}
	}

	public int autoStorage(ref<Target> target, int offset, ref<CompileContext> compileContext) {
		if (_storageClass == StorageClass.AUTO) {
			assignStorage(target, offset, compileContext);
			offset = variableStorage;
		}
		int maxStorage = offset;
		for (int i = 0; i < _enclosed.length(); i++) {
			if (_enclosed[i].storageClass() == StorageClass.AUTO)  {
				int thisStorage = _enclosed[i].autoStorage(target, offset, compileContext);
				if (thisStorage > maxStorage)
					maxStorage = thisStorage;
			}
		}
		return maxStorage;
	}

	public void assignTypesForAuto(ref<CompileContext> compileContext) {
		for (int i = 0; i < _enclosed.length(); i++)
			if (_enclosed[i].storageClass() == StorageClass.AUTO)
				compileContext.assignTypesForAuto(_enclosed[i]);
		// How about this case for vectorization:
		// if (_enclosed.storageClass() == StorageClass.AUTO)
		//	compileContext.assign(_enclosed);
	}
}

class Namespace extends Symbol {
	private ref<Scope> _symbols;
	private string _dottedName;

	Namespace(ref<Node> namespaceNode, ref<Scope> enclosing, ref<Scope> symbols, ref<Node> annotations, ref<CompileString> name) {
		super(Operator.PUBLIC, StorageClass.ENCLOSING, enclosing, annotations, name, null);
		_symbols = symbols;
		if (namespaceNode != null) {
			boolean x;
			
			(_dottedName, x) = namespaceNode.dottedName();
		}
	}

	public void print(int indent, boolean printChildScopes) {
		printf("%*.*c", indent, indent, ' ');
		if (_name != null)
			printf("%s", _name.asString());
		else
			printf("<null>");
		printf(" Namespace %p %s", this, string(visibility()));
		if (_type != null) {
			printf(" @%d ", offset);
			_type.print();
		}
		printf("\n");
		_symbols.print(indent + INDENT, false);
		printf("\n");
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		ref<Type> base = compileContext.arena().builtInType(TypeFamily.NAMESPACE);
		_type = compileContext.pool().newClassType(TypeFamily.CLASS, base, _symbols);
		return _type;
	}

	ref<Symbol> findImport(ref<Ternary> namespaceNode) {
		ref<Identifier> id = ref<Identifier>(namespaceNode.right());
		if (namespaceNode.middle().op() == Operator.EMPTY) {
			if (name() != null && name().equals(*id.identifier()))
				return this;
			else
				return null;
		} else {
			return _symbols.lookup(id.identifier());
		}
	}

	boolean includes(ref<Ternary> namespaceNode) {
		ref<Node> name = namespaceNode.middle();
		printf("          dotted name = %s\n", _dottedName);
		string newName;
		boolean x;
		if (name.op() == Operator.EMPTY)
			(newName, x) = namespaceNode.right().dottedName();
		else
			(newName, x) = name.dottedName();
		printf("          namespaceNode middle name = %s\n", newName);
		if (!_dottedName.beginsWith(newName))
			return false;
		if (_dottedName.length() == newName.length()) {
			printf("          lengths match\n");
			return true;
		}
		return _dottedName[newName.length()] == '.';
	}

	public ref<Scope> symbols() {
		return _symbols;
	}
}
/*
	PlainSymbol
	
	This class represents a 'plain' symbol, one that is not overloaded (i.e. neither functions nor templates).
	
	There are two relevant components that define a symbol: the type declaration and any initializer supplied
	with the declaration.
 */
class PlainSymbol extends Symbol {
	private ref<Node> _typeDeclarator;
	private ref<Node> _initializer;

	PlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<Node> typeDeclarator, ref<Node> initializer) {
		super(visibility, storageClass, enclosing, annotations, name, source);
		_typeDeclarator = typeDeclarator;
		_initializer = initializer;
	}
	
	PlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<Type> type, ref<Node> initializer) {
		super(visibility, storageClass, enclosing, annotations, name, source);
		_type = type;
		_initializer = initializer;
	}
	
	public void print(int indent, boolean printChildScopes) {
		printf("%*.*c%s PlainSymbol %p %s", indent, indent, ' ', _name.asString(), this, string(visibility()));
		if (declaredStorageClass() != StorageClass.ENCLOSING)
			printf(" %s", string(declaredStorageClass()));
		if (_type != null) {
			printf(" @%d[%d] ", offset, _type.size());
			_type.print();
		}
		if (value != null)
			printf(" val=%p", value);
		if (offset != 0)
			printf(" offset=%x", offset);
		printf("\n");
		if (_initializer != null && _initializer.op() == Operator.CLASS && _type != null && _type.family() == TypeFamily.TYPEDEF) {
			ref<TypedefType> tt = ref<TypedefType>(_type);
			ref<ClassType> t = ref<ClassType>(tt.wrappedType());
			t.scope().print(indent + INDENT, printChildScopes);
		} else {
			definition().printBasic(indent + INDENT);
			printf("\n");
			if (_typeDeclarator != null) {
				printf("%*.*c  {typeDeclarator}:\n", indent, indent, ' ');
				_typeDeclarator.printBasic(indent + INDENT);
				printf("\n");
			}
			if (_initializer != null) {
				printf("%*.*c  {initializer}:\n", indent, indent, ' ');
				_initializer.printBasic(indent + INDENT);
				printf("\n");
			}
		}
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		if (_type == null) {
			ref<Scope> current = compileContext.current();
			if (_enclosing.storageClass() == StorageClass.TEMPLATE) {
				_type = compileContext.arena().builtInType(TypeFamily.CLASS_DEFERRED);
			} else {
				compileContext.assignTypes(enclosing(), _typeDeclarator);
				if (_typeDeclarator.op() == Operator.CLASS_DECLARATION ||
					_typeDeclarator.op() == Operator.ENUM_DECLARATION)
					_type = _typeDeclarator.type;
				else if (_typeDeclarator.op() == Operator.FUNCTION)
					_type = _typeDeclarator.type;
				else
					_type = _typeDeclarator.unwrapTypedef(compileContext);
			}
		}
		return _type;
	}

	protected boolean validateAnnotations(ref<CompileContext> compileContext) {
		if (annotations() == null)
			return true;
		if (!super.validateAnnotations(compileContext))
			return false;
		if (storageClass() == StorageClass.CONSTANT) {
			switch (_type.family()) {
			case	SIGNED_32:
				if (_initializer == null) {
					definition().add(MessageId.INITIALIZER_REQUIRED, compileContext.pool());
					return false;
				}
				if (!_initializer.isConstant()) {
					definition().add(MessageId.INITIALIZER_MUST_BE_CONSTANT, compileContext.pool());
					return false;
				}
				break;
				
			default:
				print(0, false);
				assert(false);
			}
		}
		return true;
	}
	
	public ref<Node> typeDeclarator() {
		return _typeDeclarator;
	}

	public ref<Node> initializer() {
		return _initializer;
	}
}

class Overload extends Symbol {
	private Operator _kind;
	ref<OverloadInstance>[] _instances;

	Overload(ref<Scope>  enclosing, ref<Node> annotations, ref<CompileString> name, Operator kind) {
		super(Operator.PUBLIC, StorageClass.ENCLOSING, enclosing, annotations, name, null);
		_kind = kind;
	}

	public ref<Symbol> addInstance(Operator visibility, boolean isStatic, ref<Node> annotations, ref<Identifier> name, ref<ParameterScope> functionScope, ref<CompileContext> compileContext) {
		ref<OverloadInstance> sym = compileContext.pool().newOverloadInstance(visibility, isStatic, _enclosing, annotations, name.identifier(), name, functionScope);
		_instances.append(sym);
		return sym;
	}

	public void checkForDuplicateMethods(ref<CompileContext> compileContext) {
		for (int i = 0; i < _instances.length(); i++) {
			for (int j = i + 1; j < _instances.length(); j++) {
				if (_instances[i].parameterScope().equals(_instances[j].parameterScope(), compileContext)) {
					_instances[i].definition().add(MessageId.DUPLICATE, compileContext.pool(), *_name);
					_instances[j].definition().add(MessageId.DUPLICATE, compileContext.pool(), *_name);
				}
			}
		}
	}

	public void merge(ref<Overload> unitDeclarations) {
		for (int i = 0; i < unitDeclarations._instances.length(); i++) {
			ref<OverloadInstance> s = unitDeclarations._instances[i];
			_instances.append(s);
		}
	}

	public void markAsDuplicates(ref<MemoryPool> pool) {
		assert(false);
	}

	public void print(int indent, boolean printChildScopes) {
		printf("%*.*c%s Overload %p %s %s\n", indent, indent, ' ', _name.asString(), this, string(visibility()), string(_kind));
		for (int i = 0; i < _instances.length(); i++)
			_instances[i].print(indent + INDENT, printChildScopes);
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		assert(false);
		return null;
	}

	public Operator kind() {
		return _kind;
	}

	public ref<ref<OverloadInstance>[]> instances() {
		return &_instances;
	}
}

class OverloadInstance extends Symbol {
	private boolean _overridden;
	private ref<ParameterScope> _parameterScope;
	private ref<TemplateInstanceType> _instances;	// For template's, the actual instances of those

	OverloadInstance(Operator visibility, boolean isStatic, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> source, ref<ParameterScope> parameterScope) {
		super(visibility, isStatic ? StorageClass.STATIC : StorageClass.ENCLOSING, enclosing, annotations, name, source);
		_parameterScope = parameterScope;
	}

	public void print(int indent, boolean printChildScopes) {
		printf("%*.*c%s OverloadInstance %p %s %s%s", indent, indent, ' ', _name.asString(), this, string(visibility()), string(storageClass()), _overridden ? " overridden" : "");
		if (_type != null) {
			printf(" @%d ", offset);
			_type.print();
		}
		printf("\n");
		switch (_parameterScope.definition().op()) {
		case	FUNCTION:
			if (printChildScopes)
				_parameterScope.print(indent + INDENT, printChildScopes);
			break;

		case	TEMPLATE:
			if (_type != null && _type.family() == TypeFamily.TYPEDEF && printChildScopes) {
				ref<TypedefType> tt = ref<TypedefType>(_type);
				ref<TemplateType> templateType = ref<TemplateType>(tt.wrappedType());
				templateType.scope().print(indent + INDENT, printChildScopes);
			}
			for (ref<TemplateInstanceType> ti = _instances; ti != null; ti = ti.next()) {
				printf("%*.*c", indent + INDENT, indent + INDENT, ' ');
				ti.print();
				printf("\n");
				if (printChildScopes) {
					if (ti.scope().enclosing() != null)
						ti.scope().enclosing().print(indent + INDENT + INDENT, true);
					else
						ti.scope().print(indent + INDENT + INDENT, true);
					ti.concreteDefinition().print(indent + INDENT + INDENT);
				}
			}
			break;

		default:
			_parameterScope.definition().printBasic(indent + INDENT);
			printf("\n");
		}
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		if (_type == null) {
			compileContext.assignTypesAtScope(_parameterScope, _parameterScope.definition());
			_type = _parameterScope.definition().type;
		}
		return _type;
	}

	public int parameterCount() {
		return _parameterScope.parameterCount();
	}

	public boolean isFunction() {
		return definition() != null && definition().op() == Operator.FUNCTION;
	}

	public Callable callableWith(ref<NodeList> arguments, boolean hasEllipsis, ref<CompileContext> compileContext) {
		int parameter = 0;
		boolean processingEllipsis = false;
		while (arguments != null) {
			ref<PlainSymbol> ps = ref<PlainSymbol>((*_parameterScope.parameters())[parameter]);
			ref<Node> typeDeclarator = ps.typeDeclarator();
			compileContext.assignTypes(typeDeclarator);
			if (typeDeclarator.deferAnalysis())
				return Callable.DEFER;
			ref<Type> t;
			if (typeDeclarator.type.family() == TypeFamily.FUNCTION)
				t = typeDeclarator.type;
			else
				t = typeDeclarator.unwrapTypedef(compileContext);
			if (typeDeclarator.deferAnalysis())
				return Callable.DEFER;
			if (parameter == _parameterScope.parameters().length() - 1 && hasEllipsis) {
				// in this case t is a vector type
				// Check for the special case that the argument has type t
				if (!processingEllipsis && 
					arguments.node.type.equals(t))
					return Callable.YES;
				// okay, we need to actually check the element type
				t = t.elementType(compileContext);
			}
			if (t.family() == TypeFamily.CLASS_VARIABLE) {
				if (arguments.node.type.family() != TypeFamily.TYPEDEF)
					return Callable.NO;
			} else if (!arguments.node.canCoerce(t, false, compileContext))
				return Callable.NO;
			if (parameter == _parameterScope.parameters().length() - 1) {
				// If there are more arguments, then this parameter must be an ellipsis parameter
				processingEllipsis = true;
			} else
				parameter++;
			arguments = arguments.next;
		}
		// If parameters != null, then this must be an ellipsis parameter and
		// the call includes zero ellipsis arguments.
		return Callable.YES;
	}

	public int partialOrder(ref<Symbol> other, ref<NodeList> arguments, ref<CompileContext> compileContext) {
		ref<OverloadInstance> oiOther = ref<OverloadInstance>(other);

		int parameter = 0;
		int bias = 0;
		// TODO: This doens't look right - what effect does it have?
		while (parameter < _parameterScope.parameters().length()) {
			ref<Symbol> symThis = (*_parameterScope.parameters())[parameter];
			ref<Symbol> symOther = (*oiOther._parameterScope.parameters())[parameter];
			ref<Type> typeThis = symThis.assignType(compileContext);
			ref<Type> typeOther = symOther.assignType(compileContext);
			if (!typeThis.equals(typeOther)) {
				if (typeThis.widensTo(typeOther, compileContext)) {
					if (bias < 0)
						return 0;
					bias = 1;
				} else if (typeOther.widensTo(typeThis, compileContext)) {
					if (bias > 0)
						return 0;
					bias = -1;
				}
			}
			parameter++;
		}
		return bias;
	}

	public ref<Type> instantiateTemplate(ref<Call> declaration, ref<CompileContext> compileContext) {
		var[] argValues;

		boolean success = true;
		for (ref<NodeList> nl = declaration.arguments(); nl != null; nl = nl.next) {
			if (nl.node.type.family() == TypeFamily.TYPEDEF) {
				ref<TypedefType> t = ref<TypedefType>(nl.node.type);
				var v = t.wrappedType();
				argValues.append(v);
			} else {
				nl.node.add(MessageId.UNFINISHED_INSTANTIATE_TEMPLATE, compileContext.pool());
				success = false;
			}
		}
		return instantiateTemplate(argValues, compileContext);
	}

	public ref<Type> createAddressInstance(ref<Type> target, ref<CompileContext> compileContext) {
		var v = target;

		var[] args;
		args.append(v);
		return instantiateTemplate(args, compileContext);
	}

	public ref<Type> createVectorInstance(ref<Type> element, ref<Type> index, ref<CompileContext> compileContext) {
		var[] argValues;

		var v1 = element;
		argValues.append(v1);
		var v2 = index;
		argValues.append(v2);
		return instantiateTemplate(argValues, compileContext);
	}

	public boolean overrides(ref<OverloadInstance> baseMethod) {
		if (!baseMethod.name().equals(*_name))
			return false;
		// either they must both have ellipsis, or neither
		if (_parameterScope.parameters().length() != baseMethod._parameterScope.parameters().length())
			return false;
		for (int i = 0; i < _parameterScope.parameters().length(); i++) {
			ref<Symbol> basePar = (*baseMethod._parameterScope.parameters())[i];
			ref<Symbol> par = (*_parameterScope.parameters())[i];
			if (!par.type().equals(basePar.type()))
				return false;
		}
		// TODO: Validate correct override return types.  Must be equal, or if not, they must
		// satisfy 'co-variance', that is the return type must be an address with a type that widens
		// from the overriding method to the overridden method.
		return true;
	}

	public void overrideMethod() {
		_overridden = true;
	}

	public boolean isConcrete(ref<CompileContext> compileContext) {
		assignType(compileContext);
		if (_type.family() != TypeFamily.FUNCTION)
			return true;
		ref<FunctionType> ft = ref<FunctionType>(_type);
		if (ft.scope().definition().op() != Operator.FUNCTION)
			return true;
		ref<Function> func = ref<Function>(ft.scope().definition());
		if (func.functionCategory() != Function.Category.ABSTRACT)
			return true;
		return false;
	}

	public ref<ParameterScope> parameterScope() {
		return _parameterScope;
	}

	public boolean overridden() {
		return _overridden;
	}

	private ref<Type> instantiateTemplate(var[] arguments, ref<CompileContext> compileContext) {
		for (ref<TemplateInstanceType> t = _instances; t != null; t = t.next()) {
			if (t.match(arguments))
				return t;
		}
		ref<TemplateType> templateType = ref<TemplateType>(ref<TypedefType>(_type).wrappedType());
		ref<Scope> templateScope = _parameterScope;
		ref<Scope> instanceParametersScope = 
			compileContext.arena().createScope(_parameterScope.enclosing(), null, StorageClass.TEMPLATE_INSTANCE);

		// Create one symbol for each symbol in templateScope and assign it the
		// corresponding argument, after coercing the argument to the symbol's type.

//		memDump(_parameterScope, (*_parameterScope).bytes);
		for (int i = 0; i < _parameterScope.parameterCount(); i++) {
			ref<Symbol> sym = (*_parameterScope.parameters())[i];
			if (sym.class != PlainSymbol)
				continue;
			ref<PlainSymbol> ps = ref<PlainSymbol>(sym);
//			if (ref<Type>(arguments[i]).family() == TypeFamily.ERROR) {
//				print(0, false);
//			}
			ref<Symbol> iSym = instanceParametersScope.define(Operator.PRIVATE, StorageClass.ENCLOSING, sym.annotationNode(), sym.definition(), compileContext.makeTypedef(ref<Type>(arguments[i])), null, 
																compileContext.pool());
		}
		ref<Template> definition = templateType.definition().cloneRaw();
		ref<ClassScope> instanceBodyScope = compileContext.arena().createClassScope(instanceParametersScope, definition.classDef, definition.name());
		compileContext.buildScopes();
		ref<TemplateInstanceType> result = compileContext.newTemplateInstanceType(templateType, arguments, definition, templateType.definingFile(), instanceBodyScope, _instances);
		instanceBodyScope.classType = result;
		_instances = result;
		return result;
	}
}

class Symbol {
	public int offset;				// Variable offset within scope block
	public address value;			// Scratch address for use by code generators.

	protected ref<CompileString> _name;
	protected ref<Type> _type;
	protected ref<Scope> _enclosing;
	private ref<ref<Call>[string]> _annotations;
	private ref<Node> _annotationNode;
	
	private boolean _inProgress;
	private ref<Node> _definition;
	private StorageClass _storageClass;
	private Operator _visibility;

	protected Symbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<CompileString> name, ref<Node> definition) {
		_visibility = visibility;
		if (annotations != null) {
			_annotations = new ref<Call>[string];
			populateAnnotations(annotations);
			_annotationNode = annotations;
		}
		_storageClass = storageClass;
		_enclosing = enclosing;
		_name = name;
		_definition = definition;
	}

	public abstract void print(int indent, boolean printChildScopes);

	public ref<Type> assignType(ref<CompileContext> compileContext) {
		if (_type == null) {
			if (_inProgress) {
				_definition.add(MessageId.CIRCULAR_DEFINITION, compileContext.pool(), *_name);
				_type = compileContext.errorType();
			} else {
				_inProgress = true;
				ref<Type> t = assignThisType(compileContext);
				if (_type == null)
					_type = t;
				validateAnnotations(compileContext);
				_inProgress = false;
			}
		}
		return _type;
	}

	public abstract ref<Type> assignThisType(ref<CompileContext> compileContext);

	public int parameterCount() {
		assert(false);
		return 0;
	}

	public TypeFamily effectiveFamily() {
		if (_annotations == null)
			return TypeFamily.CLASS;
		if ((*_annotations)["Shape"] != null)
			return TypeFamily.SHAPE;
		else if ((*_annotations)["Pointer"] != null)
			return TypeFamily.POINTER;
		else if ((*_annotations)["Ref"] != null)
			return TypeFamily.REF;
		else
			return TypeFamily.CLASS;
	}
	
	public ref<Call> getAnnotation(string name) {
		if (_annotations == null)
			return null;
		return (*_annotations)[name];
	}
	
	private void populateAnnotations(ref<Node> annotations) {
		if (annotations.op() == Operator.SEQUENCE) {
			ref<Binary> b = ref<Binary>(annotations);
			populateAnnotations(b.left());
			populateAnnotations(b.right());
		} else {
			ref<Call> b = ref<Call>(annotations);
			ref<Identifier> id = ref<Identifier>(b.target());
			(*_annotations)[id.identifier().asString()] = b;
		}
	}
	/*
	 *	callableWith
	 *
	 *	Determines whether this overload instance can be called with this argument
	 *	list.  It is only called after confirming that the argument count is
	 *	acceptable.  For fixed argument-list functions, both arguments and parameters
	 *	lists have identical lengths.  In variable-arguments (ellipsis) function,
	 *	there may be one less argument than there are parameters, or any number of
	 *	arguments more than that.
	 *
	 *	Except for ellipsis arguments, all arguments must be compatible with the
	 *	corresponding parameter type.  When the last argument corresponds to the
	 *	ellipsis parameter itself, that argument may be compatible with the 
	 *	parameter vetor type, or may be compatiable with the parameter's element type.
	 *
	 *	For now, to be compatible, an argument type must be convertible as if by
	 *	assignment to the parameter type.  In the future, this will be extended to
	 *	include the case where the argument type is some form of collection of
	 *	elements that is convertible to the parameter type.  Such cases are handled
	 *	by the process of vectorization of expressions.  Binding an argument to
	 *	a parameter using vectorization is treated for matching purposes as less
	 *	good a fit than any binding that involves only conversion of arguments.
	 */
	public Callable callableWith(ref<NodeList> arguments, boolean hasEllipsis, ref<CompileContext> compileContext) {
		assert(false);
		return Callable.NO;
	}
	/*
	 *	partialOrder
	 *
	 *	Determines which symbol better matches the
	 *	given argument list (this vs. other).
	 *
	 *	RETURNS
	 *		< 0	this less good than other
	 *		== 0 this neither better nor worse than other
	 *		> 0 this better than other
	 */
	public int partialOrder(ref<Symbol> other, ref<NodeList> arguments, ref<CompileContext> compileContext) {
		assert(false);
		return 0;
	}

	public void add(MessageId messageId, ref<MemoryPool> pool, CompileString... args) {
		_definition.add(messageId, pool, args);
	}

	public boolean deferAnalysis() {
		if (_type == null)
			return true;
		switch (_type.family()) {
		case	ERROR:
		case	CLASS_DEFERRED:
			return true;

		default:
			return false;
		}
		return false;
	}

	public ref<BuiltInType> bindBuiltInType(TypeFamily family, ref<CompileContext> compileContext) {
		if (_type.family() != TypeFamily.TYPEDEF) {
			_definition.add(MessageId.NOT_A_TYPE, compileContext.pool());
			return null;
		}
		ref<TypedefType> typedefType = ref<TypedefType>(_type);
		ref<Type> t = typedefType.wrappedType();
		if (t.family() != TypeFamily.CLASS) {
			_definition.add(MessageId.CANNOT_CONVERT, compileContext.pool());
			return null;
		}
		ref<BuiltInType> bt = compileContext.pool().newBuiltInType(family, ref<ClassType>(t));
		_type = compileContext.makeTypedef(bt);
		return bt;
	}

	public boolean bindType(ref<Type> t, ref<CompileContext> compileContext) {
		if (_type == null) {
			_type = t;
			validateAnnotations(compileContext);
			return true;
		} else
			return _type.equals(t);
	}

	protected boolean validateAnnotations(ref<CompileContext> compileContext) {
		if (_annotations == null)
			return true;
		ref<Call> annotation = (*_annotations)["Constant"];
		if (annotation != null) {
			// If this symbol has a Constant annotation, be sure to validate it.
			if (annotation.argumentCount() > 0) {
				_definition.add(MessageId.ANNOTATION_TAKES_NO_ARGUMENTS, compileContext.pool());
				return false;
			}
			if (storageClass() == StorageClass.STATIC)
				_storageClass = StorageClass.CONSTANT;
			else {
				_definition.add(MessageId.CONSTANT_NOT_STATIC, compileContext.pool());
				return false;
			}
		}
		return true;
	}
	
	public StorageClass storageClass() {
		if (_storageClass != StorageClass.ENCLOSING)
			return _storageClass;
		if (_enclosing != null)
			return _enclosing.storageClass();
		else
			return StorageClass.STATIC;
	}

	public StorageClass declaredStorageClass() {
		return _storageClass;
	}

	public ref<CompileString> name() {
		return _name;
	}

	public ref<Node> definition() {
		return _definition;
	}
	
	public boolean isFunction() {
		return false;
	}

	public ref<Scope> enclosing() {
		return _enclosing;
	}

	public ref<Type> type() {
		return _type;
	}

	public Operator visibility() {
		return _visibility;
	}

	public ref<ref<Call>[string]> annotations() {
		return _annotations;
	}
	
	public ref<Node> annotationNode() {
		return _annotationNode;
	}
	
	int compare(ref<Symbol> other) {
		int min = _name.length;
		if (other._name.length < min)
			min = other._name.length;
		for (int i = 0; i < min; i++) {
			int diff = _name.data[i].toLowercase() - other._name.data[i].toLowercase();
			if (diff != 0)
				return diff;
		}
		if (_name.length < other._name.length)
			return -1;
		else if (_name.length == other._name.length)
			return 0;
		else
			return 1;
	}

}

class OverloadOperation {
	private boolean _done;
	private boolean _hadConstructors;
	private ref<Node> _node;
	private ref<CompileString> _name;
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

	public OverloadOperation(Operator kind, ref<Node> node, ref<CompileString> name, ref<NodeList> arguments, ref<CompileContext> compileContext) {
		_name = name;
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

	public ref<Type> includeScope(ref<Scope> lexicalScope, ref<Scope> s) {
//		string ts = "Unit";
//		if (ts == _name.asString()) {
//			printf("Looking for Unit...\n");
//			s.print(0, false);
//		}
		ref<Symbol> sym = s.lookup(_name);
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
			ref<Symbol> oi = (*o.instances())[i];
			_anyPotentialOverloads = true;
			if (!s.encloses(lexicalScope)) {
				if (oi.visibility() == Operator.PRIVATE)
					continue;
				else if (oi.visibility() == Operator.PROTECTED) {
					// TODO: what is in scope for protected variables?
				}
			}
			ref<Type> t = includeOverload(oi);
			if (t != null)
				return t;
		}
		return null;
	}

	public ref<Type> includeOverload(ref<Symbol> oi) {
		oi.assignType(_compileContext);
		if (oi.deferAnalysis())
			return oi.type();
		int count = oi.parameterCount();
//		printf("%s parameter count = %d vs %d\n", oi.name().asString(), count, _argCount);
		if (count == int.MIN_VALUE) {
			_node.add(MessageId.NO_FUNCTION_TYPE, _compileContext.pool(), *_name);
			return _compileContext.errorType();
		}
		if (count == NOT_PARAMETERIZED_TYPE) {
			_node.add(MessageId.NOT_PARAMETERIZED_TYPE, _compileContext.pool(), *_name);
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

			// An implicit assumption in this algorithm is that the
			// partialOrdering of overloads is 
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
					if (partialOrder > 0)
						includeOi = false;
					i++;
				}
			}
			if (includeOi)
				_best.append(oi);
		}
		return null;
	}

	public ref<Type> includeConstructors(ref<Type> classType, ref<CompileContext> compileContext) {
		for (int i = 0; i < classType.scope().constructors().length(); i++) {
			_hadConstructors = true;
			ref<Function> f = ref<Function>((*classType.scope().constructors())[i].definition());
			if (f == null || f.name() == null)
				continue;
			ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
			ref<Type> t = includeOverload(oi);
			if (t != null)
				return t;
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
			if (_name != null) {
				_node.add(_anyPotentialOverloads ? MessageId.NO_MATCHING_OVERLOAD : MessageId.UNDEFINED, _compileContext.pool(), *_name);
//				_node.print(2);
//				for (ref<NodeList> nl = _arguments; nl != null; nl = nl.next)
//					nl.node.print(6);
			} else if (_arguments == null && !_hadConstructors) {
				return _compileContext.arena().builtInType(TypeFamily.VOID), null;
			} else
				_node.add(MessageId.NO_MATCHING_CONSTRUCTOR, _compileContext.pool());
			break;

		default:
			if (_name != null)
				_node.add(MessageId.AMBIGUOUS_OVERLOAD, _compileContext.pool(), *_name);
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
