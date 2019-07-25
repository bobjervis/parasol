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
 * @ignore
 */
namespace parasol:script;

import parasol:storage;

private string commandPrefix;
private ref<Object>()[string] factories;

public void setCommandPrefix(string command) {
	commandPrefix = command;
}

public void init() {
	objectFactory("script", ScriptObject.factory);
}

public void objectFactory(string tag, ref<Object> factory()) {
	factories[tag] = factory;
}

public class Null extends Atom {
	public string toSource() {
		assert(false);
		return null;
	}

	public string toString() {
		assert(false);
		return null;
	}
}

public class Object extends Atom {
	ref<Atom>[string]	_properties;

	public Object() {
		
	}

//	public boolean isRunnable() {
//		return true;
//	}

	public string toSource() {
		string s;
		ref<Atom>[string].iterator i = _properties.begin();

		boolean firstTime = true;
		ref<Atom> a = get("tag");
		if (a != null)
			s.append(a.toString());
		s.append('(');
		while (i.hasNext()) {
			if (i.key() != "tag" &&
				i.key() != "content" &&
				i.key() != "parent") {
				ref<Atom> a = i.get();
				if (firstTime)
					firstTime = false;
				else
					s.append(',');
				s.append(i.key());
				s.append(':');
				if (a == null)
					s.append("<null>");
				else
					s.append(a.toSource());
			}
			i.next();
		}
		s.append(')');
		a = get("content");
		if (a != null) {
			s.append('{');
			s.append(a.toSource());
			s.append('}');
		}
		return s;
	}

	public string toString() {
		assert(false);
		return null;
	}

	public ref<Atom> get(string name) {
		return _properties.get(name);
	}
	/*
	 * put
	 *
	 * Put method defines the name to have the given value.
	 */
	public boolean put(string name, ref<Atom> value) {
		ref<Atom> a = _properties.replace(name, value);
		if (a != null) {
			delete a;
			return false;
		} else
			return true;
	}
}

public class String extends Atom {
	private string _content;
	
	public String(string s) {
		_content = s;
	}

	public string toSource() {
		string s;
		s.append('"');
		s.append(_content.escapeParasol());
		s.append('"');
		return s;
	}

	public string toString() {
		return _content;
	}
}

public class TextRun extends Atom {
	private string _content;

	public TextRun(pointer<byte> text, long length) {
		_content = string(text, int(length));
	}

	public string toSource() {
		return _content;
	}

	public string toString() {
		return _content;
	}
}

public class Vector extends Atom {
	private ref<Atom>[] _value;
	
	public Vector(ref<Atom>[] value) {
		for (int i = 0; i < value.length(); i++)
			_value.append(value[i]);
	}

	public string toSource() {
		string s;

		for (int i = 0; i < _value.length(); i++)
			s.append(_value[i].toSource());
		return s;
	}

	public string toString() {
		string s;

		for (int i = 0; i < _value.length(); i++)
			s.append(_value[i].toString());
		return s;
	}

	public ref<Atom> get(int i) {
		if (i < 0 || i >= _value.length()) {
			assert(false);
			return null;
		}
		return _value[i];
	}

	public int length() {
		return _value.length();
	}
	
	public ref<ref<Atom>[]> value() {
		return &_value;
	}
}

public class Atom {
	public boolean validate(ref<Parser> parser) {
		return true;
	}

	public boolean isRunnable() {
		return false;
	}

	public boolean run() {
		return false;
	}

	public ref<Atom> get(string name) {
		return null;
	}

	public boolean put(string name, ref<Atom> value) {
		assert(false);
		return false;
	}

	public ref<Atom> get(int i) {
		assert(false);
		return null;
	}

	public int length() {
		assert(false);
		return 0;
	}

	public abstract string toSource();

	public abstract string toString();
}

class ScriptObject extends Object {
	public static ref<Object> factory() {
		return new ScriptObject();
	}

	private ScriptObject() {}
/*

	virtual bool validate(Parser* parser) {
		Atom* a = get("name");
		if (a == null)
			return false;
		_path = fileSystem::pathRelativeTo(a.toString(), parser.filename());
		return true;
	}

	virtual bool run() {
		string command = commandPrefix;
		command.append(' ');
		command.append(_path);
		string captureData;
		process::exception_t exception;
		int exitCode = process::debugSpawn(command, &captureData, &exception, 60);
		string sExitCode(exitCode);
		put("exit", new String(sExitCode));
		put("output", new String(captureData));
		int expectedExitCode = 0;
		Atom* expect = get("expect");
		if (expect != null)
			expectedExitCode = expect.toString().toInt();
		return exitCode == expectedExitCode;
	}

private:
	string				_path;
	*/
}

public class Parser {
	private ref<ref<Atom>[]> _atoms;
	private Scanner _scanner;
	private string _filename;
	private boolean _errorsFound;

	private Parser(string source) {
		_scanner = Scanner(source);
	}

	public ref<MessageLog> log;
/*
public:

	Parser(display::TextBuffer* buffer);

	~Parser();
*/
	public static ref<Parser> load(string filename) {
		ref<Reader> f = storage.openTextFile(filename);
		if (f == null)
			return null;
		string s;
		boolean result;
		(s, result) = f.readAll();
		delete f;
		if (!result)
			return null;
		ref<Parser> p = new Parser(s);
		p._filename = storage.absolutePath(filename);
		return p;
	}

	public static ref<Parser> loadFromString(string filename, string content) {
		ref<Parser> p = new Parser(content);
		p._filename = filename;
		return p;
	}

	public void content(ref<ref<Atom>[]> output) {
		_atoms = output;
	}

	public boolean parse() {
		if (log == null)
			log = new ScannerMessageLog();
		log.declareScanner(_filename, &_scanner);
		_errorsFound = false;
		parseGroup(null, Token.END_OF_INPUT);
		return !_errorsFound;
	}

	public string filename() { 
		return _filename; 
	}

	private void parseGroup(ref<Object> parent, Token terminator) {
		pointer<byte> run = null;
		pointer<byte> endOfRun;
		for (;;) {
			Token t = _scanner.next();
			switch (t) {
			case END_OF_INPUT:
				if (terminator != Token.END_OF_INPUT) {
					_errorsFound = true;
//					printf("terminator == %s\n", string(terminator));
					log.error(_scanner.location(), "Unexpected end of file");
				}
				if (run != null)
					_atoms.append(new TextRun(run, endOfRun - run));
				return;

			case IDENTIFIER:
				{
					pointer<byte> start = _scanner.tokenText();
					int length = _scanner.tokenSize();

					t = _scanner.next();
					if (t == Token.LEFT_PARENTHESIS) {
						// We have an object constructor, so flush any prior run
						if (run != null) {
							_atoms.append(new TextRun(run, endOfRun - run));
							run = null;
						}
						parseObject(parent, start, length);
					} else {
						_scanner.backup();
						if (run == null)
							run = start;
						endOfRun = start + length;
					}
				}
				break;

			case STRING_LITERAL:
				if (run != null) {
					_atoms.append(new TextRun(run, endOfRun - run));
					run = null;
				}
				_atoms.append(stringToken());
				break;

			case	RIGHT_PARENTHESIS:
				if (terminator == Token.RIGHT_PARENTHESIS ||
					terminator == Token.COMMA) {
					_scanner.backup();
					if (run != null)
						_atoms.append(new TextRun(run, endOfRun - run));
					return;
				}
				log.error(_scanner.location(), "Unexpected right parenthesis");
				_errorsFound = true;
				break;

			case	RIGHT_CURLY:
				if (t != terminator) {
					log.error(_scanner.location(), "Unexpected right curly brace");
					_errorsFound = true;
					_scanner.backup();
				}
				if (run != null)
					_atoms.append(new TextRun(run, endOfRun - run));
				return;

			case	COMMA:
				if (terminator == Token.COMMA) {
					_scanner.backup();
					if (run != null)
						_atoms.append(new TextRun(run, endOfRun - run));
					return;
				}

			default:
				if (run == null)
					run = _scanner.tokenText();
				endOfRun = _scanner.tokenText() + _scanner.tokenSize();
			}
		}
	}

	void parseObject(ref<Object> parent, pointer<byte> tagStart, int tagLength) {
		ref<Object> object;
		string tag(tagStart, tagLength);
		ref<Object>() factory = factories[tag];
		if (factory == null)
			object = new Object();
		else
			object = factory();
		object.put("tag", new String(tag));
		if (parent != null)
			object.put("parent", parent);
		int location = _scanner.location();
		for (;;) {
			Token t = _scanner.next();
			if (t == Token.RIGHT_PARENTHESIS)
				break;
			if (t == Token.RIGHT_CURLY) {
				log.error(_scanner.location(), "Unexpected right curly brace");
				_errorsFound = true;
				_scanner.backup();
				return;
			}
			if (t != Token.IDENTIFIER) {
				if (!resync(Token.RIGHT_PARENTHESIS))
					return;
				continue;
			}
			string attribute = string(_scanner.tokenText(), _scanner.tokenSize());
			if (_scanner.next() == Token.COLON) {
				ref<Atom>[] value;
				ref<ref<Atom>[]> outer = _atoms;
				_atoms = &value;
				parseGroup(null, Token.COMMA);
				_atoms = outer;
				if (value.length() == 0)
					object.put(attribute, new Null());
				else if (value.length() == 1)
					object.put(attribute, value[0]);
				else
					object.put(attribute, new Vector(value));
			} else if (!resync(Token.COMMA))
					return;
			t = _scanner.next();
			if (t == Token.RIGHT_PARENTHESIS)
				break;
			if (t != Token.COMMA) {
				if (!resync(Token.COMMA))
					return;
				t = _scanner.next();
				if (t != Token.COMMA)
					_scanner.backup();
				continue;
			}
		}
		Token t = _scanner.next();
		if (t == Token.LEFT_CURLY) {
			ref<ref<Atom>[]> save = _atoms;
			_atoms = new ref<Atom>[];
			parseGroup(object, Token.RIGHT_CURLY);
			object.put("content", new Vector(*_atoms));
			delete _atoms;
			_atoms = save;
		} else
			_scanner.backup();
		if (object.validate(this))
			_atoms.append(object);
		else {
			log.error(location, "Object is not valid");
			_errorsFound = true;
		}
	}

	public boolean resync(Token t) {
		// Just do no resync for now.
		return false;
	}

	public ref<String> stringToken() {
		string s(_scanner.tokenText() + 1, _scanner.tokenSize() - 2);
		string content;
		boolean result;
		(content, result) = s.unescapeParasol();
		return new String(content);
	}
	
}

private enum Token {
	END_OF_INPUT,
	TOKEN_ERROR,
	INTEGER,
	IDENTIFIER,
	FLOAT_LITERAL,
	STRING_LITERAL,
	CHAR_LITERAL,
	LEFT_PARENTHESIS,
	RIGHT_PARENTHESIS,
	LEFT_CURLY,
	RIGHT_CURLY,
	COLON,
	COMMA,
	DOT,
	OTHER
}

private class Scanner {
	private string _text;
	private int _cursor;
	private int _previous;

	public Scanner() {	
	}
	
	public Scanner(string source) {
		_text = source;
	}
/*
public:

	Scanner(display::TextBuffer* buffer);

	~Scanner();
*/
	Token next() {
		for (;;) {
			_previous = _cursor;
			if (_cursor >= _text.length())
				return Token.END_OF_INPUT;
			switch (_text[_cursor]) {
			case	'a':
			case	'b':
			case	'c':
			case	'd':
			case	'e':
			case	'f':
			case	'g':
			case	'h':
			case	'i':
			case	'j':
			case	'k':
			case	'l':
			case	'm':
			case	'n':
			case	'o':
			case	'p':
			case	'q':
			case	'r':
			case	's':
			case	't':
			case	'u':
			case	'v':
			case	'w':
			case	'x':
			case	'y':
			case	'z':
			case	'A':
			case	'B':
			case	'C':
			case	'D':
			case	'E':
			case	'F':
			case	'G':
			case	'H':
			case	'I':
			case	'J':
			case	'K':
			case	'L':
			case	'M':
			case	'N':
			case	'O':
			case	'P':
			case	'Q':
			case	'R':
			case	'S':
			case	'T':
			case	'U':
			case	'V':
			case	'W':
			case	'X':
			case	'Y':
			case	'Z':
			case	'_':
				do {
					_cursor++;
					if (_cursor >= _text.length())
						return Token.IDENTIFIER;
				} while (_text[_cursor].isAlphanumeric() || _text[_cursor] == '_');
				return Token.IDENTIFIER;

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
				_cursor++;
				if (_cursor >= _text.length())
					return Token.INTEGER;
				if (_text[_cursor] == 'x' ||
					_text[_cursor] == 'X') {
					do {
						_cursor++;
						if (_cursor >= _text.length())
							return Token.INTEGER;
					} while (_text[_cursor].isHexDigit());
					return Token.INTEGER;
				}
				while (_text[_cursor].isDigit()) {
					_cursor++;
					if (_cursor >= _text.length())
						return Token.INTEGER;
				}
				if (_text[_cursor] != '.')
					return Token.INTEGER;
				do {
					_cursor++;
					if (_cursor >= _text.length())
						return Token.FLOAT_LITERAL;
				} while (_text[_cursor].isDigit());
				if (_text[_cursor] == 'e' || _text[_cursor] == 'E') {
					do {
						_cursor++;
						if (_cursor >= _text.length())
							return Token.FLOAT_LITERAL;
					} while (_text[_cursor].isDigit());
				}
				return Token.FLOAT_LITERAL;

			case	'.':
				_cursor++;
				if (_cursor >= _text.length())
					return Token.DOT;
				if (!_text[_cursor].isDigit())
					return Token.DOT;
				do {
					_cursor++;
					if (_cursor >= _text.length())
						return Token.FLOAT_LITERAL;
				} while (_text[_cursor].isDigit());
				if (_text[_cursor] == 'e' || _text[_cursor] == 'E') {
					do {
						_cursor++;
						if (_cursor >= _text.length())
							return Token.FLOAT_LITERAL;
					} while (_text[_cursor].isDigit());
				}
				return Token.FLOAT_LITERAL;

			case	'(':
				_cursor++;
				return Token.LEFT_PARENTHESIS;

			case	')':
				_cursor++;
				return Token.RIGHT_PARENTHESIS;

			case	'{':
				_cursor++;
				return Token.LEFT_CURLY;

			case	'}':
				_cursor++;
				return Token.RIGHT_CURLY;

			case	':':
				_cursor++;
				return Token.COLON;

			case	',':
				_cursor++;
				return Token.COMMA;

			case '/':
				_cursor++;
				if (_cursor >= _text.length())
					return Token.OTHER;
				if (_text[_cursor] == '/') {
					do
						_cursor++;
					while (_cursor < _text.length() && _text[_cursor] != '\n');
					if (_cursor < _text.length())
						_cursor++;
					break;
				} else if (_text[_cursor] == '*') {
					for (;;) {
						_cursor++;
						if (_cursor >= _text.length() - 1)
							return Token.TOKEN_ERROR;
						if (_text[_cursor] == '*' &&
							_text[_cursor + 1] == '/') {
							_cursor += 2;
							break;
						}
					}
				} else
					return Token.OTHER;

			case	' ':
			case	'\t':
			case	'\r':
			case	'\n':
				_cursor++;
				break;

			case	'\'':
			case	'"': {
				byte delim = _text[_cursor];
				for(;;) {
					_cursor++;
					if (_cursor >= _text.length())
						return Token.TOKEN_ERROR;
					switch (_text[_cursor]) {
					case	'\\':
						_cursor++;
						if (_cursor >= _text.length())
							return Token.TOKEN_ERROR;
						break;

					case	'\'':
					case	'"':
						if (_text[_cursor] == delim) {
							_cursor++;
							return Token.STRING_LITERAL;
						}
					}
				}
				}

			default:
				_cursor++;
				return Token.OTHER;
			}
		}
	}

	int lineNumber(int location) {
		int line = 1;
		for (int i = 0; i < location && i < _text.length(); i++)
			if (_text[i] == '\n')
				line++;
		return line;
	}

	void backup() {
		_cursor = _previous;
	}

	int location() {
		return _previous; 
	}

	pointer<byte> tokenText() {
		return &_text[0] + _previous; 
	}

	int	tokenSize() {
		return _cursor - _previous; 
	}
}

class ScannerMessageLog extends MessageLog {

	public ScannerMessageLog() {
	}

	public void error(int offset, string msg) {
		printf("%s %d : %s\n", filename(), lineNumber(offset), msg);
	}
}

public class MessageLog {
	private int _baseLocation;
	private ref<Scanner> _scanner;
	private string _filename;

	void declareScanner(string filename, ref<Scanner> scanner) {
		_filename = filename;
		_scanner = scanner;
	}

	public string filename() {
		return _filename;
	}

	public int lineNumber(int offset) {
		return _scanner.lineNumber(offset);
	}

	public void print() {
	}
/*
public:
	string	filename;
	ref<OffsetConverter> converter;
	int errorCount;

	MessageLog() : _baseLocation(0) {}

	virtual ~MessageLog();

	fileOffset_t location() const { return _baseLocation; }
	void set_location(fileOffset_t loc) { _baseLocation = loc; }

	void log(const string& msg) { log(_baseLocation, msg); }

	virtual void log(fileOffset_t loc, const string& msg);

	void log(int offset, const string& msg) { log(_baseLocation + offset, msg); }
*/
	void error(string msg) { 
		error(_baseLocation, msg); 
	}

	public abstract void error(int loc, string msg);
/*
	void error(int offset, const string& msg) { error(_baseLocation + offset, msg); }

private:
*/
}

