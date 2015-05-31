namespace parasol:compiler;

class Parser {
	private ref<SyntaxTree> _tree;
	private ref<Scanner> _scanner;
	private ref<Class> _enclosing;

	public Parser(ref<SyntaxTree> tree, ref<Scanner> scanner) {
		_tree = tree;
		_scanner = scanner;
	}

	public ref<Block> parseFile() {
		ref<Block> block = _tree.newBlock(Operator.UNIT, _scanner.location());
		for (;;) {
			Token t = _scanner.next();
			CompileString cs = _scanner.value();
			int line = _scanner.lineNumber(_scanner.location());
			string s(cs.data, cs.length);
//			printf("Token %d %s %d\n", int(t), s, line);
			if (t == Token.END_OF_STREAM)
				return block;
			_scanner.pushBack(t);
			block.statement(_tree.newNodeList(parseStatement()));
		}
	}

	public ref<Node> parseStatement() {
		Token t;
		ref<Node> annotations = null;
		Location location;

		t = _scanner.next();
		location = _scanner.location();
		if (t == Token.ANNOTATION) {
			annotations = parseAnnotations();
			if (annotations.op() == Operator.SYNTAX_ERROR)
				return annotations;
		} else
			_scanner.pushBack(t);
		ref<Node> x = parseBareStatement();
		if (x.op() == Operator.SYNTAX_ERROR)
			return x;
		if (annotations != null)
			x = _tree.newBinary(Operator.ANNOTATED, annotations, x, x.location());
		return x;
	}

	public ref<Node> parseExpression(int precedence) {
		ref<Node> left = parseTerm(false);
		if (left.op() == Operator.SYNTAX_ERROR)
			return left;
		for (;;) {
			Token t = _scanner.next();
			Location loc = _scanner.location();
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
		for (;;) {
			Token t = _scanner.next();
			if (t == Token.RIGHT_CURLY) {
				return block;
			} else if (t == Token.END_OF_STREAM) {
				block.statement(_tree.newNodeList(syntaxError(MessageId.UNEXPECTED_EOF)));
				return block;
			}
			_scanner.pushBack(t);
			block.statement(_tree.newNodeList(parseStatement()));
		}
	}

	private ref<Node> parseBareStatement() {
		Token t;
		Location location;
		ref<Node> truePart;
		ref<Node> falsePart;
		ref<Node> x;

		t = _scanner.next();
		location = _scanner.location();
		switch (t) {
		case	SEMI_COLON:
			return _tree.newLeaf(Operator.EMPTY, location);

		case	LEFT_CURLY:
			x = parseBlock(_tree.newBlock(Operator.BLOCK, location));
			return x;

		case	BREAK:
			t = _scanner.next();
			if (t != Token.SEMI_COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.BREAK_NO_SEMI);
			}
			return _tree.newLeaf(Operator.BREAK, location);

		case	CASE:
			x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t != Token.COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.CASE_NO_CO);
			}
			t = _scanner.next();
			_scanner.pushBack(t);
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
			return _tree.newLeaf(Operator.CONTINUE, location);

		case	DEFAULT:
			t = _scanner.next();
			if (t != Token.COLON) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			t = _scanner.next();
			_scanner.pushBack(t);
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
				return parseCollectionFor(x, location);
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
			truePart = parseStatement();
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
			truePart = parseStatement();
			if (truePart.op() == Operator.SYNTAX_ERROR)
				return truePart;
			return _tree.newBinary(Operator.WHILE, x, truePart, location);

		case	PUBLIC:
			return parseVisibleDeclaration(Operator.PUBLIC);

		case	PRIVATE:
			return parseVisibleDeclaration(Operator.PRIVATE);

		case	PROTECTED:
			return parseVisibleDeclaration(Operator.PROTECTED);

		case	FINAL:
			return parseFinalDeclaration();

		case	CLASS:
			return parseClassDeclaration();
		
		case	ENUM:
			return parseEnumDeclaration();

		case	ABSTRACT:
			return parseAbstractDeclaration();

		case	STATIC:
			return parseStaticDeclaration();

		case	IMPORT:
			return parseImportStatement();

		case	NAMESPACE:
			x = parseNamespace(null, false);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			t = _scanner.next();
			if (t == Token.SEMI_COLON)
				return _tree.newUnary(Operator.DECLARE_NAMESPACE, x, location);;
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
			return parseDeclaration(x, location);
		}
		return null;
	}

	private ref<Node> parseImportStatement() {
		Location location = _scanner.location();
		Token t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Identifier> importedSymbol = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
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
		Location location = _scanner.location();
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
			stem = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
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
		Location lastIdentifier = _scanner.location();
		for (;;) {
			t = _scanner.next();
			_scanner.seek(lastIdentifier);
			_scanner.next();
			if (t != Token.DOT) {
				if (lastName != null)
					*lastName = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
				else
					stem = _tree.newSelection(stem, _scanner.value(), _scanner.location());
				return stem;
			} else
				stem = _tree.newSelection(stem, _scanner.value(), _scanner.location());
			_scanner.next(); // The Token.DOT again
			t = _scanner.next();
			if (t != Token.IDENTIFIER) {
				_scanner.pushBack(t);
				return resync(MessageId.SYNTAX_ERROR);
			}
			lastIdentifier = _scanner.location();
		}
	}

	private ref<Node> parseVisibleDeclaration(Operator visibility) {
		Location location = _scanner.location();
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

		case	CLASS:
			n = parseClassDeclaration();
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
			n = parseDeclaration(x, location);
			if (n.op() == Operator.SYNTAX_ERROR)
				return n;
		}
		return _tree.newUnary(visibility, n, location);
	}

	private ref<Node> parseAbstractDeclaration() {
		Location location = _scanner.location();
		ref<Node> returnType = parseExpression(0);
		if (returnType.op() == Operator.SYNTAX_ERROR)
			return returnType;
		ref<Node> name = parseName(_scanner.next());
		if (name.op() == Operator.SYNTAX_ERROR)
			return name;
		ref<Identifier> id = ref<Identifier>(name);
		Token t = _scanner.next();
		Location loc = _scanner.location();
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
		ref<Function> func = _tree.newFunction(Function.Category.ABSTRACT, returnType, id, parameters, loc);
		return _tree.newUnary(Operator.ABSTRACT, func, location);
	}

	private ref<Node> parseStaticDeclaration() {
		Location location = _scanner.location();
		ref<Node> x = parseExpression(0);
		if (x.op() == Operator.SYNTAX_ERROR)
			return x;
		ref<Node> n = parseDeclaration(x, location);
		if (n.op() == Operator.SYNTAX_ERROR)
			return n;
		return _tree.newUnary(Operator.STATIC, n, location);
	}

	ref<Node> parseFinalDeclaration() {
		Location location = _scanner.location();
		Token t = _scanner.next();
		ref<Node> n;
		if (t == Token.CLASS) {
			n = parseClassDeclaration();
		} else {
			Location loc = _scanner.location();
			_scanner.pushBack(t);
			ref<Node> x = parseExpression(0);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			n = parseDeclaration(x, loc);
		}
		if (n.op() == Operator.SYNTAX_ERROR)
			return n;
		return _tree.newUnary(Operator.FINAL, n, location);
	}

	private ref<Node> parseConstructor(ref<Call> declarator) {
		ref<Function> func = _tree.newFunction(Function.Category.CONSTRUCTOR, null, ref<Identifier>(declarator.target()), declarator.arguments(), declarator.location());
		Token t = _scanner.next();
		if (t == Token.LEFT_CURLY) {
			func.body = _tree.newBlock(Operator.BLOCK, _scanner.location());
			parseBlock(func.body);
		} else {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		return func;
	}

	private ref<Node> parseDestructor(ref<Call> declarator) {
		ref<Function> func = _tree.newFunction(Function.Category.DESTRUCTOR, null, ref<Identifier>(declarator.target()), declarator.arguments(), declarator.location());
		if (declarator.arguments() != null) {
			declarator.arguments().node.add(MessageId.NO_PARAMS_IN_DESTRUCTOR, _tree.pool());
		}
		Token t = _scanner.next();
		if (t == Token.LEFT_CURLY) {
			func.body = _tree.newBlock(Operator.BLOCK, _scanner.location());
			parseBlock(func.body);
		} else {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		return func;
	}

	private ref<Node> parseDeclaration(ref<Node> type, Location location) {
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
				if (isClassName(call.target()))
					return parseConstructor(call);
				break;

			default:
				break;
			}
		}
		Token t = _scanner.next();
		if (t == Token.IDENTIFIER ||
			t == Token.ANNOTATION) {
			ref<Node> x = parseName(t);
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			ref<Node> initializer;
			ref<Function> func;
			ref<Identifier> id = ref<Identifier>(x);
			t = _scanner.next();
			Location loc = _scanner.location();
			ref<NodeList> parameters;
			switch (t) {
			case	LEFT_PARENTHESIS:
				if (!parseParameterList(Token.RIGHT_PARENTHESIS, &parameters))
					return parameters.node;
				if (parameters == null || parameters.hasBindings()) {
					func = _tree.newFunction(Function.Category.NORMAL, type, id, parameters, loc);
					t = _scanner.next();
					if (t == Token.LEFT_CURLY) {
						func.body = _tree.newBlock(Operator.BLOCK, _scanner.location());
						parseBlock(func.body);
					} else if (t != Token.SEMI_COLON) {
						_scanner.pushBack(t);
						return resync(MessageId.SYNTAX_ERROR);
					} 
					return func;
				} else {
					t = _scanner.next();
					if (t == Token.SEMI_COLON) {
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
				if (initializer.op() == Operator.SYNTAX_ERROR)
					return initializer;
				x = _tree.newBinary(Operator.INITIALIZE, id, initializer, loc);
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
						Location locEq = _scanner.location();
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

	private ref<Node> parseClassDeclaration() {
		Location location = _scanner.location();
		Token t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Identifier> identifier = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
		// Look ahead to get the correct location for the CLASS node.
		_scanner.pushBack(_scanner.next());
		ref<Node> body = parseClass(identifier, _scanner.location());
		if (body.op() == Operator.SYNTAX_ERROR)
			return body;
		ref<Node> x = _tree.newBinary(Operator.CLASS_DECLARATION, identifier, body, location);
		return x;
	}

	private ref<Node> parseEnumDeclaration() {
		Location location = _scanner.location();
		Token t = _scanner.next();
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Identifier> identifier = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
		t = _scanner.next();
		Location blockLoc = _scanner.location();
		if (t != Token.LEFT_CURLY) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Block> body = _tree.newBlock(Operator.ENUM, _scanner.location());
		ref<Node> e = parseExpression(0);
		body.statement(_tree.newNodeList(e));
		t = _scanner.next();
		if (t == Token.SEMI_COLON) {
			parseBlock(body);
		} else if (t != Token.RIGHT_CURLY) {
			if (e.op() != Operator.SYNTAX_ERROR) {
				ref<Node> err = _tree.newSyntaxError(_scanner.location());
				err.add(MessageId.SYNTAX_ERROR, _tree.pool());
				body.statement(_tree.newNodeList(err));
			}
			parseBlock(body);
		}
		return _tree.newBinary(Operator.ENUM_DECLARATION, identifier, body, location);
	}

	private ref<Node> parseGeneralizedFor(ref<Node> initializer, Location location) {
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

	private ref<Node> parseCollectionFor(ref<Node> type, Location location) {
		ref<Identifier> id = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
		Token t = _scanner.next();
		if (t == Token.EQUALS) {
			Location loc = _scanner.location();
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
		if (t != Token.COLON) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Loop> loop = _tree.newLoop(location);
		ref<Node> declarator = _tree.newBinary(Operator.BIND, type, id, id.location());
		ref<Node> aggregate = parseExpression(0);
		if (aggregate.op() == Operator.SYNTAX_ERROR)
			return aggregate;
		t = _scanner.next();
		if (t != Token.RIGHT_PARENTHESIS) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Node> body = parseStatement();
		if (body.op() == Operator.SYNTAX_ERROR)
			return body;
		loop.attachParts(declarator, aggregate, body);
		return loop;
	}

	private ref<Node> parseTerm(boolean inFunctionLiteral) {
		ref<Node> x;
		ref<Node> y;
		ref<Function> func;

		Token t = _scanner.next();
		Location location = _scanner.location();
		switch (t) {

		case	NEW:
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
			x = parseClass(null, _scanner.location());
			if (x.op() == Operator.SYNTAX_ERROR)
				return x;
			break;

		case	IDENTIFIER:
			x = _tree.newIdentifier(null, _scanner.value(), location);
			break;

		case	INTEGER:
			x = _tree.newConstant(Operator.INTEGER, _scanner.value(), location);
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

		case	FUNCTION:
			t = _scanner.next();
			if (t != Token.LEFT_CURLY) {
				_scanner.pushBack(t);
				x = parseTerm(true);
				if (x.op() == Operator.SYNTAX_ERROR)
					return x;
				t = _scanner.next();
				if (t != Token.LEFT_CURLY) {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
				switch (x.op()) {
				case	FUNCTION:
					func = ref<Function>(x);
					break;

				case	IDENTIFIER:
				case	VECTOR_OF:
				case	TEMPLATE:
				case	CLASS:
				case	MAP:
				case	SUBSCRIPT:
					func = _tree.newFunction(Function.Category.NORMAL, x, null, null, _scanner.location());
					break;

				default:
					return _tree.newSyntaxError(x.location());
				}
			} else
				func = _tree.newFunction(Function.Category.NORMAL, null, null, null, _scanner.location());
			func.body = _tree.newBlock(Operator.BLOCK, _scanner.location());
			parseBlock(func.body);
			x = func;
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
				if (inFunctionLiteral)
					x = _tree.newFunction(Function.Category.NORMAL, x, null, parameters, location);
				else // This is provisional.  It may be a call, a cast or a function declarator depending on context
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
				t = _scanner.next();
				if (t == Token.LEFT_CURLY) {
					ref<Node> aggregate;
					t = _scanner.next();
					if (t == Token.RIGHT_CURLY)
						aggregate = null;
					else {
						_scanner.pushBack(t);
						aggregate = parseExpression(0);
						if (aggregate.op() == Operator.SYNTAX_ERROR)
							return aggregate;
						t = _scanner.next();
						// Needs possible changes here to resync logic.
						if (t != Token.RIGHT_CURLY) {
							_scanner.pushBack(t);
							return resync(MessageId.EXPECTING_RC);
						}
					}
				} else
					_scanner.pushBack(t);
				break;

			case	DOT:
				t = _scanner.next();
				if (t == Token.BYTES)
					x = _tree.newUnary(Operator.BYTES, x, location);
				else if (t == Token.CLASS)
					x = _tree.newUnary(Operator.CLASS_OF, x, location);
				else if (t == Token.IDENTIFIER)
					x = _tree.newSelection(x, _scanner.value(), location);
				else {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
				break;

			case	ERROR:
				return resync(MessageId.SYNTAX_ERROR);

			default:
				_scanner.pushBack(t);
				return x;
			}
		}
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
			Location aLoc = _scanner.location();
			ref<Node> name;
			ref<Node> type;
			switch (t) {
			case	CLASS: {
				Location loc = _scanner.location();
				t = _scanner.next();
				if (t != Token.IDENTIFIER) {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
				type = _tree.newLeaf(Operator.CLASS_TYPE, loc);
				name = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
				ref<Node> bind = _tree.newBinary(Operator.BIND, type, name, _scanner.location());
				if (annotations != null)
					bind = _tree.newBinary(Operator.ANNOTATED, annotations, bind, aLoc);
				templateDef.templateArgument(_tree.newNodeList(bind));
				t = _scanner.next();
			}	break;
			
			case	ENUM: {
				Location loc = _scanner.location();
				t = _scanner.next();
				if (t != Token.IDENTIFIER) {
					_scanner.pushBack(t);
					return resync(MessageId.SYNTAX_ERROR);
				}
				type = _tree.newLeaf(Operator.ENUM_TYPE, loc);
				name = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
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
					Location location = _scanner.location();
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
			Location aLoc;
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
				Location location = _scanner.location();
				name = parseName(t);
				if (name.op() == Operator.SYNTAX_ERROR) {
					*results = _tree.newNodeList(name);
					return false;
				}
				t = _scanner.next();
				if (t == Token.LEFT_PARENTHESIS) {
					Location loc = _scanner.location();
					ref<NodeList> parameters;
					if (!parseParameterList(Token.RIGHT_PARENTHESIS, &parameters)) {
						*results = _tree.newNodeList(parameters.node);
						return false;
					}
					argument = _tree.newFunction(Function.Category.NORMAL, type, ref<Identifier>(name), parameters, loc);
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
		ref<Node> annotation;

		if (t == Token.ANNOTATION) {
			annotation = parseAnnotations();
			t = _scanner.next();
		} else
			annotation = null;
		if (t != Token.IDENTIFIER) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		return _tree.newIdentifier(annotation, _scanner.value(), _scanner.location());
	}

	private ref<Node> parseAnnotations() {
		ref<Node> list = null;
		for (;;) {
			ref<Node> id = _tree.newIdentifier(null, _scanner.value(), _scanner.location());
			Token t = _scanner.next();
			Location location = _scanner.location();

			ref<NodeList> arguments = null;
			ref<NodeList> last = null;
			if (t == Token.LEFT_PARENTHESIS) {
				t = _scanner.next();
				if (t == Token.RIGHT_PARENTHESIS) {
				} else {
					_scanner.pushBack(t);
					ref<Node> annotationArguments = parseExpression(0);
					if (annotationArguments.op() == Operator.SYNTAX_ERROR)
						return annotationArguments;
					t = _scanner.next();
					if (t != Token.RIGHT_PARENTHESIS) {
						_scanner.pushBack(t);
						return resync(MessageId.SYNTAX_ERROR);
					}
					ref<NodeList> nl = _tree.newNodeList(annotationArguments);
					if (last != null)
						last.next = nl;
					else
						arguments = nl;
					last = nl;
				}
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

	private ref<Node> parseClass(ref<Identifier> name, Location location) {
		ref<Node> extendsClause = null;
		ref<Node> implementsClause = null;
		ref<Class> classDef;
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
		classDef = _tree.newClass(name, extendsClause, location);
		if (t == Token.IMPLEMENTS) {
			implementsClause = parseExpression(0);
			if (implementsClause.op() == Operator.SYNTAX_ERROR)
				return implementsClause;
			classDef.addInterface(_tree.newNodeList(implementsClause));
			t = _scanner.next();
		}
		if (t != Token.LEFT_CURLY) {
			_scanner.pushBack(t);
			return resync(MessageId.SYNTAX_ERROR);
		}
		ref<Class> oldEnclosing = pushEnclosing(classDef);
		parseBlock(classDef);
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

	private ref<Class> pushEnclosing(ref<Class> enclosing) {
		ref<Class> c = _enclosing;
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
		return id.value().equals(enclosingClassName().value());
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

