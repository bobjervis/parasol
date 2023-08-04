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
import parasol:pxi.Pxi;
import parasol:runtime;
import parasol:memory;
import parasol:text;
import parasol:x86_64.X86_64Lnx;
import parasol:x86_64.X86_64Win;

import native:C;

public class CodegenContext {
	private boolean _verbose;
	private memory.StartingHeap _startingHeap;
	private string _profilePath;
	private string _coveragePath;

	CodegenContext(boolean verbose, memory.StartingHeap startingHeap, string profilePath, string coveragePath) {
		_verbose = verbose;
		_startingHeap = startingHeap;
		_profilePath = profilePath;
		_coveragePath = coveragePath;
	}

	public boolean verbose() {
		return _verbose;
	}

	public memory.StartingHeap startingHeap() {
		return _startingHeap;
	}

	string profilePath() {
		return _profilePath;
	}

	string coveragePath() {
		return _coveragePath;
	}
}

/**
 * Class target defines the framework for Parasol compiler code generators.
 * 
 * The intention is that targets can be used both in environments where the generated code
 * can be immediately executed as well as in environments where they cannot.  THis allows
 * a single Parasol compiler to be used as a cross-compiler to other environments.
 */
public class Target {
	protected ref<Arena> _arena;

//	private ref<Type> _builtInType;
//	private ref<Type> _classType;
	
	private ref<Unit>[] _staticBlocks;
	private ref<ParameterScope>[runtime.TypeFamily] _marshallerFunctions;
	private ref<ParameterScope>[runtime.TypeFamily] _unmarshallerFunctions;
	
	private boolean _verbose;

	public Target() {
		_marshallerFunctions.resize(runtime.TypeFamily.MAX_TYPES);
		_unmarshallerFunctions.resize(runtime.TypeFamily.MAX_TYPES);
	}

	public static ref<Target> generate(ref<Unit> mainFile, ref<CompileContext> compileContext) {
		ref<Target> target;
		
		// Magic: select target
		runtime.Target selectedTarget;
		if (compileContext.arena().preferredTarget != null)
			selectedTarget = compileContext.arena().preferredTarget;
		else
			selectedTarget = runtime.Target(runtime.supportedTarget(0));
		if (compileContext.verbose())
			printf("Targeting %s\n", string(selectedTarget));
		switch (selectedTarget) {
		case	X86_64_LNX:
		case	X86_64_LNX_SRC:
			target = new X86_64Lnx(compileContext.arena());
			break;

		case	X86_64_WIN:
			target = new X86_64Win(compileContext.arena());
			break;
		}
		target._verbose = compileContext.verbose();
//		target.populateTypeMap(compileContext);
		compileContext.target = target;
		if (target.generateCode(mainFile, compileContext))
			return target;
		else
			return null;
	}
	
	public abstract boolean generateCode(ref<Unit> mainFile, ref<CompileContext> compileContext);

	public abstract int copyClassToImage(ref<Type> type, 
										 int baseOrdinal,
										 runtime.TypeFamily family);

//	public abstract int copyInterfaceToImage(ref<Type> type, ref<runtime.Interface> template);

	public void fixupType(int ordinal, ref<Type> type) {
		assert(false);
	}
	
	public void fixupVtable(int ordinal, ref<Type> type) {
		assert(false);
	}
	
	public void markRegisterParameters(ref<ParameterScope> scope, ref<CompileContext> compileContext) {
	}
	
	public byte registerValue(int registerArgumentIndex, runtime.TypeFamily family) {
		return 0;
	}
	/**
	 * hiddenParams: Either 0, 1 or 2 depending on the presence of 'this' and/or an out parameter
	 */
	public void assignRegisterArguments(int hiddenParams, pointer<ref<Type>> parameters, int parameterCount, 
										pointer<byte> registerArray, ref<CompileContext> compileContext) {
	}
	
	public abstract void assignStorageToObject(ref<Symbol> symbol, ref<Scope> scope, int offset, ref<CompileContext> compileContext);

	public void declareStaticBlock(ref<Unit> file) {
		_staticBlocks.append(file);
	}

	public ref<ref<Unit>[]> staticBlocks() {
		return &_staticBlocks;
	}

	public boolean verbose() {
		return _verbose;
	}
	/*
	 * 'Run' the target by executing it's static block and main methods.
	 */
	public abstract int, boolean run(string[] args);

	public abstract void writePxi(ref<Pxi> output);

	public abstract runtime.Target sectionType();
	
	/*
	 * Write a disassembly of the target to the console.
	 */
	public boolean disassemble(ref<Arena> arena) {
		return false;
	}
	
	public void gatherCases(ref<Node> n, ref<GatherCasesClosure> closure) {
		n.traverse(Node.Traversal.REVERSE_PRE_ORDER, gatherCasesFunc, closure);
	}
	
	public ref<ParameterScope> generateEnumToStringMethod(ref<EnumInstanceType> type, ref<CompileContext> compileContext) {
		return null;
	}
	
	public ref<ParameterScope> generateEnumFromStringMethod(ref<EnumInstanceType> type, ref<CompileContext> compileContext) {
		return null;
	}
	
	public ref<ParameterScope> generateFlagsToStringMethod(ref<FlagsInstanceType> type, ref<CompileContext> compileContext) {
		return null;
	}
	
	public void unfinished(ref<Node> n, string explanation, ref<CompileContext> compileContext) {
		n.add(MessageId.UNFINISHED_GENERATE, compileContext.pool(), " "/*n.class.name()*/, string(n.op()), explanation);
	}

	public void print() {
	}

	public ref<ParameterScope> marshaller(ref<Type> type, ref<CompileContext> compileContext) {
		ref<ParameterScope> s = _marshallerFunctions[type.family()];
		if (s == null) {
			string name = type.family().marshaller();
			if (name == null) {
				printf("no marshaller for %s\n", type.signature());
				return null;
			}
			ref<Symbol> sym = compileContext.forest().getSymbol("parasol", name, compileContext);
			if (sym == null)
				printf("Could not find parasol:%s\n", name);
			if (sym.class != Overload) {
				printf("marshaller for %s not an overloaded symbol\n", name);
				return null;
			}
			ref<Overload> o = ref<Overload>(sym);
			ref<Type> tp = (*o.instances())[0].assignType(compileContext);
			if (tp.deferAnalysis()) {
				printf("marshaller %s not well-formed\n", name);
				return null;
			}
			s = ref<ParameterScope>(tp.scope());
			_marshallerFunctions[type.family()] = s;
		}
		return s;
	}

	public ref<ParameterScope> unmarshaller(ref<Type> type, ref<CompileContext> compileContext) {
		ref<ParameterScope> s = _unmarshallerFunctions[type.family()];
		if (s == null) {
			string name = type.family().unmarshaller();
			if (name == null) {
				printf("no unmarshaller for %s\n", type.signature());
				return null;
			}
			ref<Symbol> sym = compileContext.forest().getSymbol("parasol", name, compileContext);
			if (sym == null)
				printf("Could not find parasol:%s\n", name);
			if (sym.class != Overload) {
				printf("marshaller for %s not an overloaded symbol\n", name);
				return null;
			}
			ref<Overload> o = ref<Overload>(sym);
			ref<Type> tp = (*o.instances())[0].assignType(compileContext);
			if (tp.deferAnalysis()) {
				printf("marshaller %s not well-formed\n", name);
				return null;
			}
			s = ref<ParameterScope>(tp.scope());
			_unmarshallerFunctions[type.family()] = s;
		}
		return s;
	}
}

public class GatherCasesClosure {
	public ref<Node>[] nodes;
	public ref<Target> target;
}

private TraverseAction gatherCasesFunc(ref<Node> n, address data) {
	ref<GatherCasesClosure> closure;
	switch (n.op()) {
	case	SWITCH:
		return TraverseAction.SKIP_CHILDREN;

	case	CASE:
		closure = ref<GatherCasesClosure>(data);
		closure.nodes.append(n);
		return TraverseAction.CONTINUE_TRAVERSAL;

	default:
		return TraverseAction.CONTINUE_TRAVERSAL;
	}
	return TraverseAction.CONTINUE_TRAVERSAL;
}

public class Variable {
	public ref<Scope> enclosing;			// 
	public ref<Type> type;					// If not null, the 'type' of the variable
	public pointer<ref<Type>> returns;		// If not null, the returns list from the function type this represents
	public int returnCount;					// The count of type in the returns list.
	public int offset;
	
	public int stackSize() {
		int sz;
		if (returns != null) {
			for (int i = 0; i < returnCount; i++)
				sz += returns[i].stackSize();
		} else if (type != null)
			sz = type.stackSize();
		return sz;
	}
	
	public void print() {
		if (returns != null) {
			printf("Variable V%p ", this);
			for (int i = 0; i < returnCount; i++) {
				printf("%s", returns[i].signature());
				if (i < returnCount - 1)
					printf(", ");
			}
			printf(" [%d]\n", stackSize());
		} else if (type != null)
			printf("Variable V%p %s [%d]\n", this, type.signature(), stackSize());
		else
			printf("Variable V%p no type [%d]\n", this, stackSize());
	}
}

public class Segment {
	byte[]	_content;
	Fixup[]	_fixups;
	int _alignment;
	int _offset;							// Offset of this Segment in the final image (only valid after linking).
	byte _fill;
	
	Segment(int alignment, byte fill) {
		_alignment = alignment;
		_fill = fill;
	}
	
	Segment(int alignment) {
		_alignment = alignment;
	}
	
	Segment() {
		
	}
	/**
	 * Create a fixup from a location in this segment to another location.
	 *
	 * A fixup is a reference in one part of the compiled image that refers
	 * to a location elsewhere in the image.
	 * At the time the reference is generated, the location that will 
	 * eventually referred to is only known relative to it's segment.
	 *
	 * Absolute references are 8 byte pointer values. Since an image is restricted
	 * to 2 GB in size, only the low-order 4 bytes of the address are manipulated
	 * In the generated image. The loader must add the base address of the image to
	 * each fixup (which will have to set a value for the entire 8-byte pointer.
	 *
	 * A relative reference is an address mode in a machine instruction in
	 * the CODE segment of the image, and so may not be aligned. The code here
	 * does rely on the compiler running on a system that supports misaligned
	 * integer accesses.
	 *
	 * @param location The location in this segment to be fixed up.
	 * @param segment The identity of the target segment of the fixup
	 * location.
	 * @param absolute If true, the 
	 */
	public void fixup(int location, byte segment, boolean absolute) {
		Fixup f;
		
		f.location = location;
		f.segment = segment;
		f.absolute = absolute;
		_fixups.append(f);
	}
	
	public int absoluteFixups() {
		int result = 0;
		for (int i = 0;  i < _fixups.length(); i++)
			if (_fixups[i].absolute)
				result++;
		return result;
	}
	
	public void resolveFixups(ref<Target> target, pointer<ref<Segment>> segments) {
		for (int i = 0; i < _fixups.length(); i++) {
			ref<Fixup> f = &_fixups[i];
			pointer<int> fixupTarget = pointer<int>(at(f.location));
			*fixupTarget += segments[f.segment].offset();
			if (!f.absolute)
				*fixupTarget -= _offset + f.location + int.bytes;
		}
	}
	/**
	 * Get a pointer to a byte in this segment.
	 * This arises when the code generator needs to write some
	 * data into the segment.
	 *
	 * The lifetime of the returned pointer is until the next 
	 * call to {@link reserve} or {@link align}.
	 *
	 * @param location The segment-relative location of the byte.
	 *
	 * @return A pointer to the indicated byte.
 	 */
	public pointer<byte> at(int location) {
		return &_content[location];
	}
	/**
	 * Reserve sufficient number of bytes to make the length
	 * of the segment a multiple of the alignment value set in
	 * the constructor.
	 *
	 * If the block needs to be aligned, fill with the fill byte.
	 *
	 * @return The new length of the segment.
	 */
	public int align() {
		return reserve(0);
	}
	/**
	 * Reserve a specific amount of memory in the segment, properly
	 * aligned.
	 * If the block needs to be aligned, fill with the fill byte.
	 *
	 * @param memory The amount of memory to reserve (after aligning the
	 * length of the segment).
	 *
	 * @return The offset of the newly reserved memory block.
	 */
	public int reserve(int memory) {
		return reserve(memory, _alignment);
	}
	/*
	 * Reserve memory, using a specific alignment.
	 * If the block needs to be aligned, fill with the fill byte.
	 * 
	 * @param alignment Must be a power of two.
	 */
	public int reserve(int memory, int alignment) {
		int len = _content.length();
		int partial = len & (alignment - 1);
		if (partial != 0) {
			if (_fill != 0) {
				for (int i = partial; i < alignment; i++)
					_content.append(_fill);
			} else
				_content.resize(len + alignment - partial);
		}
		int value = _content.length();
		_content.resize(value + memory);
		return value;
	}
	/**
	 * Append a properly aligned block of data values to the segment.
	 *
	 * First, a properly aligned memory block of the specified length
	 * is allocated.
	 * If the block needs to be aligned, fill with the fill byte.
	 *
	 * Second, The passed data is copied to the newly allocated block.
	 *
	 * @param data The address of the data to be copied.
	 * @param length The amount of data to be copied.
	 *
	 * @return The offset in the segment where the data was copied.
	 */
	public int append(address data, int length) {
		int location = reserve(length);
		C.memcpy(&_content[location], data, length);
		return location;
	}
	
	public int alignment() {
		return _alignment;
	}
	/*
	 * Given the initial offset offered, the next properly aligned address is picked for the segment and then
	 * the function returns the properly aligned size of the segment.
	 */
	public int link(int offset) {
		_offset = (offset + _alignment - 1) & ~(_alignment - 1);
		return _offset + align();
	}
	
	public int offset() {
		return _offset;
	}
	
	public int length() {
		return _content.length();
	}
	
	public ref<byte[]> content() {
		return &_content;
	}
}
/*
 * Note that the memory at the location is an 8-byte address, containing a 32-bit offset into the referenced segment OR
 * a 4-byte offset, containing a 32-offset into the referenced segment.
 */
public class Fixup {
	public byte segment;						// The Segment of the object being referenced.
	public int location;					// The location within the host Segment of the fixup.
	public boolean absolute;				// If true, this is an absolute, 64-bit reference;
											//     if false, a relative, 32-bit reference.
}
/**
 * The compiler builds template objects in the compiler.Type objects for each class that needs one.
 * When these objects are copied into the image, this map let's the compiler obtain the Type object
 * for a known template.
 */
public class OrdinalMap {
	map<ref<Type>, int> _map;

	public void set(int ordinal, ref<Type> t) {
		_map[ordinal] = t;
	}

	public ref<Type> get(int ordinal) {
		return _map[ordinal];
	}
}
