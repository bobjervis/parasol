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
	CATCH,
	CLASS,
	CONTINUE,
	DEFAULT,
	DELETE,
	DO,
	ELSE,
	ENUM,
	EXTENDS,
	FALSE,
	FINAL,
	FINALLY,
	FLAGS,
	FOR,
	FUNCTION,
	IF,
	IMPLEMENTS,
	IMPORT,
	INTERFACE,
	LOCK,
	MONITOR,
	NAMESPACE,
	NEW,
	NULL,
	PRIVATE,
	PROTECTED,
	PUBLIC,
	RETURN,
	SELF,
	STATIC,
	SUPER,
	SWITCH,
	THIS,
	THROW,
	TRUE,
	TRY,
	WHILE,

	// Pseudo-tokens not actually returned by a Scanner

	EMPTY,
	MAX_TOKEN //= EMPTY
}

class FileScanner extends Scanner {
	private file.File _file;
	
	public FileScanner(ref<FileStat> fileInfo) {
		super(0, fileInfo);
		_file = file.openBinaryFile(fileInfo.filename());
	}

	~FileScanner() {
		close();
	}
	
	int getByte() {
		if (!_file.opened())
			return -1;			// Should be a throw, maybe?
		int b = _file.read();
		if (b != file.EOF)
			return b;
		else
			return -1;
	}

	public void seek(Location location) {
		_file.seek(location.offset, file.Seek.START);
		super.seek(location);
	}

	public boolean opened() { 
		return _file.opened(); 
	}

	public void close() {
		if (_file.opened())
			_file.close();
	}	
}

public class StringScanner extends Scanner {
	private string _source;
	private int _cursor;
	
	public StringScanner(string source, int baseLineNumber, string sourceName) {
		super(baseLineNumber, null);
		_source = source;
	}

	public int getByte() {
		if (_cursor < _source.length())
			return _source[_cursor++];
		else
			return -1;
	}

	public void seek(Location location) {
		_cursor = location.offset;
		super.seek(location);
	}
}

class Scanner {
	private Token _pushback;
	private Location[] _lines;
	private string _value;
	private ref<FileStat> _file;
	private boolean _utfError;
	private int _baseLineNumber;		// Line number of first character in scanner input.
	/*
	 * Location of the last token read.
	 */
	private Location _location;
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
		_lastByte = -1;
		_baseLineNumber = baseLineNumber;
		_file = file;
	}

	public boolean opened() {
		return true;
	}

	public void close() {
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
				Location spLoc = _location;
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
				int cpc = codePointClass(c);
				if (cpc == CPC_WHITE_SPACE)
					continue;
				else if (cpc == CPC_ERROR) {
					startValue(c);
					return Token.ERROR;
				} else if (cpc == CPC_LETTER)
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
			int cpc = codePointClass(c);
			if (cpc == CPC_ERROR || cpc == CPC_WHITE_SPACE) {
				ungetc();
				break;
			} else
				addCharacter(c);
		}
		Token t = keywords[_value];
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
				if (codePointClass(c) == CPC_ERROR || codePointClass(c) == CPC_WHITE_SPACE)
					return Token.ERROR;
				else if (codePointClass(c) == CPC_LETTER && (c > 127 || !byte(c).isHexDigit()))
					return Token.ERROR;
			} else
				ungetc();
		}
		for (;;) {
			c = getc();
			int cpc = codePointClass(c);
			if (cpc == CPC_ERROR) {
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
			} else if (cpc == CPC_WHITE_SPACE) {
				ungetc();
				return t;
			} else if (cpc == CPC_LETTER) {
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
						int cpc = codePointClass(c);
						if (cpc == CPC_ERROR || cpc == CPC_WHITE_SPACE || cpc == CPC_LETTER)
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

	public void seek(Location location) {
		_pushback = Token.EMPTY;
		_lastByte = -1;
		_lastChar = 0;
		_cursor = location.offset;
	}

	public void pushBack(Token t) {
		_pushback = t;
	}
	
	public CompileString value() {
		CompileString result(&_value[0], _value.length());
		return result;
	}
	
	public Location location() { 
		return _location; 
	}

	public int lineNumber(Location location) {
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
	protected Location cursor() {
		return Location(_cursor);
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
	protected abstract int getByte();

	private void startValue(int c) {
		_value = null;
		_value.append(c);
	}

	private void addCharacter(int c) {
		_value.append(c);
	}

}

Token[string] keywords = [
	"abstract":		Token.ABSTRACT,
	"break":		Token.BREAK,
	"bytes": 		Token.BYTES,
	"case": 		Token.CASE,
	"catch": 		Token.CATCH,
	"class": 		Token.CLASS,
	"continue": 	Token.CONTINUE,
	"default": 		Token.DEFAULT,
	"delete": 		Token.DELETE,
	"do": 			Token.DO,
	"else": 		Token.ELSE,
	"enum": 		Token.ENUM,
	"extends":		Token.EXTENDS,
	"false": 		Token.FALSE,
	"final": 		Token.FINAL,
	"finally":		Token.FINALLY,
	"flags": 		Token.FLAGS,
	"for": 			Token.FOR,
	"function": 	Token.FUNCTION,
	"if": 			Token.IF,
	"implements":	Token.IMPLEMENTS,
	"import": 		Token.IMPORT,
	"interface":	Token.INTERFACE,
	"lock":			Token.LOCK,
	"monitor": 		Token.MONITOR,
	"namespace":	Token.NAMESPACE,
	"new": 			Token.NEW,
	"null": 		Token.NULL,
	"private":		Token.PRIVATE,
	"protected": 	Token.PROTECTED,
	"public": 		Token.PUBLIC,
	"return": 		Token.RETURN,
	"self":			Token.SELF,
	"static": 		Token.STATIC,
	"super": 		Token.SUPER,
	"switch": 		Token.SWITCH,
	"this": 		Token.THIS,
	"throw":		Token.THROW,
	"true": 		Token.TRUE,
	"try": 			Token.TRY,
	"while":		Token.WHILE,
];
