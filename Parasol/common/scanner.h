#pragma once
#include "script.h"
#include "dictionary.h"
#include "string.h"
#include "vector.h"

namespace display {

class TextBuffer;

};

namespace script {

enum Token {
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
};

class Scanner {
public:
	Scanner(const string& source);

	Scanner(display::TextBuffer* buffer);

	~Scanner();

	Token next();

	int lineNumber(fileOffset_t location) const;

	void backup() { _cursor = _previous; }

	int location() const { return _previous; }

	const char* tokenText() const { return _text + _previous; }

	int	tokenSize() const { return _cursor - _previous; }

	bool atEnd() const { return _cursor >= _length; }

private:
	void init(const char* source, int length);

	const char*		_text;
	int				_length;
	int				_cursor;
	int				_previous;
};


}  // namespace script