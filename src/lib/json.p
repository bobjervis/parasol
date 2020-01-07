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
 * JSON is a structured data format derived from Javascript and capable of contianing a variety of data
 * types and structures.
 *
 * Parasol supports conversion between strings containing JSON data and Parasol objects that correspond to various
 * JSON features.
 *
 * Conversely, an appropriately constructed set of Parasol objects can be converted readily to JSON. There are
 * restrictions on the kinds of Parasol objects that can be converted to JSON, as well as some restrictions on
 * the contents of Array and Object instances.
 */
namespace parasol:json;

import parasol:compiler.codePointClass;
import parasol:compiler.CPC_LETTER;

import parasol:text.memDump;
import parasol:text.string16;
import parasol:compiler.Type;
import parasol:compiler.ClassType;

import parasol:log;

//class Array = var[];

private ref<log.Logger> logger = log.getLogger("parasol.json");
/**
 * Parse a JSON string into Parasol objects.
 */
public var, boolean parse(string text) {
	Parser parser(text);
	var x;
	boolean success;
	
	(x, success) = parser.parse();
	return x, success;
}
/**
 * Convert an Object containing JSON -compatible data to a JSON formatted string. White space is inserted
 * into the text to produce a readable sring with white space indentation for each object and array and
 * newlines separating fields.
 *
 * @param object The JSON object to be converted.
 *
 * @return The JSON text.
 */
public string prettyPrint(var object) {
	return prettyPrint(object, 0);
}
/**
 * Convert an Object containing JSON -compatible data to a JSON formatted string. No white space is inserted
 * into the text to minimize the size of the text payload.
 *
 * @param object The JSON object to be converted.
 *
 * @return The JSON text.
 */
public string stringify(var object) {
	return prettyPrint(object, -1);
}

private string prettyPrint(var object, int indent) {
	assert(object != undefined);
	if (object.class == long) {
		string s;
		
		s.printf("%d", object);
		return s;
	} else if (object.class == double) {
		string s;
		
		s.printf("%g", object);
		return s;
	} else if (object.class == string) {
		string s;
		
		s.printf("\"%s\"", string(object).escapeJSON());
		return s;
	} else if (object.class == string16) {
		string s;
		
		s.printf("\"%s\"", string16(object).escapeJSON());
		return s;
	} else if (object.class == boolean)
		return boolean(object) ? "true" : "false";
	else if (object.class <= address && address(object) == null)
		return "null";
	else if (object.class == ref<Object>) {
		string s;
		int nextIndent = -1;

		s = "{";
		if (indent >= 0) {
			nextIndent = indent + 4;
			s += pad(indent);
		}
		boolean serializedMember;
		ref<Object> obj = ref<Object>(object);
		for (i in *obj) {
			if (serializedMember) {
				s.append(',');
				if (indent >= 0)
					s += pad(nextIndent);
			} else if (indent >= 0)
				s += "    ";
			s.printf("\"%s\":", i.escapeJSON());
			s.append(prettyPrint((*obj)[i], nextIndent));
			serializedMember = true;
		}
		if (serializedMember)
			s += pad(indent);
		s.append("}");
		return s;
	} else if (object.class == ref<Array>) {
		string s;
		ref<Array> array = ref<Array>(object);
		int nextIndent = -1;
		
		s = "[";
		if (indent >= 0) {
			nextIndent = indent + 4;
			s += pad(indent);
		}
		boolean serializedMember;
		for (int i = 0; i < array.length(); i++) {
			if (i > 0) {
				s.append(',');
				if (indent >= 0)
					s += pad(nextIndent);
			} else if (indent >= 0)
				s += "    ";
			s.append(prettyPrint(array.get(i), nextIndent));
			serializedMember = true;
		}
		if (serializedMember)
			s += pad(indent);
		s.append("]");
		return s;
	} else 
		return "\"object (unknown schema)\"";
}

private string pad(int n) {
	string s = "\n";
	for (int i = 0; i < n; i++)
		s += " ";
	return s;
}
/**
 * If object was returned from json.parse, this will delete all memory
 * allocated by the parse. If you care about any of the Object or Array instances
 * that were returned, you will need to prune the object or copy the interesting
 * items before you dispose of them.
 */
public void dispose(var object) {
	if (object.class == ref<Object>) {
		ref<Object> o = ref<Object>(object);
		if (o == null)
			return;
		for (i in *o) {
			var x = (*o)[i];
			dispose(x);
		}
		delete o;
	} else if (object.class == ref<Array>) {
		ref<Array> a = ref<Array>(object);
		if (a == null)
			return;
		for (int i = 0; i < a.length(); i++) {
			dispose(a.get(i));
		}
		delete a;
	}
}
/**
 * Clone JSON data.
 *
 * While most commonly applied to the data returned from a successful parse, or a sub-element of such
 * data, the following data can be successfully used:
 *
 *<ul>
 *  <li> A number. Any integer or floating-point numeric value. Stirctly speaking, The JSON parse method
 *       will not produce integer variants. Nevertheless, functions like {@link stringify} or {@link prettyPrint}
 *       will format the output correctly.
 *  <li> A string. Any string.
 *  <li> A boolean. Any boolean value.
 *  <li> Null. The value null.
 *  <li> A reference to a {@link parasol:types.Array Array} object. As long as every element in the Array is also
 *       valid JSON data and the Array does not recursively contain a reference to itself, then the Array object
 *       is valid. 
 *  <li> A reference to a {@link Parasol:type.Object Object} object. As long as every member of the Object is also
 *       valid JSON data and the Object does not recursively contain a reference to itself, then the Object
 *       object is valid.
 *</ul>
 *
 * JSON data can contain multiple references to Array or Object instances, as long as none contain themselves
 * recursively. A call to {@link clone} will create multiple copies, so that each Array or Object instance occurs
 * only once in a returned set of JSON data. Calls to {@link stringify} or {@link prettyPrint} will similarly
 * display multiple copies of the data, as if they were distinct objects.
 *
 * @param object The object containing json data.
 *
 * @return A copy of the json data. All objects and arrays will be replicated recursively to reproduce
 * the entire structure.
 */
public var clone(var object) {
	if (object.class == ref<Object>) {
		ref<Object> o = ref<Object>(object);
		if (o == null)
			return o;
		ref<Object> n = new Object();
		for (i in *o) {
			var x = (*o)[i];
			(*n)[i] = clone(x);
		}
		return n;
	} else if (object.class == ref<Array>) {
		ref<Array> a = ref<Array>(object);
		if (a == null)
			return a;
		ref<Array> n = new Array();
		for (i in *a)
			n.push(clone((*a)[i]));
		return n;
	} else
		return object;
}

class Parser {
	Scanner _scanner;
	boolean _error;
	
	Parser(string text) {
		_scanner.setSource(text);
	}
	
	var, boolean parse() {
		var x = parseValue();
		if (!_error) {
			Token t = _scanner.next();
			if (t != Token.END_OF_STREAM)
				_error = true;
		}
		return x, !_error;
	}
	
	var parseValue() {
		Token t = _scanner.next();
		var v;
		switch (t) {
		case	LEFT_CURLY:
			ref<Object> object = new Object();
			t = _scanner.next();
			if (t == Token.RIGHT_CURLY)
				return object;
			_scanner.pushBack(t);
			for (;;) {
				t = _scanner.next();
				if (t != Token.STRING) {
					_error = true;
					return object;
				}
				string key = _scanner.stringValue();
				t = _scanner.next();
				if (t != Token.COLON) {
					_error = true;
					return object;
				}
				var x = parseValue();
				if (_error)
					return object;
				object.set(key, x);
				t = _scanner.next();
				if (t == Token.RIGHT_CURLY)
					return object;
				else if (t != Token.COMMA) {
					_error = true;
					return object;
				}
			}

		case	LEFT_SQUARE:
			ref<Array> array = new Array();
			t = _scanner.next();
			if (t == Token.RIGHT_SQUARE)
				return array;
			_scanner.pushBack(t);
			for (;;) {
				var x = parseValue();
				if (_error)
					return x;
				array.push(x);
				t = _scanner.next();
				if (t == Token.RIGHT_SQUARE)
					return array;
				else if (t != Token.COMMA) {
					_error = true;
					return array;
				}
			}
		
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
			_location = _cursor;
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
			if (byte(x).isDigit())
				t = Token.ERROR;
		}
		addCharacter(c);
		// We know we have a prefix already stored, either a digit or minus and a digit.
		for (;;) {
			c = getc();
			if (!byte(c).isDigit())
				break;
			addCharacter(c);
		}
		if (c == '.') {
			addCharacter(c);
			boolean anyDigits;
			for (;;) {
				c = getc();
				if (!byte(c).isDigit())
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
				if (!byte(c).isDigit())
					break;
				addCharacter(c);
				anyDigits = true;
				c = getc();
			}
			if (!anyDigits)
				t = Token.ERROR;
		}
		ungetc();
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
								value = (value << 4) + 10 + unsigned(byte(c).toLowerCase() - 'a');
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
	
	public int location() { 
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

	int getMoreBytes(int valueSoFar, int extraBytes) {
		for (int i = 0; i < extraBytes; i++) {
			int x = getByte();
			if ((x & ~0x3f) != 0x80) {
				_lastByte = x;
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
