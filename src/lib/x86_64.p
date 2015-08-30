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
namespace parasol:x86_64;

import native:windows;

import parasol:runtime;
import parasol:compiler.Arena;
import parasol:compiler.Binary;
import parasol:compiler.Block;
import parasol:compiler.Call;
import parasol:compiler.CallCategory;
import parasol:compiler.Class;
import parasol:compiler.ClassScope;
import parasol:compiler.CompileContext;
import parasol:compiler.CompileString;
import parasol:compiler.Constant;
import parasol:compiler.EnumInstanceType;
import parasol:compiler.EllipsisArguments;
import parasol:compiler.FileStat;
import parasol:compiler.For;
import parasol:compiler.Function;
import parasol:compiler.FunctionType;
import parasol:compiler.GatherCasesClosure;
import parasol:compiler.Identifier;
import parasol:compiler.MessageId;
import parasol:compiler.Node;
import parasol:compiler.NodeList;
import parasol:compiler.Operator;
import parasol:compiler.Overload;
import parasol:compiler.OverloadInstance;
import parasol:compiler.ParameterScope;
import parasol:compiler.PUSH_OUT_PARAMETER;
import parasol:compiler.Reference;
import parasol:compiler.Return;
import parasol:compiler.Scope;
import parasol:compiler.Selection;
import parasol:compiler.StackArgumentAddress;
import parasol:compiler.StorageClass;
import parasol:compiler.StorageClassMap;
import parasol:compiler.Symbol;
import parasol:compiler.Target;
import parasol:compiler.TemplateInstanceType;
import parasol:compiler.Ternary;
import parasol:compiler.Test;
import parasol:compiler.Type;
import parasol:compiler.TypedefType;
import parasol:compiler.TypeFamily;
import parasol:compiler.Unary;
import parasol:compiler.Variable;
import parasol:pxi.Pxi;
import native:C;

/*
 * These are combined to produce the necessary instruciton encodings.
 */
byte REX_W = 0x48;
byte REX_R = 0x44;
byte REX_X = 0x42;
byte REX_B = 0x41;

R[] fastArgs;

fastArgs.append(R.RCX);
fastArgs.append(R.RDX);
fastArgs.append(R.R8);
fastArgs.append(R.R9);

R[] floatArgs;

floatArgs.append(R.XMM0);
floatArgs.append(R.XMM1);
floatArgs.append(R.XMM2);
floatArgs.append(R.XMM3);
/*
 * Flags for the Node.flags field. (0x0f are reserved for non-codegen flags)
 */
byte ADDRESS_MODE = 0x10;

long PXI_FIXUP = 0xff;
byte PXI_FIXUP_RELATIVE32 = 0x01;
byte PXI_FIXUP_ABSOLUTE64 = 0x02;
byte PXI_FIXUP_ABSOLUTE64_CODE = 0x03;
byte PXI_FIXUP_MAX = 0x04;
int PXI_FIXUP_SHIFT = 8;

int EXCEPTION_ACCESS_VIOLATION	= int(0xc0000005);
int EXCEPTION_IN_PAGE_ERROR		= int(0xc0000006);

@Header
class ExceptionContext {
	public address exceptionAddress;		// The machine instruction causing the exception
	public address stackPointer;			// The thread stack point at the moment of the exception
	public address framePointer;			// The frame pointer at the moment of the exception

	// This is a copy of the hardware stack at the time of the exception.  It may extend beyond the actual
	// hardware stack at the moment of the exception because, for example, the call to create the copy used
	// the address of a local variable to get a stack offset.
	
	// To compute the address in the copy from a forensic machine address, use the following:
	//
	//	COPY_ADDRESS = STACK_ADDRESS - stackBase + stackCopy;
	
	public address stackBase;			// The machine address of the hardware stack this copy was taken from
	public pointer<byte> stackCopy;		// The first byte of the copy
	public address memoryAddress;		// Valid only for memory exceptions: memory location referenced
	public int exceptionType;			// Exception type
	public int exceptionFlags;			// Flags (dependent on type).
	public int stackSize;				// The length of the copy
	
	long slot(address stackAddress) {
		long addr = long(stackAddress);
		long base = long(stackBase);
		long copy = long(address(stackCopy));
		long target = addr - base + copy;
		ref<long> copyAddress = ref<long>(address(target));
		return *copyAddress;
	}
}

public class X86_64 extends X86_64AssignTemps {
	private ref<Scope> _unitScope;
	private ref<Arena> _arena;
	private ref<OverloadInstance> _allocz;					// Symbol for allocz function.
	private ref<OverloadInstance> _free;					// Symbol for allocz function.
	private ref<OverloadInstance> _stringAppendString;		// string.append(string)
	private ref<OverloadInstance> _stringCopyConstructor;
	private ref<OverloadInstance> _stringAssign;
	private ref<OverloadInstance> _varCopyConstructor;
	private ref<OverloadInstance> _memset;
	private ref<OverloadInstance> _memcpy;
	private ref<OverloadInstance> _assert;
	private ref<Symbol> _floatSignMask;
	private ref<Symbol> _floatOne;
	private ref<Symbol> _doubleSignMask;
	private ref<Symbol> _doubleOne;
	
//	private byte[] _data;
	public int maxTypeOrdinal;
	private boolean _verbose;
	private int _stackLocalVariables;

	public X86_64(ref<Arena> arena, boolean verbose) {
		_arena = arena;
		_verbose = verbose;
		cacheCodegenObjects();
	}

	public boolean verbose() {
		return _verbose;
	}

	boolean generateCode(ref<FileStat> mainFile, int valueOffset, ref<CompileContext> compileContext) {
		ref<Block> unit = mainFile.tree().root();
//		printf("unit = %p\n", unit);
		_unitScope = new Scope(_arena.root(), unit, compileContext.blockStorageClass(), unit.className());
		maxTypeOrdinal = 1;
		// This may have to be postponed until we get some data on register usage.
		for (int i = 0; i < _arena.scopes().length(); i++) {
			ref<Scope> scope = _arena.scopes()[i];
			switch (scope.storageClass()) {
			case	TEMPLATE:
			case	AUTO:
			case	PARAMETER:
				break;
				
			default:
				scope.assignVariableStorage(this, compileContext);
			}
		}
		if (_verbose)
			printf("Variable storage assigned\n");
		return super.generateCode(mainFile, valueOffset, compileContext);
	}
	
	public void writePxi(ref<Pxi> output) {
		ref<X86_64Section> s = new X86_64Section(this);
		output.declareSection(s);
	}
	
	public int, boolean run(string[] args) {
		pointer<byte>[] runArgs;
		for (int i = 1; i < args.length(); i++)
			runArgs.append(args[i].c_str());
		int returnValue;
		pointer<address> pa = pointer<address>(&_staticMemory[_pxiHeader.builtInOffset]);
		for (int i = 0; i < _pxiHeader.builtInCount; i++) {
			if (unsigned(int(*pa)) > 50) {
				printf("pa = %p *pa = %p\n", pa, *pa);
				assert(false);
			}
			*pa = runtime.builtInFunctionAddress(int(*pa));
			pa++;
		}
		pointer<int> pxiFixups = pointer<int>(&_staticMemory[_pxiHeader.relocationOffset]);
		if (runtime.makeRegionExecutable(_staticMemory, _staticMemoryLength)) {
			for (int i = 0; i < _pxiHeader.relocationCount; i++) {
				long fx = pxiFixups[i];
				assert(false);
				return 0, false;
			}
			pointer<long> vp = pointer<long>(_staticMemory + _pxiHeader.vtablesOffset);
			for (int i = 0; i < _pxiHeader.vtableData; i++, vp++)
				*vp += long(address(_staticMemory));
			runtime.setTrace(_arena.trace);
			int xxx = 15436;
			returnValue = runtime.evalNative(&_pxiHeader, _staticMemory, &runArgs[0], runArgs.length());
			runtime.setTrace(false);
		} else {
			pointer<byte> generatedCode = pointer<byte>(runtime.allocateRegion(_staticMemoryLength));
			C.memcpy(generatedCode, _staticMemory, _staticMemoryLength);
			for (int i = 0; i < _pxiHeader.relocationCount; i++) {
				long fx = pxiFixups[i];
				assert(false);
				return 0, false;
			}
			pointer<long> vp = pointer<long>(generatedCode + _pxiHeader.vtablesOffset);
			for (int i = 0; i < _pxiHeader.vtableData; i++, vp++)
				*vp += long(address(generatedCode));
			if (runtime.makeRegionExecutable(generatedCode, _staticMemoryLength)) {
				runtime.setTrace(_arena.trace);
				returnValue = runtime.evalNative(&_pxiHeader, _staticMemory, &runArgs[0], runArgs.length());
				runtime.setTrace(false);
			} else {
				printf("GetLastError=%x\n", int(windows.GetLastError()));
				assert(false);
				return 0, false;
			}
		}
//		assert(false);
//		print("here\n");
//		printf("done returnValue = %d\n", returnValue);
		ref<ExceptionContext> raised = runtime.exceptionContext(null);
		if (raised != null) {
//			printf("assertion failed!\n");
			printf("\n");
			boolean locationIsExact = false;
			pointer<byte> message = windows.FormatMessage(unsigned(raised.exceptionType));
			string text(message);
			if (raised.exceptionType == 0)
				printf("Assertion failed ip %p", raised.exceptionAddress);
			else {
				printf("Uncaught exception %x", raised.exceptionType);
				if (message != null)
					printf(" (%s)", text);
				printf(" ip %p", raised.exceptionAddress);
				if (raised.exceptionType == EXCEPTION_ACCESS_VIOLATION ||
					raised.exceptionType == EXCEPTION_IN_PAGE_ERROR) {
					locationIsExact = true;
					printf(" flags %d referencing %p", raised.exceptionFlags, raised.memoryAddress);
				}
			}

			printf("\n");
			byte[] stackSnapshot;
						
			stackSnapshot.resize(raised.stackSize);
			raised.stackCopy = &stackSnapshot[0];
//			printf("stack snapshot size %d\n", stackSnapshot.length());
						
			runtime.fetchSnapshot(&stackSnapshot[0], stackSnapshot.length());
//			printf("    failure address %p\n", raised.exceptionAddress);
//			printf("    sp: %p fp: %p stack size: %d\n", raised.stackPointer, raised.framePointer, raised.stackSize);
			address stackLow = raised.stackPointer;
			address stackHigh = pointer<byte>(raised.stackPointer) + raised.stackSize;
			address fp = raised.framePointer;
			address ip = raised.exceptionAddress;
			string tag = "->";
			while (long(fp) >= long(stackLow) && long(fp) < long(stackHigh)) {
//				printf("fp = %p ip = %p relative = %x", fp, ip, int(ip) - int(_staticMemory));
				pointer<address> stack = pointer<address>(fp);
				long nextFp = raised.slot(fp);
				int relative = int(ip) - int(_staticMemory);
//				printf("relative = (%p) %x\n", ip, relative);
				string locationLabel;
				if (relative >= _staticMemoryLength || relative < 0)
					locationLabel.printf("@%x", relative);
				else
					locationLabel = formattedLocation(relative, locationIsExact);
				printf(" %2s %s\n", tag, locationLabel);
//				if (nextFp != 0 && nextFp < long(fp)) {
//					printf("    *** Stored frame pointer out of sequence: %p\n", nextFp);
//					break;
//				}
				fp = address(nextFp);
				ip = address(raised.slot(stack + 1));
				tag = "";
				locationIsExact = false;
			}
			printf("\n");
			return 0, false;
		} else
		/*
			ref<ExceptionContext> ec = ref<ExceptionContext>(exceptionInfo[3]);
		*/
			return returnValue, true;
	}

	private string formattedLocation(int offset, boolean locationIsExact) {
		int unadjustedOffset = offset;
		if (!locationIsExact)
			offset--;
		pointer<SourceLocation> psl = &_sourceLocations[0];
		int interval = _sourceLocations.length();
		string result;
		for (;;) {
			if (interval <= 0) {
				result.printf("@%x", offset);
				break;
			}
			int middle = interval / 2;
			if (psl[middle].offset > offset)
				interval = middle;
			else if (middle == interval - 1 || psl[middle + 1].offset > offset) {
				ref<FileStat> file = psl[middle].file;
				result.printf("%s %d (@%x)", file.filename(), file.scanner().lineNumber(psl[middle].location) + 1, unadjustedOffset);
				break;
			} else {
				psl = &psl[middle + 1];
				interval = interval - middle - 1;
			}
		}
		return result;
	}
	
	public ref<Scope>, boolean getFunctionAddress(ref<ParameterScope> functionScope, ref<CompileContext> compileContext) {
		ref<Function> func = ref<Function>(functionScope.definition());
		if (func == null) {
			if (functionScope.value == null) {
				functionScope.value = address(-1);
				functionScope.value = address(1 + generateFunction(functionScope, compileContext));
			}
			return functionScope, false;
		}
		if (functionScope.value != null) {
			if (func.functionCategory() == Function.Category.ABSTRACT &&
				functionScope.enclosing().storageClass() == StorageClass.STATIC)
				return functionScope, true;
			else
				return functionScope, false;
		} else {
			if (func.functionCategory() == Function.Category.ABSTRACT) {
				if (functionScope.enclosing().storageClass() == StorageClass.STATIC) {
					for (int i = 0;; i++) {
						pointer<byte> name = runtime.builtInFunctionName(i);
						if (name == null)
							break;
						// TODO: Add code to verify correct domain/namespace.
						if (func.name().value().equals(name)) {
							address v = address(long(i + 1));
							if (func.name() != null)
								func.name().symbol().value = v;
							functionScope.value = v;
							return functionScope, true;
						}
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
		ref<ParameterScope> parameterScope = ref<ParameterScope>(scope);

		ref<Function> func = ref<Function>(scope.definition());
		if (func == null) {
			generateCallToBaseDefaultConstructor(parameterScope, compileContext);
			if (!generateReturn(scope, compileContext))
				assert(false);
			return;
		}
		if (func.op() == Operator.FUNCTION) {
//			if (func.name() != null)
//				printf("Generating for %s\n", func.name().identifier().asString());
			node = func.body;
			if (node == null) {
				func.print(0);
				assert(false);
			} else {
				int initialVariableCount = compileContext.variableCount();
				ref<FileStat> file = scope.file();
				
				// For template functions, this assigns any missing types info:
				
				if (node.type == null) {
					parameterScope.assignTypesForAuto(compileContext);
					if (node.type == null) {
						node.print(0);
						assert(false);
					}
				}
				
				// All function/method body folding is done here:
				
				node = node.fold(file.tree(), false, compileContext);
				
				allocateStackForLocalVariables(compileContext);
				
				if (func.functionCategory() == Function.Category.CONSTRUCTOR)
					generateConstructorPreamble(parameterScope, compileContext);

				ref<Scope> outer = compileContext.setCurrent(scope);
				generate(node, compileContext);
				compileContext.setCurrent(outer);
				compileContext.resetVariables(initialVariableCount);
				_stackLocalVariables = initialVariableCount;
			}
			closeCodeSegment(CC.NOP, null);
			insertPreamble();
			inst(X86.ENTER, 0);
			int registerArgs = 0;
			int frameSize = 0;
			if (parameterScope.hasThis()) {
				inst(X86.PUSH, TypeFamily.SIGNED_64, R.RSI);
				frameSize += address.bytes;
				inst(X86.MOV, TypeFamily.ADDRESS, R.RSI, R.RCX);
				registerArgs++;
/*
 * TODO: Fix this up for a proper test. You can't use this simple test, you need to account for
 * subclasses.
				if (parameterScope.enclosing().hasVtable()) {
					instLoadVtable(R.RAX, ref<ClassScope>(parameterScope.enclosing()));
					inst(X86.CMP, TypeFamily.ADDRESS, R.RSI, 0, R.RAX);
					ref<CodeSegment> join = new CodeSegment;
					closeCodeSegment(CC.JE, join);
					inst(X86.XOR, TypeFamily.BOOLEAN, R.RCX, R.RCX);
					instCall(_assert.parameterScope(), compileContext);
					join.start(this);
				}
 */
			}
			if (parameterScope.hasOutParameter(compileContext)) {
				frameSize += address.bytes;
				inst(X86.PUSH, TypeFamily.SIGNED_64, fastArgs[registerArgs]);
				registerArgs++;
			}
			for (int i = 0; i < parameterScope.parameters().length(); i++) {
				ref<Symbol> sym = parameterScope.parameters()[i];
				
				if (sym.deferAnalysis())
					continue;
				if (registerArgs < fastArgs.length() && !sym.type().passesViaStack(compileContext)) {
					if (sym.type().isFloat()) {
						inst(X86.SUB, TypeFamily.SIGNED_64, R.RSP, 8);
						inst(X86.MOVSD, TypeFamily.SIGNED_64, R.RSP, 0, floatArgs[registerArgs]);
					} else
						inst(X86.PUSH, TypeFamily.SIGNED_64, fastArgs[registerArgs]);
					frameSize += address.bytes;
					registerArgs++;
				}
			}
			reserveAutoMemory(false, compileContext, frameSize);
			closeCodeSegment(CC.NOP, null);
			if (node.fallsThrough() == Test.PASS_TEST) {
				if (!generateReturn(scope, compileContext)) {
					node.print(0);
					assert(false);
				}
			}
		} else {
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.RBX);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.RSI);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.RDI);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.R12);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.R13);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.R14);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.R15);
			inst(X86.PUSH, TypeFamily.SIGNED_64, R.RCX);
			ref<CodeSegment> handler = new CodeSegment;
			pushExceptionHandler(handler);
			_arena.clearStaticInitializers();
			// Now we have to generate the various static blocks for included units.
			while (_arena.collectStaticInitializers(this))
				;
			if (_arena.verbose)
				printf("Static initializers:\n");
//			printf("staticBlocks %d\n", staticBlocks().length());
			int initialVariableCount = compileContext.variableCount();
			for (int i = 0; i < staticBlocks().length(); i++) {
				ref<FileStat> file = staticBlocks()[i];
				if (file != scope.file()) {
					if (_arena.verbose)
						printf("   %s\n", file.filename());
					generateStaticBlock(file, compileContext);
				}
			}
			for (int i = 0; i < _arena.types().length(); i++) {
				ref<TemplateInstanceType> t = _arena.types()[i];
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
			ref<Symbol> main = scope.lookup("main");
			if (main != null &&
				main.class == Overload) {
				ref<Overload> m = ref<Overload>(main);
				// Confirm that it has 'function int(string[])' type
				// generate call to main
				// MOV RCX,input - find some place to put it.
				inst(X86.POP, TypeFamily.SIGNED_64, R.RCX);
				inst(X86.PUSH, TypeFamily.SIGNED_64, R.RCX);
				inst(X86.PUSH, R.RCX, 8);
				inst(X86.PUSH, R.RCX, 0);
				ref<OverloadInstance> instance = m.instances()[0];
				instCall(instance.parameterScope(), compileContext);
				// return value is in RAX
			} else {
//				inst(X86.POP, TypeFamily.SIGNED_64, R.RCX);
				inst(X86.XOR, TypeFamily.SIGNED_64, R.RAX, R.RAX);
			}
			pushExceptionHandler(null);
			ref<CodeSegment> join = new CodeSegment;
			closeCodeSegment(CC.NOP, null);
			insertPreamble();
			inst(X86.ENTER, 0);
			reserveAutoMemory(true, compileContext, 0);
			closeCodeSegment(CC.NOP, null);
			join.start(this);
			inst(X86.POP, TypeFamily.SIGNED_64, R.RCX);
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
			handler.start(this);
			inst(X86.LEA, R.RSP, R.RBP, -(f().autoSize + 8 * address.bytes));
			closeCodeSegment(CC.JMP, join);
		}
	}

	private void reserveAutoMemory(boolean preserveRCX, ref<CompileContext> compileContext, int frameSize) {
		frameSize &= 15;											// Reduce the calculated frame size to 0-15.
		int zeroZone = f().autoSize - f().registerSaveSize;
		f().autoSize += REGISTER_PARAMETER_STACK_AREA;
		if (((f().autoSize + frameSize) & 15) != 0)					// Now if the combined size is odd, bail out.
			f().autoSize = (f().autoSize + frameSize + 15) & ~15;
		int reserveSpace = f().autoSize - f().registerSaveSize;
		inst(X86.SUB, TypeFamily.SIGNED_64, R.RSP, reserveSpace);
		if (zeroZone > 0) {
			if (preserveRCX)
				inst(X86.PUSH, TypeFamily.SIGNED_64, R.RCX);
			inst(X86.MOV, TypeFamily.ADDRESS, R.RCX, R.RSP);
			if (preserveRCX)
				inst(X86.ADD, TypeFamily.ADDRESS, R.RCX, address.bytes);
			inst(X86.XOR, TypeFamily.UNSIGNED_8, R.RDX, R.RDX);
			inst(X86.MOV, TypeFamily.SIGNED_32, R.R8, reserveSpace);
			instCall(_memset.parameterScope(), compileContext);
			if (preserveRCX)
				inst(X86.POP, TypeFamily.SIGNED_64, R.RCX);
		}
	}

	private void allocateStackForLocalVariables(ref<CompileContext> compileContext) {
		ref<Variable>[] v = compileContext.variables();
//		if (_stackLocalVariables < v.length())
//			printf("-- Scope %p\n", f().current);
		for (int i = _stackLocalVariables; i < v.length(); i++) {
			ref<Variable> var = v[i];
			int sz;
			if (var.type != null)
				sz = var.type.stackSize();
			else if (var.returns != null) {
				for (ref<NodeList> nl = var.returns; nl != null; nl = nl.next) {
					int nlSize = nl.node.type.stackSize();
					sz += nlSize;
				}
			}
			f().autoSize += sz;
			var.offset = -f().autoSize;
//			printf("Var [%d] %p offset %d\n", i, var, var.offset);
		}
//		if (_stackLocalVariables < v.length())
//			printf("<<\n");
		_stackLocalVariables = v.length();
	}
	
	private void generateConstructorPreamble(ref<ParameterScope> scope, ref<CompileContext> compileContext) {
		if (scope.enclosing().hasVtable()) {
//			instStoreVTable(R.RSI, R.RAX, ref<ClassScope>(scope.enclosing()));
			if (scope.enclosing().variableStorage > address.bytes) {
				inst(X86.LEA, R.RCX, R.RSI, address.bytes);
				inst(X86.XOR, TypeFamily.ADDRESS, R.RDX, R.RDX);
				inst(X86.MOV, TypeFamily.SIGNED_32, R.R8, scope.enclosing().variableStorage - address.bytes);
				instCall(_memset.parameterScope(), compileContext);
			}
		} else {
			inst(X86.MOV, TypeFamily.ADDRESS, R.RCX, R.RSI);
			inst(X86.XOR, TypeFamily.ADDRESS, R.RDX, R.RDX);
			inst(X86.MOV, TypeFamily.SIGNED_32, R.R8, scope.enclosing().variableStorage);
			instCall(_memset.parameterScope(), compileContext);
		}
		// TODO: add code to check for absence of super. or self. calls at the head of the node
//					generateCallToBaseDefaultConstructor(parameterScope, compileContext);
	}
	
	private void generateCallToBaseDefaultConstructor(ref<ParameterScope> scope, ref<CompileContext> compileContext) {
		ref<ClassScope> classScope = ref<ClassScope>(scope.enclosing());
		ref<Scope> base = classScope.getSuper().scope();
		if (base != null) {
			ref<ParameterScope> baseDefaultConstructor = base.defaultConstructor(); 
			if (baseDefaultConstructor != null)
				instCall(baseDefaultConstructor, compileContext);
		}
	}
	
	private void generateStaticBlock(ref<FileStat> file, ref<CompileContext> compileContext) {
		
		// Here is where all static initializers are folded:
		
		ref<Node> n = file.tree().root().fold(file.tree(), true, compileContext);
		
		allocateStackForLocalVariables(compileContext);
		if (file.fileScope() != null)
			compileContext.setCurrent(file.fileScope());
		else
			compileContext.setCurrent(_arena.root());
		generate(n, compileContext);
	}
	
	private void generate(ref<Node> node, ref<CompileContext> compileContext) {
		if (node.deferGeneration())
			return;
		if (verbose()) {
			printf("-----  generate  ---------\n");
			f().r.print();
			node.print(4);
		}
		switch (node.op()) {
		case	BLOCK:
		case	UNIT:
			ref<Block> block = ref<Block>(node);
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

		case	SEQUENCE:
			b = ref<Binary>(node);
			generate(b.left(), compileContext);
			generate(b.right(), compileContext);
			break;
			
		case	CONDITIONAL:
			cond = ref<Ternary>(node);
			trueSegment = new CodeSegment;
			falseSegment = new CodeSegment;
			join = new CodeSegment;
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
			inst(X86.XOR, TypeFamily.BOOLEAN, R(int(node.register)), 1);
			break;
			
		case	LOGICAL_OR:
			b = ref<Binary>(node);
			join = new CodeSegment;
			trueSegment = new CodeSegment;
			generate(b.left(), compileContext);
			inst(X86.CMP, b.left(), 1, compileContext);
			closeCodeSegment(CC.JE, trueSegment);
			generate(b.right(), compileContext);
			if (node.register != b.right().register)
				inst(X86.MOV, node, b.right(), compileContext);
			closeCodeSegment(CC.JMP, join);
			trueSegment.start(this);
			inst(X86.MOV, node, 1, compileContext);
			join.start(this);
			break;
			
		case	LOGICAL_AND:
			b = ref<Binary>(node);
			falseSegment = new CodeSegment;
			join = new CodeSegment;
			generate(b.left(), compileContext);
			inst(X86.CMP, b.left(), 1, compileContext);
			closeCodeSegment(CC.JNE, falseSegment);
			generate(b.right(), compileContext);
			if (node.register != b.right().register)
				inst(X86.MOV, node, b.right(), compileContext);
			closeCodeSegment(CC.JMP, join);
			falseSegment.start(this);
			inst(X86.XOR, node, node, compileContext);
			join.start(this);
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
			ref<CodeSegment> trueSegment = new CodeSegment;
			ref<CodeSegment> falseSegment = new CodeSegment;
			ref<CodeSegment> join = new CodeSegment;
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
			trueSegment = new CodeSegment;
			falseSegment = new CodeSegment;
			join = new CodeSegment;
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

			ref<CodeSegment> testSegment = new CodeSegment;
			join = new CodeSegment;
			topOfLoop = new CodeSegment;

			closeCodeSegment(CC.JMP, testSegment);
			topOfLoop.start(this);
			generateExpressionStatement(forStmt.increment(), compileContext);
			testSegment.start(this);
			if (forStmt.test().op() != Operator.EMPTY) {
				trueSegment = new CodeSegment;
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

		case	WHILE:
			b = ref<Binary>(node);
			trueSegment = new CodeSegment;
			join = new CodeSegment;
			ref<CodeSegment> topOfLoop = new CodeSegment;
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
			join = new CodeSegment;
			trueSegment = new CodeSegment;
			topOfLoop = new CodeSegment;
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
			ref<CodeSegment> defaultSegment = new CodeSegment;
			join = new CodeSegment;
			GatherCasesClosure closure;
			closure.target = this;
			gatherCases(b.right(), &closure);
			JumpContext switchContext(b, join, defaultSegment, &closure.nodes, this, jumpContext());
			markAddressModes(b.left(), compileContext);
			sethiUllman(b.left(), compileContext, this);
			assignVoidContext(node, compileContext);		// Take the result in any register available.
			emitSourceLocation(compileContext.current().file(), node.location());
			generate(b.left(), compileContext);
			ref<CodeSegment>[] labels = switchContext.caseLabels();
			int mask = ~0;
			R controlReg = R(int(b.left().register));
			switch (b.left().type.family()) {
			case	UNSIGNED_8:
				inst(X86.MOVZX, controlReg, b.left(), compileContext);
				mask = 0xff;
			case	SIGNED_32:
				for (int i = 0; i < labels.length(); i++) {
					ref<Binary> caseNode = ref<Binary>(closure.nodes[i]);
					if (caseNode.left().deferGeneration()) {
						// TODO: generate exception
						continue;
					}
					int x = int(caseNode.left().foldInt(compileContext));
					inst(X86.CMP, b.left().type.family(), controlReg, x & mask);
					closeCodeSegment(CC.JE, labels[i]);
					ref<CodeSegment> n = new CodeSegment;
					n.start(this);
				}
				closeCodeSegment(CC.JMP, defaultSegment);
				break;

			case	ENUM:
				for (int i = 0; i < labels.length(); i++) {
					ref<Binary> caseNode = ref<Binary>(closure.nodes[i]);
					if (caseNode.left().deferGeneration()) {
						// TODO: generate exception
						continue;
					}
					ref<Identifier> c = ref<Identifier>(caseNode.left());
					if (c.symbol() != null) {
						ref<EnumInstanceType> t = ref<EnumInstanceType>(b.left().type);
						loadEnumType(R(int(node.register)), t.symbol(), c.symbol().offset * int.bytes);
						inst(X86.CMP, TypeFamily.SIGNED_64, controlReg, R(int(node.register)));
						closeCodeSegment(CC.JE, labels[i]);
						ref<CodeSegment> n = new CodeSegment;
						n.start(this);
					} else
						unfinished(c, "enum switch", compileContext);
				}
				closeCodeSegment(CC.JMP, defaultSegment);
				break;

			default:
				if (b.left().deferAnalysis())
					return;
				b.print(4);
				unfinished(b, "switch type", compileContext);
			}
			pushJumpContext(&switchContext);
			generate(b.right(), compileContext);
			popJumpContext();
			defaultSegment = switchContext.defaultLabel();
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
			context.defaultLabel().start(this);
			generate(expression.operand(), compileContext);
			break;
			
		case	BREAK:
			closeCodeSegment(CC.JMP, jumpContext().breakLabel());
			break;
			
		case	CONTINUE:
			closeCodeSegment(CC.JMP, jumpContext().continueLabel());
			break;
			
		case	RETURN:
			ref<Return> retn = ref<Return>(node);
			emitSourceLocation(compileContext.current().file(), node.location());
			ref<NodeList> arguments = retn.arguments();
			if (arguments != null) {
				for (ref<NodeList> nl = arguments; nl != null; nl = nl.next) {
					markAddressModes(nl.node, compileContext);
					sethiUllman(nl.node, compileContext, this);
				}
				if (arguments.next == null) {
					assignSingleReturn(retn, arguments.node, compileContext);
					ref<Function> enclosing = f().current.enclosingFunction();
					ref<FunctionType> functionType = ref<FunctionType>(enclosing.type);
					ref<NodeList> returnType = functionType.returnType();
					if (returnType.next != null || 
						returnType.node.type.returnsViaOutParameter(compileContext))
						generateOutParameter(arguments.node, 0, compileContext);
					else
						generate(arguments.node, compileContext);
					f().r.generateSpills(node, this);
				} else {
					int outOffset = 0;
					for (ref<NodeList> nl = arguments; nl != null; nl = nl.next) {
						assignMultiReturn(retn, nl.node, compileContext);
						generateOutParameter(nl.node, outOffset, compileContext);
						outOffset += nl.node.type.stackSize();
					}
				}
			} 
			if (!generateReturn(f().current, compileContext))
				unfinished(retn, "failed return generation", compileContext);
			break;
			
		case	CLASS_DECLARATION:
			b = ref<Binary>(node);
			node = b.right();			// Get the CLASS node
			if (node.op() != Operator.CLASS)
				break;
			ref<Class> classNode = ref<Class>(node);
			for (ref<NodeList> nl = classNode.statements(); nl != null; nl = nl.next)
				generateStaticInitializers(nl.node, compileContext);
			break;
			
		case	ENUM_DECLARATION:
		case	DECLARE_NAMESPACE:
		case	IMPORT:
		case	EMPTY:
			break;
			
		case	FUNCTION:
			ref<Function> func = ref<Function>(node);
			if (func.body != null) {
				if (func.name() == null) {
					ref<ParameterScope> functionScope = _arena.createParameterScope(compileContext.current(), func, StorageClass.PARAMETER);
					ref<Scope> funcScope;
					boolean isBuiltIn;
										
					(funcScope, isBuiltIn) = getFunctionAddress(functionScope, compileContext);
					if (isBuiltIn)
						instBuiltIn(X86.MOV, R(func.register), functionScope.value);
					else
						instFunc(X86.MOV, R(func.register), functionScope);
				}
			}
			break;
			
		case	CLASS_COPY:
			b = ref<Binary>(node);
			generateOperands(b, compileContext);
			inst(X86.MOV, TypeFamily.SIGNED_32, R.R8, b.type.size());
			instCall(_memcpy.parameterScope(), compileContext);
			break;

		case	ASSIGN:
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
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	SIGNED_16:
				case	SIGNED_32:
				case	UNSIGNED_32:
				case	SIGNED_64:
				case	BOOLEAN:
				case	ENUM:
				case	FUNCTION:
				case	ADDRESS:
				case	REF:
				case	POINTER:
					generateOperands(b, compileContext);
	//				printf("\n\n---- ASSIGN ----\n");
	//				b.print(4);
					if (b.register == 0)
						inst(X86.MOV, b.left(), b.right(), compileContext);
					else {
						inst(X86.MOV, R(b.register), b.right(), compileContext);
						inst(X86.MOV, b.left(), R(b.register), compileContext);
					}
					break;
					
				case	FLOAT_32:
					generateOperands(b, compileContext);
					inst(X86.MOVSS, b.left(), b.right(), compileContext);
					break;
					
				case	FLOAT_64:
					generateOperands(b, compileContext);
					inst(X86.MOVSD, b.left(), b.right(), compileContext);
					break;
					
				case	CLASS:
					generateOperands(b, compileContext);
					inst(X86.MOV, b.left(), b.right(), compileContext);
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
				case	SIGNED_32:
				case	SIGNED_64:
					inst(X86.AND, b.left(), b.right(), compileContext);
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
				case	SIGNED_32:
				case	SIGNED_64:
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
					inst(X86.AND, b, b.right(), compileContext);
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
				case	SIGNED_32:
				case	SIGNED_64:
					inst(X86.OR, b.left(), b.right(), compileContext);
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
				case	SIGNED_32:
				case	SIGNED_64:
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
					inst(X86.OR, b, b.right(), compileContext);
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
				case	SIGNED_32:
				case	SIGNED_64:
					inst(X86.XOR, b.left(), b.right(), compileContext);
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
				case	SIGNED_32:
				case	SIGNED_64:
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
					inst(X86.XOR, b, b.right(), compileContext);
					inst(X86.MOV, b.left(), R(int(b.register)), compileContext);
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
				
			case	SIGNED_32:
			case	SIGNED_64:
				inst(X86.CWD, b.type.family(), R.RAX);
				inst(X86.IDIV, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.RAX, compileContext);
				break;
				
			case	FLOAT_32:
				inst(X86.MOVSS, b, b.left(), compileContext);
				inst(X86.DIVSS, b, b.right(), compileContext);
				inst(X86.MOVSS, b.left(), b, compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.MOVSD, b, b.left(), compileContext);
				inst(X86.DIVSD, b, b.right(), compileContext);
				inst(X86.MOVSD, b.left(), b, compileContext);
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
				inst(X86.IMUL, R(int(b.left().register)), b.right(), compileContext);
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
				inst(X86.MULSS, b.left(), b.right(), compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.MULSD, b.left(), b.right(), compileContext);
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
			case	SIGNED_32:
			case	SIGNED_64:
				inst(X86.MOV, R.RAX, b.left(), compileContext);
				inst(X86.MUL, R.RAX, b.right(), compileContext);
				inst(X86.MOV, b.left(), R.RAX, compileContext);
				break;
				
			case	FLOAT_32:
				inst(X86.MULSS, b.right(), b.left(), compileContext);
				inst(X86.MOVSS, b.left(), b.right(), compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.MULSD, b.right(), b.left(), compileContext);
				inst(X86.MOVSD, b.left(), b.right(), compileContext);
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
			case	SIGNED_32:
			case	SIGNED_64:
				t = b.left().type.indirectType(compileContext);
				if (t != null && t.size() > 1) {
					inst(X86.XOR, b.type.family(), R.RDX, R.RDX);
					inst(X86.SUB, b.left(), b.right(), compileContext);
					inst(X86.SBB, TypeFamily.SIGNED_64, R.RDX, 0);
					inst(X86.MOV, TypeFamily.SIGNED_64, R.RCX, t.size());
					inst(X86.IDIV, TypeFamily.SIGNED_64, R.RCX);
				} else if (b.register == 0 || b.op() == Operator.SUBTRACT)
					inst(X86.SUB, b.left(), b.right(), compileContext);
				else {
					inst(X86.MOV, b, b.left(), compileContext);
					inst(X86.SUB, b, b.right(), compileContext);
					inst(X86.MOV, b.left(), b, compileContext);
				}
				break;
				
			case	ADDRESS:
				inst(X86.MOVSXD, b.right(), b.right(), compileContext);
				inst(X86.SUB, b.left(), b.right(), compileContext);
				break;

			case	FLOAT_32:
				if (b.op() == Operator.SUBTRACT)
					inst(X86.SUBSS, b.left(), b.right(), compileContext);
				else {
					inst(X86.MOVSS, b, b.left(), compileContext);
					inst(X86.SUBSS, b, b.right(), compileContext);
					inst(X86.MOVSS, b.left(), b, compileContext);
				}
				break;
				
			case	FLOAT_64:
				if (b.op() == Operator.SUBTRACT)
					inst(X86.SUBSD, b.left(), b.right(), compileContext);
				else {
					inst(X86.MOVSD, b, b.left(), compileContext);
					inst(X86.SUBSD, b, b.right(), compileContext);
					inst(X86.MOVSD, b.left(), b, compileContext);
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
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	POINTER:
				generateOperands(b, compileContext);
				if (b.register == 0 || b.op() == Operator.ADD)
					inst(X86.ADD, b.left(), b.right(), compileContext);
				else {
					inst(X86.MOV, b, b.left(), compileContext);
					inst(X86.ADD, b, b.right(), compileContext);
					inst(X86.MOV, b.left(), b, compileContext);
				}
				break;
				
			case	FLOAT_32:
				generateOperands(b, compileContext);
				if (b.op() == Operator.ADD)
					inst(X86.ADDSS, b.left(), b.right(), compileContext);
				else {
					inst(X86.ADDSS, b.right(), b.left(), compileContext);
					inst(X86.MOVSS, b.left(), b.right(), compileContext);
				}
				break;
				
			case	FLOAT_64:
				generateOperands(b, compileContext);
				if (b.op() == Operator.ADD)
					inst(X86.ADDSD, b.left(), b.right(), compileContext);
				else {
					inst(X86.ADDSD, b.right(), b.left(), compileContext);
					inst(X86.MOVSD, b.left(), b.right(), compileContext);
				}
				break;
				
			case	STRING:
				if (b.op() == Operator.ADD) {
					b.type.print();
					printf("\n");
					unfinished(node, "string +", compileContext);
				} else {
					generateOperands(b, compileContext);
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
			case	SIGNED_32:
			case	SIGNED_64:
				if (b.register == 0)
					inst(X86.SAL, b.left(), b.right(), compileContext);
				else {
					inst(X86.SAL, b.left(), b.right(), compileContext);
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
					inst(X86.SHR, b.left(), b.right(), compileContext);
				else {
					inst(X86.SHR, b.left(), b.right(), compileContext);
					inst(X86.MOV, R(int(b.register)), b.left(), compileContext);
				}
				break;
				
			case	SIGNED_32:
			case	SIGNED_64:
				if (b.register == 0 || b.op() == Operator.SUBTRACT)
					inst(X86.SAR, b.left(), b.right(), compileContext);
				else {
					inst(X86.SAR, b.left(), b.right(), compileContext);
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
			case	SIGNED_32:
			case	SIGNED_64:
				if (b.register == 0 || b.op() == Operator.SUBTRACT)
					inst(X86.SHR, b.left(), b.right(), compileContext);
				else {
					inst(X86.SHR, b.left(), b.right(), compileContext);
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
			int size = t.size();
			f().r.generateSpills(node, this);
			inst(X86.MOV, TypeFamily.SIGNED_64, R.RCX, size);
			instCall(_allocz.parameterScope(), compileContext);
			break;

		case	DELETE:
			b = ref<Binary>(node);
			assert(b.left().op() == Operator.EMPTY);
			generate(b.right(), compileContext);
			f().r.generateSpills(node, this);
			instCall(_free.parameterScope(), compileContext);
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
					inst(X86.MOVSD, expression, expression.operand(), compileContext);
					inst(X86.ADDSD, R(expression.register), _doubleOne);
					inst(X86.MOVSD, expression.operand(), expression, compileContext);
				} else {
					inst(X86.MOVSS, expression, expression.operand(), compileContext);
					inst(X86.ADDSS, R(expression.register), _floatOne);
					inst(X86.MOVSS, expression.operand(), expression, compileContext);
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
					inst(X86.MOVSD, expression, expression.operand(), compileContext);
					inst(X86.SUBSD, R(expression.register), _doubleOne);
					inst(X86.MOVSD, expression.operand(), expression, compileContext);
				} else {
					inst(X86.MOVSS, expression, expression.operand(), compileContext);
					inst(X86.SUBSS, R(expression.register), _floatOne);
					inst(X86.MOVSS, expression.operand(), expression, compileContext);
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
					inst(X86.MOVSD, expression, expression.operand(), compileContext);
					inst(X86.ADDSD, R(expression.register), _doubleOne);
					inst(X86.MOVSD, expression.operand(), expression, compileContext);
					inst(X86.SUBSD, R(expression.register), _doubleOne);
				} else {
					inst(X86.MOVSS, expression, expression.operand(), compileContext);
					inst(X86.ADDSS, R(expression.register), _floatOne);
					inst(X86.MOVSS, expression.operand(), expression, compileContext);
					inst(X86.SUBSS, R(expression.register), _floatOne);
				}
				break;
			}
			inst(X86.MOV, expression, expression.operand(), compileContext);
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
					inst(X86.MOVSD, expression, expression.operand(), compileContext);
					inst(X86.SUBSD, R(expression.register), _doubleOne);
					inst(X86.MOVSD, expression.operand(), expression, compileContext);
					inst(X86.ADDSD, R(expression.register), _doubleOne);
				} else {
					inst(X86.MOVSS, expression, expression.operand(), compileContext);
					inst(X86.SUBSS, R(expression.register), _floatOne);
					inst(X86.MOVSS, expression.operand(), expression, compileContext);
					inst(X86.ADDSS, R(expression.register), _floatOne);
				}
				break;
			}
			inst(X86.MOV, expression, expression.operand(), compileContext);
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
			
		case	INDIRECT:
			expression = ref<Unary>(node);
			generate(expression.operand(), compileContext);
			f().r.generateSpills(expression, this);
			if ((expression.flags & ADDRESS_MODE) == 0) {
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
			
		case	SUBSCRIPT:
			b = ref<Binary>(node);

			if (b.left().type.family() == TypeFamily.STRING) {
				generateOperands(b, compileContext);
				inst(X86.MOVSXD, b.right(), b.right(), compileContext);
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
				inst(X86.XORPS, expression, expression.operand(), compileContext);
				break;
				
			case	FLOAT_64:
				inst(X86.MOVSD, R(node.register), _doubleSignMask);
				inst(X86.XORPD, expression, expression.operand(), compileContext);
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
			R dest = R(int(node.register));
			node.register = 0;
			inst(X86.LEA, dest, node, compileContext);
			node.register = byte(int(dest));
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
			if ((node.flags & ADDRESS_MODE) != 0)
				break;
			ref<Constant> c = ref<Constant>(node);
			switch (c.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
				inst(X86.MOV, c.type.family(), R(int(node.register)), c.intValue());
				break;
				
			default:
				node.print(0);
				unfinished(node, "generate INTEGER", compileContext);
			}
			break;

		case	CHARACTER:
			if ((node.flags & ADDRESS_MODE) != 0)
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
			case	VAR:
				generate(expression.operand(), compileContext);
				inst(X86.MOV, expression, expression.operand(), compileContext);
				break;
				
			case	REF:
			case	POINTER:
				generate(expression.operand(), compileContext);
				if (expression.operand().op() == Operator.EMPTY)
					instLoadType(R(int(expression.register)), expression.operand().type);
				else if (expression.operand().type.indirectType(compileContext).hasVtable()) {
					inst(X86.MOV, expression, expression.operand(), compileContext);
					inst(X86.MOV, R(expression.register), R(expression.register), 0);
					inst(X86.MOV, R(expression.register), R(expression.register), 0);
				} else
					instLoadType(R(expression.register), expression.operand().type.indirectType(compileContext));
				break;

			default:
				instLoadType(R(expression.register), expression.operand().type);
			}
			break;
			
		case	DOT:
			ref<Selection> dot = ref<Selection>(node);
			generate(dot.left(), compileContext);
			if ((node.flags & ADDRESS_MODE) != 0)
				break;
			switch (dot.type.family()) {
			case	VAR:
				node.print(0);
				assert(false);
				break;
				
			case	FUNCTION:
				if (generateFunctionAddress(node, compileContext))
					break;
				
			default:
				switch (dot.symbol().storageClass()) {
				case ENUMERATION:
					if (dot.symbol().value == null) {
						node.print(0);
						assert(false);
						break;
					}
					ref<EnumInstanceType> t = ref<EnumInstanceType>(dot.type);
					loadEnumType(R(dot.register), t.symbol(), 0);
					inst(X86.ADD, TypeFamily.ENUM, R(dot.register), dot.symbol().offset * int.bytes);
					break;

				default:
					if ((dot.flags & ADDRESS_MODE) == 0)
						generateLoad(X86.MOV, dot, compileContext);
				}
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
			if ((node.flags & ADDRESS_MODE) != 0)
				break;
			if (node.type.family() == TypeFamily.FUNCTION &&
				generateFunctionAddress(node, compileContext))
				break;

		case	VARIABLE:
		case	THIS:
		case	SUPER:
			if ((node.flags & ADDRESS_MODE) != 0)
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
			
		default:
			node.print(0);
			assert(false);
		}
	}

	private void generateOutParameter(ref<Node> value, int outOffset, ref<CompileContext> compileContext) {
		if (value.op() == Operator.SEQUENCE) {
			generate(ref<Binary>(value).left(), compileContext);
			generateOutParameter(ref<Binary>(value).right(), outOffset, compileContext);
		} else if (value.register != 0) {
			generate(value, compileContext);
			f().r.generateSpills(value, this);
			if (value.register == int(R.RAX)) {
				inst(X86.MOV, R.RCX, R.RBP, f().outParameterOffset);
				inst(X86.MOV, value.type.family(), R.RCX, outOffset, R(int(value.register)));
			} else {
				inst(X86.MOV, R.RAX, R.RBP, f().outParameterOffset);
				inst(X86.MOV, value.type.family(), R.RAX, outOffset, R(int(value.register)));
			}
		} else if (value.isLvalue()) {
			value.flags |= ADDRESS_MODE;
			generate(value, compileContext);
			f().r.generateSpills(value, this);
			inst(X86.LEA, R.RDX, value, compileContext);
			inst(X86.MOV, R.RCX, R.RBP, f().outParameterOffset);
			if (outOffset > 0)
				inst(X86.ADD, R.RCX, outOffset);
			inst(X86.MOV, TypeFamily.SIGNED_32, R.R8, value.type.size());
			instCall(_memcpy.parameterScope(), compileContext);
		} else {
			value.print(0);
			assert(false);
		}
	}
	
	private boolean generateFunctionAddress(ref<Node> node, ref<CompileContext> compileContext) {
		ref<Symbol> symbol = node.symbol();
		if (symbol == null || symbol.class != OverloadInstance)
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
			ref<Class> classNode = ref<Class>(node);
			for (ref<NodeList> nl = classNode.statements(); nl != null; nl = nl.next)
				generateStaticInitializers(nl.node, compileContext);
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
		case	ENUM_DECLARATION:
			break;
			
		case	SEQUENCE:
			b = ref<Binary>(node);
			generateStaticInitializers(b.left(), compileContext);
			generateStaticInitializers(b.right(), compileContext);
			break;
			
		case	CALL:			// must be a constructor
			generateInitializers(node, compileContext);
			break;
			
		default:
			node.print(0);
			assert(false);
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
		R reg = R(int(expression.register));
		expression.register = 0;
		inst(instruction, reg, expression, compileContext);
		expression.register = byte(int(reg));
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
					inst(X86.MOVSXD, x.right(), x.right(), compileContext);
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
			ref<CodeSegment> secondTest = new CodeSegment;
			generateConditional(b.left(), secondTest, falseSegment, compileContext);
			secondTest.start(this);
			generateConditional(b.right(), trueSegment, falseSegment, compileContext);
			return;
			
		case	LOGICAL_OR:
			b = ref<Binary>(node);
			secondTest = new CodeSegment;
			generateConditional(b.left(), trueSegment, secondTest, compileContext);
			secondTest.start(this);
			generateConditional(b.right(), trueSegment, falseSegment, compileContext);
			return;
			
		case	NOT:
			ref<Unary> u = ref<Unary>(node);
			generateConditional(u.operand(), falseSegment, trueSegment, compileContext);
			return;
			
		case	CALL:
			generate(node, compileContext);
			inst(X86.CMP, node, 0, compileContext);
			closeCodeSegment(CC.JE, falseSegment);
			break;
			
		case	DOT:
			ref<Selection> dot = ref<Selection>(node);
			generate(dot.left(), compileContext);
			
		case	IDENTIFIER:
			inst(X86.CMP, node, 0, compileContext);
			closeCodeSegment(CC.JE, falseSegment);
			break;
			
		default:
			printf("generateConditional\n");
			node.print(0);
			assert(false);
		}
		ref<CodeSegment> insurance = new CodeSegment;
		insurance.start(this);
		closeCodeSegment(CC.JMP, trueSegment);
	}

	private void generateCompare(ref<Binary> b, ref<CodeSegment> trueSegment, ref<CodeSegment> falseSegment, ref<CompileContext> compileContext) {
		generateOperands(b, compileContext);
		switch (b.left().type.family()) {
		case	UNSIGNED_32:
		case	SIGNED_32:
		case	SIGNED_64:
		case	CLASS:
		case	ENUM:
		case	TYPEDEF:
		case	ADDRESS:
		case	REF:
		case	POINTER:
		case	BOOLEAN:
		case	FUNCTION:
			inst(X86.CMP, b.left(), b.right(), compileContext);
			break;
			
		case	FLOAT_32:
			inst(X86.UCOMISS, b.left(), b.right(), compileContext);
			break;
			
		case	FLOAT_64:
			inst(X86.UCOMISD, b.left(), b.right(), compileContext);
			break;
			
		default:
			b.print(0);
			assert(false);
		}
		CC parityJump = parityTest(b.op(), b.left().type);
		switch (parityJump) {
		case	NOP:
			closeCodeSegment(continuation(invert(b.op()), b.left().type), falseSegment);
			break;
			
		case	JP:
			closeCodeSegment(continuation(b.op(), b.left().type), trueSegment);
			closeCodeSegment(CC.JNP, falseSegment);
			break;
			
		case	JNP:
			closeCodeSegment(continuation(invert(b.op()), b.left().type), falseSegment);
			closeCodeSegment(CC.JP, falseSegment);
			break;
			
		default:
			b.print(0);
			assert(false);
		}
	}
	
	private void generateInitializers(ref<Node> node, ref<CompileContext> compileContext) {
//		printf("generateInitializers\n");
//		node.print(4);
		boolean hasDefaultConstructor = false;
		if (node.type == null) {
			node.print(0);
			assert(false);
		}
		if (node.deferGeneration()) {
			// TODO: make this generate a runtime exception
			return;
		}
		switch (node.op()) {
		case	IDENTIFIER:
		case	VARIABLE:
			switch (node.type.family()) {
			case	CLASS:
			case	SHAPE:
				ref<Scope> scope = node.type.scope();
				for (int i = 0; i < scope.constructors().length(); i++) {
					ref<Scope> sc = scope.constructors()[i];
					if (sc.symbols().size() == 0) {
						inst(X86.LEA, R.RCX, node, compileContext);
						if (node.type.hasVtable())
							storeVtable(node.type, compileContext);
//						printf("Found a constructor!\n");
//						node.print(4);
//						sc.print(4, false);
						instCall(ref<ParameterScope>(sc), compileContext);
						hasDefaultConstructor = true;
						break;
					}
				}
			}
			if (!hasDefaultConstructor) {
				ref<Symbol> sym = node.symbol();
				if (sym != null &&
					sym.storageClass() == StorageClass.AUTO &&
					sym.type() != null &&
					sym.type().requiresAutoStorage()) {
					if (sym.type().hasVtable()) {
						assert(false);
						/*
						target.byteCode(ByteCodes.AUTO);
						target.byteCode(sym.offset);
						storeVtable(sym.type(), this, compileContext);
						target.byteCode(ByteCodes.POP);
						if (sym.type().size() > address.bytes) {
							target.byteCode(ByteCodes.ZERO_A);
							target.byteCode(int(sym.offset + address.bytes));
							target.byteCode(int(sym.type().size() - address.bytes)); 
						}
						*/
					} else {
						if (sym.type().size() <= address.bytes)
							inst(X86.MOV, node, 0, compileContext);
						else {
							inst(X86.LEA, R.RCX, node, compileContext);
							inst(X86.XOR, TypeFamily.ADDRESS, R.RDX, R.RDX);
							inst(X86.MOV, TypeFamily.SIGNED_32, R.R8, node.type.size());
							instCall(_memset.parameterScope(), compileContext);
						}
					}
					break;
				}
				if (node.type.hasVtable()) {
					inst(X86.LEA, R.RCX, node, compileContext);
					storeVtable(node.type, compileContext);
				}
			}
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
			
		case	CLASS_COPY:
			markAddressModes(node, compileContext);
			sethiUllman(node, compileContext, this);
			assignVoidContext(node, compileContext);
			ref<Binary> b = ref<Binary>(node);
			generateOperands(b, compileContext);
			inst(X86.MOV, TypeFamily.SIGNED_32, R.R8, b.type.size());
			instCall(_memcpy.parameterScope(), compileContext);
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
				if (call.target() == null || call.category() == CallCategory.CONSTRUCTOR) {
					assert(false);
					generateCall(call, compileContext);
					break;
				}
//				printf("not a special case\n");
			}
//			printf("Initialize:\n");
//			node.print(4);
//			print("-->>\n");
			switch (seq.type.family()) {
			case	STRING:
				node.print(0);
				assert(false);
				break;
				
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	SIGNED_32:
			case	UNSIGNED_32:
			case	SIGNED_64:
			case	BOOLEAN:
			case	ENUM:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
				generate(seq.right(), compileContext);
				inst(X86.MOV, seq.left(), seq.right(), compileContext);
				break;
				
			case	FLOAT_32:
				generate(seq.right(), compileContext);
//				printf("Spilling...\n");
//				seq.print(0);
				f().r.generateSpills(seq, this);
				inst(X86.MOVSS, seq.left(), seq.right(), compileContext);
				break;
				
			case	FLOAT_64:
				generate(seq.right(), compileContext);
//				printf("Spilling...\n");
//				seq.print(0);
				f().r.generateSpills(seq, this);
				inst(X86.MOVSD, seq.left(), seq.right(), compileContext);
				break;
				
			case	CLASS:
				generateOperands(seq, compileContext);
				inst(X86.MOV, seq.left(), R(int(seq.right().register)), compileContext);
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
		for (ref<NodeList> args = call.stackArguments(); args != null; args = args.next) {
			if (args.node.op() == Operator.ELLIPSIS_ARGUMENTS)
				cleanup = ref<EllipsisArguments>(args.node).stackConsumed(); 
			generate(args.node, compileContext);
		}

		if (call.arguments() != null) {
			// Now the register arguments.  They're pretty easy
			for (ref<NodeList> args = call.arguments(); args != null; args = args.next)
				generate(args.node, compileContext);
		}
		f().r.generateSpills(call, this);

		ref<Symbol> overload = call.overload();
		
		switch (call.category()) {
		case	CONSTRUCTOR:
			if (call.type.hasVtable() && (call.target() == null || call.target().op() != Operator.SUPER))
				storeVtable(call.type, compileContext);
			if (!instCall(ref<OverloadInstance>(overload).parameterScope(), compileContext)) {
				call.print(0);
				assert(false);
				return;
			}
			break;

		case	VIRTUAL_METHOD_CALL:
			inst(X86.MOV, R.RAX, R.RCX, 0);
			inst(X86.CALL, TypeFamily.ADDRESS, R.RAX, overload.offset * address.bytes);
			break;
			
		case	METHOD_CALL:
		case	FUNCTION_CALL:
			ref<Node> func = call.target();
			assert(func != null);
			if (func.type.family() == TypeFamily.VAR) {
				if (func.op() == Operator.DOT) {
					ref<Selection> f = ref<Selection>(func);
					ref<Node> left = f.left();
					if (left.type.family() == TypeFamily.VAR) {
						assert(false);
						/*
						if (f.indirect())
							generate(f.left(), compileContext);
						else
							pushAddress(f.left(), compileContext);
						target.byteCode(ByteCodes.STRING);
						ref<String> s = _owner.newString(f.name());
						if (s == null) {
							call.add(MessageId.BAD_STRING, compileContext.pool(), f.name());
							// emit(trap of some kind);
						} else
							target.byteCode(s.index());
						int count = 0;
						for (ref<NodeList> nl = call.arguments(); nl != null; nl = nl.next) {
							generate(nl.node, compileContext);
							count++;
						}
						target.byteCode(ByteCodes.INVOKE);
						target.byteCode(count);
						*/
						return;
					}
				}
				call.print(4);
				assert(false);
			}
			if (overload != null) {
				if (!instCall(ref<OverloadInstance>(overload).parameterScope(), compileContext)) {
					call.print(0);
					assert(false);
				}
			} else
				inst(X86.CALL, func);
			break;
			
		default:
			call.print(0);
			assert(false);
		}
		if (cleanup != 0)
			inst(X86.ADD, TypeFamily.SIGNED_64, R.RSP, cleanup);		// What about destructors?
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
				ref<Node> n = u.operand();
				switch (n.type.family()) {
				case	STRING:
					generate(n, compileContext);
					f().r.generateSpills(args.node, this);
					inst(X86.LEA, R.RCX, R.RSP, offset);
					instCall(_stringCopyConstructor.parameterScope(), compileContext);
					break;
					
				case	VAR:
					generatePush(n, compileContext);
					f().r.generateSpills(args.node, this);
					inst(X86.LEA, R.RCX, R.RSP, offset + var.bytes);
					instCall(_varCopyConstructor.parameterScope(), compileContext);
					break;
					
				case	CLASS:
					if (n.type.indirectType(compileContext) == null) {
						generatePush(n, compileContext);
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

	private void generatePush(ref<Node> node, ref<CompileContext> compileContext) {
		int size = (node.type.size() + (long.bytes - 1)) & ~(long.bytes - 1);
		switch (node.op()) {
		case	INDIRECT:
			ref<Unary> u = ref<Unary>(node);
			generate(u.operand(), compileContext);
			
		case	IDENTIFIER:
		case	VARIABLE:
			if ((node.flags & ADDRESS_MODE) != 0)
				node.print(0);
			assert ((node.flags & ADDRESS_MODE) == 0);
			break;
			
		case	DOT:
			if ((node.flags & ADDRESS_MODE) != 0)
				node.print(0);
			assert ((node.flags & ADDRESS_MODE) == 0);
			ref<Selection> dot = ref<Selection>(node);
			if (dot.symbol().storageClass() == StorageClass.ENUMERATION) {
				if (dot.symbol().value == null) {
					node.print(0);
					assert(false);
					break;
				}
				ref<EnumInstanceType> t = ref<EnumInstanceType>(dot.type);
				loadEnumType(R.RAX, t.symbol(), 0);
				inst(X86.ADD, TypeFamily.ENUM, R.RAX, dot.symbol().offset * int.bytes);
				inst(X86.PUSH, TypeFamily.SIGNED_64, R.RAX);
				return;
			}
			generate(dot.left(), compileContext);
			break;
			
		case	CALL:
			ref<Call> call = ref<Call>(node);
			if ((call.flags & PUSH_OUT_PARAMETER) != 0)
				inst(X86.SUB, TypeFamily.SIGNED_64, R.RSP, call.type.stackSize());
			generate(call, compileContext);
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
			inst(X86.PUSH, TypeFamily.ADDRESS, R.RSI);
			return;
			
		case	CAST:
		case	BYTES:
		case	ADDRESS:
		case	NEGATE:
		case	INTEGER:
		case	MULTIPLY:
		case	ADD:
		case	SUBTRACT:
		case	AND:
		case	OR:
		case	CONDITIONAL:
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
		switch (existingType.family()) {
		case	BOOLEAN:
		case	UNSIGNED_8:
			switch (newType.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
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
				if (R(n.register) == R.AH) {
					// The only way that AH could get assigned is to use the result of a byte-% operator
					inst(X86.MOV, TypeFamily.UNSIGNED_8, R.RAX, R.AH);
					inst(X86.AND, newType.family(), R.RAX, 0xff);
				} else
					inst(X86.AND, newType.family(), R(result.register), 0xff);
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
				
			case	ENUM:
				if (R(n.register) == R.AH) {
					// The only way that AH could get assigned is to use the result of a byte-% operator
					inst(X86.MOV, TypeFamily.UNSIGNED_8, R.RAX, R.AH);
					inst(X86.AND, newType.family(), R.RAX, 0xff);
				} else
					inst(X86.AND, newType.family(), R(n.register), 0xff);
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
				return;
			}
			break;

		case	UNSIGNED_16:
			switch (newType.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	SIGNED_16:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				return;

			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				inst(X86.AND, newType.family(), R(result.register), 0xffff);
				return;

			case	ENUM:
				inst(X86.AND, newType.family(), R(n.register), 0xffff);
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
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
			switch (newType.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				return;

			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				inst(X86.SAL, TypeFamily.UNSIGNED_32, R(result.register), 32);
				inst(X86.SHR, TypeFamily.UNSIGNED_32, R(result.register), 32);
				return;

			case	ENUM:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				inst(X86.SAL, TypeFamily.UNSIGNED_32, R(n.register), 32);
				inst(X86.SHR, TypeFamily.UNSIGNED_32, R(n.register), 32);
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
				return;
				
			case	FLOAT_32:
			case	FLOAT_64:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
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
			switch (newType.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				return;

			case	UNSIGNED_32:
			case	SIGNED_32:
				inst(X86.MOVSX, result, n, compileContext);
				return;
				
			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
				inst(X86.MOVSX_REX_W, result, n, compileContext);
				return;
				
			case	FLOAT_32:
				inst(X86.CVTSI2SS, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSI2SD, result, n, compileContext);
				return;
				
			case	ENUM:
				inst(X86.MOVSX_REX_W, TypeFamily.ADDRESS, R(n.register), R(n.register));
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
				return;
			}
			break;

		case	SIGNED_32:
			switch (newType.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				return;

			case	SIGNED_64:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
				inst(X86.MOVSXD, result, n, compileContext);
				return;
				
			case	FLOAT_32:
				inst(X86.CVTSI2SS, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSI2SD, result, n, compileContext);
				return;
				
			case	ENUM:
				inst(X86.MOVSXD, TypeFamily.ADDRESS, R(n.register), R(n.register));
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
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
			switch (newType.family()) {
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
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				return;

			case	FLOAT_32:
				inst(X86.CVTSI2SS, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSI2SD, result, n, compileContext);
				return;
				
			case	ENUM:
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
				return;
			}
			break;

		case	FLOAT_32:
			switch (newType.family()) {
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
				inst(X86.CVTSS2SI, result, n, compileContext);
				return;

			case	FLOAT_32:
				return;
				
			case	FLOAT_64:
				inst(X86.CVTSS2SD, result, n, compileContext);
				return;
				
			case	ENUM:
				inst(X86.CVTSS2SI, result, n, compileContext);
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
				return;
			}
			break;

		case	FLOAT_64:
			switch (newType.family()) {
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
				inst(X86.CVTSD2SI, result, n, compileContext);
				return;

			case	FLOAT_32:
				inst(X86.CVTSD2SS, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				return;
				
			case	ENUM:
				inst(X86.CVTSD2SI, result, n, compileContext);
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
				return;
			}
			break;

		case	ADDRESS:
		case	REF:
		case	POINTER:
			switch (newType.family()) {
/*
			case	ADDRESS:
			case	FUNCTION:
				return;

				// The only valid conversion is for the NULL node.
				// so do nothing here.
				return;
*/
			case	BOOLEAN:
			case	ENUM:
			case	SIGNED_32:
			case	STRING:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	SIGNED_64:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				return;
			}
			break;

		case	ENUM:
			switch (newType.family()) {
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
				R dest = R(result.register);
				ref<EnumInstanceType> t = ref<EnumInstanceType>(existingType);
				loadEnumType(dest, t.symbol(), 0);
				inst(X86.SUB, dest, n, compileContext);
				inst(X86.SAR, dest, 1);
				inst(X86.SAR, dest, 1);
				inst(X86.NEG, newType.family(), dest);
				return;

			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	FUNCTION:
			case	ENUM:
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				return;

			case	FLOAT_32:
				R src = R(n.register);
				t = ref<EnumInstanceType>(existingType);
				result.print(0);
				assert(false);
				subEnumType(src, t.symbol(), 0);
				inst(X86.SAR, src, 1);
				inst(X86.SAR, src, 1);
				inst(X86.CVTSI2SS, result, n, compileContext);
				return;
				
			case	FLOAT_64:
				src = R(n.register);
				t = ref<EnumInstanceType>(existingType);
				result.print(0);
				assert(false);
				subEnumType(src, t.symbol(), 0);
				inst(X86.SAR, src, 1);
				inst(X86.SAR, src, 1);
				inst(X86.CVTSI2SD, result, n, compileContext);
				return;
			}
			break;

		case	CLASS:
			// A general class coercion from another class type.
			if (existingType.size() == newType.size())
				return;
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
			switch (newType.family()) {
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
				if ((n.flags & ADDRESS_MODE) != 0 || result.register != n.register)
					inst(X86.MOV, result, n, compileContext);
				return;

			case	FLOAT_32:
			case	FLOAT_64:
				if (newType.family() == TypeFamily.FLOAT_32)
					inst(X86.CVTSI2SS, TypeFamily.FLOAT_32, R(result.register), R(n.register));
				else
					inst(X86.CVTSI2SD, TypeFamily.FLOAT_64, R(result.register), R(n.register));
				return;
				
			case	ENUM:
				generateIntToEnum(result, n, ref<EnumInstanceType>(newType));
				return;
			}
			break;
		}
		printf("Convert from ");
		existingType.print();
		printf(" -> ");
		newType.print();
		printf("\n");
		n.print(4);
		assert(false);
	}

	private void generateIntToEnum(ref<Node> result, ref<Node> node, ref<EnumInstanceType> newType) {
		loadEnumType(R(int(result.register)), newType.symbol(), 0);
		loadEnumAddress(R(int(result.register)), R(int(node.register)));
	}
	
	private boolean generateReturn(ref<Scope> scope, ref<CompileContext> compileContext) {
		if (scope.definition() == null || scope.definition().op() != Operator.FUNCTION)			// in-line code
			inst(X86.RET);
		else {							// a function body
			ref<Function> func = ref<Function>(scope.definition());
			ref<FunctionType> functionType = ref<FunctionType>(func.type);
			if (functionType == null) {
				unfinished(func, "generateReturn functionType == null", compileContext);
				return true;
			}
			ref<ParameterScope> parameterScope = ref<ParameterScope>(scope);
			if (parameterScope.hasThis())
				inst(X86.MOV, R.RSI, R.RBP, -address.bytes);
			inst(X86.LEAVE);
			inst(X86.RET, parameterScope.variableStorage);
		}
		return true;
	}

	private void storeVtable(ref<Type> t, ref<CompileContext> compileContext) {
		ref<ClassScope> classScope = ref<ClassScope>(t.scope());
		buildVtable(classScope, compileContext);
		instStoreVTable(R.RCX, R.RAX, classScope);
	}

	private void cacheCodegenObjects() {
		ref<Scope> root = _arena.root();
		ref<Symbol> alloczOverload = root.lookup("allocz");
		if (alloczOverload.class == Overload) {
			ref<Overload> o = ref<Overload>(alloczOverload);
			_allocz = o.instances()[0];
		}
		ref<Symbol> freeOverload = root.lookup("free");
		if (freeOverload.class == Overload) {
			ref<Overload> o = ref<Overload>(freeOverload);
			_free = o.instances()[0];
		}
		ref<Symbol> assertOverload = root.lookup("assert");
		if (assertOverload.class == Overload) {
			ref<Overload> o = ref<Overload>(assertOverload);
			_assert = o.instances()[0];
		}
		ref<Symbol> memsetOverload = root.lookup("memset");
		if (memsetOverload.class == Overload) {
			ref<Overload> o = ref<Overload>(memsetOverload);
			_memset = o.instances()[0];
		}
		ref<Symbol> memcpyOverload = root.lookup("memcpy");
		if (memsetOverload.class == Overload) {
			ref<Overload> o = ref<Overload>(memcpyOverload);
			_memcpy = o.instances()[0];
		}
		ref<Type> stringType = _arena.builtInType(TypeFamily.STRING);
		for (int i = 0; i < stringType.scope().constructors().length(); i++) {
			ref<Scope> scope = stringType.scope().constructors()[i];
			ref<Function> func = ref<Function>(scope.definition());
			ref<NodeList> args = func.arguments();
			if (args == null ||
				args.next != null)
				continue;
			if (args.node.type.equals(stringType)) {
				_stringCopyConstructor = ref<OverloadInstance>(func.name().symbol());
				break;
			}
		}
		ref<Type> varType = _arena.builtInType(TypeFamily.VAR);
		for (int i = 0; i < varType.scope().constructors().length(); i++) {
			ref<Scope> scope = varType.scope().constructors()[i];
			ref<Function> func = ref<Function>(scope.definition());
			ref<NodeList> args = func.arguments();
			if (args == null ||
				args.next != null)
				continue;
			if (args.node.type.equals(varType)) {
				_varCopyConstructor = ref<OverloadInstance>(func.name().symbol());
				break;
			}
		}
		ref<Type> floatType = _arena.builtInType(TypeFamily.FLOAT_32);
		ref<Symbol> signMask = floatType.scope().lookup("SIGN_MASK");
		if (signMask != null)
			_floatSignMask = signMask;
		ref<Symbol> one = floatType.scope().lookup("ONE");
		if (one != null)
			_floatOne = one;
		ref<Type> doubleType = _arena.builtInType(TypeFamily.FLOAT_64);
		signMask = doubleType.scope().lookup("SIGN_MASK");
		if (signMask != null)
			_doubleSignMask = signMask;
		one = doubleType.scope().lookup("ONE");
		if (one != null)
			_doubleOne = one;
		
		ref<Symbol> assign = stringType.scope().lookup("assign");
		if (assign != null) {
			ref<Overload> o = ref<Overload>(assign);
			if (o.instances().length() == 1) {
				ref<OverloadInstance> oi = o.instances()[0];
				// TODO: Validate that we have the correct symbol;
				_stringAssign = oi;
			}
		}
		ref<Symbol> append = stringType.scope().lookup("append");
		if (append != null) {
			ref<Overload> o = ref<Overload>(append);
			for (int i = 0; i < o.instances().length(); i++) {
				ref<OverloadInstance> oi = o.instances()[i];
				if (oi.parameterCount() != 1)
					continue;
				ref<Scope> s = oi.parameterScope();
				ref<Symbol>[string].iterator iter = s.symbols().begin();
				if (iter.get().type().family() == TypeFamily.STRING) {
					_stringAppendString = oi;
					break;
				}
			}
		}
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

int[Operator] nodeClasses;
nodeClasses.resize(Operator.MAX_OPERATOR);

nodeClasses[Operator.IDENTIFIER] =			NC_SYMBOL;
nodeClasses[Operator.INTEGER] =				NC_CONST;
nodeClasses[Operator.FLOATING_POINT] =		NC_CONST;
nodeClasses[Operator.CHARACTER] =			NC_CONST;
nodeClasses[Operator.ADDRESS] =				NC_CONST;
nodeClasses[Operator.EQUALITY] =			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.NOT_EQUAL] =			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.LESS] =				NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.GREATER] =				NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.LESS_EQUAL] =			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.GREATER_EQUAL] =		NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.LESS_GREATER] =		NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.NOT_LESS] =			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.NOT_GREATER] =			NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.NOT_LESS_EQUAL] =		NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.NOT_GREATER_EQUAL] =	NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
nodeClasses[Operator.NOT_LESS_GREATER] =	NC_NOCSE|NC_CLEAN|NC_BYTE|NC_IMMED;
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

