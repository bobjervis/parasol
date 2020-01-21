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
namespace parasol:x86_64;

import parasol:compiler.Arena;
import parasol:compiler.ClassScope;
import parasol:compiler.FileStat;
import parasol:compiler.FIRST_USER_METHOD;
import parasol:compiler.OverloadInstance;
import parasol:compiler.ParameterScope;
import parasol:compiler.Scope;
import parasol:compiler.Symbol;
import parasol:compiler.Type;
import parasol:compiler.OrdinalMap;
import parasol:runtime.SourceLocation;
import native:C;

public class Disassembler {
	private ref<Arena> _arena;
	private long _logical;
	private long _ip;
	private pointer<byte> _physical;
	private int _length;
	private int _stringsEndOffset;
	private int _typeDataEndOffset;
	private int _vtablesEndOffset;
	private int _staticDataStart;
	private int _staticDataEnd;
	private pointer<ExceptionEntry> _exceptionsEndOffset;
	private int _imageLength;
	private ref<X86_64SectionHeader> _pxiHeader;
	private int _offset;
	
	// Instruction prefixes.
	private byte _rex;
	private boolean _operandSize;
	private boolean _repne;
	private boolean _repe;
	private int _sourceIndex;
	private int _builtInsFinalOffset;
	private pointer<ref<Symbol>> _dataMap;
	private ref<ref<Scope>[]> _functionMap;
	private int _dataMapLength;
	private pointer<SourceLocation> _sourceLocations;
	private int _sourceLocationsCount;
	private ref<ref<ClassScope>[]> _vtables;
	private ref<OrdinalMap> _ordinalMap;
	
	Disassembler(ref<Arena> arena, long logical, int imageLength, pointer<byte> physical, ref<X86_64SectionHeader> pxiHeader) {
		_arena = arena;
		_logical = logical;
		_imageLength = imageLength;
		_physical = physical;
		_length = pxiHeader.typeDataOffset;
		_pxiHeader = pxiHeader; 
		_builtInsFinalOffset = _pxiHeader.builtInOffset + _pxiHeader.builtInCount * address.bytes; 
		_stringsEndOffset = _pxiHeader.stringsOffset + _pxiHeader.stringsLength;
		_typeDataEndOffset = _pxiHeader.typeDataOffset + _pxiHeader.typeDataLength;
		_vtablesEndOffset = _pxiHeader.vtablesOffset + _pxiHeader.vtableData * address.bytes;
		_exceptionsEndOffset = pointer<ExceptionEntry>(_physical + _pxiHeader.exceptionsOffset + _pxiHeader.exceptionsCount * ExceptionEntry.bytes);
		_ip = _pxiHeader.entryPoint;
		_staticDataStart = _pxiHeader.typeDataOffset + _pxiHeader.typeDataLength;
		_staticDataEnd = _pxiHeader.builtInsText;
	}
	
	void setDataMap(pointer<ref<Symbol>> dataMap, int dataMapLength) {
		_dataMap = dataMap;
		_dataMapLength = dataMapLength;
	}
	
	void setFunctionMap(ref<ref<Scope>[]> functionMap) {
		_functionMap = functionMap;
	}
	
	void setOrdinalMap(ref<OrdinalMap> om) {
		_ordinalMap = om;
	}

	void setSourceLocations(pointer<SourceLocation> sourceLocations, int sourceLocationsCount) {
		_sourceLocations = sourceLocations;
		_sourceLocationsCount = sourceLocationsCount;
	}
	
	void setVtablesClasses(ref<ref<ClassScope>[]> vtables) {
		_vtables = vtables;
	}
	
	public boolean disassemble() {
		printHeader(_pxiHeader, -1);

		if (_pxiHeader.exceptionsCount > 0) {
			printf("\nException Table:\n");
			printf("    Location  Handler\n");
			for (pointer<ExceptionEntry> ee = pointer<ExceptionEntry>(_physical + _pxiHeader.exceptionsOffset); ee < _exceptionsEndOffset; ee++) {
				printf("    %8.8x  %8.8x\n", ee.location, ee.handler);
			}
		}
		if (_pxiHeader.nativeBindingsCount > 0) {
			printf("\n  Native Bindings:\n");
			
			int addr = _pxiHeader.nativeBindingsOffset;
			pointer<NativeBinding> nb = pointer<NativeBinding>(_physical + addr);
			
			for (int i = 0; i < _pxiHeader.nativeBindingsCount; i++, nb++) {
				string d(_physical + int(nb.dllName));
				string s(_physical + int(nb.symbolName));
				printf("    [%8.8x] %20s %s\n", addr, d, s);
				addr += NativeBinding.bytes;
			}
		}
		printf("\n    symbols for      %8x - %8x\n", _staticDataStart, _staticDataEnd);
		for (int i = 0; i < _dataMapLength; i++) {
			string prefix;
			prefix.printf("[%d]", i);
			printf("      %8s %8.8x %s\n", prefix, _dataMap[i].offset, _dataMap[i].name());
		}
		printf("\n    vtables\n");
		pointer<address> vp = pointer<address>(_physical + _pxiHeader.vtablesOffset);
		ref<ClassScope> scope = null;
		int scopeIndex;
		int vtableIndex = 0;
		if (_vtables != null) {
			scope = (*_vtables)[0];
			ref<ref<OverloadInstance>[]> methods = scope.methods();
			int methodIndex = 0;
			for (int i = 0; i < _pxiHeader.vtableData; i++, methodIndex++) {
				int vtableValue = i * address.bytes + 1;
				if (vtableIndex < _vtables.length() && int(scope.vtable) == vtableValue) {
					printf("\n      %s (%p) (pxi %x):\n", scope.classType.signature(), &vp[i], _pxiHeader.vtablesOffset + i * address.bytes);
					vtableIndex++;
					methods = scope.methods();
					scope = (*_vtables)[vtableIndex];
					methodIndex = 0;
				}
				printf("        %2d: %8x", i, vp[i]);
				if (methodIndex >= FIRST_USER_METHOD && methodIndex - FIRST_USER_METHOD < methods.length())
					printf(" %s", (*methods)[methodIndex - FIRST_USER_METHOD].name());
				printf("\n");
			}
		}
/*
		if (_pxiHeader.relocationCount > 0) {
			printf("PXI Fixups:\n");
			pointer<int> f = pointer<int>(_physical + _pxiHeader.relocationOffset);
			for (int i = 0; i < _pxiHeader.relocationCount; i++)
				printf("    [%d] %#x\n", i, f[i]);
		}
 */
		printf("\n");
		_offset = 0;
		_rex = 0;
		_operandSize = false;
		_sourceIndex = 0;
		currentAddress();
		for (;;) {
			byte next = _physical[_offset];
			_offset++;
			boolean done = true;
			switch (next) {
			case	0x00:					// ADD Eb, Gb
			case	0x08:
			case	0x20:
			case	0x28:
			case	0x30:
			case	0x38:
			case	0x88:					// MOV Eb, Gb
				instructionOpcode(next);
				disassembleEbGb();
				break;
				
			case	0x01:
			case	0x09:
			case	0x21:
			case	0x29:
			case	0x31:
			case	0x39:
			case	0x85:
			case	0x87:
			case	0x89:
				instructionOpcode(next);
				disassembleEvGv();
				break;
				
			case	0x02:
			case	0x0a:
			case	0x22:
			case	0x2a:
			case	0x32:
			case	0x3a:
			case	0x8a:
				instructionOpcode(next);
				disassembleGbEb();
				break;
				
			case	0x03:
			case	0x0b:
			case	0x23:
			case	0x2b:
			case	0x33:
			case	0x3b:
			case	0x8b:
			case	0x8d:
				instructionOpcode(next);
				disassembleGvEv(0);
				break;
				
			case	0x63:
				instructionOpcode(next);
				disassembleGvEvWiden(0, false);
				break;
				
			case	0x04:
				instructionOpcode(next);
				printf("al,");
				immediateByte();
				break;
				
			case	0x15:
			case	0x25:
			case	0x35:
				instructionOpcode(next);
				disassemblerAXIz();
				break;
				
			case	0x0f:
				escape0F();
				break;
				
			case	0x40:
			case	0x41:
			case	0x42:
			case	0x43:
			case	0x44:
			case	0x45:
			case	0x46:
			case	0x47:
			case	0x48:
			case	0x49:
			case	0x4a:
			case	0x4b:
			case	0x4c:
			case	0x4d:
			case	0x4e:
			case	0x4f:
				_rex = next;
				done = false;
				break;
				
			case	0x66:
				_operandSize = true;
				done = false;
				break;
				
			case	0x50:
			case	0x51:
			case	0x52:
			case	0x53:
			case	0x54:
			case	0x55:
			case	0x56:
			case	0x57:
			case	0x58:
			case	0x59:
			case	0x5a:
			case	0x5b:
			case	0x5c:
			case	0x5d:
			case	0x5e:
			case	0x5f:
				instructionOpcode(next);
				register64(next & 0x7, false);
				break;
				
			case	0x68:
				instructionOpcode(next);
				immediateWord();
				break;
				
			case	0x69:
				instructionOpcode(next);
				disassembleGvEv(int.bytes);
				printf(",");
				immediateWord();
				break;
				
			case	0x6a:
				instructionOpcode(next);
				immediateByte();
				break;
				
			case	0x70:
			case	0x71:
			case	0x72:
			case	0x73:
			case	0x74:
			case	0x75:
			case	0x76:
			case	0x77:
			case	0x78:
			case	0x79:
			case	0x7a:
			case	0x7b:
			case	0x7c:
			case	0x7d:
			case	0x7e:
			case	0x7f:
				instructionOpcode(next);
				displacement = _physical[_offset];
				_offset++;
				printf("%#x", _logical + _offset + displacement);
				break;
				
			case	0x80:
				byte modRM = _physical[_offset];
				int opcode = (modRM >> 3) & 0x7;
				instructionOpcode(immedGrp1mnemonics[opcode]);
				disassembleEbIb();
				break;
				
			case	0x81:
				modRM = _physical[_offset];
				opcode = (modRM >> 3) & 0x7;
				instructionOpcode(immedGrp1mnemonics[opcode]);
				disassembleEvIz();
				break;
				
			case	0x83:
				modRM = _physical[_offset];
				opcode = (modRM >> 3) & 0x7;
				instructionOpcode(immedGrp1mnemonics[opcode]);
				disassembleEvIb();
				break;
				
			case	0x99:
				if ((_rex & REX_W) != 0)
					instructionOpcode("cdo");
				else if (_operandSize)
					instructionOpcode("cdw");
				else
					instructionOpcode("cdq");
				break;
				
			case	0x2f:
			case	0x37:
			case	0x3f:
			case	0xc3:
			case	0xc9:
				instructionOpcode(next);
				break;
				
			case	0xc6:
				instructionOpcode(next);
				disassembleEbIb();
				break;
				
			case	0xc7:
				instructionOpcode(next);
				disassembleEvIz();
				break;
				
			case	0x6b:
				instructionOpcode(next);
				disassembleGvEv(byte.bytes);
				printf(",");
				immediateByte();
				break;
				
			case	0xb0:
			case	0xb1:
			case	0xb2:
			case	0xb3:
			case	0xb4:
			case	0xb5:
			case	0xb6:
			case	0xb7:
				instructionOpcode(next);
				register8(next - 0xb0, false);
				printf(",");
				immediateByte();
				break;
				
			case	0xb8:
			case	0xb9:
			case	0xba:
			case	0xbb:
			case	0xbc:
			case	0xbd:
			case	0xbe:
			case	0xbf:
				instructionOpcode(next);
				registerWord(next - 0xb8, false);
				printf(",");
				if ((_rex & REX_W) == REX_W)
					immediateLong();
				else
					immediateWord();
				break;
				
			case	0xc2:
				instructionOpcode(next);
				immediateShort();
				break;
				
			case	0xc8:
				instructionOpcode(next);
				int stackSize = _physical[_offset] + (int(_physical[_offset + 1]) << 8);
				_offset += 2;
				int nesting = _physical[_offset];
				_offset++;
				if (nesting == 0)
					printf("%d", stackSize);
				else
					printf("%d,%d", stackSize, nesting);
				break;
				
			case	0xc0:
			case	0xc1:
			case	0xd0:
			case	0xd1:
			case	0xd2:
			case	0xd3:
				group2(next);
				break;
				
			case	0xe1:
				instructionOpcode(next);
				// TODO: restore when byte codes fix this: int displacement = (int(_physical[_offset]) << 24) >> 24;
				int displacement = (int(_physical[_offset]) << 24);
				displacement >>= 24;
				_offset++;
				printf("%#x", _logical + _offset + displacement);
				break;
				
			case	0xe8:
				instructionOpcode(next);
				displacement = *ref<int>(&_physical[_offset]);
				_offset += int.bytes;
				printf("%#x", _logical + _offset + displacement);
				lookupReference(int(_logical + _offset + displacement));
				break;
				
			case	0xe9:
				instructionOpcode(next);
				displacement = *ref<int>(&_physical[_offset]);
				_offset += int.bytes;
				printf("%#x", _logical + _offset + displacement);
				break;
				
			case	0xf2:
				_repne = true;
				done = false;
				break;
				
			case	0xf3:
				_repe = true;
				done = false;
				break;
				
			case	0xf6:
			case	0xf7:
				group3(next);
				break;
				
			case	0xfe:
				group4();
				break;
				
			case	0xff:
				group5();
				break;
				
			default:
				printf("Byte: '%#x'\n", int(next));
				assert(false);
			}
			if (done)
				printf("\n");
			if (_offset >= _length) {
				if (!done)
					printf("\n");
				printf("\n");
				printf("Code loaded at %p\n", _physical);
//				assert(false);
				return done;
			}
			if (done) {
				currentAddress();
				_rex = 0;
				_operandSize = false;
				_repne = false;
				_repe = false;
			}
		}
	}
	
	void escape0F() {
		byte next = _physical[_offset];
		_offset++;
		switch (next) {
		case	0x10:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("movsd");
				disassembleGfEf(true, true);
			} else if (_repe) {
				instructionOpcode("movss");
				disassembleGfEf(false, false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;
			
		case	0x11:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("movsd");
				_rex |= REX_W;
				disassembleEfGf();
			} else if (_repe) {
				instructionOpcode("movss");
				disassembleEfGf();
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;

		case	0x2a:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("cvtsi2sd");
				disassembleGfEv(true);
			} else if (_repe) {
				instructionOpcode("cvtsi2ss");
				disassembleGfEv(false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;

		case	0x2c:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("cvttsd2si");
				disassembleGvEf(true);
			} else if (_repe) {
				instructionOpcode("cvttss2si");
				disassembleGvEf(false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;

		case	0x2d:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("cvtsd2si");
				disassembleGvEf(true);
			} else if (_repe) {
				instructionOpcode("cvtss2si");
				disassembleGvEf(false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;

		case	0x2e:
			if (_operandSize) {
				instructionOpcode("ucomisd");
				disassembleGfEf(true, true);
			} else if (_repne) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else {
				instructionOpcode("ucomiss");
				disassembleGfEf(false, false);
			}
			break;
			
		case	0x57:
			if (_operandSize) {
				instructionOpcode("xorpd");
				disassembleGfEf(true, true);
			} else if (_repne) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else {
				instructionOpcode("xorps");
				disassembleGfEf(false, false);
			}
			break;
			
		case	0x58:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("addsd");
				disassembleGfEf(true, true);
			} else if (_repe) {
				instructionOpcode("addss");
				disassembleGfEf(false, false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;
			
		case	0x59:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("mulsd");
				disassembleGfEf(true, true);
			} else if (_repe) {
				instructionOpcode("mulss");
				disassembleGfEf(false, false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;
			
		case	0x5a:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("cvtsd2ss");
				disassembleGfEf(true, false);
			} else if (_repe) {
				instructionOpcode("cvtss2sd");
				disassembleGfEf(false, true);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;

		case	0x5c:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("subsd");
				disassembleGfEf(true, true);
			} else if (_repe) {
				instructionOpcode("subss");
				disassembleGfEf(false, false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;
			
		case	0x5e:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("divsd");
				disassembleGfEf(true, true);
			} else if (_repe) {
				instructionOpcode("divss");
				disassembleGfEf(false, false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;
			
		case	0x7e:
			instructionOpcode("movq");
			disassembleEfGf();
			break;
			
		case	0x80:
		case	0x81:
		case	0x82:
		case	0x83:
		case	0x84:
		case	0x85:
		case	0x86:
		case	0x87:
		case	0x88:
		case	0x89:
		case	0x8a:
		case	0x8b:
		case	0x8c:
		case	0x8d:
		case	0x8e:
		case	0x8f:
			instructionOpcode(escape0Fmnemonics[next]);
			int displacement = *ref<int>(&_physical[_offset]);
			_offset += int.bytes;
			printf("%#x", _logical + _offset + displacement);
			break;
			
		case	0xaf:
			instructionOpcode("imul");
			disassembleGvEv(0);
			break;
			
		case	0xb6:
			instructionOpcode("movzx");
			disassembleGvEb();
			break;
			
		case	0xbf:
			instructionOpcode("movsx");
			disassembleGvEvWiden(0, true);
			break;
			
		default:
			printf("0x0F escape Byte: '%#x'", int(next));
			if (_operandSize)
				printf(" 0x66 prefix present");
			else if (_repne)
				printf(" 0xf2 prefix present");
			else if (_repe)
				printf(" 0xf3 prefix present");
			printf("\n");
			assert(false);

			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			}
			break;
		}
	}
	
	void currentAddress() {
		long loc = _logical + _offset;
		boolean printedSource;
		while (_sourceIndex < _sourceLocationsCount) {
			if (_sourceLocations[_sourceIndex].offset <= loc) {
				ref<FileStat> file = _sourceLocations[_sourceIndex].file;
				if (!printedSource)
					printf("\n");
				printf("  %s %d\n", file.filename(), file.scanner().lineNumber(_sourceLocations[_sourceIndex].location) + 1);
				if (!printedSource)
					printf("\n");
				printedSource = true;
				_sourceIndex++;
			} else
				break;
		}
		printf("%c%8.8x ", loc == _ip ? '*' : ' ', loc);
	}

	void group2(byte opcode) {
		byte modRM = _physical[_offset];
		int regOpcode = (modRM >> 3) & 0x7;
		instructionOpcode(grp2mnemonics[regOpcode]);
		switch (opcode) {
		case	0xc0:
			disassembleEbIb();
			break;
			
		case	0xc1:
			disassembleEvIb();
			break;
			
		case	0xd0:
		case	0xd1:
			disassembleEv();
			printf(",1");
			break;
			
		case	0xd2:
		case	0xd3:
			disassembleEv();
			printf(",cl");
		}
	}
	
	void group3(byte opcode) {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		instructionOpcode(grp3mnemonics[regOpcode]);
		switch (regOpcode) {
		case	0:		// TEST
			switch (opcode) {
			case	0xf6:
				_offset++;
				effectiveByte(mod, rm, byte.bytes);
				printf(",");
				immediateByte();
				break;
				
			case	0xf7:
				_offset++;
				effectiveWord(false, mod, rm, int.bytes);
				printf(",");
				immediateWord();
			}
			break;

		case	1:
			break;
			
		case	2:
		case	3:
			switch (opcode) {
			case	0xf6:
				_offset++;
				effectiveByte(mod, rm, 0);
				break;
				
			case	0xf7:
				_offset++;
				effectiveWord(false, mod, rm, 0);
			}
			break;
			
		case	4:
		case	5:
		case	6:
		case	7:
			switch (opcode) {
			case	0xf6:
				_offset++;
				effectiveByte(mod, rm, 0);
				break;
				
			case	0xf7:
				_offset++;
				effectiveWord(false, mod, rm, 0);
			}
		}
	}
	
	void group4() {
		byte modRM = _physical[_offset];
		_offset++;
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		switch (regOpcode) {
		case	0:
			instructionOpcode("inc");
			effectiveByte(mod, rm, 0);
			break;
			
		case	1:
			instructionOpcode("dec");
			effectiveByte(mod, rm, 0);
			break;
			
		case	2:
			instructionOpcode("<illegal opcode FF /2>");
			break;
			
		case	6:
			instructionOpcode("<illegal opcode FF /6>");
			break;
			
		case	7:
			instructionOpcode("<illegal opcode FF /7>");
			break;
			
		default:
			printf("opcode=%d mod=%d rm=%d\n", regOpcode, mod, rm);
			assert(false);
		}
	}
	
	void group5() {
		byte modRM = _physical[_offset];
		_offset++;
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		switch (regOpcode) {
		case	0:
			instructionOpcode("inc");
			effectiveWord(false, mod, rm, 0);
			break;
			
		case	1:
			instructionOpcode("dec");
			effectiveWord(false, mod, rm, 0);
			break;
			
		case	2:
			instructionOpcode("call");
			_rex |= REX_W;
			effectiveWord(false, mod, rm, 0);
			break;
			
		case	6:
			instructionOpcode("push");
			_rex |= REX_W;
			effectiveWord(false, mod, rm, 0);
			break;

		case	7:
			instructionOpcode("<illegal opcode FF /7>");
			break;
			
		default:
			printf("opcode=%d mod=%d rm=%d\n", regOpcode, mod, rm);
			assert(false);
		}
	}
	/*
	 * Effective Address (byte size), General register (byte)
	 */
	void disassembleEbGb() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		effectiveByte(mod, rm, 0);
		printf(",%s", byteRegs[regOpcode]);
	}
	/*
	 * Effective Address (dword size), XMM floating register ()
	 */
	void disassembleEfGf() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		effectiveWord(true, mod, rm, 0);
		if ((_rex & REX_W) != 0)
			printf(",%s", doubleRegs[regOpcode]);
		else
			printf(",%s", floatRegs[regOpcode]);
	}
	/*
	 * Effective Address (dword size), XMM floating register ()
	 */
	void disassembleGfEf(boolean doublePrecisionSrc, boolean doublePrecisionDest) {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		if (doublePrecisionDest)
			printf("%s,", doubleRegs[regOpcode]);
		else
			printf("%s,", floatRegs[regOpcode]);
		if (doublePrecisionSrc)
			_rex |= REX_W;
		effectiveWord(true, mod, rm, 0);
	}
	/*
	 * Effective Address (dword size), XMM floating register ()
	 */
	void disassembleGfEv(boolean doublePrecision) {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		if (doublePrecision)
			printf("%s,", doubleRegs[regOpcode]);
		else
			printf("%s,", floatRegs[regOpcode]);
		effectiveWord(false, mod, rm, 0);
	}
	/*
	 * General register (byte), Effective Address (byte size) 
	 */
	void disassembleGbEb() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		register8(regOpcode, true);
		printf(",");
		effectiveByte(mod, rm, 0);
	}
	/*
	 * General register (byte), Effective Address (byte size) 
	 */
	void disassembleGvEb() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		registerWord(regOpcode, true);
		printf(",");
		effectiveByte(mod, rm, 0);
	}
	/*
	 * General register (word size), effective Address (word size)
	 */
	void disassembleGvEv(int ipAdjust) {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		registerWord(regOpcode, true);
		printf(",");
		effectiveWord(false, mod, rm, ipAdjust);
	}
	/*
	 * General register (word size), effective Floating-point Address (word size)
	 */
	void disassembleGvEf(boolean doublePrecision) {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		registerWord(regOpcode, true);
		printf(",");
		if (doublePrecision)
			_rex |= REX_W;
		effectiveWord(true, mod, rm, 0);
	}

	void disassembleGvEvWiden(int ipAdjust, boolean operandSize) {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		registerWord(regOpcode, true);
		printf(",");
		_rex &= ~REX_W;
		_operandSize = operandSize;
		effectiveWord(false, mod, rm, ipAdjust);
	}
	/*
	 * Effective Address (word size), general register (word size)
	 */
	void disassembleEvGv() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		effectiveWord(false, mod, rm, 0);
		printf(",");
		registerWord(regOpcode, true);
	}
	/*
	 * Effective Address (byte size), immediate byte
	 */
	void disassembleEbIb() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		effectiveByte(mod, rm, byte.bytes);
		printf(",");
		immediateByte();
	}
	/*
	 * Effective Address (word size), immediate byte
	 */
	void disassembleEvIb() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		effectiveWord(false, mod, rm, byte.bytes);
		printf(",");
		immediateByte();
	}
	
	void disassembleEv() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		effectiveWord(false, mod, rm, byte.bytes);
	}
	
	void disassemblerAXIz() {
		if ((_rex & REX_W) != 0)
			printf("rax,");
		else
			printf("eax,");
		immediateWord();
	}

	/*
	 * Effective Address (word size), immediate byte
	 */
	void disassembleEvIz() {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		effectiveWord(false, mod, rm, int.bytes);
		printf(",");
		immediateWord();
	}
	
	void immediateByte() {
		int immed = int(_physical[_offset]) << 24 >> 24;
		printf("%d (%x)", immed, immed);
		_offset++;
	}

	void immediateShort() {
		int immed = *ref<char>(&_physical[_offset]);
		_offset += char.bytes;
		printf("%d (%x)", immed, immed);
	}
	
	void immediateWord() {
		int immed;
		if (_operandSize) {
			immed = *ref<char>(&_physical[_offset]);
			_offset += char.bytes;
		} else {
			immed = *ref<int>(&_physical[_offset]);
			_offset += int.bytes;
		}
		printf("%d (%x)", immed, immed);
	}
	
	void immediateLong() {
		long immed = *ref<long>(&_physical[_offset]);
		printf("%d (%x)", immed, immed);
		_offset += long.bytes;
	}
	
	void registerWord(int reg, boolean useREX_R) {
		if ((_rex & REX_W) == REX_W)
			register64(reg, useREX_R);
		else if (_operandSize)
			register16(reg, useREX_R);
		else
			register32(reg, useREX_R);
	}
	
	void register64(int reg, boolean useREX_R) {
		if (useREX_R) {
			if ((_rex & REX_R) == REX_R)
				reg += 8;
		} else {
			if ((_rex & REX_B) == REX_B)
				reg += 8;
		}
		printf("%s", longRegs[reg]);
	}
	
	void register32(int reg, boolean useREX_R) {
		if (useREX_R) {
			if ((_rex & REX_R) == REX_R)
				reg += 8;
		} else {
			if ((_rex & REX_B) == REX_B)
				reg += 8;
		}
		printf("%s", intRegs[reg]);
	}
	
	void register16(int reg, boolean useREX_R) {
		if (useREX_R) {
			if ((_rex & REX_R) == REX_R)
				reg += 8;
		} else {
			if ((_rex & REX_B) == REX_B)
				reg += 8;
		}
		printf("%s", shortRegs[reg]);
	}
	
	void register8(int reg, boolean useREX_R) {
		if (useREX_R) {
			if ((_rex & REX_R) == REX_R)
				reg += 8;
		} else {
			if ((_rex & REX_B) == REX_B)
				reg += 8;
		}
		printf("%s", byteRegs[reg]);
	}
	
	void register64f(int reg) {
		if ((_rex & REX_R) == REX_R)
			reg += 8;
		printf("%s", doubleRegs[reg]);
	}
	
	void register32f(int reg) {
		if ((_rex & REX_R) == REX_R)
			reg += 8;
		printf("%s", floatRegs[reg]);
	}
	
	void effectiveByte(int mod, int rm, int ipAdjust) {
		switch (mod) {
		case	0:
			switch (rm) {
			case	0:
			case	1:
			case	2:
			case	3:
			case	6:
			case	7:
				printf("byte ptr [%s]", longRegs[rm]);
				break;
				
			case	5:
				int displacement = *ref<int>(&_physical[_offset]);
				_offset += int.bytes;
				int location = int(_logical + _offset + ipAdjust + displacement);
				printf("byte ptr [%#x]", location);
				lookupReference(location);
				break;
				
			case	4:
				// sib
				int sib = _physical[_offset];
				_offset++;
				int base = sib & 7;
				int index = (sib >> 3) & 7;
				int logScale = (sib >> 6) & 3;
				int scale = 1 << logScale;			// 0 -> 1, 1 -> 2, etc
				switch (base) {
				case	0:
				case	1:
				case	2:
				case	3:
				case	4:
				case	6:
				case	7:
					if (scale > 1)
						printf("byte ptr [%s+%s*%d]", longRegs[base], longRegs[index], scale);
					else
						printf("byte ptr [%s+%s]", longRegs[base], longRegs[index]);
					break;
					
				default:
					printf("base=%d\n", base);
					assert(false);
				}
				break;
				
			default:
				printf("rm=%d\n", rm);
				assert(false);
			}
			break;
			
		case	1:
			switch (rm) {
			case	0:
			case	1:
			case	2:
			case	3:
			case	5:
			case	6:
			case	7:
				printf("byte ptr [%s%+d]", longRegs[rm], (long(_physical[_offset]) << 56) >> 56);
				break;
				
			case	4:
				// sib
				int sib = _physical[_offset];
				_offset++;
				int base = sib & 7;
				int index = (sib >> 3) & 7;
				int logScale = (sib >> 6) & 3;
				int scale = 1 << logScale;			// 0 -> 1, 1 -> 2, etc
				switch (base) {
				case	0:
				case	1:
				case	2:
				case	3:
				case	4:
				case	6:
				case	7:
					if (scale > 1)
						printf("byte ptr [%s+%s*%d%+d]", longRegs[base], longRegs[index], scale, (long(_physical[_offset]) << 56) >> 56);
					else
						printf("byte ptr [%s+%s%+d]", longRegs[base], longRegs[index], (long(_physical[_offset]) << 56) >> 56);
					break;
					
				default:
					printf("base=%d\n", base);
					assert(false);
				}
				break;
				
			default:
				printf("rm=%d\n", rm);
				assert(false);
			}
			_offset++;
			break;
				
		case	2:
			switch (rm) {
			case	0:
			case	1:
			case	3:
			case	5:
			case	6:
			case	7:
				printf("byte ptr [%s%+d]", longRegs[rm], (long(*ref<int>(&_physical[_offset])) << 32) >> 32);
				break;
				
			default:
				printf("rm=%d\n", rm);
				assert(false);
			}
			_offset += int.bytes;
			break;
			
		case	3:
			register8(rm, false);
			break;
			
		default:
			printf("mod=%d\n", mod);
			assert(false);
		}
	}

	void effectiveWord(boolean isFloat, int mod, int rm, int ipAdjust) {
		if (mod == 3) {
			if (isFloat) {
				if ((_rex & REX_W) == REX_W)
					register64f(rm);
				else
					register32f(rm);
			} else if ((_rex & REX_W) == REX_W)
				register64(rm, false);
			else if (_operandSize)
				register16(rm, false);
			else
				register32(rm, false);
			return;
		}
		if ((_rex & REX_W) == REX_W)
			printf("qword ptr [");
		else if (_operandSize)
			printf("word ptr [");
		else
			printf("dword ptr [");
		
		int base, index, scale, displacement;
		
		if (rm == 4) {
			// sib
			int sib = _physical[_offset];
			_offset++;
			base = sib & 7;
			if ((_rex & REX_B) == REX_B)
				base += 8;
			index = (sib >> 3) & 7;
			if ((_rex & REX_X) == REX_X)
				index += 8;
			int logScale = (sib >> 6) & 3;
			scale = 1 << logScale;			// 0 -> 1, 1 -> 2, etc
			if (index == 4)
				scale = 0;
			if (base == 5)
				base = -1;
		} else if (mod == 0 && rm == 5) {
			int displacement = *ref<int>(&_physical[_offset]);
			_offset += int.bytes;
			int location = int(_logical + _offset + ipAdjust + displacement);
			printf("%#x]", location);
			lookupReference(location);
			return;
		} else
			base = rm;
		
		if (base >= 0) {
			printf("%s", longRegs[base]);
			if (scale != 0)
				printf("+");
		}
		switch (scale) {
		case	0:
			break;

		case	1:
			printf("%s", longRegs[index]);
			break;
			
		default:
			printf("%s*%d", longRegs[index], scale);
		}
		
		switch (mod) {
		case	0:
			printf("]");
			return;
			
		case	1:
			displacement = int((long(_physical[_offset]) << 56) >> 56);
			_offset++;
			break;

		case	2:
			displacement = int((long(*ref<int>(&_physical[_offset])) << 32) >> 32);
			_offset += int.bytes;
			break;
		}
		printf("%+d]", displacement);
	}

	void lookupReference(int location) {
		if (location < _pxiHeader.typeDataOffset) {
			int index = findFunction(location);
			if (index >= 0) {
				ref<Scope> scope = (*_functionMap)[index];
				if (scope.class == ParameterScope) {
					ref<ParameterScope> funcScope = ref<ParameterScope>(scope);
					printf(" %s", funcScope.label());
					if (int(funcScope.value) <= location)
						printf("+%d", location - (int(funcScope.value) - 1));
				}
			}
		} else if (location >= _pxiHeader.builtInOffset && location < _builtInsFinalOffset) {
			printf(" &%s", builtInAt((location - _pxiHeader.builtInOffset) / address.bytes));
		} else if (location >= _pxiHeader.stringsOffset && location < _stringsEndOffset) {
			address x = &_physical[int(location - _logical)];
			pointer<string> ps = pointer<string>(&x);		// We want to make sure we don't call a destructor here
			printf(" '%s'", *ps);
		} else if (location >= _pxiHeader.typeDataOffset && location < _typeDataEndOffset) {
			int ordinal = location - _pxiHeader.typeDataOffset;
			if (_ordinalMap != null) {
				ref<Type> t = _ordinalMap.get(ordinal);
				if (t != null) {
					printf(" [%s (ordinal %x)]", t.signature(), ordinal);
					return;
				}
			}
			printf(" [ordinal %x]", ordinal);
		} else if (location >= _pxiHeader.vtablesOffset && location < _vtablesEndOffset) {
			printf(" [vtable %x]", (location - _pxiHeader.vtablesOffset) / address.bytes);
		} else if (location >= _staticDataStart && location < _staticDataEnd) {
			// It's somewhere in static data.
			int index = findSymbol(location);
			if (index >= 0) {
				printf(" %s", _dataMap[index].name());
				if (_dataMap[index].offset < location)
					printf("+%d", location - _dataMap[index].offset);
			}
		}
	}

	int findFunction(int location) {
		if (_functionMap == null)
			return -1;
		pointer<ref<Scope>> functionMap = &(*_functionMap)[0];
		int length = _functionMap.length();
		int base = 0;
		if (length <= 0)
			return -1;
		for (;;) {
			if (length == 1)
				return base;
			
			// Compute a 'middle' that guarantees that there is one more element past the middle.
			
			int middle = (length - 1) / 2;

//			printf(" checking %s %x", dataMap[middle].name().asString(), dataMap[middle].offset);

			// If the target location is somewhere above the last of the middle's data, look in the upper half
			
			if (functionAddress(functionMap[middle + 1]) <= location) {
				middle++;
				base += middle;
				length -= middle;
				functionMap += middle;
				
			// If the target location is somewhere below the middle symbol, look in the lower half
				
			} else if (functionAddress(functionMap[middle]) > location)
				length = middle;
			else
				return base + middle;
		}
	}
	
	private int functionAddress(ref<Scope> scope) {
		int result = scope.functionAddress();
		
		if (result < 0)
			return _pxiHeader.entryPoint;
		else
			return result;
	}
	
	int findSymbol(int location) {
		pointer<ref<Symbol>> dataMap = _dataMap;
		int length = _dataMapLength;
		int base = 0;
		if (length <= 0)
			return -1;
		for (;;) {
			if (length == 1)
				return base;
			
			// Compute a 'middle' that guarantees that there is one more element past the middle.
			
			int middle = (length - 1) / 2;

//			printf(" checking %s %x", dataMap[middle].name().asString(), dataMap[middle].offset);

			// If the target location is somewhere above the last of the middle's data, look in the upper half
			
			if (dataMap[middle + 1].offset <= location) {
				middle++;
				base += middle;
				length -= middle;
				dataMap += middle;
				
			// If the target location is somewhere below the middle symbol, look in the lower half
				
			} else if (dataMap[middle].offset > location)
				length = middle;
			else
				return base + middle;
		}
	}

	string builtInAt(int index) {
		pointer<byte> pb = _physical + _pxiHeader.builtInsText;
		for (int i = 0; i < index; i++) {
			pb += C.strlen(pb) + 1;
		}
		string s(pb);
		return s;
	}

	private void instructionOpcode(byte op) {
		instructionOpcode(instructionMnemonic[op]);
	}

	private void instructionOpcode(string op) {
		printf(" %-5s ", op); 
//		printf("%#2.2x ", int(_physical[_offset - 1]));
	}
}

private string[] instructionMnemonic;
instructionMnemonic.resize(256);

for (int i = 0; i < 6; i++) {
	instructionMnemonic[i] = "add";
	instructionMnemonic[i + 0x08] = "or";
	instructionMnemonic[i + 0x10] = "adc";
	instructionMnemonic[i + 0x18] = "sbb";
	instructionMnemonic[i + 0x20] = "and";
	instructionMnemonic[i + 0x28] = "sub";
	instructionMnemonic[i + 0x30] = "xor";
	instructionMnemonic[i + 0x38] = "cmp";
}
for (int i = 0x50; i < 0x58; i++)
	instructionMnemonic[i] = "push";
for (int i = 0x58; i < 0x60; i++)
	instructionMnemonic[i] = "pop";
for (int i = 0x88; i < 0x8d; i++)
	instructionMnemonic[i] = "mov";

for (int i = 0xb0; i < 0xc0; i++)
	instructionMnemonic[i] = "mov";

instructionMnemonic[0x2f] = "-";
instructionMnemonic[0x37] = "-";
instructionMnemonic[0x3f] = "-";


instructionMnemonic[0x63] = "movsxd";
instructionMnemonic[0x68] = "push";
instructionMnemonic[0x69] = "imul";
instructionMnemonic[0x6a] = "push";
instructionMnemonic[0x6b] = "imul";
instructionMnemonic[0x70] = "jo";
instructionMnemonic[0x71] = "jno";
instructionMnemonic[0x72] = "jb";
instructionMnemonic[0x73] = "jnb";
instructionMnemonic[0x74] = "je";
instructionMnemonic[0x75] = "jne";
instructionMnemonic[0x76] = "jna";
instructionMnemonic[0x77] = "ja";
instructionMnemonic[0x78] = "js";
instructionMnemonic[0x79] = "jns";
instructionMnemonic[0x7a] = "jpe";
instructionMnemonic[0x7b] = "jpo";
instructionMnemonic[0x7c] = "jl";
instructionMnemonic[0x7d] = "jge";
instructionMnemonic[0x7e] = "jle";
instructionMnemonic[0x7f] = "jg";
instructionMnemonic[0x85] = "test";
instructionMnemonic[0x87] = "xchg";

instructionMnemonic[0x8d] = "lea";

instructionMnemonic[0xc2] = "retn";
instructionMnemonic[0xc3] = "retn";
instructionMnemonic[0xc6] = "mov";
instructionMnemonic[0xc7] = "mov";
instructionMnemonic[0xc8] = "enter";
instructionMnemonic[0xc9] = "leave";
instructionMnemonic[0xe1] = "loopz";
instructionMnemonic[0xe8] = "call";
instructionMnemonic[0xe9] = "jmp";

private string[] immedGrp1mnemonics = [
	"add",
	"or",
	"adc",
	"sbb",
	"and",
	"sub",
	"xor",
	"cmp"
];

private string[] grp2mnemonics = [
	"rol",
	"ror",
	"rcl",
	"rcr",
	"sal",
	"shr",
	"<bad>",
	"sar"
];

private string[] grp3mnemonics = [
	"test",
	"<bad>",
	"not",
	"neg",
	"mul",
	"imul",
	"div",
	"idiv"
];

private string[] byteRegs = [
	"al",
	"cl",
	"dl",
	"bl",
	"ah",
	"ch",
	"dh",
	"bh",
	"r8l",
	"r9l",
	"r10l",
	"r11l",
	"r12l",
	"r13l",
	"r14l",
	"r15l",
	"",		// xmm0
	"",		// xmm1
	"",		// xmm2
	"",		// xmm3
	"",		// xmm4
	"",		// xmm5
	"",		// xmm6
	"",		// xmm7
	"ah"
];

private string[] shortRegs = [
	"ax",
	"cx",
	"dx",
	"bx",
	"sp",
	"bp",
	"si",
	"di",
	"r8w",
	"r9w",
	"r10w",
	"r11w",
	"r12w",
	"r13w",
	"r14w",
	"r15w",
];

private string[] intRegs = [
	"eax",
	"ecx",
	"edx",
	"ebx",
	"esp",
	"ebp",
	"esi",
	"edi",
	"r8d",
	"r9d",
	"r10d",
	"r11d",
	"r12d",
	"r13d",
	"r14d",
	"r15d",
];

private string[] longRegs = [
	"rax",
	"rcx",
	"rdx",
	"rbx",
	"rsp",
	"rbp",
	"rsi",
	"rdi",
	"r8",
	"r9",
	"r10",
	"r11",
	"r12",
	"r13",
	"r14",
	"r15",
];

private string[] floatRegs = [
	"mm0",
	"mm1",
	"mm2",
	"mm3",
	"mm4",
	"mm5",
	"mm6",
	"mm7",
];

private string[] doubleRegs = [
	"xmm0",
	"xmm1",
	"xmm2",
	"xmm3",
	"xmm4",
	"xmm5",
	"xmm6",
	"xmm7",
];

private string[] fixupTypes = [
	"<error>",
	"relative32",
	"absolute64",
	"absolute64-code",
];

private string[] escape0Fmnemonics;

escape0Fmnemonics.resize(256);
escape0Fmnemonics[0x80] = "jo";
escape0Fmnemonics[0x81] = "jno";
escape0Fmnemonics[0x82] = "jb";
escape0Fmnemonics[0x83] = "jnb";
escape0Fmnemonics[0x84] = "je";
escape0Fmnemonics[0x85] = "jne";
escape0Fmnemonics[0x86] = "jna";
escape0Fmnemonics[0x87] = "ja";
escape0Fmnemonics[0x88] = "js";
escape0Fmnemonics[0x89] = "jns";
escape0Fmnemonics[0x8a] = "jpe";
escape0Fmnemonics[0x8b] = "jpo";
escape0Fmnemonics[0x8c] = "jl";
escape0Fmnemonics[0x8d] = "jge";
escape0Fmnemonics[0x8e] = "jle";
escape0Fmnemonics[0x8f] = "jg";

public void printHeader(ref<X86_64SectionHeader> header, long fileOffset) {
	printf("\n");
	if (fileOffset >= 0)
		printf("        image offset         %8x\n", fileOffset);
	printf("        entryPoint           %8x\n", header.entryPoint);
	printf("        builtInOffset        %8x", header.builtInOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.builtInOffset + fileOffset);
	printf("\n");
	printf("        builtInCount         %8d.\n", header.builtInCount);
	printf("        vtablesOffset        %8x", header.vtablesOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.vtablesOffset + fileOffset);
	printf("\n");
	printf("        vtableData           %8x\n", header.vtableData);
	printf("        typeDataOffset       %8x", header.typeDataOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.typeDataOffset + fileOffset);
	printf("\n");
	printf("        typeDataLength       %8x\n", header.typeDataLength);
	printf("        stringsOffset        %8x", header.stringsOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.stringsOffset + fileOffset);
	printf("\n");
	printf("        stringsLength        %8x\n", header.stringsLength);
	printf("        nativeBindingsOffset %8x", header.nativeBindingsOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.nativeBindingsOffset + fileOffset);
	printf("\n");
	printf("        nativeBindingsCount  %8d.\n", header.nativeBindingsCount);
	printf("        relocationOffset     %8x", header.relocationOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.relocationOffset + fileOffset);
	printf("\n");
	printf("        relocationCount      %8d.\n", header.relocationCount);
	printf("        builtInsText         %8x", header.builtInsText);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.builtInsText + fileOffset);
	printf("\n");
	printf("        exceptionsOffset     %8x", header.exceptionsOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.exceptionsOffset + fileOffset);
	printf("\n");
	printf("        exceptionsCount      %8d.\n", header.exceptionsCount);
}
/**
 * This is a bug: There should not be duplicate functions in a single scope.
 * TODO: Fix this
 */
public void printHeader(ref<X86_64SectionHeader> header, long fileOffset) {
	printf("\n");
	if (fileOffset >= 0)
		printf("        image offset         %8x\n", fileOffset);
	printf("        entryPoint           %8x\n", header.entryPoint);
	printf("        builtInOffset        %8x", header.builtInOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.builtInOffset + fileOffset);
	printf("\n");
	printf("        builtInCount         %8d.\n", header.builtInCount);
	printf("        vtablesOffset        %8x", header.vtablesOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.vtablesOffset + fileOffset);
	printf("\n");
	printf("        vtableData           %8x\n", header.vtableData);
	printf("        typeDataOffset       %8x", header.typeDataOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.typeDataOffset + fileOffset);
	printf("\n");
	printf("        typeDataLength       %8x\n", header.typeDataLength);
	printf("        stringsOffset        %8x", header.stringsOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.stringsOffset + fileOffset);
	printf("\n");
	printf("        stringsLength        %8x\n", header.stringsLength);
	printf("        relocationOffset     %8x", header.relocationOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.relocationOffset + fileOffset);
	printf("\n");
	printf("        relocationCount      %8d.\n", header.relocationCount);
	printf("        builtInsText         %8x", header.builtInsText);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.builtInsText + fileOffset);
	printf("\n");
	printf("        exceptionsOffset     %8x", header.exceptionsOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.exceptionsOffset + fileOffset);
	printf("\n");
}
