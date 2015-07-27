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

boolean shouldVectorize(ref<Node> node) {
	if (node.isLvalue())
		return false;
	switch (node.op()) {
	case	CALL:
		return false;
		
	case	SEQUENCE:
		ref<Binary> b = ref<Binary>(node);
		return shouldVectorize(b.right());
	}
	return true;
}

ref<Node> vectorize(ref<SyntaxTree> tree, ref<Node> vectorExpression, ref<CompileContext> compileContext) {
	ref<Variable> iterator = compileContext.newVariable(vectorExpression.type.indexType(compileContext));
	ref<Reference> def = tree.newReference(iterator, true, vectorExpression.location());
	CompileString init("0");
	ref<Node> start = tree.newConstant(Operator.INTEGER, init, vectorExpression.location());
	start = tree.newBinary(Operator.ASSIGN, def, start, vectorExpression.location());
	// test should really be: lognest of contributing lvalues, so lvalues need to be calculated (if not
	// simple, or cloned if simple) - then the largest is selected.
//	vectorExpression.print(0);
	ExtractLvaluesClosure closure;
	closure.tree = tree;
	vectorExpression.traverse(Node.Traversal.PRE_ORDER, extractLvalues, &closure);
//	printf("Extracted lvalues:\n");
//	for (int i = 0; +i < +closure.lvalues.length(); i++) {
//		closure.lvalues[i].print(+4);
//	}
//	printf("Extracted operands:\n");
//	for (int i = 0; +i < +closure.operands.length(); i++) {
//		closure.operands[i].print(+4);
//	}
	ref<Variable> vectorSize = compileContext.newVariable(def.type);
	if (closure.operands.length() > 0) {
		ref<Reference> vsDef = tree.newReference(vectorSize, true, vectorExpression.location());
		ref<Node> opnd = closure.operands[0];
		if (opnd.isSimpleLvalue()) {
			opnd = opnd.clone(tree);
			opnd.type = vsDef.type;
			opnd = tree.newBinary(Operator.ASSIGN, vsDef, opnd, vectorExpression.location());
			start = tree.newBinary(Operator.SEQUENCE, start, opnd, vectorExpression.location());
		} else {
			printf("Operand 0 too complex\n");
			vectorExpression.print(0);
			assert(false);
		}
		for (int i = 1; i < closure.operands.length(); i++) {
			opnd = closure.operands[i];
			if (opnd.isSimpleLvalue()) {
				ref<Node> opnd2  = opnd.clone(tree);
				opnd2.type = vsDef.type;
				opnd = opnd.clone(tree);
				opnd.type = vsDef.type;
				ref<Node> comp = tree.newBinary(Operator.LESS, vsDef, opnd, vectorExpression.location());
				ref<Node> vsdef2 = tree.newReference(vectorSize, true, vectorExpression.location());
				opnd2 = tree.newBinary(Operator.ASSIGN, vsdef2, opnd2, vectorExpression.location());
				ref<Node> emp = tree.newLeaf(Operator.EMPTY, vectorExpression.location());
				emp.type = vsDef.type;
				comp = tree.newTernary(Operator.CONDITIONAL, comp, opnd2, emp, vectorExpression.location());
				start = tree.newBinary(Operator.SEQUENCE, start, comp, vectorExpression.location());
			} else {
				printf("Operand %d too complex\n", i);
				vectorExpression.print(0);
				assert(false);
			}
		}
		if (closure.lvalues.length() == 1) {
			CompileString name("resize");
			
			ref<Symbol> sym = closure.lvalues[0].type.lookup(&name, compileContext);
			if (sym == null || sym.class != Overload) {
				closure.lvalues[0].add(MessageId.UNDEFINED, compileContext.pool(), name);
				return vectorExpression;
			}
			ref<OverloadInstance> oi = ref<Overload>(sym).instances()[0];
			ref<Selection> method = tree.newSelection(closure.lvalues[0], oi, vectorExpression.location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(tree.newReference(vectorSize, false, vectorExpression.location()));
			ref<Call> call = tree.newCall(oi, null,  method, args, vectorExpression.location());
			start = tree.newBinary(Operator.SEQUENCE, start, call, vectorExpression.location());
		} else {
			printf("Only 1 lvalue per expression allowed\n");
			vectorExpression.print(0);
			assert(false);
		}
	} else {
		printf("Too few operands\n");
		vectorExpression.print(0);
		assert(false);
	}
	ref<Node> limit = tree.newReference(vectorSize, false, vectorExpression.location());
	ref<Node> v  = tree.newReference(iterator, false, vectorExpression.location());
	ref<Node> test = tree.newBinary(Operator.LESS, v, limit, vectorExpression.location());
	ref<Reference> r = tree.newReference(iterator, false, vectorExpression.location());
	ref<Node> increment = tree.newUnary(Operator.INCREMENT_BEFORE, r, vectorExpression.location());
	
	ref<Node> body = rewriteVectorTree(tree, vectorExpression, iterator, vectorSize, compileContext);
	body = tree.newUnary(Operator.EXPRESSION, body, vectorExpression.location());
	
	ref<Node> loop = tree.newFor(Operator.FOR, start, test, increment, body, vectorExpression.location());
//	printf("Re-written loop:\n");
//	loop.print(0);
	compileContext.assignTypes(loop);
	return loop.fold(tree, false, compileContext);
}

private ref<Node> rewriteVectorTree(ref<SyntaxTree> tree, ref<Node> vectorStuff, ref<Variable> iterator, ref<Variable> vectorSize, ref<CompileContext> compileContext) {
	if ((vectorStuff.flags & VECTOR_OPERAND) != 0) {
		CompileString sub("getModulo");

		ref<Node> index = tree.newReference(iterator, false, vectorStuff.location());
		ref<Symbol> sym = vectorStuff.type.lookup(&sub, compileContext);
		
		if (sym == null || sym.class != Overload) {
			vectorStuff.add(MessageId.UNDEFINED, compileContext.pool(), sub);
			return vectorStuff;
		}
		ref<OverloadInstance> oi = ref<Overload>(sym).instances()[0];
		ref<Selection> method = tree.newSelection(vectorStuff, oi, vectorStuff.location());
		method.type = oi.type();
		ref<NodeList> args = tree.newNodeList(index);
		return tree.newCall(oi, null,  method, args, vectorStuff.location());
	}
	switch (vectorStuff.op()) {
	case	ASSIGN:
		CompileString elem("setModulo");

		ref<Binary> b = ref<Binary>(vectorStuff);
		ref<Node> index = tree.newReference(iterator, false, vectorStuff.location());
		ref<Symbol> sym = vectorStuff.type.lookup(&elem, compileContext);
		
		if (sym == null || sym.class != Overload) {
			vectorStuff.add(MessageId.UNDEFINED, compileContext.pool(), elem);
			return vectorStuff;
		}
		ref<OverloadInstance> oi = ref<Overload>(sym).instances()[0];
		ref<Selection> method = tree.newSelection(b.left(), oi, vectorStuff.location());
		method.type = oi.type();
		ref<Node> right = rewriteVectorTree(tree, b.right(), iterator, vectorSize, compileContext);
		ref<NodeList> args = tree.newNodeList(tree.newReference(iterator, false, vectorStuff.location()), right);
		return tree.newCall(oi, null,  method, args, vectorStuff.location());

	case	NEGATE:
	case	UNARY_PLUS:
	case	BIT_COMPLEMENT:
	case	NOT:
		ref<Unary> u = ref<Unary>(vectorStuff);
		right = rewriteVectorTree(tree, u.operand(), iterator, vectorSize, compileContext);
		return tree.newUnary(u.op(), right, u.location());
		
	case	ADD:
		b = ref<Binary>(vectorStuff);
		ref<Node> left = rewriteVectorTree(tree, b.left(), iterator, vectorSize, compileContext);
		right = rewriteVectorTree(tree, b.right(), iterator, vectorSize, compileContext);
		return tree.newBinary(b.op(), left, right, b.location());
		
	default:
		vectorStuff.print(0);
		assert(false);
	}
	return vectorStuff;
}

private class ExtractLvaluesClosure {
	ref<SyntaxTree> tree;
	ref<Node>[] lvalues;
	ref<Node>[] operands;
}

TraverseAction extractLvalues(ref<Node> n, address data) {
	if (n.isLvalue()) {
		ref<ExtractLvaluesClosure> closure = ref<ExtractLvaluesClosure>(data);
		closure.operands.append(n);
		n.flags |= VECTOR_OPERAND;
		return TraverseAction.SKIP_CHILDREN;
	}
	if (n.type.family() != TypeFamily.SHAPE)
		return TraverseAction.SKIP_CHILDREN;

	switch (n.op()) {
	case	ASSIGN:
		ref<Binary> b = ref<Binary>(n);
		ref<ExtractLvaluesClosure> closure = ref<ExtractLvaluesClosure>(data);
		closure.lvalues.append(b.left());
		b.left().flags |= VECTOR_LVALUE;
		b.right().traverse(Node.Traversal.PRE_ORDER, extractLvalues, data);
		return TraverseAction.SKIP_CHILDREN;
		
	case	ADD:
	case	NEGATE:
	case	UNARY_PLUS:
	case	BIT_COMPLEMENT:
	case	NOT:
		break;
		
	default:
		n.print(0);
		assert(false);
	}
	return TraverseAction.CONTINUE_TRAVERSAL;
}


