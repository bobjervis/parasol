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

import parasol:runtime;

boolean shouldVectorize(ref<Node> node) {
	if (node.isLvalue())
		return false;
	switch (node.op()) {
	case	CALL:
		return false;
		
	case	SEQUENCE:
		ref<Binary> b = ref<Binary>(node);
		return shouldVectorize(b.right());

	case	ARRAY_AGGREGATE:
		if (node.type != null && node.type.family() == runtime.TypeFamily.REF)
			return false;							// This is a ref<Array> initializer
	}
	return true;
}

ref<Node> reduce(Operator op, ref<SyntaxTree> tree, ref<Node> vectorExpression, ref<CompileContext> compileContext) {
	ref<Variable> accumulator = compileContext.newVariable(vectorExpression.type.elementType());
	ref<Variable> iterator = compileContext.newVariable(vectorExpression.type.indexType());
	ref<Reference> def = tree.newReference(iterator, true, vectorExpression.location());
	substring init("0");
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
	r = tree.newReference(accumulator, false, vectorExpression.location());
	body = tree.newBinary(reduceToAssignment(op), r, body, vectorExpression.location());
	body = tree.newUnary(Operator.EXPRESSION, body, vectorExpression.location());
	
	ref<Node> loop = tree.newFor(Operator.FOR, start, test, increment, body, vectorExpression.location());
	r = tree.newReference(accumulator, false, vectorExpression.location());
	loop = tree.newBinary(Operator.SEQUENCE, loop, r, vectorExpression.location());
//	printf("Re-written loop:\n");
//	loop.print(0);
	compileContext.assignTypes(loop);
	return loop.fold(tree, false, compileContext);
}

ref<Node> vectorize(ref<SyntaxTree> tree, ref<Node> vectorExpression, ref<CompileContext> compileContext) {
	ref<Binary> b = ref<Binary>(vectorExpression);
	if (b.right().op() == Operator.ARRAY_AGGREGATE)
		return vectorizeAggregateAssignment(tree, b, compileContext);
	ref<Variable> iterator = compileContext.newVariable(vectorExpression.type.indexType());
	ref<Reference> def = tree.newReference(iterator, true, vectorExpression.location());
	substring init("0");
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
			ref<OverloadInstance> oi = getMethodSymbol(closure.lvalues[0], "resize", closure.lvalues[0].type, compileContext);
			if (oi == null)
				return vectorExpression;
			ref<Selection> method = tree.newSelection(closure.lvalues[0], oi, false, vectorExpression.location());
			method.type = oi.type();
			ref<NodeList> args = tree.newNodeList(tree.newReference(vectorSize, false, vectorExpression.location()));
			ref<Call> call = tree.newCall(oi.parameterScope(), null,  method, args, vectorExpression.location(), compileContext);
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
	if ((vectorStuff.nodeFlags & VECTOR_OPERAND) != 0) {
		ref<Node> index = tree.newReference(iterator, false, vectorStuff.location());
		ref<OverloadInstance> oi = getMethodSymbol(vectorStuff, "getModulo", vectorStuff.type, compileContext);
		if (oi == null)
			return vectorStuff;
		ref<Selection> method = tree.newSelection(vectorStuff, oi, false, vectorStuff.location());
		method.type = oi.type();
		ref<NodeList> args = tree.newNodeList(index);
		return tree.newCall(oi.parameterScope(), null,  method, args, vectorStuff.location(), compileContext);
	}
	if (vectorStuff.isLvalue())
		return vectorStuff;
	switch (vectorStuff.op()) {
	case	ASSIGN:
	case	INITIALIZE:
		ref<Binary> b = ref<Binary>(vectorStuff);
		ref<Node> index = tree.newReference(iterator, false, vectorStuff.location());
		ref<OverloadInstance> oi = getMethodSymbol(vectorStuff, "setModulo", vectorStuff.type, compileContext);
		if (oi == null)
			return vectorStuff;
		ref<Selection> method = tree.newSelection(b.left(), oi, false, vectorStuff.location());
		method.type = oi.type();
		ref<Node> right = rewriteVectorTree(tree, b.right(), iterator, vectorSize, compileContext);
		ref<NodeList> args = tree.newNodeList(tree.newReference(iterator, false, vectorStuff.location()), right);
		return tree.newCall(oi.parameterScope(), null,  method, args, vectorStuff.location(), compileContext);

	case	NEGATE:
	case	UNARY_PLUS:
	case	BIT_COMPLEMENT:
	case	NOT:
		ref<Unary> u = ref<Unary>(vectorStuff);
		right = rewriteVectorTree(tree, u.operand(), iterator, vectorSize, compileContext);
		return tree.newUnary(u.op(), right, u.location());
		
	case	ADD:
	case	SUBTRACT:
	case	DIVIDE:
	case	MULTIPLY:
	case	REMAINDER:
	case	AND:
	case	OR:
	case	EXCLUSIVE_OR:
	case	LEFT_SHIFT:
	case	RIGHT_SHIFT:
	case	UNSIGNED_RIGHT_SHIFT:
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
	if (n.type.family() != runtime.TypeFamily.SHAPE)
		return TraverseAction.SKIP_CHILDREN;
	if (n.isLvalue() || n.op() == Operator.ARRAY_AGGREGATE) {
		ref<ExtractLvaluesClosure> closure = ref<ExtractLvaluesClosure>(data);
		closure.operands.append(n);
		n.nodeFlags |= VECTOR_OPERAND;
		return TraverseAction.SKIP_CHILDREN;
	}

	switch (n.op()) {
	case	INITIALIZE:
	case	ASSIGN:
		ref<Binary> b = ref<Binary>(n);
		ref<ExtractLvaluesClosure> closure = ref<ExtractLvaluesClosure>(data);
		closure.lvalues.append(b.left());
		b.left().nodeFlags |= VECTOR_LVALUE;
		b.right().traverse(Node.Traversal.PRE_ORDER, extractLvalues, data);
		return TraverseAction.SKIP_CHILDREN;
		
	case	ARRAY_AGGREGATE:
	case	ADD:
	case	SUBTRACT:
	case	DIVIDE:
	case	MULTIPLY:
	case	REMAINDER:
	case	AND:
	case	OR:
	case	EXCLUSIVE_OR:
	case	LEFT_SHIFT:
	case	RIGHT_SHIFT:
	case	UNSIGNED_RIGHT_SHIFT:
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

private Operator reduceToAssignment(Operator reduce) {
	switch (reduce) {
	case	ADD_REDUCE:
		return Operator.ADD_ASSIGN;
		
	default:
		assert(false);
	}
	return Operator.SEQUENCE;
}

private ref<Node> vectorizeAggregateAssignment(ref<SyntaxTree> tree, ref<Binary> vectorExpression, ref<CompileContext> compileContext) {
	ref<Call> aggregate = ref<Call>(vectorExpression.right());
	ref<Node> folded = aggregate.fold(tree, false, compileContext);
	assert(folded.class == Call);
	aggregate = ref<Call>(folded);
	if (aggregate.deferAnalysis())
		return aggregate;
	ref<Type> vectorType = vectorExpression.type;
	ref<Node> lhs = vectorExpression.left();
	if (lhs.commentary() != null) {
		vectorExpression.type = compileContext.errorType();
		return vectorExpression;
	}
	ref<Node> result = null;
	if (!lhs.isSimpleLvalue()) {
		ref<Type> refVector = compileContext.newRef(vectorType);

		ref<Variable> lhv = compileContext.newVariable(refVector);
		ref<Reference> def = tree.newReference(lhv, true, lhs.location());
		ref<Node> adr = tree.newUnary(Operator.ADDRESS, lhs, lhs.location());
		result = tree.newBinary(Operator.ASSIGN, def, adr, lhs.location());
		lhs = tree.newReference(lhv, false, lhs.location());
	}
	ref<Type> indexType = vectorType.indexType();
	if (indexType.isCompactIndexType()) {
		boolean anyLabels = false;
		int maxIndexValue = -1;
		int lastIndexValue = -1;
		
		// Calculate the maximum assigned element in this aggregate.
		
		for (ref<NodeList> nl = aggregate.arguments(); nl != null; nl = nl.next) {
			if (nl.node.op() == Operator.LABEL) {
				ref<Binary> b = ref<Binary>(nl.node);
				switch (indexType.family()) {
				case ENUM:
				case UNSIGNED_8:
				case UNSIGNED_16:
				case UNSIGNED_32:
				case SIGNED_16:
				case SIGNED_32:
				case SIGNED_64:
					lastIndexValue = int(b.left().foldInt(null, compileContext));
					break;

				default:
					vectorExpression.print(0);
					assert(false);
				}
				anyLabels = true;
			} else
				lastIndexValue++;
			if (lastIndexValue > maxIndexValue)
				maxIndexValue = lastIndexValue;
		}
		if (anyLabels) {
			
			// If we have labels, pre-allocate all the elements as empty.
			
			ref<Node> arg = tree.newConstant(maxIndexValue + 1, aggregate.location());
			arg.type = compileContext.builtInType(runtime.TypeFamily.SIGNED_32);
			arg = tree.newCast(indexType, arg);
			ref<ParameterScope> constructor = null;
			for (int i = 0; i < vectorType.scope().constructors().length(); i++) {
				ref<FunctionDeclaration> f = ref<FunctionDeclaration>((*vectorType.scope().constructors())[i].definition());
				ref<OverloadInstance> oi = ref<OverloadInstance>(f.name().symbol());
				oi.assignType(compileContext);
				if (oi.parameterCount() != 1)
					continue;
				if ((*oi.parameterScope().parameters())[0].type() == indexType) {
					constructor = oi.parameterScope();
					break;
				}
			}
			if (constructor != null) {
				ref<NodeList> args = tree.newNodeList(arg);
				ref<Node> adr;
				if (lhs.op() == Operator.ADDRESS) 
					adr = lhs;
				else
					adr = tree.newUnary(Operator.ADDRESS, lhs, lhs.location());
				result = tree.newCall(constructor, CallCategory.CONSTRUCTOR, adr, args, aggregate.location(), compileContext);
				result.type = compileContext.builtInType(runtime.TypeFamily.VOID);
			} else {
				// This should generate a runtime exception, because this was likely due to a catastrophic compile error somewhere
				result = tree.newLeaf(Operator.SYNTAX_ERROR, vectorExpression.location());
				result.type = compileContext.errorType();
				return result;
			}
			lastIndexValue = -1;
			for (ref<NodeList> nl = aggregate.arguments(); nl != null; nl = nl.next) {
				ref<Node> val;
				ref<Node> idx;
				if (nl.node.op() == Operator.LABEL) {
					ref<Binary> b = ref<Binary>(nl.node);
					val = b.right();
					switch (indexType.family()) {
					case ENUM:
					case UNSIGNED_8:
					case UNSIGNED_16:
					case UNSIGNED_32:
					case SIGNED_16:
					case SIGNED_32:
					case SIGNED_64:
						lastIndexValue = int(b.left().foldInt(null, compileContext));
						break;
	
					default:
						vectorExpression.print(0);
						assert(false);
					}
				} else {
					lastIndexValue++;
					val = nl.node;
				}
				idx = tree.newConstant(lastIndexValue, val.location());
				idx.type = compileContext.builtInType(runtime.TypeFamily.SIGNED_32);
				idx = tree.newCast(indexType, idx);
				substring set("set");
				ref<Node> arrayRef = lhs.clone(tree);
				ref<Symbol> sym = vectorType.lookup(set, compileContext);

				if (sym == null || sym.class != Overload) {
					vectorExpression.add(MessageId.UNDEFINED, compileContext.pool(), set);
					return vectorExpression;
				}
				ref<OverloadInstance> oi = (*ref<Overload>(sym).instances())[0];
				ref<Selection> method = tree.newSelection(arrayRef, oi, false, arrayRef.location());
				method.type = oi.type();
				ref<NodeList> args = tree.newNodeList(idx, val);
				ref<Node> next = tree.newCall(oi.parameterScope(), null,  method, args, val.location(), compileContext);
				result = tree.newBinary(Operator.SEQUENCE, result, next, vectorExpression.location());
			}
		} else {
			for (ref<NodeList> nl = aggregate.arguments(); nl != null; nl = nl.next) {
				ref<Node> arrayRef = lhs.clone(tree);
				ref<Selection> method = tree.newSelection(arrayRef, "append", arrayRef.location());
				if (nl.node.op() == Operator.LABEL) {
					vectorExpression.print(0);
					assert(false);
				}
				ref<NodeList> args = tree.newNodeList(nl.node);
				ref<Node> next = tree.newCall(Operator.CALL, method, args, nl.node.location());
				if (result == null)
					result = next;
				else
					result = tree.newBinary(Operator.SEQUENCE, result, next, vectorExpression.location());
			}
		}
	} else {
		for (ref<NodeList> nl = aggregate.arguments(); nl != null; nl = nl.next) {
			substring set("set");

			ref<Node> arrayRef = lhs.clone(tree);
			
			ref<Symbol> sym = vectorType.lookup(set, compileContext);

			if (sym == null || sym.class != Overload) {
				vectorExpression.add(MessageId.UNDEFINED, compileContext.pool(), set);
				return vectorExpression;
			}
			ref<OverloadInstance> oi = (*ref<Overload>(sym).instances())[0];
			ref<Selection> method = tree.newSelection(arrayRef, oi, false, arrayRef.location());
			method.type = oi.type();
			if (nl.node.op() != Operator.LABEL) {
				vectorExpression.print(0);
				assert(false);
			}
			ref<Binary> label = ref<Binary>(nl.node);
			ref<NodeList> args = tree.newNodeList(label.left(), label.right());
			ref<Node> next = tree.newCall(oi.parameterScope(), null,  method, args, nl.node.location(), compileContext);
			if (result == null)
				result = next;
			else
				result = tree.newBinary(Operator.SEQUENCE, result, next, vectorExpression.location());
		}
	}
	
	if (result == null)
		result = tree.newLeaf(Operator.EMPTY, lhs.location());	// TODO: This is probably wrong.
	compileContext.assignTypes(result);
//	vectorExpression.print(0);
//	printf("-->\n");
//	result.print(0);
//	assert(false);
	return result.fold(tree, true, compileContext);
}
