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
namespace parasol:json;

import parasol:compiler.codePointClass;
import parasol:compiler.CompileString;
import parasol:compiler.CPC_LETTER;
import parasol:compiler.Location;

public var, boolean parse(string text) {
	Parser parser(text);
	var x;
	boolean success;
	
	(x, success) = parser.parse();
	return x, success;
}

class Parser {
	Scanner _scanner;
	boolean _error;
	
	Parser(string text) {
		_scanner.setSource(text);
	}
	
	var, boolean parse() {
		var x = parseValue();
		printf("_error = %s\n", _error ? "true" : "false");
		return x, !_error;
	}
	
	var parseValue() {
		Token t = _scanner.next();
		var v;
		switch (t) {
		case	LEFT_CURLY:
//			return;

		case	LEFT_SQUARE:
//			return;
		
		case	NUMBER:
			return _scanner.numberValue();
		
		case	STRING:
			return _scanner.stringValue();
		
		case	FALSE:
			return false;
		
		case	TRUE:
			return true;
		
		case	NULL:
			return null;
		}
		_error = true;
		return 0;
	}
}
enum Token {
	ERROR,
	END_OF_STREAM,

	// Each of these tokens has an associated 'value'

	NUMBER,
	STRING,

	// Each of these are paired tokens:

	LEFT_CURLY,
	RIGHT_CURLY,
	LEFT_SQUARE,
	RIGHT_SQUARE,

	// These are single character tokens:

	COLON,
	COMMA,

	// Keywords

	FALSE,
	NULL,
	TRUE,

	// Pseudo-tokens not actually returned by a Scanner

	EMPTY,
	MAX_TOKEN //= EMPTY
}

class Scanner {
	private string _source;
	private Token _pushback;
	private string _value;
	private boolean _utfError;
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
	
	public Scanner() {
		_pushback = Token.EMPTY;
		_lastByte = -1;
	}
	
	public void setSource(string text) {
		_source = text;
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

			case	'\t':
			case	'\n':
			case	'\r':
			case	' ':
				continue;

			case	'"':
				return stringLiteral();

			case	',':
				return Token.COMMA;

			case	'-':
				c = getc();
				if (byte(c).isDigit()) {
					startValue('-');
					return number(c);
				}
				ungetc();

			default:
				startValue(c);
				return Token.ERROR;

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
				clearValue();
				return number(c);

			case	'f':
			case	'n':
			case	't':
				return identifier(c);
				
			case	':':
				return Token.COLON;

			case	'[':
				return Token.LEFT_SQUARE;

			case	']':
				return Token.RIGHT_SQUARE;

			case	'{':
				return Token.LEFT_CURLY;

			case	'}':
				return Token.RIGHT_CURLY;
			}
		}
	}

	private Token identifier(int c) {
		startValue(c);
		for (;;) {
			c = getc();
			if (c == -1)
				break;
			int cpc = codePointClass(c);
			if (cpc == CPC_LETTER)
				addCharacter(c);
			else {
				ungetc();
				break;
			}
		}
		// returns ERROR on any miss
		return keywords[_value];
	}
	
	private Token number(int c) {
		Token t = Token.NUMBER;
		if (c == '0') {
			int x = getc();
			ungetc();
			if (x.isDigit())
				t = Token.ERROR;
		}
		addCharacter(c);
		// We know we have a prefix already stored, either a digit or minus and a digit.
		for (;;) {
			c = getc();
			if (!c.isDigit())
				break;
			addCharacter(c);
		}
		c == getc();
		if (c == '.') {
			addCharacter(c);
			boolean anyDigits;
			for (;;) {
				c = getc();
				if (!c.isDigit())
					break;
				addCharacter(c);
				anyDigits = true;
			}
			if (!anyDigits)
				t = Token.ERROR;
		}
		if (c == 'e' || c == 'E') {
			addCharacter(c);
			c = getc();
			if (c == '+' || c == '-') {
				addCharacter(c);
				c = getc();
			}
			boolean anyDigits;
			for (;;) {
				c = getc();
				if (!c.isDigit())
					break;
				addCharacter(c);
				anyDigits = true;
			}
			if (!anyDigits)
				t = Token.ERROR;
		}
		return t;
	}

	private Token stringLiteral() {
		Token t = Token.STRING;
		_value = "";
		for (;;) {
			int c = getc();
			switch (c) {
			case -1:
				if (t != Token.ERROR)
					_value.insert(0, '"');
				return Token.ERROR;
				
			case '"':
				return t;

			case '\r':
				break;
				
			case '\n':
				ungetc();
				if (t != Token.ERROR)
					_value.insert(0, '"');
				return Token.ERROR;
				
			case	'\\':
				unsigned value = 0;

				c = getc();

				while (c == '\r') 
					c = getc();

				switch (c) {
				case	-1:
					if (t != Token.ERROR)
						_value.insert(0, '"');
					return Token.ERROR;

				case	'\\':
				case	'/':
				case	'b':
				case	'f':
				case	'n':
				case	'r':
				case	't':
				case	'"':
					addCharacter('\\');			
					addCharacter(c);
					break;

				case	'u':
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
					if (value > 0xffff) {
						if (t != Token.ERROR)
							_value.insert(0, '"');
						t = Token.ERROR;
					}
					break;

				default:
					addCharacter('\\');			
					addCharacter(c);
					if (t != Token.ERROR)
						_value.insert(0, '"');
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
	/*
	 * Only valid if the last returned token was STRING
	 */
	public string stringValue() {
		return _value.unescapeJSON();
	}
	/*
	 * Only valid if the last returned token was NUMBER
	 */
	public double numberValue() {
		return double.parse(_value);
	}
	
	public Location location() { 
		return _location; 
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

	public int getByte() {
		if (_cursor < _source.length())
			return _source[_cursor++];
		else
			return -1;
	}

	private void clearValue() {
		_value = null;
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
                      	"false": 		Token.FALSE,
                      	"null": 		Token.NULL,
                      	"true": 		Token.TRUE,
                      ];
