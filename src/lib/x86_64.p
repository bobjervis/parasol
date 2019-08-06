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
/**
 * This namespace provides code generation facilities for both Windows and Linux running on an Intel x86-64
 * machine instruction set.
 */
namespace parasol:x86_64;

import native:windows;
import native:linux;

import parasol:compiler;
import parasol:compiler.Access;
import parasol:compiler.Arena;
import parasol:compiler.Binary;
import parasol:compiler.Block;
import parasol:compiler.Call;
import parasol:compiler.CallCategory;
import parasol:compiler.Class;
import parasol:compiler.ClassScope;
import parasol:compiler.ClassType;
import parasol:compiler.CompileContext;
import parasol:compiler.CompileString;
import parasol:compiler.Constant;
import parasol:compiler.DestructorList;
import parasol:compiler.EnumInstanceType;
import parasol:compiler.EnumScope;
import parasol:compiler.EllipsisArguments;
import parasol:compiler.FileStat;
import parasol:compiler.FlagsInstanceType;
import parasol:compiler.For;
import parasol:compiler.FunctionDeclaration;
import parasol:compiler.FunctionType;
import parasol:compiler.GatherCasesClosure;
import parasol:compiler.Identifier;
import parasol:compiler.InterfaceImplementationScope;
import parasol:compiler.InterfaceType;
import parasol:compiler.InternalLiteral;
import parasol:compiler.Jump;
import parasol:compiler.Location;
import parasol:compiler.LockScope;
import parasol:compiler.Loop;
import parasol:compiler.MessageId;
import parasol:compiler.Node;
import parasol:compiler.NodeList;
import parasol:compiler.Operator;
import parasol:compiler.Overload;
import parasol:compiler.OverloadInstance;
import parasol:compiler.ParameterScope;
import parasol:compiler.PlainSymbol;
import parasol:compiler.PUSH_OUT_PARAMETER;
import parasol:compiler.Reference;
import parasol:compiler.Return;
import parasol:compiler.Scope;
import parasol:compiler.Selection;
import parasol:compiler.StackArgumentAddress;
import parasol:compiler.StorageClass;
import parasol:compiler.Symbol;
import parasol:compiler.Target;
import parasol:compiler.TemplateInstanceType;
import parasol:compiler.Ternary;
import parasol:compiler.Test;
import parasol:compiler.ThunkScope;
import parasol:compiler.TraverseAction;
import parasol:compiler.Try;
import parasol:compiler.Type;
import parasol:compiler.TypedefType;
import parasol:compiler.TypeFamily;
import parasol:compiler.Unary;
import parasol:compiler.USE_COMPARE_METHOD;
import parasol:compiler.Variable;
import parasol:exception;
import parasol:pxi.Pxi;
import parasol:runtime;
import parasol:storage;
import native:C;

/*
 * These are combined to produce the necessary instruction encodings.
 */
byte REX_W = 0x48;
byte REX_R = 0x44;
byte REX_X = 0x42;
byte REX_B = 0x41;

/*
 * Flags for the Node.nodeFlags field. (0x1f are reserved for non-codegen flags)
 */
byte ADDRESS_MODE = 0x80;

long PXI_FIXUP = 0xff;
byte PXI_FIXUP_RELATIVE32 = 0x01;
byte PXI_FIXUP_ABSOLUTE64 = 0x02;
byte PXI_FIXUP_ABSOLUTE64_CODE = 0x03;
byte PXI_FIXUP_MAX = 0x04;
int PXI_FIXUP_SHIFT = 8;

public class X86_64Lnx extends X86_64 {
	public X86_64Lnx(ref<Arena> arena, boolean verbose) {
		super(arena, verbose);
	}
	
	static R[] fastArgs = [ R.RDI, R.RSI, R.RDX, R.RCX, R.R8, R.R9 ];

	static R[] floatArgs = [ R.XMM0, R.XMM1, R.XMM2, R.XMM3, R.XMM4, R.XMM5, R.XMM6, R.XMM7 ];
	
	public byte registerValue(int registerArgumentIndex, TypeFamily family) {
		switch (family) {
		case	FLOAT_32:
		case	FLOAT_64:
			if (registerArgumentIndex < floatArgs.length())
				return byte(floatArgs[registerArgumentIndex]);
			break;

		default:
			if (registerArgumentIndex < fastArgs.length())
				return byte(fastArgs[registerArgumentIndex]);
		}
		return 0;
	}

	public void assignRegisterArguments(int hiddenParams, ref<NodeList> params, ref<CompileContext> compileContext) {
		int registerArgumentIndex = hiddenParams;
		int floatRegisterArgumentIndex = 0;
		for (; params != null; params = params.next) {
			if (params.node.type.passesViaStack(compileContext))
				continue;
			
			byte nextReg;
			switch (params.node.type.family()) {
			case	FLOAT_32:
			case	FLOAT_64:
				nextReg = registerValue(floatRegisterArgumentIndex, params.node.type.family());
				if (nextReg > 0)
					floatRegisterArgumentIndex++;
				break;
				
			default:
				nextReg = registerValue(registerArgumentIndex, params.node.type.family());
				if (nextReg > 0)
					registerArgumentIndex++;
			}
			
			if (nextReg > 0)
				params.node.register = nextReg;
		}
	}

	public R firstRegisterArgument() {
		return R.RDI;
	}
	
	public R secondRegisterArgument() {
		return R.RSI;
	}
	
	public R thirdRegisterArgument() {
		return R.RDX;
	}
	
	public R fourthRegisterArgument() {
		return R.RCX;
	}
	
	public R thisRegister() {
		return R.RBX;
	}
	
	public long longMask() {
		return RAXmask|RCXmask|RDXmask|R8mask|R9mask|RSImask|RDImask|R10mask|R11mask;			// RBX, R12, R13, R14, R15, RBP and RSP are reserved
	}
	
	public runtime.Target sectionType() {
		return runtime.Target.X86_64_LNX;
	}

	public int, boolean run(string[] args) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			printf("Running Linux target in Windows\n");
			return 0, false;
		}
		return super.run(args);
	}
}

public class X86_64Win extends X86_64 {
	public X86_64Win(ref<Arena> arena, boolean verbose) {
		super(arena, verbose);
	}
	
	static R[] fastArgs = [ R.RCX, R.RDX, R.R8, R.R9 ];

	static R[] floatArgs = [ R.XMM0, R.XMM1, R.XMM2, R.XMM3 ];
	
	public byte registerValue(int registerArgumentIndex, TypeFamily family) {
		if (registerArgumentIndex < fastArgs.length()) {
			switch (family) {
			case	FLOAT_32:
			case	FLOAT_64:
				return byte(floatArgs[registerArgumentIndex]);

			default:
				return byte(fastArgs[registerArgumentIndex]);
			}
			return byte(fastArgs[registerArgumentIndex]);
		}
		else
			return 0;
	}

	public void assignRegisterArguments(int hiddenParams, ref<NodeList> params, ref<CompileContext> compileContext) {
		int registerArgumentIndex = hiddenParams;
		for (; params != null; params = params.next) {
			byte nextReg = registerValue(registerArgumentIndex, params.node.type.family());
			
			if (nextReg > 0 && !params.node.type.passesViaStack(compileContext)) {
				params.node.register = nextReg;
				registerArgumentIndex++;
			}
		}
	}

	public R firstRegisterArgument() {
		return R.RCX;
	}
	
	public R secondRegisterArgument() {
		return R.RDX;
	}
	
	public R thirdRegisterArgument() {
		return R.R8;
	}
	
	public R fourthRegisterArgument() {
		return R.R9;
	}
	
	public R thisRegister() {
		return R.RSI;
	}
	
	public long longMask() {
		return RAXmask|RCXmask|RDXmask|R8mask|R9mask|R10mask|R11mask;			// RBP and RSP are reserved
	}

	public runtime.Target sectionType() {
		return runtime.Target.X86_64_WIN;
	}

	public int, boolean run(string[] args) {
		if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			printf("Running windows target in Linux\n");
			return 0, false;
		}
		return super.run(args);
	}
}

public class X86_64 extends X86_64AssignTemps {
	private ref<Scope> _unitScope;
	private ref<ParameterScope> _alloc;						// Symbol for alloc function.
	private ref<ParameterScope> _free;						// Symbol for free function.
	private ref<OverloadInstance> _stringAppendString;		// string.append(string)
	private ref<OverloadInstance> _stringCopyConstructor;
	private ref<OverloadInstance> _stringAssign;
	private ref<OverloadInstance> _stringCompare;
	private ref<OverloadInstance> _varCopyConstructor;
	private ref<ParameterScope> _memset;
	private ref<ParameterScope> _memcpy;
	private ref<ParameterScope> _takeMethod;
	private ref<ParameterScope> _releaseMethod;
	
	private ref<Symbol> _floatSignMask;
	private ref<Symbol> _floatOne;
	private ref<Symbol> _floatZero;
	private ref<Symbol> _doubleSignMask;
	private ref<Symbol> _doubleOne;
	private ref<Symbol> _doubleZero;
	
	public int maxTypeOrdinal;
	private boolean _verbose;
	private int _stackLocalVariables;

	public X86_64(ref<Arena> arena, boolean verbose) {
		_arena = arena;
		_verbose = verbose;
	}

	public boolean verbose() {
		return _verbose;
	}

	boolean generateCode(ref<FileStat> mainFile, ref<CompileContext> compileContext) {
		cacheCodegenObjects(compileContext);
		ref<Block> unit = mainFile.tree().root();
//		printf("unit = %p\n", unit);
		_unitScope = new Scope(_arena.root(), unit, compileContext.blockStorageClass(), unit.className());
		maxTypeOrdinal = 1;
		// This may have to be postponed until we get some data on register usage.
		for (int i = 0; i < _arena.scopes().length(); i++) {
			ref<Scope> scope = (*_arena.scopes())[i];
			switch (scope.storageClass()) {
			case	TEMPLATE:
			case	AUTO:
			case	PARAMETER:
				break;
				
			default:
				scope.assignVariableStorage(this, compileContext);
			}
		}
		for (int i = 0; i < compileContext.staticSymbols().length(); i++) {
			ref<PlainSymbol> symbol = (*compileContext.staticSymbols())[i];
			assignStaticSymbolStorage(symbol, compileContext);
		}
		if (_verbose)
			printf("Variable storage assigned\n");
		return super.generateCode(mainFile, compileContext);
	}
	
	public void writePxi(ref<Pxi> output) {
		ref<X86_64WinSection> s = new X86_64WinSection(this);
		output.declareSection(s);
	}
	
	public int, boolean run(string[] args) {
		pointer<byte>[] runArgs;
		for (int i = 1; i < args.length(); i++)
			runArgs.append(args[i].c_str());
		int returnValue;
		pointer<address> pa = pointer<address>(&_staticMemory[_pxiHeader.builtInOffset]);
		pointer<runtime.SourceLocation> outerSource = runtime.sourceLocations();
		int outerSourceCount = runtime.sourceLocationsCount();
		if (runtime.makeRegionExecutable(_staticMemory, _staticMemoryLength)) {
			pointer<int> pxiFixups = pointer<int>(&_staticMemory[_pxiHeader.relocationOffset]);
			pointer<long> vp;
			for (int i = 0; i < _pxiHeader.relocationCount; i++) {
				vp = pointer<long>(_staticMemory + pxiFixups[i]);
				*vp += long(address(_staticMemory));
			}
			vp = pointer<long>(_staticMemory + _pxiHeader.vtablesOffset);
			for (int i = 0; i < _pxiHeader.vtableData; i++, vp++)
				*vp += long(address(_staticMemory));
			pointer<NativeBinding> nativeBindings = pointer<NativeBinding>(_staticMemory + _pxiHeader.nativeBindingsOffset);
			for (int i = 0; i < _pxiHeader.nativeBindingsCount; i++) {
				if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
					windows.HMODULE dll = windows.GetModuleHandle(nativeBindings[i].dllName);
					if (dll == null) {
						dll = windows.LoadLibrary(nativeBindings[i].dllName);
						if (dll == null) {
							string d(nativeBindings[i].dllName);
							printf("Unable to locate DLL %s\n", d);
							assert(false);
						}
					}
					nativeBindings[i].functionAddress = windows.GetProcAddress(dll, nativeBindings[i].symbolName);
				} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
					string soName(nativeBindings[i].dllName);
					if (soName == "libparasol.so.1") {
						soName = "libparasol.so";
					}
					address handle = linux.dlopen(soName.c_str(), linux.RTLD_LAZY);
					if (handle == null) {
						printf("Unable to locate shared object %s (%s)\n", soName, linux.dlerror());
						assert(false);
					} else
						nativeBindings[i].functionAddress = linux.dlsym(handle, nativeBindings[i].symbolName);
//					linux.dlclose(handle);
				}
				if (nativeBindings[i].functionAddress == null) {
					string d(nativeBindings[i].dllName);
					string s(nativeBindings[i].symbolName);
					printf("Unable to locate symbol %s in %s\n", s, d);
					assert(false);
				}
			}
			runtime.setSourceLocations(&_sourceLocations[0], _sourceLocations.length());
			returnValue = runtime.eval(&_pxiHeader, _staticMemory, 0, &runArgs[0], runArgs.length());
		} else {
			pointer<byte> generatedCode = pointer<byte>(runtime.allocateRegion(_staticMemoryLength));
			C.memcpy(generatedCode, _staticMemory, _staticMemoryLength);
			pointer<int> pxiFixups = pointer<int>(&generatedCode[_pxiHeader.relocationOffset]);
			pointer<long> vp;
			for (int i = 0; i < _pxiHeader.relocationCount; i++) {
				vp = pointer<long>(generatedCode + pxiFixups[i]);
				*vp += long(address(generatedCode));
			}
			vp = pointer<long>(generatedCode + _pxiHeader.vtablesOffset);
			for (int i = 0; i < _pxiHeader.vtableData; i++, vp++)
				*vp += long(address(generatedCode));
			pointer<NativeBinding> nativeBindings = pointer<NativeBinding>(generatedCode + _pxiHeader.nativeBindingsOffset);
			for (int i = 0; i < _pxiHeader.nativeBindingsCount; i++) {
				if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
					windows.HMODULE dll = windows.GetModuleHandle(nativeBindings[i].dllName);
					if (dll == null) {
						dll = windows.LoadLibrary(nativeBindings[i].dllName);
						if (dll == null) {
							string d(nativeBindings[i].dllName);
							printf("Unable to locate DLL %s\n", d);
							assert(false);
						}
					}
					nativeBindings[i].functionAddress = windows.GetProcAddress(dll, nativeBindings[i].symbolName);
				} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
					address handle = linux.dlopen(nativeBindings[i].dllName, linux.RTLD_LAZY);
					if (handle == null) {
						printf("Unable to locate shared object %s (%s)\n", nativeBindings[i].dllName, linux.dlerror());
						assert(false);
					} else
						nativeBindings[i].functionAddress = linux.dlsym(handle, nativeBindings[i].symbolName);
					linux.dlclose(handle);
				}
				if (nativeBindings[i].functionAddress == null) {
					string d(nativeBindings[i].dllName);
					string s(nativeBindings[i].symbolName);
					printf("Unable to locate symbol %s in %s\n", s, d);
					assert(false);
				}
			}
			if (runtime.makeRegionExecutable(generatedCode, _staticMemoryLength)) {
				runtime.setSourceLocations(&_sourceLocations[0], _sourceLocations.length());
				returnValue = runtime.eval(&_pxiHeader, generatedCode, 0, &runArgs[0], runArgs.length());
			} else {
				assert(false);
				return 0, false;
			}
		}
		runtime.setSourceLocations(outerSource, outerSourceCount);
		if (exception.fetchExposedException() == null)
			return returnValue, true;
		else
			return 0, false;
	}

	public ref<ParameterScope>, boolean getFunctionAddress(ref<ParameterScope> functionScope, ref<CompileContext> compileContext) {
		ref<FunctionDeclaration> func = ref<FunctionDeclaration>(functionScope.definition());
		if (func == null) {
			if (functionScope.value == null) {
				functionScope.value = address(-1);
				functionScope.value = address(1 + generateFunction(functionScope, compileContext));
			}
			return functionScope, false;
		}
		if (functionScope.value != null) {
			if (func.functionCategory() == FunctionDeclaration.Category.ABSTRACT &&
				functionScope.enclosing().storageClass() == StorageClass.STATIC)
				return functionScope, true;
			else
				return functionScope, false;
		} else {
			if (func.functionCategory() == FunctionDeclaration.Category.ABSTRACT) {
				if (functionScope.enclosing().storageClass() == StorageClass.STATIC) {
					ref<Symbol> fsym = func.name().symbol();
					ref<Call> binding;
					switch (sectionType()) {
					case X86_64_LNX:
						binding = fsym.getAnnotation("Linux");
						break;
						
					case X86_64_WIN:
						binding = fsym.getAnnotation("Windows");
						break;
						
					default:
						binding = null;
					}
					if (binding != null) {
						ref<NodeList> args = binding.arguments();
						if (args == null || args.next == null || args.next.next != null) {
							binding.add(sectionType() == runtime.Target.X86_64_WIN ? MessageId.BAD_WINDOWS_BINDING : MessageId.BAD_LINUX_BINDING, compileContext.pool());
							return null, false;
						}
						ref<Node> dll = args.node;
						ref<Node> symbol = args.next.node;
						if (dll.op() != Operator.STRING || symbol.op() != Operator.STRING) {
							binding.add(sectionType() == runtime.Target.X86_64_WIN ? MessageId.BAD_WINDOWS_BINDING : MessageId.BAD_LINUX_BINDING, compileContext.pool());
							return null, false;
						}
						CompileString dllName = ref<Constant>(dll).value();
						CompileString symbolName = ref<Constant>(symbol).value();
						int dllNameOffset = _segments[Segments.BUILT_INS_TEXT].reserve(dllName.length + 1);
						int symbolNameOffset = _segments[Segments.BUILT_INS_TEXT].reserve(symbolName.length + 1);
						C.memcpy(_segments[Segments.BUILT_INS_TEXT].at(dllNameOffset), dllName.data, dllName.length);
						C.memcpy(_segments[Segments.BUILT_INS_TEXT].at(symbolNameOffset), symbolName.data, symbolName.length);
						int offset = _segments[Segments.NATIVE_BINDINGS].reserve(NativeBinding.bytes);
						_segments[Segments.NATIVE_BINDINGS].fixup(Segments.BUILT_INS_TEXT, offset, true);
						_segments[Segments.NATIVE_BINDINGS].fixup(Segments.BUILT_INS_TEXT, offset + address.bytes, true);
						C.memcpy(_segments[Segments.NATIVE_BINDINGS].at(offset), &dllNameOffset, int.bytes);
						C.memcpy(_segments[Segments.NATIVE_BINDINGS].at(offset + address.bytes), &symbolNameOffset, int.bytes);
						address v = address(long(offset + 2 * address.bytes));
						fsym.value = v;
						fsym.offset = offset + 2 * address.bytes;
						_nativeBindingSymbols.append(fsym);
						functionScope.value = v;
						functionScope.nativeBinding = true;
						return functionScope, true;
					}
					func.add(MessageId.UNDEFINED_BUILT_IN, compileContext.pool(), func.name().value());
					return null, false;
				} else
					return null, false;
			} else {
				functionScope.value = address(-1);
				functionScope.value = address(1 + generateFunction(functionScope, compileContext));
			}
			if (func.name() != null)
				func.name().symbol().value = functionScope.value;
			return functionScope, false;
		}
	}

	public void generateFunctionCore(ref<Scope> scope, ref<CompileContext> compileContext) {
		// Sketch of the code generator:
		// 1 optimization, tree clean up and all tree-level rewrites.
		// 2 block decomposition (partial flattening of control-flow)
		// 3 register allocation
		// 4 instruction selection
		// 5 jump clean-up
		// 6 instruction ordering
		// 7 coding
		ref<Block> node;
		if (scope.class <= ParameterScope) {
			ref<ParameterScope> parameterScope = ref<ParameterScope>(scope);

			ref<FunctionDeclaration> func = ref<FunctionDeclaration>(scope.definition());
			if (func == null) {
				switch (parameterScope.kind()) {
				case	DEFAULT_CONSTRUCTOR:
					inst(X86.PUSH, TypeFamily.SIGNED_64, thisRegister());
					inst(X86.MOV, TypeFamily.ADDRESS, thisRegister(), firstRegisterArgument());
					generateConstructorPreamble(null, parameterScope, compileContext);
					inst(X86.POP, TypeFamily.SIGNED_64, thisRegister());
					if (!generateReturn(parameterScope, compileContext))
						assert(false);
					break;
					
				case	IMPLIED_DESTRUCTOR:
					if (generateInterfaceDestructorThunk(parameterScope, compileContext))
						break;
					if (needsDestructorShutdown(parameterScope, compileContext)) { 
						inst(X86.PUSH, TypeFamily.SIGNED_64, thisRegister());
						inst(X86.MOV, TypeFamily.ADDRESS, thisRegister(), firstRegisterArgument());
						generateDestructorShutdown(parameterScope, compileContext);
						inst(X86.POP, TypeFamily.SIGNED_64, thisRegister());
					}
					if (!generateReturn(parameterScope, compileContext))
						assert(false);
					break;
					
				case	ENUM_TO_STRING:
					ref<EnumScope> enclosing = ref<EnumScope>(scope.enclosing());
					
					ref<ref<Symbol>[]> instances = enclosing.instances();
					R indexRegister = firstRegisterArgument();
					switch (enclosing.enumType.instanceFamily()) {
					case UNSIGNED_8:
						if ((getRegMask(firstRegisterArgument()) & byteMask) != 0) {
							indexRegister = R.RDX;
							inst(X86.MOVZX_8, TypeFamily.UNSIGNED_32, indexRegister, firstRegisterArgument());
						}
						inst(X86.MOVZX_8, TypeFamily.UNSIGNED_64, indexRegister, indexRegister);
						inst(X86.SAL, TypeFamily.SIGNED_64, indexRegister, 3);
						break;
						
					case UNSIGNED_16:
						inst(X86.MOVZX, TypeFamily.UNSIGNED_64, indexRegister, indexRegister);
						inst(X86.SAL, TypeFamily.SIGNED_64, indexRegister, 3);
						break;
						
					case UNSIGNED_32:
						inst(X86.SAL, TypeFamily.SIGNED_64, indexRegister, 32);
						inst(X86.SAR, TypeFamily.UNSIGNED_64, indexRegister, 29);
					}
					ref<Symbol> stringArray;
					if (parameterScope.symbolCount() == 0) {
						string nm = "*";
						stringArray = parameterScope.define(Operator.PRIVATE, StorageClass.STATIC, null, nm, compileContext.arena().builtInType(TypeFamily.ADDRESS), null, compileContext.pool());
						assignStaticRegion(stringArray, string.bytes, instances.length() * string.bytes);
						for (int i = 0; i < instances.length(); i++) {
							int offset = addStringLiteral((*instances)[i].name().asString());
							fixup(FixupKind.ABSOLUTE64_STRING, stringArray, i * address.bytes, address(offset));
						}
					} else
						stringArray = parameterScope.lookup("*", compileContext);
					inst(X86.LEA, R.RAX, stringArray);
					inst(X86.MOV, R.RAX, indexRegister, R.RAX);
					if (!generateReturn(parameterScope, compileContext))
						assert(false);
					break;
					
				case	THUNK:
					ref<ThunkScope> thunk = ref<ThunkScope>(parameterScope);
					if (thunk.isDestructor()) {
						if (thunk.func() == null) {
							inst(X86.LEA, R.RAX, R.RDI, -thunk.thunkOffset());
						} else {
							if (thunk.thunkOffset() > 0)
								inst(X86.SUB, TypeFamily.ADDRESS, firstRegisterArgument(), thunk.thunkOffset());
							inst(X86.PUSH, TypeFamily.ADDRESS, R.RDI);
							instCall(thunk.func(), compileContext);
							inst(X86.POP, TypeFamily.ADDRESS, R.RAX);
						}
						inst(X86.RET);
					} else {
						if (thunk.func() == null)
							inst(X86.RET);
						else {
							inst(X86.SUB, TypeFamily.ADDRESS, firstRegisterArgument(), thunk.thunkOffset());
							instJump(thunk.func(), compileContext);
						}
					}
					break;
					
				default:
					assert(false);
				}
				return;
			}
			if (parameterScope.type() == null) {
				// TODO add throw
				return;
			}
			node = func.body;
			if (node == null) {
				func.print(0);
				assert(false);
			} else {
				int initialVariableCount = compileContext.variableCount();
				ref<FileStat> file = scope.file();
				
				// For template functions, this assigns any missing types info:
				
				if (node.type == null) {
					compileContext.assignTypes(parameterScope, node);
					if (node.type == null) {
						parameterScope.printStatus();
						node.print(0);
						assert(false);
					}
				}
				
				// All function/method body folding is done here:
				
				if (verbose()) {
					printf("=====  folding %s:%s  =========\n", file.filename(), func.name() != null ? func.name().identifier().asString() : "<anonymous>");
				}
				node = ref<Block>(compileContext.fold(node, file));
				allocateStackForLocalVariables(compileContext);
				
				if (func.functionCategory() == FunctionDeclaration.Category.CONSTRUCTOR)
					generateConstructorPreamble(node, parameterScope, compileContext);
	
				ref<Scope> outer = compileContext.setCurrent(scope);
				generate(node, compileContext);
				compileContext.setCurrent(outer);
				compileContext.resetVariables(initialVariableCount);
				_stackLocalVariables = initialVariableCount;
				if (func.functionCategory() == FunctionDeclaration.Category.DESTRUCTOR)
					generateDestructorShutdown(parameterScope, compileContext);
			}
			closeCodeSegment(CC.NOP, null);
			insertPreamble();
			if (node != null)
				emitSourceLocation(parameterScope.file(), node.location());
			inst(X86.ENTER, 0);
			int registerArgs = 0;
			if (parameterScope.hasThis()) {
				inst(X86.PUSH, TypeFamily.SIGNED_64, thisRegister());
				inst(X86.MOV, TypeFamily.ADDRESS, thisRegister(), firstRegisterArgument());
				registerArgs++;
			}
			if (parameterScope.hasOutParameter(compileContext)) {
				inst(X86.PUSH, TypeFamily.SIGNED_64, R(registerValue(registerArgs, TypeFamily.ADDRESS)));
			}
			for (ref<NodeList> params = parameterScope.type().parameters(); params != null; params = params.next) {
				byte value = params.node.register;
				if (value > 0) {
					if (params.node.type.isFloat()) {
						inst(X86.SUB, TypeFamily.SIGNED_64, R.RSP, 8);
						inst(X86.MOVSD, TypeFamily.SIGNED_64, R.RSP, 0, R(value));
					} else
						inst(X86.PUSH, TypeFamily.SIGNED_64, R(value));
				}
			}
			reserveAutoMemory(false, compileContext);
			if (parameterScope.enclosing().isMonitor() && func.functionCategory() != FunctionDeclaration.Category.CONSTRUCTOR &&
				parameterScope.hasThis()) {
				inst(X86.MOV, TypeFamily.ADDRESS, firstRegisterArgument(), thisRegister());
				instCall(takeMethod(compileContext), compileContext);
			}
			closeCodeSegment(CC.NOP, null);
			if (node.fallsThrough() == Test.PASS_TEST) {
				if (!generateReturn(parameterScope, compileContext)) {
					node.print(0);
					assert(false);
				}
			}
			resolveDeferredTrys(true, compileContext);
		} else {
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.RBX);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.RSI);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.RDI);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.R12);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.R13);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.R14);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.R15);
			inst(X86.PUSH, TypeFamily.SIGNED_64, firstRegisterArgument());
			ref<CodeSegment> handler = _storage new CodeSegment;
			pushExceptionHandler(handler);
			_arena.clearStaticInitializers();
			// Now we have to generate the various static blocks for included units.
			while (_arena.collectStaticInitializers(this))
				;
			ref<Scope> globalFrame = _arena.createScope(null, null, StorageClass.AUTO);
			for (int i = 0; i < staticBlocks().length(); i++) {
				ref<FileStat> file = (*staticBlocks())[i];
				if (file.fileScope() != null)
					globalFrame.collectAutoScopesUnderUnitScope(file.fileScope());
			}
			f().autoSize = globalFrame.autoStorage(this, 0, compileContext);
			if (_arena.verbose)
				printf("Static initializers:\n");
//			printf("staticBlocks %d\n", staticBlocks().length());
			int initialVariableCount = compileContext.variableCount();
			for (int i = 0; i < staticBlocks().length(); i++) {
				ref<FileStat> file = (*staticBlocks())[i];
				if (file != scope.file()) {
					if (_arena.verbose)
						printf("   %s\n", file.filename());
					generateStaticBlock(file, compileContext);
				}
			}
			for (int i = 0; i < _arena.types().length(); i++) {
				ref<TemplateInstanceType> t = (*_arena.types())[i];
				ref<FileStat> file = t.definingFile();
				if (_arena.verbose)
					printf("   Template in %s\n", file.filename());
				if (file.fileScope() != null)
					compileContext.setCurrent(file.fileScope());
				else
					compileContext.setCurrent(_arena.root());
				for (ref<NodeList> nl = t.concreteDefinition().classDef.statements(); nl != null; nl = nl.next) {
					allocateStackForLocalVariables(compileContext);
					generateStaticInitializers(nl.node, compileContext);
				}
			}
			if (_arena.verbose)
				printf("   %s\n", scope.file().filename());
			generateStaticBlock(scope.file(), compileContext);
			node = ref<Block>(scope.definition());
			ref<Symbol> main = scope.lookup("main", compileContext);
			Location loc;
			loc.offset = int(storage.size(scope.file().filename()));
			emitSourceLocation(scope.file(), loc);
			if (main != null &&
				main.class == Overload) {
				ref<Overload> m = ref<Overload>(main);
				// Confirm that it has 'function int(string[])' type
				// generate call to main
				// MOV RCX,input - find some place to put it.
				inst(X86.POP, TypeFamily.SIGNED_64, firstRegisterArgument());
				inst(X86.PUSH, TypeFamily.SIGNED_64, firstRegisterArgument());
				inst(X86.PUSH, firstRegisterArgument(), 8);
				inst(X86.PUSH, firstRegisterArgument(), 0);
				ref<OverloadInstance> instance = (*m.instances())[0];
				instCall(instance.parameterScope(), compileContext);
				// return value is in RAX
			} else {
//				inst(X86.POP, TypeFamily.SIGNED_64, firstRegisterArgument());
				inst(X86.XOR, TypeFamily.SIGNED_64, R.RAX, R.RAX);
			}
			pushExceptionHandler(null);
			ref<CodeSegment> join = _storage new CodeSegment;
			closeCodeSegment(CC.NOP, null);
			insertPreamble();
			inst(X86.ENTER, 0);
			reserveAutoMemory(true, compileContext);
			pushExceptionHandler(handler);
			join.start(this);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.RAX);
			inst(X86.SUB, TypeFamily.ADDRESS, R.RSP, 8);
			int liveVariables = compileContext.liveSymbolCount();
			for (int i = liveVariables - 1; i >= 0; i--) {
				ref<Node> id = compileContext.getLiveSymbol(i);
//				id.print(0, false);
				inst(X86.LEA, firstRegisterArgument(), id, compileContext);
				instCall(id.type.scope().destructor(), compileContext);
			}
			inst(X86.ADD, TypeFamily.ADDRESS, R.RSP, 8);
			inst(X86.POP, TypeFamily.SIGNED_64, R.RAX);

			inst(X86.POP, TypeFamily.SIGNED_64, firstRegisterArgument());
			inst(X86.POP, TypeFamily.SIGNED_64, R.R15);
			inst(X86.POP, TypeFamily.SIGNED_64, R.R14);
			inst(X86.POP, TypeFamily.SIGNED_64, R.R13);
			inst(X86.POP, TypeFamily.SIGNED_64, R.R12);
			inst(X86.POP, TypeFamily.SIGNED_64, R.RDI);
			inst(X86.POP, TypeFamily.SIGNED_64, R.RSI);
			inst(X86.POP, TypeFamily.SIGNED_64, R.RBX);
			inst(X86.LEAVE);
			if (!generateReturn(scope, compileContext))
				unfinished(node, "generateReturn failed - default end-of-static block", compileContext);
			pushExceptionHandler(null);
			handler.start(this);
			inst(X86.LEA, R.RSP, R.RBP, -(f().autoSize + 8 * address.bytes));
			ref<Symbol> re;
			ref<Overload> o;
			re = compileContext.arena().getSymbol("parasol", "exception.uncaughtException", compileContext);
			if (re == null || re.class != Overload)
				assert(false);
			o = ref<Overload>(re);
			ref<Type> tp = (*o.instances())[0].assignType(compileContext);
			ref<ParameterScope> uncaughtException = ref<ParameterScope>(tp.scope());
			instCall(uncaughtException, compileContext);
			int reserveSpace = f().autoSize - f().registerSaveSize;
			inst(X86.LEA, R.RSP, R.RBP, -reserveSpace); 
			inst(X86.POP, TypeFamily.SIGNED_64, firstRegisterArgument());
			inst(X86.POP, TypeFamily.SIGNED_64, R.R15);
			inst(X86.POP, TypeFamily.SIGNED_64, R.R14);
			inst(X86.POP, TypeFamily.SIGNED_64, R.R13);
			inst(X86.POP, TypeFamily.SIGNED_64, R.R12);
			inst(X86.POP, TypeFamily.SIGNED_64, R.RDI);
			inst(X86.POP, TypeFamily.SIGNED_64, R.RSI);
			inst(X86.POP, TypeFamily.SIGNED_64, R.RBX);
			inst(X86.LEAVE);
			if (!generateReturn(scope, compileContext))
				unfinished(node, "generateReturn failed - default end-of-static block", compileContext);
			closeCodeSegment(CC.NOP, null);
			resolveDeferredTrys(false, compileContext);
		}
		_deferredTry.resize(f().knownDeferredTrys);
	}

	private void generateDestructorShutdown(ref<ParameterScope> parameterScope, ref<CompileContext> compileContext) {
		ref<ClassScope> classScope = ref<ClassScope>(parameterScope.enclosing());
		assert(classScope.storageClass() == StorageClass.MEMBER);
		for (int i = 0; i < classScope.members().length(); i++) {
			ref<Symbol> sym = (*classScope.members())[i];
			if (sym.storageClass() == StorageClass.MEMBER && sym.type().hasDestructor()) {
				inst(X86.LEA, firstRegisterArgument(), thisRegister(), sym.offset);
				instCall(sym.type().scope().destructor(), compileContext);
			}
		}
		ref<Scope> base = classScope.base(compileContext);
		if (base != null && base.destructor() != null) {
			inst(X86.MOV, TypeFamily.ADDRESS, firstRegisterArgument(), thisRegister());
			instCall(base.destructor(), compileContext);			
		}
	}

	private boolean generateInterfaceDestructorThunk(ref<ParameterScope> parameterScope, ref<CompileContext> compileContext) {
		ref<Scope> scope = parameterScope.enclosing();
		if (scope.class != InterfaceImplementationScope)
			return false;
		ref<InterfaceImplementationScope> iis = ref<InterfaceImplementationScope>(scope);
		if (!iis.implementingClass().hasDestructor())
			return false;
		inst(X86.SUB, TypeFamily.ADDRESS, firstRegisterArgument(), iis.thunkOffset);
		instJump(parameterScope, compileContext);
		return true;
	}
	
	private boolean needsDestructorShutdown(ref<ParameterScope> parameterScope, ref<CompileContext> compileContext) {
		ref<ClassScope> classScope = ref<ClassScope>(parameterScope.enclosing());
		for (int i = 0; i < classScope.members().length(); i++) {
			ref<Symbol> sym = (*classScope.members())[i];
			if (sym.type().hasDestructor())
				return true;
		}
		ref<Scope> base = classScope.base(compileContext);
		return base != null && base.destructor() != null;
	}
	
	private void resolveDeferredTrys(boolean isFunction, ref<CompileContext> compileContext) {
		ref<Symbol> re = compileContext.arena().getSymbol("parasol", "exception.dispatchException", compileContext);
		if (re == null || re.class != Overload)
			assert(false);
		ref<Overload> o = ref<Overload>(re);
		ref<Type> tp = (*o.instances())[0].assignType(compileContext);
		ref<ParameterScope> dispatchException = ref<ParameterScope>(tp.scope());
		re = compileContext.arena().getSymbol("parasol", "exception.throwException", compileContext);
		if (re == null || re.class != Overload)
			assert(false);
		o = ref<Overload>(re);
		tp = (*o.instances())[0].assignType(compileContext);
		ref<ParameterScope> throwException = ref<ParameterScope>(tp.scope());
		for (int i = f().knownDeferredTrys; i < _deferredTry.length(); i++) {
			ref<DeferredTry> dt = &_deferredTry[i];
			ref<CodeSegment> outer = pushExceptionHandler(dt.exceptionHandler);
			dt.primaryHandler.start(this);
			int adjust = -f().autoSize;
			if (!isFunction)
				adjust -= 8 * address.bytes;
			// An exception handler enters with RBP correct and RCX pointing to the exception itself.
			// First we have to chop the stack, so we can proceed to dispatch to one of a set of catch
			// clauses. The clauses were sorted during the fold phase to put the most specific Exception
			// first. That way we only have to move down the list in sequence.
			inst(X86.LEA, R.RSP, R.RBP, adjust);
			ref<NodeList> nl = dt.tryStatement.catchList();
			ref<Node> temp = nl.node;
			inst(X86.MOV, temp, firstRegisterArgument(), compileContext);
			for (nl = nl.next; nl != null; nl = nl.next) {
				ref<CodeSegment> nextCheck = _storage new CodeSegment;
				ref<Binary> b = ref<Binary>(nl.node);
				ref<Type> t = ref<TypedefType>(b.left().type).wrappedType();	// Get the catch Exception class
				instLoadType(secondRegisterArgument(), t);	// target type
				inst(X86.MOV, firstRegisterArgument(), temp, compileContext);
				inst(X86.LEA, thirdRegisterArgument(), b.right(), compileContext);
				inst(X86.MOV, TypeFamily.SIGNED_32, fourthRegisterArgument(), t.size());
				instCall(dispatchException, compileContext);
				inst(X86.OR, TypeFamily.BOOLEAN, R.RAX, R.RAX);
				closeCodeSegment(CC.JE, nextCheck);
				generate(nl.node, compileContext);
				closeCodeSegment(CC.JMP, dt.join);
				nextCheck.start(this);
			}
			if (dt.tryStatement.finallyClause() != null)
				generate(dt.tryStatement.finallyClause(), compileContext);
			inst(X86.MOV, firstRegisterArgument(), temp, compileContext);
			inst(X86.MOV, TypeFamily.ADDRESS, secondRegisterArgument(), R.RBP);
			inst(X86.MOV, TypeFamily.ADDRESS, thirdRegisterArgument(), R.RSP);
			instCall(throwException, compileContext);

			pushExceptionHandler(outer);
		}
	}
	
	private void reserveAutoMemory(boolean preserveRCX, ref<CompileContext> compileContext) {
		int zeroZone = f().autoSize - f().registerSaveSize;
		f().autoSize += REGISTER_PARAMETER_STACK_AREA;
		if ((f().autoSize & 15) != 0)
			f().autoSize = (f().autoSize + 15) & ~15;
		int reserveSpace = f().autoSize - f().registerSaveSize;
		inst(X86.SUB, TypeFamily.SIGNED_64, R.RSP, reserveSpace);
		if (zeroZone > 0) {
			if (preserveRCX)
				inst(X86.PUSH, TypeFamily.SIGNED_64, firstRegisterArgument());
			inst(X86.MOV, TypeFamily.ADDRESS, firstRegisterArgument(), R.RSP);
			if (preserveRCX)
				inst(X86.ADD, TypeFamily.ADDRESS, firstRegisterArgument(), address.bytes);
			inst(X86.XOR, TypeFamily.UNSIGNED_16, secondRegisterArgument(), secondRegisterArgument());
			inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), reserveSpace);
			instCall(_memset, compileContext);
			if (preserveRCX)
				inst(X86.POP, TypeFamily.SIGNED_64, firstRegisterArgument());
		}
	}

	private void allocateStackForLocalVariables(ref<CompileContext> compileContext) {
		ref<ref<Variable>[]> v = compileContext.variables();
//		if (_stackLocalVariables < v.length())
//			printf("-- Scope %p\n", f().current);
		for (int i = _stackLocalVariables; i < v.length(); i++) {
			ref<Variable> var = (*v)[i];
			int sz = var.stackSize();
//			if (var.returns != null)
//				var.print();
//			assert(sz > 0);
			f().autoSize += sz;
			var.offset = -f().autoSize;
//			printf("Var [%d] %p offset %d\n", i, var, var.offset);
		}
//		if (_stackLocalVariables < v.length())
//			printf("<<\n");
		_stackLocalVariables = v.length();
	}
	
	private void generateConstructorPreamble(ref<Block> constructorBody, ref<ParameterScope> scope, ref<CompileContext> compileContext) {
		int firstMemberOffset = scope.enclosing().firstMemberOffset(compileContext);
		if (firstMemberOffset > 0) {
			if (scope.enclosing().variableStorage > firstMemberOffset) {
				inst(X86.LEA, firstRegisterArgument(), thisRegister(), firstMemberOffset);
				inst(X86.XOR, TypeFamily.UNSIGNED_16, secondRegisterArgument(), secondRegisterArgument());
				inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), scope.enclosing().variableStorage - firstMemberOffset);
				instCall(_memset, compileContext);
			}
		} else {
			inst(X86.MOV, TypeFamily.ADDRESS, firstRegisterArgument(), thisRegister());
			inst(X86.XOR, TypeFamily.UNSIGNED_16, secondRegisterArgument(), secondRegisterArgument());
			inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), scope.enclosing().variableStorage);
			instCall(_memset, compileContext);
		}
		for (ref<Symbol>[Scope.SymbolKey].iterator i = scope.enclosing().symbols().begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.class != PlainSymbol || sym.storageClass() != StorageClass.MEMBER)
				continue;
			ref<ParameterScope> defaultConstructor = sym.type().defaultConstructor();
			if (!sym.type().isInterface() && sym.type().hasVtable(compileContext)) {
				inst(X86.LEA, firstRegisterArgument(), thisRegister(), sym.offset);
				storeVtable(sym.type(), compileContext);
				if (defaultConstructor != null)
					instCall(defaultConstructor, compileContext);
			} else if (defaultConstructor != null) {
				inst(X86.LEA, firstRegisterArgument(), thisRegister(), sym.offset);
				instCall(defaultConstructor, compileContext);
			} else if (sym.type().interfaceCount() > 0)
				inst(X86.LEA, firstRegisterArgument(), thisRegister(), sym.offset);
			storeITables(sym.type(), sym.offset, compileContext);
		}
		if (constructorBody != null) {
			// if there is no super. or self. calls at the head of the node, we need to generate one
			ref<NodeList> nl = constructorBody.statements();
			if (nl != null && nl.node.op() == Operator.EXPRESSION) {
				ref<Unary> u = ref<Unary>(nl.node);
				if (u.operand().op() == Operator.CALL) {
					ref<Call> c = ref<Call>(u.operand());
					if (c.target() != null) {
						if (c.target().op() == Operator.SUPER || c.target().op() == Operator.SELF)
							return;
					}
				}
			}
		}
		if (scope.enclosing().base(compileContext) != null) {
			inst(X86.MOV, TypeFamily.ADDRESS, firstRegisterArgument(), thisRegister());
			generateCallToBaseDefaultConstructor(scope, compileContext);
		}
	}
	
	private void generateCallToBaseDefaultConstructor(ref<ParameterScope> scope, ref<CompileContext> compileContext) {
		ref<ClassScope> classScope = ref<ClassScope>(scope.enclosing());
		ref<Type> base = classScope.getSuper();
//		ref<Scope> base = classScope.base(compileContext);
		if (base != null) {
			ref<ParameterScope> baseDefaultConstructor = base.defaultConstructor(); 
			if (baseDefaultConstructor != null)
				instCall(baseDefaultConstructor, compileContext);
		}
	}
	
	private void generateStaticBlock(ref<FileStat> file, ref<CompileContext> compileContext) {
		
		// Here is where all static initializers are folded:

		ref<Node> n = compileContext.fold(file.tree().root(), file);
		allocateStackForLocalVariables(compileContext);
		if (file.fileScope() != null)
			compileContext.setCurrent(file.fileScope());
		else
			compileContext.setCurrent(_arena.root());
		n.traverse(Node.Traversal.IN_ORDER, collectStaticDestructors, compileContext);
		generate(n, compileContext);
	}
	
	private void generate(ref<Node> node, ref<CompileContext> compileContext) {
		if (node.deferGeneration()) {
			// Throw an exception
			return;
		}
		if (verbose()) {
			printf("-----  generate %s ---------\n", compileContext.current().sourceLocation(node.location()));
			f().r.print();
			node.print(4);
		}
		switch (node.op()) {
		case	LOCK:
		case	BLOCK:
		case	UNIT:
			ref<Block> block = ref<Block>(node);
			if (!block.inSwitch())
				generateDefaultConstructors(block.scope, compileContext);
			for (ref<NodeList> nl = block.statements(); nl != null; nl = nl.next)
				generate(nl.node, compileContext);
			break;
			
		case	DECLARATION:
			ref<Binary> b = ref<Binary>(node);
//			printf("Declaration...\n");
//			node.print(0);
			emitSourceLocation(compileContext.current().file(), node.location());
			generateInitializers(b.right(), compileContext);
			break;

		case	INITIALIZE:
			generateInitializers(node, compileContext);
			break;
			
		case	ANNOTATED:
			b = ref<Binary>(node);
			generate(b.right(), compileContext);
			break;

		case	STATIC:
		case	PUBLIC:
		case	PRIVATE:
		case	PROTECTED:
		case	FINAL:
		case	ABSTRACT:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			break;
			
		case	EXPRESSION:
			ref<Unary> expression = ref<Unary>(node);
			// This was a vector expression
			if (expression.operand().op() == Operator.FOR)
				generate(expression.operand(), compileContext);
			else
				generateExpressionStatement(expression.operand(), compileContext);
			break;
	
		case	CATCH:
			cond = ref<Ternary>(node);
			generate(cond.right(), compileContext);
			break;
			
		case	SEQUENCE:
			b = ref<Binary>(node);
			generate(b.left(), compileContext);
			generate(b.right(), compileContext);
			break;
			
		case	CONDITIONAL:
			cond = ref<Ternary>(node);
			trueSegment = _storage new CodeSegment;
			falseSegment = _storage new CodeSegment;
			join = _storage new CodeSegment;
			f().r.generateSpills(cond, this);
			generateConditional(cond.left(), trueSegment, falseSegment, compileContext);
			trueSegment.start(this);
			generate(cond.middle(), compileContext);
			closeCodeSegment(CC.JMP, join);
			falseSegment.start(this);
			generate(cond.right(), compileContext);
			f().r.generateSpills(node, this);
			join.start(this);
			break;
			
		case	NOT:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			f().r.generateSpills(expression, this);
			if ((getRegMask(R(node.register)) & byteMask) != 0)
				inst(X86.XOR, TypeFamily.BOOLEAN, R(int(node.register)), 1);
			else
				inst(X86.XOR, TypeFamily.SIGNED_16, R(int(node.register)), 1);
			break;
			
		case	LOGICAL_OR:
		case	LOGICAL_AND:
			b = ref<Binary>(node);
			join = _storage new CodeSegment;
			trueSegment = _storage new CodeSegment;
			falseSegment = _storage new CodeSegment;
			generateConditional(node, trueSegment, falseSegment, compileContext);
			trueSegment.start(this);
			inst(X86.MOV, node, 1, compileContext);
			closeCodeSegment(CC.JMP, join);
			falseSegment.start(this);
			inst(X86.XOR, TypeFamily.BOOLEAN, node, node, compileContext);
			join.start(this);
			f().r.generateSpills(node, this);
			break;
			
		case	EQUALITY:
		case	LESS:
		case	GREATER:
		case	LESS_EQUAL:
		case	GREATER_EQUAL:
		case	LESS_GREATER:
		case	LESS_GREATER_EQUAL:
		case	NOT_EQUAL:
		case	NOT_LESS:
		case	NOT_GREATER:
		case	NOT_LESS_EQUAL:
		case	NOT_GREATER_EQUAL:
		case	NOT_LESS_GREATER:
		case	NOT_LESS_GREATER_EQUAL:
			b = ref<Binary>(node);
			ref<CodeSegment> trueSegment = _storage new CodeSegment;
			ref<CodeSegment> falseSegment = _storage new CodeSegment;
			ref<CodeSegment> join = _storage new CodeSegment;
			generateCompare(b, trueSegment, falseSegment, compileContext);
			trueSegment.start(this);
			inst(X86.MOV, TypeFamily.BOOLEAN, R(int(b.register)), 1);
			closeCodeSegment(CC.JMP, join);
			falseSegment.start(this);
			inst(X86.MOV, TypeFamily.BOOLEAN, R(int(b.register)), 0);
			join.start(this);
			break;
			
		case	IF:
			ref<Ternary> cond = ref<Ternary>(node);
			trueSegment = _storage new CodeSegment;
			falseSegment = _storage new CodeSegment;
			join = _storage new CodeSegment;
			markConditionalAddressModes(cond.left(), compileContext);
			sethiUllman(cond.left(), compileContext, this);
			assignConditionCode(cond.left(), compileContext);
			emitSourceLocation(compileContext.current().file(), node.location());
			generateConditional(cond.left(), trueSegment, falseSegment, compileContext);
			trueSegment.start(this);
			generate(cond.middle(), compileContext);
			closeCodeSegment(CC.JMP, join);
			falseSegment.start(this);
			generate(cond.right(), compileContext);
			join.start(this);
			break;
			
		case	FOR:
		case	SCOPED_FOR:
			ref<For> forStmt = ref<For>(node);

			if (forStmt.op() == Operator.SCOPED_FOR)
				generate(forStmt.initializer(), compileContext);
			else
				generateExpressionStatement(forStmt.initializer(), compileContext);

			ref<CodeSegment> testSegment = _storage new CodeSegment;
			join = _storage new CodeSegment;
			topOfLoop = _storage new CodeSegment;

			closeCodeSegment(CC.JMP, testSegment);
			topOfLoop.start(this);
			generateExpressionStatement(forStmt.increment(), compileContext);
			testSegment.start(this);
			if (forStmt.test().op() != Operator.EMPTY) {
				trueSegment = _storage new CodeSegment;
				markAddressModes(forStmt.test(), compileContext);
				sethiUllman(forStmt.test(), compileContext, this);
				assignConditionCode(forStmt.test(), compileContext);
				generateConditional(forStmt.test(), trueSegment, join, compileContext);
				trueSegment.start(this);
			}
			JumpContext forContext(forStmt, join, topOfLoop, null, this, jumpContext());
			pushJumpContext(&forContext);
			generate(forStmt.body(), compileContext);
			popJumpContext();
			closeCodeSegment(CC.JMP, topOfLoop);
			join.start(this);
			break;

		case	LOOP:
			ref<Loop> loop = ref<Loop>(node);
//			loop.print(0);
			testSegment = _storage new CodeSegment;
			join = _storage new CodeSegment;
			topOfLoop = _storage new CodeSegment;

			closeCodeSegment(CC.JMP, testSegment);
			topOfLoop.start(this);
//			generate(forStmt.increment(), compileContext);
			testSegment.start(this);
			trueSegment = _storage new CodeSegment;
//			markAddressModes(forStmt.test(), compileContext);
//			sethiUllman(forStmt.test(), compileContext, this);
//			assignConditionCode(forStmt.test(), compileContext);
//			generateConditional(forStmt.test(), trueSegment, join, compileContext);
			trueSegment.start(this);
			JumpContext loopContext(loop, join, topOfLoop, null, this, jumpContext());
			pushJumpContext(&loopContext);
			generate(loop.body(), compileContext);
			popJumpContext();
			closeCodeSegment(CC.JMP, topOfLoop);
			join.start(this);
			break;

		case	WHILE:
			b = ref<Binary>(node);
			trueSegment = _storage new CodeSegment;
			join = _storage new CodeSegment;
			ref<CodeSegment> topOfLoop = _storage new CodeSegment;
			markAddressModes(b.left(), compileContext);
			sethiUllman(b.left(), compileContext, this);
			assignConditionCode(b.left(), compileContext);
			topOfLoop.start(this);
			generateConditional(b.left(), trueSegment, join, compileContext);
			trueSegment.start(this);
			JumpContext whileContext(b, join, topOfLoop, null, this, jumpContext());
			pushJumpContext(&whileContext);
			generate(b.right(), compileContext);
			popJumpContext();
			closeCodeSegment(CC.JMP, topOfLoop);
			join.start(this);
			break;
			
		case	DO_WHILE:
			b = ref<Binary>(node);
			join = _storage new CodeSegment;
			trueSegment = _storage new CodeSegment;
			topOfLoop = _storage new CodeSegment;
			topOfLoop.start(this);
			JumpContext doWhileContext(b, join, trueSegment, null, this, jumpContext());
			pushJumpContext(&doWhileContext);
			generate(b.left(), compileContext);
			popJumpContext();
			trueSegment.start(this);
			markAddressModes(b.right(), compileContext);
			sethiUllman(b.right(), compileContext, this);
			assignConditionCode(b.right(), compileContext);
			generateConditional(b.right(), topOfLoop, join, compileContext);
			closeCodeSegment(CC.JMP, topOfLoop);
			join.start(this);
			break;
			
		case	SWITCH:
			b = ref<Binary>(node);
			ref<CodeSegment> defaultSegment = _storage new CodeSegment;
			join = _storage new CodeSegment;
			GatherCasesClosure closure;
			closure.target = this;
			gatherCases(b.right(), &closure);
			assert(b.right().op() == Operator.BLOCK);
			block = ref<Block>(b.right());
			emitSourceLocation(compileContext.current().file(), node.location());
			generateDefaultConstructors(block.scope, compileContext);
			JumpContext switchContext(b, join, defaultSegment, &closure.nodes, this, jumpContext());
			markAddressModes(b.left(), compileContext);
			sethiUllman(b.left(), compileContext, this);
			assignVoidContext(node, compileContext);		// Take the result in any register available.
			generate(b.left(), compileContext);
			f().r.generateSpills(node, this);
			ref<CodeSegment>[] labels = switchContext.caseLabels();
			R controlReg = R(b.left().register);
			int size = b.left().type.size();
			long mask;
			if (size < 8)
				mask = (long(1) << (size << 3)) - 1;
			else
				mask = ~0;
			for (int i = 0; i < labels.length(); i++) {
				ref<Binary> caseNode = ref<Binary>(closure.nodes[i]);
				if (caseNode.left().deferGeneration()) {
					// TODO: generate exception
					continue;
				}
				if (b.left().type.family() == TypeFamily.STRING) {
					ref<Node> literal = caseNode.left();
					inst(X86.LEA, firstRegisterArgument(), literal, compileContext);
					inst(X86.PUSH, TypeFamily.ADDRESS, firstRegisterArgument());
					inst(X86.MOV, TypeFamily.ADDRESS, firstRegisterArgument(), R.RSP);
					inst(X86.PUSH, TypeFamily.ADDRESS, controlReg);
					instCall(_stringCompare.parameterScope(), compileContext);
					inst(X86.POP, TypeFamily.ADDRESS, controlReg);
					inst(X86.ADD, TypeFamily.ADDRESS, R.RSP, 8);
					inst(X86.CMP, TypeFamily.SIGNED_32, R.RAX, 0);
					closeCodeSegment(CC.JE, labels[i]);
					ref<CodeSegment> n = _storage new CodeSegment;
					n.start(this);
				} else {
					int x;
					if (b.left().type.family() == TypeFamily.ENUM) {
						ref<EnumInstanceType> t = ref<EnumInstanceType>(b.left().type);
						ref<InternalLiteral> c = ref<InternalLiteral>(caseNode.left());
						x = int(c.intValue());
					} else
						x = int(caseNode.left().foldInt(this, compileContext));
					inst(X86.CMP, impl(b.left().type), controlReg, x);// & mask);
					closeCodeSegment(CC.JE, labels[i]);
					ref<CodeSegment> n = _storage new CodeSegment;
					n.start(this);
					
				}
			}
			closeCodeSegment(CC.JMP, defaultSegment);
			pushJumpContext(&switchContext);
			generate(b.right(), compileContext);
			popJumpContext();
			defaultSegment = switchContext.consumeDefaultLabel();
			if (defaultSegment != null)
				defaultSegment.start(this);
			join.start(this);
			break;
		
		case	CASE:
			b = ref<Binary>(node);
			ref<JumpContext> context = jumpContext().enclosingSwitch();
			context.nextCaseLabel().start(this);
			generate(b.right(), compileContext);
			break;
			
		case	DEFAULT:
			expression = ref<Unary>(node);
			context = jumpContext().enclosingSwitch();
			if (context != null) {
				ref<CodeSegment> cs = context.consumeDefaultLabel();
				if (cs != null)
					cs.start(this);
			}
			generate(expression.operand(), compileContext);
			break;
			
		case	BREAK:
			emitSourceLocation(compileContext.current().file(), node.location());
			generateLiveSymbolDestructors(ref<Jump>(node).liveSymbols(), compileContext);
			closeCodeSegment(CC.JMP, jumpContext().breakLabel());
			break;
			
		case	CONTINUE:
			emitSourceLocation(compileContext.current().file(), node.location());
			generateLiveSymbolDestructors(ref<Jump>(node).liveSymbols(), compileContext);
			closeCodeSegment(CC.JMP, jumpContext().continueLabel());
			break;
			
		case	RETURN:
			ref<Return> retn = ref<Return>(node);
			emitSourceLocation(compileContext.current().file(), node.location());
			if (retn.multiReturnOfMultiCall()) {
				ref<Node> call = retn.arguments().node;
				markAddressModes(call, compileContext);
				sethiUllman(call, compileContext, this);
				assignVoidContext(call, compileContext);		// Take the result in any register available.
				generate(call, compileContext);
				generateLiveSymbolDestructors(retn.liveSymbols(), compileContext);
			} else {
				ref<NodeList> arguments = retn.arguments();
				if (arguments != null) {
					for (ref<NodeList> nl = arguments; nl != null; nl = nl.next) {
						markAddressModes(nl.node, compileContext);
						sethiUllman(nl.node, compileContext, this);
					}
					if (arguments.next == null) {
						ref<FunctionDeclaration> enclosing = f().current.enclosingFunction();
						ref<FunctionType> functionType = ref<FunctionType>(enclosing.type);
						ref<NodeList> returnType = functionType.returnType();
						if (returnType.next != null && containsNestedMultiReturn(arguments.node))
							generateNestedMultiReturn(functionType, arguments.node, compileContext);
						else {
							assignSingleReturn(retn, arguments.node, compileContext);
							if (returnType.next != null || 
								returnType.node.type.returnsViaOutParameter(compileContext))
								generateOutParameter(arguments.node, 0, compileContext);
							else
								generate(arguments.node, compileContext);
							f().r.generateSpills(node, this);
						}
					} else {
						int outOffset = 0;
						for (ref<NodeList> nl = arguments; nl != null; nl = nl.next) {
							assignMultiReturn(retn, nl.node, compileContext);
							generateOutParameter(nl.node, outOffset, compileContext);
							outOffset += nl.node.type.stackSize();
						}
					}
					if (retn.liveSymbols() != null) {
						ref<ParameterScope> enclosing = ref<ParameterScope>(compileContext.current());
						boolean outParam = enclosing.hasOutParameter(compileContext);

						if (!outParam) {
							switch (arguments.node.type.family()) {
							case	FLOAT_64:
							case	FLOAT_32:
								retn.print(4);
								assert(false);
								
							default:
								inst(X86.PUSH, TypeFamily.ADDRESS, R.RAX);
							}
						}
						generateLiveSymbolDestructors(retn.liveSymbols(), compileContext);
						if (!outParam) {
							switch (arguments.node.type.family()) {
							case	FLOAT_64:
							case	FLOAT_32:
								retn.print(4);
								assert(false);
								
							default:
								inst(X86.POP, TypeFamily.ADDRESS, R.RAX);
							}
						}
					}
				} else
					generateLiveSymbolDestructors(retn.liveSymbols(), compileContext);
			}
				
			if (!generateReturn(f().current, compileContext))
				unfinished(retn, "failed return generation", compileContext);
			break;
			
		case	TRY:
			ref<Try> tr = ref<Try>(node);
			ref<CodeSegment> primaryHandler = _storage new CodeSegment;
//			ref<CodeSegment> secondaryHandler = tr.finallyClause() != null ? _storage new CodeSegment : null;
			join = _storage new CodeSegment;
			ref<CodeSegment> outer = pushExceptionHandler(primaryHandler);
			generate(tr.body(), compileContext);
			pushExceptionHandler(outer);
			join.start(this);
			if (tr.finallyClause() != null) {
				generate(tr.finallyClause().clone(compileContext.tree()), compileContext);
			}
			DeferredTry dt = { tryStatement: tr, primaryHandler: primaryHandler, join: join, exceptionHandler: outer };
			_deferredTry.append(dt);
			break;
			
		case	CLASS_DECLARATION:
		case	ENUM:
			generateStaticInitializers(node, compileContext);
			break;

		case	DESTRUCTOR_LIST:
			ref<DestructorList> dl = ref<DestructorList>(node);
			f().r.generateSpills(node, this);
			generateLiveSymbolDestructors(dl.arguments(), compileContext);
			break;
			
		case	INTERFACE_DECLARATION:
		case	FLAGS_DECLARATION:
		case	MONITOR_CLASS:
		case	DECLARE_NAMESPACE:
		case	IMPORT:
		case	EMPTY:
			break;
			
		case	FUNCTION:
			ref<FunctionDeclaration> func = ref<FunctionDeclaration>(node);
			if (func.body != null) {
				if (func.name() == null) {
					ref<ParameterScope> functionScope = _arena.createParameterScope(compileContext.current(), func, ParameterScope.Kind.FUNCTION);
					ref<ParameterScope> funcScope;
					boolean isBuiltIn;
										
					(funcScope, isBuiltIn) = getFunctionAddress(functionScope, compileContext);
					if (isBuiltIn)
						instBuiltIn(X86.MOV, R(func.register), functionScope);
					else
						instFunc(X86.MOV, R(func.register), functionScope);
				}
			}
			break;
			
		case	CLASS_COPY:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), b.type.size());
			instCall(_memcpy, compileContext);
			break;

		case	ASSIGN:
		case	ASSIGN_TEMP:
			b = ref<Binary>(node);
			if (b.left().op() == Operator.SEQUENCE) {
				b.print(0);
				assert(false);
			} else {
				switch (b.type.family()) {
				case	STRING:
					node.print(0);
					assert(false);
				case	TYPEDEF:
				case	CLASS_VARIABLE:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	SIGNED_16:
				case	SIGNED_32:
				case	UNSIGNED_32:
				case	SIGNED_64:
				case	BOOLEAN:
				case	ENUM:
				case	FLAGS:
				case	FUNCTION:
				case	ADDRESS:
				case	REF:
				case	POINTER:
				case	INTERFACE:
					generateOperands(b, compileContext);
	//				printf("\n\n---- ASSIGN ----\n");
	//				b.print(4);
					if (b.register == 0)
						inst(X86.MOV, impl(b.type), b.left(), b.right(), compileContext);
					else {
						inst(X86.MOV, R(b.register), b.right(), compileContext);
						inst(X86.MOV, b.left(), R(b.register), compileContext);
					}
					break;
					
				case	FLOAT_32:
					generateOperands(b, compileContext);
					inst(X86.MOVSS, b.type.family(), b.left(), b.right(), compileContext);
					break;
					
				case	FLOAT_64:
					generateOperands(b, compileContext);
					inst(X86.MOVSD, b.type.family(), b.left(), b.right(), compileContext);
					break;
					
				case	CLASS:
					generateOperands(b, compileContext);
					inst(X86.MOV, b.type.family(), b.left(), b.right(), compileContext);
					break;
					
				default:
					b.print(0);
					assert(false);
				}
			}
			/*
			if (seq.type.family() == TypeFamily.STRING)
				generateStringCopy(seq.left(), seq.right(), _stringCopyConstructor, compileContext);
			else {
				generate(seq.right(), compileContext);
				generateStore(seq.left(), compileContext);
			}
			if (!clearStack(seq.type, compileContext))
				unfinished(node, "clearStack - initialize", compileContext);
			*/
			break;
			
		case	AND:
		case	AND_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			if (b.register == 0 || b.op() == Operator.AND) {
				switch (b.type.family()) {
				case	BOOLEAN:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
				case	FLAGS:
					inst(X86.AND, impl(b.type), b.left(), b.right(), compileContext);
					if (b.op() == Operator.AND && b.register != b.left().register)
						inst(X86.MOV, b.type.family(), b, b.left(), compileContext);
					break;
					
				default:
					b.print(0);
					assert(false);
				}
			} else {
				switch (b.type.family()) {
				case	BOOLEAN:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
				case	FLAGS:
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
					inst(X86.AND, impl(b.type), b, b.right(), compileContext);
					inst(X86.MOV, b.left(), R(int(b.register)), compileContext);
					break;
					
				default:
					b.print(0);
					assert(false);
				}
			}
			break;
			
		case	OR:
		case	OR_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			if (b.register == 0 || b.op() == Operator.OR) {
				switch (b.type.family()) {
				case	BOOLEAN:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
				case	FLAGS:
					inst(X86.OR, impl(b.type), b.left(), b.right(), compileContext);
					if (b.op() == Operator.OR && b.register != b.left().register)
						inst(X86.MOV, b.type.family(), b, b.left(), compileContext);
					break;
					
				default:
					b.type.print();
					printf("\n");
					unfinished(node, "or", compileContext);
				}
			} else {
				switch (b.type.family()) {
				case	BOOLEAN:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
				case	FLAGS:
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
					inst(X86.OR, impl(b.type), b, b.right(), compileContext);
					inst(X86.MOV, b.left(), R(int(b.register)), compileContext);
					break;
					
				default:
					b.print(0);
					assert(false);
				}
			}
			break;
			
		case	EXCLUSIVE_OR:
		case	EXCLUSIVE_OR_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			if (b.register == 0 || b.op() == Operator.EXCLUSIVE_OR) {
				switch (b.type.family()) {
				case	BOOLEAN:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
				case	FLAGS:
					inst(X86.XOR, impl(b.type), b.left(), b.right(), compileContext);
					if (b.op() == Operator.EXCLUSIVE_OR && b.register != b.left().register)
						inst(X86.MOV, b.type.family(), b, b.left(), compileContext);
					break;
					
				default:
					b.print(0);
					assert(false);
				}
			} else {
				switch (b.type.family()) {
				case	BOOLEAN:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_16:
				case	SIGNED_32:
				case	SIGNED_64:
				case	FLAGS:
					inst(X86.MOV, R(b.register), b.left(), compileContext);
					inst(X86.XOR, impl(b.type), b, b.right(), compileContext);
					inst(X86.MOV, b.left(), R(b.register), compileContext);
					break;
					
				default:
					b.print(0);
					assert(false);
				}
			}
			break;
			
		case	DIVIDE:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.XOR, TypeFamily.UNSIGNED_8, R.AH, R.AH);
				inst(X86.DIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b, R.RAX, compileContext);
				break;
				
			case	UNSIGNED_16:
			case	UNSIGNED_32:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.XOR, b.type.family(), R.RDX, R.RDX);
				inst(X86.DIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b, R.RAX, compileContext);
				break;
				
			case	SIGNED_32:
			case	SIGNED_64:
				inst(X86.CWD, b.type.family(), R.RAX);
				inst(X86.IDIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b, R.RAX, compileContext);
				break;
				
			case	FLOAT_32:
				inst(X86.DIVSS, R(b.left().register), b.right(), compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.DIVSD, R(b.left().register), b.right(), compileContext);
				break;
				
			default:
				b.print(0);
				assert(false);
			}
			break;
			
		case	DIVIDE_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.XOR, TypeFamily.UNSIGNED_8, R.AH, R.AH);
				inst(X86.DIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.RAX, compileContext);
				break;
				
			case	UNSIGNED_16:
			case	UNSIGNED_32:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.XOR, b.type.family(), R.RDX, R.RDX);
				inst(X86.DIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.RAX, compileContext);
				break;
				
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				inst(X86.CWD, b.type.family(), R.RAX);
				inst(X86.IDIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.RAX, compileContext);
				break;
				
			case	FLOAT_32:
				inst(X86.MOVSS, b.type.family(), b, b.left(), compileContext);
				inst(X86.DIVSS, b.type.family(), b, b.right(), compileContext);
				inst(X86.MOVSS, b.type.family(), b.left(), b, compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.MOVSD, b.type.family(), b, b.left(), compileContext);
				inst(X86.DIVSD, b.type.family(), b, b.right(), compileContext);
				inst(X86.MOVSD, b.type.family(), b.left(), b, compileContext);
				break;
				
			default:
				b.print(0);
				assert(false);
			}
			break;
			
		case	REMAINDER:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.XOR, TypeFamily.UNSIGNED_8, R.AH, R.AH);
				inst(X86.DIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b, R.AH, compileContext);
				break;
				
			case	UNSIGNED_16:
			case	UNSIGNED_32:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.XOR, b.type.family(), R.RDX, R.RDX);
				inst(X86.DIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b, R.RDX, compileContext);
				break;
				
			case	SIGNED_32:
			case	SIGNED_64:
				inst(X86.CWD, b.type.family(), R.RAX);
				inst(X86.IDIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b, R.RDX, compileContext);
				break;
				
			default:
				b.type.print();
				printf("\n");
				unfinished(node, "remainder", compileContext);
			}
			break;
			
		case	REMAINDER_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.XOR, TypeFamily.UNSIGNED_8, R.AH, R.AH);
				inst(X86.DIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.AH, compileContext);
				break;
				
			case	UNSIGNED_16:
			case	UNSIGNED_32:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.XOR, b.type.family(), R.RDX, R.RDX);
				inst(X86.DIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.RDX, compileContext);
				break;
				
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.CWD, b.type.family(), R.RAX);
				inst(X86.IDIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.RDX, compileContext);
				break;
				
			default:
				b.type.print();
				printf("\n");
				unfinished(node, "remainder assignment", compileContext);
			}
			break;
			
		case	MULTIPLY:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
				inst(X86.IMUL, R(b.left().register), b.right(), compileContext);
				if (b.register != b.left().register)
					inst(X86.MOV, b.type.family(), b, b.left(), compileContext);
				break;
				
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
//			case	ADDRESS:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.MUL, R.RAX, b.right(), compileContext);
				if (R(b.register) != R.RAX)
					inst(X86.MOV, b, R.RAX, compileContext);
				break;
				
			case	FLOAT_32:
				inst(X86.MULSS, b.type.family(), b.left(), b.right(), compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.MULSD, b.type.family(), b.left(), b.right(), compileContext);
				break;
				
			default:
				b.print(0);
				assert(false);
			}
			break;
			
		case	MULTIPLY_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.MUL, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.RAX, compileContext);
				break;
				
			case	FLOAT_32:
				inst(X86.MULSS, b.type.family(), b.right(), b.left(), compileContext);
				inst(X86.MOVSS, b.type.family(), b.left(), b.right(), compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.MULSD, b.type.family(), b.right(), b.left(), compileContext);
				inst(X86.MOVSD, b.type.family(), b.left(), b.right(), compileContext);
				break;
				
			default:
				b.print(0);
				assert(false);
			}
			break;
			
		case	SUBTRACT:
		case	SUBTRACT_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				t = b.left().type.indirectType(compileContext);
				if (t != null && t.size() > 1) {
					inst(X86.XOR, b.type.family(), R.RDX, R.RDX);
					inst(X86.SUB, b.type.family(), b.left(), b.right(), compileContext);
					inst(X86.SBB, TypeFamily.SIGNED_64, R.RDX, 0);
					inst(X86.MOV, TypeFamily.SIGNED_64, R.RCX, t.size());
					inst(X86.IDIV, TypeFamily.SIGNED_64, R.RCX);
				} else if (b.register == 0 || b.op() == Operator.SUBTRACT)
					inst(X86.SUB, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.MOV, b.type.family(), b, b.left(), compileContext);
					inst(X86.SUB, b.type.family(), b, b.right(), compileContext);
					inst(X86.MOV, b.type.family(), b.left(), b, compileContext);
				}
				if (b.op() == Operator.SUBTRACT && b.register != b.left().register)
					inst(X86.MOV, b.type.family(), b, b.left(), compileContext);
				break;
				
			case	ADDRESS:
				inst(X86.MOVSXD, b.right().type.family(), b.right(), b.right(), compileContext);
				inst(X86.SUB, b.type.family(), b.left(), b.right(), compileContext);
				break;

			case	FLOAT_32:
				if (b.op() == Operator.SUBTRACT)
					inst(X86.SUBSS, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.MOVSS, b.type.family(), b, b.left(), compileContext);
					inst(X86.SUBSS, b.type.family(), b, b.right(), compileContext);
					inst(X86.MOVSS, b.type.family(), b.left(), b, compileContext);
				}
				break;
				
			case	FLOAT_64:
				if (b.op() == Operator.SUBTRACT)
					inst(X86.SUBSD, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.MOVSD, b.type.family(), b, b.left(), compileContext);
					inst(X86.SUBSD, b.type.family(), b, b.right(), compileContext);
					inst(X86.MOVSD, b.type.family(), b.left(), b, compileContext);
				}
				break;
				
			case	CLASS:
				printf("\n>> non pointer type\n");
				b.print(4);
				assert(false);
				
			default:
				b.print(4);
				assert(false);
			}
			break;
			
		case	ADD_ASSIGN:
		case	ADD:
			b = ref<Binary>(node);
			switch (b.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	POINTER:
				generateOperands(b, compileContext);
				if (b.register == 0 || b.op() == Operator.ADD)
					inst(X86.ADD, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.MOV, b.type.family(), b, b.left(), compileContext);
					inst(X86.ADD, b.type.family(), b, b.right(), compileContext);
					inst(X86.MOV, b.type.family(), b.left(), b, compileContext);
				}
				if (b.op() == Operator.ADD && b.register != b.left().register)
					inst(X86.MOV, b.type.family(), b, b.left(), compileContext);
				break;
				
			case	FLOAT_32:
				generateOperands(b, compileContext);
				if (b.op() == Operator.ADD)
					inst(X86.ADDSS, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.ADDSS, b.type.family(), b.right(), b.left(), compileContext);
					inst(X86.MOVSS, b.type.family(), b.left(), b.right(), compileContext);
				}
				break;
				
			case	FLOAT_64:
				generateOperands(b, compileContext);
				if (b.op() == Operator.ADD)
					inst(X86.ADDSD, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.ADDSD, b.type.family(), b.right(), b.left(), compileContext);
					inst(X86.MOVSD, b.type.family(), b.left(), b.right(), compileContext);
				}
				break;
				
			case	STRING:
				if (b.op() == Operator.ADD) {
					b.type.print();
					printf("\n");
					unfinished(node, "string +", compileContext);
				} else {
					generateOperands(b, compileContext);
					inst(X86.LEA, R.RDI, b.left(), compileContext);
					if (!instCall(_stringAppendString.parameterScope(), compileContext))
						return;
				}
				break;
				
			case	CLASS:
				printf("\n>> non pointer type\n");
				b.print(4);
				assert(false);

			default:
				b.print(4);
				assert(false);
			}
			break;
			
		case	LEFT_SHIFT:
		case	LEFT_SHIFT_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				if (b.register == 0)
					inst(X86.SAL, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.SAL, b.type.family(), b.left(), b.right(), compileContext);
					if (b.register != b.left().register)
						inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
				}
				break;
				
			default:
				b.type.print();
				printf("\n");
				unfinished(node, "left shift", compileContext);
			}
			break;
			
		case	RIGHT_SHIFT:
		case	RIGHT_SHIFT_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
				if (b.register == 0 || b.op() == Operator.SUBTRACT)
					inst(X86.SHR, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.SHR, b.type.family(), b.left(), b.right(), compileContext);
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
				}
				break;
				
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				if (b.register == 0 || b.op() == Operator.SUBTRACT)
					inst(X86.SAR, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.SAR, b.type.family(), b.left(), b.right(), compileContext);
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
				}
				break;
				
			default:
				b.type.print();
				printf("\n");
				unfinished(node, "right shift", compileContext);
			}
			break;
			
		case	UNSIGNED_RIGHT_SHIFT:
		case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			switch (b.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				if (b.register == 0 || b.op() == Operator.SUBTRACT)
					inst(X86.SHR, b.type.family(), b.left(), b.right(), compileContext);
				else {
					inst(X86.SHR, b.type.family(), b.left(), b.right(), compileContext);
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
				}
				break;
				
			default:
				b.type.print();
				printf("\n");
				unfinished(node, "unsigned right shift", compileContext);
			}
			break;
			
		case	NEW:
			b = ref<Binary>(node);
			assert(b.left().op() == Operator.EMPTY);
//			assert(b.right().op() == Operator.EMPTY);
			ref<Type> t = node.type.indirectType(compileContext);

			size = t.size();
			f().r.generateSpills(node, this);
			inst(X86.MOV, TypeFamily.SIGNED_64, firstRegisterArgument(), size);
			instCall(_alloc, compileContext);
			break;

		case	DELETE:
			b = ref<Binary>(node);
			assert(b.left().op() == Operator.EMPTY);
			if (b.right().type.family() == TypeFamily.INTERFACE)
				inst(X86.MOV, TypeFamily.ADDRESS, R.RDI, R.RAX);
			else {
				generate(b.right(), compileContext);
				f().r.generateSpills(node, this);
			}
			instCall(_free, compileContext);
			break;
			
		case	STORE_V_TABLE:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			if (expression.type.hasVtable(compileContext))
				storeVtable(expression.type, compileContext);
			storeITables(expression.type, 0, compileContext);
			break;
			
		case	CALL:
			generateCall(ref<Call>(node), compileContext);
			break;

		case	VACATE_ARGUMENT_REGISTERS:
			f().r.generateSpills(node, this);
			break;
			
		case	INCREMENT_BEFORE:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			if (expression.type.isFloat()) {
				if (expression.type.family() == TypeFamily.FLOAT_64) {
					inst(X86.MOVSD, expression.type.family(), expression, expression.operand(), compileContext);
					inst(X86.ADDSD, R(expression.register), _doubleOne);
					inst(X86.MOVSD, expression.type.family(), expression.operand(), expression, compileContext);
				} else {
					inst(X86.MOVSS, expression.type.family(), expression, expression.operand(), compileContext);
					inst(X86.ADDSS, R(expression.register), _floatOne);
					inst(X86.MOVSS, expression.type.family(), expression.operand(), expression, compileContext);
				}
				break;
			}
			if (expression.operand().type.isPointer(compileContext)) {
				ref<Type> t = expression.operand().type.indirectType(compileContext);
				size = t.size();
			} else
				size = 1;
			inst(X86.ADD, expression.operand(), size, compileContext);
			if (expression.register != int(R.NO_REG))
				inst(X86.MOV, R(int(expression.register)), expression.operand(), compileContext);
			break;
			
		case	DECREMENT_BEFORE:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			if (expression.type.isFloat()) {
				if (expression.type.family() == TypeFamily.FLOAT_64) {
					inst(X86.MOVSD, expression.type.family(), expression, expression.operand(), compileContext);
					inst(X86.SUBSD, R(expression.register), _doubleOne);
					inst(X86.MOVSD, expression.type.family(), expression.operand(), expression, compileContext);
				} else {
					inst(X86.MOVSS, expression.type.family(), expression, expression.operand(), compileContext);
					inst(X86.SUBSS, R(expression.register), _floatOne);
					inst(X86.MOVSS, expression.type.family(), expression.operand(), expression, compileContext);
				}
				break;
			}
			if (expression.operand().type.isPointer(compileContext)) {
				ref<Type> t = expression.operand().type.indirectType(compileContext);
				size = t.size();
			} else
				size = 1;
			inst(X86.SUB, expression.operand(), size, compileContext);
			if (expression.register != int(R.NO_REG))
				inst(X86.MOV, R(int(expression.register)), expression.operand(), compileContext);
			break;
			
		case	INCREMENT_AFTER:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			if (expression.type.isFloat()) {
				if (expression.type.family() == TypeFamily.FLOAT_64) {
					inst(X86.MOVSD, expression.type.family(), expression, expression.operand(), compileContext);
					inst(X86.ADDSD, R(expression.register), _doubleOne);
					inst(X86.MOVSD, expression.type.family(), expression.operand(), expression, compileContext);
					inst(X86.SUBSD, R(expression.register), _doubleOne);
				} else {
					inst(X86.MOVSS, expression.type.family(), expression, expression.operand(), compileContext);
					inst(X86.ADDSS, R(expression.register), _floatOne);
					inst(X86.MOVSS, expression.type.family(), expression.operand(), expression, compileContext);
					inst(X86.SUBSS, R(expression.register), _floatOne);
				}
				break;
			}
			inst(X86.MOV, expression.type.family(), expression, expression.operand(), compileContext);
			if (expression.operand().type.isPointer(compileContext)) {
				ref<Type> t = expression.operand().type.indirectType(compileContext);
				size = t.size();
			} else
				size = 1;
			inst(X86.ADD, expression.operand(), size, compileContext);
			break;
			
		case	DECREMENT_AFTER:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			if (expression.type.isFloat()) {
				if (expression.type.family() == TypeFamily.FLOAT_64) {
					inst(X86.MOVSD, expression.type.family(), expression, expression.operand(), compileContext);
					inst(X86.SUBSD, R(expression.register), _doubleOne);
					inst(X86.MOVSD, expression.type.family(), expression.operand(), expression, compileContext);
					inst(X86.ADDSD, R(expression.register), _doubleOne);
				} else {
					inst(X86.MOVSS, expression.type.family(), expression, expression.operand(), compileContext);
					inst(X86.SUBSS, R(expression.register), _floatOne);
					inst(X86.MOVSS, expression.type.family(), expression.operand(), expression, compileContext);
					inst(X86.ADDSS, R(expression.register), _floatOne);
				}
				break;
			}
			inst(X86.MOV, expression.type.family(), expression, expression.operand(), compileContext);
			if (expression.operand().type.isPointer(compileContext)) {
				ref<Type> t = expression.operand().type.indirectType(compileContext);
				size = t.size();
			} else
				size = 1;
			inst(X86.SUB, expression.operand(), size, compileContext);
			break;
			
		case	ADDRESS:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			if (expression.operand().deferGeneration())
				break;
			inst(X86.LEA, R(expression.register), expression.operand(), compileContext);
			break;
			
		case	ADDRESS_OF_ENUM:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			if (expression.operand().deferGeneration())
				break;
			instLoadEnumAddress(R(expression.register), expression.operand(), 0);
			break;

		case	INDIRECT:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			f().r.generateSpills(expression, this);
			if ((expression.nodeFlags & ADDRESS_MODE) == 0) {
				switch (node.type.family()) {
				case	FLOAT_32:
					generateLoad(X86.MOVSS, expression, compileContext);
					break;
					
				case	FLOAT_64:
					generateLoad(X86.MOVSD, expression, compileContext);
					break;
					
				default:
					generateLoad(X86.MOV, expression, compileContext);
				}
			}
			break;
			
		case	FRAME_PTR:
			if ((node.nodeFlags & ADDRESS_MODE) == 0) {
				inst(X86.MOV, TypeFamily.ADDRESS, R(node.register), R.RBP);
			}
			break;
			
		case	STACK_PTR:
			if ((node.nodeFlags & ADDRESS_MODE) == 0) {
				inst(X86.MOV, TypeFamily.ADDRESS, R(node.register), R.RSP);
			}
			break;
			
		case	MY_OUT_PARAMETER:
			if ((node.nodeFlags & ADDRESS_MODE) == 0) {
				inst(X86.MOV, R(node.register), R.RBP, f().outParameterOffset);
			}
			break;
			
		case	SUBSCRIPT:
			b = ref<Binary>(node);

			if (b.left().type.family() == TypeFamily.STRING) {
				generateOperands(b, compileContext);
				inst(X86.MOVSXD, TypeFamily.SIGNED_32, b.right(), b.right(), compileContext);
			} else
				generateSubscript(b, compileContext);
			if (node.register != 0) {
				switch (node.type.family()) {
				case	FLOAT_32:
					generateLoad(X86.MOVSS, node, compileContext);
					break;
					
				case	FLOAT_64:
					generateLoad(X86.MOVSD, node, compileContext);
					break;
					
				default:
					generateLoad(X86.MOV, node, compileContext);
				}
			}
			break;
			
		case	BIT_COMPLEMENT:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			f().r.generateSpills(expression, this);
			inst(X86.NOT, expression.operand());
			break;
			
		case	NEGATE:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			f().r.generateSpills(expression, this);
			switch (expression.type.family()) {
			case	FLOAT_32:
				inst(X86.MOVSS, R(node.register), _floatSignMask);
				inst(X86.XORPS, TypeFamily.FLOAT_32, expression, expression.operand(), compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.MOVSD, R(node.register), _doubleSignMask);
				inst(X86.XORPD, TypeFamily.FLOAT_64, expression, expression.operand(), compileContext);
				break;
				
			default:
				inst(X86.NEG, expression.operand());
			}
			break;
			
		case	UNARY_PLUS:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			f().r.generateSpills(expression, this);
			break;
			
		case	STRING:
			R dest = R(node.register);
			node.register = 0;
			inst(X86.LEA, dest, node, compileContext);
			node.register = byte(dest);
			break;

		case	BYTES:
			expression = ref<Unary>(node);
			t = expression.operand().type;
			if (t.family() == TypeFamily.TYPEDEF) {
				ref<TypedefType> tt = ref<TypedefType>(t);
				t = tt.wrappedType();
			}
			t.assignSize(this, compileContext);
			inst(X86.MOV, expression.type.family(), R(int(node.register)), t.size());
			break;
			
		case	INTEGER:
			if ((node.nodeFlags & ADDRESS_MODE) != 0)
				break;
			ref<Constant> c = ref<Constant>(node);
			switch (c.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	FLAGS:
//				printf("flaky integeer stuff\n");
//				node.print(0);
				inst(X86.MOV, impl(c.type), R(node.register), c.intValue());
				break;
				
			default:
				node.print(0);
				unfinished(node, "generate INTEGER", compileContext);
			}
			break;

		case	INTERNAL_LITERAL:
			if ((node.nodeFlags & ADDRESS_MODE) != 0)
				break;
			ref<InternalLiteral> il = ref<InternalLiteral>(node);
			switch (il.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	FLAGS:
			case	ENUM:
				inst(X86.MOV, impl(il.type), R(node.register), il.intValue());
				break;
				
			default:
				node.print(0);
				unfinished(node, "generate INTEGER", compileContext);
			}
			break;

		case	CHARACTER:
			if ((node.nodeFlags & ADDRESS_MODE) != 0)
				break;
			c = ref<Constant>(node);
			switch (c.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
				inst(X86.MOV, c.type.family(), R(int(node.register)), c.charValue());
				break;
				
			case	SIGNED_64:
			case	ADDRESS:
				inst(X86.MOV, c.type.family(), R(int(node.register)), c.charValue());
				break;
				
			default:
				node.print(0);
				unfinished(node, "generate INTEGER", compileContext);
			}
			break;
			
		case	CLASS_OF:
			expression = ref<Unary>(node);
			switch (expression.operand().type.family()) {
			case	ERROR:
				// Should generate a runtime exception here
				break;

			case	VAR:
				generate(expression.operand(), compileContext);
				inst(X86.MOV, TypeFamily.ADDRESS, expression, expression.operand(), compileContext);
				break;
				
			case	REF:
			case	POINTER:
				generate(expression.operand(), compileContext);
				if (expression.operand().op() == Operator.EMPTY)
					instLoadType(R(int(expression.register)), expression.operand().type);
				else {
					ref<Type> objType = expression.operand().type.indirectType(compileContext);
					if (objType.family() == TypeFamily.VAR) {
						inst(X86.MOV, TypeFamily.ADDRESS, expression, expression.operand(), compileContext);
						inst(X86.MOV, R(expression.register), R(expression.register), 0);
					} else if (objType.hasVtable(compileContext)) {
						inst(X86.MOV, TypeFamily.ADDRESS, expression, expression.operand(), compileContext);
						inst(X86.MOV, R(expression.register), R(expression.register), 0);
						inst(X86.MOV, R(expression.register), R(expression.register), 0);
					} else
						instLoadType(R(expression.register), expression.operand().type.indirectType(compileContext));
				}
				break;

			default:
				instLoadType(R(expression.register), expression.operand().type);
			}
			break;
			
		case	DOT:
			ref<Selection> dot = ref<Selection>(node);
			generate(dot.left(), compileContext);
			if ((node.nodeFlags & ADDRESS_MODE) != 0)
				break;
			switch (dot.type.family()) {
			case	VAR:
				node.print(0);
				assert(false);
				break;

			case	TYPEDEF:
				generateLoad(X86.LEA, dot, compileContext);
				break;
				
			case	CLASS:
				generateLoad(X86.MOV, dot, compileContext);
				break;
				
			case	FLOAT_32:
				dest = R(node.register);
				node.register = 0;
				inst(X86.MOVSS, dest, node, compileContext);
				node.register = byte(int(dest));
				break;

			case	FLOAT_64:
				dest = R(node.register);
				node.register = 0;
				inst(X86.MOVSD, dest, node, compileContext);
				node.register = byte(int(dest));
				break;

			case	FUNCTION:
				if (generateFunctionAddress(node, compileContext))
					break;

			default:
				generateLoad(X86.MOV, dot, compileContext);
			}
			break;
				
		case	FLOATING_POINT:
			dest = R(node.register);
			node.register = 0;
			if (node.type.family() == TypeFamily.FLOAT_32)
				inst(X86.MOVSS, dest, node, compileContext);
			else
				inst(X86.MOVSD, dest, node, compileContext);
			node.register = byte(dest);
			break;
			
		case	TEMPLATE_INSTANCE:
		case	IDENTIFIER:
			if ((node.nodeFlags & ADDRESS_MODE) != 0)
				break;
			if (node.type.family() == TypeFamily.FUNCTION &&
				generateFunctionAddress(node, compileContext))
				break;

		case	VARIABLE:
		case	THIS:
		case	SUPER:
			if ((node.nodeFlags & ADDRESS_MODE) != 0)
				break;
			if (node.register == 0) {
				// TODO: Get rid of this hook here.  Arises because of unpruned void context nodes.
				break;
				node.print(0);
				assert(false);
			}
			dest = R(node.register);
			node.register = 0;
			switch (node.type.family()) {
			case	TYPEDEF:
				inst(X86.LEA, dest, node, compileContext);
				break;

			case	FLOAT_32:
				inst(X86.MOVSS, dest, node, compileContext);
				break;

			case	FLOAT_64:
				inst(X86.MOVSD, dest, node, compileContext);
				break;
				
			default:
				inst(X86.MOV, dest, node, compileContext);
			}
			node.register = byte(int(dest));
			break;

		case	NULL:
		case	TRUE:
		case	FALSE:
			inst(X86.MOV, node.type.family(), R(int(node.register)), node.op() == Operator.TRUE ? 1 : 0);
			break;

		case	CAST:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			generateCoercion(expression, expression.operand(), compileContext);
			break;

		case	LOAD:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			f().r.generateSpills(node, this);
			break;

		case	STACK_ARGUMENT:
			generatePush(ref<Unary>(node).operand(), compileContext);
			f().r.generateSpills(node, this);
			break;

		case	ELLIPSIS_ARGUMENTS:
			generateEllipsisArguments(ref<EllipsisArguments>(node), compileContext);
			break;

		case	CALL_DESTRUCTOR:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			f().r.generateSpills(node, this);
			ref<Unary> objectAddress = ref<Unary>(expression.operand());
			ref<Type> actual = objectAddress.operand().type;
			if (actual.hasDestructor())
				instCall(actual.scope().destructor(), compileContext);
			break;

		default:
			node.print(0);
			assert(false);
		}
	}

	private static boolean containsNestedMultiReturn(ref<Node> node) {
		if (node.op() != Operator.SEQUENCE)
			return false;
		ref<Binary> b = ref<Binary>(node);
		if (b.left().op() != Operator.CALL)
			return false;
		return ref<Call>(b.left()).isNestedMultiReturn();		
	}
	
	private void generateLiveSymbolDestructors(ref<NodeList> liveSymbols, ref<CompileContext> compileContext) {
		while (liveSymbols != null) {
			if (liveSymbols.node.op() == Operator.LOCK) {
				ref<LockScope> lockScope = ref<LockScope>(ref<Block>(liveSymbols.node).scope);
				ref<Node> defn = compileContext.tree().newReference(lockScope.lockTemp, false, liveSymbols.node.location());
				inst(X86.MOV, firstRegisterArgument(), defn, compileContext);
				instCall(releaseMethod(compileContext), compileContext);
			} else {
				inst(X86.LEA, firstRegisterArgument(), liveSymbols.node, compileContext);
				instCall(liveSymbols.node.type.scope().destructor(), compileContext);
			}
			liveSymbols = liveSymbols.next;
		}
	}

	private void generateNestedMultiReturn(ref<FunctionType> funcType, ref<Node> value, ref<CompileContext> compileContext) {
		generate(ref<Binary>(value).left(), compileContext);
		f().r.generateSpills(ref<Binary>(value).left(), this);
		ref<Node> temp = ref<Binary>(value).right();
		inst(X86.LEA, secondRegisterArgument(), temp, compileContext);
		inst(X86.MOV, firstRegisterArgument(), R.RBP, f().outParameterOffset);
		inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), funcType.returnSize(this, compileContext));
		instCall(_memcpy, compileContext);
	}
	
	private void generateOutParameter(ref<Node> value, int outOffset, ref<CompileContext> compileContext) {
		if (value.deferGeneration()) {
			// TODO: Generate compile-caused exception
			return;
		}
		if (value.op() == Operator.SEQUENCE) {
			generate(ref<Binary>(value).left(), compileContext);
			generateOutParameter(ref<Binary>(value).right(), outOffset, compileContext);
		} else if (value.register != 0) {
			if (value.type.family() == TypeFamily.VAR) {
				assert(value.op() == Operator.VARIABLE);
				generateLoad(X86.MOV, value, compileContext);
				if (value.register == int(R.RAX)) {
					inst(X86.MOV, firstRegisterArgument(), R.RBP, f().outParameterOffset);
					inst(X86.MOV, value.type.family(), firstRegisterArgument(), outOffset, R(int(value.register)));
				} else {
					inst(X86.MOV, R.RAX, R.RBP, f().outParameterOffset);
					inst(X86.MOV, value.type.family(), R.RAX, outOffset, R(int(value.register)));
				}
				generateLoad(X86.MOV, value, address.bytes);
				if (value.register == int(R.RAX))
					inst(X86.MOV, value.type.family(), firstRegisterArgument(), outOffset + address.bytes, R(int(value.register)));
				else
					inst(X86.MOV, value.type.family(), R.RAX, outOffset + address.bytes, R(int(value.register)));
			} else {
				generate(value, compileContext);
				f().r.generateSpills(value, this);
				if (!value.type.isFloat() && value.register == int(R.RAX)) {
					inst(X86.MOV, firstRegisterArgument(), R.RBP, f().outParameterOffset);
					inst(X86.MOV, value.type.family(), firstRegisterArgument(), outOffset, R(int(value.register))); 
				} else {
					inst(X86.MOV, R.RAX, R.RBP, f().outParameterOffset);
					switch (value.type.family()) {
					case	FLOAT_32:
						inst(X86.MOVSS, value.type.family(), R.RAX, outOffset, R(int(value.register)));
						break;

					case	FLOAT_64:
						inst(X86.MOVSD, value.type.family(), R.RAX, outOffset, R(int(value.register)));
						break;
						
					default:
						inst(X86.MOV, value.type.family(), R.RAX, outOffset, R(int(value.register)));
					}
				}
			}
		} else if (value.isLvalue()) {
			value.nodeFlags |= ADDRESS_MODE;
			generate(value, compileContext);
			f().r.generateSpills(value, this);
			inst(X86.LEA, secondRegisterArgument(), value, compileContext);
			inst(X86.MOV, firstRegisterArgument(), R.RBP, f().outParameterOffset);
			if (outOffset > 0)
				inst(X86.ADD, TypeFamily.ADDRESS, firstRegisterArgument(), outOffset);
			inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), value.type.size());
			instCall(_memcpy, compileContext);
		} else {
			value.print(0);
			assert(false);
		}
	}
	
	private boolean generateFunctionAddress(ref<Node> node, ref<CompileContext> compileContext) {
		ref<Symbol> symbol = node.symbol();
		if (symbol == null || symbol.class !<= OverloadInstance)
			return false;
		ref<OverloadInstance> functionSym = ref<OverloadInstance>(symbol);
		return instLoadFunctionAddress(R(int(node.register)), functionSym.parameterScope(), compileContext);
	}

	private void generateStaticInitializers(ref<Node> node, ref<CompileContext> compileContext) {
		if (node.deferGeneration())
			return;
//		printf("-----  generate  ---------\n");
//		node.print(4);
		switch (node.op()) {
		case	PUBLIC:
		case	PRIVATE:
		case	PROTECTED:
		case	FINAL:
		case	STATIC:
		case	ABSTRACT:
			ref<Unary> u = ref<Unary>(node);
			generateStaticInitializers(u.operand(), compileContext);
			break;
			
		case	ANNOTATED:
			b = ref<Binary>(node);
			generateStaticInitializers(b.right(), compileContext);
			break;
			
		case	DECLARATION:
			ref<Binary> b = ref<Binary>(node);
			emitSourceLocation(compileContext.current().file(), node.location());
			generateStaticInitializers(b.right(), compileContext);
			break;

		case	CLASS_DECLARATION:
			b = ref<Binary>(node);
			node = b.right();			// Get the CLASS node
			if (node.op() != Operator.CLASS)
				break;

		case	ENUM:
			ref<Class> classNode = ref<Class>(node);
			if (node.op() == Operator.ENUM) {
				ref<EnumScope> escope = ref<EnumScope>(classNode.scope);
				if (escope.enumType.hasConstructors()) {
					ref<Node> n = classNode.extendsClause();
					generateEnumConstructors(n, compileContext);
				}
			}
			for (ref<NodeList> nl = classNode.statements(); nl != null; nl = nl.next)
				generateStaticInitializers(nl.node, compileContext);
			break;
			
		case	MONITOR_CLASS:
			b = ref<Binary>(node);
			switch (b.right().op()) {
			case	EMPTY:
				break;

			case	CLASS:
				classNode = ref<Class>(b.right());
			
				for (ref<NodeList> nl = classNode.statements(); nl != null; nl = nl.next)
					generateStaticInitializers(nl.node, compileContext);
			}
			break;

		case	INITIALIZE:
			b = ref<Binary>(node);
			ref<Symbol> sym = b.left().symbol();
			if (sym.storageClass() == StorageClass.STATIC)
				generateInitializers(node, compileContext);
			break;

		case	IDENTIFIER:
		case	FUNCTION:
		case	EMPTY:
		case	INTERFACE_DECLARATION:
		case	FLAGS_DECLARATION:
			// The ones below here only show up in mal-formed class declarations.
		case	BLOCK:
		case	SCOPED_FOR:
		case	EXPRESSION:
		case	SWITCH:
		case	FOR:
		case	DESTRUCTOR_LIST:
		case	IF:
		case	ASSIGN:
		case	DIVIDE_ASSIGN:
		case	REMAINDER_ASSIGN:
		case	MULTIPLY_ASSIGN:
		case	ADD_ASSIGN:
		case	SUBTRACT_ASSIGN:
		case	AND_ASSIGN:
		case	OR_ASSIGN:
		case	EXCLUSIVE_OR_ASSIGN:
		case	LOCK:
		case	SYNTAX_ERROR:
		case	CLASS_CLEAR:
			break;
			
		case	SEQUENCE:
			b = ref<Binary>(node);
			generateStaticInitializers(b.left(), compileContext);
			generateStaticInitializers(b.right(), compileContext);
			break;

		case	CLASS_COPY:
			
		case	CALL:			// must be a constructor
			generateInitializers(node, compileContext);
			break;
			
		default:
			node.print(0);
			assert(false);
		}
	}
	
	private void generateEnumConstructors(ref<Node> n, ref<CompileContext> compileContext) {
		switch (n.op()) {
		case SEQUENCE:
			ref<Binary> b = ref<Binary>(n);
			generateEnumConstructors(b.left(), compileContext);
			generateEnumConstructors(b.right(), compileContext);
			break;

		case IDENTIFIER:
			if (n.type == null)
				break;

			emitSourceLocation(compileContext.current().file(), n.location());
			ref<ParameterScope> constructor = n.type.defaultConstructor();
			if (constructor != null) {
				instLoadEnumAddress(firstRegisterArgument(), n, n.symbol().offset);
				instCall(constructor, compileContext);
			}
			break;

		case CALL:
			emitSourceLocation(compileContext.current().file(), n.location());
			generateInitializers(n, compileContext);
			break;
		}
	}

	private void generateOperands(ref<Binary> b, ref<CompileContext> compileContext) {
		if (b.sethi < 0) {
			generate(b.left(), compileContext);
			generate(b.right(), compileContext);
		} else {
			generate(b.right(), compileContext);
			generate(b.left(), compileContext);
		}
		f().r.generateSpills(b, this);
	}

	private void generateLoad(X86 instruction, ref<Node> expression, ref<CompileContext> compileContext) {
		R reg = R(expression.register);
		expression.register = 0;
		inst(instruction, reg, expression, compileContext);
		expression.register = byte(reg);
	}

	private void generateLoad(X86 instruction, ref<Node> expression, int offset) {
		R reg = R(expression.register);
		expression.register = 0;
		inst(instruction, expression.type, reg, expression, offset);
		expression.register = byte(reg);
	}

	private void generateSubscript(ref<Binary> x, ref<CompileContext> compileContext) {
		ref<Type> t = x.left().type.indirectType(compileContext);
		if (t != null) {
			generateOperands(x, compileContext);
			t.assignSize(this, compileContext);
			switch (t.size()) {
			case	1:
			case	2:
			case	4:
			case	8:
				if (x.right().type.size() < address.bytes)
					inst(X86.MOVSXD, x.right().type.family(), x.right(), x.right(), compileContext);
				break;
				
			default:
				x.print(0);
				assert(false);
			}
		} else {
			x.print(0);
			assert(false);
		}
	}

	private void generateConditional(ref<Node> node, ref<CodeSegment> trueSegment, ref<CodeSegment> falseSegment, ref<CompileContext> compileContext) {
		if (node.deferGeneration())
			return;
		if (verbose()) {
			printf("-----  generateConditional  ---------\n");
			f().r.print();
			node.print(4);
		}
		switch (node.op()) {
		case	EQUALITY:
		case	LESS:
		case	GREATER:
		case	LESS_EQUAL:
		case	GREATER_EQUAL:
		case	LESS_GREATER:
		case	LESS_GREATER_EQUAL:
		case	NOT_EQUAL:
		case	NOT_LESS:
		case	NOT_GREATER:
		case	NOT_LESS_EQUAL:
		case	NOT_GREATER_EQUAL:
		case	NOT_LESS_GREATER:
		case	NOT_LESS_GREATER_EQUAL:
			ref<Binary> b = ref<Binary>(node);
			generateCompare(b, trueSegment, falseSegment, compileContext);
			break;
			
		case	LOGICAL_AND:
			b = ref<Binary>(node);
			ref<CodeSegment> secondTest = _storage new CodeSegment;
			generateConditional(b.left(), secondTest, falseSegment, compileContext);
			secondTest.start(this);
			generateConditional(b.right(), trueSegment, falseSegment, compileContext);
			return;
			
		case	LOGICAL_OR:
			b = ref<Binary>(node);
			secondTest = _storage new CodeSegment;
			generateConditional(b.left(), trueSegment, secondTest, compileContext);
			secondTest.start(this);
			generateConditional(b.right(), trueSegment, falseSegment, compileContext);
			return;
			
		case	LEFT_COMMA:
			b = ref<Binary>(node);
			generate(b.left(), compileContext);
			generate(b.right(), compileContext);
			f().r.generateSpills(b, this);
			inst(X86.CMP, b.left(), 0, compileContext);
			generateConditionalJump(Operator.NOT_EQUAL, b.left().type, trueSegment, falseSegment, compileContext);
			break;
			
		case	NOT:
			ref<Unary> u = ref<Unary>(node);
			generateConditional(u.operand(), falseSegment, trueSegment, compileContext);
			return;
			
		case	CALL:
			generate(node, compileContext);
			inst(X86.CMP, node, 0, compileContext);
			closeCodeSegment(CC.JE, falseSegment);
			break;
			
		case	SEQUENCE:
			b = ref<Binary>(node);
			generate(b.left(), compileContext);
			generate(b.right(), compileContext);
			f().r.generateSpills(b, this);
			inst(X86.CMP, b.right(), 0, compileContext);
			generateConditionalJump(Operator.NOT_EQUAL, b.right().type, trueSegment, falseSegment, compileContext);
			break;
			
		case	DOT:
			ref<Selection> dot = ref<Selection>(node);
			generate(dot.left(), compileContext);
			
		case	IDENTIFIER:
			inst(X86.CMP, node, 0, compileContext);
			closeCodeSegment(CC.JE, falseSegment);
			break;
			
		case	TRUE:
			closeCodeSegment(CC.JMP, trueSegment);
			break;
			
		case	FALSE:
			closeCodeSegment(CC.JMP, falseSegment);
			break;
			
		default:
			printf("generateConditional\n");
			node.print(0);
			assert(false);
		}
		ref<CodeSegment> insurance = _storage new CodeSegment;
		insurance.start(this);
		closeCodeSegment(CC.JMP, trueSegment);
	}

	private void generateCompare(ref<Binary> b, ref<CodeSegment> trueSegment, ref<CodeSegment> falseSegment, ref<CompileContext> compileContext) {
		if ((b.nodeFlags & USE_COMPARE_METHOD) != 0) {
			ref<OverloadInstance> oi = ref<ClassType>(b.left().type).getCompareMethod(compileContext);
			f().r.generateSpills(b, this);
			if (b.sethi < 0) {
				generate(b.left(), compileContext);
				if (b.left().isLvalue()) {
					R result = R(b.left().register);
					b.left().register = 0;
					inst(X86.LEA, result, b.left(), compileContext);
				} else {
					b.print(0);
					assert(false);
				}
				generate(b.right(), compileContext);
				if (b.right().isLvalue()) {
					R result = R(b.right().register);
					b.right().register = 0;
					inst(X86.LEA, result, b.right(), compileContext);
				} else {
					b.print(0);
					assert(false);
				}
			} else {
				generate(b.right(), compileContext);
				if (b.right().isLvalue()) {
					R result = R(b.right().register);
					b.right().register = 0;
					inst(X86.LEA, result, b.right(), compileContext);
				} else {
					b.print(0);
					assert(false);
				}
				generate(b.left(), compileContext);
				if (b.left().isLvalue()) {
					R result = R(b.left().register);
					b.left().register = 0;
					inst(X86.LEA, result, b.left(), compileContext);
				} else {
					b.print(0);
					assert(false);
				}
			}
			instCall(oi.parameterScope(), compileContext);
			ref<Type> t = oi.parameterScope().type().returnType().node.type;
			switch (t.family()) {
			case	BOOLEAN:
				inst(X86.XOR, TypeFamily.BOOLEAN, R.RAX, 1);
				inst(X86.CMP, TypeFamily.BOOLEAN, R.RAX, 0);
				break;

			case	FLOAT_32:
				inst(X86.UCOMISS, R.XMM0, _floatZero);
				break;

			case	FLOAT_64:
				inst(X86.UCOMISD, R.XMM0, _doubleZero);
				break;

			default:
				inst(X86.CMP, t.family(), R.RAX, 0);
			}
			generateConditionalJump(b.op(), t, trueSegment, falseSegment, compileContext);
		} else {
			generateOperands(b, compileContext);
			generateCompareInst(b, compileContext);
			generateConditionalJump(b.op(), b.left().type, trueSegment, falseSegment, compileContext);
		}
	}
	
	private void generateCompareInst(ref<Binary> b, ref<CompileContext> compileContext) {
		switch (b.left().type.family()) {
		case	ERROR:
			// This hsould generate a runtime exception here
			break;

		case	FLAGS:
		case	ENUM:
		case	UNSIGNED_32:
		case	SIGNED_32:
		case	SIGNED_64:
		case	CLASS:
		case	TYPEDEF:
		case	ADDRESS:
		case	CLASS_VARIABLE:
		case	REF:
		case	POINTER:
		case	BOOLEAN:
		case	FUNCTION:
		case	INTERFACE:
			inst(X86.CMP, impl(b.left().type), b.left(), b.right(), compileContext);
			break;
			
		case	FLOAT_32:
			inst(X86.UCOMISS, b.left().type.family(), b.left(), b.right(), compileContext);
			break;
			
		case	FLOAT_64:
			inst(X86.UCOMISD, b.left().type.family(), b.left(), b.right(), compileContext);
			break;
			
		default:
			b.print(0);
			assert(false);
		}
	}
	
	private void generateConditionalJump(Operator op, ref<Type> type, ref<CodeSegment> trueSegment, ref<CodeSegment> falseSegment, ref<CompileContext> compileContext) {
		CC parityJump = parityTest(op, type);
		switch (parityJump) {
		case	NOP:
			closeCodeSegment(continuation(invert(op), type), falseSegment);
			break;
			
		case	JP:
			closeCodeSegment(continuation(op, type), trueSegment);
			closeCodeSegment(CC.JNP, falseSegment);
			break;
			
		case	JNP:
			closeCodeSegment(continuation(invert(op), type), falseSegment);
			closeCodeSegment(CC.JP, falseSegment);
			break;
			
		default:
			assert(false);
		}
	}
	
	private void generateInitializers(ref<Node> node, ref<CompileContext> compileContext) {
//		printf("generateInitializers\n");
//		node.print(4);
		boolean hasDefaultConstructor = false;
		if (node.type == null)		// static initiailizers in templates can generate this.
			compileContext.assignTypes(node);
		if (node.deferGeneration()) {
			// TODO: make this generate a runtime exception
			return;
		}
		switch (node.op()) {
		case	IDENTIFIER:
		case	VARIABLE:
			break;

		case	SEQUENCE:
			ref<Binary> seq = ref<Binary>(node);
			generateInitializers(seq.left(), compileContext);
			generateInitializers(seq.right(), compileContext);
			break;

		case	CALL:
			markAddressModes(node, compileContext);
			sethiUllman(node, compileContext, this);
			assignVoidContext(node, compileContext);
			generateCall(ref<Call>(node), compileContext);
			break;
			
		case	CLASS_CLEAR:
			ref<Unary> u = ref<Unary>(node);
			if (node.type.hasVtable(compileContext)) {
				inst(X86.MOV, firstRegisterArgument(), u.operand(), compileContext);
				storeVtable(node.type, compileContext);
				if (node.type.size() > address.bytes) {
					inst(X86.ADD, TypeFamily.ADDRESS, firstRegisterArgument(), address.bytes);
					inst(X86.XOR, TypeFamily.UNSIGNED_16, secondRegisterArgument(), secondRegisterArgument());
					inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), node.type.size() - address.bytes);
					instCall(_memset, compileContext);
				}
			} else if (node.type.size() > 0) {
				inst(X86.MOV, firstRegisterArgument(), u.operand(), compileContext);
				inst(X86.XOR, TypeFamily.UNSIGNED_16, secondRegisterArgument(), secondRegisterArgument());
				inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), node.type.size());
				instCall(_memset, compileContext);
			} else if (node.type.interfaceCount() > 0)
				inst(X86.MOV, firstRegisterArgument(), u.operand(), compileContext);
			storeITables(node.type, 0, compileContext);
			break;
			
		case	CLASS_COPY:
			markAddressModes(node, compileContext);
			sethiUllman(node, compileContext, this);
			assignVoidContext(node, compileContext);
			ref<Binary> b = ref<Binary>(node);
			generateOperands(b, compileContext);
			inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), b.type.size());
			instCall(_memcpy, compileContext);
			break;

		case	DESTRUCTOR_LIST:
			ref<DestructorList> dl = ref<DestructorList>(node);
			generateLiveSymbolDestructors(dl.arguments(), compileContext);
			break;

		case	EMPTY:
			break;
			
		case	ASSIGN:
//			printf("Initialize:\n");
//			node.print(4);
//			print("!!--\n");
			markAddressModes(node, compileContext);
//			print("--\n");
			sethiUllman(node, compileContext, this);
//			printf("Initialize:\n");
//			node.print(4);
//			print("<<--\n");
			assignVoidContext(node, compileContext);
			seq = ref<Binary>(node);
			if (seq.right().op() == Operator.CALL) {
				ref<Call> call = ref<Call>(seq.right());
//				printf("RHS...\n");
//				call.print(0);
				if (call.commentary() != null) {
					generate(call, compileContext);
					break;
				}
				if (call.target() == null) {
					// This can arise as a result of a compile-time error in the call, such as 'no 
					// matching definition'.
					// TODO: Generate the appropriate 'throw' statement.
					break;
				} else if (call.category() == CallCategory.CONSTRUCTOR) {
					call.print(0);
					assert(false);
				}
//				printf("not a special case\n");
			}
//			printf("generateInitializers:\n");
//			seq.print(4);
			generate(seq, compileContext);
			break;

		case	INITIALIZE:
			if (node.type == null) {
				unfinished(node, "initialize type == null", compileContext);
				break;
			}
//			printf("Initialize:\n");
//			node.print(4);
//			print("!!--\n");
			markAddressModes(node, compileContext);
//			print("--\n");
			sethiUllman(node, compileContext, this);
//			printf("Initialize:\n");
//			node.print(4);
//			print("<<--\n");
			assignVoidContext(node, compileContext);
			seq = ref<Binary>(node);
			if (seq.right().op() == Operator.CALL) {
				ref<Call> call = ref<Call>(seq.right());
//				printf("RHS...\n");
//				call.print(0);
				if (call.commentary() != null) {
					generate(call, compileContext);
					break;
				}
				if (call.target() == null) {
					// This can arise as a result of a compile-time error in the call, such as 'no 
					// matching definition'.
					// TODO: Generate the appropriate 'throw' statement.
					break;
				} else if (call.category() == CallCategory.CONSTRUCTOR) {
					call.print(0);
					assert(false);
				}
//				printf("not a special case\n");
			}
			switch (seq.type.family()) {
			case	STRING:
				node.print(0);
				assert(false);
				break;
				
			case	FLAGS:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	BOOLEAN:
			case	ENUM:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
//				seq.print(0);
				generateOperands(seq, compileContext);
				f().r.generateSpills(seq, this);
				inst(X86.MOV, impl(seq.type), seq.left(), seq.right(), compileContext);
				break;
				
			case	FLOAT_32:
				generate(seq.right(), compileContext);
//				printf("Spilling...\n");
//				seq.print(0);
				f().r.generateSpills(seq, this);
				inst(X86.MOVSS, TypeFamily.FLOAT_32, seq.left(), seq.right(), compileContext);
				break;
				
			case	FLOAT_64:
				generate(seq.right(), compileContext);
//				printf("Spilling...\n");
//				seq.print(0);
				f().r.generateSpills(seq, this);
				inst(X86.MOVSD, TypeFamily.FLOAT_64, seq.left(), seq.right(), compileContext);
				break;
				
			case	CLASS:
				generateOperands(seq, compileContext);
				inst(X86.MOV, seq.left(), R(int(seq.right().register)), compileContext);
				break;
				
			case	TYPEDEF:
				break;
				
			default:
				seq.print(0);
				assert(false);
			}
			break;

		default:
			node.print(0);
			assert(false);
		}
	}

	private void generateExpressionStatement(ref<Node> node, ref<CompileContext> compileContext) {
		if (node.deferGeneration()) {
			// TODO: make this generate a runtime exception
			return;
		}
		emitSourceLocation(compileContext.current().file(), node.location());
		if (verbose()) {
//			node.print(4);
			printf("-----  markAddressModes  ---------\n");
//			f().r.print();
		}
		markAddressModes(node, compileContext);
		if (verbose()) {
//			node.print(4);
			printf("-----  sethiUllman  ---------\n");
//			f().r.print();
		}
		sethiUllman(node, compileContext, this);
		if (verbose()) {
			node.print(4);
			printf("-----  assignVoidContext  ---------\n");
//			f().r.print();
		}
		assignVoidContext(node, compileContext);		// Take the result in any register available.
		generate(node, compileContext);
	}
	
	private void generateCall(ref<Call> call, ref<CompileContext> compileContext) {
		int cleanup = 0;
		int stackPushes = 0;
		int stackAlignment = 0;
		for (ref<NodeList> args = call.stackArguments(); args != null; args = args.next) {
			if (args.node.op() == Operator.ELLIPSIS_ARGUMENTS)
				cleanup = ref<EllipsisArguments>(args.node).stackConsumed();
			else
				stackPushes += args.node.type.stackSize();
		}
		for (ref<NodeList> args = call.stackArguments(); args != null; args = args.next) {
			generate(args.node, compileContext);
			if (args.node.op() == Operator.VACATE_ARGUMENT_REGISTERS) {
				int depth = f().r.bytesPushed();
				stackAlignment = (stackPushes + cleanup + depth + f().stackAdjustment) & 15;
				// The only viable stack alignment value has to be 16, anything else is a compiler bug.
				if (stackAlignment != 0) {
					assert(stackAlignment == 8);
					cleanup += 8;
					f().stackAdjustment += stackAlignment;
					inst(X86.SUB, TypeFamily.ADDRESS, R.RSP, 8);
				}
			}
		}

		if (call.arguments() != null) {
			// Now the register arguments.  They're pretty easy
			for (ref<NodeList> args = call.arguments(); args != null; args = args.next)
				generate(args.node, compileContext);
		}
		f().r.generateSpills(call, this);

		ref<ParameterScope> overload = call.overload();
		
		switch (call.category()) {
		case	CONSTRUCTOR:
			if (overload == null)
				return;
			if (call.target() == null || call.target().op() != Operator.SUPER) {
				if (call.type.hasVtable(compileContext))
					storeVtable(call.type, compileContext);
				storeITables(call.type, 0, compileContext);
			}
			if (!instCall(overload, compileContext)) {
				call.print(0);
				assert(false);
				return;
			}
			break;

		case	DESTRUCTOR:
			if (overload.usesVTable(compileContext)) {
				inst(X86.MOV, R.RAX, firstRegisterArgument(), 0);
				inst(X86.CALL, TypeFamily.ADDRESS, R.RAX, address.bytes);
			} else {
				if (!instCall(overload, compileContext)) {
					call.print(0);
					assert(false);
					return;
				}
			}
			break;
			
		case	METHOD_CALL:
			if (isVirtualCall(call, compileContext)) {
				inst(X86.MOV, R.RAX, firstRegisterArgument(), 0);
				inst(X86.CALL, TypeFamily.ADDRESS, R.RAX, overload.symbol().offset * address.bytes);
				break;
			}
			
		case	FUNCTION_CALL:
			ref<Node> func = call.target();
			assert(func != null);
			if (func.type.family() == TypeFamily.VAR) {
				if (func.op() == Operator.DOT) {
					ref<Selection> f = ref<Selection>(func);
					ref<Node> left = f.left();
					if (left.type.family() == TypeFamily.VAR) {
						call.print(4);
						assert(false);
						return;
					}
				}
				call.print(4);
				assert(false);
			}
			if (overload != null)
				instCall(overload, compileContext);
			else
				inst(X86.CALL, func);
			break;
			
		default:
			call.print(0);
			assert(false);
		}
		if (cleanup != 0) {
			f().stackAdjustment -= stackAlignment;
			inst(X86.ADD, TypeFamily.SIGNED_64, R.RSP, cleanup);		// What about destructors?
		}
	}

	private boolean isVirtualCall(ref<Call> call, ref<CompileContext> compileContext) {
		if (call.overload().usesVTable(compileContext)) {
			switch (call.target().op()) {
			case	DOT:
				ref<Selection> dot = ref<Selection>(call.target());
				return dot.left().op() != Operator.SUPER;

			case	IDENTIFIER:
				return true;
			}
		}
		return false;
	}
	
	private void generateEllipsisArguments(ref<EllipsisArguments> ea, ref<CompileContext> compileContext) {
		int vargCount = ea.argumentCount();
		ea.type.assignSize(this, compileContext);
		inst(X86.SUB, TypeFamily.SIGNED_64, R.RSP, ea.stackConsumed());
		// TODO: Zero out the memory
		int offset = 0;
		if (vargCount > 0) {
			for (ref<NodeList> args = ea.arguments(); args != null; args = args.next, offset += ea.type.size()) {
				ref<Unary> u = ref<Unary>(args.node);
				// u is the ELLIPSIS_ARGUMENT
				ref<Node> n = u.operand();
				switch (n.type.family()) {
				case	STRING:
					generate(n, compileContext);
					f().r.generateSpills(args.node, this);
					inst(X86.LEA, firstRegisterArgument(), R.RSP, offset);
					instCall(_stringCopyConstructor.parameterScope(), compileContext);
					break;
					
				case	VAR:
					generatePush(n, compileContext);
					f().r.generateSpills(args.node, this);
					inst(X86.LEA, firstRegisterArgument(), R.RSP, offset + var.bytes);
					instCall(_varCopyConstructor.parameterScope(), compileContext);
					break;
					
				case	CLASS:
					if (n.type.indirectType(compileContext) == null) {
						generateValueToStack(u, offset, compileContext);
						break;
					}
					
				default:
					generate(n, compileContext);
					f().r.generateSpills(args.node, this);
					if (n.register != 0)
						inst(X86.MOV, n.type.family(), R.RSP, offset, R(int(n.register)));
					else
						inst(X86.PUSH, n, compileContext);
				}
			}
		}
		inst(X86.PUSH, TypeFamily.SIGNED_64, R.RSP);
		inst(X86.MOV, TypeFamily.SIGNED_64, R.RAX, (long(vargCount) << 32) | vargCount);
		inst(X86.PUSH, TypeFamily.SIGNED_64, R.RAX);
	}

	private void generateValueToStack(ref<Node> ellipsisArgumentNode, int offset, ref<CompileContext> compileContext) {
		if (ellipsisArgumentNode.register == 0) {
			printf("This expression needs a register assigned:\n");
			ellipsisArgumentNode.print(4);
			assert(false);
		}
		ref<Node> node = ref<Unary>(ellipsisArgumentNode).operand();
		int size = node.type.size();
		switch (node.op()) {
		case	INDIRECT:
		case	IDENTIFIER:
			generate(node, compileContext);
			break;
			
		case	SEQUENCE:
			ref<Binary> b = ref<Binary>(node);
			generate(b.left(), compileContext);
			generatePush(b.right(), compileContext);
			return;
			
		default:
			ellipsisArgumentNode.print(0);
			assert(false);
		}
		int objectOffset = 0;
		for (; size >= long.bytes; objectOffset += long.bytes, size -= long.bytes) {
			inst(X86.MOV, compileContext.arena().builtInType(TypeFamily.ADDRESS), R(ellipsisArgumentNode.register), node, objectOffset);
			inst(X86.MOV, TypeFamily.ADDRESS, R.RSP, offset + objectOffset, R(ellipsisArgumentNode.register));
		}
		if (size >= int.bytes) {
			inst(X86.MOV, compileContext.arena().builtInType(TypeFamily.SIGNED_32), R(ellipsisArgumentNode.register), node, objectOffset);
			inst(X86.MOV, TypeFamily.SIGNED_32, R.RSP, offset + objectOffset, R(ellipsisArgumentNode.register));
			size -= int.bytes;
			objectOffset += int.bytes;
		}
		if (size >= short.bytes) {
			inst(X86.MOV, compileContext.arena().builtInType(TypeFamily.SIGNED_16), R(ellipsisArgumentNode.register), node, objectOffset);
			inst(X86.MOV, TypeFamily.SIGNED_16, R.RSP, offset + objectOffset, R(ellipsisArgumentNode.register));
			size -= short.bytes;
			objectOffset += short.bytes;
		}
		if (size > 0) {
			inst(X86.MOV, compileContext.arena().builtInType(TypeFamily.UNSIGNED_8), R(ellipsisArgumentNode.register), node, offset);
			inst(X86.MOV, TypeFamily.UNSIGNED_8, R.RSP, offset, R(ellipsisArgumentNode.register));
		}
	}
	
	private void generatePush(ref<Node> node, ref<CompileContext> compileContext) {
		int size = node.type.stackSize();
		switch (node.op()) {
		case	SUBSCRIPT:
			b = ref<Binary>(node);
			if (node.sethi < 0) {
				generate(b.left(), compileContext);
				generate(b.right(), compileContext);
			} else {
				generate(b.right(), compileContext);
				generate(b.left(), compileContext);
			}
			break;
			
		case	INDIRECT:
			ref<Unary> u = ref<Unary>(node);
			generate(u.operand(), compileContext);
			
		case	IDENTIFIER:
		case	VARIABLE:
			break;
			
		case	DOT:
			ref<Selection> dot = ref<Selection>(node);
			generate(dot.left(), compileContext);
			break;
			
		case	CALL:
			ref<Call> call = ref<Call>(node);
			if ((call.nodeFlags & PUSH_OUT_PARAMETER) != 0)
				inst(X86.SUB, TypeFamily.SIGNED_64, R.RSP, call.type.stackSize());
			generate(call, compileContext);
			assert(node != null);
			if (node == null)
				return;
			break;
	
		case	SEQUENCE:
			ref<Binary> b = ref<Binary>(node);
			generate(b.left(), compileContext);
			generatePush(b.right(), compileContext);
			return;
			
		case	NULL:
		case	FALSE:
			inst(X86.PUSH, 0);
			return;
			
		case	TRUE:
			inst(X86.PUSH, 1);
			return;
			
		case	THIS:
		case	SUPER:
			inst(X86.PUSH, TypeFamily.ADDRESS, thisRegister());
			return;
			
		case	CAST:
		case	BYTES:
		case	ADDRESS:
		case	NEGATE:
		case	INTEGER:
		case	INTERNAL_LITERAL:
		case	MULTIPLY:
		case	ADD:
		case	SUBTRACT:
		case	AND:
		case	OR:
		case	CONDITIONAL:
		case	STRING:
			generate(node, compileContext);
			inst(X86.PUSH, TypeFamily.ADDRESS, R(int(node.register)));
			return;
			
		case	FLOATING_POINT:
			generate(node, compileContext);
			inst(X86.SUB, TypeFamily.SIGNED_64, R.RSP, 8);
			inst(X86.MOVSD, TypeFamily.SIGNED_64, R.RSP, 0, R(node.register));
			return;
			
		default:
			node.print(0);
			assert(false);
		}
		for (int i = size; i > 0; i -= long.bytes)
			instPush(node, i - long.bytes);
	}
	
	private void generateCoercion(ref<Node> result, ref<Node> n, ref<CompileContext> compileContext) {
		ref<Type> existingType = n.type;
		ref<Type> newType = result.type;
		
		f().r.generateSpills(result, this);
		if (existingType.family() == TypeFamily.ENUM && newType.family() == TypeFamily.STRING) {
			ref<EnumInstanceType> t = ref<EnumInstanceType>(existingType);
			instCall(t.toStringMethod(this, compileContext), compileContext);
			return;
		}
		switch (impl(existingType)) {
		case	ERROR:
			// TODO: Generate a runtime exception here.
			return;

		case	BOOLEAN:
		case	UNSIGNED_8:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.UNSIGNED_8, result, n, compileContext);
				return;

			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				if (R(n.register) == R.AH) {
					// The only way that AH could get assigned is to use the result of a byte-% operator
					inst(X86.MOV, TypeFamily.UNSIGNED_8, R.RAX, R.AH);
					inst(X86.AND, newType.family(), R.RAX, 0xff);
				} else {
					if (result.register == 0) {
						result.print(0);
					}
					inst(X86.AND, newType.family(), R(result.register), 0xff);
				}
				return;
				
			case	FLOAT_32:
			case	FLOAT_64:
				R src;
				if (R(int(n.register)) == R.AH) {
					// The only way that AH could get assigned is to use the result of a byte-% operator
					inst(X86.MOV, TypeFamily.UNSIGNED_8, R.RAX, R.AH);
					inst(X86.AND, TypeFamily.SIGNED_32, R.RAX, 0xff);
					src = R.RAX;
				} else {
					inst(X86.AND, TypeFamily.SIGNED_32, R(n.register), 0xff);
					src = R(n.register);
				}
				if (newType.family() == TypeFamily.FLOAT_32)
					inst(X86.CVTSI2SS, TypeFamily.FLOAT_32, R(result.register), src);
				else
					inst(X86.CVTSI2SD, TypeFamily.FLOAT_64, R(result.register), src);
				return;
			}
			break;

		case	UNSIGNED_16:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	SIGNED_16:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.UNSIGNED_16, result, n, compileContext);
				return;

			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.UNSIGNED_16, result, n, compileContext);
				inst(X86.AND, newType.family(), R(result.register), 0xffff);
				return;
				
			case	FLOAT_32:
			case	FLOAT_64:
				inst(X86.AND, TypeFamily.SIGNED_32, R(n.register), 0xffff);
				if (newType.family() == TypeFamily.FLOAT_32)
					inst(X86.CVTSI2SS, TypeFamily.FLOAT_32, R(result.register), R(n.register));
				else
					inst(X86.CVTSI2SD, TypeFamily.FLOAT_64, R(result.register), R(n.register));
				return;
			}
			break;

		case	UNSIGNED_32:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.UNSIGNED_32, result, n, compileContext);
				return;

			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.UNSIGNED_32, result, n, compileContext);
				inst(X86.SAL, TypeFamily.UNSIGNED_32, R(result.register), 32);
				inst(X86.SHR, TypeFamily.UNSIGNED_32, R(result.register), 32);
				return;
				
			case	FLOAT_32:
			case	FLOAT_64:
				inst(X86.SAL, TypeFamily.UNSIGNED_32, R(n.register), 32);
				inst(X86.SHR, TypeFamily.UNSIGNED_32, R(n.register), 32);
				if (newType.family() == TypeFamily.FLOAT_32)
					inst(X86.CVTSI2SS, TypeFamily.SIGNED_64, R(result.register), R(n.register));
				else
					inst(X86.CVTSI2SD, TypeFamily.SIGNED_64, R(result.register), R(n.register));
				return;
			}
			break;

		case	SIGNED_16:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.SIGNED_16, result, n, compileContext);
				return;

			case	UNSIGNED_32:
			case	SIGNED_32:
				inst(X86.MOVSX, TypeFamily.SIGNED_32, result, n, compileContext);
				return;
				
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				inst(X86.MOVSX_REX_W, TypeFamily.SIGNED_64, result, n, compileContext);
				return;
				
			case	FLOAT_32:
				inst(X86.CVTSI2SS, TypeFamily.SIGNED_16, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSI2SD, TypeFamily.SIGNED_16, result, n, compileContext);
				return;
			}
			break;

		case	SIGNED_32:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.SIGNED_32, result, n, compileContext);
				return;

			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				inst(X86.MOVSXD, TypeFamily.SIGNED_32, result, n, compileContext);
				return;
				
			case	FLOAT_32:
				inst(X86.CVTSI2SS, TypeFamily.SIGNED_32, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSI2SD, TypeFamily.SIGNED_32, result, n, compileContext);
				return;
/*
			case	VAR:
				target.byteCode(ByteCodes.CVTIL);
				ref<Type> t = target.arena().builtInType(TypeFamily.SIGNED_64);
				if (target.unit() != null) {
					ref<TypeRef> tr = target.unit().newTypeRef(t, target.arena().stringType().enclosing());
					target.byteCode(ByteCodes.LDSA);
					target.byteCode(tr.index());
				} else {
					target.byteCode(ByteCodes.VALUE);
					target.byteCode(0);
				}
				target.byteCode(ByteCodes.CVTLV);
				target.pushSp(var.bytes - address.bytes);
				return;
				*/
			}
			break;

		case	SIGNED_64:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.SIGNED_64, result, n, compileContext);
				return;

			case	FLOAT_32:
				inst(X86.CVTSI2SS, TypeFamily.SIGNED_64, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSI2SD, TypeFamily.SIGNED_64, result, n, compileContext);
				return;
			}
			break;

		case	FLOAT_32:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				inst(X86.CVTTSS2SI, TypeFamily.FLOAT_32, result, n, compileContext);
				return;

			case	FLOAT_32:
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSS2SD, TypeFamily.FLOAT_32, result, n, compileContext);
				return;
			}
			break;

		case	FLOAT_64:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				inst(X86.CVTTSD2SI, TypeFamily.FLOAT_64, result, n, compileContext);
				return;

			case	FLOAT_32:
				inst(X86.CVTSD2SS, TypeFamily.FLOAT_64, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				return;
			}
			break;

		case	INTERFACE:
		case	ADDRESS:
		case	REF:
		case	POINTER:
			switch (impl(newType)) {
			case	INTERFACE:
				if (existingType.indirectType(compileContext) != null && existingType.indirectType(compileContext).doesImplement(newType, compileContext)) {
					inst(X86.MOV, TypeFamily.ADDRESS, result, n, compileContext);
					inst(X86.ADD, result, existingType.indirectType(compileContext).interfaceOffset(newType, compileContext), compileContext);
					return;
				}
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	STRING:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.ADDRESS, result, n, compileContext);
				return;

			case	FLOAT_32:
				inst(X86.CVTSI2SS, TypeFamily.ADDRESS, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSI2SD, TypeFamily.ADDRESS, result, n, compileContext);
				return;
			}
			break;

		case	CLASS:
			// A general class coercion from another class type.
			if (existingType.size() == newType.size())
				return;
			if (newType.family() == TypeFamily.INTERFACE) {
				int interfaceOffset = existingType.interfaceOffset(newType, compileContext);
				if (interfaceOffset == -1) {
					result.print(0);
					assert(false);
				}
				inst(X86.LEA, newType, R(result.register), n, interfaceOffset);
				return;
			}
			break;

		case	STRING:
			switch (newType.family()) {
			/*
			case	VAR:
				ref<TypedefType> tt = ref<TypedefType>(target.arena().stringType().type());
				ref<Type> t = tt.wrappedType();
				if (target.unit() != null) {
					ref<TypeRef> tr = target.unit().newTypeRef(t, target.arena().stringType().enclosing());
					target.byteCode(ByteCodes.LDSA);
					target.byteCode(tr.index());
				} else {
					target.byteCode(ByteCodes.VALUE);
					target.byteCode(0);
				}
				target.byteCode(ByteCodes.CVTSV);
				target.pushSp(var.bytes - address.bytes);
				return;
				*/
			case	STRING:
				return;
			}
			break;
/*
		case	VAR:
			switch (newType.family()) {
			case	UNSIGNED_16:
			case	SIGNED_32:
				target.byteCode(ByteCodes.CVTVI);
				target.popSp(var.bytes - address.bytes);
				return;

			case	STRING:
				target.byteCode(ByteCodes.CVTVS);
				target.popSp(var.bytes - address.bytes);
				return;

			case	CLASS:
				if (newType.indirectType(compileContext) != null) {
					target.byteCode(ByteCodes.CVTVA);
					target.popSp(var.bytes - address.bytes);
					return;
				}
				break;

			default:
				break;
			}
			*/
		case	FUNCTION:
			switch (impl(newType)) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	INTERFACE:
				if ((n.nodeFlags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, TypeFamily.FUNCTION, result, n, compileContext);
				return;

			case	FLOAT_32:
			case	FLOAT_64:
				if (newType.family() == TypeFamily.FLOAT_32)
					inst(X86.CVTSI2SS, TypeFamily.FLOAT_32, R(result.register), R(n.register));
				else
					inst(X86.CVTSI2SD, TypeFamily.FLOAT_64, R(result.register), R(n.register));
				return;
			}
			break;
		}
		printf("Convert from ");
		existingType.print();
		printf(" -> ");
		newType.print();
		printf("\n");
		result.print(4);
		assert(false);
	}

	public ref<ParameterScope> generateEnumToStringMethod(ref<EnumInstanceType> type, ref<CompileContext> compileContext) {
		ref<ParameterScope> scope = compileContext.arena().createParameterScope(type.scope(), null, ParameterScope.Kind.ENUM_TO_STRING);
		return scope;
	}
	
	public ref<ParameterScope> generateFlagsToStringMethod(ref<FlagsInstanceType> type, ref<CompileContext> compileContext) {
		ref<ParameterScope> scope = compileContext.arena().createParameterScope(type.scope(), null, ParameterScope.Kind.FLAGS_TO_STRING);
		return scope;
	}
	
	private boolean generateReturn(ref<Scope> scope, ref<CompileContext> compileContext) {
		if (scope.definition() == null || scope.definition().op() != Operator.FUNCTION)			// in-line code
			inst(X86.RET);
		else {							// a function body
			ref<FunctionDeclaration> func = ref<FunctionDeclaration>(scope.definition());
			ref<FunctionType> functionType = ref<FunctionType>(func.type);
			if (functionType == null) {
				unfinished(func, "generateReturn functionType == null", compileContext);
				return true;
			}
			ref<ParameterScope> parameterScope = ref<ParameterScope>(scope);
			if (parameterScope.enclosing().isMonitor() && func.functionCategory() != FunctionDeclaration.Category.CONSTRUCTOR &&
				parameterScope.hasThis()) {
				boolean returnRegisterBusy = functionType.returnCount() == 1 && 
						!functionType.returnValueType().returnsViaOutParameter(compileContext);

				if (returnRegisterBusy)
					pushRegister(functionType.returnValueType().family(), 
							functionType.returnValueType().isFloat() ? R.XMM0 : R.RAX);
				inst(X86.MOV, TypeFamily.ADDRESS, firstRegisterArgument(), thisRegister());
				instCall(releaseMethod(compileContext), compileContext);
				if (returnRegisterBusy)
					popRegister(functionType.returnValueType().family(), 
							functionType.returnValueType().isFloat() ? R.XMM0 : R.RAX);
			}
			if (parameterScope.hasThis())
				inst(X86.MOV, thisRegister(), R.RBP, -address.bytes);
			inst(X86.LEAVE);
			inst(X86.RET, parameterScope.variableStorage);
		}
		return true;
	}

	private void storeVtable(ref<Type> t, ref<CompileContext> compileContext) {
		ref<ClassScope> classScope = ref<ClassScope>(t.scope());
		buildVtable(classScope, compileContext);
		instStoreVTable(firstRegisterArgument(), 0, R.RAX, classScope);
	}

	private void storeITables(ref<Type> t, int adjustment, ref<CompileContext> compileContext) {
		if (t.scope() == null || t.scope().class != ClassScope)
			return;
		ref<ClassScope> classScope = ref<ClassScope>(t.scope());
		if (classScope.interfaceCount() == 0)
			return;
		ref<ref<InterfaceImplementationScope>[]> interfaces = classScope.interfaces();
		for (int i = 0; i < interfaces.length(); i++) {
			ref<InterfaceImplementationScope> iit = (*interfaces)[i];
			int offset = adjustment + iit.itableOffset(compileContext);
			buildVtable(iit, compileContext);
			instStoreVTable(firstRegisterArgument(), offset, R.RAX, iit);
		}
	}

	private void cacheCodegenObjects(ref<CompileContext> compileContext) {
		ref<Symbol> re = _arena.getSymbol("parasol", "memory.alloc", compileContext);
		if (re == null || re.class != Overload)
			assert(false);
		ref<Overload> o = ref<Overload>(re);
		_alloc = ref<ParameterScope>((*o.instances())[0].type().scope());
		re = _arena.getSymbol("parasol", "memory.free", compileContext);
		if (re == null || re.class != Overload)
			assert(false);
		 o = ref<Overload>(re);
		_free = ref<ParameterScope>((*o.instances())[0].type().scope());
		re = _arena.getSymbol("native", "C.memset", compileContext);
		if (re == null || re.class != Overload)
			assert(false);
		 o = ref<Overload>(re);
		_memset = ref<ParameterScope>((*o.instances())[0].type().scope());
		re = _arena.getSymbol("native", "C.memcpy", compileContext);
		if (re == null || re.class != Overload)
			assert(false);
		 o = ref<Overload>(re);
		_memcpy = ref<ParameterScope>((*o.instances())[0].type().scope());
		ref<Type> stringType = _arena.builtInType(TypeFamily.STRING);
		if (stringType != null && stringType.scope() != null) {
			for (int i = 0; i < stringType.scope().constructors().length(); i++) {
				ref<Scope> scope = (*stringType.scope().constructors())[i];
				ref<FunctionDeclaration> func = ref<FunctionDeclaration>(scope.definition());
				ref<NodeList> args = func.arguments();
				if (args == null ||
					args.next != null)
					continue;
				if (args.node.type.equals(stringType)) {
					_stringCopyConstructor = ref<OverloadInstance>(func.name().symbol());
					break;
				}
			}
			ref<Symbol> assign = stringType.scope().lookup("assign", compileContext);
			if (assign != null) {
				ref<Overload> o = ref<Overload>(assign);
				if (o.instances().length() == 1) {
					ref<OverloadInstance> oi = (*o.instances())[0];
					// TODO: Validate that we have the correct symbol;
					_stringAssign = oi;
				}
			}
			ref<Symbol> compare = stringType.scope().lookup("compare", compileContext);
			if (assign != null) {
				ref<Overload> o = ref<Overload>(compare);
				if (o.instances().length() == 1) {
					ref<OverloadInstance> oi = (*o.instances())[0];
					// TODO: Validate that we have the correct symbol;
					_stringCompare = oi;
				}
			}
			ref<Symbol> append = stringType.scope().lookup("append", compileContext);
			if (append != null) {
				ref<Overload> o = ref<Overload>(append);
				for (int i = 0; i < o.instances().length(); i++) {
					ref<OverloadInstance> oi = (*o.instances())[i];
					if (oi.parameterCount() != 1)
						continue;
					ref<Scope> s = oi.parameterScope();
					ref<Symbol>[Scope.SymbolKey].iterator iter = s.symbols().begin();
					if (iter.get().type().family() == TypeFamily.STRING) {
						_stringAppendString = oi;
						break;
					}
				}
			}
		}
		ref<Type> varType = _arena.builtInType(TypeFamily.VAR);
		for (int i = 0; i < varType.scope().constructors().length(); i++) {
			ref<Scope> scope = (*varType.scope().constructors())[i];
			ref<FunctionDeclaration> func = ref<FunctionDeclaration>(scope.definition());
			ref<NodeList> args = func.arguments();
			if (args == null ||
				args.next != null)
				continue;
			if (args.node.type == null) {
				ref<Binary> b = ref<Binary>(args.node);
				b.type = b.left().unwrapTypedef(Operator.CLASS, compileContext);
			}
			if (args.node.type.equals(varType)) {
				_varCopyConstructor = ref<OverloadInstance>(func.name().symbol());
				break;
			}
		}
		ref<Type> floatType = _arena.builtInType(TypeFamily.FLOAT_32);
		ref<Symbol> signMask = floatType.scope().lookup("SIGN_MASK", compileContext);
		if (signMask != null)
			_floatSignMask = signMask;
		ref<Symbol> one = floatType.scope().lookup("ONE", compileContext);
		if (one != null)
			_floatOne = one;
		ref<Symbol> zero = floatType.scope().lookup("ZERO", compileContext);
		if (zero != null)
			_floatZero = zero;
		ref<Type> doubleType = _arena.builtInType(TypeFamily.FLOAT_64);
		signMask = doubleType.scope().lookup("SIGN_MASK", compileContext);
		if (signMask != null)
			_doubleSignMask = signMask;
		one = doubleType.scope().lookup("ONE", compileContext);
		if (one != null)
			_doubleOne = one;
		zero = doubleType.scope().lookup("ZERO", compileContext);
		if (zero != null)
			_doubleZero = zero;
	}
	
	private void generateDefaultConstructors(ref<Scope> scope, ref<CompileContext> compileContext) {
		if (scope == null)
			return;
		for (ref<Symbol>[Scope.SymbolKey].iterator i = scope.symbols().begin(); i.hasNext(); i.next()) {
			ref<Symbol> sym = i.get();
			if (sym.class != PlainSymbol)
				continue;
			if (sym.enclosing() != scope)
				continue;
			if (!sym.initializedWithConstructor()) {
				ref<ParameterScope> constructor = sym.type().defaultConstructor();
				if (constructor != null) {
					inst(X86.LEA, firstRegisterArgument(), sym.definition(), compileContext);
					if (sym.type().hasVtable(compileContext))
						storeVtable(sym.type(), compileContext);
					storeITables(sym.type(), 0, compileContext);
					instCall(constructor, compileContext);
				} else {
					if (sym.accessFlags() & Access.CONSTANT)
						continue;
					switch (sym.type().family()) {
					case	FUNCTION:
					case	REF:
					case	POINTER:
					case	ADDRESS:
					case	BOOLEAN:
					case	ENUM:
					case	FLAGS:
					case	SIGNED_16:
					case	SIGNED_32:
					case	SIGNED_64:
					case	UNSIGNED_8:
					case	UNSIGNED_16:
					case	UNSIGNED_32:
					case	CLASS_VARIABLE:
						if (sym.storageClass() != StorageClass.STATIC) {
							if (sym.definition().type == null)
								sym.definition().type = sym.type();		// probably caused by some error condition, patch it
							inst(X86.MOV, sym.definition(), 0, compileContext);
						}
						break;
						
					case	TYPEDEF:
					case	ERROR:
					case	CLASS_DEFERRED:
					case	INTERFACE:
						break;
						
					case	CLASS:
						
						if (sym.type().hasVtable(compileContext)) {
							inst(X86.LEA,firstRegisterArgument(),  sym.definition(), compileContext);
							storeVtable(sym.type(), compileContext);
						} else if (sym.type().interfaceCount() > 0)
							inst(X86.LEA,firstRegisterArgument(),  sym.definition(), compileContext);
						storeITables(sym.type(), 0, compileContext);
						break;
													
					default:
						sym.print(0, false);
						assert(false);
					}
				}
			}
		}
	}
	
	private void classClear(ref<Type> type, ref<Node> node, ref<CompileContext> compileContext) {
		if (type.hasVtable(compileContext)) {
			if (type.size() > address.bytes) {
				if (node != null) {
					inst(X86.LEA, firstRegisterArgument(), node, compileContext);
					inst(X86.ADD, TypeFamily.ADDRESS, firstRegisterArgument(), 8);
				} else
					inst(X86.LEA, firstRegisterArgument(), thisRegister(), address.bytes);
				inst(X86.XOR, TypeFamily.UNSIGNED_16, secondRegisterArgument(), secondRegisterArgument());
				inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), type.size() - address.bytes);
				instCall(_memset, compileContext);
			}
		} else if (type.size() > 0) {
			if (type.size() <= int.bytes) {
				if (node != null)
					inst(X86.MOV, node, 0, compileContext);
				else
					inst(X86.MOV, impl(type), thisRegister(), 0, 0);
			} else {
				if (node != null)
					inst(X86.LEA, firstRegisterArgument(), node, compileContext);
				else
					inst(X86.MOV, TypeFamily.ADDRESS, firstRegisterArgument(), thisRegister());
				inst(X86.XOR, TypeFamily.UNSIGNED_16, secondRegisterArgument(), secondRegisterArgument());
				inst(X86.MOV, TypeFamily.SIGNED_32, thirdRegisterArgument(), type.size());
				instCall(_memset, compileContext);
			}
		}
	}
	
	private ref<ParameterScope> takeMethod(ref<CompileContext> compileContext) {
		if (_takeMethod == null) {
			ref<Type> m = compileContext.monitorClass();
			CompileString cs("take");
			ref<Symbol> take = m.scope().lookup(&cs, compileContext);
			if (take == null || take.class != Overload) {
				printf("Could not find appropriate 'take' method.\n");
				assert(false);
			}
			ref<Overload> o = ref<Overload>(take);
			if (o.instances().length() != 1) {
				printf("Could not find appropriate 'take' method.\n");
				assert(false);
			}
			if ((*o.instances())[0].parameterCount() != 0) {
				printf("Could not find appropriate 'take' method.\n");
				assert(false);
			}
			_takeMethod = (*o.instances())[0].parameterScope();
		}
		return _takeMethod;
	}
	
	private ref<ParameterScope> releaseMethod(ref<CompileContext> compileContext) {
		if (_releaseMethod == null) {
			ref<Type> m = compileContext.monitorClass();
			CompileString cs("release");
			ref<Symbol> release = m.scope().lookup(&cs, compileContext);
			if (release == null || release.class != Overload) {
				printf("Could not find appropriate 'release' method.\n");
				assert(false);
			}
			ref<Overload> o = ref<Overload>(release);
			if (o.instances().length() != 1) {
				printf("Could not find appropriate 'release' method.\n");
				assert(false);
			}
			if ((*o.instances())[0].parameterCount() != 0) {
				printf("Could not find appropriate 'release' method.\n");
				assert(false);
			}
			_releaseMethod = (*o.instances())[0].parameterScope();
		}
		return _releaseMethod;
	}
}

int NC_SYMBOL =	0x000001,
	NC_FLOAT =	0x000002,
	NC_MOVE =	0x000004,
	NC_CONST =	0x000008,
	NC_COMMU =	0x000010,	/* Commutative operation */
//	NC_REG =	0x000020,
	NC_CLEAN =	0x000040,	/* Operation doesn't modify operands */
	NC_LEFT =	0x000100,	/* Prefer the left operand, if there is
					   a choice.  Basically, if the node
					   is not an assignment node, the left
					   hand operand register is assigned to
					   the result.
					 */
//	NC_VAR =	0x000200,	/* Node is a variable */
//	NC_CALL =	0x000400,	/* Node is a call */
//	NC_WAIT =	0x000800,	/* The node needs an FWAIT if one is 
//					   pending */
//	NC_SPCALL =	0x001000,	/* The node is a special internal 
//					   call */
	NC_FREE =	0x002000,	/* The node generates no code itself */
	NC_IMMED =	0x004000,
	NC_BYTE =	0x008000,
	NC_LEFTOP =	0x010000,
	NC_RIGHTOP =	0x020000,
	NC_NLEAF =	NC_LEFTOP|NC_RIGHTOP,
	NC_NOCSE =	0x040000;

int[Operator] nodeClasses = [
	IDENTIFIER:			NC_SYMBOL,
	INTEGER:			NC_CONST,
	FLOATING_POINT:		NC_CONST,
	CHARACTER:			NC_CONST,
	ADDRESS:			NC_CONST,
	EQUALITY:			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	NOT_EQUAL:			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	LESS:				NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	GREATER:			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	LESS_EQUAL:			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	GREATER_EQUAL:		NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	LESS_GREATER:		NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	NOT_LESS:			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	NOT_GREATER:		NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	NOT_LESS_EQUAL:		NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	NOT_GREATER_EQUAL:	NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	NOT_LESS_GREATER:	NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
	MAX_OPERATOR:		0
];

/*
Nodes:	public	const	[] nodeDescriptor = [
	[ NC_FREE ],				// O_ERROR
	[ NC_SYMBOL,	I386_MOVC ],		// O_ID
	[ NC_CONST,	I386_MOVC ],		// O_ICON
	[ NC_CONST,	I386_MOVC ],		// O_FCON
	[ NC_SYMBOL,	I386_MOVC ],		// O_SELF
	[ NC_SYMBOL,	I386_MOVC ],		// O_SUPER
	[ NC_SYMBOL,	I386_MOVC ],		// O_TOS
	[ NC_SYMBOL,	I386_MOVC ],		// O_REG
	[ NC_SYMBOL,	I386_MOVC ],		// O_AUTO
	[ NC_SYMBOL,	I386_MOVC ],		// O_DYNAMIC
	[ NC_SYMBOL,	I386_MOVC ],		// O_REMOTE
	[ NC_SYMBOL,	I386_MOVC ],		// O_TYPE
	[ NC_SYMBOL,	I386_MOVC ],		// O_SCONST
	[ NC_SYMBOL,	I386_MOVC ],		// O_LITERAL
	[ NC_CONST,	I386_MOVC ],		// O_ELLIPSIS

	    // Binary operators

	[ NC_NLEAF|NC_COMMU|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_ADDC, I386_ADDC ],		// O_ADD
	[ NC_NLEAF|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_SUBC, I386_SUBRF - 3 ],	// O_SUB
	[ NC_NLEAF|NC_COMMU, I386_MULC, I386_MULC ],	// O_MUL
	[ NC_NLEAF, 	I386_DIVC, I386_DIVRF - 3 ],	// O_DIV
	[ NC_NLEAF,	I386_DIVC ],			// O_MOD
	[ NC_NLEAF|NC_LEFT, I386_LSLC ],		// O_LSH
	[ NC_NLEAF|NC_LEFT, I386_LSRC ],		// O_RSH
	[ NC_NLEAF|NC_COMMU|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_ANDC ],			// O_AND
	[ NC_NLEAF|NC_COMMU|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_ORC ],			// O_OR
	[ NC_NLEAF|NC_COMMU|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_XORC ],			// O_XOR

	[ NC_NLEAF|NC_MOVE|NC_IMMED,
			I386_MOVC ],			// O_ASG
	[ NC_NLEAF|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_ADDC, I386_ADDC ],		// O_ADA
	[ NC_NLEAF|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_SUBC, I386_SUBF - 3 ],	// O_SBA
	[ NC_NLEAF,	I386_MULC, I386_MULC ],		// O_MUA
	[ NC_NLEAF,	I386_DIVC, I386_DIVRF - 3 ],	// O_DVA
	[ NC_NLEAF,	I386_DIVC ],			// O_MOA
	[ NC_NLEAF|NC_LEFT, I386_LSLC ],		// O_LSA
	[ NC_NLEAF|NC_LEFT, I386_LSRC ],		// O_RSA
	[ NC_NLEAF|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_ANDC ],			// O_ANA
	[ NC_NLEAF|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_ORC ],			// O_ORA
	[ NC_NLEAF|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_XORC ],			// O_XRA
			I386_CMPC, I386_CMPC ],			// O_EQ
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_NE
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_GT
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_LT
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_GE
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_LE
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_ORD
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_UNORD
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_NLT
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_NLE
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_NGT
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_NGE
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_LT_GT
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
			I386_CMPC, I386_CMPC ],			// O_NLT_GT
	[ NC_NLEAF|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_ADDC ],			// O_INA
	[ NC_NLEAF|NC_LEFT|NC_BYTE|NC_IMMED,
			I386_SUBC, I386_SUBRF - 3 ],	// O_DEA
	[ 0 ],						// O_QUES
	[ 0 ],						// O_LAND
	[ 0 ],						// O_LOR
	[ 0 ],						// O_SEQ
	[ 0 ],						// O_ARG
	[ 0 ],						// O_IOARROW
	[ 0 ],						// O_INIT

	   // Unary operators

	[ NC_NLEAF|NC_LEFT, I386_NEGC ],		// O_NEG
	[ NC_NLEAF|NC_LEFT, I386_NEGC ],		// O_PLUS
	[ NC_NLEAF|NC_LEFT, I386_COMC ],		// O_COM
	[ NC_NLEAF|NC_LEFT ],				// O_NOT
	[ NC_NLEAF,	I386_MOVC ],			// O_IND
	[ NC_CONST ],					// O_ADR

	   // Special operators

	[ 0 ],						// O_FLD
	[ 0 ],						// O_CAST
	[ NC_IMMED ],					// O_SCALL
	[ NC_IMMED ],					// O_MCALL
	[ NC_IMMED ],					// O_RCALL
	[ 0 ],						// O_DOT
	[ 0 ],						// O_ARROW
	[ 0 ],						// O_SUBSCRIPT
	[ 0 ],						// O_SLICE
	[ 0 ],						// O_BOUND
	[ 0 ],						// O_MBOUND
	[ 0 ],						// O_SIZEOF

		// Code generation operations

	[ 0 ],						// O_INTRPT
	[ 0 ],						// O_ABS
	[ 0 ],						// O_OUT
	[ 0 ],						// O_IN
	[ 0 ],						// O_EMIT
	[ 0 ],						// O_MSCAN
	[ 0 ],						// O_MCOPY
	[ 0 ],						// O_MSET
	[ NC_NLEAF|NC_LEFT, I386_ROLL-2 ],		// O_ROL
	[ NC_NLEAF|NC_LEFT, I386_RORL-2 ],		// O_ROR
	[ 0 ],						// O_FABS
	[ 0 ],						// O_XCHG
	[ 0 ],						// O_RNDINT
	[ 0 ],						// O_CVTBCD
	[ NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED,
				I386_TESTC ],		// O_TST

	[ 0 ],						// O_ALLOCTOS
	[ 0 ],						// O_NEW
	[ 0 ],						// O_TYPELEN
	[ 0 ],						// O_OFFSETOF
	[ 0 ],						// O_TYPEOF
	[ 0 ],						// O_SEND
	[ 0 ],						// O_BLOCK
	[ 0 ],						// O_DECL
	[ 0 ],						// O_GOTO
	[ 0 ],						// O_ASSERT
	[ 0 ],						// O_LABEL
	[ 0 ],						// O_RETURN
	[ 0 ],						// O_ENDTRY
	[ 0 ],						// O_REPLY
	[ 0 ],						// O_JUMP
	[ 0 ],						// O_TEST
	[ 0 ],						// O_STMT
	[ 0 ],						// O_SWITCH
	[ 0 ],						// O_TRY
	[ 0 ],						// O_EXCEPT
	[ 0 ],						// O_ENDEX
*/

boolean isCompileTimeConstant(ref<Node> t) {
	if	(t.op() == Operator.INTEGER)
		return true;
/*
	if	(t.op() != Operator.ADDRESS)
		return false;
	t = ref<Unary>(t).operand();
	if	(t.op() == Operator.IDENTIFIER)
		return false;
	else
		return true;
 */
	return false;
}

private TraverseAction collectStaticDestructors(ref<Node> n, address data) {
	if (n.op() == Operator.DECLARATION) {
		//n.print(0);
		compiler.markLiveSymbols(ref<Binary>(n).right(), StorageClass.STATIC, ref<CompileContext>(data));
	}
	return TraverseAction.CONTINUE_TRAVERSAL;
}

TypeFamily impl(ref<Type> t) {
	switch (t.family()) {
	case FLAGS:
	case ENUM:
		switch (t.size()) {
		case 1:
			return TypeFamily.UNSIGNED_8;
		case 2:
			return TypeFamily.SIGNED_16;
		case 4:
			return TypeFamily.SIGNED_32;
		}
		return TypeFamily.SIGNED_64;
	}
	return t.family();
}
