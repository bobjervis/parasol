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

import parasol:x86_64.X86_64Lnx;
import parasol:x86_64.X86_64Win;
import parasol:pxi.Pxi;
import parasol:pxi.SectionType;
import parasol:runtime;

/**
 * Class target defines the framework for Parasol compiler code generators.
 * 
 * The intention is that targets can be used both in environments where the generated code
 * can be immediately executed as well as in environments where they cannot.  THis allows
 * a single Parasol compiler to be used as a cross-compiler to other environments.
 */
public class Target {
	protected ref<Arena> _arena;

	private ref<Type> _builtInType;
	private ref<Type> _classType;
	
	private ref<FileStat>[] _staticBlocks;
	
	public static ref<Target> generate(ref<Arena> arena, ref<FileStat> mainFile, boolean countCurrentObjects, ref<CompileContext> compileContext, boolean verbose) {
		ref<Target> target;
		
		// Magic: select target
		SectionType selectedTarget;
		if (arena.preferredTarget != null)
			selectedTarget = arena.preferredTarget;
		else
			selectedTarget = SectionType(runtime.supportedTarget(0));
		if (verbose)
			printf("Targeting %s\n", string(selectedTarget));
		switch (selectedTarget) {
		case	X86_64_LNX:
			target = new X86_64Lnx(arena, verbose);
			break;

		case	X86_64_WIN:
			target = new X86_64Win(arena, verbose);
			break;
		}
		target.populateTypeMap(compileContext);
		compileContext.target = target;
		if (target.generateCode(mainFile, countCurrentObjects ? runtime.injectObjects(null, 0) : 0, compileContext))
			return target;
		else
			return null;
	}
	
	private void populateTypeMap(ref<CompileContext> compileContext) {
		ref<Symbol> re = _arena.getSymbol("parasol", "compiler.BuiltInType", compileContext);
		if (re.type().family() != TypeFamily.TYPEDEF)
			assert(false);
		ref<TypedefType> t = ref<TypedefType>(re.type());
		_builtInType = t.wrappedType();
		
		re = _arena.getSymbol("parasol", "compiler.ClassType", compileContext);
		if (re.type().family() != TypeFamily.TYPEDEF)
			assert(false);
		t = ref<TypedefType>(re.type());
		_classType = t.wrappedType();
	}
	
	public abstract boolean generateCode(ref<FileStat> mainFile, int valueOffset, ref<CompileContext> compileContext);

	public address, int allocateImageData(int size, int alignment) {
		printf("allocateImageData(%d, %d)\n", size, alignment);
		assert(false);
		return null, 0;
	}

	public void fixupType(int ordinal, ref<Type> type) {
		assert(false);
	}
	
	public void fixupVtable(int ordinal, ref<Type> type) {
		assert(false);
	}
	
	public void definePxiFixup(int location) {
		assert(false);
	}
	
	public void markRegisterParameters(ref<ParameterScope> scope, ref<CompileContext> compileContext) {
	}
	
	public byte registerValue(int registerArgumentIndex, TypeFamily family) {
		return 0;
	}
	/**
	 * hiddenParams: Either 0, 1 or 2 depending on the presence of 'this' and/or an out parameter
	 */
	public void assignRegisterArguments(int hiddenParams, ref<NodeList> params, ref<CompileContext> compileContext) {
	}
	
	public abstract void assignStorageToObject(ref<Symbol> symbol, ref<Scope> scope, int offset, ref<CompileContext> compileContext);

	public void declareStaticBlock(ref<FileStat> file) {
		_staticBlocks.append(file);
	}

	public ref<ref<FileStat>[]> staticBlocks() {
		return &_staticBlocks;
	}

	public boolean verbose() {
		return false;
	}
	/*
	 * 'Run' the target by executing it's static block and main methods.
	 */
	public abstract int, boolean run(string[] args);

	public abstract void writePxi(ref<Pxi> output);

	public abstract SectionType sectionType();
	
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
	
	public ref<ParameterScope> generateFlagsToStringMethod(ref<FlagsInstanceType> type, ref<CompileContext> compileContext) {
		return null;
	}
	
	public void unfinished(ref<Node> n, string explanation, ref<CompileContext> compileContext) {
		n.add(MessageId.UNFINISHED_GENERATE, compileContext.pool(), CompileString(" "/*n.class.name()*/), CompileString(string(n.op())), CompileString(explanation));
	}
	
	public ref<Type> builtInType() {
		return _builtInType;
	}
	
	public ref<Type> classType() {
		return _classType;
	}
	
	public void print() {
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
	public ref<Scope> 	enclosing;			// 
	public ref<Type>	type;				// If not null, the 'type' of the variable
	public ref<NodeList> returns;			// If not null, the returns list from the function type this represents
	public int			offset;
}

public class Segment<class T> {
	byte[]	_content;
	Fixup<T>[]	_fixups;
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

	public void fixup(T segment, int location, boolean absolute) {
		Fixup<T> f;
		
		f.segment = segment;
		f.location = location;
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
	
	public void resolveFixups(ref<Target> target, ref<ref<Segment<T>>[T]> segments) {
		for (int i = 0; i < _fixups.length(); i++) {
			ref<Fixup<T>> f = &_fixups[i];
			pointer<int> fixupTarget = pointer<int>(at(f.location));
			*fixupTarget += (*segments)[f.segment].offset();
			if (f.absolute)
				target.definePxiFixup(_offset + f.location);
			else
				*fixupTarget -= _offset + f.location + int.bytes;
		}
	}
	
	public pointer<byte> at(int location) {
		return &_content[location];
	}
	
	public int reserve(int memory) {
		return reserve(memory, _alignment);
	}
	/*
	 * Reserve memory, using a specific alignment. If the block needs to be aligned, fill with the fill byte.
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
	
	public int alignment() {
		return _alignment;
	}
	/*
	 * Given the initial offset offered, the next properly aligned address is picked for the segment and then
	 * the function returns the properly aligned size of the segment.
	 */
	public int link(int offset) {
		_offset = (offset + _alignment - 1) & ~(_alignment - 1);
		return _offset + reserve(0);
	}
	
	public int offset() {
		return _offset;
	}
	
	public ref<byte[]> content() {
		return &_content;
	}
}
/*
 * Note that the memory at the location is an 8-byte address, containing a 32-bit offset into the referenced segment OR
 * a 4-byte offset, containing a 32-offset into the referenced segment.
 */
public class Fixup<class T> {
	public T segment;						// The Segment of the object being referenced.
	public int location;					// The location within the host Segment of the fixup.
	public boolean absolute;				// If true, this is an absolute, 64-bit reference;
											//     if false, a relative, 32-bit reference.
}
