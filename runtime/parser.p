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

import parasol:process;
import parasol:runtime;
import parasol:thread;

public class Parser {
	private ref<SyntaxTree> _tree;
	private ref<Scanner> _scanner;
	private ref<ClassDeclarator> _enclosing;

	public Parser(ref<SyntaxTree> tree, ref<Scanner> scanner) {
		_tree = tree;
		_scanner = scanner;
	}

	public ref<Block> parseFile() {
		ref<Block> block = _tree.newBlock(Operator.UNIT, false, _scanner.location());
		for (;;) {
			Token t = _scanner.next();
//			int line = _scanner.lineNumber(_scanner.location());
			if (t == Token.END_OF_STREAM) {
				_scanner.close();
				return block;
			}
			_scanner.pushBack(t);
			block.statement(_tree.newNodeList(parseStatement()));
		}
	}

	public ref<Node> parseStatement() {
		Token t;
		ref<Node> annotations = null;
		SourceOffset location;

		t = _scanner.next();
		// This could've been generated because of semi-colon elision and a pushback hre would be disastrous
		if (t == Token.SEMI_COLON) {
			return _tree.newLeaf(Operator.EMPTY, _scanner.location());
		}
		if (t == Token.ANNOTATION) {
			annotations = parseAnnotations();
			if (annotations.op() == Operator.SYNTAX_ERROR)
				return annotations;
		} else
			_scanner.pushBack(t);
		location = _scanner.location();
		ref<Node> x = parseBareStatement();
		if (x.op() == Operator.SYNTAX_ERROR)
			return x;
		if (annotations != null)
			x = _tree.newBinary(Operator.ANNOTATED, annotations, x, location);
		return x;
	}

	public ref<Node> parseExpression(int precedence) {
		ref<Node> left = parseTerm(false);
		if (left.op() == Operator.SYNTAX_ERROR)
			return left;
		for (;;) {
			Token t = _scanner.next();
			SourceOffset loc = _scanner.location();
			Operator op = binaryOperators.binaryOperator(t);

			// If it isn't a binary operator, just go with the term.

			if (op == Operator.SYNTAX_ERROR) {
				_scanner.pushBack(t);
				return left;
			}

			int p = binaryOperators.precedence(op);
			if (p < precedence) {
				_scanner.pushBack(t);
				return left;
			} else if (p == precedence) {
				if (p != 2) { // assignment operators are all right-associative, otherwise left-associative
					_scanner.pushBack(t);
					return left;
				}
			}
			if (op == Operator.CONDITIONAL) {
				ref<Node> truePart = parseExpression(0);
				if (truePart.op() == Operator.SYNTAX_ERROR)
					return truePart;
				t = _scanner.next();
				if (t == Token.COLON) {
					ref<Node> falsePart = parseExpression(binaryOperators.precedence(Operator.CONDITIONAL));
					if (falsePart.op() == Operator.SYNTAX_ERROR)
						return falsePart;
					left = _tree.newTernary(Operator.CONDITIONAL, left, truePart, falsePart, loc);
					continue;
				} else {
					_scanner.pushBack(t);
					return _tree.newSyntaxError(_scanner.location());
				}
			}
			ref<Node> right = parseExpression(p);
			if (right.op() == Operator.SYNTAX_ERROR)
				return right;
			left = _tree.newBinary(op, left, right, loc);
		}
	}
/*
	public ref<LoopDescriptor> currentLoop;
 */
	private ref<Block> parseBlock(ref<Block> block) {
//		if (long(_scanner) > 0x100000000) {
//			printf("_scanner is wrong-o\n");
//			process.exit(1);
//		}
		previous := _scanner.allowSemiColonElision();
		for (;;) {
			Token t = _scanner.next();
//			s := string(_scanner.value());
//			int line = _scanner.lineNumber(_scanner.location());
//			printf("Token %s %s %d\n", string(t), s, line);
			if (t == Token.RIGHT_CURLY) {
				block.closeCurlyLocation = _scanner.location();
				_scanner.preventSemiColon();
				_scanner.restoreSemiColonElision(previous);
				return block;
			} else if (t == Token.END_OF_STREAM) {
				block.closeCurlyLocation = _scanner.location();
				block.statement(_tree.newNodeList(syntaxError(MessageId.UNEXPECTED_EOF)));
				return block;
			}
			_scanner.pushBack(t);
			block.statement(_tree.newNodeList(parseStatement()));
		}
	}

	private ref<Node> parseBareStatement() {
		Token t;
		SourceOffset location;
		ref<Node> truePart;
		ref<Node> falsePart;
		ref<Node> x;

		t = _scanner.next();
		location = _scanner.location();
		switch (t) {
		case	SEMI_COLON:
			return _tree.newLeaf(Operator.EMPTY, location);

		case	LOCK:
			x = parseLockStatement();
			return x;

		case	LEFT_CURLY:
			x = parseBlock(_tree.newBlock(Operator.BLOCK, false, location));
			_scanner.preventSemiColon();
			return x;

		case	BREAK:
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.BREAK_NO_SEMI);
			}
			return _tree.newJump(Operator.BREAK, location);

		case	CASE:
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t != Token.COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.CASE_NO_CO);
			}
			t = _scanner.preventSemiColon();
			if (t == Token.RIGHT_CURLY)
				return resync(MessageId.UNEXPECTED_RC);
			truePart = parseStatement();
			if (truePart.op() == Operator.SYNTAX_ERROR)
				return truePart;
			return _tree.newBinary(Operator.CASE, x, truePart, location);

		case	CONTINUE:
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			return _tree.newJump(Operator.CONTINUE, location);

		case	DEFAULT:
			t = _scanner.next();
			if (t != Token.COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			t = _scanner.preventSemiColon();
			if (t == Token.RIGHT_CURLY)
				return resync(MessageId.UNEXPECTED_RC);
			truePart = parseStatement();
			if (truePart.op() == Operator.SYNTAX_ERROR)
				return truePart;
			return _tree.newUnary(Operator.DEFAULT, truePart, location);

		case	DO:
			truePart = parseStatement();
			if (truePart.op() == Operator.SYNTAX_ERROR)
				return truePart;
			t = _scanner.next();
			if (t != Token.WHILE) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			t = _scanner.next();
			if (t != Token.LEFT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t != Token.RIGHT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.DO_WHILE_NO_SEMI);
			}
			return _tree.newBinary(Operator.DO_WHILE, truePart, x, location);

		case	FOR:
			t = _scanner.next();
			if (t != Token.LEFT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			t = _scanner.next();
			if (t == Token.SEMI_COLON)
				return parseGeneralizedFor(_tree.newLeaf(Operator.EMPTY, _scanner.location()), location);
			_scanner.pushBack(t);
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t == Token.SEMI_COLON)
				return parseGeneralizedFor(x, location);
			else if (t == Token.IDENTIFIER)
				return parseScopedFor(x, location);
			else if (t == Token.IN)
				return parseIteratorFor(x, location);
			else {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}

		case	IF:
			t = _scanner.next();
			if (t != Token.LEFT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t != Token.RIGHT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			_scanner.preventSemiColon();
			truePart = parseStatement();
			if (truePart.op() == Operator.SYNTAX_ERROR)
				return truePart;
			t = _scanner.next();
			if (t == Token.ELSE) {
				falsePart = parseStatement();
				if (falsePart.op() == Operator.SYNTAX_ERROR)
					return falsePart;
			} else {
				_scanner.pushBack(t);
				falsePart = _tree.newLeaf(Operator.EMPTY, _scanner.location());
			}
			return _tree.newTernary(Operator.IF, x, truePart, falsePart, location);

		case	RETURN:
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				x = parseExpression(0);
				if (x.op() == Operator.SYNTAX_ERROR)
					return x;
				t = _scanner.next();
				if (t != Token.SEMI_COLON) {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
				return _tree.newReturn(x.treeToList(null, _tree), location);
			} else
				return _tree.newReturn(null, location);

		case	SWITCH:
			t = _scanner.next();
			if (t != Token.LEFT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t != Token.RIGHT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			previous := _scanner.disableSemiColonElision();
			t = _scanner.next();
			if (t != Token.LEFT_CURLY) {
				_scanner.restoreSemiColonElision(previous);
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			_scanner.restoreSemiColonElision(previous);
			ref<Block> body = _tree.newBlock(Operator.BLOCK, true, _scanner.location());
			truePart = parseBlock(body);
			if (truePart.op() == Operator.SYNTAX_ERROR)
				return truePart;
			return _tree.newBinary(Operator.SWITCH, x, truePart, location);

		case	WHILE:
			t = _scanner.next();
			if (t != Token.LEFT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t != Token.RIGHT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			_scanner.preventSemiColon();
			truePart = parseStatement();
			if (truePart.op() == Operator.SYNTAX_ERROR)
				return truePart;
			return _tree.newBinary(Operator.WHILE, x, truePart, location);

		case	THROW:
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			return _tree.newUnary(Operator.THROW, x, location);
			
		case	TRY:
			truePart = parseStatement();
			if (truePart.op() == Operator.SYNTAX_ERROR)
				return truePart;
			ref<Node> finallyClause;
			ref<NodeList> nl = null;
			for (;;) {
				t = _scanner.next();
				if (t == Token.CATCH) {
					SourceOffset loc = _scanner.location();
					t = _scanner.next();
					if (t != Token.LEFT_PARENTHESIS) {
						_scanner.pushBack(t);
						return resync(MessageId.SYNTAX_ERROR);
					}
					ref<Node> typeExpr = parseExpression(0);
					if (typeExpr.op() == Operator.SYNTAX_ERROR)
						return typeExpr;
					t = _scanner.next();
					if (t != Token.IDENTIFIER) {
						_scanner.pushBack(t);
						return resync(MessageId.SYNTAX_ERROR);
					}
					ref<Node> variable = _tree.newIdentifier(_scanner.value(), _scanner.location());
					t = _scanner.next();
					if (t != Token.RIGHT_PARENTHESIS) {
						_scanner.pushBack(t);
						return resync(MessageId.SYNTAX_ERROR);
					}
					ref<Node> clause = parseStatement();
					if (clause.op() == Operator.SYNTAX_ERROR)
						return clause;
					ref<Ternary> catchClause = _tree.newTernary(Operator.CATCH, typeExpr, variable, clause, loc);
					if (nl == null)
						nl = _tree.newNodeList(catchClause);
					else
						nl.last().next = _tree.newNodeList(catchClause);
				} else if (t == Token.FINALLY) {
					finallyClause = parseStatement();
					if (finallyClause.op() == Operator.SYNTAX_ERROR)
						return finallyClause;
					break;
				} else {
					_scanner.pushBack(t);
					break;
				}
			}
			return _tree.newTry(truePart, finallyClause, nl, location);
			
		case	PUBLIC:
			return parseVisibleDeclaration(Operator.PUBLIC);

		case	PRIVATE:
			return parseVisibleDeclaration(Operator.PRIVATE);

		case	PROTECTED:
			return parseVisibleDeclaration(Operator.PROTECTED);

		case	FINAL:
			return parseFinalDeclaration();

		case	INTERFACE:
			return parseClassOrInterfaceDeclaration(ClassContext.INTERFACE);

		case	CLASS:
			return parseClassOrInterfaceDeclaration(ClassContext.CLASS);
		
		case	MONITOR:
			return parseMonitorDeclaration();
			
		case	FLAGS:
			return parseFlagsDeclaration();

		case	ENUM:
			return parseEnumDeclaration();

		case	ABSTRACT:
			return parseAbstractDeclaration();

		case	STATIC:
			return parseStaticDeclaration();

		case	IMPORT:
			return parseImportStatement();

		case	NAMESPACE:
			ref<Doclet> doclet = _scanner.extractDoclet();
			x = parseNamespace(null, false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t == Token.SEMI_COLON) {
				_tree.newDoclet(x, doclet);
				return _tree.newUnary(Operator.DECLARE_NAMESPACE, x, location);
			}
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);

		case	RIGHT_CURLY:
			return syntaxError(MessageId.UNEXPECTED_RC);

		case	END_OF_STREAM:
			return syntaxError(MessageId.UNEXPECTED_EOF);

		default:
			_scanner.pushBack(t);
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR) {
				return x;
			}
			t = _scanner.next();
			if (t == Token.SEMI_COLON)
				return _tree.newUnary(Operator.EXPRESSION, x, location);
			_scanner.pushBack(t);
			return parseDeclarators(x, location);
		}
		return null;
	}

	private ref<Node> parseLockStatement() {
		SourceOffset location = _scanner.location();
		Token t = _scanner.next();
		ref<Node> lockReference;
		if (t == Token.LEFT_PARENTHESIS) {
			lockReference = parseExpression(0);
			if (lockReference.op() == Operator.SYNTAX_ERROR)
				return lockReference;
			t = _scanner.next();
			if (t != Token.RIGHT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			t = _scanner.next();
			lockReference = _tree.newUnary(Operator.EXPRESSION, lockReference, lockReference.location());
		} else
			lockReference = _tree.newLeaf(Operator.EMPTY, location);
		ref<Block> block = _tree.newBlock(Operator.BLOCK, false, _scanner.location());
		if (t != Token.LEFT_CURLY) {
			_scanner.pushBack(t);
			block.statement(_tree.newNodeList(resync(MessageId.SYNTAX_ERROR)));
		} else {
			parseBlock(block);
		}
		return _tree.newLock(lockReference, block, location);
	}
	
	private ref<Node> parseImportStatement() {
		SourceOffset location = _scanner.location();
		Token t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Identifier> importedSymbol = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
		ref<Identifier> domainSymbol;
		t = _scanner.next();
		if (t == Token.EQUALS)
			domainSymbol = null;
		else {
			_scanner.pushBack(t);
			domainSymbol = importedSymbol;
			importedSymbol = null;
		}
		ref<Node> namespaceNode = parseNamespace(domainSymbol, true);
		if (namespaceNode.op() == Operator.SYNTAX_ERROR)
			return namespaceNode;
		t = _scanner.next();
		if (t != Token.SEMI_COLON) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		return _tree.newImport(importedSymbol, ref<Ternary>(namespaceNode), location);
	}

	private ref<Node> parseNamespace(ref<Node> stem, boolean forImport) {
		ref<Node> dom = parseDottedName(stem, null);
		if (dom.op() == Operator.SYNTAX_ERROR)
			return dom;
		Token t = _scanner.next();
		if (t != Token.COLON) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		SourceOffset location = _scanner.location();
		ref<Identifier> lastName = null;
		ref<Node> ns = parseDottedName(null, ref<ref<Identifier>>(forImport ? &lastName : null));
		if (ns.op() == Operator.SYNTAX_ERROR)
			return ns;
		return _tree.newTernary(Operator.NAMESPACE, dom, ns, lastName, location);
	}

	private ref<Node> parseDottedName(ref<Node> stem, ref<ref<Identifier>> lastName) {
		Token t;
		if (stem == null) {
			t = _scanner.next();
			if (t != Token.IDENTIFIER) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			stem = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
		}
		t = _scanner.next();
		if (t != Token.DOT) {
			_scanner.pushBack(t);
			if (lastName != null) {
				*lastName = ref<Identifier>(stem);
				return _tree.newLeaf(Operator.EMPTY, stem.location());
			} else
				return stem;
		}
		t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		SourceOffset lastIdentifier = _scanner.location();
		string text;
		substring spelling = _scanner.value();
		for (;;) {
			text = spelling;
			spelling = text;
			t = _scanner.next();
			if (t != Token.DOT) {
				if (lastName != null)
					*lastName = _tree.newIdentifier(spelling, lastIdentifier);
				else
					stem = _tree.newSelection(stem, spelling, lastIdentifier);
				_scanner.pushBack(t);
				return stem;
			} else
				stem = _tree.newSelection(stem, spelling, lastIdentifier);
			t = _scanner.next();
			if (t != Token.IDENTIFIER) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			lastIdentifier = _scanner.location();
			spelling = _scanner.value();
		}
	}

	private ref<Node> parseVisibleDeclaration(Operator visibility) {
		SourceOffset location = _scanner.location();
		Token t = _scanner.next();
		ref<Node> n;
		ref<Node> x;
		switch (t) {
		case	STATIC:
			n = parseStaticDeclaration();
			break;

		case	FINAL:
			n = parseFinalDeclaration();
			break;

		case	INTERFACE:
			n = parseClassOrInterfaceDeclaration(ClassContext.INTERFACE);
			break;

		case	CLASS:
			n = parseClassOrInterfaceDeclaration(ClassContext.CLASS);
			break;

		case	MONITOR:
			n = parseMonitorDeclaration();
			break;
			
		case	FLAGS:
			n = parseFlagsDeclaration();
			break;

		case	ENUM:
			n = parseEnumDeclaration();
			break;

		case	ABSTRACT:
			n = parseAbstractDeclaration();
			break;

		default:
			_scanner.pushBack(t);
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			n = parseDeclarators(x, location);
			if (n.op() == Operator.SYNTAX_ERROR)
				return n;
		}
		return _tree.newUnary(visibility, n, location);
	}

	private ref<Node> parseAbstractDeclaration() {
		SourceOffset location = _scanner.location();
		ref<Node> returnType = parseExpression(0);
		if (returnType.op() == Operator.SYNTAX_ERROR)
			return returnType;
		ref<Node> name = parseName(_scanner.next());
		if (name.op() == Operator.SYNTAX_ERROR)
			return name;
		ref<Doclet> doclet = _scanner.extractDoclet();
		ref<Identifier> id = ref<Identifier>(name);
		Token t = _scanner.next();
		SourceOffset loc = _scanner.location();
		if (t != Token.LEFT_PARENTHESIS) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<NodeList> parameters;
		if (!parseParameterList(Token.RIGHT_PARENTHESIS, &parameters))
			return parameters.node;
		t = _scanner.next();
		if (t != Token.SEMI_COLON) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<FunctionDeclaration> func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.ABSTRACT, returnType, id, parameters, loc);
		_tree.newDoclet(id, doclet);
		return _tree.newUnary(Operator.ABSTRACT, func, location);
	}

	private ref<Block> parseInterface(ref<Block> block) {
		for (;;) {
			Token t = _scanner.next();
//			CompileString cs = _scanner.value();
//			int line = _scanner.lineNumber(_scanner.location());
//			string s(cs.data, cs.length);
//			printf("Token %s %s %d\n", string(t), s, line);
			if (t == Token.RIGHT_CURLY) {
				block.closeCurlyLocation = _scanner.location();
				_scanner.preventSemiColon();
				return block;
			} else if (t == Token.END_OF_STREAM) {
				block.closeCurlyLocation = _scanner.location();
				block.statement(_tree.newNodeList(syntaxError(MessageId.UNEXPECTED_EOF)));
				return block;
			} else if (t == Token.FINAL)
				block.statement(_tree.newNodeList(syntaxError(MessageId.UNEXPECTED_FINAL)));
			else if (t == Token.ABSTRACT)
				block.statement(_tree.newNodeList(syntaxError(MessageId.UNEXPECTED_ABSTRACT)));
			else
				_scanner.pushBack(t);
			SourceOffset location = _scanner.location();
			ref<Node> returnType = parseExpression(0);
			if (returnType.op() == Operator.SYNTAX_ERROR) {
				block.statement(_tree.newNodeList(returnType));
				continue;
			}
			ref<Node> name = parseName(_scanner.next());
			if (name.op() == Operator.SYNTAX_ERROR) {
				block.statement(_tree.newNodeList(name));
				continue;
			}
			ref<Doclet> doclet = _scanner.extractDoclet();
			ref<Identifier> id = ref<Identifier>(name);
			_tree.newDoclet(id, doclet);
			t = _scanner.next();
			SourceOffset loc = _scanner.location();
			if (t != Token.LEFT_PARENTHESIS) {
				_scanner.pushBack(t);
				block.statement(_tree.newNodeList(resync(MessageId.SYNTAX_ERROR)));
				continue;
			}
			ref<NodeList> parameters;
			if (!parseParameterList(Token.RIGHT_PARENTHESIS, &parameters)) {
				block.statement(_tree.newNodeList(parameters.node));
				continue;
			}
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				block.statement(_tree.newNodeList(resync(MessageId.SYNTAX_ERROR)));
				continue;
			}
			ref<FunctionDeclaration> func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.ABSTRACT, returnType, id, parameters, loc);
			ref<Unary> u = _tree.newUnary(Operator.PUBLIC, func, location);
			block.statement(_tree.newNodeList(u));
		}
	}
	
	private ref<Node> parseStaticDeclaration() {
		SourceOffset location = _scanner.location();
		ref<Node> x = parseExpression(0);
		if (x.op() == Operator.SYNTAX_ERROR)
			return x;
		ref<Node> n = parseDeclarators(x, location);
		if (n.op() == Operator.SYNTAX_ERROR)
			return n;
		return _tree.newUnary(Operator.STATIC, n, location);
	}

	ref<Node> parseFinalDeclaration() {
		SourceOffset location = _scanner.location();
		Token t = _scanner.next();
		ref<Node> n;
		if (t == Token.CLASS)
			n = parseClassOrInterfaceDeclaration(ClassContext.CLASS);
		else if (t == Token.INTERFACE)
			n = parseClassOrInterfaceDeclaration(ClassContext.INTERFACE);
		else if (t == Token.MONITOR)
			n = parseMonitorDeclaration();
		else if (t == Token.ENUM)
			n = parseEnumDeclaration();
		else {
			SourceOffset loc = _scanner.location();
			_scanner.pushBack(t);
			ref<Node> x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			n = parseDeclarators(x, loc);
			if (n.op() == Operator.SYNTAX_ERROR)
				return n;
			if (n.op() != Operator.FUNCTION && n.op() != Operator.SYNTAX_ERROR)
				n.add(MessageId.UNEXPECTED_FINAL, _tree.pool());
		}
		if (n.op() == Operator.SYNTAX_ERROR)
			return n;
		return _tree.newUnary(Operator.FINAL, n, location);
	}

	private ref<Node> parseConstructor(ref<Call> declarator) {
		ref<FunctionDeclaration> func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.CONSTRUCTOR, null, ref<Identifier>(declarator.target()), declarator.arguments(), declarator.location());
		Token t = _scanner.next();
		if (t == Token.LEFT_CURLY) {
			func.body = _tree.newBlock(Operator.BLOCK, false, _scanner.location());
			parseBlock(func.body);
		} else {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		return func;
	}

	private ref<Node> parseDestructor(ref<Call> declarator) {
		ref<FunctionDeclaration> func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.DESTRUCTOR, null, ref<Identifier>(declarator.target()), declarator.arguments(), declarator.location());
		if (declarator.arguments() != null) {
			declarator.arguments().node.add(MessageId.NO_PARAMS_IN_DESTRUCTOR, _tree.pool());
		}
		Token t = _scanner.next();
		if (t == Token.LEFT_CURLY) {
			func.body = _tree.newBlock(Operator.BLOCK, false, _scanner.location());
			parseBlock(func.body);
		} else {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		return func;
	}

	private ref<Node> parseDeclarators(ref<Node> type, SourceOffset location) {
		ref<Doclet> doclet = _scanner.extractDoclet();
		if (enclosingClassName() != null) {
			switch (type.op()) {
			case	BIT_COMPLEMENT:	// possible destructor
				ref<Unary> u = ref<Unary>(type);
				if (u.operand().op() == Operator.CALL) {
					call = ref<Call>(u.operand());
					if (isClassName(call.target()))
						return parseDestructor(call);
				}
				break;

			case	CALL:			// possible constructor
				ref<Call> call = ref<Call>(type);
				if (isClassName(call.target())) {
					_tree.newDoclet(call.target(), doclet);
					return parseConstructor(call);
				}
				break;

			default:
				break;
			}
		}
		Token t = _scanner.next();
		if (t == Token.IDENTIFIER) {
			ref<Node> x = parseName(t);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			ref<Node> initializer;
			ref<FunctionDeclaration> func;
			ref<Identifier> id = ref<Identifier>(x);
			t = _scanner.next();
			SourceOffset loc = _scanner.location();
			ref<NodeList> parameters;
			_tree.newDoclet(id, doclet);
			switch (t) {
			case	LEFT_PARENTHESIS:
				if (!parseParameterList(Token.RIGHT_PARENTHESIS, &parameters))
					return parameters.node;
				if (parameters == null) {
					t = _scanner.next();
					if (t == Token.LOCK) {
						func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.NORMAL, type, id, parameters, loc);
						ref<Node> n = parseLockStatement();
						if (n.op() == Operator.SYNTAX_ERROR)
							return n;
						func.body = _tree.newBlock(Operator.BLOCK, false, n.location());
						func.body.statement(_tree.newNodeList(n));						
						return func;
					} else if (t == Token.LEFT_CURLY) {
						func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.NORMAL, type, id, parameters, loc);
						func.body = _tree.newBlock(Operator.BLOCK, false, _scanner.location());
						parseBlock(func.body);
						return func;
					} else if (t != Token.SEMI_COLON) {
						_scanner.pushBack(t);
						return resync(MessageId.SYNTAX_ERROR);
					} 
					//
					// If the 'type' expression is the keyword 'void' the only possible meaning
					// of this declaration token sequence is as an improper function declaration.
					// if could have several possible interpretations. For example, this code
					// was added in response to a poor error message when this was compiled:
					//
					//       void f(int, long);
					//
					// This was entered as a test of whether it was an acceptable way to declare
					// a function pointer (it isn't).
					// The correct way to do that is:
					//
					//		void(int, long) f;
					//
					// The declaration has parsed as:
					//
					//		VOID function-name LP parameter-list RP SM
					//
					// This could also just be missing the 'abstract' keyword, or also
					// that the semi-colon is a mistaken substitution or insertion error and
					// a function body was intended to follow.
					// 
					// The special-purpose parse tree comes pre-tagged with a syntax error,
					// opting to point out the need for a function body. Of course, if we are
					// willing to accept this here as valid syntax and then detect the error 
					// after we could see that the example given above, of an incorrectly formaatted
					// function pointer, perhaps we could produce an even better error message
					// specifically saying that the object name needs to come after the argument list.
					//
					if (type.op() == Operator.VOID) {
						func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.NORMAL,
															type, id, parameters, loc);
						func.body = _tree.newBlock(Operator.BLOCK, false, _scanner.location());
						func.add(MessageId.FUNCTION_MISSING_BODY, _tree.pool());
						return func;
					}
					ref<Call> initializer = _tree.newCall(Operator.CALL, null, null, loc);
					x = _tree.newBinary(Operator.INITIALIZE, id, initializer, loc);
					return _tree.newDeclaration(type, x, location);
				} else if (parameters.hasBindings()) {
					func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.NORMAL, type, id, parameters, loc);
					t = _scanner.next();
					if (t == Token.LOCK) {
						ref<Node> n = parseLockStatement();
						if (n.op() == Operator.SYNTAX_ERROR)
							return n;
						func.body = _tree.newBlock(Operator.BLOCK, false, n.location());
						
						func.body.statement(_tree.newNodeList(n));						
					} else if (t == Token.LEFT_CURLY) {
						func.body = _tree.newBlock(Operator.BLOCK, false, _scanner.location());
						parseBlock(func.body);
					} else {
						_scanner.pushBack(t);
						return resync(MessageId.FUNCTION_MISSING_BODY);
					}
					return func;
				} else {
					t = _scanner.next();
					if (t == Token.SEMI_COLON) {
						// See comment above
						if (type.op() == Operator.VOID) {
							func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.NORMAL,
																type, id, parameters, loc);
							func.body = _tree.newBlock(Operator.BLOCK, false, _scanner.location());
							func.add(MessageId.FUNCTION_MISSING_BODY, _tree.pool());
							return func;
						}
						ref<Call> initializer = _tree.newCall(Operator.CALL, null, parameters, loc);
						x = _tree.newBinary(Operator.INITIALIZE, id, initializer, loc);
						return _tree.newDeclaration(type, x, location);
					} else {
						_scanner.pushBack(t);
						return resync(MessageId.SYNTAX_ERROR);
					}
				}

			case	EQUALS:
				initializer = parseExpression(1);
				x = _tree.newBinary(Operator.INITIALIZE, id, initializer, loc);
				if (initializer.op() == Operator.SYNTAX_ERROR)
					return _tree.newDeclaration(type, x, location);
				t = _scanner.next();
				if (t == Token.SEMI_COLON) {
					return _tree.newDeclaration(type, x, location);
				} else if (t != Token.COMMA) {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}

			case	COMMA:
				for (;;) {
					ref<Node> right = parseName(_scanner.next());
					if (right.op() == Operator.SYNTAX_ERROR)
						return right;
					t = _scanner.next();
					if (t == Token.EQUALS) {
						SourceOffset locEq = _scanner.location();
						initializer = parseExpression(1);
						if (initializer.op() == Operator.SYNTAX_ERROR)
							return initializer;
						right = _tree.newBinary(Operator.INITIALIZE, right, initializer, locEq);
						t = _scanner.next();
					}
					x = _tree.newBinary(Operator.SEQUENCE, x, right, loc);
					if (t == Token.SEMI_COLON)
						return _tree.newDeclaration(type, x, location);
					else if (t != Token.COMMA) {
						_scanner.pushBack(t);
						return resync(MessageId.SYNTAX_ERROR);
					}
					loc = _scanner.location();
				}

			case	SEMI_COLON:
				return _tree.newDeclaration(type, x, location);

			default:
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			return null;
		} else if (t == Token.END_OF_STREAM)
			return syntaxError(MessageId.UNEXPECTED_EOF);
		else {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
	}

	private ref<Node> parseClassOrInterfaceDeclaration(ClassContext context) {
		SourceOffset location = _scanner.location();
		Token t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Identifier> identifier = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
		ref<Doclet> doclet = _scanner.extractDoclet();
		_tree.newDoclet(identifier, doclet);
		// Look ahead to get the correct location for the CLASS node.
		t = _scanner.next();
		if (t == Token.EQUALS) {
			SourceOffset locEq = _scanner.location();
			ref<Node> initializer = parseExpression(1);
			if (initializer.op() == Operator.SYNTAX_ERROR)
				return initializer;
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			ref<Node> x = _tree.newBinary(Operator.INITIALIZE, identifier, initializer, locEq);
			ref<Node> type = _tree.newLeaf(Operator.EMPTY, location);
			return _tree.newDeclaration(type, x, location);
		} else if (t == Token.SEMI_COLON) {
			ref<Node> type = _tree.newLeaf(Operator.EMPTY, location);
			return _tree.newDeclaration(type, identifier, location);
		} else
			_scanner.pushBack(t);
		
		ref<Node> body = parseClass(context, identifier, _scanner.location());
		if (body.op() == Operator.SYNTAX_ERROR)
			return body;
		ref<Node> x = _tree.newBinary(context == ClassContext.INTERFACE ? Operator.INTERFACE_DECLARATION : Operator.CLASS_DECLARATION, identifier, body, location);
		return x;
	}

	private ref<Node> parseMonitorDeclaration() {
		SourceOffset location = _scanner.location();
		Token t = _scanner.next();

		if (t != Token.CLASS) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Identifier> identifier = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
		ref<Doclet> doclet = _scanner.extractDoclet();
		_tree.newDoclet(identifier, doclet);
		// Look ahead to get the correct location for the CLASS node.
		t = _scanner.next();
		_scanner.pushBack(t);
		ref<Node> body = parseClass(ClassContext.MONITOR, identifier, _scanner.location());
		if (body.op() == Operator.SYNTAX_ERROR)
			return body;
		ref<Node> x = _tree.newBinary(Operator.CLASS_DECLARATION, identifier, body, location);
		return x;
	}

	private ref<Node> parseFlagsDeclaration() {
		SourceOffset location = _scanner.location();
		Token t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Doclet> doclet = _scanner.extractDoclet();
		ref<Identifier> identifier = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
		_tree.newDoclet(identifier, doclet);
		t = _scanner.next();
		SourceOffset blockLoc = _scanner.location();
		if (t != Token.LEFT_CURLY) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		previous := _scanner.disableSemiColonElision();
		ref<Block> body = _tree.newBlock(Operator.FLAGS, false, _scanner.location());
		ref<Node> e = parseIdentifierList();
		body.statement(_tree.newNodeList(e));
		t = _scanner.next();
		_scanner.restoreSemiColonElision(previous);
		if (t != Token.RIGHT_CURLY) {
			if (e.op() != Operator.SYNTAX_ERROR) {
				ref<Node> err = _tree.newSyntaxError(_scanner.location());
				err.add(MessageId.SYNTAX_ERROR, _tree.pool());
				body.statement(_tree.newNodeList(err));
			}
			parseBlock(body);
		} else
			_scanner.preventSemiColon();
		return _tree.newBinary(Operator.FLAGS_DECLARATION, identifier, body, location);
	}

	private ref<Node> parseEnumDeclaration() {
		SourceOffset location = _scanner.location();
		Token t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Doclet> doclet = _scanner.extractDoclet();
		ref<Identifier> identifier = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
		_tree.newDoclet(identifier, doclet);
		t = _scanner.next();
		SourceOffset enumLoc = _scanner.location();
		if (t != Token.LEFT_CURLY) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Node> e = parseEnumInstanceList();

		t = _scanner.next();
		ref<ClassDeclarator> body = _tree.newClassDeclarator(Operator.ENUM, identifier, e, enumLoc);
		if (t == Token.RIGHT_CURLY) {
			_scanner.pushBack(_scanner.next());
			return body;
		} else if (t != Token.SEMI_COLON) {
			if (e.op() != Operator.SYNTAX_ERROR) {
				ref<Node> err = _tree.newSyntaxError(_scanner.location());
				err.add(MessageId.SYNTAX_ERROR, _tree.pool());
				body.statement(_tree.newNodeList(err));
			}
		}
		ref<ClassDeclarator> oldEnclosing = pushEnclosing(body);
		parseBlock(body);
		pushEnclosing(oldEnclosing);
		return body;
	}

	private ref<Node> parseEnumInstanceList() {
		ref<Node> e = null;
		SourceOffset commaLocation;
		Token t;
		for (;;) {
			t = _scanner.next();
			ref<Doclet> doclet = _scanner.extractDoclet();
			if (t == Token.IDENTIFIER) {
				ref<Node> x = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
				_tree.newDoclet(x, doclet);
				t = _scanner.next();
				SourceOffset location = _scanner.location();
				if (t == Token.LEFT_PARENTHESIS) {
					ref<NodeList> parameters;
					if (!parseParameterList(Token.RIGHT_PARENTHESIS, &parameters))
						return parameters.node;
					x = _tree.newCall(Operator.CALL, x, parameters, location);
					t = _scanner.next();
				}
				if (e != null)
					e = _tree.newBinary(Operator.SEQUENCE, e, x, commaLocation);
				else
					e = x;
				if (t == Token.COMMA)
					commaLocation = _scanner.location();
				else
					break;
			} else if (e != null)
				break;
			else {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
		}
		_scanner.pushBack(t);
		return e;
	}
	
	private ref<Node> parseIdentifierList() {
		ref<Node> e = null;
		SourceOffset commaLocation;
		Token t;
		for (;;) {
			t = _scanner.next();
			ref<Doclet> doclet = _scanner.extractDoclet();
			if (t == Token.IDENTIFIER) {
				ref<Node> x = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
				_tree.newDoclet(x, doclet);
				if (e != null)
					e = _tree.newBinary(Operator.SEQUENCE, e, x, commaLocation);
				else
					e = x;
				t = _scanner.next();
				if (t == Token.COMMA)
					commaLocation = _scanner.location();
				else
					break;
			} else if (e != null)
				break;
			else {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
		}
		_scanner.pushBack(t);
		return e;
	}
	
	private ref<Node> parseGeneralizedFor(ref<Node> initializer, SourceOffset location) {
		ref<Node> test;
		ref<Node> increment;
		ref<Node> body;
		Token t;

		t = _scanner.next();
		if (t == Token.SEMI_COLON)
			test = _tree.newLeaf(Operator.EMPTY, _scanner.location());
		else {
			_scanner.pushBack(t);
			test = parseExpression(0);
			if (test.op() == Operator.SYNTAX_ERROR)
				return test;
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
		}
		t = _scanner.next();
		if (t == Token.RIGHT_PARENTHESIS)
			increment = _tree.newLeaf(Operator.EMPTY, _scanner.location());
		else {
			_scanner.pushBack(t);
			increment = parseExpression(0);
			if (increment.op() == Operator.SYNTAX_ERROR)
				return increment;
			t = _scanner.next();
			if (t != Token.RIGHT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
		}
		_scanner.preventSemiColon();
		body = parseStatement();
		if (body.op() == Operator.SYNTAX_ERROR)
			return body;
		Operator op;
		if (initializer.op() == Operator.DECLARATION)
			op = Operator.SCOPED_FOR;
		else
			op = Operator.FOR;
		return _tree.newFor(op, initializer, test, increment, body, location);
	}

	private ref<Node> parseScopedFor(ref<Node> type, SourceOffset location) {
		ref<Identifier> id = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
		Token t = _scanner.next();
		if (t != Token.EQUALS) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		SourceOffset loc = _scanner.location();
		ref<Node> initializer = parseExpression(0);
		if (initializer.op() == Operator.SYNTAX_ERROR)
			return initializer;
		t = _scanner.next();
		if (t != Token.SEMI_COLON) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Node> x = _tree.newBinary(Operator.INITIALIZE, id, initializer, loc);
		x = _tree.newDeclaration(type, x, location);
		return parseGeneralizedFor(x, location);
	}

	private ref<Node> parseIteratorFor(ref<Node> iteratorVar, SourceOffset location) {
		if (iteratorVar.op() != Operator.IDENTIFIER)
			return resync(MessageId.SYNTAX_ERROR);
		ref<Loop> loop = _tree.newLoop(location);
		ref<Node> aggregate = parseExpression(0);
		if (aggregate.op() == Operator.SYNTAX_ERROR)
			return aggregate;
		Token t = _scanner.next();
		if (t != Token.RIGHT_PARENTHESIS) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		_scanner.preventSemiColon();
		ref<Node> body = parseStatement();
		if (body.op() == Operator.SYNTAX_ERROR)
			return body;
		loop.attachParts(ref<Identifier>(iteratorVar), aggregate, body);
		return loop;
	}

	private ref<Node> parseTerm(boolean inFunctionLiteral) {
		ref<Node> x;
		ref<Node> y;
		ref<FunctionDeclaration> func;

		Token t = _scanner.next();
		SourceOffset location = _scanner.location();
		
		switch (t) {
		case	NEW:
			t = _scanner.next();
			if (t == Token.LEFT_PARENTHESIS) {
				y = parseExpression(0);
				if (y.op() == Operator.SYNTAX_ERROR)
					return y;
				t = _scanner.next();
				if (t != Token.RIGHT_PARENTHESIS) {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
				x = parseTerm(false);
				if (x.op() == Operator.SYNTAX_ERROR)
					return x;
				return _tree.newBinary(Operator.PLACEMENT_NEW, y, x, location);
			} else
				_scanner.pushBack(t);
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newBinary(Operator.NEW, _tree.newLeaf(Operator.EMPTY, location), x, location);

		case	DELETE:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newBinary(Operator.DELETE, _tree.newLeaf(Operator.EMPTY, location), x, location);

		case	PLUS:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.UNARY_PLUS, x, location);

		case	DASH:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.NEGATE, x, location);

		case	PLUS_EQ:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.ADD_REDUCE, x, location);
			
		case	TILDE:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.BIT_COMPLEMENT, x, location);

		case	EXCLAMATION:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.NOT, x, location);

		case	AMPERSAND:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.ADDRESS, x, location);

		case	ASTERISK:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.INDIRECT, x, location);

		case	PLUS_PLUS:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.INCREMENT_BEFORE, x, location);

		case	DASH_DASH:
			x = parseTerm(false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			return _tree.newUnary(Operator.DECREMENT_BEFORE, x, location);

		case	CLASS:
			x = parseClass(ClassContext.CLASS, null, _scanner.location());
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			break;

		case	IDENTIFIER:
			x = _tree.newIdentifier(/*null, */_scanner.value(), location);
			break;

		case	INTEGER:
			x = _tree.newConstant(Operator.INTEGER, _scanner.value(), location);
			break;

		case	INTEGER_DOT:
			x = _tree.newConstant(Operator.INTEGER, _scanner.value(), location);
			x = parseDotOperand(x);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			break;
			
		case	FLOATING_POINT:
			x = _tree.newConstant(Operator.FLOATING_POINT, _scanner.value(), location);
			break;

		case	CHARACTER:
			x = _tree.newConstant(Operator.CHARACTER, _scanner.value(), location);
			break;

		case	STRING:
			x = _tree.newConstant(Operator.STRING, _scanner.value(), location);
			break;

		case	THIS:
			x = _tree.newLeaf(Operator.THIS, location);
			break;

		case	SELF:
			x = _tree.newLeaf(Operator.SELF, location);
			break;
			
		case	SUPER:
			x = _tree.newLeaf(Operator.SUPER, location);
			break;

		case	TRUE:
			x = _tree.newLeaf(Operator.TRUE, location);
			break;

		case	FALSE:
			x = _tree.newLeaf(Operator.FALSE, location);
			break;

		case	NULL:
			x = _tree.newLeaf(Operator.NULL, location);
			break;

		case	VOID:
			x = _tree.newLeaf(Operator.VOID, location);
			break;

		case	LEFT_PARENTHESIS:
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t != Token.RIGHT_PARENTHESIS) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			break;

		case	LEFT_SQUARE:
		case	LEFT_CURLY:
			x = parseAggregateInitializer(t);
			break;
			
		case	FUNCTION:
			x = parseTerm(true);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			if (x.op() != Operator.FUNCTION)
				return resync(MessageId.SYNTAX_ERROR);
			break;

		case	ELSE:
			x = _tree.newSyntaxError(_scanner.location());
			x.add(MessageId.NOT_EXPECTING_ELSE, _tree.pool(), _scanner.value());
			return x;

		default:
			_scanner.pushBack(t);
			return resync(MessageId.EXPECTING_TERM);
		}
		for (;;) {
			ref<NodeList> parameters;
			t = _scanner.next();
			location = _scanner.location();
			switch (t) {
			case	PLUS_PLUS:
				x = _tree.newUnary(Operator.INCREMENT_AFTER, x, location);
				break;

			case	DASH_DASH:
				x = _tree.newUnary(Operator.DECREMENT_AFTER, x, location);
				break;

			case	LEFT_PARENTHESIS:
				if (!parseParameterList(Token.RIGHT_PARENTHESIS, &parameters))
					return parameters.node;
				if (inFunctionLiteral) {
					t = _scanner.next();
					ref<FunctionDeclaration> func = _tree.newFunctionDeclaration(FunctionDeclaration.Category.NORMAL, x, null, parameters, location);
					if (t == Token.LOCK) {
						ref<Node> n = parseLockStatement();
						if (n.op() == Operator.SYNTAX_ERROR)
							return n;
						func.body = _tree.newBlock(Operator.BLOCK, false, n.location());
						func.body.statement(_tree.newNodeList(n));						
					} else if (t == Token.LEFT_CURLY) {
						func.body = _tree.newBlock(Operator.BLOCK, false, _scanner.location());
						parseBlock(func.body);
					} else {
						_scanner.pushBack(t);
						x = _tree.newFunctionDeclaration(FunctionDeclaration.Category.DECLARATOR, x, null, parameters, location);
						break;
					}
					return func;
				} else // This is provisional.  It may be a call, a cast or a function declarator depending on context
					x = _tree.newCall(Operator.CALL, x, parameters, location);
				break;

			case	LEFT_ANGLE:
				if (!parseParameterList(Token.RIGHT_ANGLE, &parameters))
					return parameters.node;
				x = _tree.newCall(Operator.TEMPLATE_INSTANCE, x, parameters, location);
				break;

			case	ELLIPSIS:
				x = _tree.newUnary(Operator.ELLIPSIS, x, location);
				break;

			case	LEFT_SQUARE:
				t = _scanner.next();
				if (t == Token.RIGHT_SQUARE)
					x = _tree.newUnary(Operator.VECTOR_OF, x, location);
				else {
					_scanner.pushBack(t);
					y = parseExpression(0);
					if (y.op() == Operator.SYNTAX_ERROR)
						return y;
					t = _scanner.next();
					if (t == Token.COLON) {
						ref<Node> seed;
						t = _scanner.next();
						if (t == Token.RIGHT_SQUARE)
							seed = _tree.newLeaf(Operator.EMPTY, _scanner.location());
						else {
							_scanner.pushBack(t);
							seed = parseExpression(0);
							if (seed.op() == Operator.SYNTAX_ERROR)
								return seed;
							t = _scanner.next();
							if (t != Token.RIGHT_SQUARE) {
								_scanner.pushBack(t);
								return resync(MessageId.EXPECTING_RS);
							}
						}
						x = _tree.newMap(x, y, seed, location);
					} else if (t == Token.RIGHT_SQUARE)
						x = _tree.newBinary(Operator.SUBSCRIPT, x, y, location);
					else {
						_scanner.pushBack(t);
						return resync(MessageId.EXPECTING_RS);
					}
				}
				break;

			case	DOT:
				x = parseDotOperand(x);
				if (x.op() == Operator.SYNTAX_ERROR)
					return x;
				break;

			case	ERROR:
				return resync(MessageId.SYNTAX_ERROR);

			default:
				_scanner.pushBack(t);
				return x;
			}
		}
	}

	private ref<Node> parseDotOperand(ref<Node> x) {
		Token t = _scanner.next();
		SourceOffset location = _scanner.location();
		switch (t) {
		case	BYTES:
			return _tree.newUnary(Operator.BYTES, x, location);
			
		case	TILDE:
			t = _scanner.next();
			if (t != Token.LEFT_PARENTHESIS)
				break;
			t = _scanner.next();
			if (t != Token.RIGHT_PARENTHESIS)
				break;
			return _tree.newUnary(Operator.CALL_DESTRUCTOR, x, location);
			
		case	CLASS:
			return _tree.newUnary(Operator.CLASS_OF, x, location);
			
		case	IDENTIFIER:
			return _tree.newSelection(x, _scanner.value(), location);
		}
		_scanner.pushBack(t);
		return resync(MessageId.SYNTAX_ERROR);
	}

	private ref<Node> parseAggregateInitializer(Token startingToken) {
		Token endingToken;
		SourceOffset location = _scanner.location();
		
		if (startingToken == Token.LEFT_SQUARE)
			endingToken = Token.RIGHT_SQUARE;
		else
			endingToken = Token.RIGHT_CURLY;
		ref<Node>[] leftHandle;
		previous := _scanner.disableSemiColonElision();
		for (;;) {
			Token t = _scanner.next();
			if (t == endingToken)
				break;
			_scanner.pushBack(t);
			ref<Node> x = parseExpression(1);
			leftHandle.append(x);
			if (x.op() == Operator.SYNTAX_ERROR) {
				if (endingToken == Token.RIGHT_SQUARE)
					break;
				t = _scanner.next();
				if (t == Token.RIGHT_CURLY || t == Token.END_OF_STREAM)
					break;				// This will bail us out of the aggregate
				_scanner.pushBack(t);
				continue;
			}
			t = _scanner.next();
			if (t == endingToken)
				break;
			else if (t == Token.COLON) {
				SourceOffset labLoc = _scanner.location();
				ref<Node> y = parseExpression(1);
				x = _tree.newBinary(Operator.LABEL, x, y, labLoc);
				int last = leftHandle.length() - 1;
				leftHandle[last] = x;
				if (y.op() == Operator.SYNTAX_ERROR) {
					if (endingToken == Token.RIGHT_SQUARE)
						break;
					t = _scanner.next();
					if (t == Token.RIGHT_CURLY || t == Token.END_OF_STREAM)
						break;				// This will bail us out of the aggregate
					_scanner.pushBack(t);
					continue;
				}
				t = _scanner.next();
				if (t == endingToken)
					break;
				else if (t != Token.COMMA) {
					_scanner.pushBack(t);
					_scanner.restoreSemiColonElision(previous);
					return resync(MessageId.SYNTAX_ERROR);
				}
			} else if (t != Token.COMMA) {
				_scanner.pushBack(t);
				_scanner.restoreSemiColonElision(previous);
				return resync(MessageId.SYNTAX_ERROR);
			}
		}
		_scanner.restoreSemiColonElision(previous);
		return _tree.newCall(startingToken == Token.LEFT_SQUARE ? Operator.ARRAY_AGGREGATE : Operator.OBJECT_AGGREGATE, null, 
				leftHandle.length() > 0 ? _tree.newNodeList(leftHandle) : null, location);
	}
	
	private ref<Node> parseTemplateList(ref<Template> templateDef) {
		for (;;) {
			Token t = _scanner.next();
			ref<Node> annotations = null;
			if (t == Token.ANNOTATION) {
				annotations = parseAnnotations();
				if (annotations.op() == Operator.SYNTAX_ERROR)
					return annotations;
				t = _scanner.next();
			}
			SourceOffset aLoc = _scanner.location();
			ref<Node> name;
			ref<Node> type;
			switch (t) {
			case	CLASS: {
				SourceOffset loc = _scanner.location();
				t = _scanner.next();
				if (t != Token.IDENTIFIER) {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
				type = _tree.newLeaf(Operator.CLASS_TYPE, loc);
				name = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
				ref<Node> bind = _tree.newBinary(Operator.BIND, type, name, _scanner.location());
				if (annotations != null)
					bind = _tree.newBinary(Operator.ANNOTATED, annotations, bind, aLoc);
				templateDef.templateArgument(_tree.newNodeList(bind));
				t = _scanner.next();
			}	break;
			
			case	ENUM: {
				SourceOffset loc = _scanner.location();
				t = _scanner.next();
				if (t != Token.IDENTIFIER) {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
				type = _tree.newLeaf(Operator.ENUM_TYPE, loc);
				name = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
				ref<Node> bind = _tree.newBinary(Operator.BIND, type, name, _scanner.location());
				if (annotations != null)
					bind = _tree.newBinary(Operator.ANNOTATED, annotations, bind, aLoc);
				templateDef.templateArgument(_tree.newNodeList(bind));
				t = _scanner.next();
			}	break;

			default:
				_scanner.pushBack(t);
				type = parseExpression(1);
				if (type.op() == Operator.SYNTAX_ERROR)
					return type;
				t = _scanner.next();
				if (t == Token.ANNOTATION ||
					t == Token.IDENTIFIER) {
					SourceOffset location = _scanner.location();
					name = parseName(t);
					if (name.op() == Operator.SYNTAX_ERROR)
						return name;
					ref<Node> bind = _tree.newBinary(Operator.BIND, type, name, location);
					if (annotations != null)
						bind = _tree.newBinary(Operator.ANNOTATED, annotations, bind, aLoc);
					templateDef.templateArgument(_tree.newNodeList(bind));
					t = _scanner.next();
				} else {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
			}
			ref<Identifier> id = ref<Identifier>(name);
			if (t != Token.COMMA) {
				if (t == Token.RIGHT_ANGLE)
					break;
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
		}
		return templateDef;
	}

	private boolean parseParameterList(Token delimiter, ref<ref<NodeList>> results) {
		Token t = _scanner.next();
		if (t == delimiter) {
			*results = null;
			return true;
		}
		_scanner.pushBack(t);
		ref<NodeList> last = null;
		for (;;) {
			t = _scanner.next();
			ref<Node> annotations = null;
			SourceOffset aLoc;
			if (t == Token.ANNOTATION) {
				annotations = parseAnnotations();
				if (annotations.op() == Operator.SYNTAX_ERROR) {
					*results = _tree.newNodeList(annotations);
					return false;
				}
				aLoc = _scanner.location();
			} else
				_scanner.pushBack(t);
			ref<Node> type = parseExpression(1);
			ref<Node> name;
			if (type.op() == Operator.SYNTAX_ERROR) {
				*results = _tree.newNodeList(type);
				return false;
			}
			t = _scanner.next();
			ref<Node> argument;
			if (t == Token.ANNOTATION ||
				t == Token.IDENTIFIER) {
				SourceOffset location = _scanner.location();
				name = parseName(t);
				if (name.op() == Operator.SYNTAX_ERROR) {
					*results = _tree.newNodeList(name);
					return false;
				}
				t = _scanner.next();
				if (t == Token.LEFT_PARENTHESIS) {
					SourceOffset loc = _scanner.location();
					ref<NodeList> parameters;
					if (!parseParameterList(Token.RIGHT_PARENTHESIS, &parameters)) {
						*results = _tree.newNodeList(parameters.node);
						return false;
					}
					argument = _tree.newFunctionDeclaration(FunctionDeclaration.Category.NORMAL, type, ref<Identifier>(name), parameters, loc);
					t = _scanner.next();
				} else
					argument = _tree.newBinary(Operator.BIND, type, name, location);
			} else
				argument = type;
			if (annotations != null)
				argument = _tree.newBinary(Operator.ANNOTATED, annotations, argument, aLoc);
			ref<NodeList> nl = _tree.newNodeList(argument);
			if (last != null)
				last.next = nl;
			else
				*results = nl;
			last = nl;
			if (t != Token.COMMA) {
				if (t == delimiter)
					break;
				_scanner.pushBack(t);
				*results = _tree.newNodeList(resync(MessageId.SYNTAX_ERROR));
				return false;
			}
		}
		return true;
	}

	private ref<Node> parseName(Token t) {
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		return _tree.newIdentifier(_scanner.value(), _scanner.location());
	}

	private ref<Node> parseAnnotations() {
		ref<Node> list = null;
		for (;;) {
			ref<Node> id = _tree.newIdentifier(/*null, */_scanner.value(), _scanner.location());
			Token t = _scanner.next();
			SourceOffset location = _scanner.location();

			ref<NodeList> arguments = null;
			ref<NodeList> last = null;
			if (t == Token.LEFT_PARENTHESIS) {
				previous := _scanner.disableSemiColonElision();
				t = _scanner.next();
				if (t != Token.RIGHT_PARENTHESIS) {
					_scanner.pushBack(t);
					for (;;) {
						ref<Node> annotationArguments = parseExpression(binaryOperators.precedence(Operator.ASSIGN));
						if (annotationArguments.op() == Operator.SYNTAX_ERROR) {
							_scanner.restoreSemiColonElision(previous);
							return annotationArguments;
						}
						ref<NodeList> nl = _tree.newNodeList(annotationArguments);
						if (last != null)
							last.next = nl;
						else
							arguments = nl;
						last = nl;
						t = _scanner.next();
						if (t == Token.RIGHT_PARENTHESIS)
							break;
						else if (t != Token.COMMA) {
							_scanner.pushBack(t);
							return resync(MessageId.SYNTAX_ERROR);
						}
					}
				}
				_scanner.pushBack(_scanner.next());
				_scanner.restoreSemiColonElision(previous);
			} else
				_scanner.pushBack(t);
			ref<Call> annotation = _tree.newCall(Operator.ANNOTATION, id, arguments, location);
			if (list == null)
				list = annotation;
			else
				list = _tree.newBinary(Operator.SEQUENCE, list, annotation, id.location());

			t = _scanner.next();
			if (t != Token.ANNOTATION) {
				_scanner.pushBack(t);
				return list;
			}
		}
	}

	private enum ClassContext {
		INTERFACE,
		CLASS,
		MONITOR
	}

	private ref<Node> parseClass(ClassContext context, ref<Identifier> name, SourceOffset location) {
		ref<Node> extendsClause = null;
		ref<Node> implementsClause = null;
		ref<ClassDeclarator> classDef;
		ref<Template> templateDef = null;

		Token t = _scanner.next();
		if (t == Token.LEFT_ANGLE) {
			templateDef = _tree.newTemplate(name, location);
			ref<Node> templ = parseTemplateList(templateDef);
			if (templ.op() == Operator.SYNTAX_ERROR)
				return templ;
			t = _scanner.next();
			location = _scanner.location();
		}
		if (t == Token.EXTENDS) {
			extendsClause = parseExpression(0);
			if (extendsClause.op() == Operator.SYNTAX_ERROR)
				return extendsClause;
			t = _scanner.next();
		}
		classDef = _tree.newClassDeclarator(context == ClassContext.MONITOR ? Operator.MONITOR_CLASS : Operator.CLASS, name, extendsClause, location);
		if (context != ClassContext.INTERFACE && t == Token.IMPLEMENTS) {
			do {
				implementsClause = parseExpression(1);
				if (implementsClause.op() == Operator.SYNTAX_ERROR)
					return implementsClause;
				classDef.addInterface(_tree.newNodeList(implementsClause));
				t = _scanner.next();
			} while (t == Token.COMMA);
		}
		if (t != Token.LEFT_CURLY) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<ClassDeclarator> oldEnclosing = pushEnclosing(classDef);
		if (context != ClassContext.INTERFACE)
			parseBlock(classDef);
		else
			parseInterface(classDef);
		pushEnclosing(oldEnclosing);
		if (templateDef != null) {
			templateDef.classDef = classDef;
			return templateDef;
		} else
			return classDef;
	}

	private ref<Node> resync(MessageId messageId) {
		Token t = _scanner.next();
		if (t == Token.ERROR)
			messageId = MessageId.BAD_TOKEN;
		_scanner.pushBack(t);
		ref<Node> result = _tree.newSyntaxError(_scanner.location());
		result.add(messageId, _tree.pool(), _scanner.value());
		for (;;) {
			t = _scanner.next();
			switch (t) {
			case	LEFT_CURLY:
			case	RIGHT_CURLY:
				_scanner.pushBack(t);
				return result;

			case	END_OF_STREAM:
			case	SEMI_COLON:
				return result;
			}
		}
	}

	private ref<Node> syntaxError(MessageId messageId) {
		ref<Node> result = _tree.newSyntaxError(_scanner.location());
		result.add(messageId, _tree.pool());
		return result;
	}

	private ref<ClassDeclarator> pushEnclosing(ref<ClassDeclarator> enclosing) {
		ref<ClassDeclarator> c = _enclosing;
		_enclosing = enclosing;
		return c;
	}

	private ref<Identifier> enclosingClassName() {
		if (_enclosing == null)
			return null;
		else
			return _enclosing.className();
	}

	private boolean isClassName(ref<Node> n) {
		if (n.op() != Operator.IDENTIFIER)
			return false;
		ref<Identifier> id = ref<Identifier>(n);
		substring ss = enclosingClassName().identifier();
//		printf("isClassName %s == %s -> %s\n", id.identifier(), ss, id.identifier() == ss);
		return id.identifier() == ss;
	}
}

private BinaryOperators binaryOperators;

class BinaryOperators {
	private int[Operator] _precedence;
	private Operator[Token] _operators;

	public BinaryOperators() {
		_precedence.resize(Operator.MAX_OPERATOR);
		_operators.resize(Token.MAX_TOKEN);
		for (int i = 0; i < int(Token.MAX_TOKEN); i++)
			_operators[Token(i)] = Operator.SYNTAX_ERROR;

		int precedence = 1;

		define(Operator.SEQUENCE, Token.COMMA, precedence);

		precedence++;

		define(Operator.DEF_ASSIGN, Token.CO_EQ, precedence);
		define(Operator.ASSIGN, Token.EQUALS, precedence);
		define(Operator.DIVIDE_ASSIGN, Token.SLASH_EQ, precedence);
		define(Operator.REMAINDER_ASSIGN, Token.PERCENT_EQ, precedence);
		define(Operator.MULTIPLY_ASSIGN, Token.ASTERISK_EQ, precedence);
		define(Operator.ADD_ASSIGN, Token.PLUS_EQ, precedence);
		define(Operator.SUBTRACT_ASSIGN, Token.DASH_EQ, precedence);
		define(Operator.AND_ASSIGN, Token.AMPERSAND_EQ, precedence);
		define(Operator.EXCLUSIVE_OR_ASSIGN, Token.CARET_EQ, precedence);
		define(Operator.OR_ASSIGN, Token.VERTICAL_BAR_EQ, precedence);
		define(Operator.LEFT_SHIFT_ASSIGN, Token.LA_LA_EQ, precedence);
		define(Operator.RIGHT_SHIFT_ASSIGN, Token.RA_RA_EQ, precedence);
		define(Operator.UNSIGNED_RIGHT_SHIFT_ASSIGN, Token.RA_RA_RA_EQ, precedence);

		precedence++;

		define(Operator.CONDITIONAL, Token.QUESTION_MARK, precedence);

		precedence++;

		define(Operator.NEW, Token.NEW, precedence);
		define(Operator.DELETE, Token.DELETE, precedence);

		precedence++;

		define(Operator.LOGICAL_AND, Token.AMP_AMP, precedence);
		define(Operator.LOGICAL_OR, Token.VBAR_VBAR, precedence);

		precedence++;

		define(Operator.AND, Token.AMPERSAND, precedence);
		define(Operator.EXCLUSIVE_OR, Token.CARET, precedence);
		define(Operator.OR, Token.VERTICAL_BAR, precedence);

		precedence++;

		define(Operator.LESS, Token.SP_LA, precedence);
		define(Operator.GREATER, Token.SP_RA, precedence);
		define(Operator.LESS_EQUAL, Token.LA_EQ, precedence);
		define(Operator.GREATER_EQUAL, Token.RA_EQ, precedence);
		define(Operator.LESS_GREATER, Token.LA_RA, precedence);
		define(Operator.LESS_GREATER_EQUAL, Token.LA_RA_EQ, precedence);
		define(Operator.NOT_LESS, Token.EX_LA, precedence);
		define(Operator.NOT_GREATER, Token.EX_RA, precedence);
		define(Operator.NOT_LESS_EQUAL, Token.EX_LA_EQ, precedence);
		define(Operator.NOT_GREATER_EQUAL, Token.EX_RA_EQ, precedence);
		define(Operator.NOT_LESS_GREATER, Token.EX_LA_RA, precedence);
		define(Operator.NOT_LESS_GREATER_EQUAL, Token.EX_LA_RA_EQ, precedence);

		precedence++;

		define(Operator.EQUALITY, Token.EQ_EQ, precedence);
		define(Operator.NOT_EQUAL, Token.EXCLAMATION_EQ, precedence);
		define(Operator.IDENTITY, Token.EQ_EQ_EQ, precedence);
		define(Operator.NOT_IDENTITY, Token.EX_EQ_EQ, precedence);

		precedence++;

		define(Operator.DOT_DOT, Token.DOT_DOT, precedence);

		precedence++;

		define(Operator.LEFT_SHIFT, Token.LA_LA, precedence);
		define(Operator.RIGHT_SHIFT, Token.RA_RA, precedence);
		define(Operator.UNSIGNED_RIGHT_SHIFT, Token.RA_RA_RA, precedence);

		precedence++;

		define(Operator.ADD, Token.PLUS, precedence);
		define(Operator.SUBTRACT, Token.DASH, precedence);

		precedence++;

		define(Operator.DIVIDE, Token.SLASH, precedence);
		define(Operator.REMAINDER, Token.PERCENT, precedence);
		define(Operator.MULTIPLY, Token.ASTERISK, precedence);
	}

	public int precedence(Operator op) {
		return _precedence[op];
	}

	public Operator binaryOperator(Token t) {
		return _operators[t];
	}

	private void define(Operator op, Token t, int precedence) {
		_precedence[op] = precedence;
		_operators[t] = op;
	}
}

private TraverseAction setOnError(ref<Node> n, address data) {
	if (n.op() == Operator.SYNTAX_ERROR) {
		ref<boolean> b = ref<boolean>(data);
		*b = true;
		return TraverseAction.ABORT_TRAVERSAL;
	}
	return TraverseAction.CONTINUE_TRAVERSAL;
}

public boolean containsErrors(ref<Node> tree) {
	boolean anyErrors = false;
	tree.traverse(Node.Traversal.REVERSE_POST_ORDER, setOnError, &anyErrors);
	return anyErrors;
}

