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
 * This file cacluates the Sethi-Ullman number for expression parse trees.
 * 
 * This code should be run after address modes have been marked, but before temporaries are assigned (since the
 * Sethi-Ullman numbers are inputs to the temporary assignment algorithm).
 */
import parasol:compiler.Binary;
import parasol:compiler.Call;
import parasol:compiler.CompileContext;
import parasol:compiler.Node;
import parasol:compiler.NodeList;
import parasol:compiler.Operator;
import parasol:compiler.Selection;
import parasol:compiler.StorageClass;
import parasol:compiler.Symbol;
import parasol:compiler.Target;
import parasol:compiler.Ternary;
import parasol:compiler.TypeFamily;
import parasol:compiler.Unary;
import parasol:math;

private int CALL_REG_USE = 7;

void sethiUllman(ref<Node> node, ref<CompileContext> compileContext, ref<Target> target) {
	switch (node.op()) {
	case	CALL:
		ref<Call> c = ref<Call>(node);
		c.sethi = CALL_REG_USE;
		for (ref<NodeList> nl = c.arguments(); nl != null; nl = nl.next) {
			sethiUllman(nl.node, compileContext, target);
			int s = math.abs(nl.node.sethi);
			if (s > c.sethi)
				c.sethi = s;
		}
		if (c.target() != null) {
			sethiUllman(c.target(), compileContext, target);
			if (c.target().sethi > c.sethi)
				c.sethi = c.target().sethi;
		}
		break;
		
	case	ADDRESS:
		ref<Unary> u = ref<Unary>(node);
		if (u.operand().op() == Operator.IDENTIFIER) {
			ref<Symbol> sym = u.operand().symbol();
			if (sym.storageClass() == StorageClass.AUTO) {
				node.sethi = 1;
				break;
			}
		}
		sethiUllman(u.operand(), compileContext, target);
		node.sethi = u.operand().sethi;
		break;
		
	case	LOAD:
		u = ref<Unary>(node);
		sethiUllman(u.operand(), compileContext, target);
		node.sethi = u.operand().sethi;
		break;
		
	case	INITIALIZE:
		ref<Binary> b = ref<Binary>(node);
		b.left().sethi = 0;
		sethiUllman(b.right(), compileContext, target);
		node.sethi = 0;
		break;
		
	case	DOT:
		ref<Selection> dot = ref<Selection>(node);
		sethiUllman(dot.left(), compileContext, target);
		dot.sethi = dot.left().sethi;
		break;
		
	case	INDIRECT:
	case	BIT_COMPLEMENT:
	case	UNARY_PLUS:
	case	NEGATE:
	case	NOT:
	case	INCREMENT_BEFORE:
	case	DECREMENT_BEFORE:
	case	CAST:
	case	CLASS_OF:
		u = ref<Unary>(node);
		sethiUllman(u.operand(), compileContext, target);
		tp = regneeds(node, compileContext, target);
		int to = regneeds(u.operand(), compileContext, target);
		int suo = math.abs(u.operand().sethi);
		u.sethi = math.max(suo, math.max(tp, math.min(suo, to)));
		break;
		
	case	INCREMENT_AFTER:
	case	DECREMENT_AFTER:
		u = ref<Unary>(node);
		sethiUllman(u.operand(), compileContext, target);
		u.sethi = regneeds(node, compileContext, target) + math.abs(u.operand().sethi);
		break;
		
	case	CLASS_COPY:
		b = ref<Binary>(node);
		sethiUllman(b.left(), compileContext, target);
		sethiUllman(b.right(), compileContext, target);
		b.sethi = CALL_REG_USE;
		break;

	case	ASSIGN:
	case	INITIALIZE:
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
	case	EXCLUSIVE_OR_ASSIGN:
		b = ref<Binary>(node);
		sethiUllman(b.left(), compileContext, target);
		sethiUllman(b.right(), compileContext, target);
		int tp = regneeds(node, compileContext, target);
		int tl = regneeds(b.left(), compileContext, target);
		int sul = math.abs(b.left().sethi);
		int tr = regneeds(b.right(), compileContext, target);
		int sur = math.abs(b.right().sethi);
		b.sethi = math.max(sur, math.max(sul, math.max(tp, math.min(sur + tl, sul + tr))));
		if	(sul > sur)
			b.sethi = -b.sethi;
		break;

	case	LOGICAL_OR:
	case	LOGICAL_AND:
	case	MULTIPLY:
	case	DIVIDE:
	case	REMAINDER:
	case	LEFT_SHIFT:
	case	RIGHT_SHIFT:
	case	UNSIGNED_RIGHT_SHIFT:
	case	ADD:
	case	SUBTRACT:
	case	AND:
	case	OR:
	case	EXCLUSIVE_OR:
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
	case	NEW:
	case	SEQUENCE:
	case	SUBSCRIPT:
		b = ref<Binary>(node);
		sethiUllman(b.left(), compileContext, target);
		sethiUllman(b.right(), compileContext, target);
		tp = regneeds(node, compileContext, target);
		tl = regneeds(b.left(), compileContext, target);
		sul = math.abs(b.left().sethi);
		tr = regneeds(b.right(), compileContext, target);
		sur = math.abs(b.right().sethi);
		b.sethi = math.max(sur, math.max(sul, math.max(tp, math.min(sur + tl, sul + tr))));
		if	(sul >= sur)
			b.sethi = -b.sethi;
		break;
		
	case	DELETE:
		b = ref<Binary>(node);
		sethiUllman(b.right(), compileContext, target);
		b.sethi = regneeds(node, compileContext, target);
		break;
		
	case	CONDITIONAL:
		ref<Ternary> cond = ref<Ternary>(node);
		sethiUllman(cond.left(), compileContext, target);
		sethiUllman(cond.middle(), compileContext, target);
		sethiUllman(cond.right(), compileContext, target);
		tp = regneeds(node, compileContext, target);
		sul = math.abs(cond.left().sethi);
		int sum = math.abs(cond.middle().sethi);
		sur = math.abs(cond.right().sethi);
		cond.sethi = math.max(sur, math.max(sul, math.max(tp, sum)));
		break;
		
	case	BYTES:
	case	TRUE:
	case	FALSE:
	case	THIS:
	case	SUPER:
	case	IDENTIFIER:
	case	FUNCTION:
	case	VARIABLE:
	case	INTEGER:
	case	CHARACTER:
	case	EMPTY:
	case	STRING:
	case	NULL:
	case	TEMPLATE_INSTANCE:
	case	BIND:
		node.sethi = 0;
		break;
		
	default:
		node.print(0);
		assert(false);
	}
}

/*
	This function generates code for a function represented by the
	expression node x.  The resulting code and fixups are generated
	in the value object v.

	The expression node x has already been checked for errors, locals
	have been parsed and initializers created appropriately.  Static
	objects have also been fully generated.
 */
private int regneeds(ref<Node> node, ref<CompileContext> compileContext, ref<Target> target) {
	switch (node.op()) {
	case	CALL:
	case	NEW:
	case	DELETE:
		return CALL_REG_USE;
		
	case	BYTES:
	case	THIS:
	case	SUPER:
	case	IDENTIFIER:
	case	VARIABLE:
	case	STRING:
	case	INTEGER:
	case	CHARACTER:
	case	NULL:
	case	TRUE:
	case	FALSE:
	case	ADDRESS:
	case	EMPTY:
	case	INITIALIZE:
	case	INCREMENT_BEFORE:
	case	DECREMENT_BEFORE:
	case	CONDITIONAL:
	case	SEQUENCE:
	case	TEMPLATE_INSTANCE:
		return 0;
		
	case	INCREMENT_AFTER:
	case	DECREMENT_AFTER:
	case	DOT:
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
	case	ADD_ASSIGN:
	case	SUBTRACT_ASSIGN:
	case	AND_ASSIGN:
	case	OR_ASSIGN:
	case	EXCLUSIVE_OR_ASSIGN:
	case	ADD:
	case	SUBTRACT:
	case	AND:
	case	OR:
	case	EXCLUSIVE_OR:
	case	LOGICAL_OR:
	case	LOGICAL_AND:
	case	ASSIGN:
	case	BIT_COMPLEMENT:
	case	UNARY_PLUS:
	case	NEGATE:
	case	NOT:
	case	SUBSCRIPT:
	case	INDIRECT:
	case	CAST:
	case	CLASS_OF:
		return 1;
		
	case	CLASS_COPY:
		return CALL_REG_USE;
		
	case	MULTIPLY:
	case	DIVIDE:
	case	REMAINDER:
	case	LEFT_SHIFT:
	case	RIGHT_SHIFT:
	case	UNSIGNED_RIGHT_SHIFT:
	case	DIVIDE_ASSIGN:
	case	MULTIPLY_ASSIGN:
	case	REMAINDER_ASSIGN:
	case	LEFT_SHIFT_ASSIGN:
	case	RIGHT_SHIFT_ASSIGN:
	case	UNSIGNED_RIGHT_SHIFT_ASSIGN:
		if (node.type == null)
			return 0;
		switch (node.type.family()) {
		case	FLOAT_32:
		case	FLOAT_64:
			return 1;
		}
		return 2;
		
	default:
		node.print(0);
		assert(false);
	}
	return 1;
}
