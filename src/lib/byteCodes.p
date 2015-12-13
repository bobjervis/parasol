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
namespace parasol:byteCodes;

import parasol:file;
import parasol:process;
import parasol:pxi;
import parasol:runtime;
import parasol:compiler.Arena;
import parasol:compiler.Binary;
import parasol:compiler.Block;
import parasol:compiler.Call;
import parasol:compiler.Class;
import parasol:compiler.ClassScope;
import parasol:compiler.ClassType;
import parasol:compiler.CompileContext;
import parasol:compiler.CompileString;
import parasol:compiler.Constant;
import parasol:compiler.EnumInstanceType;
import parasol:compiler.familySize;
import parasol:compiler.FileScanner;
import parasol:compiler.FileStat;
import parasol:compiler.For;
import parasol:compiler.Function;
import parasol:compiler.FunctionType;
import parasol:compiler.GatherCasesClosure;
import parasol:compiler.Identifier;
import parasol:compiler.Location;
import parasol:compiler.MessageId;
import parasol:compiler.Operator;
import parasol:compiler.Overload;
import parasol:compiler.OverloadInstance;
import parasol:compiler.Node;
import parasol:compiler.NodeList;
import parasol:compiler.ParameterScope;
import parasol:compiler.PlainSymbol;
import parasol:compiler.Return;
import parasol:compiler.Scope;
import parasol:compiler.Selection;
import parasol:compiler.StorageClass;
import parasol:compiler.Symbol;
import parasol:compiler.Target;
import parasol:compiler.Ternary;
import parasol:compiler.Test;
import parasol:compiler.Token;
import parasol:compiler.TraverseAction;
import parasol:compiler.Type;
import parasol:compiler.TypedefType;
import parasol:compiler.TypeFamily;
import parasol:compiler.Unary;
import parasol:pxi.Pxi;
import parasol:pxi.Section;
import native:C;

int STACK_SLOT = address.bytes;
int FRAME_SIZE = 3 * address.bytes;

class StackFrame {
	public pointer<byte> fp;
	public pointer<byte> code;
	public int ip;
}

@Header("B_")
enum ByteCodes {
	ILLEGAL,
	INT,
	LONG,
	STRING,
	CALL,
	ICALL,
	VCALL,
	XCALL,
	LDTR,			// Load TypeRef from VTable
	INVOKE,
	CHKSTK,
	SP,
	LOCALS,
	VARG,
	VARG1,
	POP,
	POPN,
	DUP,
	SWAP,
	RET,			// Return no value, fixed argument list
	RET1,			// Return 1-slot value, fixed argument list
	RETN,			// Return an N-byte value, fixed argument list
	STSA,			// store static address
	LDSA,			// load static address
	STSB,			// store static byte
	LDSB,			// load static byte
	STSC,			// store static char
	LDSC,			// load static char
	STSI,			// store static int
	LDSI,			// load static int
	LDSU,			// load static unsigned
	STSO,			// store static object
	STSS,			// store static short
	LDSS,			// load static short
	STAA,			// store auto address
	LDAA,			// load auto address
	STAB,			// store auto byte
	LDAB,			// load auto byte
	LDAC,			// load auto char
	STAI,			// store auto int
	LDAI,			// load auto int
	LDAU,			// load auto int
	LDAO,			// load auto object
	STAO,			// store auto object
	STAS,			// store auto short
	LDAS,			// load auto short
	STAV,			// store auto var
	STVA,			// store varg address
	STVB,			// store varg byte
	STVI,			// store varg int
	STVO,			// store varg object
	STVS,			// store varg short
	STVV,			// store varg var
	LDPA,			// load parameter address
	STPA,			// store parameter address
	LDPB,			// load parameter byte
	STPB,			// store parameter byte
	LDPC,			// load parameter char
	LDPI,			// load parameter int
	LDPL,			// load parameter long
	LDPU,			// load parameter unsigned
	STPI,			// store parameter int
	STPL,			// store parameter long
	LDPO,			// load parameter object
	STPO,			// store parameter object
	STPS,			// store parameter short
	LDPS,			// load parameter short
	LDIA,			// load indirect address
	STIA,			// store indirect address
	POPIA,		// pop into indirect address (pop then store using TOS)
	LDIB,			// load indirect byte
	STIB,			// store indirect byte
	LDIC,			// load indirect char
	STIC,			// store indirect char
	LDII,			// load indirect int
	STII,			// store indirect int
	LDIL,			// load indirect long
	STIL,			// store indirect long
	LDIU,			// load indirect unsigned
	LDIO,			// load indirect object
	STIO,			// store indirect object
	LDIV,			// load indirect var
	STIV,			// store indirect var
	MUL,
	DIV,
	REM,
	ADD,
	SUB,
	LSH,
	RSH,
	URS,
	OR,
	AND,
	XOR,
	NOT,
	NEG,
	BCM,
	MULV,
	DIVV,
	REMV,
	ADDV,
	SUBV,
	LSHV,
	RSHV,
	URSV,
	ORV,
	ANDV,
	XORV,
	EQI,
	NEI,
	GTI,
	GEI,
	LTI,
	LEI,
	GTU,
	GEU,
	LTU,
	LEU,
	EQL,
	NEL,
	GTL,
	GEL,
	LTL,
	LEL,
	GTA,
	GEA,
	LTA,
	LEA,
	EQV,
	NEV,
	GTV,
	GEV,
	LTV,
	LEV,
	LGV,
	NGV,
	NGEV,
	NLV,
	NLEV,
	NLGV,
	CVTBI,		// convert byte . int
	CVTCI,		// convert char . int
	CVTIL,		// convert int . long
	CVTUL,		// convert unsigned . long
	CVTIV,		// convert int . var
	CVTLV,		// convert long . var
	CVTSV,		// convert string . var
	CVTAV,		// convert address . var
	CVTVI,		// convert var . int
	CVTVS,		// convert var . string
	CVTVA,		// convert var . address
	SWITCHI,		// integer switch
	SWITCHE,		// enum switch
	JMP,
	JZ,
	JNZ,
	NEW,			// new N bytes
	DELETE,		// delete p
	THROW,
	ADDR,
	ZERO_A,		// set auto addresses to zero
	ZERO_I,		// set indirect to zero
	AUTO,			// address of auto
	AVARG,		// address of vararg
	PARAMS,		// address of params
	ASTRING,		// address of string
	VALUE,		// address of value
	CHAR_AT,
	CLASSV,		// var.class
	string,
	MAX_BYTECODE
}

public class ByteCodesTarget extends Target {
	private ref<Unit> _unit;
	private ref<Arena> _arena;
	private ref<Code> _staticBlock;
	private int _currentSpDepth;
	private byte[] _byteCodeBuffer;
	private int[] _fixups;
	private int[] _jumpTargets;
	private ref<JumpContext> _jumpContext;
	public int stopAt;
	public Location stopLocation;

	// These are the various methods/functions/objects from the runtime needed for code gen

	private ref<ParameterScope> _stringCopyConstructor;
	private ref<ParameterScope> _stringCompare;
	private ref<ParameterScope> _stringAssign;
	private ref<ParameterScope> _stringAppend;
	
	public ByteCodesTarget(ref<Arena> arena) {
		_arena = arena;
	}
	
	boolean generateCode(ref<FileStat> mainFile, int valueOffset, ref<CompileContext> compileContext) {
		cacheRootCodegenObjects(_arena.root());
		_unit = new Unit(_arena.root(), mainFile.tree().root(), this, valueOffset, compileContext);
		for (int i = 0; i < _arena.scopes().length(); i++)
			_arena.scopes()[i].assignVariableStorage(this, compileContext);
		for (int i = 0; i < _unit.values().length(); i++)
			_unit.values()[i].initializeStorage(this, compileContext);
		if (mainFile.tree().root().countMessages() > 0)
			return false;
		ref<Code> code = _unit.newCode(mainFile.fileScope(), 0);
		clearByteCodeBuffer();
		code.generateFunction(this, compileContext);
		if (!_unit.rootError) {
			if (code.isEmpty())
				mainFile.tree().root().add(MessageId.NO_CODE, compileContext.pool());
			else if (mainFile.tree().root().countMessages() == 0) {
				_staticBlock = code;
				_unit.populateVTables();
				return true;
			}
		}
//		delete _unit;
		_unit = null;
		return false;
	}

	public int, boolean run(string[] args) {
		// Need to create an object table.
		int objectCount = _unit.values().length();
		address[] objects;
		for (int i = 0; i < objectCount; i++)
			objects.append(_unit.values()[i].machineAddress());
		int startingObject = runtime.injectObjects(&objects[0], objectCount);
		pointer<byte>[] runArgs;
		for (int i = 1; i < args.length(); i++)
			runArgs.append(args[i].c_str());
		pointer<byte>[] exceptionInfo;
		exceptionInfo.resize(6);
//		printf("running\n");
		runtime.setTrace(_arena.trace);
//		printf("tracy\n");
		int returnValue = runtime.eval(_staticBlock.index(), &runArgs[0], runArgs.length(), &exceptionInfo[0]);
		runtime.setTrace(false);
//		assert(false);
//		print("here\n");
//		printf("done returnValue = %d\n", returnValue);
		if (returnValue == int.MIN_VALUE) {
			byte[] stackSnapshot;
			
//			printf("exceptionInfo = [ %p, %p, %p, %p, %p, %p ]\n", exceptionInfo[0], exceptionInfo[1], exceptionInfo[2], exceptionInfo[3], exceptionInfo[4], exceptionInfo[5]);
			stackSnapshot.resize(int(exceptionInfo[5] - exceptionInfo[3]));
//			printf("stack snapshot size %d\n", stackSnapshot.length());
			
			runtime.fetchSnapshot(&stackSnapshot[0], stackSnapshot.length());
//			print("Got snapshot\n");
			dumpStack(objects, exceptionInfo, stackSnapshot, startingObject);
			return 1, false;
		} else
			return returnValue, true;
 	}
	
	public void writePxi(ref<Pxi> output) {
		ref<Section> s = new ByteCodeSection(_staticBlock.index(), _unit);
		output.declareSection(s);
	}
	
	public boolean disassemble(ref<Arena> arena) {
		if (_unit != null)
			_unit.print(0);
		else
			printf("No unit to disassemble\n");
		return true;
	}
	
	byte[] byteCodeBuffer() {
		return _byteCodeBuffer;
	}

	public void clearByteCodeBuffer() {
		_byteCodeBuffer.clear();
	}

	public int markByteCodes() {
		return _byteCodeBuffer.length();
	}

	public void resetByteCodeMark(int mark) {
		_byteCodeBuffer.resize(mark);
	}

	public void byteCode(ByteCodes b) {
//		printf("%s\n", byteCodeMap.name[b]);
		_byteCodeBuffer.append(byte(int(b)));
	}
	
	public void byteCode(int x) {
		for (int i = 0; i < int.bytes; i++) {
			_byteCodeBuffer.append(byte(x));
			x >>= 8;
		}
	}	

	public void fixup(int x) {
		_fixups.append(_byteCodeBuffer.length());
		for (int i = 0; i < int.bytes; i++) {
			_byteCodeBuffer.append(byte(x));
			x >>= 8;
		}
	}	

	public ref<Value> buildVtable(ref<Scope> scope, ref<CompileContext> compileContext) {
		ref<ClassScope> classScope = ref<ClassScope>(scope);
		
		if (classScope.vtable == null) {
			ref<TypeRef> tr = _unit.newTypeRef(classScope.classType, classScope);
			classScope.vtable = _unit.newVTable(classScope, tr);
//			ref<VTable>(classScope.vtable).disassemble(0);
			for (int i = 0; i < classScope.methods().length(); i++) {
				ref<OverloadInstance> method = classScope.methods()[i];
				if (!method.deferAnalysis()) {
					ref<Value> v = _unit.getCode(method.parameterScope(), this, compileContext);
					if (v == null) {
						ref<Function> func = ref<Function>(method.parameterScope().definition());
						classScope.classType.definition().add(MessageId.UNRESOLVED_ABSTRACT, compileContext.pool(), func.name().value());
					}
				}
			}
		}
		return ref<Value>(classScope.vtable);
	}
	
	public void assignStorageToObject(ref<Symbol> symbol, ref<Scope> scope, int offset, ref<CompileContext> compileContext) {
		if (symbol.class == PlainSymbol) {
			ref<Type> type = symbol.assignType(compileContext);
			if (type == null)
				return;
			if (!type.requiresAutoStorage())
				return;
			int size;
			int alignment;
			type.assignSize(this, compileContext);
			switch (symbol.storageClass()) {
			case	STATIC:
				if (symbol.value == null) {
					int size = type.size();
					if (size < 0) {
						symbol.add(MessageId.UNFINISHED_ASSIGN_STORAGE, compileContext.pool(), CompileString(string(symbol.storageClass())));
						break;
					}
					symbol.value = _unit.newStaticObject(_unit, symbol, size);
				}
				break;

			case	PARAMETER:
				// Round parameter sizes up to next slot size.
				size = type.stackSize();
				symbol.offset = scope.variableStorage;
				scope.variableStorage += size;
				break;

			case	AUTO:
				// Round auto sizes up to next slot size - do not try to optimize stack frame yet.
				size = type.stackSize();
				scope.variableStorage += size;
				symbol.offset = -(offset + scope.variableStorage);
				break;

			case	TEMPLATE_INSTANCE:
				symbol.offset = 0;
				scope.variableStorage = 0;
				break;

			case	MEMBER:
				// Align member fields, but don't reorder them - do not try to optimize stack frame yet.
				size = type.size();
				alignment = type.alignment();
				if (alignment == -1) {
					symbol.add(MessageId.UNFINISHED_ASSIGN_STORAGE, compileContext.pool(), CompileString(string(scope.storageClass())));
				}
				scope.variableStorage = (scope.variableStorage + alignment - 1) & ~(alignment - 1);
				symbol.offset = scope.variableStorage;
				scope.variableStorage += size;
				break;

			case	ENUMERATION:{
				printf("Saw enumeration\n");
				ref<EnumInstanceType> eit = ref<EnumInstanceType>(type);
				ref<Symbol> typeDefinition = eit.symbol();
				if (typeDefinition.value == null)
					assignStorageToObject(typeDefinition, typeDefinition.enclosing(), 0, compileContext);
				symbol.value = typeDefinition.value;
			}	break;

			default:
				symbol.add(MessageId.UNFINISHED_ASSIGN_STORAGE, compileContext.pool(), CompileString(string(scope.storageClass())));
			}
		}
	}

	public void jumpTarget(int x) {
		_jumpTargets.append(_byteCodeBuffer.length());
		for (int i = 0; i < int.bytes; i++) {
			_byteCodeBuffer.append(byte(x));
			x >>= 8;
		}
	}
	
	public int fixups() {
		return _fixups.length();
	}
	
	public int jumpTargets() {
		return _jumpTargets.length();
	}
	
	public void pushJumpContext(ref<JumpContext> context) {
		_jumpContext = context;
	}
	
	public ref<JumpContext> jumpContext() {
		return _jumpContext;
	}

	public void popJumpContext() {
		_jumpContext = _jumpContext.next();
	}

	public void applyFixups(int startAt, int amount) {
		for (int i = startAt; i < _fixups.length(); i++)
			*ref<int>(&_byteCodeBuffer[_fixups[i]]) += amount;
		_fixups.resize(startAt);
	}

	public void applyJumpTargets(int startAt, ref<Code> code) {
		for (int i = startAt; i < _jumpTargets.length(); i++) {
			int label = *ref<int>(&_byteCodeBuffer[_jumpTargets[i]]);
			*ref<int>(&_byteCodeBuffer[_jumpTargets[i]]) = code.labels()[label - 1];
		}
		_jumpTargets.resize(startAt);
	}
	
	public void pushSp(int amount) {
		_currentSpDepth -= amount;
	}

	public void popSp(int amount) {
		_currentSpDepth += amount;
	}
	
	public int currentSpDepth() {
		return _currentSpDepth;
	}

	public void print() {
		if (_unit != null)
			_unit.unitScope().definition().print(0);
		else
			printf("No unit defined\n");
	}

	private void cacheRootCodegenObjects(ref<Scope> root) {
		ref<Type> stringType = _arena.builtInType(TypeFamily.STRING);
		ref<Symbol> sym = _arena.stringType();
		if (sym != null && sym.class == PlainSymbol) {
			ref<PlainSymbol> stringDef = ref<PlainSymbol> (sym);
			if (stringDef.initializer().op() == Operator.CLASS) {
				ref<Class> stringClass = ref<Class> (stringDef.initializer());
				for (int i = 0; i < stringType.scope().constructors().length(); i++) {
					ref<ParameterScope> scope = stringType.scope().constructors()[i];
					ref<Function> func = ref<Function>(scope.definition());
					ref<NodeList> args = func.arguments();
					if (args == null ||
						args.next != null)
						continue;
					if (args.node.type.equals(stringType)) {
						_stringCopyConstructor = scope;
						break;
					}
				}
			}
		}
		ref<Symbol> compare = stringType.scope().lookup("compare");
		if (compare != null) {
			ref<Overload> o = ref<Overload>(compare);
			if (o.instances().length() == 1) {
				ref<OverloadInstance> oi = o.instances()[0];
				// TODO: Validate that we have the correct symbol;
				_stringCompare = oi.parameterScope();
			}
		}
		ref<Symbol> assign = stringType.scope().lookup("assign");
		if (assign != null) {
			ref<Overload> o = ref<Overload>(assign);
			if (o.instances().length() == 1) {
				ref<OverloadInstance> oi = o.instances()[0];
				// TODO: Validate that we have the correct symbol;
				_stringAssign = oi.parameterScope();
			}
		}
		ref<Symbol> append = stringType.scope().lookup("append");
		if (append != null) {
			ref<Overload> o = ref<Overload>(append);
			for (int i = 0; i < o.instances().length(); i++) {
				ref<OverloadInstance> oi = o.instances()[i];
				if (oi.parameterCount() != 1)
					continue;
				ref<ParameterScope> s = oi.parameterScope();
				ref<Symbol>[string].iterator iter = s.symbols().begin();
				if (iter.get().type().family() == TypeFamily.STRING) {
					_stringAppend = s;
					break;
				}
			}
		}
	}

	ref<ParameterScope> stringCopyConstructor() {
		return _stringCopyConstructor;
	}

	ref<ParameterScope> stringCompare() {
		return _stringCompare;
	}

	ref<ParameterScope> stringAssign() {
		return _stringAssign;
	}

	ref<ParameterScope> stringAppend() {
		return _stringAppend;
	}

	void dumpStack(address[] objects, pointer<byte>[] exceptionInfo, byte[] stackSnapshot, int startingObject) {
//		printf("dumpStack\n");
		CompileContext context(_arena, _arena.global());
		
		ref<Code> code = ref<Code>(getValue(objects, exceptionInfo[0]));
		if (code != null) {
			string s = collectIp(objects, exceptionInfo[0], int(exceptionInfo[1]), &context);
			printf(" -> %s\n", s);
		}
		pointer<byte> lowestSp = exceptionInfo[3];
		pointer<byte> stackData = &stackSnapshot[0];
		for (ref<StackFrame> frame = ref<StackFrame>(stackData + (exceptionInfo[2] - lowestSp)); frame.ip > 0; frame = ref<StackFrame>(stackData + (frame.fp - lowestSp))) {
			string text = collectIp(objects, frame.code, frame.ip, &context);
			printf("    %s\n", text);
		}
	}

	string collectIp(address[] objects, pointer<byte> byteCodes, int ip, ref<CompileContext> compileContext) {
		ref<Code> code = ref<Code>(getValue(objects, byteCodes));
		if (code == null) {
			string s;

			s.printf("invalid address %p:%d", byteCodes, ip);
			return s;
		}

		code.regenerateFunction(this, ip, compileContext);
		ref<FileStat> failingFile = code.file();
		int lineNumber = -1;
		if (failingFile != null) {
			FileScanner scanner(failingFile);
			if (scanner.opened()) {
				// build the line number table.
				while (scanner.next() != Token.END_OF_STREAM)
					;
				lineNumber = scanner.lineNumber(stopLocation);
			} else
				printf("Could not open scanner for line numbers of %s\n", failingFile.filename());
			if (!stopLocation.isInFile())
				return failingFile.filename();
			else if (lineNumber >= 0) {
				string s;

				s.printf("%s %d %s", failingFile.filename(), lineNumber + 1, code.label());
				return s;
			} else {
				string s;
				s.printf("%s [byte %d] %s", failingFile.filename(), stopLocation.offset, code.label());
				return s;
			}
		} else
			return code.label();
	}

	ref<Value> getValue(address[] objects, address addr) {
		for (int i = 0; i < objects.length(); i++)
			if (objects[i] == addr)
				return _unit.values()[i];
		return null;
	}

	public ref<Arena> arena() {
		return _arena;
	}
	
	public ref<Unit> unit() {
		return _unit;
	}

	class JumpContext {
		private int[] _caseLabels;
		private int _nextCase;
		private ref<JumpContext> _next;
		private ref<Node> _controller;
		private int _breakLabel;
		private int _continueLabel;

		public JumpContext(ref<Node> controller, int breakLabel, int continueLabel, ref<ref<Node>[]> nodes, ref<Code> code, ref<JumpContext> next) {
			_next = next;
			_controller = controller;
			_breakLabel = breakLabel;
			_continueLabel = continueLabel;
			if (nodes != null) {
				for (int i = 0; i < nodes.length(); i++) {
					_caseLabels.append(code.createLabel());
					_nextCase++;
				}
			}
		}

		public ref<JumpContext> next() { 
			return _next; 
		}

		public int breakLabel() {
			return _breakLabel; 
		}

		public int continueLabel() {
			if (_controller.op() == Operator.SWITCH)
				return _next.continueLabel();
			else
				return _continueLabel;
		}

		public int defaultLabel() {
			int defaultLabel = _continueLabel;
			_continueLabel = -1;
			return defaultLabel;
		}

		public ref<JumpContext> enclosingSwitch() {
			if (_controller.op() == Operator.SWITCH)
				return this;
			else if (_next != null)
				return _next.enclosingSwitch();
			else
				return null;
		}

		public int nextCaseLabel() {
			--_nextCase;
			return _caseLabels[_nextCase];
		}

		int[] caseLabels() { 
			return _caseLabels; 
		}
	}
}

class Unit {
	private ref<Scope> _unitScope;
	private ref<Value>[] _values;
	private int _valueOffset;
	public boolean rootError;
	public int maxTypeOrdinal;
	
	public Unit(ref<Scope> enclosing, ref<Block> unit, ref<ByteCodesTarget> target, int valueOffset, ref<CompileContext> compileContext) {
		_unitScope = new Scope(enclosing, unit, compileContext.blockStorageClass(), unit.className());
		_valueOffset = valueOffset;
		maxTypeOrdinal = 1;
		for (int i = 0;; i++) {
			pointer<byte> name = runtime.builtInFunctionName(i);
			if (name == null)
				break;
			// Not a 'root' built-in
			if (runtime.builtInFunctionDomain(i) != null)
				continue;
			ref<Symbol> sym = target.arena().root().lookup(name);
			if (sym == null || sym.class != Overload)
				unit.add(MessageId.UNDEFINED_BUILT_IN, compileContext.pool(), CompileString(name));
			else {
				ref<Overload> o = ref<Overload>(sym);
				ref<Value> v = createBuiltIn(i);
				ref<ParameterScope> f = ref<ParameterScope>(o.instances()[0].type().scope());
				o.instances()[0].value = v;
				f.value = v;
			}
		}
		rootError = false;
	}

	public void populateVTables() {
		for (int i = 0; i < _values.length(); i++) {
			ref<Value> v = _values[i];
			if (v.class == VTable) {
				ref<VTable> vt = ref<VTable>(v);
				vt.populateTable();
			}
		}
	}

	public ref<Code> newCode(ref<Scope> scope, int autoSize) {
		ref<Code> code = new Code(this, scope, autoSize);
		defineValue(code);
		return code;
	}

	public ref<String> newString(CompileString value) {
		assert(value.data != null);
//		printf("value=%p, %d\n", value.data, value.length);
		string s(value.data, value.length);
		string output;
		boolean result;
		(output, result) = s.unescapeC();
		if (!result)
			return null;
		ref<String> str = new String(output);
		defineValue(str);
		return str;
	}

	public ref<TypeRef> newTypeRef(ref<Type> addr, ref<Scope> enclosing) {
		ref<TypeRef> tr = new TypeRef(addr, this);
		if (enclosing != null)
			defineValue(tr);
		return tr;
	}

	public ref<VTable> newVTable(ref<ClassScope> classScope, ref<TypeRef> typeRef) {
		ref<VTable> v = new VTable(classScope, typeRef);
		defineValue(v);
		return v;
	}

	public ref<Value> getCode(ref<ParameterScope> functionScope, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		ref<Function> func = ref<Function>(functionScope.definition());
		if (functionScope.value == null) {
			if (func.functionCategory() == Function.Category.ABSTRACT) {
				if (functionScope.enclosing().storageClass() == StorageClass.STATIC) {
					ref<Value> v = BuiltInFunction.create(func, target);
					if (v != null)
						functionScope.value = v;
					else
						func.add(MessageId.UNDEFINED_BUILT_IN, compileContext.pool(), func.name().value());
				}
			} else {
				ref<Code> code = newCode(functionScope, functionScope.autoStorage(target, 0, compileContext));
				functionScope.value = code;
				code.generateFunction(target, compileContext);
			}
			if (func.name() != null)
				func.name().symbol().value = functionScope.value;
		}
		return ref<Value>(functionScope.value);
	}

	public ref<StaticObject> newStaticObject(ref<Unit> owner, ref<Symbol> symbol, int size) {
		ref<StaticObject> v = new StaticObject(owner, symbol, size);
		defineValue(v);
		return v;
	}

	public ref<BuiltInFunction> createBuiltIn(int index) {
		if (unsigned(index) > 50)
			assert(false);
		ref<BuiltInFunction> v = new BuiltInFunction(index,
												 runtime.builtInFunctionAddress(index), 
												 runtime.builtInFunctionArguments(index),
												 runtime.builtInFunctionReturns(index));
		defineValue(v);
		return v;
	}

	void defineValue(ref<Value> value) {
//		printf("[%d]\n", _values.length());
		value._index = _values.length() + _valueOffset;
		_values.append(value);
	}

	public void print(int indent) {
		indentBy(indent);
		printf("Unit %p\n", this);
		for (int i = 0; i < _values.length(); i++) {
			indentBy(indent);
			_values[i].print();
			printf("\n");
			_values[i].disassemble(indent);
		}
	}

	public int valueOffset() {
		return _valueOffset;
	}
	
	public ref<Value>[] values() {
		return _values;
	}

	public ref<Scope> unitScope() {
		return _unitScope;
	}
/*
	ref<Node> namespaceNode() { return _namespaceNode; }


private:
	ref<Node> _namespaceNode;
	*/
}

class BuiltInFunction extends Value {
	private int _builtInIndex;
	private address _function;
	private int _args;
	private int _returns;

	BuiltInFunction(int index, address func, int args, int returns) {
		_builtInIndex = index;
		_function = func;
		_args = args;
		_returns = returns;
	}

	public static ref<BuiltInFunction> create(ref<Function> func, ref<ByteCodesTarget> target) {
		for (int i = 0;; i++) {
			pointer<byte> name = runtime.builtInFunctionName(i);
			if (name == null)
				break;
			if (runtime.builtInFunctionDomain(i) == null)
				continue;
			if (func.name().value().equals(name))
				return target.unit().createBuiltIn(i);
		}
		return null;
	}

	public void print() {
		super.print();
		printf(" %p '%s'", _function, runtime.builtInFunctionName(_builtInIndex));
	}

	public int builtInIndex() {
		return _builtInIndex;
	}
}

class Code extends Value {
	private int _length;
	private ref<Unit> _owner;
	private ref<Scope> _scope;
	private pointer<byte> _byteCodes;
	private int _autoSize;
	private int _stackDepth;
	private int[] _labels;
	
	Code(ref<Unit> owner, ref<Scope> scope, int autoSize) {
		_owner = owner;
		_scope = scope;
		_autoSize = autoSize;
	}

	public void generateFunction(ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		int spDepth = target.currentSpDepth();
		target.popSp(-target.currentSpDepth());
		target.stopAt = int.MAX_VALUE;
		int fixupsAtStart = target.fixups();
		int jumpsAtStart = target.jumpTargets();
		int mark = generateFunctionCore(target, compileContext);
		target.applyFixups(fixupsAtStart, _autoSize);
		for (int i = 0; i < _labels.length(); i++)
			_labels[i] -= mark;
		target.applyJumpTargets(jumpsAtStart, this);
		_byteCodes = pointer<byte>(allocz(_length));
		C.memcpy(_byteCodes, &target.byteCodeBuffer()[mark], _length);
		target.resetByteCodeMark(mark);
		target.popSp(-target.currentSpDepth());
		target.popSp(spDepth);
		alignStackFrame(address.bytes);
	}

	public void regenerateFunction(ref<ByteCodesTarget> target, int stopAt, ref<CompileContext> compileContext) {
		target.stopAt = stopAt;
		int autoSize = _autoSize;
		int fixupsAtStart = target.fixups();
		int jumpsAtStart = target.jumpTargets();
		int mark = generateFunctionCore(target, compileContext);
		target.applyFixups(fixupsAtStart, 0);
		target.applyJumpTargets(jumpsAtStart, this);
		target.resetByteCodeMark(mark);
		_autoSize = autoSize;
	}

	private int generateFunctionCore(ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		int mark = target.markByteCodes();
		target.stopLocation = Location.OUT_OF_FILE;
		ref<Block> tree;
		target.byteCode(ByteCodes.LOCALS);
		target.fixup(0);
		if (_scope.definition().op() == Operator.FUNCTION) {
			ref<Function> func = ref<Function>(_scope.definition());
			tree = func.body;
			if (tree == null) {
				target.unfinished(func, "no function body", compileContext);
				_length = 0;
				return mark;
			} else if (tree.type != null) {
				if (func.functionCategory() == Function.Category.CONSTRUCTOR) {
					if (_scope.enclosing().hasVtable(compileContext)) {
						if (_scope.enclosing().variableStorage > address.bytes) {
							pushThis(target);
							pushInteger(address.bytes, target);
							target.byteCode(ByteCodes.ADD);
							target.popSp(address.bytes);
							target.byteCode(ByteCodes.ZERO_I);
							target.byteCode(_scope.enclosing().variableStorage - int(address.bytes));
							target.popSp(address.bytes);
						}
					} else {
						pushThis(target);
						target.byteCode(ByteCodes.ZERO_I);
						target.byteCode(_scope.enclosing().variableStorage);
						target.popSp(address.bytes);
					}
				}
				generate(tree, target, compileContext);
			} else
				target.unfinished(tree, "no tree type", compileContext);
		} else {
			target.arena().clearStaticInitializers();
			// Now we have to generate the various static blocks for included units.
			while (target.arena().collectStaticInitializers(target))
				;
			if (target.arena().verbose)
				printf("Static initializers (%d):\n", target.staticBlocks().length());
			for (int i = 0; i < target.staticBlocks().length(); i++) {
				ref<FileStat> file = target.staticBlocks()[i];
				if (target.arena().verbose)
					printf("   %s\n", file.filename());
				generate(file.tree().root(), target, compileContext);
			}
			tree = ref<Block>(_scope.definition());
			//generate(tree, target);
			ref<Symbol> main = _scope.lookup("main");
			if (main != null &&
				main.class == Overload) {
				ref<Overload> m = ref<Overload>(main);
				// Confirm that it has 'function int(string[])' type
				// generate call to main
				target.byteCode(ByteCodes.LDPO);
				target.byteCode(0);
				target.byteCode((int)(address.bytes + 2 * int.bytes));
				target.byteCode(ByteCodes.CALL);
				ref<OverloadInstance> instance = m.instances()[0];
				
				ref<Value> value = target.unit().getCode(instance.parameterScope(), target, compileContext);
				target.byteCode(value.index());
				// return value is in TOS
			} else
				pushInteger(0, target);
		}
		if (tree.fallsThrough() == Test.PASS_TEST) {
			if (!generateReturn(target, compileContext))
				target.unfinished(tree, "generateReturn failed - default end-of-function", compileContext);
		}
		// If this is a piece of the runtime root scope, then
		// we have a root compile error and should flag it later.
		if (!_owner.unitScope().encloses(_scope)) {
			if (tree.countMessages() > 0)
				_owner.rootError = true;
		}

		_length = target.markByteCodes() - mark;
		return mark;
	}

/*
	void addMainCall(ref<Symbol> main, ref<CompileContext> target);
*/
	public void print() {
		super.print();
		if (_scope != null) {
			string label = _scope.label();
			printf(" scope %p auto %d %s", _scope, _autoSize, label);
		}
	}

	public void disassemble(int indent) {
		int i = 0; 
		while (i < _length)
			i = disassembleAt(i, indent);
	}

	public address machineAddress() {
		return _byteCodes;
	}
	
	public int length() {
		return _length;
	}
	
	int disassembleAt(int offset, int indent) {
		int x, y;
		printf("%*d:\t%s", indent + 4, offset, byteCodeMap.name[ByteCodes(_byteCodes[offset])]);
		switch (ByteCodes(_byteCodes[offset])) {
		case	NEW:
		case	INT:
		case	RET:
		case	RET1:
		case	VARG:
		case	VARG1:
		case	CHKSTK:
		case	LDIO:
		case	STIO:
		case	POPN:
		case	INVOKE:
		case	ZERO_I:
		case	LOCALS:
			printf("\t%d", *ref<int>(&_byteCodes[offset + 1]));
			offset += 4;
			break;

		case	LONG:
			printf("\t%d", *ref<long>(&_byteCodes[offset + 1]));
			offset += 8;
			break;

		case	RETN:
			x = *ref<int>(&_byteCodes[offset + 1]);
			offset += 4;
			printf("\t%d, %d", x, *ref<int>(&_byteCodes[offset + 1]));
			offset += 4;
			break;

		case	LDAA:
		case	STAA:
		case	LDAB:
		case	STAB:
		case	LDAC:
		case	LDAS:
		case	STAS:
		case	STAV:
		case	LDAI:
		case	LDAU:
		case	STAI:
		case	AUTO:
			printf("\t[fp%+d]", *ref<int>(&_byteCodes[offset + 1]));
			offset += 4;
			break;

		case	STVA:
		case	STVB:
		case	STVS:
		case	STVI:
		case	STVV:
		case	AVARG:
			printf("\t[fp%+d]", -*ref<int>(&_byteCodes[offset + 1]));
			offset += 4;
			break;
			
		case	ZERO_A:
		case	STAO:
		case	LDAO:
			printf("\t[fp%+d],%d", *ref<int>(&_byteCodes[offset + 1]),
				*ref<int>(&_byteCodes[offset + 5]));
			offset += 8;
			break;

		case	STVO:
			printf("\t[fp%+d],%d", -*ref<int>(&_byteCodes[offset + 1]),
				*ref<int>(&_byteCodes[offset + 5]));
			offset += 8;
			break;

		case	LDPA:
		case	STPA:
		case	LDPC:
		case	LDPS:
		case	STPS:
		case	LDPB:
		case	STPB:
		case	LDPI:
		case	LDPL:
		case	LDPU:
		case	STPI:
		case	STPL:
		case	PARAMS:
			printf("\t[param+%d]", *ref<int>(&_byteCodes[offset + 1]));
			offset += 4;
			break;

		case	LDPO:
		case	STPO:
			printf("\t[param+%d],%d", *ref<int>(&_byteCodes[offset + 1]),
				*ref<int>(&_byteCodes[offset + 5]));
			offset += 8;
			break;

		case	SWITCHI:
			x = *ref<int>(&_byteCodes[offset + 1]);
			printf("\t%d cases, default ", x);
			offset += 4;
			y = *ref<int>(&_byteCodes[offset + 1]);
			printf("%d:", y);
			offset += 4;
			for (int j = 0; j < x; j++) {
				int value = *ref<int>(&_byteCodes[offset + 1]);
				offset += 4;
				int label = *ref<int>(&_byteCodes[offset + 1]);
				offset += 4;
				printf("\n%*s%08x . %d", indent + 6, " ", value, label);
			}
			break;

		case	SWITCHE:
			x = *ref<int>(&_byteCodes[offset + 1]);
			printf("\t%d cases, default ", x);
			offset += 4;
			y = *ref<int>(&_byteCodes[offset + 1]);
			printf("%d:", y);
			offset += 4;
			for (int j = 0; j < x; j++) {
				int value = *ref<int>(&_byteCodes[offset + 1]);
				offset += 4;
				int xoffset = *ref<int>(&_byteCodes[offset + 1]);
				offset += 4;
				int label = *ref<int>(&_byteCodes[offset + 1]);
				offset += 4;
				printf("\n%*s[%d]:%d . %d", indent + 6, " ", value, xoffset, label);
			}
			break;

		case	JMP:
		case	JZ:
		case	JNZ:
			x = *ref<int>(&_byteCodes[offset + 1]);
			printf("\t%d", x);
			offset += 4;
			break;

		case	SP:
			printf("\t%d,sp", *ref<int>(&_byteCodes[offset + 1]));
			offset += 4;
			break;

		case	STSA:
		case	STSB:
		case	STSC:
		case	STSI:
		case	STSS:
		case	LDSA:
		case	LDSB:
		case	LDSC:
		case	LDSI:
		case	LDSU:
		case	LDSS:
		case	VALUE:
		case	CALL:
		case	STRING:
		case	ASTRING:
		case	ADDR:
			x = *ref<int>(&_byteCodes[offset + 1]);
			if (x == -1)
				printf("\t<invalid>");
			else {
				printf("\t");
				int vo = _owner.valueOffset();
				if (x >= vo && x < vo + _owner.values().length())
					_owner.values()[x - vo].print();
				else
					printf("<invalid:%d>", x);
			}
			offset += 4;
			break;

		case	XCALL:
			x = *ref<int>(&_byteCodes[offset + 1]);
			if (x == -1)
				printf("\t<invalid>");
			else
				printf("\t%s (%d)", runtime.builtInFunctionName(x), x);
			offset += 4;
			break;

		case	VCALL:
			x = *ref<int>(&_byteCodes[offset + 1]);
			offset += 4;
			printf("\t@%d,", x);
			y = *ref<int>(&_byteCodes[offset + 1]);
			offset += 4;
			int vo = _owner.valueOffset();
			if (y >= vo && y < vo + _owner.values().length())
				_owner.values()[y - vo].print();
			else
				printf("<invalid:%d>", y);
			break;

		case	STSO:
			x = *ref<int>(&_byteCodes[offset + 1]);
			if (x == -1)
				printf("\t<invalid>");
			else {
				printf("\t");
				if (x >= 0 && x < _owner.values().length())
					_owner.values()[x].print();
				else
					printf("<invalid:%d>", x);
			}
			printf(",%d", *ref<int>(&_byteCodes[offset + 5]));
			offset += 8;
			break;
		}
		printf("\n");
		return offset + 1;
	}

	public boolean isEmpty() {
		return _length == 0;
	}

	int allocateTemp(ref<Type> t) {
		// Align the auto size for the new object;
		alignStackFrame(t.alignment());
		_autoSize += t.stackSize();
		return -_autoSize;
	}

	void alignStackFrame(int alignment) {
		_autoSize = (_autoSize + alignment - 1) & ~(alignment - 1);
	}

	int createLabel() {
		_labels.append(-1);
		return _labels.length();
	}

	void locateLabel(int label, ref<ByteCodesTarget> target) {
		_labels[label - 1] = target.markByteCodes();
		target.popSp(-target.currentSpDepth());
	}

	string label() {
		if (_scope != null)
			return _scope.label();
		else
			return "<no scope>";
	}

	ref<FileStat> file() {
		if (_scope != null)
			return _scope.file();
		else
			return null;
	}

	int[] labels() { 
		return _labels;
	}

	private void generate(ref<Node> tree, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		if (target.stopAt < target.markByteCodes())
			return;
		target.stopLocation = tree.location();
		if (tree.deferAnalysis()) {
			// push the correct kind of exception
			target.byteCode(ByteCodes.THROW);
			return;
		}
		checkStack(target);
		switch (tree.op()) {
		case	ANNOTATED: {
			ref<Binary> annotated = ref<Binary>(tree);
			generate(annotated.right(), target, compileContext);
			break;
		}
		case	ADDRESS:{
			ref<Unary> u = ref<Unary>(tree);
			pushAddress(u.operand(), target, compileContext);
		}break;

		case	BLOCK:
		case	UNIT: {
			ref<Block> block = ref<Block>(tree);
			boolean staticCode = false;
			for (ref<NodeList> nl = block.statements(); nl != null; nl = nl.next)
				generate(nl.node, target, compileContext);
		}break;
		
		case	DECLARATION: {
			ref<Binary> declaration = ref<Binary>(tree);
			generateInitializers(declaration.right(), target, compileContext);
			break;
		}
		case	STATIC:
		case	ABSTRACT:
		case	PRIVATE:
		case	PUBLIC: {
			ref<Unary> u = ref<Unary>(tree);
			generate(u.operand(), target, compileContext);
			break;
		}
		case	ENUM_DECLARATION:
		case	CLASS_DECLARATION:
		case	DECLARE_NAMESPACE:
		case	IMPORT:
			break;

		case	FUNCTION: {
			ref<Function> func = ref<Function>(tree);
			if (func.body != null) {
				if (func.name() == null) {
					ref<ParameterScope> functionScope = target.arena().createParameterScope(compileContext.current(), func, ParameterScope.Kind.FUNCTION);
					_owner.getCode(functionScope, target, compileContext);
					pushAddress(ref<Value>(functionScope.value), target);
				}
			}
			break;
		}
		case	RETURN: {
			ref<Return> expression = ref<Return>(tree);
			for (ref<NodeList> nl = expression.arguments(); nl != null; nl = nl.next)
				generate(nl.node, target, compileContext);
			if (!generateReturn(target, compileContext))
				target.unfinished(tree, "generateReturn failed - RETURN node", compileContext);
			break;
		}
		case	CONDITIONAL:
		case	IF: {
			int falseDepth = target.currentSpDepth();
			ref<Ternary> stmt = ref<Ternary>(tree);
			generate(stmt.left(), target, compileContext);
			int falseLabel = createLabel();
			int joinLabel = createLabel();
			target.byteCode(ByteCodes.JZ);
			target.popSp(address.bytes);
			target.jumpTarget(falseLabel);
			generate(stmt.middle(), target, compileContext);
			target.byteCode(ByteCodes.JMP);
			target.jumpTarget(joinLabel);
			locateLabel(falseLabel, target);
			target.pushSp(-falseDepth);
			generate(stmt.right(), target, compileContext);
			int joinDepth = target.currentSpDepth();
			locateLabel(joinLabel, target);
			target.pushSp(-joinDepth);
			break;
		}
		case	FOR:
		case	SCOPED_FOR: {
			ref<For> stmt = ref<For>(tree);

			if (stmt.op() == Operator.SCOPED_FOR)
				generate(stmt.initializer(), target, compileContext);
			else
				generateExpressionStatement(stmt.initializer(), target, compileContext);
			int continueLabel = createLabel();
			int breakLabel = createLabel();
			int joinLabel = createLabel();
			target.byteCode(ByteCodes.JMP);
			target.jumpTarget(joinLabel);
			locateLabel(continueLabel, target);
			generateExpressionStatement(stmt.increment(), target, compileContext);
			locateLabel(joinLabel, target);
			if (stmt.test().op() != Operator.EMPTY) {
				generate(stmt.test(), target, compileContext);
				target.byteCode(ByteCodes.JZ);
				target.popSp(address.bytes);
				target.jumpTarget(breakLabel);
			}
			ByteCodesTarget.JumpContext jumpContext(stmt, breakLabel, continueLabel, null, this, target.jumpContext());
			target.pushJumpContext(&jumpContext);
			generate(stmt.body(), target, compileContext);
			target.popJumpContext();
			target.byteCode(ByteCodes.JMP);
			target.jumpTarget(continueLabel);
			locateLabel(breakLabel, target);
			break;
		}

		case	DO_WHILE: {
			ref<Binary> stmt = ref<Binary>(tree);
			int continueLabel = createLabel();
			int breakLabel = createLabel();
			int topLabel = createLabel();
			locateLabel(topLabel, target);
			ByteCodesTarget.JumpContext jumpContext(stmt, breakLabel, continueLabel, null, this, target.jumpContext());
			target.pushJumpContext(&jumpContext);
			generate(stmt.left(), target, compileContext);
			locateLabel(continueLabel, target);
			generate(stmt.right(), target, compileContext);
			target.popJumpContext();
			target.byteCode(ByteCodes.JNZ);
			target.popSp(address.bytes);
			target.jumpTarget(topLabel);
			locateLabel(breakLabel, target);
			break;
		}
		case	WHILE: {
			ref<Binary> stmt = ref<Binary>(tree);
			int continueLabel = createLabel();
			int breakLabel = createLabel();
			locateLabel(continueLabel, target);
			generate(stmt.left(), target, compileContext);
			target.byteCode(ByteCodes.JZ);
			target.popSp(address.bytes);
			target.jumpTarget(breakLabel);
			ByteCodesTarget.JumpContext jumpContext(stmt, breakLabel, continueLabel, null, this, target.jumpContext());
			target.pushJumpContext(&jumpContext);
			generate(stmt.right(), target, compileContext);
			target.popJumpContext();
			target.byteCode(ByteCodes.JMP);
			target.jumpTarget(continueLabel);
			locateLabel(breakLabel, target);
			break;
		}
		case	BREAK:
			target.byteCode(ByteCodes.JMP);
			target.jumpTarget(target.jumpContext().breakLabel());
			break;

		case	CONTINUE:
			target.byteCode(ByteCodes.JMP);
			target.jumpTarget(target.jumpContext().continueLabel());
			break;

		case	SWITCH:
			generateSwitch(tree, target, compileContext);
			break;

		case	CASE: {
			ref<Binary> stmt = ref<Binary>(tree);
			ref<ByteCodesTarget.JumpContext> context = target.jumpContext().enclosingSwitch();
			locateLabel(context.nextCaseLabel(), target);
			generate(stmt.right(), target, compileContext);
			break;
		}
		case	DEFAULT: {
			ref<Unary> stmt = ref<Unary>(tree);
			ref<ByteCodesTarget.JumpContext> context = target.jumpContext().enclosingSwitch();
			locateLabel(context.defaultLabel(), target);
			generate(stmt.operand(), target, compileContext);
			break;
		}
		case	EMPTY:
			break;

		case	EXPRESSION: {
			ref<Unary> expression = ref<Unary>(tree);
			generateExpressionStatement(expression.operand(), target, compileContext);
			break;
		}

		case	SEQUENCE: {
			ref<Binary> stmt = ref<Binary>(tree);
			generateExpressionStatement(stmt.left(), target, compileContext);
			generate(stmt.right(), target, compileContext);
			break;
		}
		case	STRING: {
			ref<Constant> str = ref<Constant>(tree);
			target.byteCode(ByteCodes.STRING);
			ref<String> s = _owner.newString(str.value());
			if (s == null) {
				tree.add(MessageId.BAD_STRING, compileContext.pool(), str.value());
				target.byteCode(-1);
			} else
				target.byteCode(s.index());
			target.pushSp(address.bytes);
			break;
		}

		case	CHARACTER: {
			ref<Constant> integer = ref<Constant>(tree);
			target.byteCode(ByteCodes.INT);
			int charVal;
			boolean result;
			(charVal, result) = integer.charValue();
			if (result)
				target.byteCode(charVal);
			else {
				tree.add(MessageId.BAD_CHAR, compileContext.pool(), integer.value());
				target.byteCode(-1);
			}
			target.pushSp(address.bytes);
			break;
		}
		case	INTEGER: {
			ref<Constant> integer = ref<Constant>(tree);
			long val = integer.intValue();
			if (val > int.MAX_VALUE || val < int.MIN_VALUE)
				pushLong(val, target);
			else {
				target.byteCode(ByteCodes.INT);
				target.byteCode(int(val));
				target.pushSp(address.bytes);
			}
			break;
		}
		case	NULL:
		case	TRUE:
		case	FALSE: {
			target.byteCode(ByteCodes.INT);
			target.byteCode(tree.op() == Operator.TRUE ? 1 : 0);
			target.pushSp(address.bytes);
			break;
		}
		case	IDENTIFIER: {
			ref<Identifier> id = ref<Identifier>(tree);
			ref<Symbol> symbol = id.symbol();
			if (symbol == null) {
				target.unfinished(tree, "no symbol for IDENTIFIER", compileContext);
				break;
			}
			switch (symbol.storageClass()) {
			case	AUTO:
				switch (id.type.family()) {
				case	UNSIGNED_8:
				case	BOOLEAN:
					target.byteCode(ByteCodes.LDAB);
					target.byteCode(symbol.offset);
					break;

				case	UNSIGNED_16:
					target.byteCode(ByteCodes.LDAC);
					target.byteCode(symbol.offset);
					break;

				case	SIGNED_32:
					target.byteCode(ByteCodes.LDAI);
					target.byteCode(symbol.offset);
					break;

				case	UNSIGNED_32:
					target.byteCode(ByteCodes.LDAU);
					target.byteCode(symbol.offset);
					break;

				case	SIGNED_64:
				case	ENUM:
				case	ADDRESS:
				case	FUNCTION:
				case	STRING:
					target.byteCode(ByteCodes.LDAA);
					target.byteCode(symbol.offset);
					break;

				case	CLASS:
					if (id.type.indirectType(compileContext) != null) {
						target.byteCode(ByteCodes.LDAA);
						target.byteCode(symbol.offset);
					} else {
						target.byteCode(ByteCodes.LDAO);
						target.byteCode(symbol.offset);
						target.byteCode(id.type.size());
					}
					break;

				case	VAR:
					target.byteCode(ByteCodes.LDAO);
					target.byteCode(symbol.offset);
					target.byteCode(var.bytes);
					break;

				default:
					target.unfinished(tree, "auto identifier", compileContext);
				}
				target.pushSp(id.type.stackSize());
				break;

			case	PARAMETER:
				switch (id.type.family()) {
				case	UNSIGNED_8:
				case	BOOLEAN:
					target.byteCode(ByteCodes.LDPB);
					target.byteCode(symbol.offset);
					break;

				case	UNSIGNED_16:
					target.byteCode(ByteCodes.LDPC);
					target.byteCode(symbol.offset);
					break;

				case	ENUM:
				case	STRING:
				case	FUNCTION:
				case	ADDRESS:
					target.byteCode(ByteCodes.LDPA);
					target.byteCode(symbol.offset);
					break;

				case	UNSIGNED_32:
					target.byteCode(ByteCodes.LDPU);
					target.byteCode(symbol.offset);
					break;

				case	SIGNED_32:
					target.byteCode(ByteCodes.LDPI);
					target.byteCode(symbol.offset);
					break;

				case	SIGNED_64:
					target.byteCode(ByteCodes.LDPL);
					target.byteCode(symbol.offset);
					break;

				case	CLASS:
					if (id.type.indirectType(compileContext) != null) {
						target.byteCode(ByteCodes.LDPA);
						target.byteCode(symbol.offset);
					} else {
						target.byteCode(ByteCodes.LDPO);
						target.byteCode(symbol.offset);
						target.byteCode(id.type.stackSize());
					}
					break;

				case	VAR:
					target.byteCode(ByteCodes.LDPO);
					target.byteCode(symbol.offset);
					target.byteCode(var.bytes);
					break;

				default:
					target.unfinished(tree, "param identifier", compileContext);
				}
				target.pushSp(id.type.stackSize());
				break;

			case	MEMBER:
				pushThis(target);
				if (!loadFromSymbol(symbol, 0, id.type, target, compileContext))
					target.unfinished(tree, "member identifier loadFromSymbol", compileContext);
				break;

			case	STATIC:
				if (symbol.type().family() == TypeFamily.TYPEDEF) {
					ref<TypedefType> tt = ref<TypedefType>(symbol.type());
					ref<Type> t = tt.wrappedType();
					ref<TypeRef> tr = target.unit().newTypeRef(t, symbol.enclosing());
					target.byteCode(ByteCodes.LDSA);
					target.byteCode(tr.index());
					target.pushSp(address.bytes);
				} else
					generateStaticLoad(id, symbol, target, compileContext);
				break;

			default:
				target.unfinished(tree, "identifier storage class", compileContext);
			}
			break;
		}

		case	THIS:
		case	SUPER:
			pushThis(target);
			break;

		case	DOT: {
			ref<Selection> dot = ref<Selection>(tree);
			if (dot.left().type.family() == TypeFamily.VAR) {
				target.unfinished(tree, "var dot", compileContext);
			} else {
				switch (dot.symbol().storageClass()) {
				case STATIC:
					generateStaticLoad(dot, dot.symbol(), target, compileContext);
					break;

				case ENUMERATION:
					target.byteCode(ByteCodes.VALUE);
					if (dot.symbol().value == null) {
						target.unfinished(tree, "dot enum - no value", compileContext);
						break;
					}
					target.byteCode(ref<Value>(dot.symbol().value).index());
					target.pushSp(address.bytes);
					if (dot.symbol().offset > 0) {
						pushInteger(dot.symbol().offset * 4, target);
						target.byteCode(ByteCodes.ADD);
						target.popSp(address.bytes);
					}
					break;

				default:
					if (dot.indirect())
						generate(dot.left(), target, compileContext);
					else
						pushAddress(dot.left(), target, compileContext);
					if (!loadFromSymbol(dot.symbol(), 0, dot.type, target, compileContext))
						target.unfinished(tree, "dot - storage class", compileContext);
				}
			}
			break;
		}
		case	SUBSCRIPT: {
			ref<Binary> x = ref<Binary>(tree);
			if (x.left().type.isVector(compileContext) ||
				x.left().type.isMap(compileContext)) {
				CompileString name("get");
				
				ref<Symbol> sym = x.left().type.lookup(&name, compileContext);
				if (sym == null || sym.class != Overload) {
					tree.add(MessageId.UNDEFINED, compileContext.pool(), name);
					break;
				}
				ref<Overload> o = ref<Overload>(sym);
				ref<OverloadInstance> oi = o.instances()[0];
				generate(x.right(), target, compileContext);
				pushAddress(x.left(), target, compileContext);
				ref<FunctionType> functionType = ref<FunctionType>(oi.type());
				if (functionType == null) {
					target.unfinished(tree, "subscript get functionType == null", compileContext);
					break;
				}
				ref<Value>  value = target.unit().getCode(ref<ParameterScope>(functionType.scope()), target, compileContext);
				target.byteCode(ByteCodes.CALL);
				target.byteCode(value.index());
				target.pushSp(functionType.returnSize(target, compileContext) - 
						functionType.fixedArgsSize(target, compileContext) - address.bytes);
			} else if (x.left().type.family() == TypeFamily.STRING) {
				generate(x.left(), target, compileContext);
				generate(x.right(), target, compileContext);
				target.byteCode(ByteCodes.CHAR_AT);
				target.popSp(address.bytes);
			} else {
				generateSubscript(x, target, compileContext);
				if (!loadIndirect(x.type, target, compileContext))
					target.unfinished(tree, "subscript", compileContext);
			}
			break;
		}
		case	INDIRECT: {
			ref<Unary> x = ref<Unary>(tree);
			generate(x.operand(), target, compileContext);
			if (!loadIndirect(x.type, target, compileContext))
				target.unfinished(tree, "indirect", compileContext);
			break;
		}
		case	BYTES: {
			ref<Unary> x = ref<Unary>(tree);
			ref<Type> t = x.operand().type;
			if (t.family() == TypeFamily.TYPEDEF) {
				ref<TypedefType> tt = ref<TypedefType>(t);
				t = tt.wrappedType();
			}
			t.assignSize(target, compileContext);
			pushInteger(t.size(), target);
			break;
		}
		case	CLASS_OF:{
			ref<Unary> x = ref<Unary>(tree);
			ref<Type> t = x.operand().type;
			ref<Type> ind;
			switch (t.family()) {
			case	VAR:
				generate(x.operand(), target, compileContext);
				target.byteCode(ByteCodes.CLASSV);
				target.popSp(var.bytes - address.bytes);
				break;

			case	CLASS:
				ind = t.indirectType(compileContext);
				if (ind != null) {
					if (ind.hasVtable(compileContext)) {
						generate(x.operand(), target, compileContext);
						target.byteCode(ByteCodes.LDTR);	// TypeRef value
					} else {
						ref<TypeRef> tr = target.unit().newTypeRef(ind, _scope);
						target.byteCode(ByteCodes.LDSA);
						target.byteCode(tr.index());
						target.pushSp(address.bytes);
					}
				} else {
					ref<TypeRef> tr = target.unit().newTypeRef(t, _scope);
					target.byteCode(ByteCodes.LDSA);
					target.byteCode(tr.index());
					target.pushSp(address.bytes);
				}
				break;

			default:
				target.unfinished(tree, ".class type", compileContext);
			}
			break;
		}
		case	CALL: {
			ref<Call> call = ref<Call>(tree);
			if (call.target().type.family() == TypeFamily.ERROR)
				break;
			if (call.target().type.family() == TypeFamily.TYPEDEF) {
				ref<Symbol> sym = call.overload();
				if (sym != null) {
					if (sym.isFunction()) {
						ref<Function> f = ref<Function>(sym.definition());
						if (f.functionCategory() == Function.Category.CONSTRUCTOR) {
							int tempOffset = generateCall(call, null, call.type, false, target, compileContext);
							generateAutoLoad(call, call.type, tempOffset, target, compileContext);
						} else
							target.unfinished(tree, "typedef not a constructor", compileContext);
					} else
						target.unfinished(tree, "typedef not a function", compileContext);
				} else {
					generate(call.arguments().node, target, compileContext);
					generateCoercion(call.arguments().node.type, call.type, call, target, compileContext);
				}
			} else
				generateCall(call, null, null, false, target, compileContext);
			break;
		}

		case	EQUALITY:
		case	GREATER:
		case	GREATER_EQUAL:
		case	LESS:
		case	LESS_EQUAL:
		case	LESS_GREATER:
		case	LESS_GREATER_EQUAL:
		case	NOT_EQUAL:
		case	NOT_GREATER:
		case	NOT_GREATER_EQUAL:
		case	NOT_LESS:
		case	NOT_LESS_EQUAL:
		case	NOT_LESS_GREATER:
		case	NOT_LESS_GREATER_EQUAL: {
			ref<Binary> x = ref<Binary>(tree);
			ByteCodes bc = OpToByteCodeMap.byteCode[x.left().type.family()][x.op()];
			Operator op;
			if (bc == ByteCodes.string) {
				if (x.left().isLvalue()) {
					generate(x.right(), target, compileContext);
					pushAddress(x.left(), target, compileContext);
					op = x.op();
				} else if (x.right().isLvalue()) {
					generate(x.left(), target, compileContext);
					pushAddress(x.right(), target, compileContext);
					op = opToByteCodeMap.swapped[x.op()];
				} else {
					generate(x.left(), target, compileContext);
					int tempOffset = allocateTemp(x.left().type);
					// empty the temp
					pushInteger(0, target);
					target.byteCode(ByteCodes.STAA);	// STore Auto Address
					target.byteCode(tempOffset);
					target.byteCode(ByteCodes.POP);
					target.popSp(address.bytes);
					checkStack(target);
					generateAutoStore(x.left(), x.left().type, tempOffset, target, compileContext);
					target.byteCode(ByteCodes.POP);
					target.popSp(address.bytes);
					checkStack(target);
					generate(x.right(), target, compileContext);
					target.byteCode(ByteCodes.AUTO);
					target.byteCode(tempOffset);
					target.pushSp(address.bytes);
					checkStack(target);
					op = x.op();
				}
				target.byteCode(ByteCodes.CALL);
				ref<Value> func = _owner.getCode(target.stringCompare(), target, compileContext);
				target.byteCode(func.index());
				bc = OpToByteCodeMap.byteCode[TypeFamily.SIGNED_32][op];
				target.popSp(address.bytes);
				pushInteger(0, target);
			} else {
				generate(x.left(), target, compileContext);
				generate(x.right(), target, compileContext);
				checkStack(target);
			}
			if (bc != null)
				target.byteCode(bc);
			else
				target.unfinished(tree, "compare", compileContext);
			target.popSp(x.left().type.stackSize());
			target.popSp(x.right().type.stackSize());
			target.pushSp(address.bytes);
			checkStack(target);
			break;
		}
		case	ADD:
			if (tree.type.family() == TypeFamily.STRING) {
				ref<Binary> x = ref<Binary>(tree);
				
				generate(x.left(), target, compileContext);
				int tempOffset = allocateTemp(x.left().type);
				// empty the temp
				pushInteger(0, target);
				target.byteCode(ByteCodes.STAA);	// STore Auto Address
				target.byteCode(tempOffset);
				target.byteCode(ByteCodes.POP);
				target.popSp(address.bytes);
				checkStack(target);
				generateAutoStore(x.left(), x.left().type, tempOffset, target, compileContext);
				target.byteCode(ByteCodes.POP);
				target.popSp(address.bytes);
				checkStack(target);
				generate(x.right(), target, compileContext);
				target.byteCode(ByteCodes.AUTO);
				target.byteCode(tempOffset);
				target.pushSp(address.bytes);
				checkStack(target);
				target.byteCode(ByteCodes.CALL);
				ref<Value> v = _owner.getCode(target.stringAppend(), target, compileContext);
				target.byteCode(v.index());
				target.popSp(address.bytes);
				break;
			}

		case	SUBTRACT:
		case	DIVIDE:
		case	MULTIPLY:
		case	REMAINDER:
		case	LEFT_SHIFT:
		case	RIGHT_SHIFT:
		case	UNSIGNED_RIGHT_SHIFT:
		case	OR:
		case	AND:
		case	EXCLUSIVE_OR: {
			ref<Binary> x = ref<Binary>(tree);
			generate(x.left(), target, compileContext);
			if (x.right().type.isPointer(compileContext) &&
				!x.left().type.isPointer(compileContext)) {
				ref<Type> t = x.right().type.indirectType(compileContext);
				int size = t.size();
				if (size > 1) {
					target.byteCode(ByteCodes.INT);
					target.byteCode(size);
					target.byteCode(ByteCodes.MUL);
				}
			}
			generate(x.right(), target, compileContext);
			if (x.left().type.isPointer(compileContext) &&
				!x.right().type.isPointer(compileContext)) {
				ref<Type> t = x.left().type.indirectType(compileContext);
				int size = t.size();
				if (size > 1) {
					target.byteCode(ByteCodes.INT);
					target.byteCode(size);
					target.byteCode(ByteCodes.MUL);
				}
			}
			ByteCodes bc = OpToByteCodeMap.byteCode[x.type.family()][x.op()];
			if (bc != null)
				target.byteCode(bc);
			else
				target.unfinished(tree, "arithmetic", compileContext);
			target.popSp(x.left().type.stackSize());
			if (x.right().type.isPointer(compileContext) &&
				x.left().type.isPointer(compileContext)) {
				ref<Type> t = x.left().type.indirectType(compileContext);
				int size = t.size();
				if (size > 1) {
					target.byteCode(ByteCodes.INT);
					target.byteCode(size);
					target.byteCode(ByteCodes.DIV);
				}
			}
			break;
		}
		case	ASSIGN: {
			ref<Binary> x = ref<Binary>(tree);
			if (x.left().op() == Operator.SEQUENCE) {
				if (x.right().op() == Operator.CALL)
					generateCall(ref<Call>(x.right()), null, null, true, target, compileContext);
				else
					generate(x.right(), target, compileContext);
				generateMultiStore(x.left(), target, compileContext);
			} else if (x.type.family() == TypeFamily.STRING) {
				generateStringCopy(x.left(), x.right(), target.stringAssign(), target, compileContext);
			} else {
				generate(x.right(), target, compileContext);
				generateStore(x.left(), target, compileContext);
			}
			break;
		}
		case	ADD_ASSIGN:
		case	SUBTRACT_ASSIGN:
		case	DIVIDE_ASSIGN:
		case	MULTIPLY_ASSIGN:
		case	REMAINDER_ASSIGN:
		case	LEFT_SHIFT_ASSIGN:
		case	RIGHT_SHIFT_ASSIGN:
		case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
		case	OR_ASSIGN:
		case	AND_ASSIGN:
		case	EXCLUSIVE_OR_ASSIGN: {
			ref<Binary> x = ref<Binary>(tree);
			generate(x.left(), target, compileContext);
			generate(x.right(), target, compileContext);
			if (x.left().type.isPointer(compileContext) &&
				!x.right().type.isPointer(compileContext)) {
				ref<Type> t = x.left().type.indirectType(compileContext);
				int size = t.size();
				if (size > 1) {
					target.byteCode(ByteCodes.INT);
					target.byteCode(size);
					target.byteCode(ByteCodes.MUL);
				}
			}
			ByteCodes bc;
			if (x.left().type.isPointer(compileContext))
				bc = OpToByteCodeMap.byteCode[TypeFamily.ADDRESS][x.op()];
			else
				bc = OpToByteCodeMap.byteCode[x.type.family()][x.op()];
			if (bc != null) {
				target.byteCode(bc);
				target.popSp(x.left().type.stackSize());
			} else
				target.unfinished(tree, "arithmetic - assignment", compileContext);
			generateStore(x.left(), target, compileContext);
			break;
		}
		case	NEW: {
			ref<Binary> x = ref<Binary>(tree);
			ref<Type> t = x.right().type;
			if (t.family() == TypeFamily.TYPEDEF)
				t = ref<TypedefType>(t).wrappedType();
			if (x.right().op() == Operator.CALL) {
				int tempOffset = generateCall(ref<Call>(x.right()), tree, t, false, target, compileContext);
				if (tempOffset < 0) {
					target.byteCode(ByteCodes.LDAA);
					target.byteCode(tempOffset);
					target.pushSp(address.bytes);
				}
			} else {
				int size = t.size();
				target.byteCode(ByteCodes.NEW);
				target.byteCode(size);
				target.pushSp(address.bytes);
			}
			break;
		}
		case	DELETE: {
			ref<Binary> x = ref<Binary>(tree);
			generate(x.right(), target, compileContext);
			target.byteCode(ByteCodes.DELETE);
			target.popSp(address.bytes);
			break;
		}
		case	UNARY_PLUS:{	// always a no-op - just evaluate the operand
			ref<Unary> x = ref<Unary>(tree);
			generate(x.operand(), target, compileContext);
			break;
		}
		case	BIT_COMPLEMENT:
		case	NEGATE: {
			ref<Unary> x = ref<Unary>(tree);
			generate(x.operand(), target, compileContext);
			switch (x.type.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
			case	SIGNED_64:
				target.byteCode(OpToByteCodeMap.byteCode[x.type.family()][x.op()]);
				break;
			default:
				target.unfinished(tree, "type unexpected", compileContext);
			}
			break;
		}
		case	NOT: {
			ref<Unary> x = ref<Unary>(tree);
			generate(x.operand(), target, compileContext);
			target.byteCode(ByteCodes.NOT);
			break;
		}
		case	LOGICAL_AND:{
			ref<Binary> x = ref<Binary>(tree);
			int targetDepth = target.currentSpDepth();
			int firstTrue = createLabel();
			generate(x.left(), target, compileContext);
			target.byteCode(ByteCodes.JNZ);
			target.jumpTarget(firstTrue);
			target.byteCode(ByteCodes.INT);
			target.byteCode(0);
			int joinDepth = target.currentSpDepth();
			int join = createLabel();
			target.byteCode(ByteCodes.JMP);
			target.jumpTarget(join);
			locateLabel(firstTrue, target);
			target.pushSp(-targetDepth);
			generate(x.right(), target, compileContext);
			locateLabel(join, target);
			target.pushSp(-joinDepth);
			break;
		}
		case	LOGICAL_OR:{
			ref<Binary> x = ref<Binary>(tree);
			int targetDepth = target.currentSpDepth();
			int firstFalse = createLabel();
			generate(x.left(), target, compileContext);
			target.byteCode(ByteCodes.JZ);
			target.jumpTarget(firstFalse);
			target.byteCode(ByteCodes.INT);
			target.byteCode(1);
			int joinDepth = target.currentSpDepth();
			int join = createLabel();
			target.byteCode(ByteCodes.JMP);
			target.jumpTarget(join);
			locateLabel(firstFalse, target);
			target.pushSp(-targetDepth);
			generate(x.right(), target, compileContext);
			locateLabel(join, target);
			target.pushSp(-joinDepth);
			break;
		}
		case	INCREMENT_AFTER:
		case	DECREMENT_AFTER: {
			ref<Unary> x = ref<Unary>(tree);
			generate(x.operand(), target, compileContext);
			target.byteCode(ByteCodes.DUP);
			target.pushSp(address.bytes);
			target.byteCode(ByteCodes.INT);
			if (x.operand().type.isPointer(compileContext)) {
				ref<Type> t = x.operand().type.indirectType(compileContext);
				int size = t.size();
				target.byteCode(size);
			} else
				target.byteCode(1);
			if (x.op() == Operator.INCREMENT_AFTER)
				target.byteCode(ByteCodes.ADD);
			else
				target.byteCode(ByteCodes.SUB);
			generateStore(x.operand(), target, compileContext);
			target.byteCode(ByteCodes.POP);
			target.popSp(address.bytes);
			break;
		}
		case	INCREMENT_BEFORE: {
			ref<Unary> x = ref<Unary>(tree);
			generate(x.operand(), target, compileContext);
			target.byteCode(ByteCodes.INT);
			if (x.operand().type.isPointer(compileContext)) {
				ref<Type> t = x.operand().type.indirectType(compileContext);
				int size = t.size();
				target.byteCode(size);
			} else
				target.byteCode(1);
			target.byteCode(ByteCodes.ADD);
			generateStore(x.operand(), target, compileContext);
			break;
		}
		case	DECREMENT_BEFORE: {
			ref<Unary> x = ref<Unary>(tree);
			generate(x.operand(), target, compileContext);
			target.byteCode(ByteCodes.INT);
			if (x.operand().type.isPointer(compileContext)) {
				ref<Type> t = x.operand().type.indirectType(compileContext);
				int size = t.size();
				target.byteCode(size);
			} else
				target.byteCode(1);
			target.byteCode(ByteCodes.SUB);
			generateStore(x.operand(), target, compileContext);
			break;
		}
		case	INITIALIZE: {
			ref<Binary> x = ref<Binary>(tree);
			break;
		}
		
		case	CAST: {
			ref<Unary> u = ref<Unary>(tree);
			generate(u.operand(), target, compileContext);
			generateCoercion(u.operand().type, u.type, u.operand(), target, compileContext);
			break;
		}
		case	TEMPLATE_INSTANCE: {
			ref<Call> templ = ref<Call>(tree);

			ref<TypedefType> tt = ref<TypedefType>(templ.type);
			ref<Type> t = tt.wrappedType();
			ref<TypeRef> tr = target.unit().newTypeRef(t, compileContext.current());
			target.byteCode(ByteCodes.LDSA);
			target.byteCode(tr.index());
			target.pushSp(address.bytes);
			break;
		}
		
		default:
			target.unfinished(tree, "unexpected operator", compileContext);
		}
	}
	
	private void checkStack(ref<ByteCodesTarget> target) {
		target.byteCode(ByteCodes.CHKSTK);
		target.fixup(-target.currentSpDepth());
	}

	private void generateStaticLoad(ref<Node> tree, ref<Symbol> symbol, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		if (symbol.value == null) {
			if (tree.type.family() == TypeFamily.FUNCTION){
				ref<FunctionType> ft = ref<FunctionType>(tree.type);
				target.unit().getCode(ref<ParameterScope>(ft.scope()), target, compileContext);
			} else {
				target.unfinished(tree, "generateStaticLoad symbol value == null", compileContext);
				return;
			}
		}
		switch (tree.type.family()) {
		case	UNSIGNED_8:
		case	BOOLEAN:
			target.byteCode(ByteCodes.LDSB);
			target.byteCode(ref<Value>(symbol.value).index());
			break;

		case	UNSIGNED_16:
			target.byteCode(ByteCodes.LDSS);
			target.byteCode(ref<Value>(symbol.value).index());
			break;

		case	UNSIGNED_32:
			target.byteCode(ByteCodes.LDSU);
			target.byteCode(ref<Value>(symbol.value).index());
			break;

		case	SIGNED_32:
			target.byteCode(ByteCodes.LDSI);
			target.byteCode(ref<Value>(symbol.value).index());
			break;

		case	SIGNED_64:
		case	ENUM:
			target.byteCode(ByteCodes.LDSA);
			target.byteCode(ref<Value>(symbol.value).index());
			break;

		case	FUNCTION:
			if (symbol.class == OverloadInstance)
				target.byteCode(ByteCodes.VALUE);
			else
				target.byteCode(ByteCodes.LDSA);
			target.byteCode(ref<Value>(symbol.value).index());
			break;

		case	STRING:
			target.byteCode(ByteCodes.LDSA);
			target.byteCode(ref<Value>(symbol.value).index());
			break;

		case	CLASS:
			if (tree.type.indirectType(compileContext) != null) {
				target.byteCode(ByteCodes.LDSA);
				target.byteCode(ref<Value>(symbol.value).index());
			} else {
				pushAddress(ref<Value>(symbol.value), target);
				target.byteCode(ByteCodes.LDIO);
				int size = tree.type.size();
				target.byteCode(size);
				target.popSp(address.bytes);
			}
			break;

		default:
			target.unfinished(tree, "static load type", compileContext);
		}
		target.pushSp(tree.type.stackSize());
	}

	private int generateCall(ref<Call> call, ref<Node> placement, ref<Type> constructorType, boolean multiStore, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		ref<Node> func = call.target();
		if (func.type.family() == TypeFamily.VAR) {
			if (func.op() == Operator.DOT) {
				ref<Selection> f = ref<Selection>(func);
				ref<Node> left = f.left();
				if (left.type.family() == TypeFamily.VAR) {
					if (f.indirect())
						generate(f.left(), target, compileContext);
					else
						pushAddress(f.left(), target, compileContext);
					target.byteCode(ByteCodes.STRING);
					ref<String> s = _owner.newString(f.name());
					if (s == null) {
						call.add(MessageId.BAD_STRING, compileContext.pool(), f.name());
						target.byteCode(-1);
					} else
						target.byteCode(s.index());
					int count = 0;
					for (ref<NodeList> nl = call.arguments(); nl != null; nl = nl.next) {
						generate(nl.node, target, compileContext);
						count++;
					}
					target.byteCode(ByteCodes.INVOKE);
					target.byteCode(count);
					return 0;
				}
			}
			target.unfinished(call, "var not dot", compileContext);
			return 0;
		}

		ref<Symbol> overload = call.overload();
		if (overload != null && overload.type().family() != TypeFamily.FUNCTION) {
			// This can only arise when a class constructor was called with no defined
			// parameter-less constructor.
			if (placement != null)
				generateObjectPlacement(placement, constructorType, target, compileContext);
			return 0;
		}
		ref<FunctionType> functionType = ref<FunctionType>(func.type);
		int cleanup = generateArguments(call.arguments(), functionType.parameters(), target, compileContext);
		checkStack(target);
		int pushedThisSize = 0;
		int tempOffset = 0;
		if (overload != null) {
			boolean isIndirectCall = false;
			if (overload.storageClass() == StorageClass.MEMBER) {
				if (placement != null) {
					tempOffset = generateObjectPlacement(placement, constructorType, target, compileContext);
					if (tempOffset != 0) {
						target.byteCode(ByteCodes.STAA);
						target.byteCode(tempOffset);
					}
				} else if (constructorType != null) {					// inline constructor
					tempOffset = allocateTemp(constructorType);
					target.byteCode(ByteCodes.AUTO);
					target.byteCode(tempOffset);
					target.pushSp(address.bytes);
				} else if (func.op() == Operator.DOT) {
					ref<Selection> dot = ref<Selection>(func);
					if (dot.indirect()) {
						generate(dot.left(), target, compileContext);
						isIndirectCall = dot.left().op() != Operator.SUPER;
					} else
						pushAddress(dot.left(), target, compileContext);
				} else {
					pushThis(target);
					isIndirectCall = true;
				}
				pushedThisSize = address.bytes;
			}
			if (isIndirectCall && overload.usesVTable(compileContext)) {
				target.byteCode(ByteCodes.VCALL);
				target.byteCode(overload.offset);
				target.byteCode(-1);
			} else {
				ref<Value> value = target.unit().getCode(ref<ParameterScope>(functionType.scope()), target, compileContext);
				// Hopefully, this will get caught elsewhere.
				if (value == null) {
//					target.unfinished(call, "call function type == null");
					return 0;
				}
				if (value.class == BuiltInFunction) {
					ref<BuiltInFunction> f = ref<BuiltInFunction>(value);
					target.byteCode(ByteCodes.XCALL);
					target.byteCode(f.builtInIndex());
				} else {
					target.byteCode(ByteCodes.CALL);
					target.byteCode(value.index());
				}
			}
		} else {
			generate(call.target(), target, compileContext);
			target.byteCode(ByteCodes.ICALL);
			target.popSp(address.bytes);
		}
		target.pushSp(functionType.returnSize(target, compileContext) -
				functionType.fixedArgsSize(target, compileContext) - pushedThisSize);
		if (cleanup != 0) {
			int returnSize = functionType.returnSize(target, compileContext);
			if (returnSize == 0)
				target.byteCode(ByteCodes.VARG);
			else if (returnSize <= long.bytes)
				target.byteCode(ByteCodes.VARG1);
			else
				target.unfinished(call, "big return size", compileContext);
			target.byteCode(cleanup);
			target.popSp(cleanup);
		}
		if (!multiStore && functionType.returnCount() > 1)
			clearMultiReturn(functionType.returnType().next, target, compileContext);
		checkStack(target);
		return tempOffset;
	}

	private void clearMultiReturn(ref<NodeList> retn, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		if (retn.next != null)
			clearMultiReturn(retn.next, target, compileContext);
		if (!clearStack(retn.node.type, target, compileContext))
			target.unfinished(retn.node, "clearStack - multireturn", compileContext);
	}
	
	private int generateObjectPlacement(ref<Node> placement, ref<Type> constructorType, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		int tempOffset = 0;
		if (constructorType != null) {
			if (placement.op() == Operator.NEW) {		// regular new expression
				int size = constructorType.size();
				target.byteCode(ByteCodes.NEW);
				target.byteCode(size);
				target.pushSp(address.bytes);
				tempOffset = allocateTemp(target.arena().builtInType(TypeFamily.ADDRESS));
			} else									// placement new expression
				generate(placement, target, compileContext);
		} else {									// static initializer
			pushAddress(placement, target, compileContext);
			constructorType = placement.type;
		}
		if (constructorType.hasVtable(compileContext))
			storeVtable(constructorType, target, compileContext);
		return tempOffset;
	}

	private void generateSwitch(ref<Node> tree, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		ref<Binary> stmt = ref<Binary>(tree);
		int breakLabel = createLabel();
		int defaultLabel = createLabel();
		GatherCasesClosure closure;
		closure.target = target;
		target.gatherCases(stmt.right(), &closure);
		ByteCodesTarget.JumpContext jumpContext(stmt, breakLabel, defaultLabel, &closure.nodes, this, target.jumpContext());
		generate(stmt.left(), target, compileContext);
		checkStack(target);
		int[] labels = jumpContext.caseLabels();
		int mask = ~0;
		switch (stmt.left().type.family()) {
		case	UNSIGNED_8:
			target.byteCode(ByteCodes.CVTBI);
			mask = 0xff;
		case	SIGNED_32:
			target.byteCode(ByteCodes.SWITCHI);
			target.byteCode(labels.length());
			target.jumpTarget(defaultLabel);
			for (int i = 0; i < labels.length(); i++) {
				ref<Binary> caseNode = ref<Binary>(closure.nodes[i]);
				int x = int(caseNode.left().foldInt(compileContext));
				target.byteCode(x & mask);
				target.jumpTarget(labels[i]);
			}
			break;

		case	ENUM:
			target.byteCode(ByteCodes.SWITCHE);
			target.byteCode(labels.length());
			target.jumpTarget(defaultLabel);
			for (int i = 0; i < labels.length(); i++) {
				ref<Binary> caseNode = ref<Binary>(closure.nodes[i]);
				if (caseNode.left().deferAnalysis())
					target.byteCode(0);
				else {
					ref<Identifier> c = ref<Identifier>(caseNode.left());
					if (c.symbol() != null) {
						target.byteCode(ref<Value>(c.symbol().value).index());
						target.byteCode(c.symbol().offset);
					} else
						target.unfinished(c, "enum switch", compileContext);
				}
				target.jumpTarget(labels[i]);
			}
			break;

		default:
			if (stmt.left().deferAnalysis())
				return;
			target.unfinished(stmt, "switch type", compileContext);
		}
		target.popSp(long.bytes);
		checkStack(target);
		target.pushJumpContext(&jumpContext);
		generate(stmt.right(), target, compileContext);
		target.popJumpContext();
		defaultLabel = jumpContext.defaultLabel();
		if (defaultLabel >= 0)
			locateLabel(defaultLabel, target);
		locateLabel(breakLabel, target);
	}

	private void generateExpressionStatement(ref<Node> tree, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		if (tree.type == null) {
			target.unfinished(tree, "expression type == null", compileContext);
			return;
		}
		generate(tree, target, compileContext);
		if (tree.type == null ||
			!clearStack(tree.type, target, compileContext))
			target.unfinished(tree, "clearStack = expression", compileContext);
	}

	private void generateInitializers(ref<Node> tree, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		boolean hasDefaultConstructor = false;
		switch (tree.op()) {
		case	IDENTIFIER:
			if (tree.type.family() == TypeFamily.CLASS) {
				ref<Scope> scope = tree.type.scope();
				for (int i = 0; i < scope.constructors().length(); i++) {
					ref<Scope> sc = scope.constructors()[i];
					if (sc.symbols().size() == 0) {
						pushAddress(tree, target, compileContext);
						checkStack(target);
						if (tree.type.hasVtable(compileContext))
							storeVtable(tree.type, target, compileContext);
						ref<FunctionType> functionType = ref<FunctionType>(sc.definition().type);
						ref<Value> value = target.unit().getCode(ref<ParameterScope>(functionType.scope()), target, compileContext);
						target.byteCode(ByteCodes.CALL);
						target.byteCode(value.index());
						target.popSp(address.bytes);
						checkStack(target);
						hasDefaultConstructor = true;
						break;
					}
				}
			}
			if (!hasDefaultConstructor) {
				ref<Symbol> sym = tree.symbol();
				if (sym != null &&
					sym.storageClass() == StorageClass.AUTO &&
					sym.type() != null &&
					sym.type().requiresAutoStorage()) {
					if (sym.type().hasVtable(compileContext)) {
						target.byteCode(ByteCodes.AUTO);
						target.byteCode(sym.offset);
						storeVtable(sym.type(), target, compileContext);
						target.byteCode(ByteCodes.POP);
						if (sym.type().size() > address.bytes) {
							target.byteCode(ByteCodes.ZERO_A);
							target.byteCode(int(sym.offset + address.bytes));
							target.byteCode(int(sym.type().size() - address.bytes)); 
						}
					} else {
						target.byteCode(ByteCodes.ZERO_A);
						target.byteCode(sym.offset);
						target.byteCode(sym.type().size()); 
					}
					break;
				}
			}
			break;

		case	SEQUENCE: {
			ref<Binary> seq = ref<Binary>(tree);
			generateInitializers(seq.left(), target, compileContext);
			generateInitializers(seq.right(), target, compileContext);
			break;
		}

		case	INITIALIZE: {
			ref<Binary> seq = ref<Binary>(tree);
			if (seq.type == null) {
				target.unfinished(tree, "initialize type == null", compileContext);
				break;
			}
			if (seq.right().op() == Operator.CALL) {
				ref<Call> call = ref<Call>(seq.right());
				if (call.commentary() != null) {
					generate(call, target, compileContext);
					break;
				}
				if (call.target() == null) {
					generateCall(call, seq.left(), null, false, target, compileContext);
					break;
				}
			}
			if (seq.type.family() == TypeFamily.STRING)
				generateStringCopy(seq.left(), seq.right(), target.stringCopyConstructor(), target, compileContext);
			else {
				generate(seq.right(), target, compileContext);
				generateStore(seq.left(), target, compileContext);
			}
			if (!clearStack(seq.type, target, compileContext))
				target.unfinished(tree, "clearStack - initialize", compileContext);
			break;
		}
		default:
			target.unfinished(tree, "generateInitializers", compileContext);
		}
	}

	private void generateStringCopy(ref<Node> left, ref<Node> right, ref<ParameterScope> method, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		generate(right, target, compileContext);
		target.byteCode(ByteCodes.DUP);
		target.pushSp(address.bytes);
		pushAddress(left, target, compileContext);
		target.byteCode(ByteCodes.CALL);
		ref<Value> v = _owner.getCode(method, target, compileContext);
		target.byteCode(v.index());
		target.popSp(var.bytes);
		//target.byteCode(ByteCodes.LDIA);
	}

	private void generateStore(ref<Node> tree, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		switch (tree.op()) {
		case	IDENTIFIER: {
			ref<Identifier> id = ref<Identifier>(tree);
			if (id.deferAnalysis()) {
				// TODO: Fix up with proper exception
				target.byteCode(ByteCodes.THROW);
				break;
			}
			ref<Symbol> symbol = id.symbol();
			ref<Value> constructor;
			if (symbol == null) {
				target.unfinished(tree, "store - symbol == null", compileContext);
				break;
			}
			if (id.type == null) {
				target.unfinished(tree, "store - id.type == null", compileContext);
				break;
			}
			switch (symbol.storageClass()) {
			case	AUTO:
				generateAutoStore(tree, id.type, symbol.offset, target, compileContext);
				break;

			case	PARAMETER:
				switch (id.type.family()) {
				case	BOOLEAN:
				case	UNSIGNED_8:
					target.byteCode(ByteCodes.STPB);	// STore Params Byte
					target.byteCode(symbol.offset);
					break;

				case	SIGNED_32:
					target.byteCode(ByteCodes.STPI);	// STore Params Int
					target.byteCode(symbol.offset);
					break;

				case	SIGNED_64:
					target.byteCode(ByteCodes.STPL);	// STore Params Int
					target.byteCode(symbol.offset);
					break;

				case	STRING:
					target.byteCode(ByteCodes.PARAMS);	// Params address
					target.byteCode(symbol.offset);
					target.byteCode(ByteCodes.SWAP);
					target.byteCode(ByteCodes.CALL);
					constructor = _owner.getCode(target.stringCopyConstructor(), target, compileContext);
					target.byteCode(constructor.index());
					break;

				case	ENUM:
					target.byteCode(ByteCodes.STPA);	// STore params Pointer
					target.byteCode(symbol.offset);
					break;

				case	CLASS:
					if (id.type.indirectType(compileContext) != null) {
						target.byteCode(ByteCodes.STPA);	// STore params Pointer
						target.byteCode(symbol.offset);
					} else {
						target.byteCode(ByteCodes.STPO);	// STore Auto Object
						target.byteCode(symbol.offset);
						target.byteCode(id.type.size());
					}
					break;

				default:
					target.unfinished(tree, "store param unexpected type", compileContext);
				}
				break;

			case	MEMBER:
				pushThis(target);
				if (!storeToSymbol(symbol, 0, id.type, target, compileContext))
					target.unfinished(tree, "member storeToSymbol failed", compileContext);
				break;

			case	STATIC:
				switch (id.type.family()) {
				case	UNSIGNED_8:
				case	BOOLEAN:
					target.byteCode(ByteCodes.STSB);	// STore Static Byte
					target.byteCode(ref<Value>(symbol.value).index());
					break;

				case	UNSIGNED_16:
					target.byteCode(ByteCodes.STSC);	// STore Static Short
					target.byteCode(ref<Value>(symbol.value).index());
					break;

				case	SIGNED_32:
				case	UNSIGNED_32:
					target.byteCode(ByteCodes.STSI);	// STore Static Int
					target.byteCode(ref<Value>(symbol.value).index());
					break;

				case	SIGNED_64:
				case	ENUM:
				case	FUNCTION:
					target.byteCode(ByteCodes.STSA);	// STore Static Pointer
					target.byteCode(ref<Value>(symbol.value).index());
					break;

				case	CLASS:
					if (id.type.indirectType(compileContext) != null) {
						target.byteCode(ByteCodes.STSA);	// STore params Pointer
						target.byteCode(ref<Value>(symbol.value).index());
					} else {
						target.byteCode(ByteCodes.STSO);	// STore params Pointer
						target.byteCode(ref<Value>(symbol.value).index());
						target.byteCode(symbol.type().stackSize());
					}
					break;

				default:
					target.unfinished(tree, "store identifier static unexpected type", compileContext);
				}
				break;

			default:
				target.unfinished(tree, "store identifier unexpected storage class", compileContext);
			}
			break;
		}
		case DOT: {
			ref<Selection> dot = ref<Selection>(tree);
			if (dot.indirect())
				generate(dot.left(), target, compileContext);
			else
				pushAddress(dot.left(), target, compileContext);
			if (!storeToSymbol(dot.symbol(), 0, dot.type, target, compileContext))
				target.unfinished(tree, "store dot storeToSymbol failed", compileContext);
			break;
		}
		case	INDIRECT: {
			ref<Unary> x = ref<Unary>(tree);
			generate(x.operand(), target, compileContext);
			if (!storeIndirect(x.type, target, compileContext))
				target.unfinished(tree, "store indirect storeIndirect failed", compileContext);
			break;
		}
		case	SUBSCRIPT: {
			ref<Binary> x = ref<Binary>(tree);
			if (x.left().type.isVector(compileContext) ||
				x.left().type.isMap(compileContext)) {
				CompileString name("set");
				
				ref<Symbol> sym = x.left().type.lookup(&name, compileContext);
				if (sym == null || sym.class != Overload) {
					tree.add(MessageId.UNDEFINED, compileContext.pool(), name);
					break;
				}
				ref<Overload> o = ref<Overload>(sym);
				ref<OverloadInstance> oi = o.instances()[0];
				// Gross, gross, gross: cheap, dirty and hold my nose bad
				target.byteCode(ByteCodes.DUP);
				target.pushSp(address.bytes);
				generate(x.right(), target, compileContext);
				pushAddress(x.left(), target, compileContext);
				ref<FunctionType> functionType = ref<FunctionType>(oi.assignType(compileContext));
				ref<Value> value = target.unit().getCode(ref<ParameterScope>(functionType.scope()), target, compileContext);
				target.byteCode(ByteCodes.CALL);
				target.byteCode(value.index());
				target.popSp(3 * address.bytes);
			} else if (x.left().type.family() == TypeFamily.STRING) {
				generate(x.left(), target, compileContext);
				target.byteCode(ByteCodes.INT);
				target.byteCode(int(int.bytes));
				target.byteCode(ByteCodes.ADD);
				generate(x.right(), target, compileContext);
				target.byteCode(ByteCodes.ADD);
				target.byteCode(ByteCodes.STIB);
				target.popSp(2 * address.bytes);
			} else {
				generateSubscript(x, target, compileContext);
				if (!storeIndirect(x.type, target, compileContext))
					target.unfinished(tree, "store subscript storeIndirect failed", compileContext);
			}
			break;
		}
		default:
			target.unfinished(tree, "store", compileContext);
		}
	}

	private void generateMultiStore(ref<Node> tree, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		while (tree.op() == Operator.SEQUENCE) {
			ref<Binary> b = ref<Binary>(tree);
			generateMultiStore(b.right(), target, compileContext);
			tree = b.left();
		}
		generateStore(tree, target, compileContext);
		if (!clearStack(tree.type, target, compileContext))
			target.unfinished(tree, "generateMultiReturn - clearStack failed", compileContext);
	}

	private void generateAutoStore(ref<Node> tree, ref<Type> type, int offset, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		ref<Value> constructor;
		switch (type.family()) {
		case	BOOLEAN:
		case	UNSIGNED_8:
			target.byteCode(ByteCodes.STAB);	// STore Auto Byte
			target.byteCode(offset);
			return;

		case	UNSIGNED_16:
			target.byteCode(ByteCodes.STAS);	// STore Auto Short
			target.byteCode(offset);
			return;

		case	UNSIGNED_32:
		case	SIGNED_32:
			target.byteCode(ByteCodes.STAI);	// STore Auto Int
			target.byteCode(offset);
			return;

		case	ADDRESS:
		case	SIGNED_64:
		case	ENUM:
		case	FUNCTION:
			target.byteCode(ByteCodes.STAA);	// STore Auto Pointer
			target.byteCode(offset);
			return;

		case	STRING:
			target.byteCode(ByteCodes.DUP);
			target.byteCode(ByteCodes.AUTO);	// Auto address
			target.byteCode(offset);
			target.byteCode(ByteCodes.CALL);
			constructor = _owner.getCode(target.stringCopyConstructor(), target, compileContext);
			target.byteCode(constructor.index());
			return;

		case	CLASS:
			if (type.indirectType(compileContext) != null) {
				target.byteCode(ByteCodes.STAA);	// STore Auto Pointer
				target.byteCode(offset);
				return;
			} else {
				target.byteCode(ByteCodes.STAO);	// STore Auto Object
				target.byteCode(offset);
				target.byteCode(type.size());
				return;
			}
			break;

		case	VAR:
			target.byteCode(ByteCodes.STAV);	// STore Auto Var
			target.byteCode(offset);
			return;
		}
		target.unfinished(tree, "generateAutoStore", compileContext);
	}

	private void generateAutoLoad(ref<Node> tree, ref<Type> type, int offset, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		switch (type.family()) {
	/*
		case	UNSIGNED_8:
		case	BOOLEAN:
			target.byteCode(ByteCodes.LDAB);
			target.byteCode(offset);
			break;

		case	UNSIGNED_16:
			target.byteCode(ByteCodes.LDAC);
			target.byteCode(offset);
			break;

		case	SIGNED_32:
			target.byteCode(ByteCodes.LDAI);
			target.byteCode(offset);
			break;

		case	UNSIGNED_32:
			target.byteCode(ByteCodes.LDAU);
			target.byteCode(offset);
			break;

		case	ENUM:
		case	ADDRESS:
	*/
		case	STRING:
		case	FUNCTION:
			target.byteCode(ByteCodes.LDAA);
			target.byteCode(offset);
			break;

		case	CLASS:
			if (type.indirectType(compileContext) != null) {
				target.byteCode(ByteCodes.LDAA);
				target.byteCode(offset);
			} else {
				target.byteCode(ByteCodes.LDAO);
				target.byteCode(offset);
				target.byteCode(type.size());
			}
			break;

		case	VAR:
			target.byteCode(ByteCodes.LDAO);
			target.byteCode(offset);
			target.byteCode(var.bytes);
			break;

		default:
			target.unfinished(tree, "generateAutoLoad", compileContext);
		}
		target.pushSp(type.stackSize());
	}

	private void generateVargStore(ref<Node> tree, ref<Type> type, int offset, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		ref<Value> constructor;
		switch (type.family()) {
		case	BOOLEAN:
		case	UNSIGNED_8:
			target.byteCode(ByteCodes.STVB);	// STore Auto Byte
			target.fixup(offset);
			return;

		case	UNSIGNED_16:
			target.byteCode(ByteCodes.STVS);	// STore Auto Short
			target.fixup(offset);
			return;

		case	UNSIGNED_32:
		case	SIGNED_32:
			target.byteCode(ByteCodes.STVI);	// STore Auto Int
			target.fixup(offset);
			return;

		case	ENUM:
			target.byteCode(ByteCodes.STVA);	// STore Auto Pointer
			target.fixup(offset);
			return;

		case	STRING:
			target.byteCode(ByteCodes.DUP);
			target.byteCode(ByteCodes.AVARG);	// Auto address
			target.fixup(offset);
			target.byteCode(ByteCodes.CALL);
			constructor = _owner.getCode(target.stringCopyConstructor(), target, compileContext);
			target.byteCode(constructor.index());
			return;

		case	CLASS:
			if (type.indirectType(compileContext) != null) {
				target.byteCode(ByteCodes.STVA);	// STore Auto Pointer
				target.fixup(offset);
				return;
			} else {
				target.byteCode(ByteCodes.STVO);	// STore Auto Object
				target.fixup(offset);
				target.byteCode(type.size());
				return;
			}
			break;

		case	VAR:
			target.byteCode(ByteCodes.STVV);	// STore Auto Var
			target.fixup(offset);
			return;
		}
		target.unfinished(tree, "generateVargStore", compileContext);
	}

	private void generateSubscript(ref<Binary> x, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		ref<Type> t = x.left().type.indirectType(compileContext);
		if (t != null) {
			generate(x.left(), target, compileContext);
			generate(x.right(), target, compileContext);
			t.assignSize(target, compileContext);
			checkStack(target);
			if (t.size() != 1) {
				pushInteger(t.size(), target);
				target.byteCode(ByteCodes.MUL);
				target.popSp(long.bytes);
				checkStack(target);
			}
			target.byteCode(ByteCodes.ADD);
			target.popSp(x.left().type.stackSize());
			checkStack(target);
		} else {
			x.print(0);
			assert(false);
		}
	}

	private void generateCoercion(ref<Type> existingType, ref<Type> newType, ref<Node> n, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		switch (existingType.family()) {
		case	UNSIGNED_8:
			switch (newType.family()) {
			case	SIGNED_32:
				target.byteCode(ByteCodes.CVTBI);
				return;
				
			case	SIGNED_64:
				target.byteCode(ByteCodes.CVTBI);
				target.byteCode(ByteCodes.CVTIL);
				return;

			case	ENUM:
				target.byteCode(ByteCodes.CVTBI);
				generateIntToEnum(ref<EnumInstanceType>(newType), target);
				return;
			}
			break;

		case	UNSIGNED_16:
			switch (newType.family()) {
			case	UNSIGNED_8:
				return;

			case	VAR:
				target.byteCode(ByteCodes.CVTCI);
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

			case	SIGNED_32:
				target.byteCode(ByteCodes.CVTCI);
				return;

			case	SIGNED_64:
				target.byteCode(ByteCodes.CVTCI);
				target.byteCode(ByteCodes.CVTIL);
				return;
			}
			break;

		case	UNSIGNED_32:
			switch (newType.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
				return;

			case	SIGNED_64:
			case	ADDRESS:
				target.byteCode(ByteCodes.CVTUL);
				return;
				
			case	ENUM:
				generateIntToEnum(ref<EnumInstanceType>(newType), target);
				return;

			case	VAR:
				target.byteCode(ByteCodes.CVTIV);
				target.pushSp(var.bytes - address.bytes);
				return;

			case	CLASS:
				if (newType.indirectType(compileContext) != null)
					return;	// TODO: widen from int 32 to pointer type.
			}
			break;

		case	SIGNED_32:
			switch (newType.family()) {
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_32:
				return;

			case	SIGNED_64:
			case	ADDRESS:
				target.byteCode(ByteCodes.CVTIL);
				return;
				
			case	ENUM:
				generateIntToEnum(ref<EnumInstanceType>(newType), target);
				return;

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

			case	CLASS:
				if (newType.indirectType(compileContext) != null)
					return;	// TODO: widen from int 32 to pointer type.
			}
			break;

		case	SIGNED_64:
			switch (newType.family()) {
			case	SIGNED_32:
			case	UNSIGNED_32:
			case	ADDRESS:
				return;
				
			case	VAR:
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
			}
			break;

		case	ADDRESS:
			switch (newType.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
			case	ADDRESS:
			case	FUNCTION:
			case	ENUM:
				return;

			case	STRING:
				// The only valid conversion is for the NULL node.
				// so do nothing here.
				return;

			case	CLASS:
				if (newType.indirectType(compileContext) != null)
					return;
				break;
				
			case	VAR:
				ref<TypeRef> tr = target.unit().newTypeRef(existingType, compileContext.current());
				target.byteCode(ByteCodes.LDSA);
				target.byteCode(tr.index());
				target.byteCode(ByteCodes.CVTAV);
				target.pushSp(var.bytes - address.bytes);
				return;
			}
			break;

		case	ENUM:
			switch (newType.family()) {
			case	UNSIGNED_8:
			case	SIGNED_32: {
				ref<EnumInstanceType> t = ref<EnumInstanceType>(existingType);
				pushAddress(ref<Value>(t.symbol().value), target);
				target.byteCode(ByteCodes.SUB);
				target.popSp(address.bytes);
				pushInteger(4, target);
				target.byteCode(ByteCodes.DIV);
				target.popSp(address.bytes);
			}	return;

			case	ADDRESS:
				return;

			case	CLASS:
				if (newType.indirectType(compileContext) != null) {
					return;
				}
				break;
			}
			break;

		case	CLASS:
			if (existingType.indirectType(compileContext) != null) {
				ref<Scope> scope;
				switch (newType.family()) {
				case	SIGNED_32:
				case	SIGNED_64:
				case	ADDRESS:
					return;

				case	STRING:
					scope = newType.scope();
					for (int i = 0; i < scope.constructors().length(); i++) {
						ref<Scope> sc = scope.constructors()[i];
						if (sc.symbols().size() == 1 &&
							sc.symbols().first().type() == existingType) {
							ref<Function> constructorDef = ref<Function>(sc.definition());
							ref<Symbol> sym = constructorDef.name().symbol();
							ref<FunctionType> functionType = ref<FunctionType>(sym.type());
							checkStack(target);
							ref<Value>  value = target.unit().getCode(ref<ParameterScope>(functionType.scope()), target, compileContext);
							target.byteCode(ByteCodes.CALL);
							target.byteCode(value.index());
							target.popSp(address.bytes);
							return;
						}
					}
					break;

				case	CLASS:
					if (newType.indirectType(compileContext) != null)
						return;
					break;

				case	VAR:
					ref<TypeRef> tr = target.unit().newTypeRef(existingType, compileContext.current());
					target.byteCode(ByteCodes.LDSA);
					target.byteCode(tr.index());
					target.byteCode(ByteCodes.CVTAV);
					target.pushSp(var.bytes - address.bytes);
					return;
				}
			} else {
				// A general class coercion from another class type.
				if (existingType.size() == newType.size())
					return;
			}
			break;

		case	STRING:
			switch (newType.family()) {
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
				
			case	STRING:
				return;
			}
			break;

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
		}
		target.unfinished(n, "generateCoercion", compileContext);
	}

	private void generateIntToEnum(ref<EnumInstanceType> newType, ref<ByteCodesTarget> target) {
		pushInteger(4, target);
		target.byteCode(ByteCodes.MUL);
		target.popSp(address.bytes);
		pushAddress(ref<Value>(newType.symbol().value), target);
		target.byteCode(ByteCodes.ADD);
		target.popSp(address.bytes);
	}
	
	private int generateArguments(ref<NodeList> args, ref<NodeList> params, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		if (params == null)
			return 0;
		ref<Unary> ellipsis = params.node.getProperEllipsis();
		if (ellipsis != null) {
			if (args != null && args.next == null && args.node.type.equals(params.node.type)) {
				generate(args.node, target, compileContext);
				return 0;
			}
			int vargCount = 0;
			for (ref<NodeList> v = args; v != null; v = v.next)
				vargCount++;
			ref<Type> e = params.node.type.elementType(compileContext);
			e.assignSize(target, compileContext);
			int varArgSize = (e.size() * vargCount + long.bytes - 1) & ~(long.bytes - 1);
			target.byteCode(ByteCodes.SP);
			target.byteCode(varArgSize);
			target.pushSp(varArgSize);
			int offset = -target.currentSpDepth();
			target.pushSp(address.bytes);
			while (args != null) {
				if (args.node.type == null) {
					target.unfinished(args.node, "generateArguments type == null", compileContext);
					continue;
				}
				if (args.node.type.family() == TypeFamily.STRING) {
					generate(args.node, target, compileContext);
					target.byteCode(ByteCodes.AVARG);
					target.fixup(offset);
					target.pushSp(address.bytes);
					target.byteCode(ByteCodes.CALL);
					ref<Value> v = _owner.getCode(target.stringCopyConstructor(), target, compileContext);
					target.byteCode(v.index());
					target.popSp(address.bytes + address.bytes);
				} else {
					generate(args.node, target, compileContext);
					generateVargStore(args.node, args.node.type, offset, target, compileContext);
					if (!clearStack(args.node.type, target, compileContext))
						target.unfinished(args.node, "generateArguments clearStack failed", compileContext);
				}
				offset -= e.size();
				args = args.next;
			}
			pushLong((long(vargCount) << 32) | vargCount, target);
			return varArgSize;
		} else {
			int varArgsSize = 0;
			if (params.next != null)
				varArgsSize = generateArguments(args.next, params.next, target, compileContext);
			generate(args.node, target, compileContext);
			return varArgsSize;
		}
	}

	private boolean generateReturn(ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		if (_scope.definition().op() != Operator.FUNCTION) {			// in-line code
			target.byteCode(ByteCodes.RET1);
			target.byteCode(0);
		} else {							// a function body
			ref<Function> func = ref<Function>(_scope.definition());
			ref<FunctionType> functionType = ref<FunctionType>(func.type);
			if (functionType == null) {
				target.unfinished(func, "generateReturn functionType == null", compileContext);
				return true;
			}
			if (functionType.returnType() == null)
				target.byteCode(ByteCodes.RET);
			else if (functionType.returnType().next != null) {
				int totalSize = 0;

				for (ref<NodeList> nl = functionType.returnType(); nl != null; nl = nl.next)
					totalSize += nl.node.type.stackSize();
				target.byteCode(ByteCodes.RETN);
				target.byteCode(totalSize);
			} else {
				ref<Type> returnType = functionType.returnType().node.type;
				switch (returnType.family()) {
				case	VOID:
					break;

				case	BOOLEAN:
				case	UNSIGNED_8:
				case	UNSIGNED_16:
				case	UNSIGNED_32:
				case	SIGNED_32:
				case	SIGNED_64:
				case	STRING:
				case	ENUM:
				case	ADDRESS:
				case	FUNCTION:
					target.byteCode(ByteCodes.RET1);
					break;

				case	VAR:
					target.byteCode(ByteCodes.RETN);
					target.byteCode(familySize[TypeFamily.VAR]);
					break;

				case	CLASS:
					if (returnType.indirectType(compileContext) != null)
						target.byteCode(ByteCodes.RET1);
					else {
						// TODO: Add code to generate constructor for TOS, if one is warranted.
						target.byteCode(ByteCodes.RETN);
						target.byteCode(returnType.size());
					}
					break;

				default:
					return false;
				}
			}
			int sz = functionType.fixedArgsSize(target, compileContext);
			if (sz < 0)
				return false;
			if ((sz & 1) != 0)
				return false;
			ref<Symbol> sym = func.name().symbol();
			if (sym.storageClass() == StorageClass.MEMBER)
				sz += address.bytes;
			target.byteCode(sz);
		}
		target.popSp(-target.currentSpDepth());
		return true;
	}

	private boolean clearStack(ref<Type> tos, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		switch (tos.family()) {
		case	VOID:
		case	ERROR:
		case	CLASS_DEFERRED:
			break;

		case	ADDRESS:
		case	FUNCTION:
		case	UNSIGNED_8:
		case	UNSIGNED_16:
		case	UNSIGNED_32:
		case	SIGNED_32:
		case	SIGNED_64:
		case	BOOLEAN:
		case	STRING:
		case	ENUM:
			target.byteCode(ByteCodes.POP);
			target.popSp(address.bytes);
			break;

		case	VAR:
			target.byteCode(ByteCodes.POPN);
			target.byteCode(int(var.bytes));
			target.popSp(var.bytes);
			break;

		case	CLASS:
			if (tos.indirectType(compileContext) != null) {
				target.byteCode(ByteCodes.POP);
				target.popSp(address.bytes);
			} else {
				target.byteCode(ByteCodes.POPN);
				target.byteCode(tos.stackSize());
				target.popSp(tos.stackSize());
			}
			break;

		default:
			return false;
		}
		target.byteCode(ByteCodes.CHKSTK);
		target.fixup(-target.currentSpDepth());
		return true;
	}

	private boolean loadFromSymbol(ref<Symbol> symbol, int offset, ref<Type> t, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		if (symbol.offset != 0) {
			pushInteger(symbol.offset, target);
			target.byteCode(ByteCodes.ADD);
			target.popSp(address.bytes);
		}
		return loadIndirect(t, target, compileContext);
	}

	private boolean storeToSymbol(ref<Symbol> symbol, int offset, ref<Type> t, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		if (symbol.offset != 0) {
			pushInteger(symbol.offset, target);
			target.byteCode(ByteCodes.ADD);
			target.popSp(long.bytes);
		}
		return storeIndirect(t, target, compileContext);
	}

	private void storeVtable(ref<Type> t, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		ref<Value> v = target.buildVtable(t.scope(), compileContext);
		target.byteCode(ByteCodes.VALUE);
		target.byteCode(v.index());
		target.byteCode(ByteCodes.POPIA);
	}

	private boolean loadIndirect(ref<Type> t, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		target.popSp(address.bytes);
		target.pushSp(t.stackSize());
		switch (t.family()) {
		case	UNSIGNED_8:
		case	BOOLEAN:
			target.byteCode(ByteCodes.LDIB);
			return true;

		case	UNSIGNED_16:
			target.byteCode(ByteCodes.LDIC);
			return true;

		case	STRING:
		case	ADDRESS:
		case	FUNCTION:
		case	ENUM:
			target.byteCode(ByteCodes.LDIA);
			return true;

		case	SIGNED_32:
			target.byteCode(ByteCodes.LDII);
			return true;

		case	UNSIGNED_32:
			target.byteCode(ByteCodes.LDIU);
			return true;

		case	SIGNED_64:
			target.byteCode(ByteCodes.LDIL);
			return true;

		case	VAR:
			target.byteCode(ByteCodes.LDIV);
			return true;

		case	CLASS:
			if (t.indirectType(compileContext) != null) {
				target.byteCode(ByteCodes.LDIA);
				return true;
			} else {
				target.byteCode(ByteCodes.LDIO);
				target.byteCode(t.stackSize());
				return true;
			}
		}
		return false;
	}

	private boolean storeIndirect(ref<Type> t, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		target.popSp(address.bytes);
		switch (t.family()) {
		case	UNSIGNED_8:
		case	BOOLEAN:
			target.byteCode(ByteCodes.STIB);
			return true;

		case	UNSIGNED_16:
			target.byteCode(ByteCodes.STIC);
			return true;

		case	STRING:
		case	ADDRESS:
		case	FUNCTION:
		case	ENUM:
			target.byteCode(ByteCodes.STIA);
			return true;

		case	SIGNED_32:
		case	UNSIGNED_32:
			target.byteCode(ByteCodes.STII);
			return true;

		case	SIGNED_64:
			target.byteCode(ByteCodes.STIL);
			return true;

		case	VAR:
			target.byteCode(ByteCodes.STIV);
			return true;

		case	CLASS:
			if (t.indirectType(compileContext) != null)
				target.byteCode(ByteCodes.STIA);
			else {
				target.byteCode(ByteCodes.STIO);
				target.byteCode(t.size());
			}
			return true;
		}
		return false;
	}
	
	private void pushAddress(ref<Value> value, ref<ByteCodesTarget> target) {
		target.byteCode(ByteCodes.ADDR);
		target.byteCode(value.index());
		target.pushSp(address.bytes);
	}

	private void pushAddress(ref<Node> n, ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		switch (n.op()) {
		case	DOT: {
			ref<Selection> s = ref<Selection>(n);
			if (s.indirect())
				generate(s.left(), target, compileContext);
			else if (s.symbol().storageClass() == StorageClass.STATIC ||
					 s.symbol().storageClass() == StorageClass.CONSTANT) {
				target.byteCode(ByteCodes.VALUE);
				if (s.symbol().value == null) {
					target.unfinished(s, "pushAddress selection value == null", compileContext);
					break;
				}
				target.byteCode(ref<Value>(s.symbol().value).index());
				target.pushSp(address.bytes);
				break;
			} else
				pushAddress(s.left(), target, compileContext);
			if (s.symbol().offset != 0) {
				pushInteger(s.symbol().offset, target);
				target.byteCode(ByteCodes.ADD);
				target.popSp(address.bytes);
			}
		}break;

		case	INDIRECT: {
			ref<Unary> u = ref<Unary>(n);
			generate(u.operand(), target, compileContext);
		}break;

		case	IDENTIFIER: {
			ref<Identifier> id = ref<Identifier>(n);
			switch (id.symbol().storageClass()) {
			case	AUTO:
				target.byteCode(ByteCodes.AUTO);
				target.byteCode(id.symbol().offset);
				break;

			case	PARAMETER:
				target.byteCode(ByteCodes.PARAMS);
				target.byteCode(id.symbol().offset);
				break;

			case	STATIC:
				target.byteCode(ByteCodes.VALUE);
				if (id.symbol().value == null) {
					target.unfinished(id, "pushAddress id value == null", compileContext);
					break;
				}
				target.byteCode(ref<Value>(id.symbol().value).index());
				break;

			case	MEMBER:
				pushThis(target);
				if (id.symbol().offset != 0) {
					pushInteger(id.symbol().offset, target);
					target.byteCode(ByteCodes.ADD);
					target.popSp(address.bytes);
				}
				target.popSp(address.bytes);
				break;

			default:
				target.unfinished(id, "pushAddress", compileContext);
			}
			target.pushSp(address.bytes);
		}break;

		case	STRING: {
			ref<Constant> str = ref<Constant>(n);
			target.byteCode(ByteCodes.ASTRING);
			ref<String> s = _owner.newString(str.value());
			if (s == null) {
				n.add(MessageId.BAD_STRING, compileContext.pool(), str.value());
				target.byteCode(-1);
			} else
				target.byteCode(s.index());
			target.pushSp(address.bytes);
		}break;

		case	SUBSCRIPT: {
			ref<Binary> b = ref<Binary>(n);
			if (b.left().type.isVector(compileContext)) {
				ref<Symbol> sym = b.left().type.scope().lookup("elementAddress");
				if (sym.class != Overload) {
					target.unfinished(n, "elementAddress not an Overloaded symbol", compileContext);
					break;
				}
				sym = ref<Overload>(sym).instances()[0];
				generate(b.right(), target, compileContext);
				pushAddress(b.left(), target, compileContext);
				if (sym.type().family() != TypeFamily.FUNCTION) {
					target.unfinished(n, "elementAddress not a function", compileContext);
					break;
				}
				ref<FunctionType> functionType = ref<FunctionType>(sym.type());
				checkStack(target);
				ref<Value>  value = target.unit().getCode(ref<ParameterScope>(functionType.scope()), target, compileContext);
				target.byteCode(ByteCodes.CALL);
				target.byteCode(value.index());
				target.popSp(address.bytes);
			} else if (b.left().type.isMap(compileContext)) {
				ref<Symbol> sym = b.left().type.scope().lookup("createEmpty");
				if (sym.class != Overload) {
					target.unfinished(n, "createEmpty is not an Overloaded symbol", compileContext);
					break;
				}
				sym = ref<Overload>(sym).instances()[0];
				generate(b.right(), target, compileContext);
				pushAddress(b.left(), target, compileContext);
				if (sym.type().family() != TypeFamily.FUNCTION) {
					target.unfinished(n, "createEmpty not a function", compileContext);
					break;
				}
				ref<FunctionType> functionType = ref<FunctionType>(sym.type());
				checkStack(target);
				ref<Value>  value = target.unit().getCode(ref<ParameterScope>(functionType.scope()), target, compileContext);
				target.byteCode(ByteCodes.CALL);
				target.byteCode(value.index());
				target.popSp(address.bytes);
			} else if (b.left().type.family() == TypeFamily.STRING) {
				generate(b.left(), target, compileContext);
				target.byteCode(ByteCodes.INT);
				target.byteCode(int(int.bytes));
				target.byteCode(ByteCodes.ADD);
				generate(b.right(), target, compileContext);
				target.byteCode(ByteCodes.ADD);
				target.popSp(address.bytes);
			} else {
				generate(b.left(), target, compileContext);
				generate(b.right(), target, compileContext);
				ref<Type> t = b.left().type.indirectType(compileContext);
				if (t != null && t.size() > 1) {
					target.byteCode(ByteCodes.INT);
					target.byteCode(t.size());
					target.byteCode(ByteCodes.MUL);
				}
				target.byteCode(ByteCodes.ADD);
				target.popSp(address.bytes);
			}
		}break;

		case	CALL: {
			generate(n, target, compileContext);
			int tempOffset = allocateTemp(n.type);
			generateAutoStore(n, n.type, tempOffset, target, compileContext);
			clearStack(n.type, target, compileContext);
			checkStack(target);
			target.byteCode(ByteCodes.AUTO);
			target.byteCode(tempOffset);
			target.pushSp(address.bytes);
			checkStack(target);
		}break;

		default:
			target.unfinished(n, "pushAddress", compileContext);
		}
	}

	private void pushInteger(int i, ref<ByteCodesTarget> target) {
		target.byteCode(ByteCodes.INT);
		target.byteCode(i);
		target.pushSp(address.bytes);
	}

	private void pushLong(long x, ref<ByteCodesTarget> target) {
		target.byteCode(ByteCodes.LONG);
		target.byteCode(int(x));
		target.byteCode(int(x >> 32));
		target.pushSp(long.bytes);
	}
	
	private void pushThis(ref<ByteCodesTarget> target) {
		target.byteCode(ByteCodes.LDPA);
		target.byteCode(0);
		target.pushSp(address.bytes);
	}
}

class StaticObject extends Value {
	private ref<Unit> _owner;
	private ref<Symbol> _symbol;
	private address _data;
	private int _size;

	StaticObject(ref<Unit>  owner, ref<Symbol> symbol, int size) {
		_owner = owner;
		_symbol = symbol;
		_size = size;
		_data = allocz(size);
		switch (symbol.type().family()) {
		case	TYPEDEF:
			ref<Scope> s = symbol.type().scope();
			for (ref<Symbol>[string].iterator i = s.symbols().begin(); i.hasNext(); i.next()) {
				ref<Symbol> instance = i.get();
				pointer<int>(_data)[instance.offset] = instance.offset;
			}
			break;
		}
	}

	public void initializeStorage(ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
		ref<PlainSymbol> ps = ref<PlainSymbol>(_symbol);
		ref<Node> initializer = ps.initializer();

		if (_symbol.type().hasVtable(compileContext)) {
			ref<Value> v = target.buildVtable(_symbol.type().scope(), compileContext);
			if (v != null)
				*ref<address>(_data) = v.machineAddress();
		}
		if (initializer == null)
			return;
		switch (initializer.op()) {
		case	INTEGER:{
			ref<Constant> c = ref<Constant>(initializer);
			long x = c.intValue();
			C.memcpy(_data, &x, _size);
			break;
		}
	//	default:
	//		target.unfinished(initializer, "initialize storage");
		}
	}

	public void print() {
		super.print();
		printf(" %s %p[%d]", _symbol.name().asString(), _data, _size);
	}

	public void disassemble(int indent) {
		if (_symbol.type().family() == TypeFamily.TYPEDEF) {
			ref<TypedefType> tt = ref<TypedefType>(_symbol.type());
			if (tt.wrappedType().family() == TypeFamily.ENUM) {
				for (int i = 0; i < _size; i += 4) {
					indentBy(indent + 4);
					printf("0x%08d\n", *ref<int>(pointer<byte>(_data) + i));
				}
			}
		}
	}

	public address machineAddress() {
		return _data;
	}

	public int length() {
		return _size;
	}
	
}

class String extends Value {
	private address _value;
	private int _length;

	String(string value) {
		if (value != null) {
			_length = address.bytes + int.bytes + value.length() + 1;
			_value = allocz(_length);
			pointer<int> data = pointer<int>(pointer<address>(_value) + 1);
			*pointer<address>(_value) = data;
			*data = value.length();
			C.memcpy(data + 1, &value[0], value.length() + 1);
		} else {
			_length = address.bytes;
			_value = allocz(_length);
		}
	}

	public void print() {
		super.print();
		address value = pointer<address>(_value) + 1;
		printf(" '%s'", *ref<string>(&value));
	}

	public address machineAddress() {
		return _value;
	}

	public int length() {
		return _length;
	}
	
	public void emitRelocations(ref<ByteCodeSection> section) {
		section.emitRelocation(_index, 0, _index, address.bytes);
	}
	
}

class TypeRef extends Value {
	private ref<Type> _type;
	private long _ordinal;
	
	TypeRef(ref<Type> addr, ref<Unit> unit) {
		_type = addr;
		_ordinal = _type.ordinal(unit.maxTypeOrdinal);
		if (_ordinal > unit.maxTypeOrdinal)
			unit.maxTypeOrdinal = int(_ordinal);
	}

	public void print() {
		super.print();
		printf(" @%08x [%d] ", _type, _ordinal);
		_type.print();
	}

	public address machineAddress() {
		return &_ordinal;
	}

	public int length() {
		return _ordinal.bytes;
	}
}

class VTable extends Value {
	ref<TypeRef> _typeRef;
	ref<ClassScope> _classScope;
	private int[] _virtualMethods;		// value index of each Code object, or else null.  size = ClassScope methods map size

	VTable(ref<ClassScope> classScope, ref<TypeRef> typeRef) {
		_classScope = classScope;
		_typeRef = typeRef;
		_virtualMethods.resize(_classScope.methods().length() + 1);
	}

	public void populateTable() {
		_virtualMethods[0] = _typeRef.index();
		for (int i = 0; i < _classScope.methods().length(); i++) {
			ref<OverloadInstance> method = _classScope.methods()[i];
			if (!method.deferAnalysis() &&
				method.value != null)
				_virtualMethods[i + 1] = ref<Value>(method.value).index();
			else
				_virtualMethods[i + 1] = -1;
		}
	}

	public void print() {
		super.print();
		printf(" ClassScope %p[%d]", _classScope, _virtualMethods.length());
	}

	public void disassemble(int indent) {
		indentBy(indent);
		printf("Methods for ");
		_typeRef.print();
		printf(":\n");
		for (int i = 1; i < _virtualMethods.length(); i++)
			printf("    @%d\n", _virtualMethods[i]);
	}

	public address machineAddress() {
		return &_virtualMethods[0];
	}

	public int length() {
		return _virtualMethods.length() * int.bytes;
	}

/*
	const vector<int> &virtualMethods() const { return _virtualMethods; }

	ref<TypeRef> typeRef() { return _typeRef; }
*/
}

class Value {
	int _index;			// The value index in the parent unit.

	public int index() {
		return _index;
	}
/*
	virtual void initialize(ref<Node> initializer, ref<ByteCodesTarget> target);
*/
	public void print() {
		printf("[%d/%p] %s", _index, machineAddress(), ""/*this.class.name()*/);
	}

	public void disassemble(int indent) {
	}
	
	public address machineAddress() {
		return null;
	}

	public int length() {
		return 0;
	}
	
	public void emitRelocations(ref<ByteCodeSection> section) {
	}
	
	public void initializeStorage(ref<ByteCodesTarget> target, ref<CompileContext> compileContext) {
	}
}

class ByteCodeSection extends pxi.Section {
	private int _entryPoint;
	private ref<Unit> _unit;
	private int _valueDataLength;
	private ByteCodeRelocation[] _relocations;
	
	public ByteCodeSection(int entryPoint, ref<Unit> unit) {
		super(pxi.SectionType.BYTE_CODES);
		_entryPoint = entryPoint;
		_unit = unit;
		for (int i = 0; i < _unit.values().length(); i++) {
			_valueDataLength += _unit.values()[i].length() + (address.bytes - 1);
			_valueDataLength &= ~(address.bytes - 1);
			_unit.values()[i].emitRelocations(this);
		}
	}
	
	public long length() {
		return ByteCodeSectionHeader.bytes + _unit.values().length() * int.bytes + _valueDataLength +
				_relocations.length() * ByteCodeRelocation.bytes;
	}
	
	public void write(file.File pxiFile) {
		ByteCodeSectionHeader header;
		header.entryPoint = _entryPoint;
		header.objectCount = _unit.values().length();
		header.relocationCount = _relocations.length();
		pxiFile.write(&header, header.bytes);
		int len = 0;
		for (int i = 0; i < _unit.values().length(); i++) {
			pxiFile.write(&len, len.bytes);
			len += _unit.values()[i].length() + (address.bytes - 1);
			len &= ~(address.bytes - 1);
		}
		for (int i = 0; i < _relocations.length(); i++) {
			pointer<ByteCodeRelocation> r = &_relocations[i];
			pointer<byte> pb = pointer<byte>(_unit.values()[r.relocObject].machineAddress());
			*ref<address>(pb + r.relocOffset) = null;
		}
		for (int i = 0; i < _unit.values().length(); i++) {
			int actualLen = _unit.values()[i].length();
			int len = actualLen + (address.bytes - 1);
			len &= ~(address.bytes - 1);			
			pxiFile.write(_unit.values()[i].machineAddress(), actualLen);
			address dummy;
			pxiFile.write(&dummy, len - actualLen);
		}
		for (int i = 0; i < _relocations.length(); i++)
			pxiFile.write(&_relocations[i], _relocations[i].bytes);
	}
	
	public void emitRelocation(int relocObject, int relocOffset, int reference, int offset) {
		ByteCodeRelocation reloc;
		
		reloc.relocObject = relocObject;
		reloc.relocOffset = relocOffset;
		reloc.reference = reference;
		reloc.offset = offset;
		_relocations.append(reloc);
	}
}

public class ByteCodeRelocation {
	public int relocObject;			// Object containing this relocation
	public int relocOffset;			// Object offset where relocation must be done
	public int reference;			// Object id of the referenced object
	public int offset;				// Object offset within the referenced object
}

public class ByteCodeSectionHeader {
	public int entryPoint;			// Object id of the starting function to run in the image
	public int objectCount;			// Total number of objects in the object table
	public int relocationCount;		// Total number of relocations
	private int _1;					// Filler
}

private class OpToByteCodeMap {
	public OpToByteCodeMap() {
		byteCode.resize(TypeFamily.MAX_TYPES);
		byteCode[TypeFamily.BOOLEAN].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.BOOLEAN][Operator.OR]						= ByteCodes.OR;

		byteCode[TypeFamily.BOOLEAN][Operator.AND]						= ByteCodes.AND;
		byteCode[TypeFamily.BOOLEAN][Operator.EXCLUSIVE_OR]				= ByteCodes.XOR;
		byteCode[TypeFamily.BOOLEAN][Operator.EQUALITY]					= ByteCodes.EQI;
		byteCode[TypeFamily.BOOLEAN][Operator.NOT_EQUAL]				= ByteCodes.NEI;
		byteCode[TypeFamily.BOOLEAN][Operator.OR_ASSIGN]				= ByteCodes.OR;
		byteCode[TypeFamily.BOOLEAN][Operator.AND_ASSIGN]				= ByteCodes.AND;
		byteCode[TypeFamily.BOOLEAN][Operator.EXCLUSIVE_OR_ASSIGN]		= ByteCodes.XOR;

		byteCode[TypeFamily.UNSIGNED_8].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.UNSIGNED_8][Operator.BIT_COMPLEMENT]		= ByteCodes.BCM;
		byteCode[TypeFamily.UNSIGNED_8][Operator.NEGATE]				= ByteCodes.NEG;
		byteCode[TypeFamily.UNSIGNED_8][Operator.LEFT_SHIFT]			= ByteCodes.LSH;
		byteCode[TypeFamily.UNSIGNED_8][Operator.RIGHT_SHIFT]			= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_8][Operator.UNSIGNED_RIGHT_SHIFT]	= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_8][Operator.MULTIPLY_ASSIGN]		= ByteCodes.MUL;
		byteCode[TypeFamily.UNSIGNED_8][Operator.DIVIDE_ASSIGN]			= ByteCodes.DIV;
		byteCode[TypeFamily.UNSIGNED_8][Operator.REMAINDER_ASSIGN]		= ByteCodes.REM;
		byteCode[TypeFamily.UNSIGNED_8][Operator.ADD_ASSIGN]			= ByteCodes.ADD;
		byteCode[TypeFamily.UNSIGNED_8][Operator.SUBTRACT_ASSIGN]		= ByteCodes.SUB;
		byteCode[TypeFamily.UNSIGNED_8][Operator.LEFT_SHIFT_ASSIGN]		= ByteCodes.LSH;
		byteCode[TypeFamily.UNSIGNED_8][Operator.RIGHT_SHIFT_ASSIGN]	= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_8][Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN]= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_8][Operator.OR_ASSIGN]				= ByteCodes.OR;
		byteCode[TypeFamily.UNSIGNED_8][Operator.AND_ASSIGN]			= ByteCodes.AND;
		byteCode[TypeFamily.UNSIGNED_8][Operator.EXCLUSIVE_OR_ASSIGN]	= ByteCodes.XOR;

		byteCode[TypeFamily.UNSIGNED_16].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.UNSIGNED_16][Operator.BIT_COMPLEMENT]		= ByteCodes.BCM;
		byteCode[TypeFamily.UNSIGNED_16][Operator.NEGATE]				= ByteCodes.NEG;
		byteCode[TypeFamily.UNSIGNED_16][Operator.LEFT_SHIFT]			= ByteCodes.LSH;
		byteCode[TypeFamily.UNSIGNED_16][Operator.RIGHT_SHIFT]			= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_16][Operator.UNSIGNED_RIGHT_SHIFT]	= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_16][Operator.MULTIPLY_ASSIGN]		= ByteCodes.MUL;
		byteCode[TypeFamily.UNSIGNED_16][Operator.DIVIDE_ASSIGN]		= ByteCodes.DIV;
		byteCode[TypeFamily.UNSIGNED_16][Operator.REMAINDER_ASSIGN]		= ByteCodes.REM;
		byteCode[TypeFamily.UNSIGNED_16][Operator.ADD_ASSIGN]			= ByteCodes.ADD;
		byteCode[TypeFamily.UNSIGNED_16][Operator.SUBTRACT_ASSIGN]		= ByteCodes.SUB;
		byteCode[TypeFamily.UNSIGNED_16][Operator.LEFT_SHIFT_ASSIGN]	= ByteCodes.LSH;
		byteCode[TypeFamily.UNSIGNED_16][Operator.RIGHT_SHIFT_ASSIGN]	= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_16][Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN]= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_16][Operator.OR_ASSIGN]			= ByteCodes.OR;
		byteCode[TypeFamily.UNSIGNED_16][Operator.AND_ASSIGN]			= ByteCodes.AND;
		byteCode[TypeFamily.UNSIGNED_16][Operator.EXCLUSIVE_OR_ASSIGN]	= ByteCodes.XOR;

		byteCode[TypeFamily.UNSIGNED_32].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.UNSIGNED_32][Operator.BIT_COMPLEMENT]		= ByteCodes.BCM;
		byteCode[TypeFamily.UNSIGNED_32][Operator.NEGATE]				= ByteCodes.NEG;
		byteCode[TypeFamily.UNSIGNED_32][Operator.MULTIPLY]				= ByteCodes.MUL;
		byteCode[TypeFamily.UNSIGNED_32][Operator.DIVIDE]				= ByteCodes.DIV;
		byteCode[TypeFamily.UNSIGNED_32][Operator.REMAINDER]			= ByteCodes.REM;
		byteCode[TypeFamily.UNSIGNED_32][Operator.ADD]					= ByteCodes.ADD;
		byteCode[TypeFamily.UNSIGNED_32][Operator.SUBTRACT]				= ByteCodes.SUB;
		byteCode[TypeFamily.UNSIGNED_32][Operator.LEFT_SHIFT]			= ByteCodes.LSH;
		byteCode[TypeFamily.UNSIGNED_32][Operator.RIGHT_SHIFT]			= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_32][Operator.UNSIGNED_RIGHT_SHIFT]= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_32][Operator.OR]					= ByteCodes.OR;
		byteCode[TypeFamily.UNSIGNED_32][Operator.AND]					= ByteCodes.AND;
		byteCode[TypeFamily.UNSIGNED_32][Operator.EXCLUSIVE_OR]			= ByteCodes.XOR;
		byteCode[TypeFamily.UNSIGNED_32][Operator.EQUALITY]				= ByteCodes.EQI;
		byteCode[TypeFamily.UNSIGNED_32][Operator.GREATER]				= ByteCodes.GTU;
		byteCode[TypeFamily.UNSIGNED_32][Operator.GREATER_EQUAL]		= ByteCodes.GEU;
		byteCode[TypeFamily.UNSIGNED_32][Operator.LESS]					= ByteCodes.LTU;
		byteCode[TypeFamily.UNSIGNED_32][Operator.LESS_EQUAL]			= ByteCodes.LEU;
		byteCode[TypeFamily.UNSIGNED_32][Operator.LESS_GREATER]			= ByteCodes.NEI;
		byteCode[TypeFamily.UNSIGNED_32][Operator.NOT_EQUAL]			= ByteCodes.NEI;
		byteCode[TypeFamily.UNSIGNED_32][Operator.NOT_GREATER]			= ByteCodes.LEU;
		byteCode[TypeFamily.UNSIGNED_32][Operator.NOT_GREATER_EQUAL]	= ByteCodes.LTU;
		byteCode[TypeFamily.UNSIGNED_32][Operator.NOT_LESS]				= ByteCodes.GEU;
		byteCode[TypeFamily.UNSIGNED_32][Operator.NOT_LESS_EQUAL]		= ByteCodes.GTU;
		byteCode[TypeFamily.UNSIGNED_32][Operator.NOT_LESS_GREATER]		= ByteCodes.EQI;
		byteCode[TypeFamily.UNSIGNED_32][Operator.MULTIPLY_ASSIGN]		= ByteCodes.MUL;
		byteCode[TypeFamily.UNSIGNED_32][Operator.DIVIDE_ASSIGN]		= ByteCodes.DIV;
		byteCode[TypeFamily.UNSIGNED_32][Operator.REMAINDER_ASSIGN]		= ByteCodes.REM;
		byteCode[TypeFamily.UNSIGNED_32][Operator.ADD_ASSIGN]			= ByteCodes.ADD;
		byteCode[TypeFamily.UNSIGNED_32][Operator.SUBTRACT_ASSIGN]		= ByteCodes.SUB;
		byteCode[TypeFamily.UNSIGNED_32][Operator.LEFT_SHIFT_ASSIGN]	= ByteCodes.LSH;
		byteCode[TypeFamily.UNSIGNED_32][Operator.RIGHT_SHIFT_ASSIGN]	= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_32][Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN]= ByteCodes.URS;
		byteCode[TypeFamily.UNSIGNED_32][Operator.OR_ASSIGN]			= ByteCodes.OR;
		byteCode[TypeFamily.UNSIGNED_32][Operator.AND_ASSIGN]			= ByteCodes.AND;
		byteCode[TypeFamily.UNSIGNED_32][Operator.EXCLUSIVE_OR_ASSIGN]	= ByteCodes.XOR;

		byteCode[TypeFamily.SIGNED_32].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.SIGNED_32][Operator.BIT_COMPLEMENT]			= ByteCodes.BCM;
		byteCode[TypeFamily.SIGNED_32][Operator.NEGATE]					= ByteCodes.NEG;
		byteCode[TypeFamily.SIGNED_32][Operator.MULTIPLY]				= ByteCodes.MUL;
		byteCode[TypeFamily.SIGNED_32][Operator.DIVIDE]					= ByteCodes.DIV;
		byteCode[TypeFamily.SIGNED_32][Operator.REMAINDER]				= ByteCodes.REM;
		byteCode[TypeFamily.SIGNED_32][Operator.ADD]					= ByteCodes.ADD;
		byteCode[TypeFamily.SIGNED_32][Operator.SUBTRACT]				= ByteCodes.SUB;
		byteCode[TypeFamily.SIGNED_32][Operator.LEFT_SHIFT]				= ByteCodes.LSH;
		byteCode[TypeFamily.SIGNED_32][Operator.RIGHT_SHIFT]			= ByteCodes.RSH;
		byteCode[TypeFamily.SIGNED_32][Operator.UNSIGNED_RIGHT_SHIFT]	= ByteCodes.URS;
		byteCode[TypeFamily.SIGNED_32][Operator.OR]						= ByteCodes.OR;
		byteCode[TypeFamily.SIGNED_32][Operator.AND]					= ByteCodes.AND;
		byteCode[TypeFamily.SIGNED_32][Operator.EXCLUSIVE_OR]			= ByteCodes.XOR;
		byteCode[TypeFamily.SIGNED_32][Operator.EQUALITY]				= ByteCodes.EQI;
		byteCode[TypeFamily.SIGNED_32][Operator.GREATER]				= ByteCodes.GTI;
		byteCode[TypeFamily.SIGNED_32][Operator.GREATER_EQUAL]			= ByteCodes.GEI;
		byteCode[TypeFamily.SIGNED_32][Operator.LESS]					= ByteCodes.LTI;
		byteCode[TypeFamily.SIGNED_32][Operator.LESS_EQUAL]				= ByteCodes.LEI;
		byteCode[TypeFamily.SIGNED_32][Operator.LESS_GREATER]			= ByteCodes.NEI;
		byteCode[TypeFamily.SIGNED_32][Operator.NOT_EQUAL]				= ByteCodes.NEI;
		byteCode[TypeFamily.SIGNED_32][Operator.NOT_GREATER]			= ByteCodes.LEI;
		byteCode[TypeFamily.SIGNED_32][Operator.NOT_GREATER_EQUAL]		= ByteCodes.LTI;
		byteCode[TypeFamily.SIGNED_32][Operator.NOT_LESS]				= ByteCodes.GEI;
		byteCode[TypeFamily.SIGNED_32][Operator.NOT_LESS_EQUAL]			= ByteCodes.GTI;
		byteCode[TypeFamily.SIGNED_32][Operator.NOT_LESS_GREATER]		= ByteCodes.EQI;
		byteCode[TypeFamily.SIGNED_32][Operator.MULTIPLY_ASSIGN]		= ByteCodes.MUL;
		byteCode[TypeFamily.SIGNED_32][Operator.DIVIDE_ASSIGN]			= ByteCodes.DIV;
		byteCode[TypeFamily.SIGNED_32][Operator.REMAINDER_ASSIGN]		= ByteCodes.REM;
		byteCode[TypeFamily.SIGNED_32][Operator.ADD_ASSIGN]				= ByteCodes.ADD;
		byteCode[TypeFamily.SIGNED_32][Operator.SUBTRACT_ASSIGN]		= ByteCodes.SUB;
		byteCode[TypeFamily.SIGNED_32][Operator.LEFT_SHIFT_ASSIGN]		= ByteCodes.LSH;
		byteCode[TypeFamily.SIGNED_32][Operator.RIGHT_SHIFT_ASSIGN]		= ByteCodes.RSH;
		byteCode[TypeFamily.SIGNED_32][Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN]= ByteCodes.URS;
		byteCode[TypeFamily.SIGNED_32][Operator.OR_ASSIGN]				= ByteCodes.OR;
		byteCode[TypeFamily.SIGNED_32][Operator.AND_ASSIGN]				= ByteCodes.AND;
		byteCode[TypeFamily.SIGNED_32][Operator.EXCLUSIVE_OR_ASSIGN]	= ByteCodes.XOR;

		byteCode[TypeFamily.SIGNED_64].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.SIGNED_64][Operator.BIT_COMPLEMENT]			= ByteCodes.BCM;
		byteCode[TypeFamily.SIGNED_64][Operator.NEGATE]					= ByteCodes.NEG;
		byteCode[TypeFamily.SIGNED_64][Operator.MULTIPLY]				= ByteCodes.MUL;
		byteCode[TypeFamily.SIGNED_64][Operator.DIVIDE]					= ByteCodes.DIV;
		byteCode[TypeFamily.SIGNED_64][Operator.REMAINDER]				= ByteCodes.REM;
		byteCode[TypeFamily.SIGNED_64][Operator.ADD]					= ByteCodes.ADD;
		byteCode[TypeFamily.SIGNED_64][Operator.SUBTRACT]				= ByteCodes.SUB;
		byteCode[TypeFamily.SIGNED_64][Operator.LEFT_SHIFT]				= ByteCodes.LSH;
		byteCode[TypeFamily.SIGNED_64][Operator.RIGHT_SHIFT]			= ByteCodes.RSH;
		byteCode[TypeFamily.SIGNED_64][Operator.UNSIGNED_RIGHT_SHIFT]	= ByteCodes.URS;
		byteCode[TypeFamily.SIGNED_64][Operator.OR]						= ByteCodes.OR;
		byteCode[TypeFamily.SIGNED_64][Operator.AND]					= ByteCodes.AND;
		byteCode[TypeFamily.SIGNED_64][Operator.EXCLUSIVE_OR]			= ByteCodes.XOR;
		byteCode[TypeFamily.SIGNED_64][Operator.EQUALITY]				= ByteCodes.EQL;
		byteCode[TypeFamily.SIGNED_64][Operator.GREATER]				= ByteCodes.GTL;
		byteCode[TypeFamily.SIGNED_64][Operator.GREATER_EQUAL]			= ByteCodes.GEL;
		byteCode[TypeFamily.SIGNED_64][Operator.LESS]					= ByteCodes.LTL;
		byteCode[TypeFamily.SIGNED_64][Operator.LESS_EQUAL]				= ByteCodes.LEL;
		byteCode[TypeFamily.SIGNED_64][Operator.LESS_GREATER]			= ByteCodes.NEL;
		byteCode[TypeFamily.SIGNED_64][Operator.NOT_EQUAL]				= ByteCodes.NEL;
		byteCode[TypeFamily.SIGNED_64][Operator.NOT_GREATER]			= ByteCodes.LEL;
		byteCode[TypeFamily.SIGNED_64][Operator.NOT_GREATER_EQUAL]		= ByteCodes.LTL;
		byteCode[TypeFamily.SIGNED_64][Operator.NOT_LESS]				= ByteCodes.GEL;
		byteCode[TypeFamily.SIGNED_64][Operator.NOT_LESS_EQUAL]			= ByteCodes.GTL;
		byteCode[TypeFamily.SIGNED_64][Operator.NOT_LESS_GREATER]		= ByteCodes.EQL;
		byteCode[TypeFamily.SIGNED_64][Operator.MULTIPLY_ASSIGN]		= ByteCodes.MUL;
		byteCode[TypeFamily.SIGNED_64][Operator.DIVIDE_ASSIGN]			= ByteCodes.DIV;
		byteCode[TypeFamily.SIGNED_64][Operator.REMAINDER_ASSIGN]		= ByteCodes.REM;
		byteCode[TypeFamily.SIGNED_64][Operator.ADD_ASSIGN]				= ByteCodes.ADD;
		byteCode[TypeFamily.SIGNED_64][Operator.SUBTRACT_ASSIGN]		= ByteCodes.SUB;
		byteCode[TypeFamily.SIGNED_64][Operator.LEFT_SHIFT_ASSIGN]		= ByteCodes.LSH;
		byteCode[TypeFamily.SIGNED_64][Operator.RIGHT_SHIFT_ASSIGN]		= ByteCodes.RSH;
		byteCode[TypeFamily.SIGNED_64][Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN]= ByteCodes.URS;
		byteCode[TypeFamily.SIGNED_64][Operator.OR_ASSIGN]				= ByteCodes.OR;
		byteCode[TypeFamily.SIGNED_64][Operator.AND_ASSIGN]				= ByteCodes.AND;
		byteCode[TypeFamily.SIGNED_64][Operator.EXCLUSIVE_OR_ASSIGN]	= ByteCodes.XOR;

		byteCode[TypeFamily.ADDRESS].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.ADDRESS][Operator.EQUALITY]					= ByteCodes.EQL;
		byteCode[TypeFamily.ADDRESS][Operator.NOT_EQUAL]				= ByteCodes.NEL;
		byteCode[TypeFamily.ADDRESS][Operator.ADD_ASSIGN]				= ByteCodes.ADD;
		byteCode[TypeFamily.ADDRESS][Operator.SUBTRACT_ASSIGN]			= ByteCodes.SUB;

		byteCode[TypeFamily.FUNCTION].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.FUNCTION][Operator.EQUALITY]				= ByteCodes.EQL;
		byteCode[TypeFamily.FUNCTION][Operator.NOT_EQUAL]				= ByteCodes.NEL;

		// The only way an ADD gets a TypeFamily.CLASS is if this is a pointer
		byteCode[TypeFamily.CLASS].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.CLASS][Operator.ADD]						= ByteCodes.ADD;
		byteCode[TypeFamily.CLASS][Operator.SUBTRACT]					= ByteCodes.SUB;
		byteCode[TypeFamily.CLASS][Operator.EQUALITY]					= ByteCodes.EQL;
		byteCode[TypeFamily.CLASS][Operator.GREATER]					= ByteCodes.GTA;
		byteCode[TypeFamily.CLASS][Operator.GREATER_EQUAL]				= ByteCodes.GEA;
		byteCode[TypeFamily.CLASS][Operator.LESS]						= ByteCodes.LTA;
		byteCode[TypeFamily.CLASS][Operator.LESS_EQUAL]					= ByteCodes.LEA;
		byteCode[TypeFamily.CLASS][Operator.LESS_GREATER]				= ByteCodes.NEL;
		byteCode[TypeFamily.CLASS][Operator.NOT_EQUAL]					= ByteCodes.NEL;
		byteCode[TypeFamily.CLASS][Operator.NOT_GREATER]				= ByteCodes.LEA;
		byteCode[TypeFamily.CLASS][Operator.NOT_GREATER_EQUAL]			= ByteCodes.LTA;
		byteCode[TypeFamily.CLASS][Operator.NOT_LESS]					= ByteCodes.GEA;
		byteCode[TypeFamily.CLASS][Operator.NOT_LESS_EQUAL]				= ByteCodes.GTA;
		byteCode[TypeFamily.CLASS][Operator.NOT_LESS_GREATER]			= ByteCodes.EQL;

		byteCode[TypeFamily.STRING].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.STRING][Operator.EQUALITY]					= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.GREATER]					= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.GREATER_EQUAL]				= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.LESS]						= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.LESS_EQUAL]				= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.LESS_GREATER]				= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.NOT_EQUAL]					= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.NOT_GREATER]				= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.NOT_GREATER_EQUAL]			= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.NOT_LESS]					= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.NOT_LESS_EQUAL]			= ByteCodes.string;
		byteCode[TypeFamily.STRING][Operator.NOT_LESS_GREATER]			= ByteCodes.string;

		byteCode[TypeFamily.ENUM].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.ENUM][Operator.EQUALITY]					= ByteCodes.EQL;
		byteCode[TypeFamily.ENUM][Operator.NOT_EQUAL]					= ByteCodes.NEL;

		byteCode[TypeFamily.VAR].resize(Operator.MAX_OPERATOR);
		byteCode[TypeFamily.VAR][Operator.MULTIPLY]						= ByteCodes.MULV;
		byteCode[TypeFamily.VAR][Operator.DIVIDE]						= ByteCodes.DIVV;
		byteCode[TypeFamily.VAR][Operator.REMAINDER]					= ByteCodes.REMV;
		byteCode[TypeFamily.VAR][Operator.ADD]							= ByteCodes.ADDV;
		byteCode[TypeFamily.VAR][Operator.SUBTRACT]						= ByteCodes.SUBV;
		byteCode[TypeFamily.VAR][Operator.LEFT_SHIFT]					= ByteCodes.LSHV;
		byteCode[TypeFamily.VAR][Operator.RIGHT_SHIFT]					= ByteCodes.RSHV;
		byteCode[TypeFamily.VAR][Operator.UNSIGNED_RIGHT_SHIFT]			= ByteCodes.URSV;
		byteCode[TypeFamily.VAR][Operator.OR]							= ByteCodes.ORV;
		byteCode[TypeFamily.VAR][Operator.AND]							= ByteCodes.ANDV;
		byteCode[TypeFamily.VAR][Operator.EXCLUSIVE_OR]					= ByteCodes.XORV;
		byteCode[TypeFamily.VAR][Operator.EQUALITY]						= ByteCodes.EQV;
		byteCode[TypeFamily.VAR][Operator.GREATER]						= ByteCodes.GTV;
		byteCode[TypeFamily.VAR][Operator.GREATER_EQUAL]				= ByteCodes.GEV;
		byteCode[TypeFamily.VAR][Operator.LESS]							= ByteCodes.LTV;
		byteCode[TypeFamily.VAR][Operator.LESS_EQUAL]					= ByteCodes.LEV;
		byteCode[TypeFamily.VAR][Operator.LESS_GREATER]					= ByteCodes.LGV;
		byteCode[TypeFamily.VAR][Operator.NOT_EQUAL]					= ByteCodes.NEV;
		byteCode[TypeFamily.VAR][Operator.NOT_GREATER]					= ByteCodes.NGV;
		byteCode[TypeFamily.VAR][Operator.NOT_GREATER_EQUAL]			= ByteCodes.NGEV;
		byteCode[TypeFamily.VAR][Operator.NOT_LESS]						= ByteCodes.NLV;
		byteCode[TypeFamily.VAR][Operator.NOT_LESS_EQUAL]				= ByteCodes.NLEV;
		byteCode[TypeFamily.VAR][Operator.NOT_LESS_GREATER]				= ByteCodes.NLGV;
		byteCode[TypeFamily.VAR][Operator.MULTIPLY_ASSIGN]				= ByteCodes.MULV;
		byteCode[TypeFamily.VAR][Operator.DIVIDE_ASSIGN]				= ByteCodes.DIVV;
		byteCode[TypeFamily.VAR][Operator.REMAINDER_ASSIGN]				= ByteCodes.REMV;
		byteCode[TypeFamily.VAR][Operator.ADD_ASSIGN]					= ByteCodes.ADDV;
		byteCode[TypeFamily.VAR][Operator.SUBTRACT_ASSIGN]				= ByteCodes.SUBV;
		byteCode[TypeFamily.VAR][Operator.LEFT_SHIFT_ASSIGN]			= ByteCodes.LSHV;
		byteCode[TypeFamily.VAR][Operator.RIGHT_SHIFT_ASSIGN]			= ByteCodes.RSHV;
		byteCode[TypeFamily.VAR][Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN]	= ByteCodes.URSV;
		byteCode[TypeFamily.VAR][Operator.OR_ASSIGN]					= ByteCodes.ORV;
		byteCode[TypeFamily.VAR][Operator.AND_ASSIGN]					= ByteCodes.ANDV;
		byteCode[TypeFamily.VAR][Operator.EXCLUSIVE_OR_ASSIGN]			= ByteCodes.XORV;

		swapped.resize(Operator.MAX_OPERATOR);
		swapped[Operator.EQUALITY] = Operator.EQUALITY;
		swapped[Operator.GREATER] = Operator.LESS_EQUAL;
		swapped[Operator.GREATER_EQUAL] = Operator.LESS;
		swapped[Operator.LESS] = Operator.GREATER_EQUAL;
		swapped[Operator.LESS_EQUAL] = Operator.GREATER;
		swapped[Operator.LESS_GREATER] = Operator.LESS_GREATER;
		swapped[Operator.LESS_GREATER_EQUAL] = Operator.LESS_GREATER_EQUAL;
		swapped[Operator.NOT_EQUAL] = Operator.NOT_EQUAL;
		swapped[Operator.NOT_GREATER] = Operator.NOT_LESS_EQUAL;
		swapped[Operator.NOT_GREATER_EQUAL] = Operator.NOT_LESS;
		swapped[Operator.NOT_LESS] = Operator.NOT_GREATER_EQUAL;
		swapped[Operator.NOT_LESS_EQUAL] = Operator.NOT_GREATER;
		swapped[Operator.NOT_LESS_GREATER] = Operator.NOT_LESS_GREATER;
		swapped[Operator.NOT_LESS_GREATER_EQUAL] = Operator.NOT_LESS_GREATER_EQUAL;

	}
	// TODO: Fix order of subscripts to match order of declaration
	static ByteCodes[Operator][TypeFamily] byteCode;
	// A table of operator mappings (from an operator to the equivalent with swapped operands)
	static Operator[Operator] swapped;
};

private OpToByteCodeMap opToByteCodeMap;

class ByteCodeMap {
	string[ByteCodes] name;

	ByteCodeMap() {
		name.resize(ByteCodes.MAX_BYTECODE);
		name[ByteCodes.ILLEGAL] = "<invalid byte code>";
		name[ByteCodes.INT] = "int";
		name[ByteCodes.LONG] = "long";
		name[ByteCodes.STRING] = "string";
		name[ByteCodes.CALL] = "call";
		name[ByteCodes.ICALL] = "call.ind";
		name[ByteCodes.VCALL] = "call.virt";
		name[ByteCodes.XCALL] = "call.ext";
		name[ByteCodes.INVOKE] = "invoke";
		name[ByteCodes.CHKSTK] = "chkstk";
		name[ByteCodes.SP] = "push";
		name[ByteCodes.LOCALS] = "locals";
		name[ByteCodes.VARG] = "varg";
		name[ByteCodes.VARG1] = "varg1";
		name[ByteCodes.POP] = "pop";
		name[ByteCodes.POPN] = "pop";
		name[ByteCodes.DUP] = "dup";
		name[ByteCodes.SWAP] = "swap";
		name[ByteCodes.RET] = "ret";
		name[ByteCodes.RET1] = "ret1";
		name[ByteCodes.RETN] = "ret";
		name[ByteCodes.STSA] = "st.addr";
		name[ByteCodes.LDSA] = "ld.addr";
		name[ByteCodes.STSB] = "st.byte";
		name[ByteCodes.LDSB] = "ld.byte";
		name[ByteCodes.STSC] = "st.char";
		name[ByteCodes.LDSC] = "ld.char";
		name[ByteCodes.STSI] = "st.int";
		name[ByteCodes.LDSI] = "ld.int";
		name[ByteCodes.LDSU] = "ld.uns";
		name[ByteCodes.STSS] = "st.shrt";
		name[ByteCodes.LDSS] = "ld.shrt";
		name[ByteCodes.STAA] = "st.addr";
		name[ByteCodes.LDAA] = "ld.addr";
		name[ByteCodes.STAB] = "st.byte";
		name[ByteCodes.STSO] = "st.obj";
		name[ByteCodes.LDAB] = "ld.byte";
		name[ByteCodes.LDAC] = "ld.char";
		name[ByteCodes.STAS] = "st.shrt";
		name[ByteCodes.LDAS] = "ld.shrt";
		name[ByteCodes.STAI] = "st.int";
		name[ByteCodes.LDAI] = "ld.int";
		name[ByteCodes.LDAU] = "ld.uns";
		name[ByteCodes.LDAO] = "ld.obj";
		name[ByteCodes.STAO] = "st.obj";
		name[ByteCodes.STAV] = "st.var";
		name[ByteCodes.STVA] = "st.addr";
		name[ByteCodes.STVB] = "st.byte";
		name[ByteCodes.STVS] = "st.shrt";
		name[ByteCodes.STVI] = "st.int";
		name[ByteCodes.STVO] = "st.obj";
		name[ByteCodes.STVV] = "st.var";
		name[ByteCodes.LDPA] = "ld.addr";
		name[ByteCodes.STPA] = "st.addr";
		name[ByteCodes.LDPB] = "ld.byte";
		name[ByteCodes.STPB] = "st.byte";
		name[ByteCodes.LDPC] = "ld.char";
		name[ByteCodes.STPS] = "st.shrt";
		name[ByteCodes.LDPS] = "ld.shrt";
		name[ByteCodes.LDPI] = "ld.int";
		name[ByteCodes.LDPL] = "ld.long";
		name[ByteCodes.LDPU] = "ld.uns";
		name[ByteCodes.STPI] = "st.int";
		name[ByteCodes.STPL] = "st.int";
		name[ByteCodes.LDPO] = "ld.obj";
		name[ByteCodes.STPO] = "st.obj";
		name[ByteCodes.LDIA] = "ld.addr";
		name[ByteCodes.LDTR] = "ld.class";
		name[ByteCodes.STIA] = "st.addr";
		name[ByteCodes.POPIA] = "st.pop";
		name[ByteCodes.LDIB] = "ld.byte",
		name[ByteCodes.STIB] = "st.byte",
		name[ByteCodes.LDIC] = "ld.char";
		name[ByteCodes.STIC] = "st.char";
		name[ByteCodes.LDII] = "ld.int";
		name[ByteCodes.STII] = "st.int";
		name[ByteCodes.LDIL] = "ld.long";
		name[ByteCodes.STIL] = "st.long";
		name[ByteCodes.LDIU] = "ld.uns";
		name[ByteCodes.LDIO] = "ld.obj";
		name[ByteCodes.STIO] = "st.obj";
		name[ByteCodes.LDIV] = "ld.var";
		name[ByteCodes.STIV] = "st.var";
		name[ByteCodes.THROW] = "throw";
		name[ByteCodes.NEW] = "new";
		name[ByteCodes.DELETE] = "delete";
		name[ByteCodes.ADDR] = "addr";
		name[ByteCodes.AUTO] = "auto";
		name[ByteCodes.AVARG] = "auto";
		name[ByteCodes.ZERO_A] = "zero.addr";
		name[ByteCodes.ZERO_I] = "zero";
		name[ByteCodes.PARAMS] = "parms";
		name[ByteCodes.VALUE] = "value";
		name[ByteCodes.CHAR_AT] = "char.at";
		name[ByteCodes.CLASSV] = "class.var";
		name[ByteCodes.ASTRING] = "addr";
		name[ByteCodes.NEG] = "neg.int";
		name[ByteCodes.BCM] = "bcm.int";
		name[ByteCodes.MUL] = "mul.int";
		name[ByteCodes.DIV] = "div.int";
		name[ByteCodes.REM] = "rem.int";
		name[ByteCodes.ADD] = "add.int";
		name[ByteCodes.SUB] = "sub.int";
		name[ByteCodes.LSH] = "lsh.int";
		name[ByteCodes.RSH] = "rsh.int";
		name[ByteCodes.URS] = "urs.int";
		name[ByteCodes.OR] = "or.int";
		name[ByteCodes.AND] = "and.int";
		name[ByteCodes.XOR] = "xor.int";
		name[ByteCodes.MULV] = "mul.var";
		name[ByteCodes.DIVV] = "div.var";
		name[ByteCodes.REMV] = "rem.var";
		name[ByteCodes.ADDV] = "add.var";
		name[ByteCodes.SUBV] = "sub.var";
		name[ByteCodes.LSHV] = "lsh.var";
		name[ByteCodes.RSHV] = "rsh.var";
		name[ByteCodes.URSV] = "urs.var";
		name[ByteCodes.ORV] = "or.var";
		name[ByteCodes.ANDV] = "and.var";
		name[ByteCodes.XORV] = "xor.var";
		name[ByteCodes.NOT] = "not.int";
		name[ByteCodes.EQI] = "eq.int";
		name[ByteCodes.NEI] = "ne.int";
		name[ByteCodes.GTI] = "gt.int";
		name[ByteCodes.GEI] = "ge.int";
		name[ByteCodes.LTI] = "lt.int";
		name[ByteCodes.LEI] = "le.int";
		name[ByteCodes.EQL] = "eq.long";
		name[ByteCodes.NEL] = "ne.long";
		name[ByteCodes.GTL] = "gt.long";
		name[ByteCodes.GEL] = "ge.long";
		name[ByteCodes.LTL] = "lt.long";
		name[ByteCodes.LEL] = "le.long";
		name[ByteCodes.GTA] = "gt.addr";
		name[ByteCodes.GEA] = "ge.addr";
		name[ByteCodes.LTA] = "lt.addr";
		name[ByteCodes.LEA] = "le.addr";
		name[ByteCodes.GTU] = "gt.uns";
		name[ByteCodes.GEU] = "ge.uns";
		name[ByteCodes.LTU] = "lt.uns";
		name[ByteCodes.LEU] = "le.uns";
		name[ByteCodes.EQV] = "eq.var";
		name[ByteCodes.NEV] = "ne.var";
		name[ByteCodes.GTV] = "gt.var";
		name[ByteCodes.GEV] = "ge.var";
		name[ByteCodes.LTV] = "lt.var";
		name[ByteCodes.LEV] = "le.var";
		name[ByteCodes.LGV] = "lg.var";
		name[ByteCodes.NGV] = "ng.var";
		name[ByteCodes.NGEV] = "nge.var";
		name[ByteCodes.NLV] = "nl.var";
		name[ByteCodes.NLEV] = "nle.var";
		name[ByteCodes.NLGV] = "nlg.var";
		name[ByteCodes.CVTBI] = "cvt.bi";
		name[ByteCodes.CVTCI] = "cvt.usi";
		name[ByteCodes.CVTIL] = "cvt.il";
		name[ByteCodes.CVTUL] = "cvt.ul";
		name[ByteCodes.CVTIV] = "cvt.iv";
		name[ByteCodes.CVTLV] = "cvt.lv";
		name[ByteCodes.CVTSV] = "cvt.sv";
		name[ByteCodes.CVTAV] = "cvt.av";
		name[ByteCodes.CVTVI] = "cvt.vi";
		name[ByteCodes.CVTVS] = "cvt.vs";
		name[ByteCodes.CVTVA] = "cvt.va";
		name[ByteCodes.SWITCHI] = "switch.int";
		name[ByteCodes.SWITCHE] = "switch.enum";
		name[ByteCodes.string] = "[string]";
		name[ByteCodes.JMP] = "jmp";
		name[ByteCodes.JZ] = "jz";
		name[ByteCodes.JNZ] = "jnz";

		string last = "<none>";
		int lastI = -1;
		for (int i = 0; i < int(ByteCodes.MAX_BYTECODE); i++)
			if (name[ByteCodes(i)] == null) {
				printf("ERROR: Byte code %d has no name entry (last defined entry: %s %d)\n", i, last, lastI);
			} else {
				last = name[ByteCodes(i)];
				lastI = i;
			}
	}
}

ByteCodeMap byteCodeMap;

void indentBy(int x) {
	if (x > 0)
		printf("%*c", x, ' ');
}
