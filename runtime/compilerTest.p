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
/**
 * @ignore - This namespace is for internal compiler testing and is not intended for end-user
 * services.
 */
namespace parasol:compiler.test;

import parasol:context;
import parasol:memory;
import parasol:process;
import parasol:runtime;
import parasol:script;
import parasol:script.Vector;
import parasol:storage;
import parasol:text;
import parasol:time;
import parasol:pxi;
import parasol:compiler;
import parasol:compiler.Block;
import parasol:compiler.CompileContext;
import parasol:compiler.containsErrors;
import parasol:compiler.MemoryPool;
import parasol:compiler.Message;
import parasol:compiler.MessageId;
import parasol:compiler.Node;
import parasol:compiler.Operator;
import parasol:compiler.Parser;
import parasol:compiler.Scanner;
import parasol:compiler.Scope;
import parasol:compiler.StorageClass;
import parasol:compiler.StringScanner;
import parasol:compiler.SyntaxTree;
import parasol:compiler.Target;
import parasol:compiler.Token;
import parasol:compiler.TraverseAction;
import parasol:compiler.Unit;

private boolean verboseFlag;
private boolean printSymbolTable;
private boolean showParseStageErrors;
private string rootFolder;
private string parasolCommand;
private string pxiFile;
private string targetArgument;
private string importPathArgument;

public void initTestObjects(string argv0, string argv1, boolean verbose, 
				boolean symbols, string target, string importPathArg, string rootDir, boolean showParseStageErrorsArgument) {
	verboseFlag = verbose;
	showParseStageErrors = showParseStageErrorsArgument;
	if (rootDir != null)
		rootFolder = rootDir;
	else
		rootFolder = storage.directory(storage.directory(process.binaryFilename()));
	parasolCommand = argv0;
	pxiFile = argv1;
	targetArgument = target;
	importPathArgument = importPathArg;
	printSymbolTable = symbols;
	script.objectFactory("codePoint", CodePointObject.factory);
	script.objectFactory("compile", CompileObject.factory);
	script.objectFactory("expression", ExpressionObject.factory);
	script.objectFactory("run", RunObject.factory);
	script.objectFactory("scan", ScanObject.factory);
	script.objectFactory("statement", StatementObject.factory);
}

class CodePointObject extends script.Object {
	private string _source;
	private boolean _expectSuccess;
	private int[] _expectedValue;

	public static ref<script.Object> factory(int offset) {
		return new CodePointObject(offset);
	}

	public boolean isRunnable() {
		return true;
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("content");
		if (a == null)
			return false;
		_source = a.toString();
		a = get("expect");
		if (a != null) {
			if (a.toString() == "fail")
				_expectSuccess = false;
			else if (a.toString() == "success")
				_expectSuccess = true;
			else {
				parser.log.error(offset(), "Unexpected value for 'expect' attribute: '%s'\n", a.toString());
				return false;
			}
		} else
			_expectSuccess = true;
		a = get("value");
		string[] codes = a.toString().split(',');
		for (int i = 0; i < codes.length(); i++) {
			boolean success;
			int xValue;
			(xValue, success) = int.parse(codes[i], 16);
			if (!success) {
				parser.log.error(offset(), "value attribute '%s' is not an integer in '%s'\n", codes[i], a.toString());
				return false;
			}
			_expectedValue.append(xValue);
		}
		return true;
	}

	public boolean run() {
		boolean success = runTest(false);
		if (_expectSuccess) {
			if (!success) {
				printf("expecting %d characters\n", _expectedValue.length());
				text.memDump(&_source[0], _source.length());
				runTest(true);
			}
			return success;
		} else
			return !success;
	}

	private boolean runTest(boolean verbose) {
		StringScanner scanner(_source, 0, "StringScanner test");

		boolean success = true;
		for (int i = 0; i < _expectedValue.length(); i++) {
			int actual = scanner.getc();
			if (actual != _expectedValue[i]) {
				if (verbose)
					printf("[%d] Expected: %#x Actual: %#x\n", i, _expectedValue[i], actual);
				success = false;
			}
		}
		int next = scanner.getc();
		if (next != -1) {
			if (verbose)
				printf("Expecting end of stream, got '%#x'\n", next);
			success = false;
		}
		return success;
	}

	private CodePointObject(int offset) {
		super(offset);
	}

	void dump(ref<Node> expression) {
		printf("Scanning '%s'\n", _source);
		StringScanner scanner(_source, 0, "StringScanner test");
		Token t;
		do {
			t = scanner.next();
			printf("%s %s\n", string(t), scanner.value());
		} while(t != Token.END_OF_STREAM);
		expression.print(0);
		printSyntaxErrors(expression, &_source);
	}
}

class ScanObject extends script.Object {
	private string _source;
	private boolean _expectSuccess;
	private int _tokenCount;
	private ref<script.Atom> _keyword;
	private ref<script.Atom> _value;

	public static ref<script.Object> factory(int offset) {
		return new ScanObject(offset);
	}

	public boolean isRunnable() {
		return true;
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a;

		a = get("character");
		if (a != null) {
			string s = a.toString();
			int v;
			boolean result;
			(v, result) = int.parse(s.trim());
			if (!result) {
				printf("Invalid character value: %s\n", s.trim());
				return false;
			}
			_source.append(v);
		} else {
			a = get("content");
			if (a == null)
				return false;
			_source = a.toString();
		}
		a = get("expect");
		if (a != null) {
			if (a.toString() == "fail")
				_expectSuccess = false;
			else if (a.toString() == "success")
				_expectSuccess = true;
			else {
				printf("Unexpected value for 'expect' attribute: '%s'\n", a.toString().c_str());
				return false;
			}
		} else
			_expectSuccess = true;
		a = get("tokens");
		if (a != null) {
			boolean result;
			(_tokenCount, result) = int.parse(a.toString());
			if (!result) {
				printf("Must have a numeric value for 'tokens' attribute: %s\n", a.toString());
				return false;
			}
			if (_tokenCount < 0) {
				printf("Must specify a non-negative integer count of expected tokens\n");
				return false;
			}
		} else
			_tokenCount = -1;
		_keyword = get("keyword");
		_value = get("value");
		return true;
	}

	boolean matches(ref<Scanner> scanner, ref<script.Atom> a) {
		if (a != null) {
			string s = a.toString();
			boolean matches = false;
			if (s.length() == scanner.value().length()) {
				matches = true;
				for (int i = 0; i < s.length(); i++)
					if (s[i] != scanner.value().c_str()[i]) {
						matches = false;
						break;
					}
			}
			if (!matches) {
				printf("Not the correct value: %s :: %s\n", s, scanner.value());
				return false;
			}
		}
		return true;
	}

	public boolean run() {
//		printf("source:          %s\n", _source);
//		printf("token count:     %d\n", _tokenCount);
//		printf("expect success?: %s\n", _expectSuccess ? "true" : "false");

		StringScanner scanner(_source, 0, "StringScanner test");
		Token t;
		int i;
		scanner.disableSemiColonElision();
		for (i = 0; ; i++) {
			if (_tokenCount != -1) {
				if (i >= _tokenCount + 1)
					break;
			}
			t = scanner.next();
			if (t == Token.END_OF_STREAM)
				break;
			if (t == Token.ERROR)
				break;
			if (_keyword != null) {
				if (t == Token.IDENTIFIER) {
					printf("Not a keyword: %s\n", _keyword.toString());
					return false;
				}
				if (!matches(&scanner, _keyword))
					return false;
			}
			if (!matches(&scanner, _value))
				return false;
		}
		if (i < _tokenCount) {
			dump();
			printf("Not enough tokens (expecting %d, found %d)\n", _tokenCount, i);
			return false;
		}
		if (_expectSuccess) {
			if (t == Token.END_OF_STREAM)
				return true;
		} else {
			if (t == Token.ERROR)
				return true;
		}
		dump();
		return false;
	}
	
	private ScanObject(int offset) {
		super(offset);
	}

	void dump() {
		printf("Scanning '%s' (%d)\n", _source, _source.length());
		StringScanner scanner(_source, 0, "StringScanner test");
		scanner.disableSemiColonElision();
		Token t;
		do {
			t = scanner.next();
			substring value = scanner.value();
			if (t == Token.ERROR)
				printf("%s '%c' (%<$2.2x)\n", string(t), value.c_str()[0]);
			else
				printf("%s %s\n", string(t), value);
		} while(t != Token.END_OF_STREAM);
	}
}

class ExpressionObject extends script.Object {
	private string _source;
	private boolean _expectSuccess;

	public static ref<script.Object> factory(int offset) {
		return new ExpressionObject(offset);
	}

	public boolean isRunnable() {
		return true;
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("content");
		if (a == null)
			return false;
		_source = a.toString();
		a = get("expect");
		if (a != null) {
			if (a.toString() == "fail")
				_expectSuccess = false;
			else if (a.toString() == "success")
				_expectSuccess = true;
			else {
				printf("Unexpected value for 'expect' attribute: '%s'\n", a.toString());
				return false;
			}
		} else
			_expectSuccess = true;
		return true;
	}

	public boolean run() {
		ref<Unit> f = new Unit();
		f.setSource(_source);
		ref<Scanner> scanner = f.scanner();
		scanner.disableSemiColonElision();
		ref<SyntaxTree> tree = new SyntaxTree();
		Parser parser(tree, scanner);

		ref<Node> expression = parser.parseExpression(0);
		
		boolean success = !containsErrors(expression) && (scanner.next() == Token.END_OF_STREAM);

		if (checkInOrder(expression, _source) && checkMessages(expression, get("message"))) {
			if (_expectSuccess) {
				if (success) {
					delete f;
					delete tree;
					return true;
				}
				printf("\n  Expecting SUCCESS got FAIL\n");
			} else {
				if (!success) {
					delete f;
					delete tree;
					return true;
				}
				printf("\n  Expecting FAIL got SUCCESS\n");
			}
		} else if (!checkMessages(expression, get("message")))
			printf("\n  Message did not match %s\n", get("message"));
		dump(expression);
		delete f;
		delete tree;
		return false;
	}

	private ExpressionObject(int offset) {
		super(offset);
	}

	void dump(ref<Node> expression) {
		printf("Scanning '%s'\n", _source);
		StringScanner scanner(_source, 0, "StringScanner test");
		scanner.disableSemiColonElision();
		Token t;
		do {
			t = scanner.next();
			printf("%s %s\n", string(t), scanner.value());
		} while(t != Token.END_OF_STREAM);
		expression.print(0);
		printSyntaxErrors(expression, &_source);
	}
}

enum Expect {
	SUCCESS,
	FAIL,
	RECOVERED,
	SEMANTIC
}

class StatementObject extends script.Object {
	private string _source;
	private Expect _expect;
	
	public static ref<script.Object> factory(int offset) {
		return new StatementObject(offset);
	}

	public boolean isRunnable() {
		return true;
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("content");
		if (a == null)
			return false;
		_source = a.toString();
		a = get("expect");
		if (a != null) {
			if (a.toString() == "fail")
				_expect = Expect.FAIL;
			else if (a.toString() == "success")
				_expect = Expect.SUCCESS;
			else if (a.toString() == "recovered")
				_expect = Expect.RECOVERED;
			else if (a.toString() == "semantic")
				_expect = Expect.SEMANTIC;
			else {
				printf("Unexpected value for 'expect' attribute: '%s'\n", a.toString().c_str());
				return false;
			}
		} else
			_expect = Expect.SUCCESS;
		return true;
	}

	public boolean run() {
		saved := compiler.semiColonElision;
		compiler.semiColonElision = compiler.SemiColonElision.DISABLED;
		ref<Unit> f = new Unit();
		f.setSource(_source);
		ref<Scanner> scanner = f.scanner();
		scanner.disableSemiColonElision();
		ref<SyntaxTree> tree = new SyntaxTree();
		Parser parser(tree, scanner);

		ref<Node> statement = parser.parseStatement();
		Token t = scanner.next();
		boolean success = !containsErrors(statement) && (t == Token.END_OF_STREAM);

		Expect outcome;

		if (success)
			outcome = Expect.SUCCESS;
		else if (t == Token.END_OF_STREAM && statement.op() != Operator.SYNTAX_ERROR)
			outcome = Expect.RECOVERED;
		else
			outcome = Expect.FAIL;
		compiler.semiColonElision = saved;
		if (checkInOrder(statement, _source)) {
			if (outcome == Expect.SUCCESS) {
				if (statement.countMessages() > 0)
					outcome = Expect.SEMANTIC;
			}
			if (checkMessages(statement, get("message")) && _expect == outcome) {
				delete f;
				delete tree;
				return true;
			}
		}
		printf("  Expecting %s got %s\n", string(_expect), string(outcome));
		dump(statement);
		delete f;
		delete tree;
		return false;
	}

	private StatementObject(int offset) {
		super(offset);
	}

	private void dump(ref<Node> expression) {
		printf("Scanning '%s'\n", _source);
		StringScanner scanner(_source, 0, "StringScanner test");
		scanner.disableSemiColonElision();
		Token t;
		do {
			t = scanner.next();
			substring value = scanner.value();
			printf("%s %s\n", string(t), value);
		} while(t != Token.END_OF_STREAM);
		expression.print(0);
		printSyntaxErrors(expression, &_source);
	}
}

class CompileObject  extends script.Object {
	private string _filename;
	private string _source;
	private Expect _expect;

	public static ref<script.Object> factory(int offset) {
		return new CompileObject(offset);
	}

	public boolean isRunnable() {
		return true; 
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("filename");
		if (a != null)
			_filename = a.toString();
		else {
			a = get("content");
			if (a == null)
				return false;
			_source = a.toString();
		}
		a = get("expect");
		if (a != null) {
			if (a.toString() == "fail")
				_expect = Expect.FAIL;
			else if (a.toString() == "success")
				_expect = Expect.SUCCESS;
			else {
				printf("Unexpected value for 'expect' attribute: '%s'\n", a.toString());
				return false;
			}
		} else
			_expect = Expect.SUCCESS;
		return true;
	}

	public void insertDefaultPath(string defaultPath) {
		if (_filename != null)
			_filename = storage.path(storage.path(rootFolder, defaultPath), _filename);
	}

	public boolean run() {
		compiler.Arena arena;
		boolean loadFailed = false;

		if (targetArgument != null)
			arena.preferredTarget = pxi.sectionType(targetArgument);

		CompileContext compileContext(&arena, verboseFlag, false);

		if (!compileContext.loadRoot(false)) {
			arena.printMessages();
			arena.print();
			printf("Failed to load arena\n");
			return false;
		}

		ref<Unit> f;
		if (_filename.length() > 0) {
			f = new Unit(_filename, "");
		} else {
			f = new Unit();
			f.setSource(_source);
		}
		boolean nodesOrdered;
		ref<Target> target;

		(target, nodesOrdered) = compileContext.compile(f, checkInOrder);

//		printf("after folding and codegen:\n");
//		f.tree().root().print(0);

		if (printSymbolTable)
			arena.printSymbolTable();

		Expect outcome;
		int messageCount = arena.countMessages();
		if (target == null || messageCount > 0)
			outcome = Expect.FAIL;
		else
			outcome = Expect.SUCCESS;

		Message[] messages;

		boolean result = true;
		if (!nodesOrdered ||
			!checkMessages(f.tree().root(), get("message")) ||
			_expect != outcome) {
			printf("\n  Expecting %s got %s\n", string(_expect), string(outcome));
			printf("      Messages flagged %d\n", messageCount);
			if (verboseFlag)
				f.tree().root().print(0);
			arena.printMessages();
			result = false;
		}
		delete target;
		return result;
	}

	private CompileObject(int offset) {
		super(offset);
	}
}

class RunObject extends script.Object {
	private string _filename;
	private Expect _expect;
	private int _exitCode;
	private string _arguments;
	private string _output;
	private boolean _checkOutput;
	private int _timeout;
	private string _include;

	private RunObject(int offset) {
		super(offset);
		_timeout = 120;
	}
	
	public static ref<script.Object> factory(int offset) {
		return new RunObject(offset);
	}

	public boolean isRunnable() { 
		return true; 
	}

	public boolean validate(ref<script.Parser> parser) {
		ref<script.Atom> a = get("filename");
		if (a == null)
			return false;
		_filename = a.toString();
		a = get("expect");
		if (a != null) {
			if (a.toString() == "fail")
				_expect = Expect.FAIL;
			else if (a.toString() == "success")
				_expect = Expect.SUCCESS;
			else {
				printf("Unexpected value for 'expect' attribute: '%s'\n", a.toString());
				return false;
			}
		} else
			_expect = Expect.SUCCESS;
		a = get("exitCode");
		if (a != null) {
			boolean result;
			(_exitCode, result) = int.parse(a.toString());
			if (!result) {
				printf("exitCode must be an integer\n");
				return false;
			}
		} else
			_exitCode = 0;
		a = get("timeout");
		if (a != null) {
			boolean result;
			
			(_timeout, result) = int.parse(a.toString());
			if (!result) {
				printf("Timeout %s is not an integer (in seconds)\n");
				return false;
			}
		}
		a = get("include");
		if (a != null)
			_include = a.toString();
		a = get("arguments");
		if (a != null)
			_arguments = a.toString();
		a = get("expectedOutput");
		if (a != null) {
			_checkOutput = true;
			string output = a.toString();
			for (int i = 0; i < output.length(); i++) {
				if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
					if (output[i] == '\n')
						_output.append('\r');
				}
				_output.append(output[i]);
			}
		} else
			_checkOutput = false;
		return true;
	}

	public void insertDefaultPath(string defaultPath) {
		if (_filename != null)
			_filename = storage.path(storage.path(rootFolder, defaultPath), _filename);
		if (_include != null) {
			includes := _include.split(':');
			_include = "";
			for (i in includes) {
				include := includes[i];
				include = storage.path(storage.path(rootFolder, defaultPath), include);
				if (_include.length() > 0)
					_include += ":";
				_include += include;
			}
		}
	}

	public boolean run() {
		string[] args;

		rootDir := storage.directory(storage.directory(parasolCommand));
		args.append("build/install_parasollanguage.org/bin/pc");
		if (targetArgument != null)
			args.append("--target=" + targetArgument);
		if (_include != null) {
			args.append("--include=" + _include);
		}
		if (verboseFlag)
			args.append("-v");
		args.append(_filename);
		if (_arguments.length() > 0) {
			string[] finalArgs = _arguments.split(' ');
			args.append(finalArgs);
		}

		int result;
		string output;
		process.exception_t exception;
		
		(result, output, exception) = process.execute(_timeout.seconds(), args);
		Expect outcome;
		if (result < 0)
			outcome = Expect.FAIL;
		else if (result != _exitCode)
			outcome = Expect.FAIL;
		else
			outcome = Expect.SUCCESS;

		if (_expect == outcome) {
			if (_checkOutput && output != _output) {
				printf("  Expecting output: '%s'\n     Actual output: '%s'\n",
					_output.escapeC(),
					output.escapeC());
				return false;
			}
			return true;
		}
		printf("-->");
		for (i in args)
			printf(" %s", args[i]);
		printf("\n");
		printf("%s\n", output);
		printf("  Expecting %s got %s\n", string(_expect), string(outcome));
		if (result < 0)
			printf("    Saw an exception running %s: %s\n", _filename, string(exception));
		else if (result != _exitCode)
			printf("    Unexpected exit code %d\n", result);
		if (verboseFlag) {
			compiler.Arena arena;

			CompileContext compileContext(&arena, verboseFlag, false);
			if (!compileContext.loadRoot(false)) {
				arena.printMessages();
				arena.print();
				printf("Failed to load arena\n");
				return false;
			}
			ref<Unit> f = new Unit(_filename, "");
			compileContext.compile(f, null);
			arena.print();
			delete f;
		}
		return false;
	}
}

boolean checkInOrder(ref<Node> n, string source) {
	compiler.SourceOffset loc;
	boolean success = true;

	loc = 0;
	if (!n.traverse(Node.Traversal.IN_ORDER, checkAscending, &loc)) {
		printf("IN_ORDER:\n");
		if (source != null)
			n.traverse(Node.Traversal.IN_ORDER, dumpCursor, &source);
		else
			n.print(4);
		success = false;
	}
	loc = int.MAX_VALUE;
	if (!n.traverse(Node.Traversal.REVERSE_IN_ORDER, checkDescending, &loc)) {
		printf("REVERSE_IN_ORDER:\n");
		if (source != null)
			n.traverse(Node.Traversal.REVERSE_IN_ORDER, dumpCursor, &source);
		else
			n.print(4);
		success = false;
	}
	return success;
}

TraverseAction checkAscending(ref<Node> n, address data) {
	if (n.op() == Operator.CAST)
		return TraverseAction.CONTINUE_TRAVERSAL;
		
	ref<compiler.SourceOffset> locp = ref<compiler.SourceOffset>(data);

	if (*locp > n.location()) {
		return TraverseAction.ABORT_TRAVERSAL;
	}
	*locp = n.location();
	return TraverseAction.CONTINUE_TRAVERSAL;
}

static TraverseAction checkDescending(ref<Node> n, address data) {
	if (n.op() == Operator.CAST)
		return TraverseAction.CONTINUE_TRAVERSAL;

	ref<compiler.SourceOffset> locp = ref<compiler.SourceOffset>(data);

	if (*locp < n.location()) {
		return TraverseAction.ABORT_TRAVERSAL;
	}
	*locp = n.location();
	return TraverseAction.CONTINUE_TRAVERSAL;
}

static TraverseAction dumpCursor(ref<Node> n, address data) {
	ref<string> sp = ref<string>(data);

	printf("Source: %s\n", *sp);
	printf("      : ");
	int column = 0;
	for (int i = 0; i < n.location(); i++) {
		if (*sp != null && (*sp)[i] == '\t') {
			int next = (column + 8) & ~7;
			printf("%*c", next - column, ' ');
			column = next;
		} else {
			printf(" ");
			column++;
		}
	}
	printf("^ %p\n", n);
//	printf("%s\n", operatorMap.name[n.op()]);
	return TraverseAction.CONTINUE_TRAVERSAL;
}

boolean checkMessages(ref<Node> n, ref<script.Atom> message) {
	if (message == null)
		return true;
	MessageId[] targets;
	if (message.class == Vector) {
		ref<script.Vector> v = ref<script.Vector>(message);
		for (int i = 0; i < v.length(); i++) {
			ref<script.Atom> a = v.get(i);
			string s = a.toString();
			MessageId m = messageId(s);
			if (m == MessageId.MAX_MESSAGE) {
				printf("'%s' is not a valid message id\n", s);
				return false;
			}
			targets.append(m);
		}
	} else {
		string s = message.toString();
		MessageId m = messageId(s);
		if (m == MessageId.MAX_MESSAGE) {
			printf("'%s' is not a valid message id\n", s);
			return false;
		}
		targets.append(m);
	}
	Message[] messages;
	n.getMessageList(&messages);
	for (int i = 0; i < targets.length(); i++) {
		boolean found = false;
		for (int j = 0; j < messages.length(); j++) {
			if (targets[i] == messages[j].commentary.messageId()) {
				found = true;
				break;
			}
		}
		if (!found) {
			printf("Did not see message '%s' in messages\n", string(targets[i]));
			return false;
		}
	}
	return true;
}

MessageId messageId(string messageIdName) {
	for (int i = 0; i < int(MessageId.MAX_MESSAGE); i++)
		if (string(MessageId(i)) == messageIdName)
			return MessageId(i);
	return MessageId.MAX_MESSAGE;
}

void printSyntaxErrors(ref<Node> n, ref<string> source) {
	n.traverse(Node.Traversal.IN_ORDER, dumpSyntaxError, source);
}

TraverseAction dumpSyntaxError(ref<Node> n, address data) {
	if (n.op() == Operator.SYNTAX_ERROR)
		dumpCursor(n, data);
	return TraverseAction.CONTINUE_TRAVERSAL;
}
