#pragma once
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "vector.h"
#define null 0

class string {
public:
	string() : _contents(0) {
	}

	string(const char* value) : _contents(0) {
		size_t len = strlen(value);
		if (len) {
			resize((int)len);
			memcpy(_contents->data, value, len + 1);
		}
	}

	string(const string& value) : _contents(0) {
		if (value.size()) {
			resize(value.size());
			memcpy(_contents->data, value._contents->data, value._contents->length + 1);
		}
	}

	string(int v) : _contents(0) {
		char buffer[32];
		sprintf(buffer, "%d", v);
		size_t len = strlen(buffer);
		resize((int)len);
		memcpy(_contents->data, buffer, len + 1);
	}

	string(unsigned long v) : _contents(0) {
		char buffer[32];
		sprintf(buffer, "%lu", v);
		size_t len = strlen(buffer);
		resize((int)len);
		memcpy(_contents->data, buffer, len + 1);
	}

	string(double x) : _contents(0) {
		char buffer[32];
		sprintf(buffer, "%g", x);
		size_t len = strlen(buffer);
		resize((int)len);
		memcpy(_contents->data, buffer, len + 1);
	}

	string(const char* value, int len) : _contents(0) {
		if (len) {
			resize(len);
			memcpy(_contents->data, value, len);
			_contents->data[len] = 0;
		}
	}

	string(const vector<char> &value) : _contents(0) {
		if (value.size()) {
			resize(value.size());
			memcpy(_contents->data, &value[0], value.size());
			_contents->data[value.size()] = 0;
		}
	}

	~string() {
		clear();
	}

	int size() const {
		if (_contents)
			return _contents->length;
		else
			return 0;
	}

	void clear() {
		if (_contents)
			free(_contents);
		_contents = 0;
	}

	void resize(int length);

	const char* c_str() const {
		if (_contents)
			return _contents->data;
		else
			return "";
	}

	string& append(const string& s) {
		size_t length = s.size();
		if (length) {
			int old_size = size();
			resize(old_size + (int)length);
			memcpy(&_contents->data[old_size], s.c_str(), length + 1);
		}
		return *this;
	}

	string& append(const char* s) {
		size_t len = strlen(s);
		int old_size = size();
		resize(old_size + (int)len);
		memcpy(&_contents->data[old_size], s, len + 1);
		return *this;
	}

	string& append(const char* s, int length) {
		int old_size = size();
		resize(old_size + length);
		memcpy(&_contents->data[old_size], s, length);
		_contents->data[old_size + length] = 0;
		return *this;
	}
	/*
	 *	split
	 *
	 *	Splits a string into one or more sub-strings and
	 *	stores them in the output vector.  Previous contents
	 *	of the vector are deleted.  If no instance of the
	 *	delimiter character are present, then the vector is
	 *	filled with a single element that is the entire
	 *	string.  The output vector always has as many elements
	 *	as the number of delimiters in the input string plus one.
	 *	The delimiter characters are not included in the output.
	 */
	void split(char delimiter, vector<string>* output) const;

	int printf(const char* format, ...);

	int localTime(time_t t, const char* format);

	int universalTime(time_t t, const char* format);
	/*
	 *	escapeC
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed C
	 *	string literal token with the same string value as 
	 *	this object.
	 */
	string escapeC();
	/*
	 *	unescapeC
	 *
	 *	Process the input string as if it were a C string literal.
	 *	Escape sequences are:
	 *
	 *		\a		audible bell
	 *		\b		backspace
	 *		\f		form-feed
	 *		\n		newline
	 *		\r		carriage return
	 *		\t		tab
	 *		\v		vertical tab
	 *		\xHHH	hex escape
	 *		\0DDD	octal escape
	 *		\\		\
	 *
	 */
	bool unescapeC(string* output);

	string trim() const;

	int toInt() const;

	double toDouble() const;

	bool toBool() const;

	void push_back(char c) {
		resize(size() + 1);
		_contents->data[_contents->length - 1] = c;
		_contents->data[_contents->length] = 0;
	}

	int find(char c, int offset = 0) const {
		for (int i = offset; i < size(); i++) {
			if (_contents->data[i] == c)
				return i;
		}
		return npos;
	}

	int rfind(char c, int offset = npos) const {
		if (offset == npos)
			offset = size();
		for (int i = offset - 1; i >= 0; i--) {
			if (_contents->data[i] == c)
				return i;
		}
		return npos;
	}

	string tolower() const;

	string substr(int offset = 0, int count = npos) const {
		if (offset > size())
			offset = size();
		if (count == npos)
			count = size() - offset;
		else if (count > size())
			count = size() - offset;
		string result;
		if (count) {
			result.resize(count);
			memcpy(result._contents->data, _contents->data + offset, count);
			result._contents->data[count] = 0;
		}
		return result;
	}

	char* buffer_(int len) {
		resize(len);
		return _contents->data;
	}

	char& operator [](int i) {
		if (_contents)
			return _contents->data[i];
		else
			return dummy;
	}

	const char& operator [] (int i) const {
		if (_contents)
			return _contents->data[i];
		else
			return dummy;
	}

	string operator + (const string& s2) const {
		string result;

		result.resize(size() + s2.size());
		if (size())
			memcpy(result._contents->data, _contents->data, _contents->length);
		if (s2.size())
			memcpy(result._contents->data + size(), s2._contents->data, s2._contents->length + 1);
		return result;
	}

	string operator += (const string& s2) {
		resize(size() + s2.size());
		if (s2.size())
			memcpy(_contents->data + _contents->length, s2._contents->data, s2._contents->length + 1);
		return *this;
	}

	bool operator == (const string& s2) const {
		if (size() != s2.size())
			return false;
		return memcmp(c_str(), s2.c_str(), size()) == 0;
	}

	bool operator != (const string& s2) const {
		if (size() != s2.size())
			return true;
		return memcmp(c_str(), s2.c_str(), size()) != 0;
	}

	bool operator < (const string& s2) const {
		int n;

		int s1size = size();
		int s2size = s2.size();
		if (s1size < s2size)
			n = s1size;
		else
			n = s2size;
		int r = memcmp(c_str(), s2.c_str(), n);
		if (r < 0)
			return true;
		else if (r > 0)
			return false;
		return s1size < s2size;
	}

	string& operator= (const string& s) {
		if (this != &s) {
			clear();
			if (s.size()) {
				resize(s.size());
				memcpy(_contents->data, s._contents->data, s._contents->length + 1);
			}
		}
		return *this;
	}

	int compare(const string* other) const {
		int n;

		int s1size = size();
		int s2size = other->size();
		if (s1size < s2size)
			n = s1size;
		else
			n = s2size;
		int r = memcmp(c_str(), other->c_str(), n);
		if (r != 0)
			return r;
		else
			return s1size - s2size;
	}

	bool beginsWith(const string& prefix) const;

	bool endsWith(const string& suffix) const;

	unsigned asHex() const;

	int hashValue() const;

	static const int npos = -1;

private:
	static char dummy;
	static const int MIN_SIZE = 0x10;

	struct allocation {
		int length;
		char data[1];
	};

	int reserved_size(int length) {
		int used_size = length + sizeof (int) + 1;
		int alloc_size = MIN_SIZE;
		while (alloc_size < used_size)
			alloc_size <<= 1;
		return alloc_size;
	}

	allocation* _contents;
};

string operator+ (const char* left, const string& right);

int compare(const string& ref, const char* text, int length);
