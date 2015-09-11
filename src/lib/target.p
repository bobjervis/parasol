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

import parasol:byteCodes.ByteCodesTarget;
import parasol:x86_64.X86_64;
import parasol:pxi.Pxi;
import parasol:pxi.SectionType;
import parasol:pxi.sectionTypeNames;
import parasol:runtime;
/**
 * Class target defines the framework for Parasol compiler code generators.
 * 
 * The intention is that targets can be used both in environments where the generated code
 * can be immediately executed as well as in environments where they cannot.  THis allows
 * a single Parasol compiler to be used as a cross-compiler to other environments.
 */
public class Target {
	private ref<FileStat>[] _staticBlocks;
	
	public static ref<Target> generate(ref<Arena> arena, ref<FileStat> mainFile, boolean countCurrentObjects, ref<CompileContext> compileContext, boolean verbose) {
		ref<Target> target;
		
		// Magic: select target
		SectionType selectedTarget;
		if (arena.preferredTarget != null)
			selectedTarget = arena.preferredTarget;
		else
			selectedTarget = SectionType(runtime.supportedTarget(0));
//		selectedTarget = SectionType.BYTE_CODES;
		if (verbose)
			printf("Targeting %s\n", sectionTypeNames[selectedTarget]);
		switch (selectedTarget) {
		case	BYTE_CODES:
			target = new ByteCodesTarget(arena);
			break;
			
		case	X86_64:
			target = new X86_64(arena, verbose);
			break;
		}
		if (verbose)
			printf("target=%p\n", target);
		compileContext.target = target;
		if (target.generateCode(mainFile, countCurrentObjects ? runtime.injectObjects(null, 0) : 0, compileContext))
			return target;
		else
			return null;
	}
	
	public abstract boolean generateCode(ref<FileStat> mainFile, int valueOffset, ref<CompileContext> compileContext);

	public address, int allocateImageData(int size, int alignment) {
		printf("allocateImageData(%d, %d)\n", size, alignment);
		assert(false);
		return null, 0;
	}

	public void markRegisterParameters(ref<ParameterScope> scope, ref<CompileContext> compileContext) {
	}
	
	public byte registerValue(int registerArgumentIndex, TypeFamily family) {
		return 0;
	}
	
	public abstract void assignStorageToObject(ref<Symbol> symbol, ref<Scope> scope, int offset, ref<CompileContext> compileContext);

	public void declareStaticBlock(ref<FileStat> file) {
		_staticBlocks.append(file);
	}

	public ref<FileStat>[] staticBlocks() {
		return _staticBlocks;
	}

	public boolean verbose() {
		return false;
	}
	/*
	 * 'Run' the target by executing it's static block and main methods.
	 */
	public abstract int, boolean run(string[] args);

	public abstract void writePxi(ref<Pxi> output);
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
	
	public void unfinished(ref<Node> n, string explanation, ref<CompileContext> compileContext) {
		n.add(MessageId.UNFINISHED_GENERATE, compileContext.pool(), CompileString(" "/*n.class.name()*/), CompileString(operatorMap.name[n.op()]), CompileString(explanation));
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

class Variable {
	ref<Type>	type;				// If not null, the 'type' of the variable
	ref<NodeList> returns;			// If not null, the returns list from the function type this represents
	int			offset;
}
