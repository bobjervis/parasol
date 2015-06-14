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

import parasol:compiler.Arena;
import parasol:compiler.ClasslikeScope;
import parasol:compiler.FileStat;
import parasol:compiler.Scope;
import parasol:compiler.Symbol;

class Disassembler {
	private ref<Arena> _arena;
	private long _logical;
	private long _ip;
	private pointer<byte> _physical;
	private int _length;
	private int _stringsEndOffset;
	private int _typeDataEndOffset;
	private int _vtablesEndOffset;
	private int _imageLength;
	private ref<X86_64SectionHeader> _pxiHeader;
	private ref<int[]> _pxiFixups;
	private ref<Fixup> _fixups;
	private int _offset;
	
	// Instruction prefixes.
	private byte _rex;
	private boolean _operandSize;
	private boolean _repne;
	private boolean _repe;
	private int _sourceIndex;
	private int _builtInsFinalOffset;
	private pointer<ref<Symbol>> _dataMap;
	private int _dataMapLength;
	private pointer<SourceLocation> _sourceLocations;
	private int _sourceLocationsCount;
	
	Disassembler(ref<Arena> arena, long logical, int imageLength, pointer<byte> physical, ref<X86_64SectionHeader> pxiHeader) {
		_arena = arena;
		_logical = logical;
		_imageLength = imageLength;
		_physical = physical;
		_length = pxiHeader.builtInOffset;
		_pxiHeader = pxiHeader; 
		_builtInsFinalOffset = _pxiHeader.builtInOffset + _pxiHeader.builtInCount * address.bytes; 
		_stringsEndOffset = _pxiHeader.stringsOffset + _pxiHeader.stringsLength;
		_typeDataEndOffset = _pxiHeader.typeDataOffset + _pxiHeader.typeDataLength;
		_vtablesEndOffset = _pxiHeader.vtablesOffset + _pxiHeader.vtableData * address.bytes;
		_ip = _pxiHeader.entryPoint;
	}
	
	void setFixups(ref<int[]> pxiFixups) {
		_pxiFixups = pxiFixups;
	}
	
	void setFixups(ref<Fixup> fixups) {
		_fixups = fixups;
	}
	
	void setDataMap(pointer<ref<Symbol>> dataMap, int dataMapLength) {
		_dataMap = dataMap;
		_dataMapLength = dataMapLength;
	}
	
	void setSourceLocations(pointer<SourceLocation> sourceLocations, int sourceLocationsCount) {
		_sourceLocations = sourceLocations;
		_sourceLocationsCount = sourceLocationsCount;
	}
	
	boolean disassemble() {
		printHeader(_pxiHeader, -1);

		printf("    symbols for      %8x - %8x\n", _length, _imageLength);
		
		pointer<address> vp = pointer<address>(_physical + _pxiHeader.vtablesOffset);
		ref<ClasslikeScope> scope;
		int scopeIndex;
		(scope, scopeIndex) = nextVtable(0);
		for (int i = 0; i < _pxiHeader.vtableData; i++) {
			if (scope != null && i == int(scope.vtable) - 1) {
				printf("\n        %p:\n\n", scope);
				(scope, scopeIndex) = nextVtable(scopeIndex + 1);
			}
			printf("        %2d: %8x\n", i, vp[i]);
		}
		if (_pxiFixups.length() > 0) {
			printf("PXI Fixups:\n");
			for (int i = 0; i < _pxiFixups.length(); i++)
				printf("    [%d] %#x\n", i, (*_pxiFixups)[i]);
		}
/*
		if (_fixups != null) {
			printf("Fixups:\n");
			for (ref<Fixup> f = _fixups; f != null; f = f.next) {
				printf("    ");
				f.print();
			}
		}
*/		
		if (_pxiHeader.builtInCount > 0) {
			printf("\n  Built-in method references:\n");
			pointer<byte> pb = _physical + _pxiHeader.builtInsText;
			
			int addr = _pxiHeader.builtInOffset;
			for (int i = 0; i < _pxiHeader.builtInCount; i++) {
				pointer<int> pi = pointer<int>(_physical + addr);
				string s(pb);
				pb += s.length() + 1;
				printf("    [%8.8x] %d \"%s\"\n", addr, *pi, s);
				addr += address.bytes;
			}
		}
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
				disassembleGvEvWiden(0);
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
			case	0xd1:
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
				disassembleGfEf(true);
			} else if (_repe) {
				instructionOpcode("movss");
				disassembleGfEf(false);
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
			
		case	0x2e:
			if (_operandSize) {
				instructionOpcode("ucomisd");
				disassembleGfEf(true);
			} else if (_repne) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else {
				instructionOpcode("ucomiss");
				disassembleGfEf(false);
			}
			break;
			
		case	0x57:
			if (_operandSize) {
				instructionOpcode("xorpd");
				disassembleGfEf(true);
			} else if (_repne) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else {
				instructionOpcode("xorps");
				disassembleGfEf(false);
			}
			break;
			
		case	0x58:
			if (_operandSize) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
			} else if (_repne) {
				instructionOpcode("addsd");
				disassembleGfEf(true);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
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
				disassembleGfEf(true);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
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
				disassembleGfEf(true);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
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
				disassembleGfEf(true);
			} else if (_repe) {
				printf("0x0F escape Byte: '%#x'\n", int(next));
				assert(false);
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
			disassembleGvEv(0);
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
			
		case	0xd1:
			disassembleEv();
			printf(",1");
			break;
			
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
	void disassembleGfEf(boolean doublePrecision) {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		if (doublePrecision)
			printf("%s,", doubleRegs[regOpcode]);
		else
			printf("%s,", floatRegs[regOpcode]);
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

	void disassembleGvEvWiden(int ipAdjust) {
		byte modRM = _physical[_offset];
		int mod = modRM >> 6;
		int regOpcode = (modRM >> 3) & 0x7;
		int rm = modRM & 7;
		_offset++;
		registerWord(regOpcode, true);
		printf(",");
		_rex &= ~REX_W;
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

	ref<Scope>, int nextVtable(int index) {
		while (index < _arena.scopes().length()) {
			ref<Scope> scope = _arena.scopes()[index];
			if (scope.hasVtable())
				return scope, index;
			index++;
		}
		return null, int.MAX_VALUE;
	}
	
	void lookupReference(int location) {
		if (location >= _pxiHeader.builtInOffset && location < _builtInsFinalOffset) {
			printf(" &%s", builtInAt((location - _pxiHeader.builtInOffset) / address.bytes));
		} else if (location >= _pxiHeader.stringsOffset && location < _stringsEndOffset) {
			address x = &_physical[int(location - _logical)];
			pointer<string> ps = pointer<string>(&x);		// We want to make sure we don't call a destructor here
			printf(" '%s'", *ps);
		} else if (location >= _pxiHeader.typeDataOffset && location < _typeDataEndOffset) {
			printf(" [ordinal %x]", location - _pxiHeader.typeDataOffset);
		} else if (location >= _pxiHeader.vtablesOffset && location < _vtablesEndOffset) {
			printf(" [vtable %x]", (location - _pxiHeader.vtablesOffset) / address.bytes);
		} else if (location >= _length && location < _imageLength) {
			// It's somewhere in static data.
			int index = findSymbol(location);
			if (index >= 0) {
				printf(" %s", _dataMap[index].name().asString());
				if (_dataMap[index].offset < location)
					printf("+%d", location - _dataMap[index].offset);
			}
		}
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
			pb += strlen(pb) + 1;
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

instructionMnemonic[0x2f] = "-";
instructionMnemonic[0x37] = "-";
instructionMnemonic[0x3f] = "-";

for (int i = 0x50; i < 0x58; i++)
	instructionMnemonic[i] = "push";
for (int i = 0x58; i < 0x60; i++)
	instructionMnemonic[i] = "pop";

instructionMnemonic[0x63] = "movsxd";
instructionMnemonic[0x69] = "imul";
instructionMnemonic[0x6a] = "imul";
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

for (int i = 0x88; i < 0x8d; i++)
	instructionMnemonic[i] = "mov";

instructionMnemonic[0x8d] = "lea";

for (int i = 0xb0; i < 0xc0; i++)
	instructionMnemonic[i] = "mov";

instructionMnemonic[0xc2] = "retn";
instructionMnemonic[0xc3] = "retn";
instructionMnemonic[0xc6] = "mov";
instructionMnemonic[0xc7] = "mov";
instructionMnemonic[0xc8] = "enter";
instructionMnemonic[0xc9] = "leave";
instructionMnemonic[0xe1] = "loopz";
instructionMnemonic[0xe8] = "call";
instructionMnemonic[0xe9] = "jmp";

private string[] immedGrp1mnemonics;
immedGrp1mnemonics.resize(8);

immedGrp1mnemonics[0] = "add";
immedGrp1mnemonics[1] = "or";
immedGrp1mnemonics[2] = "adc";
immedGrp1mnemonics[3] = "sbb";
immedGrp1mnemonics[4] = "and";
immedGrp1mnemonics[5] = "sub";
immedGrp1mnemonics[6] = "xor";
immedGrp1mnemonics[7] = "cmp";

private string[] grp2mnemonics;
grp2mnemonics.resize(8);

grp2mnemonics[0] = "rol";
grp2mnemonics[1] = "ror";
grp2mnemonics[2] = "rcl";
grp2mnemonics[3] = "rcr";
grp2mnemonics[4] = "sal";
grp2mnemonics[5] = "shr";
grp2mnemonics[6] = "<bad>";
grp2mnemonics[7] = "sar";

private string[] grp3mnemonics;
grp3mnemonics.resize(8);

grp3mnemonics[0] = "test";
grp3mnemonics[1] = "<bad>";
grp3mnemonics[2] = "not";
grp3mnemonics[3] = "neg";
grp3mnemonics[4] = "mul";
grp3mnemonics[5] = "imul";
grp3mnemonics[6] = "div";
grp3mnemonics[7] = "idiv";

private string[] byteRegs;
byteRegs.append("al");
byteRegs.append("cl");
byteRegs.append("dl");
byteRegs.append("bl");
byteRegs.append("ah");
byteRegs.append("ch");
byteRegs.append("dh");
byteRegs.append("bh");
byteRegs.append("r8l");
byteRegs.append("r9l");
byteRegs.append("r10l");
byteRegs.append("r11l");
byteRegs.append("r12l");
byteRegs.append("r13l");
byteRegs.append("r14l");
byteRegs.append("r15l");
byteRegs.append("");		// xmm0
byteRegs.append("");		// xmm1
byteRegs.append("");		// xmm2
byteRegs.append("");		// xmm3
byteRegs.append("");		// xmm4
byteRegs.append("");		// xmm5
byteRegs.append("");		// xmm6
byteRegs.append("");		// xmm7
byteRegs.append("ah");

private string[] shortRegs;
shortRegs.append("ax");
shortRegs.append("cx");
shortRegs.append("dx");
shortRegs.append("bx");
shortRegs.append("sp");
shortRegs.append("bp");
shortRegs.append("si");
shortRegs.append("di");
shortRegs.append("r8w");
shortRegs.append("r9w");
shortRegs.append("r10w");
shortRegs.append("r11w");
shortRegs.append("r12w");
shortRegs.append("r13w");
shortRegs.append("r14w");
shortRegs.append("r15w");

private string[] intRegs;
intRegs.append("eax");
intRegs.append("ecx");
intRegs.append("edx");
intRegs.append("ebx");
intRegs.append("esp");
intRegs.append("ebp");
intRegs.append("esi");
intRegs.append("edi");
intRegs.append("r8d");
intRegs.append("r9d");
intRegs.append("r10d");
intRegs.append("r11d");
intRegs.append("r12d");
intRegs.append("r13d");
intRegs.append("r14d");
intRegs.append("r15d");

private string[] longRegs;
longRegs.append("rax");
longRegs.append("rcx");
longRegs.append("rdx");
longRegs.append("rbx");
longRegs.append("rsp");
longRegs.append("rbp");
longRegs.append("rsi");
longRegs.append("rdi");
longRegs.append("r8");
longRegs.append("r9");
longRegs.append("r10");
longRegs.append("r11");
longRegs.append("r12");
longRegs.append("r13");
longRegs.append("r14");
longRegs.append("r15");

private string[] floatRegs;
floatRegs.append("mm0");
floatRegs.append("mm1");
floatRegs.append("mm2");
floatRegs.append("mm3");
floatRegs.append("mm4");
floatRegs.append("mm5");
floatRegs.append("mm6");
floatRegs.append("mm7");

private string[] doubleRegs;
doubleRegs.append("xmm0");
doubleRegs.append("xmm1");
doubleRegs.append("xmm2");
doubleRegs.append("xmm3");
doubleRegs.append("xmm4");
doubleRegs.append("xmm5");
doubleRegs.append("xmm6");
doubleRegs.append("xmm7");

private string[] fixupTypes;
fixupTypes.append("<error>");
fixupTypes.append("relative32");
fixupTypes.append("absolute64");
fixupTypes.append("absolute64-code");

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
		printf("        image offset     %8x\n", fileOffset);
	printf("        entryPoint       %8x\n", header.entryPoint);
	printf("        builtInOffset    %8x", header.builtInOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.builtInOffset + fileOffset);
	printf("\n");
	printf("        builtInCount     %8d.\n", header.builtInCount);
	printf("        vtablesOffset    %8x", header.vtablesOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.vtablesOffset + fileOffset);
	printf("\n");
	printf("        vtableData       %8x\n", header.vtableData);
	printf("        typeDataOffset   %8x", header.typeDataOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.typeDataOffset + fileOffset);
	printf("\n");
	printf("        typeDataLength   %8x\n", header.typeDataLength);
	printf("        stringsOffset    %8x", header.stringsOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.stringsOffset + fileOffset);
	printf("\n");
	printf("        stringsLength    %8x\n", header.stringsLength);
	printf("        relocationOffset %8x", header.relocationOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.relocationOffset + fileOffset);
	printf("\n");
	printf("        relocationCount  %8x\n", header.relocationCount);
	printf("        builtInsText     %8x", header.builtInsText);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.builtInsText + fileOffset);
	printf("\n");
	printf("        exceptionsOffset %8x", header.exceptionsOffset);
	if (fileOffset >= 0)
		printf(" (file offset %x)", header.exceptionsOffset + fileOffset);
	printf("\n");
	printf("        exceptionsCount  %8d.\n", header.exceptionsCount);
}
