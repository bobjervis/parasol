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
/*
 * This file defines the target methods that assign register remporaries to specific
 * parse nodes.
 * 
 * This code is called after Address-modes and Sethi-Ullman numbers have been assigned to
 * the parse tree.
 */
import parasol:compiler.Binary;
import parasol:compiler.Call;
import parasol:compiler.CallCategory;
import parasol:compiler.CompileContext;
import parasol:compiler.EllipsisArguments;
import parasol:compiler.FunctionDeclaration;
import parasol:compiler.FunctionType;
import parasol:compiler.Node;
import parasol:compiler.NodeList;
import parasol:compiler.Operator;
import parasol:compiler.OverloadInstance;
import parasol:compiler.PUSH_OUT_PARAMETER;
import parasol:compiler.Return;
import parasol:compiler.Scope;
import parasol:compiler.Selection;
import parasol:compiler.StorageClass;
import parasol:compiler.Symbol;
import parasol:compiler.Ternary;
import parasol:compiler.Type;
import parasol:compiler.TypedefType;
import parasol:compiler.TypeFamily;
import parasol:compiler.Unary;

class X86_64AssignTemps extends X86_64AddressModes {
	void assignVoidContext(ref<Node> node, ref<CompileContext> compileContext) {
		if	(node.deferGeneration())
			return;
//		printf("AssignVoidContext:\n");
//		node.print(4);
//		printf(">>\n");
		int depth = tempStackDepth();
		switch (node.op()) {
		case	FOR:
		case	EMPTY:
			return;
			
		case	CALL:
			assignRegisterTemp(node, longMask(), compileContext);
			f().r.cleanupTemps(node, depth);
			break;
			
		case	INITIALIZE:
			b = ref<Binary>(node);
			assignRegisterTemp(b.right(), requiredMask(b), compileContext);
			assignLvalueTemps(b.left(), compileContext);
			break;
			
		case	SEQUENCE:
		case	LOGICAL_OR:
		case	LOGICAL_AND:
			b = ref<Binary>(node);
			assignVoidContext(b.left(), compileContext);
			assignVoidContext(b.right(), compileContext);
			node.register = byte(int(R.NO_REG));
			break;

		case	SWITCH:
			b = ref<Binary>(node);
			assignRegisterTemp(b.left(), longMask(), compileContext);		// Take the result in any register available.
			if (b.left().type.family() == TypeFamily.ENUM) {
				int i = int(f().r.getreg(node, longMask(), longMask()));
				node.register = byte(i);
			}
			break;
			
		case	EMPTY:
		case	TRUE:
			break;
			
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
		case	NOT_LESS_GREATER_EQUAL:
			b = ref<Binary>(node);
			b.register = byte(int(R.NO_REG));
			if	(b.sethi < 0) {
				assignRegisterTemp(b.left(), requiredMask(b.left()), compileContext);
				assignRegisterTemp(b.right(), requiredMask(b.right()), compileContext);
			} else {
				assignRegisterTemp(b.right(), requiredMask(b.right()), compileContext);
				assignRegisterTemp(b.left(), requiredMask(b.left()), compileContext);
			}
			break;

		case	MULTIPLY_ASSIGN:
			ref<Binary> b = ref<Binary>(node);
			if	(b.sethi < 0) {
				assignLvalueTemps(b.left(), compileContext);
				assignRegisterTemp(b.right(), requiredMask(node) & ~RAXmask, compileContext);
			} else {
				assignRegisterTemp(b.right(), requiredMask(node) & ~RAXmask, compileContext);
				assignLvalueTemps(b.left(), compileContext);
			}
			f().r.getreg(b, RAXmask, RAXmask);
			break;

		case	INCREMENT_BEFORE:
		case	DECREMENT_BEFORE:
			ref<Unary> u = ref<Unary>(node);
			assignLvalueTemps(u.operand(), compileContext);
			break;
			
		case	CLASS_COPY:
			assignLargeClass(ref<Binary>(node), compileContext);
			break;

		case	LEFT_SHIFT_ASSIGN:
		case	RIGHT_SHIFT_ASSIGN:
		case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
			b = ref<Binary>(node);
			if (b.left().op() == Operator.SEQUENCE) {
				b.print(0);
				assert(false);
			} else {
				if (b.sethi < 0) {
					assignLvalueTemps(b.left(), compileContext);
					assignRegisterTemp(b.right(), RCXmask, compileContext);
				} else {
					assignRegisterTemp(b.right(), RCXmask, compileContext);
					assignLvalueTemps(b.left(), compileContext);
				}
			}
			break;

		case	ASSIGN:
		case	ASSIGN_TEMP:
		case	ADD_ASSIGN:
		case	SUBTRACT_ASSIGN:
		case	OR_ASSIGN:
		case	AND_ASSIGN:
		case	EXCLUSIVE_OR_ASSIGN:
			b = ref<Binary>(node);
			if (b.left().op() == Operator.SEQUENCE) {
				b.print(0);
				assert(false);
			} else {
				if (b.type.isFloat()) {
					assignRegisterTemp(b, floatMask, compileContext);
				} else if (b.sethi < 0) {
					assignLvalueTemps(b.left(), compileContext);
					assignRegisterTemp(b.right(), requiredMask(b), compileContext);
				} else {
					assignRegisterTemp(b.right(), requiredMask(b), compileContext);
					assignLvalueTemps(b.left(), compileContext);
				}
			}
			break;

		case	DIVIDE_ASSIGN:
		case	REMAINDER_ASSIGN:
			b = ref<Binary>(node);
			if (b.type.isFloat()) {
				assignRegisterTemp(b, floatMask, compileContext);
				break;
			} else if (b.sethi < 0) {
				assignLvalueTemps(b.left(), compileContext);
				assignRegisterTemp(b.right(), requiredMask(node) & ~(RAXmask|RDXmask), compileContext);
			} else {
				assignRegisterTemp(b.right(), requiredMask(node) & ~(RAXmask|RDXmask), compileContext);
				assignLvalueTemps(b.left(), compileContext);
			}
			f().r.getreg(b, RAXmask, RAXmask);
			break;

		case	DELETE:
			b = ref<Binary>(node);
			assignRegisterTemp(b.right(), getRegMask(firstRegisterArgument()), compileContext);
			break;
			
		case	CONDITIONAL:
			ref<Ternary> cond = ref<Ternary>(node);
			assignConditionCode(cond.left(), compileContext);
			assignVoidContext(cond.middle(), compileContext);
			assignVoidContext(cond.right(), compileContext);
			break;

		case	LEFT_COMMA:
			b = ref<Binary>(node);
			assignRegisterTemp(b.left(), longMask(), compileContext);
			f().r.clobberSomeRegisters(b, callMask());
//			assignVoidContext(b.right(), compileContext); - d
			break;
			
		case	EMPTY:
			break;
			
		case	STORE_V_TABLE:
		case	CALL_DESTRUCTOR:
			u = ref<Unary>(node);
			assignRegisterTemp(u.operand(), getRegMask(firstRegisterArgument()), compileContext);
			break;

		default:
			node.print(0);
			assert(false);
		}
		f().r.cleanupTemps(node, depth);
	}

	void assignConditionCode(ref<Node> node, ref<CompileContext> compileContext) {
		int depth = tempStackDepth();
		switch (node.op()) {
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
		case	NOT_LESS_GREATER_EQUAL:
			ref<Binary> b = ref<Binary>(node);
			if	(b.sethi < 0) {
				assignRegisterTemp(b.left(), requiredMask(b.left()), compileContext);
				assignRegisterTemp(b.right(), requiredMask(b.right()), compileContext);
			} else {
				assignRegisterTemp(b.right(), requiredMask(b.right()), compileContext);
				assignRegisterTemp(b.left(), requiredMask(b.left()), compileContext);
			}
			break;

		case	LEFT_COMMA:
			b = ref<Binary>(node);
			assignRegisterTemp(b.left(), longMask(), compileContext);
			f().r.clobberSomeRegisters(b.right(), callMask());
//			assignVoidContext(b.right(), compileContext);
			break;
			
		case	LOGICAL_OR:
		case	LOGICAL_AND:
			b = ref<Binary>(node);
			assignConditionCode(b.left(), compileContext);
			assignConditionCode(b.right(), compileContext);
			break;
			
		case	SEQUENCE:
			b = ref<Binary>(node);
			assignVoidContext(b.left(), compileContext);
			assignRegisterTemp(b.right(), longMask(), compileContext);
			break;
			
		case	NOT:
			ref<Unary> u = ref<Unary>(node);
			assignConditionCode(u.operand(), compileContext);
			break;
			
		case	DOT:
			ref<Selection> dot = ref<Selection>(node);
			assignLvalueTemps(dot, compileContext);
			break;
			
		case	IDENTIFIER:
		case	TRUE:
		case	FALSE:
			break;
			
		case	CALL:
			assignVoidContext(node, compileContext);
			break;
			
		default:
			printf("assignConditionCode\n");
			node.print(0);
			assert(false);
		}
		f().r.cleanupTemps(node, depth);
	}

	void assignRegisterTemp(ref<Node> node, long regMask, ref<CompileContext> compileContext) {
		if	(node.deferGeneration())
			return;
//		printf("AssignRegisterTemp:\n");
//		node.print(4);
//		printf(">>\n");
		if ((node.nodeFlags & ADDRESS_MODE) != 0) {
			assignLvalueTemps(node, compileContext);
			return;
		}
		int depth = tempStackDepth();
//		printf("===\nright up front (desired depth=%d current depth=%d):\n", depth, tempStackDepth());
//		node.print(4);
		switch (node.op()) {
		case	CALL:
			ref<Call> call = ref<Call>(node);
			if (call.category() == CallCategory.DECLARATOR)
				node.register = byte(f().r.getreg(node, longMask(), regMask));
			else
				assignCallRegisters(call, compileContext);
			break;
			
		case	CAST:
			u = ref<Unary>(node);
			assignCastNode(u, u.operand(), regMask, compileContext);
			break;
			
		case	LOGICAL_OR:
		case	LOGICAL_AND:
			b = ref<Binary>(node);
			assignConditionCode(b.left(), compileContext);
			assignConditionCode(b.right(), compileContext);
			node.register = byte(f().r.getreg(node, regMask, regMask));
			f().r.cleanupTemps(node, depth);
			break;
			
		case	SEQUENCE:
			b = ref<Binary>(node);
			assignVoidContext(b.left(), compileContext);
			assignRegisterTemp(b.right(), regMask, compileContext);
			f().r.cleanupTemps(node, depth);
			node.register = b.right().register;
			break;
			
		case	DIVIDE_ASSIGN:
			b = ref<Binary>(node);
			if (b.type.isFloat()) {
				if (b.sethi < 0) {
					assignLvalueTemps(b.left(), compileContext);
					assignRegisterTemp(b.right(), requiredMask(b), compileContext);
				} else {
					assignRegisterTemp(b.right(), requiredMask(b), compileContext);
					assignLvalueTemps(b.left(), compileContext);
				}
				node.register = byte(f().r.getreg(node, floatMask, regMask));
				f().r.cleanupTemps(node, depth);
				break;
			} else if	(b.type.size() > 1) {
				if	(b.sethi < 3) {
					b.sethi = -1;
					reserveReg(node, R.RDX, RDXmask);
					node.register = byte(int(R.RDX));
					assignLvalueTemps(b.left(), compileContext);
					assignRegisterTemp(b.right(), longMask() & ~(RAXmask | RDXmask), compileContext);
				} else {
					reserveReg(node, R.RDX, RDXmask);
					node.register = byte(int(R.RDX));
					assignRegisterTemp(b.right(), longMask() & ~(RAXmask | RDXmask), compileContext);
					assignLvalueTemps(b.left(), compileContext);
				}
			} else {
				if	(b.sethi < 0) {
					assignRegisterTemp(b.left(), RAXmask, compileContext);
					assignRegisterTemp(b.right(), longMask() & ~RAXmask, compileContext);
				} else {
					assignRegisterTemp(b.right(), longMask() & ~RAXmask, compileContext);
					assignRegisterTemp(b.left(), RAXmask, compileContext);
				}
			}
			f().r.cleanupTemps(node, depth);
			node.register = byte(int(R.RAX));
			break;
			
		case	DIVIDE:
			b = ref<Binary>(node);
			if (b.type.isFloat()) {
				assignBinaryOperands(b, regMask, floatMask, compileContext);
				break;
			} else if (b.type.size() > 1) {
				if	(b.sethi < 0) {
					assignRegisterTemp(b.left(), RAXmask, compileContext);
					f().r.clobberSomeRegisters(node, RDXmask);
					assignRegisterTemp(b.right(), longMask() & ~(RAXmask | RDXmask), compileContext);
				} else {
					assignRegisterTemp(b.right(), longMask() & ~(RAXmask | RDXmask), compileContext);
					f().r.clobberSomeRegisters(node, RDXmask);
					assignRegisterTemp(b.left(), RAXmask, compileContext);
				}
			} else {
				if	(b.sethi < 0) {
					assignRegisterTemp(b.left(), RAXmask, compileContext);
					assignRegisterTemp(b.right(), longMask() & ~RAXmask, compileContext);
				} else {
					assignRegisterTemp(b.right(), longMask() & ~RAXmask, compileContext);
					assignRegisterTemp(b.left(), RAXmask, compileContext);
				}
			}
			f().r.cleanupTemps(node, depth);
			node.register = byte(R.RAX);
			break;
			
		case	REMAINDER_ASSIGN:
		case	REMAINDER:
			b = ref<Binary>(node);
			if	(b.type.size() > 1) {
				if	(b.sethi < 3) {
					b.sethi = -1;
					assignRegisterTemp(b.left(), RAXmask, compileContext);
					reserveReg(node, R.RDX, RDXmask);
					node.register = byte(int(R.RDX));
					assignRegisterTemp(b.right(), longMask() & ~(RAXmask | RDXmask), compileContext);
				} else {
					assignRegisterTemp(b.right(), longMask() & ~(RAXmask | RDXmask), compileContext);
					reserveReg(node, R.RDX, RDXmask);
					node.register = byte(int(R.RDX));
					assignRegisterTemp(b.left(), RAXmask, compileContext);
				}
				node.register = byte(int(R.RDX));
			} else {
				if	(b.sethi < 0) {
					assignRegisterTemp(b.left(), RAXmask, compileContext);
					assignRegisterTemp(b.right(), longMask() & ~RAXmask, compileContext);
				} else {
					assignRegisterTemp(b.right(), longMask() & ~RAXmask, compileContext);
					assignRegisterTemp(b.left(), RAXmask, compileContext);
				}
				node.register = byte(int(R.AH));
			}
			f().r.cleanupTemps(node, depth);
			break;
			
		case	MULTIPLY_ASSIGN:
			b = ref<Binary>(node);
			f().r.getreg(b, RAXmask, RAXmask);
			if	(b.sethi < 0) {
				assignLvalueTemps(b.left(), compileContext);
				assignRegisterTemp(b.right(), requiredMask(node) & ~RAXmask, compileContext);
			} else {
				assignRegisterTemp(b.right(), requiredMask(node) & ~RAXmask, compileContext);
				assignLvalueTemps(b.left(), compileContext);
			}
			f().r.cleanupTemps(node, depth);
			node.register = byte(int(R.RAX));
			break;

		case	MULTIPLY:
			b = ref<Binary>(node);
			switch (b.type.family()) {
			case	SIGNED_32:
			case	SIGNED_64:
				assignBinaryOperands(b, regMask, longMask(), compileContext);
				break;

			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
				assignBinaryOperands(b, RAXmask, longMask(), compileContext);
				break;
				
			case	FLOAT_32:
			case	FLOAT_64:
				assignBinaryOperands(b, regMask, floatMask, compileContext);
				break;
				
			default:
				node.print(4);
				assert(false);
			}
			break;

		case	SUBTRACT_ASSIGN:
		case	ADD_ASSIGN:
			switch (node.type.family()) {
			case	CLASS:
				printf("\n>> non pointer type\n");
				node.print(4);
				assert(false);
			}

		case	ASSIGN:
			if (node.type.family() == TypeFamily.CLASS && node.type.indirectType(compileContext) == null) {
				assignLargeClass(ref<Binary>(node), compileContext);
				break;
			}
			
		case	AND_ASSIGN:
		case	OR_ASSIGN:
		case	EXCLUSIVE_OR_ASSIGN:
			b = ref<Binary>(node);
			if (b.left().op() == Operator.SEQUENCE) {
				b.print(0);
				assert(false);
			}
			if (node.type.isFloat()) {
				if (b.sethi < 0) {
					assignLvalueTemps(b.left(), compileContext);
					assignRegisterTemp(b.right(), requiredMask(b), compileContext);
				} else {
					assignRegisterTemp(b.right(), requiredMask(b), compileContext);
					assignLvalueTemps(b.left(), compileContext);
				}
				switch (b.op()) {
				case	SUBTRACT_ASSIGN:
					node.register = byte(f().r.getreg(node, floatMask, regMask));
					break;
					
				default:
					node.register = byte(f().r.latestResult(b.right()));
				}
				f().r.cleanupTemps(b, depth);
				break;
			} else if (b.sethi < 0) {
				assignLvalueTemps(b.left(), compileContext);
				assignRegisterTemp(b.right(), requiredMask(b), compileContext);
			} else {
				assignRegisterTemp(b.right(), requiredMask(b), compileContext);
				assignLvalueTemps(b.left(), compileContext);
			}
			node.register = byte(f().r.getreg(node, requiredMask(b), requiredMask(b)));
			f().r.cleanupTemps(b, depth);
			break;
			
		case	ADD:
		case	SUBTRACT:
			if (node.type.isFloat()) {
				b = ref<Binary>(node);
				assignBinaryOperands(b, regMask, floatMask, compileContext);
				break;
			}
			switch (node.type.family()) {
			case	CLASS:
				printf("\n>> non pointer type\n");
				node.print(4);
				assert(false);
			}

		case	AND:
		case	OR:
		case	EXCLUSIVE_OR:
			b = ref<Binary>(node);
			assignBinaryOperands(b, regMask, requiredMask(b), compileContext);
			break;

		case	LEFT_SHIFT_ASSIGN:
		case	RIGHT_SHIFT_ASSIGN:
		case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
			b = ref<Binary>(node);
			if	(b.sethi < 0) {
				assignLvalueTemps(b.left(), compileContext);
				assignRegisterTemp(b.right(), RCXmask, compileContext);
			} else {
				assignRegisterTemp(b.right(), RCXmask, compileContext);
				assignLvalueTemps(b.left(), compileContext);
			}
			f().r.cleanupTemps(b, depth);
			if (b.right().register != 0)
				node.register = byte(R.RCX);
			else
				node.register = byte(f().r.getreg(node, longMask(), longMask()));
			break;
			
		case	LEFT_SHIFT:
		case	RIGHT_SHIFT:
		case	UNSIGNED_RIGHT_SHIFT:
			b = ref<Binary>(node);
			if (regMask == RCXmask) {
				if ((b.right().nodeFlags & ADDRESS_MODE) == 0)
					regMask = requiredMask(b.left()) & ~RCXmask;
			} else
				regMask &= ~RCXmask;

			if	(b.sethi < 0) {
				assignRegisterTemp(b.left(), regMask, compileContext);
				assignRegisterTemp(b.right(), RCXmask, compileContext);
			} else {
				assignRegisterTemp(b.right(), RCXmask, compileContext);
				assignRegisterTemp(b.left(), regMask, compileContext);
			}
			f().r.cleanupTemps(b, depth);
			b.register = byte(f().r.latestResult(b.left()));
			break;
			
		case	INCREMENT_AFTER:
		case	DECREMENT_AFTER:
			ref<Unary> u = ref<Unary>(node);
			assignLvalueTemps(u.operand(), compileContext);
			long rhsMask = requiredMask(node);
			int i = int(f().r.getreg(node, rhsMask, rhsMask));
			f().r.cleanupTemps(node, depth);
			node.register = byte(i);
			break;
			
		case	INCREMENT_BEFORE:
		case	DECREMENT_BEFORE:
			u = ref<Unary>(node);
			assignLvalueTemps(u.operand(), compileContext);
			f().r.cleanupTemps(node, depth);
			rhsMask = requiredMask(node);
			node.register = byte(f().r.getreg(node, rhsMask, rhsMask));
			break;
			
		case	INDIRECT:
			u = ref<Unary>(node);
			assignRegisterTemp(u.operand(), longMask(), compileContext);
			f().r.cleanupTemps(node, depth);
			node.register = byte(f().r.getreg(node, requiredMask(node), regMask));
			break;
			
		case	UNARY_PLUS:
			u = ref<Unary>(node);
			assignRegisterTemp(u.operand(), regMask, compileContext);
			f().r.cleanupTemps(node, depth);
			node.register = byte(int(f().r.latestResult(u.operand())));
			break;

		case	NEGATE:
			if (node.type.isFloat()) {
				u = ref<Unary>(node);
				regMask &= requiredMask(node);
				assignRegisterTemp(u.operand(), regMask, compileContext);
				node.register = byte(int(f().r.getreg(node, floatMask, regMask)));
				f().r.cleanupTemps(node, depth);
				break;
			}

		case	BIT_COMPLEMENT:
		case	NOT:
			u = ref<Unary>(node);
			if ((regMask & requiredMask(node)) != 0)
				regMask &= requiredMask(node);
			assignRegisterTemp(u.operand(), regMask, compileContext);
			f().r.cleanupTemps(node, depth);
			node.register = byte(int(f().r.latestResult(u.operand())));
			break;
			
		case	CONDITIONAL:
			ref<Ternary> conditional = ref<Ternary>(node);
			if ((regMask & requiredMask(node)) != 0)
				regMask &= requiredMask(node);
//			printf("\n\nbefore test (desired depth=%d current depth=%d):\n", depth, tempStackDepth());
//			f().r.print();
			f().r.clobberSomeRegisters(conditional, callMask());
			assignConditionCode(conditional.left(), compileContext);
//			printf("\n\nbefore first cleanup (desired depth=%d current depth=%d):\n", depth, tempStackDepth());
//			f().r.print();
			f().r.cleanupTemps(node, depth);
			assignRegisterTemp(conditional.middle(), regMask, compileContext);
//			printf("\n\nbefore cleanup (desired depth=%d current depth=%d):\n", depth, tempStackDepth());
//			f().r.print();
			f().r.cleanupTemps(node, depth);
//			printf("\n\nafter cleanup:\n");
//			f().r.print();
//			conditional.print(4);
			assignRegisterTemp(conditional.right(), getRegMask(R(int(conditional.middle().register))), compileContext);
//			printf("\n---\n");
			f().r.cleanupTemps(node, depth);
			node.register = conditional.middle().register;
			break;
			
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
		case	NOT_LESS_GREATER_EQUAL:
			ref<Binary> b = ref<Binary>(node);
			assignBinaryOperands(b, regMask, 0, compileContext);
			break;

		case	ADDRESS:
			u = ref<Unary>(node);
			assignLvalueTemps(u.operand(), compileContext);
			f().r.cleanupTemps(u, depth);
			u.register = byte(f().r.getreg(u, longMask(), regMask));
			break;
			
		case	LOAD:
			u = ref<Unary>(node);
			if ((regMask & requiredMask(u)) == 0)
				regMask = requiredMask(u);
			assignRegisterTemp(u.operand(), regMask, compileContext);
			f().r.cleanupTemps(u, depth);
			u.register = u.operand().register;
			break;
			
		case	CLASS_OF:
			u = ref<Unary>(node);
			switch (u.operand().type.family()) {
			case	VAR:
				assignLvalueTemps(u.operand(), compileContext);
				f().r.cleanupTemps(u, depth);
				u.register = byte(f().r.getreg(u, longMask(), regMask));
				break;
				
			case	REF:
			case	POINTER:
				if (u.operand().op() != Operator.EMPTY) {
					assignRegisterTemp(u.operand(), longMask(), compileContext);
					f().r.cleanupTemps(u, depth);
				}
				u.register = byte(int(f().r.getreg(u, longMask(), regMask)));
				break;
				
			default:
				assignRegisterTemp(u.operand(), longMask(), compileContext);
				f().r.cleanupTemps(u, depth);
				u.register = byte(int(f().r.latestResult(u.operand())));
			}
			break;

		case	MY_OUT_PARAMETER:
			node.register = byte(f().r.getreg(node, longMask(), regMask));
			break;

		case	FALSE:
		case	INTEGER:
		case	CHARACTER:
		case	INTERNAL_LITERAL:
		case	TRUE:
		case	STRING:
		case	IDENTIFIER:
		case	VARIABLE:
		case	THIS:
		case	SUPER:
		case	NULL:
		case	BYTES:
		case	TEMPLATE_INSTANCE:
		case	FLOATING_POINT:
		case	FRAME_PTR:
		case	STACK_PTR:
			if (node.type.isFloat())
				node.register = byte(f().r.getreg(node, floatMask, regMask));
			else {
				node.register = byte(f().r.getreg(node, requiredMask(node), regMask));
			}
			break;
			
		case	SUBSCRIPT:
			b = ref<Binary>(node);
			if (b.left().type.indirectType(compileContext) != null || 
				b.left().type.family() == TypeFamily.STRING) {
				if (b.sethi < 0) {
					assignRegisterTemp(b.left(), longMask(), compileContext);
					assignRegisterTemp(b.right(), longMask(), compileContext);
				} else {
					assignRegisterTemp(b.right(), longMask(), compileContext);
					assignRegisterTemp(b.left(), longMask(), compileContext);
				}
				f().r.cleanupTemps(b, depth);
				node.register = byte(f().r.getreg(node, requiredMask(node), regMask));
			} else {
				node.print(0);
				assert(false);
			}
			break;
			
		case	DOT:
			ref<Selection> dot = ref<Selection>(node);
			if (dot.indirect())
				assignRegisterTemp(dot.left(), longMask(), compileContext);
			else
				assignLvalueTemps(dot.left(), compileContext);
			f().r.cleanupTemps(node, depth);
			node.register = byte(int(f().r.getreg(node, requiredMask(node), regMask)));
			break;
			
		case	NEW:
			// NEW nodes have been re-written - they now just signify that we should call memory.alloc
			b = ref<Binary>(node);
			assert(b.left().op() == Operator.EMPTY);
//			assert(b.right().op() == Operator.EMPTY);
			f().r.clobberSomeRegisters(b, callMask());
			f().r.getreg(b, RAXmask, RAXmask);
			node.register = byte(int(R.RAX));
			break;
			
		default:
			node.print(0);
			assert(false);
		}
		if (node.register != 0)
			reserveReg(node, R(int(node.register)), regMask);
//		printf("<<<\n");
//		f().r.print();
	}

	private void assignLargeClass(ref<Binary> assignment, ref<CompileContext> compileContext) {
		int depth = tempStackDepth();
		f().r.clobberSomeRegisters(assignment, callMask());
		if	(assignment.sethi < 0) {
			assignRegisterTemp(assignment.left(), getRegMask(firstRegisterArgument()), compileContext);
			assignRegisterTemp(assignment.right(), getRegMask(secondRegisterArgument()), compileContext);
		} else {
			assignRegisterTemp(assignment.right(), getRegMask(secondRegisterArgument()), compileContext);
			assignRegisterTemp(assignment.left(), getRegMask(firstRegisterArgument()), compileContext);
		}
		f().r.getreg(assignment, RAXmask, RAXmask);
		f().r.cleanupTemps(assignment, depth);
		assignment.register = byte(int(R.RAX));
	}
	
	private void assignCastNode(ref<Node> result, ref<Node> operand, long regMask, ref<CompileContext> compileContext) {
		ref<Type> existingType = operand.type;
		ref<Type> newType = result.type;
		if (existingType.family() == TypeFamily.ENUM && newType.family() == TypeFamily.STRING) {
			// We can't use the assignCast method because this is a method call, so the output
			// register is fixed
			int depth = tempStackDepth();
			assignRegisterTemp(operand, getRegMask(firstRegisterArgument()), compileContext);
			f().r.getreg(result, RAXmask, RAXmask);
			f().r.cleanupTemps(result, depth);
			result.register = byte(R.RAX);
			return;
		}
		switch (impl(existingType)) {
		case	BOOLEAN:
		case	UNSIGNED_8:
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
				int depth = tempStackDepth();
				assignRegisterTemp(operand, longMask(), compileContext);
				f().r.cleanupTemps(result, depth);
				if (R(int(operand.register)) == R.AH)
					result.register = byte(int(f().r.getreg(result, RAXmask, RAXmask)));
				else
					result.register = byte(int(f().r.latestResult(operand)));
				return;

			case	FLOAT_32:
			case	FLOAT_64:
				assignCast(result, operand, regMask, longMask(), compileContext);
				return;
			}
			break;
			
		case	SIGNED_16:
		case	UNSIGNED_16:
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
				assignCast(result, operand, regMask, 0, compileContext);
				return;

			case	FLOAT_32:
			case	FLOAT_64:
				assignCast(result, operand, regMask, longMask(), compileContext);
				return;
			}
			break;
			
		case	UNSIGNED_32:
		case	SIGNED_32:
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
				assignCast(result, operand, regMask, 0, compileContext);
				if (unsigned(int(result.register)) > unsigned(int(R.MAX_REG))) {
					printf("----- %s ---------\n", compileContext.current().sourceLocation(result.location()));
					result.print(0);
					f().r.print();
					assert(false);
				}
				return;
				
			case	FLOAT_32:
			case	FLOAT_64:
				assignCast(result, operand, regMask, longMask(), compileContext);
				return;
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
				assignCast(result, operand, regMask, 0, compileContext);
				return;

			case	FLOAT_32:
			case	FLOAT_64:
				assignCast(result, operand, regMask, longMask(), compileContext);
				return;
			}
			break;

		case	FLOAT_32:
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
				assignCast(result, operand, regMask, floatMask, compileContext);
				return;

			case	FLOAT_32:
			case	FLOAT_64:
				assignCast(result, operand, regMask, 0, compileContext);
				return;
			}
			break;

		case	STRING:
			switch (newType.family()) {
			case	STRING:
				assignCast(result, operand, regMask, 0, compileContext);
				return;
			}
			break;

		case	INTERFACE:
		case	ADDRESS:
		case	REF:
		case	POINTER:
			switch (impl(newType)) {
			case	STRING:
			case	ADDRESS:
			case	REF:
			case	POINTER:
			case	BOOLEAN:
			case	UNSIGNED_8:
			case	UNSIGNED_16:
			case	UNSIGNED_32:
			case	SIGNED_16:
			case	SIGNED_32:
			case	SIGNED_64:
			case	FUNCTION:
			case	INTERFACE:
				assignCast(result, operand, regMask, 0, compileContext);
				return;

			case	FLOAT_32:
			case	FLOAT_64:
				assignCast(result, operand, regMask, longMask(), compileContext);
				return;
			}
			break;

		case	CLASS:
			// A general class coercion from another class type.
			if (existingType.size() == newType.size())
				return;
			if (newType.family() == TypeFamily.INTERFACE) {
				int depth = tempStackDepth();
				assignLvalueTemps(operand, compileContext);
				R reg = f().r.getreg(result, longMask(), longMask());
				f().r.cleanupTemps(result, depth);
				result.register = byte(reg);
				return;
			}
			break;

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
			case	FLAGS:
				assignCast(result, operand, regMask, 0, compileContext);
				return;

			case	FLOAT_32:
			case	FLOAT_64:
			case	ENUM:
				assignCast(result, operand, regMask, longMask(), compileContext);
				return;
			}
			break;
		}
		result.print(0);
		assert(false);
	}
	
	private void assignCast(ref<Node> result, ref<Node> operand, long regMask, long operandMask, ref<CompileContext> compileContext) {
//		long originalOperandMask = operandMask;
//		long originalRegMask = regMask;
		int depth = tempStackDepth();
		if (operandMask != 0) {
//			if ((operandMask & regMask) != 0)
//				operandMask &= regMask;
			assignRegisterTemp(operand, operandMask, compileContext);
			R operandRegister = R(operand.register);
			long actualMask = getRegMask(operandRegister);
			if ((regMask & ~actualMask) == 0)
				regMask = requiredMask(result) & ~actualMask;
			else
				regMask &= ~actualMask;
//			if (regMask == 0)
//				printf("operandMask = %x regMask = %x actualMask = %x\n", originalOperandMask, originalRegMask, actualMask);
			R output = f().r.getreg(result, regMask, regMask);
			f().r.cleanupTemps(result, depth);
			result.register = byte(output);
		} else {
			assignRegisterTemp(operand, regMask, compileContext);
			f().r.cleanupTemps(result, depth);
			if (operand.register == 0)
				result.register = byte(f().r.getreg(result, regMask, regMask));
			else
				result.register = byte(f().r.latestResult(operand));
		}
	}
	
	private void assignBinaryOperands(ref<Binary> b, long resultMask, long rhsMask, ref<CompileContext> compileContext) {
		int depth = tempStackDepth();

		if	((resultMask & rhsMask) == 0) {
			if (rhsMask == 0)
				rhsMask = requiredMask(b.right());
			if	(b.sethi < 0) {
				assignRegisterTemp(b.left(), rhsMask, compileContext);
				assignRegisterTemp(b.right(), rhsMask, compileContext);
			} else {
				assignRegisterTemp(b.right(), rhsMask, compileContext);
				assignRegisterTemp(b.left(), rhsMask, compileContext);
			}
			f().r.cleanupTemps(b, depth);
			b.register = byte(f().r.getreg(b, resultMask, resultMask));
		} else {
//			resultMask &= rhsMask;
			if	(b.sethi < 0) {
				assignRegisterTemp(b.left(), resultMask, compileContext);
				assignRegisterTemp(b.right(), rhsMask, compileContext);
			} else {
				assignRegisterTemp(b.right(), rhsMask, compileContext);
				assignRegisterTemp(b.left(), resultMask, compileContext);
			}
			f().r.cleanupTemps(b, depth);
			b.register = byte(f().r.latestResult(b.left()));
		}
	}
	
	void assignSingleReturn(ref<Return> retn, ref<Node> value, ref<CompileContext> compileContext) {
		ref<FunctionDeclaration> enclosing = f().current.enclosingFunction();
		ref<FunctionType> functionType = ref<FunctionType>(enclosing.type);
		ref<NodeList> returnType = functionType.returnType();
		int depth = tempStackDepth();
		if (returnType.next != null ||
			returnType.node.type.returnsViaOutParameter(compileContext)) {
			if (value.op() == Operator.SEQUENCE) {
				ref<Binary> b = ref<Binary>(value);
				assignVoidContext(b.left(), compileContext);
				assignSingleReturn(retn, b.right(), compileContext);
			} else {
				switch (value.type.size()) {
				case	1:
				case	2:
				case	4:
				case	8:
					assignRegisterTemp(value, requiredMask(value), compileContext); 
					break;
					
				default:
					if (value.isLvalue())
						assignLvalueTemps(value, compileContext);
					else
						// else this is an rvalue expression and we have to get our value from somewhere else
						assignVoidContext(value, compileContext);
				}
			}
		} else if (retn.type.isFloat())
			assignRegisterTemp(value, xmm0mask, compileContext);	// Take the result in any register available.
		else
			assignRegisterTemp(value, RAXmask, compileContext);		// Take the result in any register available.
		f().r.cleanupTemps(retn, depth);
	}
	
	void assignMultiReturn(ref<Return> retn, ref<Node> value, ref<CompileContext> compileContext) {
		ref<FunctionDeclaration> enclosing = f().current.enclosingFunction();
		ref<FunctionType> functionType = ref<FunctionType>(enclosing.type);
		ref<NodeList> returnType = functionType.returnType();
		int depth = tempStackDepth();
		if (requiredMask(value) != 0) 
			assignRegisterTemp(value, requiredMask(value), compileContext); 
		else if (value.isLvalue())
			assignLvalueTemps(value, compileContext);
		// else this is an rvalue expression and we have to get our value from somewhere else
		f().r.cleanupTemps(retn, depth);
	}
	
	private void ensureRegisterPlacement(ref<Node> where, ref<Node> affected, R reg) {
		if ((affected.nodeFlags & ADDRESS_MODE) != 0)
			return;
//		printf("ensure in %s:\n", regNames[reg]);
//		affected.print(4);
		if (f().r.latestResult(affected) != reg) {
			// Need to get the register into the right place
			f().r.transfer(where, affected, reg);
		}
	}
	
	private void assignCallRegisters(ref<Call> call, ref<CompileContext> compileContext) {
		int i = 0;
		boolean isConstructor = false;
		// This will flush out any stray temps at the 'last minute'
		int depth = tempStackDepth();
		for (ref<NodeList> args = call.stackArguments(); args != null; args = args.next)
			assignStackArgument(args.node, compileContext);

		if (call.arguments() != null) {
			for (ref<NodeList> args = call.arguments(); args != null; args = args.next) {
				long regMask;
				
				// This can happen for a multi-return of a multi-call, where this is the call part.
				if (args.node.register == 0) {
					assignVoidContext(args.node, compileContext);
					continue;
				}
				if (args.node.register == 0xff)
					regMask = longMask();
				else
					regMask = getRegMask(R(args.node.register));
				args.node.register = 0;
				assignRegisterTemp(args.node, regMask, compileContext);
			}
			
			f().r.cleanupTemps(call, depth);
		}
		
		if (compileContext.arena().verbose) {
			printf("After arguments cleanup:\n");
			f().r.print();
		}
		if (call.type.family() == TypeFamily.VOID || (call.nodeFlags & PUSH_OUT_PARAMETER) != 0)
			call.register = byte(R.NO_REG);
		else if (call.type.isFloat()) {
			f().r.getreg(call, xmm0mask, xmm0mask);
			call.register = byte(R.XMM0);
		} else {
			f().r.getreg(call, RAXmask, RAXmask);
			call.register = byte(R.RAX);
		}
	}

	private void ensureCorrectPlacement(ref<Call> call, int i, ref<NodeList> args, ref<NodeList> params) {
		ref<Node> ellipsis = params.node.getProperEllipsis();
		if (ellipsis == null) {
			byte r = registerValue(i, args.node.type.family());
			if (r > 0) {
				ensureRegisterPlacement(call, args.node, R(r));
				i++;
			}
			if (params.next != null)
				ensureCorrectPlacement(call, i, args.next, params.next);
		}
	}
	
	private void assignStackArgument(ref<Node> arg, ref<CompileContext> compileContext) {
		int depth = tempStackDepth();
		if (arg.isLvalue())
			assignLvalueTemps(arg, compileContext);
		else {
			switch (arg.op()) {
			case	SEQUENCE:
				ref<Binary> b = ref<Binary>(arg);
				assignVoidContext(b.left(), compileContext);
				assignStackArgument(b.right(), compileContext);
				break;
				
			case	CALL:
				assignVoidContext(arg, compileContext);
				break;
			
			case	VACATE_ARGUMENT_REGISTERS:
				f().r.clobberSomeRegisters(arg, callMask());
				break;
				
			case	ELLIPSIS_ARGUMENTS:
				ref<EllipsisArguments> ea = ref<EllipsisArguments>(arg);
				for (ref<NodeList> args = ea.arguments(); args != null; args = args.next) {
					ref<Unary> u = ref<Unary>(args.node);
					switch (u.type.family()) {
					case STRING:
						assignRegisterTemp(u.operand(), getRegMask(secondRegisterArgument()), compileContext);
						reserveReg(u.operand(), firstRegisterArgument(), getRegMask(firstRegisterArgument()));
						break;
						
					case VAR:
						assignStackArgument(u.operand(), compileContext);
						break;
						
					case CLASS:
						if (u.type.indirectType(compileContext) == null) {
							if (u.operand().isLvalue())
								assignLvalueTemps(u.operand(), compileContext);
							else 
								assignStackArgument(u.operand(), compileContext); 
							u.register = byte(f().r.getreg(u, longMask(), longMask()));
							break;
						}
					default:
						assignRegisterTemp(u.operand(), longMask(), compileContext);
					}
					f().r.cleanupTemps(u, depth);
				}
				break;
				
			case	STACK_ARGUMENT:
				ref<Unary> u = ref<Unary>(arg);
				assignStackArgument(u.operand(), compileContext);
				f().r.cleanupTemps(u, depth);
				break;
			
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
			case	FLOATING_POINT:
			case	STRING:
				assignRegisterTemp(arg, requiredMask(arg), compileContext);
				f().r.cleanupTemps(arg, depth);
				break;
				
			case	NULL:
			case	THIS:
			case	SUPER:
			case	TRUE:
			case	FALSE:
				break;
				
			default:
				arg.print(0);
				assert(false);
			}
		}
		f().r.cleanupTemps(arg, depth);
	}
	
	private void assignLvalueTemps(ref<Node> node, ref<CompileContext> compileContext) {
		if	(node.deferGeneration())
			return;
		switch (node.op()) {
		case	TRUE:
		case	FALSE:
		case	IDENTIFIER:
		case	VARIABLE:
		case	INTEGER:
		case	INTERNAL_LITERAL:
		case	EMPTY:
		case	STRING:
		case	THIS:
		case	SUPER:
		case	FRAME_PTR:
		case	STACK_PTR:
			break;
			
		case	SEQUENCE:
			ref<Binary> b = ref<Binary>(node);
			assignVoidContext(b.left(), compileContext);
			assignLvalueTemps(b.right(), compileContext);
			break;
			
		case	NULL:
			node.print(0);
			assert(false);
			break;
			
		case	SUBSCRIPT:
			b = ref<Binary>(node);
			if (b.sethi < 0) {
				assignRegisterTemp(b.left(), longMask(), compileContext);
				assignRegisterTemp(b.right(), longMask(), compileContext);
			} else {
				assignRegisterTemp(b.right(), longMask(), compileContext);
				assignRegisterTemp(b.left(), longMask(), compileContext);
			}
			break;
			
		case	INDIRECT:
			ref<Unary> u = ref<Unary>(node);
			assignRegisterTemp(u.operand(), longMask(), compileContext);
			break;
			
		case	DOT:
			ref<Selection> dot = ref<Selection>(node);
			if (dot.indirect())
				assignRegisterTemp(dot.left(), longMask(), compileContext);
			else
				assignLvalueTemps(dot.left(), compileContext);
			break;
			
		default:
			node.print(0);
			assert(false);
		}
	}
	
	private void reserveReg(ref<Node> node, R actual, long asked) {
		f().r.makeTemp(node, actual, asked);
		assert(f().current != null);
		long regMask = getRegMask(actual);
		for	(ref<Scope> sc = f().current; sc != null && sc.storageClass() == StorageClass.AUTO; sc = sc.enclosing())
			sc.reservedInScope |= regMask;
	}
	
	private long requiredMask(ref<Node> node) {
		switch (node.type.family()) {
		case SIGNED_8:
		case UNSIGNED_8:
		case BOOLEAN:
			return byteMask;
			
		case FLOAT_32:
		case FLOAT_64:
			return floatMask;
			
		case FLAGS:
		case ENUM:
			if (node.type.size() == 1)
				return byteMask;
			
		default:
			return longMask();
		}
		return longMask();
	}
}

class ArgumentDescriptor {
	public ref<Node> argument;
	public int regMask;
	
	ArgumentDescriptor() {
	}
	
	ArgumentDescriptor(ref<Node> argument, int regMask) {
		this.argument = argument;
		this.regMask = regMask;
	}
}
