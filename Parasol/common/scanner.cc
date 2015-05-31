#include "../common/platform.h"
#include "scanner.h"

#include <ctype.h>

namespace script {

Scanner::Scanner(const string& source) {
	char* buffer = new char[source.size()];
	memcpy(buffer, source.c_str(), source.size());
	init(buffer, source.size());
}

Scanner::~Scanner() {
	delete _text;
}

Token Scanner::next() {
	for (;;) {
		if (_cursor >= _length)
			return END_OF_INPUT;
		_previous = _cursor;
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
				if (_cursor >= _length)
					return IDENTIFIER;
			} while (isalnum(_text[_cursor]) || _text[_cursor] == '_');
			return IDENTIFIER;

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
			if (_cursor >= _length)
				return INTEGER;
			if (_text[_cursor] == 'x' ||
				_text[_cursor] == 'X') {
				do {
					_cursor++;
					if (_cursor >= _length)
						return INTEGER;
				} while (isxdigit(_text[_cursor]));
				return INTEGER;
			}
			while (isdigit(_text[_cursor])) {
				_cursor++;
				if (_cursor >= _length)
					return INTEGER;
			}
			if (_text[_cursor] != '.')
				return INTEGER;
			do {
				_cursor++;
				if (_cursor >= _length)
					return FLOAT_LITERAL;
			} while (isdigit(_text[_cursor]));
			if (_text[_cursor] == 'e' || _text[_cursor] == 'E') {
				do {
					_cursor++;
					if (_cursor >= _length)
						return FLOAT_LITERAL;
				} while (isdigit(_text[_cursor]));
			}
			return FLOAT_LITERAL;

		case	'.':
			_cursor++;
			if (_cursor >= _length)
				return DOT;
			if (!isdigit(_text[_cursor]))
				return DOT;
			do {
				_cursor++;
				if (_cursor >= _length)
					return FLOAT_LITERAL;
			} while (isdigit(_text[_cursor]));
			if (_text[_cursor] == 'e' || _text[_cursor] == 'E') {
				do {
					_cursor++;
					if (_cursor >= _length)
						return FLOAT_LITERAL;
				} while (isdigit(_text[_cursor]));
			}
			return FLOAT_LITERAL;

		case	'(':
			_cursor++;
			return LEFT_PARENTHESIS;

		case	')':
			_cursor++;
			return RIGHT_PARENTHESIS;

		case	'{':
			_cursor++;
			return LEFT_CURLY;

		case	'}':
			_cursor++;
			return RIGHT_CURLY;

		case	':':
			_cursor++;
			return COLON;

		case	',':
			_cursor++;
			return COMMA;

		case '/':
			_cursor++;
			if (_cursor >= _length)
				return OTHER;
			if (_text[_cursor] == '/') {
				do
					_cursor++;
				while (_cursor < _length && _text[_cursor] != '\n');
				if (_cursor < _length)
					_cursor++;
				break;
			} else if (_text[_cursor] == '*') {
				for (;;) {
					_cursor++;
					if (_cursor >= _length - 1)
						return TOKEN_ERROR;
					if (_text[_cursor] == '*' &&
						_text[_cursor + 1] == '/') {
						_cursor += 2;
						break;
					}
				}
			} else
				return OTHER;

		case	' ':
		case	'\t':
		case	'\n':
			_cursor++;
			break;

		case	'\'':
		case	'"': {
			char delim = _text[_cursor];
			for(;;) {
				_cursor++;
				if (_cursor >= _length)
					return TOKEN_ERROR;
				switch (_text[_cursor]) {
				case	'\\':
					_cursor++;
					if (_cursor >= _length)
						return TOKEN_ERROR;
					break;

				case	'\'':
				case	'"':
					if (_text[_cursor] == delim) {
						_cursor++;
						return STRING_LITERAL;
					}
				}
			}
			}

		default:
			_cursor++;
			return OTHER;
		}
	}
}

int Scanner::lineNumber(fileOffset_t location) const {
	int line = 1;
	for (int i = 0; i < location; i++)
		if (_text[i] == '\n')
			line++;
	return line;
}

void Scanner::init(const char* text, int length) {
	_text = text;
	_length = length;
	_cursor = 0;
	_previous = 0;
}

}  // namespace script