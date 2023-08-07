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

import parasol:runtime;
import parasol:runtime.TypeFamily;
import parasol:stream;
import parasol:text;

public class Namespace extends Symbol {
	private ref<ClassScope> _symbols;
	private substring _dottedName;
	private substring _domain;
	private ref<Unit>[] _units;				// Units that have been defined for this Arena's namespaces, excluding imports.

	Namespace(substring domain, ref<Node> namespaceNode, ref<Scope> enclosing, 
				ref<Node> annotations, substring name, ref<Arena> arena, ref<MemoryPool> pool) {
		super(Operator.PUBLIC, StorageClass.ENCLOSING, enclosing, annotations, pool, name, null);
		if (arena != null)
			_symbols = arena.createNamespaceScope(enclosing, this);
		else
			_symbols = pool new NamespaceScope(enclosing, this);
		if (namespaceNode != null) {
			boolean x;
			string d;

			(d, x) = namespaceNode.dottedName();
			_dottedName = pool.newCompileString(d);
		}
		_domain = domain;
	}

	public void print(int indent, boolean printChildScopes) {
		printf("%*.*c", indent, indent, ' ');
		if (_name != null)
			printf("%s", _name);
		else
			printf("<null>");
		printf(" Namespace %p %s", this, string(visibility()));
		if (_type != null) {
			printf(" @%d ", offset);
			_type.print();
		}
		printf("\n");
		for (i in _units)
			printf("%*.*c%s\n", indent + 8, indent + 8, ' ', _units[i].filename());
		if (printChildScopes) {
			_symbols.print(indent + INDENT, false);
			printf("\n");
		}
		printAnnotations(indent + INDENT);
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		ref<Type> base = compileContext.builtInType(TypeFamily.NAMESPACE);
		_type = compileContext.pool().newClassType(TypeFamily.CLASS, base, _symbols);
		return _type;
	}

	public ref<Symbol> findImport(ref<Ternary> namespaceNode, ref<CompileContext> compileContext) {
		ref<Identifier> id = ref<Identifier>(namespaceNode.right());
		if (namespaceNode.middle().op() == Operator.EMPTY) {
			if (_name != null && _name == id.identifier())
				return this;
			else
				return null;
		} else {
			ref<Symbol> sym = _symbols.lookup(id.identifier(), compileContext);
			if (sym != null && sym.visibility() == Operator.PUBLIC)
				return sym;
			else
				return null;
		}
	}

	boolean includes(ref<Ternary> namespaceNode) {
		ref<Node> name = namespaceNode.middle();
//		printf("          dotted name = %s\n", _dottedName);
		string newName;
		boolean x;
		if (name.op() == Operator.EMPTY)
			(newName, x) = namespaceNode.right().dottedName();
		else
			(newName, x) = name.dottedName();
//		printf("          namespaceNode middle name = %s\n", newName);
		if (!_dottedName.startsWith(newName))
			return false;
		if (_dottedName.length() == newName.length()) {
//			printf("          lengths match\n");
			return true;
		}
		return _dottedName[newName.length()] == '.';
	}

	public void includeUnit(ref<Unit> unit) {
		_units.append(unit);
	}

	public ref<ref<Unit>[]> includedUnits() {
		return &_units;
	}

	public int includedUnitCount() {
		return _units.length();
	}

	public ref<Scope> symbols() {
		return _symbols;
	}
	
	public string domain() {
		return _domain;
	}
	/**
	 * This is the namespace string, excluding the domain.
	 *
	 * @return The dotted list of identifiers that compose the namespace.
	 */
	public string dottedName() {
		return _dottedName;
	}

	public string fullNamespace() {
		return _domain + ":" + _dottedName;
	}
}

public flags Access {
	CONSTANT,
	COMPILE_TARGET,
	CONSTRUCTED			// If the object is not initialized with a constructor, it will be constructed at scope start.						// the bit will be set any constructor initializer is performed.
}
/*
 * DelegateSymbol
 * 
 * This class represents a plain symbol visible through a lock statement.
 */
class DelegateSymbol extends PlainSymbol {
	ref<PlainSymbol> _delegate;
	
	DelegateSymbol(ref<Scope> enclosing, ref<PlainSymbol> delegate, ref<MemoryPool> pool) {
		super(Operator.PUBLIC, StorageClass.LOCK, enclosing, null, pool, delegate.name(), null, ref<Type>(null), null);
		_delegate = delegate;
	}
	
	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		return _delegate.assignThisType(compileContext);
	}
	
	ref<PlainSymbol> delegate() {
		return _delegate;
	}
}
/*
	PlainSymbol
	
	This class represents a 'plain' symbol, one that is not overloaded (i.e. neither functions nor templates).
	
	There are two relevant components that define a symbol: the type declaration and any initializer supplied
	with the declaration.
 */
public class PlainSymbol extends Symbol {
	private ref<Node> _typeDeclarator;
	private ref<Node> _initializer;
	private Access _accessFlags;
	
	PlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<MemoryPool> pool, substring name, ref<Node> source, ref<Node> typeDeclarator, ref<Node> initializer) {
		super(visibility, storageClass, enclosing, annotations, pool, name, source);
		_typeDeclarator = typeDeclarator;
		_initializer = initializer;
	}
	
	PlainSymbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<MemoryPool> pool, substring name, ref<Node> source, ref<Type> type, ref<Node> initializer) {
		super(visibility, storageClass, enclosing, annotations, pool, name, source);
		_type = type;
		_initializer = initializer;
	}
	
	public void print(int indent, boolean printChildScopes) {
//		printf("%p name [ %p. %d ]\n", this, _name.data, _name.length);
		printf("%*.*c%s PlainSymbol %p %s", indent, indent, ' ', _name, this, string(visibility()));
		if (declaredStorageClass() != StorageClass.ENCLOSING)
			printf(" %s", string(declaredStorageClass()));
		if (_type != null)
			printf(" @%d[%d] %s", offset, _type.size(), _type.signature());
		if (value != null)
			printf(" val=%p", value);
		if (_accessFlags)
			printf(" _accessFlags=%x", long(_accessFlags));
		printf("\n");
		if (_initializer != null && _initializer.op() == Operator.CLASS && _type != null && _type.family() == TypeFamily.TYPEDEF) {
			ref<TypedefType> tt = ref<TypedefType>(_type);
			ref<Type> declaredType = tt.wrappedType();
			if (declaredType.class == BuiltInType)
				declaredType = ref<BuiltInType>(declaredType).classType();
			if (declaredType.class == ClassType) {
				ref<ClassType> c = ref<ClassType>(declaredType);
				if (c.definition() != null) {
					if (c.definition().name().identifier() == _name) {
						if (c.interfaceCount() > 0) {
							ref<ref<InterfaceType>[]> it = c.interfaces();
							for (int i = 0; i < it.length(); i++) {
								ref<InterfaceType> itt = (*it)[i];
								printf("%*.*c      Implements %s\n", indent, indent, ' ', itt.signature());
							}
						}
					}
				}
			}
			declaredType.scope().print(indent + INDENT, printChildScopes);
		} else {
			if (definition() != null) {
				definition().printBasic(indent + INDENT);
				printf("\n");
			}
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
		printAnnotations(indent + INDENT);
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		if (_type == null) {
			ref<Scope> current = compileContext.current();
			if (_typeDeclarator.op() == Operator.EMPTY) {
				if (_initializer != null) {
					compileContext.assignTypes(enclosing(), _initializer);
					if (_initializer.deferAnalysis())
						_type = _initializer.type;
					else if (_initializer.type.family() == TypeFamily.TYPEDEF) {
						_type = _initializer.type;
					} else {
						_initializer.add(MessageId.NOT_A_TYPE, compileContext.pool());
						_type = compileContext.errorType();
					}
				} else
					_type = compileContext.builtInType(TypeFamily.CLASS_VARIABLE);
			} else {
				compileContext.assignDeclarationTypes(enclosing(), _typeDeclarator);
				if (_typeDeclarator.deferAnalysis()) {
					_type = _typeDeclarator.type;
					return _type;
				}
				switch (_typeDeclarator.op()) {
				case CLASS_DECLARATION:
				case ENUM:
				case INTERFACE_DECLARATION:
					_type = _typeDeclarator.type;
					break;

				case FUNCTION:
					_type = _typeDeclarator.type;
					break;

				case LOOP:
					ref<Loop> loop = ref<Loop>(_typeDeclarator);
					ref<Type> t = loop.aggregate().type;
					if (t.deferAnalysis())
						_type = t;
					else {
						switch (t.family()) {
						case SHAPE:
							_type = t.indexType();
							break;

						case OBJECT_AGGREGATE:
							_type = compileContext.builtInType(TypeFamily.STRING);
							break;

						case STRING:
						case STRING16:
						case SUBSTRING:
						case SUBSTRING16:
						case ARRAY_AGGREGATE:
							_type = compileContext.builtInType(TypeFamily.SIGNED_32);
							break;

						default:	// Any error message is being assigned elsewhere
							_type = compileContext.errorType();
						}
					}
					break;
				
				default:
					_type = _typeDeclarator.unwrapTypedef(Operator.CLASS, compileContext);
					if (_type.family() == TypeFamily.VOID)
						_type = compileContext.errorType();
					if (_enclosing.storageClass() == StorageClass.TEMPLATE && _type.family() == TypeFamily.CLASS_VARIABLE)
						_type = compileContext.builtInType(TypeFamily.CLASS_DEFERRED);
				}
			}
		}
		return _type;
	}
	/**
	 * This folds an initializer expression in order to extract a constant expression that can be used to 
	 * initialize a constant.
	 *
	 * Note: the expression must be cloned, because folding calls is not repeatable. If we did not clone
	 * the expression here, then later code generation would choke if there were any embedded COERCION calls, for example.
	 */
	public ref<Node> foldInitializer(ref<CompileContext> compileContext) {
		_initializer = compileContext.fold(_initializer.clone(_enclosing.unit().tree()), _enclosing.unit());
		return _initializer;
	}

	protected void validateAnnotations(ref<CompileContext> compileContext) {
		if (annotations() == null)
			return;
		ref<Call> annotation = (*annotations())[Annotations.CONSTANT];
		if (annotation != null) {
			// If this symbol has a Constant annotation, be sure to validate it.
			if (annotation.argumentCount() > 0) {
				definition().add(MessageId.ANNOTATION_TAKES_NO_ARGUMENTS, compileContext.pool());
				return;
			}
			if (storageClass() != StorageClass.STATIC) {
				definition().add(MessageId.CONSTANT_NOT_STATIC, compileContext.pool());
				return;
			}
			switch (_type.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				if (_initializer == null) {
					definition().add(MessageId.INITIALIZER_REQUIRED, compileContext.pool());
					return;
				}
				compileContext.assignTypes(enclosing(), _initializer);
				if (!_initializer.isConstant()) {
					_initializer.print(0);
					definition().add(MessageId.INITIALIZER_MUST_BE_CONSTANT, compileContext.pool());
					return;
				}
				break;
				
			case	FUNCTION:
			case	CLASS:
			case	SHAPE:
				definition().add(MessageId.CONSTANT_NOT_ALLOWED, compileContext.pool());
				return;

			case	ERROR:
				return;
				
			default:
				print(0, false);
				assert(false);
			}
			_accessFlags |= Access.CONSTANT;
		}
		annotation = (*annotations())[Annotations.COMPILE_TARGET];
		if (annotation != null) {
			if (annotation.argumentCount() > 0) {
				definition().add(MessageId.ANNOTATION_TAKES_NO_ARGUMENTS, compileContext.pool());
				return;
			}
			if (compileContext.compileTarget != null) {
				definition().add(MessageId.BAD_COMPILE_TARGET, compileContext.pool());
				return;
			}
			if (storageClass() != StorageClass.STATIC) {
				definition().add(MessageId.CONSTANT_NOT_STATIC, compileContext.pool());
				return;
			}
			_accessFlags |= Access.COMPILE_TARGET;
		}
	}

	public boolean isEnumClass() {
		if (_typeDeclarator == null)
			return false;
		return _typeDeclarator.op() == Operator.ENUM;
	}
	
	public ref<Node> typeDeclarator() {
		return _typeDeclarator;
	}

	public ref<Node> initializer() {
		return _initializer;
	}
	
	public boolean isFullyAnalyzed() {
		if (_type == null)
			return false;
		if (_initializer != null && _initializer.deferAnalysis())
			return false;
		return true;
	}
	
	public Access accessFlags() {
		return _accessFlags;
	}
	
	public boolean configureDefaultConstructors() {
		if (_type == null)
			return false;
		if (_type.family() == TypeFamily.TYPEDEF) {
			_accessFlags |= Access.CONSTRUCTED;
			return false;
		}
		if (storageClass() == StorageClass.ENUMERATION) {
			_accessFlags |= Access.CONSTRUCTED;
			return false;
		}
		// If the symbol was declared with a constructor, then it is not constructed on entry and we have to leave
		// the constructed flag for itleared.
		if (_initializer != null &&
			_initializer.op() == Operator.CALL &&
			ref<Call>(_initializer).category() == CallCategory.CONSTRUCTOR) {
			// We have an object declared with a constructor, it will not be constructed until we execute the 
			// declaration statement, so prior accesses generate errors.
			_accessFlags &= ~Access.CONSTRUCTED;
//			printf("    Constructor:\n");
//			print(8, false);
			return true;
		} else {
			_accessFlags |= Access.CONSTRUCTED;
//			printf("    Not Constructor:\n");
//			print(8, false);
			return false;
		}
	}
	
	public boolean initializedWithConstructor() {
		if (deferAnalysis())
			return false;
		if (_type.family() == TypeFamily.TYPEDEF)
			return false;
		if (storageClass() == StorageClass.ENUMERATION)
			return false;
		// If the symbol was declared with a constructor, then it is not constructed on entry and we have to leave
		// the constructed flag for itleared.
		if (_initializer != null &&
			_initializer.op() == Operator.CALL) {
			if (_initializer.deferAnalysis())
				return true;
			if (ref<Call>(_initializer).category() == CallCategory.CONSTRUCTOR) {
				// If the class has no declared constructors, then this symbol is not
				// really initialized with a constructor, just the syntax.
				return _type.hasConstructors();
			}
		}
		return false;
	}
	
	public void construct() {
		_accessFlags |= Access.CONSTRUCTED;
	}
}

public class Overload extends Symbol {
	private Operator _kind;
	ref<OverloadInstance>[] _instances;

	Overload(ref<Scope>  enclosing, ref<Node> annotations, ref<MemoryPool> pool, substring name, Operator kind) {
		super(Operator.PUBLIC, StorageClass.ENCLOSING, enclosing, annotations, pool, name, null);
		_kind = kind;
	}

	public ref<Symbol> addInstance(Operator visibility, boolean isStatic, boolean isFinal, ref<Node> annotations, ref<Identifier> name, ref<ParameterScope> functionScope, ref<CompileContext> compileContext) {
		ref<OverloadInstance> sym = compileContext.pool().newOverloadInstance(this, visibility, isStatic, isFinal, _enclosing, annotations, name.identifier(), name, functionScope);
		_instances.append(sym, compileContext.pool());
		return sym;
	}

	public void addSpecialInstance(ref<OverloadInstance> symbol, ref<CompileContext> compileContext) {
		_instances.append(symbol, compileContext.pool());
	}

	public void checkForDuplicateMethods(ref<CompileContext> compileContext) {
		for (int i = 0; i < _instances.length(); i++) {
			for (int j = i + 1; j < _instances.length(); j++) {
				if (_instances[i].parameterScope().equals(_instances[j].parameterScope(), compileContext)) {
					_instances[i].definition().addUnique(MessageId.DUPLICATE, compileContext.pool(), _name);
					_instances[j].definition().addUnique(MessageId.DUPLICATE, compileContext.pool(), _name);
				}
			}
		}
	}

	public void cloneDelegates(ref<Overload> src, ref<MemoryPool> memoryPool) {
		for (int i = 0; i < src._instances.length(); i++) {
			ref<OverloadInstance> oi = src._instances[i];
			ref<OverloadInstance> newOi = memoryPool.newDelegateOverload(this, oi);
			_instances.append(newOi, memoryPool);
		}
	}
	
	public void merge(ref<Overload> unitDeclarations, ref<CompileContext> compileContext) {
		for (i in unitDeclarations._instances) {
			ref<OverloadInstance> s = unitDeclarations._instances[i];
			if (s.visibility() == Operator.PRIVATE)
				continue;
/*
			boolean sawDuplicate;
			for (j in _instances) {
				ref<OverloadInstance> existing = _instances[j];
				if (s.parameterScope().equals(existing.parameterScope(), compileContext)) {
					s.definition().addUnique(MessageId.DUPLICATE, compileContext.pool(), s.name());
					existing.definition().addUnique(MessageId.DUPLICATE, compileContext.pool(), existing.name());
					sawDuplicate = true;
					break;
				}
			}
			if (!sawDuplicate)
 */
			_instances.append(s, compileContext.pool());
		}
	}

	public void markAsDuplicates(ref<MemoryPool> pool) {
		for (i in _instances)
			_instances[i].definition().addUnique(MessageId.DUPLICATE, pool, _instances[i].name());
	}

	public boolean doesImplement(ref<OverloadInstance> interfaceMethod) {
		for (int i = 0; i < _instances.length(); i++) {
			ref<OverloadInstance> oi = _instances[i];
			// oi is the interface method, this represents the class' methods of the same name
			if (oi.type().equals(interfaceMethod.type()))
				return true;
		}
		return false;
	}

	public void print(int indent, boolean printChildScopes) {
		printf("%*.*c%s Overload %p %s %s\n", indent, indent, ' ', _name, this, string(visibility()), string(_kind));
		for (int i = 0; i < _instances.length(); i++)
			_instances[i].print(indent + INDENT, printChildScopes);
		printAnnotations(indent + INDENT);
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		for (i in _instances)
			_instances[i].assignType(compileContext);
		return null;
	}

	public Operator kind() {
		return _kind;
	}

	public ref<ref<OverloadInstance>[]> instances() {
		return &_instances;
	}
}

public class DelegateOverload extends OverloadInstance {
	ref<OverloadInstance> _delegate;
	
	DelegateOverload(ref<Overload> overload, ref<OverloadInstance> delegate, ref<MemoryPool> pool) {
		super(overload, Operator.NAMESPACE, delegate.storageClass() == StorageClass.STATIC, delegate.isFinal(), overload.enclosing(), null, pool, delegate.name(), null, delegate.parameterScope());
		_delegate = delegate;
	}
	
	public ref<Type> assignType(ref<CompileContext> compileContext) {
		if (_type == null)
			_type = _delegate.assignType(compileContext);
		return _type;
	}

	public int parameterCount() {
		return _delegate.parameterCount();
	}

	public void print(int indent, boolean printChildScopes) {
		printf("%*.*c%s DelegateOverload %p ", indent, indent, ' ', _delegate.name(), this);
		printf("\n");
	}

	public ref<OverloadInstance> delegate() {
		return _delegate;
	}
}

public class StubOverload extends OverloadInstance {
	ref<InterfaceType> _interfaceType;

	StubOverload(ref<InterfaceType> interfaceType, ref<Overload> overload, ref<MemoryPool> pool, ref<ParameterScope> parameterScope) {
		super(overload, Operator.PUBLIC, true, false, overload.enclosing(), null, pool, overload.name(), null, parameterScope);
		_interfaceType = interfaceType;
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		if (_type == null) {
			ref<Type>[] returns = [ compileContext.builtInType(TypeFamily.STRING) ];
			ref<ClassType> rpcStubParams = compileContext.getClassType("rpc.StubParams");
			ref<Type>[] parameters = [ _interfaceType, compileContext.newRef(rpcStubParams) ];

			ref<ParameterScope> scope = parameterScope();
			_type = scope.type = compileContext.pool().newFunctionType(returns, parameters, false);

			ref<SyntaxTree> tree = compileContext.tree();
			runtime.SourceOffset loc = _interfaceType.definition().location();
			ref<Node> n = tree.newIdentifier("object", loc);
			scope.define(Operator.PUBLIC, StorageClass.PARAMETER, null, n, parameters[0], compileContext.pool());
			n = tree.newIdentifier("params", loc);
			scope.define(Operator.PUBLIC, StorageClass.PARAMETER, null, n, parameters[1], compileContext.pool());
		}
		return _type;
	}

	public ref<InterfaceType> interfaceType() {
		return _interfaceType;
	}
}

public class ProxyOverload extends OverloadInstance {
	ref<InterfaceType> _interfaceType;

	ProxyOverload(ref<InterfaceType> interfaceType, ref<Overload> overload, ref<MemoryPool> pool, ref<ParameterScope> parameterScope) {
		super(overload, Operator.PUBLIC, true, false, overload.enclosing(), null, pool, overload.name(), null, parameterScope);
		_interfaceType = interfaceType;
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		if (_type == null) {
			ref<Symbol> sym = compileContext.forest().getSymbol("parasol", "rpc.Client", compileContext);
			if (sym != null) {
	//			printf(" --- assignThisType(%s) ---\n", _interfaceType.signature());
				runtime.SourceOffset loc = _interfaceType.definition().location();
				ref<SyntaxTree> tree = compileContext.tree();

				ref<Type>[] returns = [ _interfaceType ];

				ref<TemplateInstanceType> rpcClient = getRpcClient(sym, compileContext);			
				if (rpcClient == null) {
					_interfaceType.definition().add(MessageId.NO_RPC_CLIENT, compileContext.pool());
					// This can be silent. Something else has to invoke rpc.Client
					return _type = compileContext.errorType();
				}
				ref<Type> clientTransport = compileContext.getClassType("rpc.ClientTransport");
				ref<Type> clientProxy = compileContext.getClassType("rpc.ClientProxy");
				ref<Type> tp = compileContext.newRef(clientTransport);
				ref<Node> argName = tree.newIdentifier("a", loc);
				parameterScope().define(Operator.NAMESPACE, StorageClass.ENCLOSING, null, argName, tp, compileContext.pool());
				_type = compileContext.pool().newFunctionType(returns, parameterScope());
				ref<Scope> scope = compileContext.arena().createScope(parameterScope(), null, StorageClass.AUTO);
				ref<ClassScope> classScope = compileContext.arena().createClassScope(scope, null, null);
				classScope.classType = compileContext.pool().newClassType(clientProxy, true, classScope);
				classScope.classType.implement(_interfaceType);
				scope = _interfaceType.scope();
				ref<ref<Symbol>[Scope.SymbolKey]> syms = scope.symbols();
				for (key in *syms) {
					ref<Symbol> sym = (*syms)[key];
					if (sym.class != Overload)
						continue;
					ref<Overload> o = ref<Overload>(sym);
					ref<ref<OverloadInstance>[]> instances = o.instances();
					for (i in *instances) {
						ref<OverloadInstance> oi = (*instances)[i];
						if (oi.storageClass() == StorageClass.STATIC)
							continue;
						ref<Type> tp = oi.assignType(compileContext);
						if (tp.deferAnalysis())
							continue;

						// Add the parameters to the PROXY_METHOD scope:
						ref<ref<Symbol>[]> params = oi.parameterScope().parameters();
						ref<ProxyMethodScope> functionScope = compileContext.createProxyMethodScope(classScope);
						assert(tp.family() == TypeFamily.FUNCTION);
						functionScope.type = ref<FunctionType>(tp);
						for (i in *params) {
							ref<Symbol> param = (*params)[i];
							if (param.class != PlainSymbol)
								continue;
							functionScope.define(Operator.NAMESPACE, StorageClass.PARAMETER, null, param.definition(), param.type(), compileContext.pool());
						}
						ref<Overload> o = classScope.defineOverload(oi.name(), Operator.FUNCTION, compileContext);
						ref<OverloadInstance> impl = compileContext.pool().newOverloadInstance(o, false, oi.name(), tp, functionScope);
						functionScope.method = impl;
						o.addSpecialInstance(impl, compileContext);
					}
				}
			} else
				return _type = compileContext.errorType();
		}
		return _type;
	}

	private ref<TemplateInstanceType> getRpcClient(ref<Symbol> sym, ref<CompileContext> compileContext) {
		if (sym.class != Overload)
			return null;
		ref<Overload> o = ref<Overload>(sym);
		ref<OverloadInstance> rpcClient = (*o.instances())[0];
		rpcClient.assignType(compileContext);
		var[] args;
		args.push(_interfaceType);
		return rpcClient.instantiateTemplate(args, compileContext);
	}

	public void printSimple() {
		printf("%s ProxyOverload %p %s %s @%d %s\n", _name, this, string(visibility()), string(storageClass()), offset, _type.signature());
	}
}

public class OverloadInstance extends Symbol {
	private boolean _overridden;
	private boolean _final;
	private ref<ParameterScope> _parameterScope;
	private ref<TemplateInstanceType> _instances;	// For template's, the actual instances of those (a linked list)
	private ref<Overload> _overload;

	OverloadInstance(ref<Overload> overload, Operator visibility, boolean isStatic, boolean isFinal, ref<Scope> enclosing, 
							ref<Node> annotations, ref<MemoryPool> pool, substring name, ref<Node> source, ref<ParameterScope> parameterScope) {
		super(visibility, isStatic ? StorageClass.STATIC : StorageClass.ENCLOSING, enclosing, annotations, pool, name, source);
		_overload = overload;
		_parameterScope = parameterScope;
		_final = isFinal;
	}

	OverloadInstance(ref<Overload> overload, boolean isFinal, ref<MemoryPool> pool, substring name, ref<Type> type, ref<ParameterScope> parameterScope) {
		super(Operator.PUBLIC, StorageClass.MEMBER, overload.enclosing(), null, pool, name, null);
		_overload = overload;
		_parameterScope = parameterScope;
		_final = isFinal;
		_type = type;
	}

	public void print(int indent, boolean printChildScopes) {
		printf("%*.*c", indent, indent, ' ');
		printSimple();
		Operator kind;
		if (_overload != null)
			kind = _overload.kind();
		else
			kind = Operator.FUNCTION;
		switch (kind) {
		case	FUNCTION:
			if (printChildScopes)
				_parameterScope.print(indent + INDENT, printChildScopes);
			break;

		case	TEMPLATE:
			if (_type != null && _type.family() == TypeFamily.TYPEDEF && printChildScopes) {
				ref<TypedefType> tt = ref<TypedefType>(_type);
				ref<TemplateType> templateType = ref<TemplateType>(tt.wrappedType());
//				if (templateType.scope() != null)
					templateType.scope().print(indent + INDENT, printChildScopes);
//				else
//					printf("%*.*cnull scope\n", indent + INDENT, indent + INDENT);
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
			_overload.print(indent + INDENT, false);
			printf("\n");
		}
		printAnnotations(indent + INDENT);
	}

	public void printSimple() {
		printf("%s OverloadInstance %p %s %s%s", _name, this, string(visibility()), string(storageClass()), _overridden ? " overridden" : "");
		if (_parameterScope.nativeBinding) {
			printf(" @%x ", offset);
			if (_type != null)
				printf("%s", _type.signature());
		} else if (_type != null)
			printf(" @%d %s", offset, _type.signature());
		printf("\n");
	}

	public ref<Type> assignThisType(ref<CompileContext> compileContext) {
		if (_type == null) {
//			printf(" --- assignThisType ---\n");
//			_parameterScope.definition().print(0);
			compileContext.assignTypes(_parameterScope, _parameterScope.definition());
			_type = _parameterScope.definition().type;
			if (_type == null) {
				_parameterScope.definition().print(0);
			}
			for (int i = 0; i < _parameterScope.parameters().length(); i++) {
				ref<Symbol> par = (*_parameterScope.parameters())[i];
				par.assignType(compileContext);
			}
		}
		return _type;
	}

	public void markAsReferenced(ref<CompileContext> compileContext) {
		if (_parameterScope.definition() != null &&
			_parameterScope.definition().op() == Operator.FUNCTION) {
			ref<FunctionDeclaration> func = ref<FunctionDeclaration>(_parameterScope.definition());
			func.referenced = true;
		}
	}
	
	public ref<Overload> overload() {
		return _overload;
	}

	public ref<TemplateInstanceType> instances() {
		return _instances;
	}

	public int parameterCount() {
		return _parameterScope.parameterCount();
	}

	public boolean hasEllipsis() {
		return _parameterScope.hasEllipsis();
	}

	public Callable callableWith(ref<NodeList> arguments, ref<CompileContext> compileContext) {
		int parameter = 0;
		boolean processingEllipsis = false;
		while (arguments != null) {
			ref<PlainSymbol> ps = ref<PlainSymbol>((*_parameterScope.parameters())[parameter]);
			ref<Node> typeDeclarator = ps.typeDeclarator();
			ref<Type> t;
			if (typeDeclarator == null)
				t = ps.type();
			else {
				compileContext.assignTypes(_parameterScope, typeDeclarator);
				if (typeDeclarator.deferAnalysis())
					return Callable.DEFER;
				if (typeDeclarator.type == null)
					typeDeclarator.print(0);
				if (typeDeclarator.type.family() == TypeFamily.FUNCTION)
					t = typeDeclarator.type;
				else
					t = typeDeclarator.unwrapTypedef(Operator.CLASS, compileContext);
				if (typeDeclarator.deferAnalysis())
					return Callable.DEFER;
			}
			if (parameter == _parameterScope.parameters().length() - 1 && _parameterScope.hasEllipsis()) {
				// in this case t is a vector type
				// Check for the special case that the argument has type t
				if (!processingEllipsis && 
					arguments.node.type.equals(t))
					return Callable.YES;
				// okay, we need to actually check the element type
				t = t.elementType();
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

	public string rpcMethod() {
		return name() + "-" + type().signature();
	}

	/**
	 * Evaluate which of a pair of methods are a 'better fit' to the
	 * given argument list.
	 *
	 * @return -1 if other is a better fit to the argument list, or
	 * 0 if they are equally a good fit to the argument list, or
	 * 1 if this is a better fit than other. The 'better fit' criteria
	 * are reflexive, that is switching this with other reverses the sign of 
	 * the return value.
	 */
	public int partialOrder(ref<Symbol> other, ref<NodeList> arguments, ref<CompileContext> compileContext) {
		ref<OverloadInstance> oiOther = ref<OverloadInstance>(other);

		int parameter = 0;
		int bias = 0;
		while (parameter < _parameterScope.parameters().length()) {
			ref<Symbol> symThis = (*_parameterScope.parameters())[parameter];
			if (parameter >= oiOther._parameterScope.parameters().length())
				return bias; 
			ref<Symbol> symOther = (*oiOther._parameterScope.parameters())[parameter];
			ref<Type> typeThis = symThis.assignType(compileContext);
			if (symOther == null) {
				print(0, false);
				other.print(0, false);
			}
			ref<Type> typeOther = symOther.assignType(compileContext);
			if (!typeThis.equals(typeOther)) {
				if (typeThis.widensTo(typeOther, compileContext)) {
					if (typeOther.widensTo(typeThis, compileContext)) {
						// mutually convertible. prefer an exact match.
						ref<Node> arg = nthArgument(arguments, parameter);

						if (arg != null && arg.type != null) {
							if (arg.type.equals(typeThis)) {
								if (bias < 0)
									return 0;
								bias = 1;
							} else if (arg.type.equals(typeOther)) {
								if (bias > 0)
									return 0;
								bias = -1;
							}
						}
					} else {
						if (bias < 0)
							return 0;
						bias = 1;
					}
				} else if (typeOther.widensTo(typeThis, compileContext)) {
					if (bias > 0)
						return 0;
					bias = -1;
				}
			}
			parameter++;
		}
		if (parameter < oiOther._parameterScope.parameters().length()) {
		}
		return bias;
	}

	private ref<Node> nthArgument(ref<NodeList> arguments, int parameter) {
		while (arguments != null) {
			if (parameter == 0)
				return arguments.node;
			parameter--;
			arguments = arguments.next;
		}
		return null;
	}

	public ref<Type> instantiateTemplate(ref<Call> declaration, ref<CompileContext> compileContext) {
		var[] argValues;

		boolean success = true;
		for (ref<NodeList> nl = declaration.arguments(); nl != null; nl = nl.next) {
			if (nl.node.type.family() != TypeFamily.TYPEDEF) {
				nl.node.add(MessageId.UNFINISHED_INSTANTIATE_TEMPLATE, compileContext.pool());
				success = false;
				continue;
			}
			ref<TypedefType> t = ref<TypedefType>(nl.node.type);
			if (t.wrappedType().family() == TypeFamily.TEMPLATE) {
				nl.node.add(MessageId.TEMPLATE_NAME_DISALLOWED, compileContext.pool());
				success = false;
				continue;
			}
			var v = t.wrappedType();
			argValues.append(v);
		}
		if (success)
			return instantiateTemplate(argValues, compileContext);
		else
			return compileContext.errorType();
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
		if (baseMethod.name() != _name)
			return false;
		// either they must both have ellipsis, or neither
		if (_parameterScope.parameters().length() != baseMethod._parameterScope.parameters().length())
			return false;
		for (int i = 0; i < _parameterScope.parameters().length(); i++) {
			ref<Symbol> basePar = (*baseMethod._parameterScope.parameters())[i];
			ref<Symbol> par = (*_parameterScope.parameters())[i];
			if (basePar.type() == null) {
				print(0, false);
				baseMethod.print(0, true);
				printf("par type is %p basePar type is %p\n", par.type(), basePar.type());
			}
//			printf("par type is %s basePar type is %s\n", par.type().signature(), basePar.type().signature());
			if (par.type() == null)
				return false;
			if (!par.type().equals(basePar.type()))
				return false;
		}

		// TODO: Validate correct override return types.  Must be equal, or if not, they must
		// satisfy 'co-variance', that is the return type must be an address with a type that widens
		// from the overriding method to the overridden method.
		return true;
	}

	public boolean overrideMethod() {
		if (_final)
			return false;
		_overridden = true;
		return true;
	}

	public boolean isConcrete(ref<CompileContext> compileContext) {
		assignType(compileContext);
		if (_type == null) {
			print(0, false);
		}
		if (_type.family() != TypeFamily.FUNCTION)
			return true;
		ref<FunctionType> ft = ref<FunctionType>(_type);
		if (ft.scope() == null || ft.scope().definition() == null || ft.scope().definition().op() != Operator.FUNCTION)
			return true;
		ref<FunctionDeclaration> func = ref<FunctionDeclaration>(ft.scope().definition());
		if (func.functionCategory() != FunctionDeclaration.Category.ABSTRACT)
			return true;
		return false;
	}

	public ref<ParameterScope> parameterScope() {
		return _parameterScope;
	}

	public boolean overridden() {
		return _overridden;
	}

	public boolean isFinal() {
		return _final;
	}

	protected ref<TemplateInstanceType> instantiateTemplate(var[] arguments, ref<CompileContext> compileContext) {
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
		assert(arguments.length() == _parameterScope.parameterCount());
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
		definition.classDef.scope = instanceBodyScope;
		compileContext.buildScopes();
		ref<TemplateInstanceType> result = compileContext.newTemplateInstanceType(templateType, arguments, definition, templateType.definingFile(), instanceBodyScope, _instances);
		instanceBodyScope.classType = result;
		_instances = result;
		return result;
	}
}

public class Symbol {
	public long offset;				// Variable offset within scope block
	public address segment;			// Variable segment, for static variables used by code generators
	public address value;			// Scratch address for use by code generators.
	protected substring _name;
	protected ref<Type> _type;
	protected ref<Scope> _enclosing;
	private ref<Call>[Annotations] _annotations;
	private ref<Node> _annotationNode;

	ref<Doclet> _doclet;			// Doclet used for this symbol.
	
	private boolean _inProgress;
	private ref<Node> _definition;
	private StorageClass _storageClass;
	private Operator _visibility;

	protected Symbol(Operator visibility, StorageClass storageClass, ref<Scope> enclosing, ref<Node> annotations, ref<MemoryPool> pool, substring name, ref<Node> definition) {
		_visibility = visibility;
		if (annotations != null) {
			_annotations.resize(Annotations.MAX_ANNOTATION, pool);
			populateAnnotations(annotations, pool);
			_annotationNode = annotations;
		}
		_storageClass = storageClass;
		_enclosing = enclosing;
		_name = name;
		_definition = definition;
		if (_definition != null)
			_type = _definition.type;
	}

	public void printSimple() {
		print(0, false);
	}

	public abstract void print(int indent, boolean printChildScopes);

	protected void printAnnotations(int indent) {
		if (_annotationNode != null) {
			for (i in _annotations) {
				if (_annotations[i] != null) {
					printf("%*.*c[Annotation %s]\n", indent, indent, ' ', string(i));
					_annotations[i].print(indent + INDENT);
				}
			}
		}
	}
	
	public ref<Type> assignType(ref<CompileContext> compileContext) {
		if (_type == null) {
//			printf("assignType()\n");
//			print(4, false);
			if (_inProgress) {
				_definition.add(MessageId.CIRCULAR_DEFINITION, compileContext.pool(), _name);
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

	public void markAsReferenced(ref<CompileContext> compileContext) {
	}
	
	public int parameterCount() {
		assert(false);
		return 0;
	}

	public TypeFamily effectiveFamily() {
		if (_annotationNode == null)
			return TypeFamily.CLASS;
		if (_annotations[Annotations.SHAPE] != null)
			return TypeFamily.SHAPE;
		else if (_annotations[Annotations.POINTER] != null)
			return TypeFamily.POINTER;
		else if (_annotations[Annotations.REF] != null)
			return TypeFamily.REF;
		else
			return TypeFamily.CLASS;
	}
	
	public ref<Call> getAnnotation(string name) {
		if (_annotationNode == null)
			return null;
		return _annotations[Annotations.byName(name)];
	}
	
	private void populateAnnotations(ref<Node> annotations, ref<MemoryPool> pool) {
		if (annotations.op() == Operator.SEQUENCE) {
			ref<Binary> b = ref<Binary>(annotations);
			populateAnnotations(b.left(), pool);
			populateAnnotations(b.right(), pool);
		} else {
			ref<Call> b = ref<Call>(annotations);
			ref<Identifier> id = ref<Identifier>(b.target());
			Annotations a = Annotations.byName(id.identifier());
			if (a == Annotations.ERROR)
				annotations.add(MessageId.UNRECOGNIZED_ANNOTATION, pool, id.identifier());
			else if (_annotations[a] != null)
				annotations.add(MessageId.DISALLOWED_ANNOTATION, pool, id.identifier());

				_annotations[a] = b;
		}
	}

	public boolean isVisibleIn(ref<Scope> lexicalScope, ref<CompileContext> compileContext) {
		if (_enclosing.encloses(lexicalScope))
			return true;
		switch (_visibility) {
		case PRIVATE:
			return false;

		case PROTECTED:
			ref<Scope> lexicalClassScope = lexicalScope.enclosingClassScope();
			if (lexicalClassScope == null)
				return false;
			if (!_enclosing.isBaseScope(lexicalClassScope, compileContext))
				return false;
			break;

		case NAMESPACE:
			if (_enclosing.getNamespace() != lexicalScope.getNamespace())
				return false;
		}
		return true;
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
	public Callable callableWith(ref<NodeList> arguments, ref<CompileContext> compileContext) {
		assert(false);
		return Callable.NO;
	}
	/**
	 * Determines which symbol better matches the given argument list (this vs. other).
	 *
	 * 
	 * @return < 0 this less good than other<br>
	 * == 0 this neither better nor worse than other<br>
	 * > 0 this better than other
	 */
	public int partialOrder(ref<Symbol> other, ref<NodeList> arguments, ref<CompileContext> compileContext) {
		assert(false);
		return 0;
	}

	public void add(MessageId messageId, ref<MemoryPool> pool, substring... args) {
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
		assignType(compileContext);
		if (deferAnalysis())
			return null;
		if (_type.family() != TypeFamily.TYPEDEF) {
			_definition.add(MessageId.NOT_A_TYPE, compileContext.pool());
			return null;
		}
		ref<TypedefType> typedefType = ref<TypedefType>(_type);
		ref<BuiltInType> bt = compileContext.builtInType(family);
		bt.setClassType(typedefType.wrappedType());
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

	protected void validateAnnotations(ref<CompileContext> compileContext) {
		if (_annotationNode == null)
			return;
		ref<Call> annotation = _annotations[Annotations.CONSTANT];
		if (annotation != null)
			_definition.add(MessageId.CONSTANT_NOT_ALLOWED, compileContext.pool());
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

	public substring name() {
		return _name;
	}

	public ref<Node> definition() {
		return _definition;
	}
	
	public Access accessFlags() {
		return Access.CONSTRUCTED;
	}

	public boolean configureDefaultConstructors() {
		return false;
	}
	/**
	 * returns true if this symbol is initialized via a constructor call, and false if not.
	 */
	public boolean initializedWithConstructor() {
		return false;
	}

	public boolean isEnumClass() {
		return false;
	}

	public boolean isMutable() {
		assert(_type != null);
		if (accessFlags() & Access.CONSTANT)
			return false;
		if (_type.family() == TypeFamily.TYPEDEF)
			return false;
		return true;
	}

	public boolean isFullyAnalyzed() {
		return _type != null;
	}
	
	public ref<Scope> enclosing() {
		return _enclosing;
	}

	public ref<Namespace> enclosingNamespace() {
		return _enclosing.getNamespace();
	}

	public ref<UnitScope> enclosingUnit() {
		return _enclosing.enclosingUnit();
	}

	public ref<ClasslikeScope> enclosingClassScope() {
		return _enclosing.enclosingClassScope();
	}

	public ref<Type> type() {
		return _type;
	}

	public Operator visibility() {
		return _visibility;
	}

	public ref<ref<Call>[Annotations]> annotations() {
		if (_annotationNode == null)
			return null;
		else
			return &_annotations;
	}
	
	public ref<Node> annotationNode() {
		return _annotationNode;
	}
	
	public int compare(ref<Symbol> other) {
		int min = _name.length();
		if (other._name.length() < min)
			min = other._name.length();
		for (int i = 0; i < min; i++) {
			int diff = _name.c_str()[i].toLowerCase() - other._name.c_str()[i].toLowerCase();
			if (diff != 0)
				return diff;
		}
		if (_name.length() < other._name.length())
			return -1;
		else if (_name.length() == other._name.length())
			return 0;
		else
			return 1;
	}

	public ref<Doclet> doclet() {
		return _doclet;
	}
}
