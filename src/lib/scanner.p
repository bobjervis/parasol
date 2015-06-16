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

import parasol:file;

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

	ABSTRACT,
	BREAK,
	BYTES,
	CASE,
	CONTINUE,
	CLASS,
	DEFAULT,
	DELETE,
	DO,
	ELSE,
	ENUM,
	EXTENDS,
	FALSE,
	FINAL,
	FOR,
	FUNCTION,
	IF,
	IMPLEMENTS,
	IMPORT,
	NAMESPACE,
	NEW,
	NULL,
	PRIVATE,
	PROTECTED,
	PUBLIC,
	RETURN,
	STATIC,
	SUPER,
	SWITCH,
	THIS,
	TRUE,
	WHILE,

	// Pseudo-tokens not actually returned by a Scanner

	EMPTY,
	MAX_TOKEN //= EMPTY
}

class FileScanner extends Scanner {
	private file.File _file;
	private Location _fileSize;
	private boolean _pushedBack;		// true if ungetc is called.
	private int _pushBack;
	
	public FileScanner(ref<FileStat> fileInfo) {
		super(0, fileInfo);
		_file = file.openTextFile(fileInfo.filename());
		if (_file.opened()) {
			_fileSize.offset = _file.seek(0, file.Seek.END);
			_file.seek(0, file.Seek.START);
		}
	}

	int getc() {
		if (!_file.opened())
			return -1;
		if (_pushedBack) {
			_pushedBack = false;
			return _pushBack;
		}
		_pushBack = _file.read();
		if (_pushBack != file.EOF)
			return _pushBack;
		else {
			_file.close();
			return -1;
		}
	}

	Location cursor() {
		Location loc;

		if (_file.opened())
			loc.offset = _file.tell();
		else
			loc = _fileSize;
		if (_pushedBack)
			loc.offset--;
		return loc;
	}

	void ungetc() {
		_pushedBack = true;
	}

	public void seek(Location location) {
		_pushedBack = false;
		_file.seek(location.offset, file.Seek.START);
	}

	public boolean opened() { 
		return _file.opened(); 
	}
}

public class StringScanner extends Scanner {
	private string _source;
	private int _cursor;
	
	public StringScanner(string source, int baseLineNumber, string sourceName) {
		super(baseLineNumber, null);
		_source = source;
	}

	public int getc() {
		if (_cursor < _source.length())
			return _source[_cursor++];
		else {
			_cursor = _source.length() + 1;
			return -1;
		}
	}

	public Location cursor() {
		Location loc;
		if (_cursor <= _source.length())
			loc.offset = _cursor;
		else
			loc.offset = _source.length();
		return loc;
	}

	public void ungetc() {
		if (_cursor > 0 && _cursor <= _source.length())
			_cursor--;
	}

	public void seek(Location location) {
		_cursor = location.offset;
	}
}

class Scanner {
	private Token _pushback;
	private Token _last;
	private Location[] _lines;
	private byte[] _value;
	private ref<FileStat> _file;
	private int _baseLineNumber;		// Line number of first character in scanner input.
	/*
	 * Location of the last token read.
	 */
	private Location _location;

	public static ref<Scanner> create(ref<FileStat> file) {
		ref<Scanner> scanner;
		if (file.source() != null)
			scanner = new StringScanner(file.source(), 0, "<inline>");
		else
			scanner = new FileScanner(file);
		return scanner;
	}
	
	protected Scanner(int baseLineNumber, ref<FileStat> file) {
		_pushback = Token.EMPTY;
		_last = Token.EMPTY;
		_baseLineNumber = baseLineNumber;
		_file = file;
	}

	public boolean opened() {
		return true;
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
			case	-1:
				return remember(Token.END_OF_STREAM);

			case	0x00:
			case	0x01:
			case	0x02:
			case	0x03:
			case	0x04:
			case	0x05:
			case	0x06:
			case	0x07:
			case	0x08:
				return remember(Token.ERROR, c);

			case	'\t':
				continue;

			case	'\n':
				_lines.append(_location);
				continue;

			case	0x0b:
				return remember(Token.ERROR, c);

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
				return remember(Token.ERROR, c);

			case	' ':
				_location = cursor();
				c = getc();
				if (c == '<') {
					c = getc();
					if (c == '=')
						return remember(Token.LA_EQ);
					else if (c == '<') {
						c = getc();
						if (c == '=')
							return remember(Token.LA_LA_EQ);
						ungetc();
						return remember(Token.LA_LA);
					} else if (c == '>') {
						c = getc();
						if (c == '=')
							return remember(Token.LA_RA_EQ);
						ungetc();
						return remember(Token.LA_RA);
					}
					ungetc();
					return remember(Token.SP_LA);
				} else if (c == '>') {
					c = getc();
					if (c == '=')
						return remember(Token.RA_EQ);
					else if (c == '>') {
						c = getc();
						if (c == '=')
							return remember(Token.RA_RA_EQ);
						else if (c == '>') {
							c = getc();
							if (c == '=')
								return remember(Token.RA_RA_RA_EQ);
							ungetc();
							return remember(Token.RA_RA_RA);
						}
						ungetc();
						return remember(Token.RA_RA);
					}
					ungetc();
					return remember(Token.SP_RA);
				}
				ungetc();
				continue;

			case	'!':
				c = getc();
				switch (c) {
				case	'=':
					c = getc();
					if (c == '=')
						return remember(Token.EX_EQ_EQ);
					ungetc();
					return remember(Token.EXCLAMATION_EQ);

				case	'<':
					c = getc();
					if (c == '=')
						return remember(Token.EX_LA_EQ);
					else if (c == '>') {
						c = getc();
						if (c == '=')
							return remember(Token.EX_LA_RA_EQ);
						ungetc();
						return remember(Token.EX_LA_RA);
					}
					ungetc();
					return remember(Token.EX_LA);

				case	'>':
					c = getc();
					if (c == '=')
						return remember(Token.EX_RA_EQ);
					ungetc();
					return remember(Token.EX_RA);

				default:
					ungetc();
					return remember(Token.EXCLAMATION);
				}

			case	'"':
				return remember(consume(Token.STRING, byte(c)));

			case	'#':
			case	'$':
				return remember(Token.ERROR, c);

			case	'%':
				c = getc();
				if (c == '=')
					return remember(Token.PERCENT_EQ);
				ungetc();
				return remember(Token.PERCENT);

			case	'&':
				c = getc();
				if (c == '=')
					return remember(Token.AMPERSAND_EQ);
				else if (c == '&')
					return remember(Token.AMP_AMP);
				ungetc();
				return Token.AMPERSAND;

			case	'\'':
				return remember(consume(Token.CHARACTER, byte(c)));

			case	'(':
				return remember(Token.LEFT_PARENTHESIS);

			case	')':
				return remember(Token.RIGHT_PARENTHESIS);

			case	'*':
				c = getc();
				if (c == '=')
					return remember(Token.ASTERISK_EQ);
				ungetc();
				return remember(Token.ASTERISK);

			case	'+':
				c = getc();
				if (c == '=')
					return remember(Token.PLUS_EQ);
				else if (c == '+')
					return remember(Token.PLUS_PLUS);
				ungetc();
				return remember(Token.PLUS);

			case	',':
				return remember(Token.COMMA);

			case	'-':
				c = getc();
				if (c == '=')
					return remember(Token.DASH_EQ);
				else if (c == '-')
					return remember(Token.DASH_DASH);
				ungetc();
				return remember(Token.DASH);

			case	'.':
				c = getc();
				if (c == '.') {
					c = getc();
					if (c == '.')
						return remember(Token.ELLIPSIS);
					ungetc();
					return remember(Token.DOT_DOT);
				} else if (byte(c).isDigit()) {
					ungetc();
					return remember(number('.'));
				}
				ungetc();
				return remember(Token.DOT);

			case	'/':
				c = getc();
				if (c == '=')
					return remember(Token.SLASH_EQ);
				else if (c == '/') {
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
				} else if (c == '*') {
					// Block comments nest, this tracks the nesting depth
					int depth = 0;
					for (;;) {
						c = getc();
						if (c == -1) {
							// Set up a 'value' that will indicate
							// the context of the error.
							startValue('/');
							addByte('*');
							return remember(Token.ERROR);
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
				return remember(Token.SLASH);

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
				return remember(number(c));

			case	':':
				return remember(Token.COLON);

			case	';':
				return remember(Token.SEMI_COLON);

			case	'<':
				c = getc();
				if (c == '=')
					return remember(Token.LA_EQ);
				else if (c == '<') {
					c = getc();
					if (c == '=')
						return remember(Token.LA_LA_EQ);
					ungetc();
					return remember(Token.LA_LA);
				} else if (c == '>') {
					c = getc();
					if (c == '=')
						return remember(Token.LA_RA_EQ);
					ungetc();
					return remember(Token.LA_RA);
				}
				ungetc();
				return remember(Token.LEFT_ANGLE);

			case	'=':
				c = getc();
				if (c == '=') {
					c = getc();
					if (c == '=')
						return remember(Token.EQ_EQ_EQ);
					ungetc();
					return remember(Token.EQ_EQ);
				}
				ungetc();
				return remember(Token.EQUALS);

			case	'>':
				c = getc();
				if (c == '=')
					return remember(Token.RA_EQ);
				ungetc();
				return remember(Token.RIGHT_ANGLE);

			case	'?':
				return remember(Token.QUESTION_MARK);

			case	'@':
				_value.clear();
				for (;;) {
					c = getc();
					if (c == -1)
						break;
					if (byte(c).isAlphanumeric() || c == '_' || (c & 0x80) != 0)
						addByte(c);
					else {
						ungetc();
						break;
					}
				}
				return remember(Token.ANNOTATION);

			case	'[':
				return remember(Token.LEFT_SQUARE);

			case	'\\':
				return remember(Token.ERROR, c);

			case	']':
				return remember(Token.RIGHT_SQUARE);

			case	'^':
				c = getc();
				if (c == '=')
					return remember(Token.CARET_EQ);
				ungetc();
				return remember(Token.CARET);

			case	'`':
				return remember(consume(Token.IDENTIFIER, byte(c)));

			case	'{':
				return remember(Token.LEFT_CURLY);

			case	'|':
				c = getc();
				if (c == '=')
					return remember(Token.VERTICAL_BAR_EQ);
				else if (c == '|')
					return remember(Token.VBAR_VBAR);
				ungetc();
				return remember(Token.VERTICAL_BAR);

			case	'}':
				return remember(Token.RIGHT_CURLY);

			case	'~':
				return remember(Token.TILDE);

			case	0x7f:
				return remember(Token.ERROR, c);

				// Alphabetic characters, underline and all Unicode characters above 127
				// are valid identifier characters.

			default:
				startValue(c);
				for (;;) {
					c = getc();
					if (c == -1)
						break;
					if (byte(c).isAlphanumeric() || c == '_' || (c & 0x80) != 0)
						addByte(c);
					else {
						ungetc();
						break;
					}
				}
				Token t = keywords.getKeyword(&_value[0], _value.length());
				if (t != null)
					return remember(t);
				return remember(Token.IDENTIFIER);
			}
		}
	}

	public abstract void seek(Location location);

	public void pushBack(Token t) {
		_pushback = t;
	}
	
	public CompileString value() {
		CompileString result(&_value);
		return result;
	}
	
/*
	Token last() { return _last; }
*/
	public Location location() { 
		return _location; 
	}

	public int lineNumber(Location location) {
		if (_last == Token.END_OF_STREAM)
			return _baseLineNumber + binarySearchClosestGreater(&_lines, location);
		else
			return -1;
	}
/*
	const char *sourceName();
 */
	/*
	 * A Scanner must implement getc.
	 *
	 * This function returns the next character in
	 * the input stream.  At end of stream, the function
	 * should return -1.  Windows implementations should
	 * treat a ctrl-Z as end of file inside the getc function
	 * when treating the input as a 'text file'.  UNIX
	 * implementations reutrn all characters in a file.
	 *
	 * Scanners that read non-Unicode source files should
	 * convert their inputs to UTF-8.  Each call to getc should
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
	 * At end of stream, getc will continue to return -1 indefinitely.
	 */
	protected abstract int getc();
	/*
	 * This function returns the current 'cursor' location of the
	 * Scanner.  This value 
	 */
	protected abstract Location cursor();

	protected abstract void ungetc();

	private Token remember(Token t) { 
		return _last = t; 
	}

	private Token remember(Token t, int c) {
		startValue(c);
		_last = t;
		return t;
	}

	private void startValue(int c) {
		_value.clear();
		_value.append(byte(c));
	}

	private void addByte(int c) {
		_value.append(byte(c));
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
				addByte(c);
				c = getc();
				ungetc();
				if (!byte(c).isHexDigit())
					return Token.ERROR;
			} else
				ungetc();
		}
		for (;;) {
			c = getc();
			switch (c) {
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
				addByte(c);
				break;

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
				addByte(c);
				break;

			case	'.':
				if (t == Token.FLOATING_POINT || hexConstant) {
					ungetc();
					return t;
				}
				t = Token.FLOATING_POINT;
				addByte(c);
				break;

			case	'e':
			case	'E':
				addByte(c);
				if (!hexConstant) {
					t = Token.FLOATING_POINT;
					c = getc();
					if (c == '+' || c == '-') {
						addByte(c);
						c = getc();
					}
					ungetc();
					if (!byte(c).isDigit())
						return Token.ERROR;
				}
				break;

			case	'f':
			case	'F':
				addByte(c);
				if (!hexConstant)
					return Token.FLOATING_POINT;
				break;

			default:
				ungetc();
				return t;
			}
		}
	}

	private Token consume(Token t, byte delimiter) {
		_value.clear();
		for (;;) {
			int c = getc();

			if (c == -1) {
				if (t != Token.ERROR)
					_value.insert(0, delimiter);
				return Token.ERROR;
			}
			if (c == delimiter)
				return t;
			if (c == '\n') {
				ungetc();
				if (t != Token.ERROR)
					_value.insert(0, delimiter);
				return Token.ERROR;
			}
			if (c == '\\') {
				addByte('\\');			
				unsigned value = 0;

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
					addByte(c);
					break;

				case	'u':
				case	'U':
					addByte(c);
					for (int i = 0; i < 8; i++) {
						c = getc();
						if (byte(c).isHexDigit()) {
							if (byte(c).isDigit())
								value = (value << 4) + unsigned(c - '0');
							else
								value = (value << 4) + 10 + unsigned(byte(c).toLowercase() - 'a');
							addByte(c);
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
					addByte(c);
					for (int i = 0; i < 2; i++) {
						c = getc();
						if (byte(c).isHexDigit()) {
							if (byte(c).isDigit())
								value = (value << 4) + unsigned(c - '0');
							else
								value = (value << 4) + 10 + unsigned(byte(c).toLowercase() - 'a');
							addByte(c);
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
					for (int i = 0; i < 3; i++) {
						if (c >= '0' && c <= '7') {
							value = (value << 3) + unsigned(c - '0');
							addByte(c);
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
					ungetc();
					if (t != Token.ERROR)
						_value.insert(0, delimiter);
					return Token.ERROR;

				default:
					addByte(c);
					if (t != Token.ERROR)
						_value.insert(0, delimiter);
					t = Token.ERROR;
				}
			} else
				addByte(c);
		}
	}
/*
	void writeUtf8(unsigned codePoint);

	Token _last;
	vector<Location> _lines;
	int _baseLineNumber;		// Line number of first character in scanner input.
	FileStat *_file;
*/
}

class Keywords {
	private Token[string] _keywords;

	public Keywords() {
		_keywords["abstract"] = Token.ABSTRACT;
		_keywords["break"] = Token.BREAK;
		_keywords["bytes"] = Token.BYTES;
		_keywords["case"] = Token.CASE;
		_keywords["class"] = Token.CLASS;
		_keywords["continue"] = Token.CONTINUE;
		_keywords["default"] = Token.DEFAULT;
		_keywords["delete"] = Token.DELETE;
		_keywords["do"] = Token.DO;
		_keywords["else"] = Token.ELSE;
		_keywords["enum"] = Token.ENUM;
		_keywords["extends"] = Token.EXTENDS;
		_keywords["false"] = Token.FALSE;
		_keywords["final"] = Token.FINAL;
		_keywords["for"] = Token.FOR;
		_keywords["function"] = Token.FUNCTION;
		_keywords["if"] = Token.IF;
		_keywords["implements"] = Token.IMPLEMENTS;
		_keywords["import"] = Token.IMPORT;
		_keywords["namespace"] = Token.NAMESPACE;
		_keywords["new"] = Token.NEW;
		_keywords["null"] = Token.NULL;
		_keywords["private"] = Token.PRIVATE;
		_keywords["protected"] = Token.PROTECTED;
		_keywords["public"] = Token.PUBLIC;
		_keywords["return"] = Token.RETURN;
		_keywords["static"] = Token.STATIC;
		_keywords["super"] = Token.SUPER;
		_keywords["switch"] = Token.SWITCH;
		_keywords["this"] = Token.THIS;
		_keywords["true"] = Token.TRUE;
		_keywords["while"] = Token.WHILE;
	}

	Token getKeyword(pointer<byte> name, int length) {
		string s(name, length);

		return _keywords[s];
	}
}

Keywords keywords;

/*
 *	binarySearchClosestGreater
 *
 *	This function does a binary search on an already sorted array.
 *	The key class must define a compare method that returns < 0
 *	if the key is less than its argument, > 0 if it is greater and
 *	0 if they are equal.
 *
 *	RETURNS:
 *		-1			If there are no elements in the array.
 *		N < size	If element N is the smallest greater than the key.
 *		size		If no element is greater than the key.
 */
int binarySearchClosestGreater(ref<Location[]> list, Location key) {
	int min = 0;
	int max = list.length() - 1;
	int mid = -1;
	int relation = -1;

	while (min <= max) {
		mid = (max + min) / 2;
		relation = key.compare(list.get(mid));
		if (relation == 0)
			return mid;
		if (relation < 0)
			max = mid - 1;
		else
			min = mid + 1;
	}
	if (relation > 0)
		mid++;
	return mid;
}

class Tokens {
	public	Tokens() {
		name.resize(Token.MAX_TOKEN);
		name[Token.ERROR] = "T_ERROR";
		name[Token.END_OF_STREAM] = "T_END_OF_STREAM";

		// Each of these tokens has an associated 'value'

		name[Token.IDENTIFIER] = "T_IDENTIFIER";
		name[Token.INTEGER] = "T_INTEGER";
		name[Token.FLOATING_POINT] = "T_FLOATING_POINT";
		name[Token.CHARACTER] = "T_CHARACTER";
		name[Token.STRING] = "T_STRING";
		name[Token.ANNOTATION] = "T_ANNOTATION";

		// Each of these are paired tokens:

		name[Token.LEFT_PARENTHESIS] = "T_LEFT_PARENTHESIS";
		name[Token.RIGHT_PARENTHESIS] = "T_RIGHT_PARENTHESIS";
		name[Token.LEFT_CURLY] = "T_LEFT_CURLY";
		name[Token.RIGHT_CURLY] = "T_RIGHT_CURLY";
		name[Token.LEFT_SQUARE] = "T_LEFT_SQUARE";
		name[Token.RIGHT_SQUARE] = "T_RIGHT_SQUARE";
		name[Token.LEFT_ANGLE] = "T_LEFT_ANGLE";
		name[Token.RIGHT_ANGLE] = "T_RIGHT_ANGLE";
		name[Token.SP_LA] = "T_SP_LA";
		name[Token.SP_RA] = "T_SP_RA";

		// These are single character tokens:

		name[Token.SEMI_COLON] = "T_SEMI_COLON";
		name[Token.COLON] = "T_COLON";
		name[Token.DOT] = "T_DOT";
		name[Token.COMMA] = "T_COMMA";
		name[Token.SLASH] = "T_SLASH";
		name[Token.PERCENT] = "T_PERCENT";
		name[Token.ASTERISK] = "T_ASTERISK";
		name[Token.PLUS] = "T_PLUS";
		name[Token.DASH] = "T_DASH";
		name[Token.AMPERSAND] = "T_AMPERSAND";
		name[Token.CARET] = "T_CARET";
		name[Token.VERTICAL_BAR] = "T_VERTICAL_BAR";
		name[Token.EXCLAMATION] = "T_EXCLAMATION";
		name[Token.EQUALS] = "T_EQUALS";
		name[Token.QUESTION_MARK] = "T_QUESTION_MARK";
		name[Token.TILDE] = "T_TILDE";

		// These are multi-character tokens:

		name[Token.ELLIPSIS] = "T_ELLIPSIS";
		name[Token.DOT_DOT] = "T_DOT_DOT";
		name[Token.SLASH_EQ] = "T_SLASH_EQ";
		name[Token.PERCENT_EQ] = "T_PERCENT_EQ";
		name[Token.ASTERISK_EQ] = "T_ASTERISK_EQ";
		name[Token.PLUS_EQ] = "T_PLUS_EQ";
		name[Token.DASH_EQ] = "T_DASH_EQ";
		name[Token.AMPERSAND_EQ] = "T_AMPERSAND_EQ";
		name[Token.CARET_EQ] = "T_CARET_EQ";
		name[Token.VERTICAL_BAR_EQ] = "T_VERTICAL_BAR_EQ";
		name[Token.EQ_EQ] = "T_EQ_EQ";						// ==
		name[Token.EQ_EQ_EQ] = "T_EQ_EQ_EQ";						// ===
		name[Token.LA_EQ] = "T_LA_EQ";						// <=
		name[Token.RA_EQ] = "T_RA_EQ";						// >=
		name[Token.LA_RA] = "T_LA_RA";						// <>
		name[Token.LA_RA_EQ] = "T_LA_RA_EQ";						// <>=
		name[Token.EXCLAMATION_EQ] = "T_EXCLAMATION_EQ";				// !=
		name[Token.EX_EQ_EQ] = "T_EX_EQ_EQ";						// !==
		name[Token.EX_LA] = "T_EX_LA";						// !<
		name[Token.EX_RA] = "T_EX_RA";						// !>
		name[Token.EX_LA_EQ] = "T_EX_LA_EQ";						// !<=
		name[Token.EX_RA_EQ] = "T_EX_RA_EQ";						// !>=
		name[Token.EX_LA_RA] = "T_EX_LA_RA";						// !<>
		name[Token.EX_LA_RA_EQ] = "T_EX_LA_RA_EQ";					// !<>=
		name[Token.LA_LA] = "T_LA_LA";						// <<
		name[Token.RA_RA] = "T_RA_RA";						// >>
		name[Token.RA_RA_RA] = "T_RA_RA_RA";						// >>>
		name[Token.LA_LA_EQ] = "T_LA_LA_EQ";						// <<=
		name[Token.RA_RA_EQ] = "T_RA_RA_EQ";						// >>=
		name[Token.RA_RA_RA_EQ] = "T_RA_RA_RA_EQ";					// >>>=
		name[Token.AMP_AMP] = "T_AMP_AMP";						// &&
		name[Token.VBAR_VBAR] = "T_VBAR_VBAR";					// ||
		name[Token.PLUS_PLUS] = "T_PLUS_PLUS";					// ++
		name[Token.DASH_DASH] = "T_DASH_DASH";					// --

		// Keywords

		name[Token.ABSTRACT] = "T_ABSTRACT";
		name[Token.BREAK] = "T_BREAK";
		name[Token.BYTES] = "T_BYTES";
		name[Token.CASE] = "T_CASE";
		name[Token.CONTINUE] = "T_CONTINUE";
		name[Token.CLASS] = "T_CLASS";
		name[Token.DEFAULT] = "T_DEFAULT";
		name[Token.DELETE] = "T_DELETE";
		name[Token.DO] = "T_DO";
		name[Token.ELSE] = "T_ELSE";
		name[Token.ENUM] = "T_ENUM";
		name[Token.EXTENDS] = "T_EXTENDS";
		name[Token.FALSE] = "T_FALSE";
		name[Token.FINAL] = "T_FINAL";
		name[Token.FOR] = "T_FOR";
		name[Token.FUNCTION] = "T_FUNCTION";
		name[Token.IF] = "T_IF";
		name[Token.IMPLEMENTS] = "T_IMPLEMENTS";
		name[Token.IMPORT] = "T_IMPORT";
		name[Token.NAMESPACE] = "T_NAMESPACE";
		name[Token.NEW] = "T_NEW";
		name[Token.NULL] = "T_NULL";
		name[Token.PRIVATE] = "T_PRIVATE";
		name[Token.PROTECTED] = "T_PROTECTED";
		name[Token.PUBLIC] = "T_PUBLIC";
		name[Token.RETURN] = "T_RETURN";
		name[Token.STATIC] = "T_STATIC";
		name[Token.SUPER] = "T_SUPER";
		name[Token.SWITCH] = "T_SWITCH";
		name[Token.THIS] = "T_THIS";
		name[Token.TRUE] = "T_TRUE";
		name[Token.WHILE] = "T_WHILE";

		// Pseudo-tokens not actually returned by a Scanner

		name[Token.EMPTY] = "T_EMPTY";

		string last = "<none>";
		int lastI = -1;
		for (int i = 0; i < int(Token.MAX_TOKEN); i++)
			if (name[Token(i)] == null) {
				printf("ERROR: Tokenr %d has no name entry (last defined entry: %s %d)\n", i, last, lastI);
			} else {
				last = name[Token(i)];
				lastI = i;
			}
	}

	static string[Token] name;
}

public Tokens tokens;


