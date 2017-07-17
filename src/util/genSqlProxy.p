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
import parasol:file;
import parasol:commandLine;
import parasol:compiler;
import parasol:stream.Utf8Reader;
import parasol:stream.StringReader;

string DEFAULT_CLASS_NAME = "SQLDataBase";
/*
 *	SQL Proxy Generator:
 *
 *		This code loads a SQL database schema file, finds the CREATE PROCEDURE statements
 *		and generates a Parasol proxy class that defines static methods, one for each
 *		procedure.
 *		
 *		Note that the generator assumes that the SQL file contains valid MySQL syntax that
 *		includes various CREATE TABLE, PROCEDURE and FUNCTION calls. If not, this generator
 *		will produce unpredictable results.
 */
class SQLProxyCommand extends commandLine.Command {
	public SQLProxyCommand() {
		finalArguments(2, 2, "<sql-filename> <class-filename>");
		description("The given filename is parsed as a SQL schema definition script. " +
					"\n" +
					"All CREATE PROCEDURE statements are parsed to obtain the procedure " +
					"arguments. " +
					"This information is used to generate a Parasol static method that will " +
					" execute the stored procedure."
					);
		classNameArgument = stringArgument('c', "class", "Names the generated class in the output. (Default is " + DEFAULT_CLASS_NAME + ")");
		namespaceArgument = stringArgument('n', "namespace", "If present, the file is generated in the given namespace.");
		verboseArgument = booleanArgument('v', null,
					"Enables verbose output.");
		helpArgument('?', "help",
					"Displays this help.");
	}

	ref<commandLine.Argument<string>> classNameArgument;
	ref<commandLine.Argument<string>> namespaceArgument;
	ref<commandLine.Argument<boolean>> verboseArgument;
}

SQLProxyCommand sqlProxyCommand();
private string[] finalArgs;
boolean errorsFound;
file.File output;
ref<Procedure>[] procedures;

int main(string[] args) {
	int result = 1;
	
	if (!sqlProxyCommand.parse(args))
		sqlProxyCommand.help();
	string[] a = sqlProxyCommand.finalArgs();
	Scanner s(a[0]);
	if (!s.opened()) {
		printf("Could not open '%s'\n", a[0]);
		return 1;
	}
	for (;;) {
		Token t = s.next();
		if (t == Token.END_OF_STREAM)
			break;
//		printf("%s: %s\n", string(t), s.value());
		if (t == Token.CREATE) {
			t = s.next();

			// Skip any DEFINER clause. We know that to be valid SQL syntax, there must be a PROCEDURE keyword coming...

			if (t == Token.DEFINER) {
				do
					t = s.next();
					while (t != Token.END_OF_STREAM &&
						   t != Token.PROCEDURE);
			}
			if (t == Token.PROCEDURE) {	// got one!
				parseProcedureDeclarator(&s);
			}
		}
	}
	if (procedures.length() == 0)
		error(&s, -1, "No procedures found.\n");
	if (errorsFound) {
		printf("Not writing output due to discovered errors.\n");
		return 1;
	}
	output = file.createTextFile(a[1]);
	if (!output.opened()) {
		printf("Could not create output file '%s'\n", a[1]);
		return 1;
	}
	output.write("/* GENERATED CODE - DO NOT MODIFY */\n");
	if (sqlProxyCommand.namespaceArgument.set())
		output.printf("namespace %s;\n", sqlProxyCommand.namespaceArgument.value);
	string className;
	if (sqlProxyCommand.classNameArgument.set())
		className = sqlProxyCommand.classNameArgument.value;
	else
		className = DEFAULT_CLASS_NAME;
	output.write("import parasol:sql;\n");
	output.printf("public class %s extends sql.DBConnection {\n", className);
	output.printf("public %s(ref<sql.Environment> env) { super(env); }\n", className);
	for (int i = 0; i < procedures.length(); i++) {
		procedures[i].print();
		procedures[i].generate(output);
	}
	output.write("}\n");
	output.close();

	file.File x = file.openTextFile(a[1]);
	string z = x.readAll();
	printf("%s:\n%s", a[1], z); 
	return 0;
}

void parseProcedureDeclarator(ref<Scanner> s) {
	Token t;

	if (s.next() != Token.IDENTIFIER) {
		error(s, s.location(), "Expecting a procedure name after CREATE PROCEDURE");
		return;
	}
	printf("Found procedure '%s'\n", s.value());
	ref<Procedure> p = new Procedure(s.value());
	if (s.next() != Token.LEFT_PARENTHESIS) {
		error(s, s.location(), "Expecting a ( after the procedure name");
		return;
	}

	t = s.next();
	if (t == Token.RIGHT_PARENTHESIS) {
		procedures.append(p);
		return;
	}

	s.pushBack(t);
	for (;;) {
		t = s.next();
		Token parameterDirection = Token.IN;
		switch (t) {
		case IN:
		case INOUT:
		case OUT:
			parameterDirection = t;
			t = s.next();
		}
		if (t != Token.IDENTIFIER) {
			error(s, s.location(), "Expecting an identifier for a parameter name");
			return;
		}
		string paramName = s.value();
		t = s.next();
		Token type;
		switch (t) {
		case BIGINT:
		case BINARY:
		case CHAR:
		case DECIMAL:
		case DOUBLE_PRECISION:
		case ENUM:
		case FLOAT:
		case INTEGER:
		case SET:
		case SMALLINT:
		case TEXT:
		case TINYINT:
		case VARBINARY:
		case VARCHAR:
			type = t;
			break;

		default:
			error(s, s.location(), "Unknown parameter type %s:%s", string(t), s.value());
		}
		t = s.next();
		int length = -1, precision = -1;
		if (t == Token.LEFT_PARENTHESIS) {
			if (type == Token.ENUM)
				parseEnum(s);
			else {
				(length, precision) = parseLength(s);
				if (length == -1)
					break;
				}
			t = s.next();
		}
		p.parameters.append(new Parameter(parameterDirection, paramName, type, length, precision));
		if (t == Token.RIGHT_PARENTHESIS) {
			procedures.append(p);
			break;
		} else if (t != Token.COMMA) {
			error(s, s.location(), "Expecting a comma after a parameter");
			break;
		}
	}
}

void parseEnum(ref<Scanner> s) {
	printf("enums are not yet supported.\n");
	assert(false);
}

int, int parseLength(ref<Scanner> s) {
	Token t = s.next();
	if (t != Token.INTEGER) {
		error(s, s.location(), "Expecting a length or precision");
		return -1, -1;
	}
	int length = int(intValue(s.value()));
	t = s.next();
	if (t == Token.RIGHT_PARENTHESIS)
		return length, -1;
	assert(false);
	return -1, -1;
}

class Procedure {
	string name;
	ref<Parameter>[] parameters;

	Procedure(string name) {
		this.name = name;
	}

	void print() {
		printf("name: %s\n", name);
		for (int i = 0; i < parameters.length(); i++) {
			printf("    ");
			parameters[i].print();
		}
	}

	void generate(file.File output) {
		for (int i = 0; i < parameters.length(); i++) {
			if (parameters[i].parameterDirection == Token.IN) {
				if (parameters[i].type == Token.VARCHAR)
					parameters[i].length = -1;
			} else		// INOUT or OUT
				output.printf("// out param %d: %s\n", i + 1, parameters[i].name);
		}
		output.write("public ");
		boolean anyOuts = false;
		for (int i = 0; i < parameters.length(); i++) {
			if (parameters[i].parameterDirection != Token.IN) {		// INOUT or OUT
				if (anyOuts)
					output.write(",");
				anyOuts = true;
				parameters[i].generateType(output);
			}
		}
		if (!anyOuts)
			output.write(",");
		output.printf(",boolean %s(", name);
		boolean anyIns = false;
		for (int i = 0; i < parameters.length(); i++) {
			if (parameters[i].parameterDirection != Token.OUT) {		// IN or INOUT
				if (anyIns)
					output.write(",");
				anyIns = true;
				parameters[i].generateType(output);
				output.printf(" %s", parameters[i].name);
			}
		}
		output.write(") {\n");
		for (int i = 0; i < parameters.length(); i++) {
			switch (parameters[i].parameterDirection) {
			case INOUT:
				parameters[i].generateType(output);
				output.printf(" out_%s = %s;\n", parameters[i].name, parameters[i].name);
				if (parameters[i].length >= 0)
					output.printf("out_%s.resize(%d);\n", parameters[i].name, parameters[i].length);
				break;
			case OUT:
				parameters[i].generateType(output);
				output.printf(" %s;\n", parameters[i].name);
				if (parameters[i].length >= 0)
					output.printf("%s.resize(%d);\n", parameters[i].name, parameters[i].length);
			}
			if (parameters[i].length >= 0)
				output.printf("long strlen_%s;\n", parameters[i].name);
		}
		output.write("ref<Statement> stmt = getStatement();\n");
		output.write("if(");
		for (int i = 0; i < parameters.length(); i++) {
			string nm;
			if (parameters[i].parameterDirection == Token.INOUT)
				nm.append("out_");
			nm.append(parameters[i].name);
			if (parameters[i].length > 0)
				nm.append("[0]");
			long bufferLength = parameters[i].length;
			string indicator = "sql.Indicator.NO_ACTION";
			string lengthBuffer = "null";
			if (parameters[i].length >= 0) {
				switch (parameters[i].type) {
				case VARCHAR:
					if (parameters[i].parameterDirection == Token.IN) {
						indicator = "sql.Indicator.NTS";
						break;
					}

				case VARBINARY:
					output.printf("strlen_%s = %s.length();\n", parameters[i].name);
					lengthBuffer = "&strLen_" + parameters[i].name;
					break;

				default:
					if (parameters[i].length >= 0) {

						output.printf("strlen_%s = %d;\n", parameters[i].length);
						lengthBuffer = "&strLen_" + parameters[i].name;
					}
				}
			e
			output.printf("stmt.bindParameter(%d, %s, %s, %d, %d, &%s, %d, %s, %s) &&\n", i + 1, 
								parameterDirectionMap[parameters[i].parameterDirection], dataTypeMap[parameters[i].type],
								parameters[i].length, parameters[i].scale, nm, bufferLength, indicator, lengthBuffer);
		}
		output.printf("stmt.execDirect(\"CALL %s(", name);
		boolean anyParams = false;
		for (int i = 0; i < parameters.length(); i++) {
			if (anyParams)
				output.write(",");
			anyParams = true;
			output.write("?");
		}
		output.write(")\")) {\n");
//		output.write("for(;;) {\n");
//		output.write("}\n");
		output.write("return ");
		if (anyOuts) {
			anyOuts = false;
			for (int i = 0; i < parameters.length(); i++) {
				if (parameters[i].parameterDirection != Token.IN) {		// INOUT or OUT
					if (anyOuts)
						output.write(",");
					anyOuts = true;
					if (parameters[i].parameterDirection == Token.INOUT)
						output.write("out_");
					output.write(parameters[i].name);
				}
			}
			output.write(",");
		}
		output.write("true;\n");
		output.write("} else\n");
		output.write("return ");
		if (anyOuts) {
			anyOuts = false;
			for (int i = 0; i < parameters.length(); i++) {
				if (parameters[i].parameterDirection != Token.IN) {		// INOUT or OUT
					if (anyOuts)
						output.write(",");
					anyOuts = true;
					if (parameters[i].parameterDirection == Token.INOUT)
						output.write("out_");
					output.write(parameters[i].name);
				}
			}
			output.write(",");
		}
		output.write("false;\n");
		output.write("}\n");
	}
}

string[Token] parameterDirectionMap = [
	IN:		"sql.ParameterDirection.IN",
	INOUT:	"sql.ParameterDirection.INOUT",
	OUT:	"sql.ParameterDirection.OUT",
];

string[Token] dataTypeMap = [
	BIGINT:				"sql.DataType.BIGINT",
	BINARY:				"sql.DataType.BINARY",
	BLOB:				"sql.DataType.BLOB",
	CHAR:				"sql.DataType.CHAR",
	DECIMAL:			"sql.DataType.DECIMAL",
	DOUBLE_PRECISION:	"sql.DataType.DOUBLE_PRECISION",
	ENUM:				"sql.DataType.ENUM",
	FLOAT:				"sql.DataType.FLOAT",
	INTEGER:			"sql.DataType.INTEGER",
	SET:				"sql.DataType.SET",
	SMALLINT:			"sql.DataType.SMALLINT",
	TEXT:				"sql.DataType.TEXT",
	TINYINT:			"sql.DataType.TINYINT",
	VARBINARY:			"sql.DataType.VARBINARY",
	VARCHAR:			"sql.DataType.VARCHAR",
];

class Parameter {
	Token parameterDirection;
	string name;
	Token type;
	int length;
	int scale;

	Parameter(Token parameterDirection, string name, Token type, int length, int scale) {
		this.parameterDirection = parameterDirection;
		this.name = name;
		this.type = type;
		this.length = length;
		this.scale = scale;
	}

	void print() {
		printf("%s %s %s", string(parameterDirection), name, string(type));
		if (length >= 0) {
			printf("(%d", length);
			if (scale >= 0)
				printf(",%d", scale);
			printf(")");
		}
		printf("\n");
	}

	void generateType(file.File output) {
		string value = parasolType[type];
		if (value != null)
			output.write(value);
		else
			output.write("null");
	}
}

string[Token] parasolType = [
	BIGINT: "long",
	BINARY: "byte[]",
	VARBINARY: "byte[]",
	CHAR: "string",
	INTEGER: "int",
	VARCHAR: "string",
];

string[Token] defaultValue = [
	BIGINT: "0",
	BINARY: "[]",
	CHAR: "null",
	INTEGER: "0",
	VARCHAR: "null",
	VARBINARY: "[]";
];

void error(ref<Scanner> s, int location, string message, var... args) {
	errorsFound = true;
	if (location >= 0)
		printf("%s %d : ", s.filename(), s.lineNumber(location) + 1);
	printf(message, args);
	printf("\n");
}

long intValue(string value) {
	long v = 0;
	if (value.length() == 0)
		return -1;
	StringReader r(&value);
	Utf8Reader ur(&r);
	
	int c = ur.read();
	if (compiler.codePointClass(c) == 0) {
		c = ur.read();
		if (c < 0)
			return 0;			// the constant is just a '0' (or alternate decimal zero)
		if (c == 'x' || c == 'X') {
			for (;;) {
				int digit;
				c = ur.read();
				if (c < 0)
					break;
				if (compiler.codePointClass(c) == compiler.CPC_LETTER)
					digit = 10 + byte(c).toLowercase() - 'a';
				else
					digit = compiler.codePointClass(c);
				v = v * 16 + digit;
			}
		} else {
			do {
				v = v * 8 + compiler.codePointClass(c);
				c = ur.read();
			} while (c >= 0);
		}
	} else {
		do {
			v = v * 10 + compiler.codePointClass(c);
			c = ur.read();
		} while (c >= 0);
	}
	return v;
}

enum Token {
	ERROR,
	END_OF_STREAM,

	// Each of these tokens has an associated 'value'

	IDENTIFIER,
	INTEGER,
	FLOATING_POINT,
	CHARACTER,
	STRING,
	ANNOTATION,

	// Each of these are paired tokens:

	LEFT_PARENTHESIS,
	RIGHT_PARENTHESIS,
	LEFT_CURLY,
	RIGHT_CURLY,
	LEFT_SQUARE,
	RIGHT_SQUARE,
	LEFT_ANGLE,
	RIGHT_ANGLE,
	SP_LA,				// space-<
	SP_RA,				// space->

	// These are single character tokens:

	SEMI_COLON,
	COLON,
	DOT,
	COMMA,
	SLASH,
	PERCENT,
	ASTERISK,
	PLUS,
	DASH,
	AMPERSAND,
	CARET,
	VERTICAL_BAR,
	EXCLAMATION,
	EQUALS,
	QUESTION_MARK,
	TILDE,

	// These are multi-character tokens:

	ELLIPSIS,
	DOT_DOT,
	SLASH_EQ,
	PERCENT_EQ,
	ASTERISK_EQ,
	PLUS_EQ,
	DASH_EQ,
	AMPERSAND_EQ,
	CARET_EQ,
	VERTICAL_BAR_EQ,
	EQ_EQ,						// ==
	EQ_EQ_EQ,					// ===
	LA_EQ,						// <=
	RA_EQ,						// >=
	LA_RA,						// <>
	LA_RA_EQ,					// <>=
	EXCLAMATION_EQ,				// !=
	EX_EQ_EQ,					// !==
	EX_LA,						// !<
	EX_RA,						// !>
	EX_LA_EQ,					// !<=
	EX_RA_EQ,					// !>=
	EX_LA_RA,					// !<>
	EX_LA_RA_EQ,				// !<>=
	LA_LA,						// <<
	RA_RA,						// >>
	RA_RA_RA,					// >>>
	LA_LA_EQ,					// <<=
	RA_RA_EQ,					// >>=
	RA_RA_RA_EQ,				// >>>=
	AMP_AMP,					// &&
	VBAR_VBAR,					// ||
	PLUS_PLUS,					// ++
	DASH_DASH,					// --

	// Keywords

	BIGINT,
	BINARY,
	BLOB,
	CHAR,
	CREATE,
	CURRENT_USER,
	DECIMAL,
	DEFINER,
	DOUBLE_PRECISION,
	ENUM,
	FLOAT,
	IN,
	INOUT,
	INTEGER,
	OUT,
	PROCEDURE,
	SET,
	SMALLINT,
	TEXT,
	TINYINT,
	VARBINARY,
	VARCHAR,

	// Pseudo-tokens not actually returned by a Scanner

	EMPTY,
	MAX_TOKEN //= EMPTY
}

class Scanner {
	private file.File _file;
	private Token _pushback;
	private int[] _lines;
	private string _value;
	private string _filename;
	private boolean _utfError;
	private int _baseLineNumber;		// Line number of first character in scanner input.
	/*
	 * Location of the last token read.
	 */
	private int _location;
	/*
	 * _lastChar is the last Unicode code point value returned by getc
	 */
	private int _lastChar;
	/*
	 * This is the cursor value before the last getc call, so if we unetc, we can restore the cursor
	 */
	private int _lastCursor;
	/*
	 * This is the cursor value after the last getc call, so if we ungetc, this will be the cursor
	 * we restore when we read the ungotten character.
	 */
	private int _nextCursor;
	/*
	 * _lastByte is the last character read and pushed back  
	 */
	private int _lastByte;
	private byte _errorByte;
	/*
	 * This is the byte offset in the input stream of the next byte to be read.
	 */
	private int _cursor;
	
	public Scanner(string filename) {
		_filename = filename;
		_file = file.openBinaryFile(filename);
		_pushback = Token.EMPTY;
		_lastByte = -1;
		_baseLineNumber = 0;
	}

	~Scanner() {
		close();
	}

	public string filename() {
		return _filename;
	}

	public boolean opened() { 
		return _file.opened(); 
	}

	public void close() {
		if (_file.opened())
			_file.close();
	}	
	
	public Token next() {
		Token t;

		if (_pushback != Token.EMPTY) {
			t = _pushback;
			_pushback = Token.EMPTY;
			return t;
		}
		for (;;) {
			_location = cursor();
			int c = getc();
			switch (c) {
			case	0x7fffffff://int.MAX_VALUE:
				startValue(_errorByte);
				return Token.ERROR;
			
			case	-1:
				return Token.END_OF_STREAM;

			case	0x00:
			case	0x01:
			case	0x02:
			case	0x03:
			case	0x04:
			case	0x05:
			case	0x06:
			case	0x07:
			case	0x08:
				startValue(c);
				return Token.ERROR;

			case	'\t':
				continue;

			case	'\n':
				_lines.append(_location);
				continue;

			case	0x0b:
				startValue(c);
				return Token.ERROR;

			case	'\f':
			case	'\r':
				continue;

			case	0x0e:
			case	0x0f:
			case	0x10:
			case	0x11:
			case	0x12:
			case	0x13:
			case	0x14:
			case	0x15:
			case	0x16:
			case	0x17:
			case	0x18:
			case	0x19:
			case	0x1a:
			case	0x1b:
			case	0x1c:
			case	0x1d:
			case	0x1e:
			case	0x1f:
				startValue(c);
				return Token.ERROR;

			case	' ':
				int spLoc = _location;
				_location = cursor();
				c = getc();
				if (c == '<') {
					c = getc();
					if (c == '=') {
						_location = spLoc;
						return Token.LA_EQ;
					} else if (c == '<') {
						_location = spLoc;
						c = getc();
						if (c == '=')
							return Token.LA_LA_EQ;
						ungetc();
						return Token.LA_LA;
					} else if (c == '>') {
						_location = spLoc;
						c = getc();
						if (c == '=')
							return Token.LA_RA_EQ;
						ungetc();
						return Token.LA_RA;
					}
					ungetc();
					_location = spLoc;
					return Token.SP_LA;
				} else if (c == '>') {
					c = getc();
					if (c == '=') {
						_location = spLoc;
						return Token.RA_EQ;
					} else if (c == '>') {
						_location = spLoc;
						c = getc();
						if (c == '=') {
							return Token.RA_RA_EQ;
						} else if (c == '>') {
							c = getc();
							if (c == '=')
								return Token.RA_RA_RA_EQ;
							ungetc();
							return Token.RA_RA_RA;
						}
						ungetc();
						return Token.RA_RA;
					}
					ungetc();
					_location = spLoc;
					return Token.SP_RA;
				}
				ungetc();
				continue;

			case	'!':
				c = getc();
				switch (c) {
				case	'=':
					c = getc();
					if (c == '=')
						return Token.EX_EQ_EQ;
					ungetc();
					return Token.EXCLAMATION_EQ;

				case	'<':
					c = getc();
					if (c == '=')
						return Token.EX_LA_EQ;
					else if (c == '>') {
						c = getc();
						if (c == '=')
							return Token.EX_LA_RA_EQ;
						ungetc();
						return Token.EX_LA_RA;
					}
					ungetc();
					return Token.EX_LA;

				case	'>':
					c = getc();
					if (c == '=')
						return Token.EX_RA_EQ;
					ungetc();
					return Token.EX_RA;

				default:
					ungetc();
					return Token.EXCLAMATION;
				}

			case	'"':
				return consume(Token.STRING, byte(c));

			case	'#':
				for (;;) {
					c = getc();
					if (c == '\n') {
						_lines.append(_location);
						break;
					}
					if (c == -1)
						break;
				}
				continue;

			case	'$':
				startValue(c);
				return Token.ERROR;

			case	'%':
				c = getc();
				if (c == '=')
					return Token.PERCENT_EQ;
				ungetc();
				return Token.PERCENT;

			case	'&':
				c = getc();
				if (c == '=')
					return Token.AMPERSAND_EQ;
				else if (c == '&')
					return Token.AMP_AMP;
				ungetc();
				return Token.AMPERSAND;

			case	'\'':
				return consume(Token.CHARACTER, byte(c));

			case	'(':
				return Token.LEFT_PARENTHESIS;

			case	')':
				return Token.RIGHT_PARENTHESIS;

			case	'*':
				c = getc();
				if (c == '=')
					return Token.ASTERISK_EQ;
				ungetc();
				return Token.ASTERISK;

			case	'+':
				c = getc();
				if (c == '=')
					return Token.PLUS_EQ;
				else if (c == '+')
					return Token.PLUS_PLUS;
				ungetc();
				return Token.PLUS;

			case	',':
				return Token.COMMA;

			case	'-':
				c = getc();
				if (c == '=')
					return Token.DASH_EQ;
				else if (c == '-')
					return Token.DASH_DASH;
				ungetc();
				return Token.DASH;

			case	'.':
				c = getc();
				if (c == '.') {
					c = getc();
					if (c == '.')
						return Token.ELLIPSIS;
					ungetc();
					return Token.DOT_DOT;
				} else if (byte(c).isDigit()) {
					ungetc();
					return number('.');
				}
				ungetc();
				return Token.DOT;

			case	'/':
				c = getc();
				if (c == '=')
					return Token.SLASH_EQ;
				else if (c == '*') {
					// Block comments nest, this tracks the nesting depth
					int depth = 0;
					for (;;) {
						c = getc();
						if (c == -1) {
							// Set up a 'value' that will indicate
							// the context of the error.
							startValue('/');
							addCharacter('*');
							return Token.ERROR;
						}
						if (c == '/') {
							c = getc();
							if (c == '*')
								depth++;
							else
								ungetc();
						} else if (c == '*') {
							c = getc();
							if (c == '/') {
								if (depth == 0)
									break;
								depth--;
							} else
								ungetc();
						} else if (c == '\n')
							_lines.append(cursor());
					}
					continue;
				}
				ungetc();
				return Token.SLASH;

			case	'0':
			case	'1':
			case	'2':
			case	'3':
			case	'4':
			case	'5':
			case	'6':
			case	'7':
			case	'8':
			case	'9':
				return number(c);

			case	'_':
				return identifier(c);
				
			case	':':
				return Token.COLON;

			case	';':
				return Token.SEMI_COLON;

			case	'<':
				c = getc();
				if (c == '=')
					return Token.LA_EQ;
				else if (c == '<') {
					c = getc();
					if (c == '=')
						return Token.LA_LA_EQ;
					ungetc();
					return Token.LA_LA;
				} else if (c == '>') {
					c = getc();
					if (c == '=')
						return Token.LA_RA_EQ;
					ungetc();
					return Token.LA_RA;
				}
				ungetc();
				return Token.LEFT_ANGLE;

			case	'=':
				c = getc();
				if (c == '=') {
					c = getc();
					if (c == '=')
						return Token.EQ_EQ_EQ;
					ungetc();
					return Token.EQ_EQ;
				}
				ungetc();
				return Token.EQUALS;

			case	'>':
				c = getc();
				if (c == '=')
					return Token.RA_EQ;
				ungetc();
				return Token.RIGHT_ANGLE;

			case	'?':
				return Token.QUESTION_MARK;

			case	'@':
				_value = null;
				for (;;) {
					c = getc();
					if (c == -1)
						break;
					if (byte(c).isAlphanumeric() || c == '_' || (c & 0x80) != 0)
						addCharacter(c);
					else {
						ungetc();
						break;
					}
				}
				return Token.ANNOTATION;

			case	'[':
				return Token.LEFT_SQUARE;

			case	'\\':
				startValue(c);
				return Token.ERROR;

			case	']':
				return Token.RIGHT_SQUARE;

			case	'^':
				c = getc();
				if (c == '=')
					return Token.CARET_EQ;
				ungetc();
				return Token.CARET;

			case	'`':
				return consume(Token.IDENTIFIER, byte(c));

			case	'{':
				return Token.LEFT_CURLY;

			case	'|':
				c = getc();
				if (c == '=')
					return Token.VERTICAL_BAR_EQ;
				else if (c == '|')
					return Token.VBAR_VBAR;
				ungetc();
				return Token.VERTICAL_BAR;

			case	'}':
				return Token.RIGHT_CURLY;

			case	'~':
				return Token.TILDE;

			case	0x7f:
				startValue(c);
				return Token.ERROR;

				// Alphabetic characters and all Unicode characters above 127
				// are valid identifier characters.

			default:
				int cpc = compiler.codePointClass(c);
				if (cpc == compiler.CPC_WHITE_SPACE)
					continue;
				else if (cpc == compiler.CPC_ERROR) {
					startValue(c);
					return Token.ERROR;
				} else if (cpc == compiler.CPC_LETTER)
					return identifier(c);
				else
					return number(c);
			}
		}
	}

	private Token identifier(int c) {
		startValue(c);
		for (;;) {
			c = getc();
			if (c == -1)
				break;
			if (c == '_') {
				addCharacter(c);
				continue;
			}
			int cpc = compiler.codePointClass(c);
			if (cpc == compiler.CPC_ERROR || cpc == compiler.CPC_WHITE_SPACE) {
				ungetc();
				break;
			} else
				addCharacter(c);
		}
		Token t = keywords[_value.toLower()];
		if (t != null)
			return t;
		return Token.IDENTIFIER;
	}
	
	private Token number(int c) {
		Token t = Token.INTEGER;
		startValue(c);
		boolean hexConstant = false;
		if (c == '.')
			t = Token.FLOATING_POINT;
		else if (c == '0') {
			c = getc();
			if (c == 'x' || c == 'X') {
				hexConstant = true;
				addCharacter(c);
				c = getc();
				ungetc();
				if (compiler.codePointClass(c) == compiler.CPC_ERROR || compiler.codePointClass(c) == compiler.CPC_WHITE_SPACE)
					return Token.ERROR;
				else if (compiler.codePointClass(c) == compiler.CPC_LETTER && (c > 127 || !byte(c).isHexDigit()))
					return Token.ERROR;
			} else
				ungetc();
		}
		for (;;) {
			c = getc();
			int cpc = compiler.codePointClass(c);
			if (cpc == compiler.CPC_ERROR) {
				if (c == '.') {
					if (t == Token.FLOATING_POINT || hexConstant) {
						ungetc();
						return t;
					}
					t = Token.FLOATING_POINT;
					addCharacter(c);
					continue;
				}
				ungetc();
				return t;
			} else if (cpc == compiler.CPC_WHITE_SPACE) {
				ungetc();
				return t;
			} else if (cpc == compiler.CPC_LETTER) {
				switch (c) {
				case	'a':
				case	'b':
				case	'c':
				case	'd':
				case	'A':
				case	'B':
				case	'C':
				case	'D':
					if (!hexConstant) {
						ungetc();
						return t;
					}
					addCharacter(c);
					break;
					
				case	'e':
				case	'E':
					addCharacter(c);
					if (!hexConstant) {
						t = Token.FLOATING_POINT;
						c = getc();
						if (c == '+' || c == '-') {
							addCharacter(c);
							c = getc();
						}
						ungetc();
						int cpc = compiler.codePointClass(c);
						if (cpc == compiler.CPC_ERROR || cpc == compiler.CPC_WHITE_SPACE || cpc == compiler.CPC_LETTER)
							return Token.ERROR;
					}
					break;

				case	'f':
				case	'F':
					addCharacter(c);
					if (!hexConstant)
						return Token.FLOATING_POINT;
					break;

				default:
					ungetc();
					return t;
				}
			} else			// it's a digit
				addCharacter(c);
		}
	}

	private Token consume(Token t, byte delimiter) {
		_value = "";
		for (;;) {
			int c = getc();

			if (c == delimiter)
				return t;
			switch (c) {
			case -1:
				if (t != Token.ERROR)
					_value.insert(0, delimiter);
				return Token.ERROR;
				
			case '\r':
				break;
				
			case '\n':
				ungetc();
				if (t != Token.ERROR)
					_value.insert(0, delimiter);
				return Token.ERROR;
				
			case	'\\':
				unsigned value = 0;

				c = getc();

				while (c == '\r') 
					c = getc();

				switch (c) {
				case	-1:
					if (t != Token.ERROR)
						_value.insert(0, delimiter);
					return Token.ERROR;

				case	'\\':
				case	'a':
				case	'b':
				case	'f':
				case	'n':
				case	'r':
				case	't':
				case	'v':
				case	'"':
				case	'\'':
				case	'`':
					addCharacter('\\');			
					addCharacter(c);
					break;

				case	'u':
				case	'U':
					addCharacter('\\');			
					addCharacter(c);
					for (int i = 0; i < 8; i++) {
						c = getc();
						if (byte(c).isHexDigit()) {
							if (byte(c).isDigit())
								value = (value << 4) + unsigned(c - '0');
							else
								value = (value << 4) + 10 + unsigned(byte(c).toLowercase() - 'a');
							addCharacter(c);
						} else {
							ungetc();
							break;
						}
					}
					if (value > 0x7fffffff) {
						if (t != Token.ERROR)
							_value.insert(0, delimiter);
						t = Token.ERROR;
					}
					break;

				case	'x':
				case	'X':
					addCharacter('\\');			
					addCharacter(c);
					for (int i = 0; i < 2; i++) {
						c = getc();
						if (byte(c).isHexDigit()) {
							if (byte(c).isDigit())
								value = (value << 4) + unsigned(c - '0');
							else
								value = (value << 4) + 10 + unsigned(byte(c).toLowercase() - 'a');
							addCharacter(c);
						} else {
							ungetc();
							break;
						}
					}
					if (value > 0xff) {
						if (t != Token.ERROR)
							_value.insert(0, delimiter);
						t = Token.ERROR;
					}
					break;

				case	'0':
				case	'1':
				case	'2':
				case	'3':
				case	'4':
				case	'5':
				case	'6':
				case	'7':
					addCharacter('\\');			
					for (int i = 0; i < 3; i++) {
						if (c >= '0' && c <= '7') {
							value = (value << 3) + unsigned(c - '0');
							addCharacter(c);
						} else
							break;
						c = getc();
					}
					ungetc();
					if (value > 0xff) {
						if (t != Token.ERROR)
							_value.insert(0, delimiter);
						t = Token.ERROR;
					}
					break;

				case	'\n':
					break;

				default:
					addCharacter('\\');			
					addCharacter(c);
					if (t != Token.ERROR)
						_value.insert(0, delimiter);
					t = Token.ERROR;
				}
				break;
				
			default:
				addCharacter(c);
			}
		}
	}

	public void seek(int location) {
		_pushback = Token.EMPTY;
		_lastByte = -1;
		_lastChar = 0;
		_cursor = location;
	}

	public void pushBack(Token t) {
		_pushback = t;
	}
	
	public string value() {
		return _value;
	}
	
	public int location() { 
		return _location; 
	}

	public int lineNumber(int location) {
		int x = _lines.binarySearchClosestGreater(location);
		return _baseLineNumber + x;
	}
	/*
	 * Get the next Unicode code point from the input.
	 */
	int getc() {
		if (_lastChar < 0) {	// did we have EOF or an ungetc?
			if (_lastChar == -1)
				return -1;		// EOF just keep returning EOF
			int result = -1 - _lastChar;
			_lastChar = result;	// ungetc was called, undo it's effects and return the last char again
			_cursor = _nextCursor;
			return result;
		}
		_lastCursor = _cursor;
		int x;
		if (_lastByte >= 0) {
			x = _lastByte;
			_lastByte = -1;
		} else
			x = getByte();
		_cursor++;
		if (x < 0x80) {
			_lastChar = x;
			_nextCursor = _cursor;
			return x;
		}
		if ((x & 0xc0) == 0x80 || x == 0xff) {
			_lastChar = int.MAX_VALUE;			// ungetc will turn this into int.MIN_VALUE
			_nextCursor = _cursor;
			_errorByte = byte(x);
			return int.MAX_VALUE;
		}
		int value;
		if ((x & 0xe0) == 0xc0) {
			value = x & 0x1f;
			value = getMoreBytes(value, 1);
		} else if ((x & 0xf0) == 0xe0) {
			value = x & 0xf;
			value = getMoreBytes(value, 2);
		} else if ((x & 0xf8) == 0xf0) {
			value = x & 0x7;
			value = getMoreBytes(value, 3);
		} else if ((x & 0xfc) == 0xf8) {
			value = x & 0x3;
			value = getMoreBytes(value, 4);
		} else if ((x & 0xfe) == 0xfc) {
			value = x & 0x1;
			value = getMoreBytes(value, 5);
		}
		_lastChar = value;
		_nextCursor = _cursor;
		return value;
	}
	/*
	 * This function returns the current 'cursor' location of the
	 * Scanner.  This value is the offset of the next byte to be read
	 */
	protected int cursor() {
		return _cursor;
	}

	int getMoreBytes(int valueSoFar, int extraBytes) {
		for (int i = 0; i < extraBytes; i++) {
			int x = getByte();
			_cursor++;
			if ((x & ~0x3f) != 0x80) {
				_lastByte = x;
				_cursor--;
				_errorByte = 0xff;
				return int.MAX_VALUE;
			}
			int increment = x & 0x3f;
			valueSoFar = (valueSoFar << 6) + increment;
		}
		return valueSoFar;
	}
	
	void ungetc() {
		if (_lastChar >= 0) {
			_lastChar = -1 - _lastChar;
			_cursor = _lastCursor;
		}
	}

/*
	 * A Scanner must implement getByte.
	 *
	 * This function returns the next character in
	 * the input stream.  At end of stream, the function
	 * should return -1.  Windows implementations should
	 * treat a ctrl-Z as end of file inside the getByte function
	 * when treating the input as a 'text file'.  UNIX
	 * implementations reutrn all characters in a file.
	 *
	 * Scanners that read non-Unicode source files should
	 * convert their inputs to UTF-8.  Each call to getByte should
	 * return the next octet of the input stream.  If the input
	 * text is not well-formed UTF, display semantics may be
	 * unpredictable.  Malformed UTF sequences in identifiers
	 * will be treated verbatim and as long as all instances of
	 * the identifier share the same malformation, the code
	 * will compile.  Character and string literals will be checked
	 * for validity.
	 *
	 * If not at end of file, the 'cursor' of the Scanner will
	 * advance one octet in the input stream.
	 *
	 * At end of stream, getByte will continue to return -1 indefinitely.
	 */
	private int getByte() {
		if (!_file.opened())
			return -1;			// Should be a throw, maybe?
		int b = _file.read();
		if (b != file.EOF)
			return b;
		else
			return -1;
	}

	private void startValue(int c) {
		_value = null;
		_value.append(c);
	}

	private void addCharacter(int c) {
		_value.append(c);
	}

}

Token[string] keywords = [
	"bigint":		Token.BIGINT,
	"binary":		Token.BINARY,
	"blob":			Token.BLOB,
	"char":			Token.CHAR,
	"create":		Token.CREATE,
	"current_user":	Token.CURRENT_USER,
	"dec":			Token.DECIMAL,
	"decimal":		Token.DECIMAL,
	"definer":		Token.DEFINER,
	"double":		Token.DOUBLE_PRECISION,
	"double_precision": Token.DOUBLE_PRECISION,
	"enum":			Token.ENUM,
	"fixed":		Token.DECIMAL,
	"float":		Token.FLOAT,
	"in":			Token.IN,
	"inout":		Token.INOUT,
	"int":			Token.INTEGER,
	"integer":		Token.INTEGER,
	"out":			Token.OUT,
	"procedure":	Token.PROCEDURE,
	"real":			Token.DOUBLE_PRECISION,
	"smallint":		Token.SMALLINT,
	"set":			Token.SET,
	"text":			Token.TEXT,
	"tinyint":		Token.TINYINT,
	"varbinary":	Token.VARBINARY,
	"varchar":		Token.VARCHAR,
];
