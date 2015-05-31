#include "../common/platform.h"
#include "string.h"

#include <ctype.h>
#include <stdarg.h>
#include <time.h>
#include "xml.h"

string operator+ (const char* left, const string& right) {
	string s(left);

	return s + right;
}

bool string::beginsWith(const string& prefix) const {
	if (prefix.size() > size())
		return false;
	if (prefix.size() == 0)
		return true;
	return memcmp(prefix._contents->data, _contents->data, prefix._contents->length) == 0;
}

bool string::endsWith(const string& suffix) const {
	if (suffix.size() >= size())
		return false;
	if (suffix.size() == 0)
		return false;
	return strcmp(suffix._contents->data, &_contents->data[_contents->length - suffix._contents->length]) == 0;
}

unsigned string::asHex() const {
	int i = 0;
	int length = size();
	if (length > 2){
		if (_contents->data[0] == '0' && (_contents->data[1] == 'x' || _contents->data[1] == 'X'))
			i += 2;
	}
	int v = 0;
	while (i < length){
		char c = _contents->data[i];
		if (c >= '0' && c <= '9')
			v = v * 16 + (unsigned(c) - unsigned('0'));
		else if (c >= 'a' && c <= 'f')
			v = v * 16 + 10 + (unsigned(c) - unsigned('a'));
		else if (c >= 'A' && c <= 'F')
			v = v * 16 + 10 + (unsigned(c) - unsigned('A'));
		else
			return v;
		i++;
	}
	return v;
}

void string::resize(int length) {
	int new_size;
	if (_contents) {
		if (_contents->length >= length) {
			if (length == 0)
				clear();
			else
				_contents->length = length;
			return;
		}
		int old_size = reserved_size(_contents->length);
		new_size = reserved_size(length);
		if (old_size == new_size) {
			_contents->length = length;
			return;
		}
	} else {
		if (length == 0)
			return;
		new_size = reserved_size(length);
	}
	allocation* a = (allocation*)malloc(new_size);
	if (_contents) {
		memcpy(a->data, _contents->data, _contents->length + 1);
		free(_contents);
	}
	a->length = length;
	a->data[length] = 0;
	_contents = a;
}

string string::tolower() const {
	if (_contents) {
		string result;

		char* out = result.buffer_(_contents->length);
		for (int i = 0; i < _contents->length; i++)
			out[i] = ::tolower(_contents->data[i]);
		return result;
	} else
		return string();
}

void string::split(char delimiter, vector<string>* output) const {
	output->resize(0);
	if (_contents) {
		int tokenStart = 0;
		for (int i = 0; i < _contents->length; i++) {
			if (_contents->data[i] == delimiter) {
				output->push_back(string(_contents->data + tokenStart, i - tokenStart));
				tokenStart = i + 1;
			}
		}
		if (tokenStart > 0)
			output->push_back(string(_contents->data + tokenStart, _contents->length - tokenStart));
		else
			output->push_back(*this);
	} else
		output->resize(1);
}

int skipFormat(const char* format, int i) {
	for (;; i++) {
		switch (format[i]) {
		case	0:
		case	'%':
		case	'c':
		case	'd':
		case	'e':
		case	'f':
		case	'g':
		case	'o':
		case	'p':
		case	's':
		case	'u':
		case	'x':
			return i;
		}
	}
}

int string::printf(const char* format, ...) {
	va_list ap;
	va_start(ap, format);
	int originalSize = size();
	char buffer[128];
	for (int i = 0; format[i]; i++) {
		if (format[i] == '%') {
			string a;
			const char* fmt = &format[i];
			i = skipFormat(format, i + 1);
			switch (format[i]) {
			case 0:
				va_end(ap);
				return size() - originalSize;
			case	'c':
			case	'd':
			case	'o':
			case	'p':
			case	'u':
			case	'x':
				a = string(fmt, 1 + &format[i] - fmt);
				vsprintf(buffer, a.c_str(), ap);
				va_arg(ap, int);
				append(buffer);
				break;

			case	'e':
			case	'f':
			case	'g':
				a = string(fmt, 1 + &format[i] - fmt);
				vsprintf(buffer, a.c_str(), ap);
				va_arg(ap, double);
				append(buffer);
				break;

			default:
				a = string(fmt, 1 + &format[i] - fmt);
				vsprintf(buffer, a.c_str(), ap);
				va_arg(ap, int);
				append(buffer);
				break;
			case 's':
				append(va_arg(ap, char*));
				break;
			case	'%':
				push_back('%');
				break;
			}
		} else
			push_back(format[i]);
	}
	va_end(ap);
	return size() - originalSize;
}

int string::localTime(time_t t, const char* format) {
	char buffer[1024];
	struct tm tm;
	struct tm* tmp;

	tmp = localtime(&t);
	if (tmp == null)
		return -1;
	tm = *tmp;
	int result = strftime(buffer, sizeof buffer, format, &tm);
	if (result > 0)
		append(buffer);
	return result;
}

int string::universalTime(time_t t, const char* format) {
	char buffer[1024];
	struct tm tm;

	tm = *gmtime(&t);
	int result = strftime(buffer, sizeof buffer, format, &tm);
	if (result > 0)
		append(buffer);
	return result;
}

string string::escapeC() {
	string output;

	if (size() == 0)
		return output;
	for (int i = 0; i < _contents->length; i++) {
		switch (_contents->data[i]) {
		case	'\\':	output.printf("\\\\");	break;
		case	'\a':	output.printf("\\a");	break;
		case	'\b':	output.printf("\\b");	break;
		case	'\f':	output.printf("\\f");	break;
		case	'\n':	output.printf("\\n");	break;
		case	'\r':	output.printf("\\r");	break;
		case	'\v':	output.printf("\\v");	break;
		default:
			if (_contents->data[i] >= 0x20 &&
				_contents->data[i] < 0x7f)
				output.push_back(_contents->data[i]);
			else
				output.printf("\\x%x", _contents->data[i] & 0xff);
		}
	}
	return output;
}

static inline bool isoctal(char x) {
	return x >= '0' && x <= '7';
}

bool string::unescapeC(string* output) {
	output->clear();
	if (size() == 0)
		return true;
	for (int i = 0; i < _contents->length; i++) {
		if (_contents->data[i] == '\\') {
			if (i == _contents->length - 1)
				return false;
			else {
				int v;
				i++;
				switch (_contents->data[i]) {
				case 'a':	output->push_back('\a');	break;
				case 'b':	output->push_back('\b');	break;
				case 'f':	output->push_back('\f');	break;
				case 'n':	output->push_back('\n');	break;
				case 'r':	output->push_back('\r');	break;
				case 't':	output->push_back('\t');	break;
				case 'v':	output->push_back('\v');	break;
				case 'x':
				case 'X':
					i++;;
					if (i >= _contents->length)
						return false;
					if (!isxdigit(_contents->data[i]))
						return false;
					v = 0;
					do {
						v <<= 4;
						if (v > 0xff)
							return false;
						if (isdigit(_contents->data[i]))
							v += _contents->data[i] - '0';
						else
							v += 10 + ::tolower(_contents->data[i]) - 'a';
						i++;
					} while (i < _contents->length && isxdigit(_contents->data[i]));
					output->push_back(v);
					break;
				case '0':
					i++;
					if (i >= _contents->length)
						return false;
					if (!isoctal(_contents->data[i]))
						return false;
					v = 0;
					do {
						v <<= 3;
						if (v > 0xff)
							return false;
						v += _contents->data[i] - '0';
						i++;
					} while (i < _contents->length && isoctal(_contents->data[i]));
					output->push_back(v);
					break;
				default:	
					output->push_back(_contents->data[i]);
				}
			}
		} else
			output->push_back(_contents->data[i]);
	}
	return true;
}

string string::trim() const {
	if (size() == 0)
		return string();

	int prefix;
	int suffix;
	for (prefix = 0; prefix < _contents->length; prefix++)
		if (!isspace(_contents->data[prefix]))
			break;
	for (suffix = _contents->length; suffix > prefix; suffix--)
		if (!isspace(_contents->data[suffix - 1]))
			break;
	return substr(prefix, suffix - prefix);
}

int string::toInt() const {
	if (_contents == null)
		// Range exception?
		return 0;
	else
		// Should check for range exception?
		return atoi(_contents->data);
}

double string::toDouble() const {
	if (_contents == null)
		// Range exception?
		return 0;
	else
		// Should check for range exceptions?
		return xml::sax_to_double(_contents->data, _contents->length);
}

bool string::toBool() const {
	if (_contents) {
		switch (_contents->length) {
		case	4:
			if (memcmp(_contents->data, "true", 4) == 0)
				return true;
			break;
		case	5:
			if (memcmp(_contents->data, "false", 5) == 0)
				return false;
			break;
		}
	}
	// Range exception?
	return false;
}

int compare(const string& ref, const char* text, int length) {
	int cmpLength;
	if (ref.size() < length)
		cmpLength = ref.size();
	else
		cmpLength = length;
	int i = memcmp(ref.c_str(), text, length);
	if (i)
		return i;
	if (ref.size() > length)
		return 1;
	else if (ref.size() < length)
		return -1;
	else
		return 0;
}

int string::hashValue() const {
	if (_contents == null)
		return 0;
	int v = _contents->length;
	switch (v) {
	case 0:
		return 0;

	case 1:
		return _contents->data[0];

	case 2:
		return *(unsigned short*)_contents->data;

	case 3:
		return *(unsigned short*)_contents->data + (_contents->data[2] << 2);

	case 4:
		return *(unsigned short*)_contents->data + ((*(unsigned short*)&_contents->data[2]) << 1);

	default:
		for (int i = 0; i < _contents->length; i++)
			v += _contents->data[i] << (i & 7);
	}
	return v;
}
