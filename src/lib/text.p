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
namespace parasol:text;

import native:C;
import parasol:memory;

public boolean ignoring;
public address[] deletedContents;

int printf(string format, var... arguments) {
	string s;
	
	s.printf(format, arguments);
	return print(s);
}

public class string {
	private class allocation {
		public int length;
		public byte data;
	}
	
	private static int MIN_SIZE = 0x10;

	private ref<allocation> _contents;
	
	public string() {
	}
	
	public string(string source) {
		if (source != null) {
			resize(source.length());
			C.memcpy(&_contents.data, &source._contents.data, source._contents.length + 1);
		}
	}

	public string(string source, int startOffset) {
		if (source != null) {
			resize(source.length() - startOffset);
			C.memcpy(&_contents.data, pointer<byte>(&source._contents.data) + startOffset, _contents.length);
			pointer<byte>(&source._contents.data)[_contents.length] = 0;
		}
	}

	public string(string source, int startOffset, int endOffset) {
		if (source != null) {
			resize(endOffset - startOffset);
			C.memcpy(&_contents.data, pointer<byte>(&source._contents.data) + startOffset, endOffset - startOffset);
			pointer<byte>(&source._contents.data)[_contents.length] = 0;
		}
	}

	public string(text.substring source) {
		if (source._data != null) {
			resize(source._length);
			C.memcpy(&_contents.data, source._data, source._length);
		}
	}

	public string(text.substring source, int startOffset) {
		if (source._data != null) {
			resize(source._length - startOffset);
			C.memcpy(&_contents.data, source._data + startOffset, source._length - startOffset);
		}
	}

	public string(text.substring source, int startOffset, int endOffset) {
		if (source._data != null) {
			resize(endOffset - startOffset);
			C.memcpy(&_contents.data, source._data + startOffset, endOffset - startOffset);
		}
	}

	public string(pointer<byte> cString) {
		if (cString != null) {
			int len = C.strlen(cString);
			resize(len);
			C.memcpy(&_contents.data, cString, len);
		}
	}
	
	public string(byte[] value) {
		resize(value.length());
		C.memcpy(&_contents.data, &value[0], value.length());
	}
	
	public string(pointer<byte> buffer, int len) {
		if (buffer != null) {
			resize(len);
			C.memcpy(&_contents.data, buffer, len);
		}
	}
	
	public string(long value) {
		if (value == 0) {
			append('0');
			return;
		} else if (value == long.MIN_VALUE) {
			append("-9223372036854775808");
			return;
		} else if (value < 0) {
			append('-');
			value = -value;
		}
		appendDigits(value);		
	}
	
	private string(ref<allocation> other) {
		_contents = other;
	}
	
	private void appendDigits(long value) {
		if (value > 9)
			appendDigits(value / 10);
		value %= 10;
		append('0' + int(value));
	}
	
	public string(double value) {
		printf("%g", value);
	}
	
	~string() {
		if (_contents != null) {
//			print("\"");
//			print(*this);
//			print("\"\n");
//			if (!ignoring)
//				deletedContents.append(_contents);
//			else
//				print("Delete\n");
			memory.free(_contents);
		}
	}
	
	public pointer<byte> c_str() {
		return pointer<byte>(&_contents.data);
	}
	
	@Deprecated
	public void assign(string other) {
		if (_contents != null) {
			memory.free(_contents);
			_contents = null;
		}
		if (other != null) {
			resize(other._contents.length);
			C.memcpy(&_contents.data, &other._contents.data, other._contents.length + 1);
		}
	}
	
	public void append(string other) {
//		print("'");
//		print(*this);
//		print("'+'");
//		print(other);
//		print("'");
		int len = other.length();
		if (len > 0) {
//			print("appending\n");
			int oldLength = length();
			resize(oldLength + len);
//			print("resized\n");
			C.memcpy(pointer<byte>(&_contents.data) + oldLength, &other._contents.data, len + 1);
//			print("appended\n");
		}
//		print("=");
//		print(*this);
//		print("\n");
	}
	
	public void append(text.substring other) {
		if (other._length > 0) {
			int oldLength = length();
			resize(oldLength + other._length);
			C.memcpy(pointer<byte>(&_contents.data) + oldLength, other._data, other._length);
		}
	}

	public void append(byte b) {
		if (_contents == null) {
			resize(1);
			_contents.data = b;
		} else {
			int len = _contents.length;
			resize(len + 1);
			*(pointer<byte>(&_contents.data) + len) = b;
		}
	}
	
	public void append(pointer<byte> p, int length) {
		if (_contents == null) {
			resize(length);
			C.memcpy(&_contents.data, p, length);
		} else {
			int len = _contents.length;
			resize(len + length);
			C.memcpy(pointer<byte>(&_contents.data) + len, p, length);
		}
		*(pointer<byte>(&_contents.data) + _contents.length) = 0;
	}
	
	public void append(int ch) {
		if (ch <= 0x7f)
			append(byte(ch));
		else if (ch <= 0x7ff) {
			append(byte(0xc0 + (ch >> 6)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0xffff) {
			append(byte(0xe0 + (ch >> 12)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0x1fffff) {
			append(byte(0xf0 + (ch >> 18)));
			append(byte(0x80 + ((ch >> 12) & 0x3f)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0x3ffffff) {
			append(byte(0xf8 + (ch >> 24)));
			append(byte(0x80 + ((ch >> 18) & 0x3f)));
			append(byte(0x80 + ((ch >> 12) & 0x3f)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0x7fffffff) {
			append(byte(0xfc + (ch >> 30)));
			append(byte(0x80 + ((ch >> 24) & 0x3f)));
			append(byte(0x80 + ((ch >> 18) & 0x3f)));
			append(byte(0x80 + ((ch >> 12) & 0x3f)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		}
	}
	
	public string center(int size) {
		return center(size, ' ');
	}
	
	public string center(int size, char pad) {
		int margin = size - _contents.length;
		if (margin <= 0)
			return *this;
		string result = "";
		int half = margin / 2;
		for (int i = 0; i < half; i++, margin--)
			result.append(pad);
//		print("a '");
//		print(result);
//		print("'\n");
		result.append(*this);
//		print("b '");
//		print(result);
//		print("'\n");
		for (int i = 0; i < margin; i++)
			result.append(pad);
//		print("c '");
//		print(result);
//		print("'\n");
		return result;
	}
	
	public void clear() {
		copy(null);
	}
	
	public int compare(string other) {
		if (_contents == null) {
			if (other._contents == null)
				return 0;
			else
				return -1;
		} else if (other._contents == null)
			return 1;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		pointer<byte> ocp = pointer<byte>(&other._contents.data);
		if (_contents.length < other._contents.length) {
			for (int i = 0; i < _contents.length; i++) {
				if (cp[i] != ocp[i])
					return cp[i] < ocp[i] ? -1 : 1;
			}
			return -1;
		} else {
			for (int i = 0; i < other._contents.length; i++) {
				if (cp[i] != ocp[i])
					return cp[i] < ocp[i] ? -1 : 1;
			}
			if (_contents.length > other._contents.length)
				return 1;
			else
				return 0;
		}
	}
	
	public int compareIgnoreCase(string other) {
		return 0;
	}
	
	public void copy(string other) {
		if (other != null) {
			if (_contents == other._contents)
				return;
			resize(other._contents.length);
			C.memcpy(&_contents.data, &other._contents.data, other._contents.length + 1);
		} else {
			if (_contents != null) {
				memory.free(_contents);
				_contents = null;
			}
		}
	}
	// This method is called from generated code and assumes that the target memory is un-constructed.
	void copyTemp(string other) {
		_contents = null;
		if (other != null) {
			resize(other._contents.length);
			C.memcpy(&_contents.data, &other._contents.data, other._contents.length + 1);
		}
	}
	
	public int count(RegularExpression pattern) {
		return 0;
	}
	
	public string encrypt(string salt) {
		return *this;
	}
	
	public boolean endsWith(string suffix) {
		if (suffix.length() > length())
			return false;
		int base = length() - suffix.length();
		pointer<byte> cp = pointer<byte>(&_contents.data) + base;
		pointer<byte> scp = pointer<byte>(&suffix._contents.data);
		for (int i = 0; i < suffix.length(); i++)
			if (scp[i] != cp[i])
				return false;
		return true;
	}

	public boolean equalIgnoreCase(string other) {
		return false;
	}
	/*
	 *	escapeC
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed C
	 *	string literal token with the same string value as 
	 *	this object, but which consists exclusively of 7-bit
	 *	ASCII characters.  All characters with a high-order bit
	 *	set are converted to hex escape sequences with two digits
	 *	each (e.g. \xff).
	 *
	 *	Note: Because apostrophes are also escaped, this can be used to escape C
	 *	character constants as well.
	 */
	string escapeC() {
		string output;

		if (length() == 0)
			return *this;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			switch (cp[i]) {
			case	'\\':	output.append("\\\\");	break;
			case	'\a':	output.append("\\a");	break;
			case	'\b':	output.append("\\b");	break;
			case	'\f':	output.append("\\f");	break;
			case	'\n':	output.append("\\n");	break;
			case	'\r':	output.append("\\r");	break;
			case	'\v':	output.append("\\v");	break;
			case	'\'':	output.append("\\'");	break;
			case	'"':	output.append("\\\"");	break;
			default:
				if (cp[i] >= 0x20 &&
					cp[i] < 0x7f)
					output.append(cp[i]);
				else
					output.printf("\\x%x", cp[i] & 0xff);
			}
		}
		return output;
	}
	/*
	 *	escapeJSON
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed JSON
	 *	string literal token with the same string value as 
	 *	this object.
	 */
	string escapeJSON() {
		string output;

		if (length() == 0)
			return *this;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			switch (cp[i]) {
			case	'\\':	output.append("\\\\");	break;
			case	'\b':	output.append("\\b");	break;
			case	'\f':	output.append("\\f");	break;
			case	'\n':	output.append("\\n");	break;
			case	'\r':	output.append("\\r");	break;
			case	'\t':	output.append("\\t");	break;
			case	'"':	output.append("\\\"");	break;
			default:
				output.append(cp[i]);
			}
		}
		return output;
	}
	/*
	 *	escapeParasol
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed Parasol
	 *	string literal token with the same string value as 
	 *	this object.  This differs in C-escaping a string in that
	 *	all well-formed extended Unicode characters are converted to
	 *	\uNNNNN escape sequences.  Other sub-sequences of characters with
	 *	high-order bits set will be converted using hex sequences as for
	 *	escapeC.
	 *
	 *	Note: Because apostrophes are also escaped, this can be used to escape C
	 *	character constants as well.
	 */
	string escapeParasol() {
		string output;

		if (length() == 0)
			return *this;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			switch (cp[i]) {
			case	'\\':	output.append("\\\\");	break;
			case	'\a':	output.append("\\a");	break;
			case	'\b':	output.append("\\b");	break;
			case	'\f':	output.append("\\f");	break;
			case	'\n':	output.append("\\n");	break;
			case	'\r':	output.append("\\r");	break;
			case	'\v':	output.append("\\v");	break;
			case	'\'':	output.append("\\'");	break;
			case	'"':	output.append("\\\"");	break;
			default:
				if (cp[i] >= 0x20 &&
					cp[i] < 0x7f)
					output.append(cp[i]);
				else {
					// TODO: Implement \uNNNNN sequence
					//assert(false);
					output.printf("\\x%x", cp[i]);
				}
			}
		}
		return output;
	}
	/*
	 *	escapeShell
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed shell command-line
	 *  argument.
	 */
	string escapeShell() {
		string output;

		if (length() == 0)
			return *this;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			switch (cp[i]) {
			case	'\\':	output.append("\\\\");	break;
			case	'\'':	output.append("\\'");	break;
			case	'"':	output.append("\\\"");	break;
			default:		output.append(cp[i]);
			}
		}
		return output;
	}


//	public long fingerprint() {
//		return 0;
//	}
	
//	public char get(int index) {
//		return ' ';
//	}
	
	public int hash() {
		if (_contents == null)
			return 0;
		if (_contents.length == 1)
			return pointer<byte>(&_contents.data)[0];
		else
			return pointer<byte>(&_contents.data)[0] + (pointer<byte>(&_contents.data)[_contents.length - 1] << 7);
	}
	/*
	 *	indexOf
	 *
	 *	Returns the index of the first occurrance of the byte c
	 *	in the string.
	 *
	 *	Returns -1 if the byte does not appear in the string
	 */
	public int indexOf(byte c) {
		return indexOf(c, 0);
	}
	/*
	 *	indexOf
	 *
	 *	Returns the index of the first occurance of the string s
	 *	in this object.
	 *
	 *	Returns -1 if the substring does not appear in the object.
	 */
	public int indexOf(string s) {
		return indexOf(s, 0);
	}
	/*
	 *	indexOf
	 *
	 *	Returns the index of the first occurrance of the byte c
	 *	in the string, starting with the index given by start.
	 *
	 *	Returns -1 if the byte does not appear in the string
	 */
	public int indexOf(byte c, int start) {
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = start; i < length(); i++)
			if (cp[i] == c)
				return i;
		return -1;
	}
	/*
	 *	indexOf
	 *
	 *	Returns the index of the first occurrance of the string s
	 *	in the string, starting with the index given by start.
	 *
	 *	Returns -1 if the byte does not appear in the string
	 */
	public int indexOf(string s, int start) {
		pointer<byte> cp = pointer<byte>(&_contents.data);
		int tries =  1 + length() - s.length() - start;
		for (int i = 0; i < tries; i++){
			boolean matched = true;
			for (int j = 0; j < s.length(); j++) {
				if (cp[i + start + j] != s[j]) {
					matched = false;
					break;
				}
			}
			if (matched)
				return start + i;
		}
		return -1;
	}

	public void insert(int index, byte value) {
		if (index < 0 || index > _contents.length)
			return;
		resize(_contents.length + 1);
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int j = _contents.length - 1; j > index; j--)
			cp[j] = cp[j - 1];
		cp[index] = value;
	}
	
	public int lastIndexOf(byte c) {
		return lastIndexOf(c, length() - 1);
	}
	
	public int lastIndexOf(byte c, int start) {
		if (_contents != null) {
			pointer<byte> cp = pointer<byte>(&_contents.data);
			for (int i = start; i >= 0; i--)
				if (cp[i] == c)
					return i;
		}
		return -1;
	}
	
	public int lastIndexOf(string s) {
		return lastIndexOf(s, length() - 1);
	}
	
	public int lastIndexOf(string s, int start) {
		pointer<byte> cp = pointer<byte>(&_contents.data);
		int tries =  2 + start - s.length();
		start += 1 - s.length();
		for (int i = 0; i < tries; i++){
			boolean matched = true;
			for (int j = 0; j < s.length(); j++) {
				if (cp[start + j - i] != s[j]) {
					matched = false;
					break;
				}
			}
			if (matched)
				return start - i;
		}
		return -1;
	}

	public int length() {
		if (_contents != null)
			return _contents.length;
		else
			return 0;
	}

	public int printf(string format, var... arguments) {
		StringWriter w(this);
		return w.printf(format, arguments);
	}

	public string remove(RegularExpression pattern) {
		return null;
	}
	
	public void resize(int newLength) {
		int newSize = reservedSize(newLength);
		if (_contents != null) {
			if (_contents.length >= newLength) {
				_contents.length = newLength;
				return;
			}
			int oldSize = reservedSize(_contents.length);
			if (oldSize == newSize) {
				_contents.length = newLength;
				return;
			}
		}
		ref<allocation> a = ref<allocation>(memory.alloc(newSize));
		if (_contents != null) {
			C.memcpy(&a.data, &_contents.data, _contents.length + 1);
			memory.free(_contents);
		}
		a.length = newLength;
		*(pointer<byte>(&a.data) + newLength) = 0;
		_contents = a;
	}

	private int reservedSize(int length) {
		int usedSize = length + int.bytes + 1;
		if (usedSize >= 0x40000000) {
			return (usedSize + 15) & ~15;
		}
		int allocSize = MIN_SIZE;
		while (allocSize < usedSize)
			allocSize <<= 1;
		return allocSize;
	}
	
	public void set(int index, char value) {
	}
	/*
	 *	split
	 *
	 *	Splits a string into one or more sub-strings and
	 *	stores them in the output vector.  If no instances of the
	 *	delimiter character are present, then the vector is
	 *	filled with a single element that is the entire
	 *	string.  The output vector always has as many elements
	 *	as the number of delimiters in the input string plus one.
	 *	The delimiter characters are not included in the output.
	 */
	string[] split(char delimiter) {
		string[] output;
		if (_contents != null) {
			int tokenStart = 0;
			for (int i = 0; i < _contents.length; i++) {
				if (pointer<byte>(&_contents.data)[i] == delimiter) {
					output.append(string(pointer<byte>(&_contents.data) + tokenStart, i - tokenStart));
					tokenStart = i + 1;
				}
			}
			if (tokenStart > 0)
				output.append(string(pointer<byte>(&_contents.data) + tokenStart, _contents.length - tokenStart));
			else
				output.append(*this);
		} else
			output.resize(1);
		return output;
	}
	/*
	 * startsWith - matches a prefix against the target string. If this string is a byte-by-byte match for the other
	 * string, this method returns true. If this string is null, this method returns false, regardless of the value of the
	 * prefix. 
	 */
	public boolean startsWith(string prefix) {
		if (_contents == null)
			return false;
		if (prefix.length() > length())
			return false;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		pointer<byte> pcp = pointer<byte>(&prefix._contents.data);
		for (int i = 0; i < prefix.length(); i++)
			if (pcp[i] != cp[i])
				return false;
		return true;
	}

	public boolean startsWith(text.substring prefix) {
		if (_contents == null)
			return false;
		if (prefix._data == null)
			return false;
		if (prefix._length > length())
			return false;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < prefix._length; i++)
			if (prefix._data[i] != cp[i])
				return false;
		return true;
	}
	
	/**
	 * store
	 * 
	 * This is only in generated code in those circumstances where a string returned from a function can short-
	 * circuit a copy and a delete by just taing the live string value returned from the function and calling this
	 * method to use that live value.
	 */
	void store(ref<allocation> other) {
		copy(null);			// First, just remove whatever data we have in the string
		_contents = other;	// Then. store the new data - note that other == null is the right value for a null string.
//		print("after store: ");
//		print(*this);
//		print("\n");
	}
	/**
	 * storeTemp
	 * 
	 * This is only in generated code in those circumstances where a string returned from a function can short-
	 * circuit a copy and a delete by just taing the live string value returned from the function and calling this
	 * method to use that live value.
	 * 
	 * Note that this assumes the memory being assigned-to is not constructed.
	 */
	void storeTemp(ref<allocation> other) {
		_contents = other;	// Then. store the new data - note that other == null is the right value for a null string.
//		print("after store: ");
//		print(*this);
//		print("\n");
	}
	/*
	 *	substring
	 *
	 *	Return a substring of this string, starting at the character
	 *	given by first and continuing to the end of the string.
	 */
	public string substring(int first) {
		return substring(first, length());
	}
	/*
	 *	substring
	 *
	 *	Return a substring of this string, starting at the character
	 *	given by first and continuing to (but not including) the
	 *	character given by last.
	 *
	 *	TODO: Out of range values should produce exceptions
	 */
	public string substring(int first, int last) {
		string result;
		
		result.append(pointer<byte>(&_contents.data) + first, last - first);
		return result;
	}
	
	public string toLowerCase() {
		if (length() == 0)
			return *this;
		string out;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			if (cp[i].isUpperCase())
				out.append(cp[i].toLowerCase());
			else
				out.append(cp[i]);
		}
		return out;
	}
	
	public string toUpperCase() {
		if (length() == 0)
			return *this;
		string out;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			if (cp[i].isLowerCase())
				out.append(cp[i].toUpperCase());
			else
				out.append(cp[i]);
		}
		return out;
	}
	
	public string trim() {
		if (length() == 0)
			return *this;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			if (!cp[i].isSpace()) {
				for (int j = _contents.length - 1; j > i; j--) {
					if (!cp[j].isSpace())
						return string(cp + i, 1 + (j - i));
				}
				return string(cp, 1);
			}
		}
		return "";
	}
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
	 *		\xHH	hex escape
	 *		\0DDD	octal escape
	 *		\\		\
	 *
	 *	RETURNS
	 *		false	If the sequence is not well-formed.
	 *		string	The converted string (if the boolean is true).
	 */
	string,boolean unescapeC() {
		string output;
		
		if (length() == 0)
			return *this, true;
		for (int i = 0; i < _contents.length; i++) {
			if (pointer<byte>(&_contents.data)[i] == '\\') {
				if (i == _contents.length - 1)
					return output, false;
				else {
					int v;
					i++;
					switch (pointer<byte>(&_contents.data)[i]) {
					case 'a':	output.append('\a');	break;
					case 'b':	output.append('\b');	break;
					case 'f':	output.append('\f');	break;
					case 'n':	output.append('\n');	break;
					case 'r':	output.append('\r');	break;
					case 't':	output.append('\t');	break;
					case 'v':	output.append('\v');	break;
					case 'x':
					case 'X':
						i++;;
						if (i >= _contents.length)
							return output, false;
						if (!pointer<byte>(&_contents.data)[i].isHexDigit())
							return output, false;
						v = 0;
						do {
							v <<= 4;
							if (v > 0xff)
								return output, false;
							if (pointer<byte>(&_contents.data)[i].isDigit())
								v += pointer<byte>(&_contents.data)[i] - '0';
							else
								v += 10 + pointer<byte>(&_contents.data)[i].toLowerCase() - 'a';
							i++;
						} while (i < _contents.length && pointer<byte>(&_contents.data)[i].isHexDigit());
						output.append(v);
						break;
					case '0':
						i++;
						if (i >= _contents.length)
							return output, false;
						if (!pointer<byte>(&_contents.data)[i].isOctalDigit())
							return output, false;
						v = 0;
						do {
							v <<= 3;
							if (v > 0xff)
								return output, false;
							v += pointer<byte>(&_contents.data)[i] - '0';
							i++;
						} while (i < _contents.length && pointer<byte>(&_contents.data)[i].isOctalDigit());
						output.append(byte(v));
						break;
					default:	
						output.append(pointer<byte>(&_contents.data)[i]);
					}
				}
			} else
				output.append(pointer<byte>(&_contents.data)[i]);
		}
		return output, true;
	}
	/*
	 *	unescapeJSON
	 *
	 *	Process the input string as if it were a C string literal.
	 *	Escape sequences are:
	 *
	 *		\b		backspace
	 *		\f		form-feed
	 *		\n		newline
	 *		\r		carriage return
	 *		\t		tab
	 *		\uNNNN	Unicode code point
	 *		\\		\
	 *		\/		/
	 *		\"		"
	 *
	 *	RETURNS
	 *		false	If the sequence is not well-formed.
	 *		string	The converted string (if the boolean is true).
	 */
	string, boolean unescapeJSON() {
		string output;
		
		if (length() == 0)
			return *this, true;
		for (int i = 0; i < _contents.length; i++) {
			if (pointer<byte>(&_contents.data)[i] == '\\') {
				if (i == _contents.length - 1)
					return output, false;
				else {
					int v;
					i++;
					switch (pointer<byte>(&_contents.data)[i]) {
					case 'b':	output.append('\b');	break;
					case 'f':	output.append('\f');	break;
					case 'n':	output.append('\n');	break;
					case 'r':	output.append('\r');	break;
					case 't':	output.append('\t');	break;
					case '/':	output.append('/');		break;
					case '\\':	output.append('\\');	break;
					case '"':	output.append('"');		break;
					case 'u':
					case 'U':
						i++;;
						if (i >= _contents.length)
							return output, false;
						if (!pointer<byte>(&_contents.data)[i].isHexDigit())
							return output, false;
						v = 0;
						do {
							v <<= 4;
							if (v > 0xff)
								return output, false;
							if (pointer<byte>(&_contents.data)[i].isDigit())
								v += pointer<byte>(&_contents.data)[i] - '0';
							else
								v += 10 + pointer<byte>(&_contents.data)[i].toLowerCase() - 'a';
							i++;
						} while (i < _contents.length && pointer<byte>(&_contents.data)[i].isHexDigit());
						// TODO: Implement Unicode escape sequence. 
						assert(v < 128);
						output.append(byte(v));
						i--;
						break;
						
					default:
						return output, false;
					}
				}
			} else
				output.append(pointer<byte>(&_contents.data)[i]);
		}
		return output, true;
	}
	/*
	 *	unescapeParasol
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
	 *		\uNNNN	Unicode code point
	 *		\v		vertical tab
	 *		\xHH	hex escape
	 *		\0DDD	octal escape
	 *		\\		\
	 *
	 *	RETURNS
	 *		false	If the sequence is not well-formed.
	 *		string	The converted string (if the boolean is true).
	 */
	string,boolean unescapeParasol() {
		string output;
		
		if (length() == 0)
			return *this, true;
		for (int i = 0; i < _contents.length; i++) {
			if (pointer<byte>(&_contents.data)[i] == '\\') {
				if (i == _contents.length - 1)
					return output, false;
				else {
					int v;
					i++;
					switch (pointer<byte>(&_contents.data)[i]) {
					case 'a':	output.append('\a');	break;
					case 'b':	output.append('\b');	break;
					case 'f':	output.append('\f');	break;
					case 'n':	output.append('\n');	break;
					case 'r':	output.append('\r');	break;
					case 't':	output.append('\t');	break;
					case 'v':	output.append('\v');	break;
					case 'u':
					case 'U':
					case 'x':
					case 'X':
						i++;;
						if (i >= _contents.length)
							return output, false;
						if (!pointer<byte>(&_contents.data)[i].isHexDigit())
							return output, false;
						v = 0;
						do {
							v <<= 4;
							if (v > 0xff)
								return output, false;
							if (pointer<byte>(&_contents.data)[i].isDigit())
								v += pointer<byte>(&_contents.data)[i] - '0';
							else
								v += 10 + pointer<byte>(&_contents.data)[i].toLowerCase() - 'a';
							i++;
						} while (i < _contents.length && pointer<byte>(&_contents.data)[i].isHexDigit());
						output.append(byte(v));
						i--;
						break;
						
					case '0':
						i++;
						if (i >= _contents.length ||
							!pointer<byte>(&_contents.data)[i].isOctalDigit()) {
							i--;
							output.append(byte(0));
							break;
						}
						v = 0;
						do {
							v <<= 3;
							if (v > 0xff)
								return output, false;
							v += pointer<byte>(&_contents.data)[i] - '0';
							i++;
						} while (i < _contents.length && pointer<byte>(&_contents.data)[i].isOctalDigit());
						output.append(v);
						break;
						
					default:
						output.append(pointer<byte>(&_contents.data)[i]);
					}
				}
			} else
				output.append(pointer<byte>(&_contents.data)[i]);
		}
		return output, true;
	}
}

public class substring {
	pointer<byte> _data;
	int _length;

	public substring() {
	}
	
	public substring(string source) {
		if (source != null) {
			_data = &source[0];
			_length = source.length();
		}
	}

	public substring(string source, int start) {
		if (source != null) {
			_data = &source[start];
			_length = source.length() - start;
		}
	}

	public substring(string source, int start, int end) {
		if (source != null) {
			_data = &source[start];
			_length = end - start;
		}
	}
	
	public substring(pointer<byte> cString) {
		if (cString != null) {
			_length = C.strlen(cString);
			_data = cString;
		}
	}
	
	public substring(ref<byte[]> value) {
		_length = value.length();
		_data = &(*value)[0];
	}
	
	public substring(pointer<byte> buffer, int len) {
		if (buffer != null) {
			_length = len;
			_data = buffer;
		}
	}
	
	public pointer<byte> c_str() {
		return _data;
	}

	public string center(int size) {
		return center(size, ' ');
	}
	
	public string center(int size, char pad) {
		int margin = size - _length;
		if (margin <= 0)
			return string(*this);
		string result = "";
		int half = margin / 2;
		for (int i = 0; i < half; i++, margin--)
			result.append(pad);
//		print("a '");
//		print(result);
//		print("'\n");
		result.append(*this);
//		print("b '");
//		print(result);
//		print("'\n");
		for (int i = 0; i < margin; i++)
			result.append(pad);
//		print("c '");
//		print(result);
//		print("'\n");
		return result;
	}
	
	public void clear() {
		_data = null;
		_length = 0;
	}
	
	public int compare(string other) {
		if (_data == null) {
			if (other == null)
				return 0;
			else
				return -1;
		} else if (other == null)
			return 1;
		pointer<byte> ocp = &other[0];
		if (_length < other.length()) {
			for (int i = 0; i < _length; i++) {
				if (_data[i] != ocp[i])
					return _data[i] < ocp[i] ? -1 : 1;
			}
			return -1;
		} else {
			for (int i = 0; i < other.length(); i++) {
				if (_data[i] != ocp[i])
					return _data[i] < ocp[i] ? -1 : 1;
			}
			if (_length > other.length())
				return 1;
			else
				return 0;
		}
	}
	
	public int compareIgnoreCase(string other) {
		return 0;
	}
	
	public int count(RegularExpression pattern) {
		return 0;
	}
	
	public string encrypt(string salt) {
		return string(*this);
	}
	
	public boolean endsWith(string suffix) {
		if (suffix.length() > _length)
			return false;
		int base = _length - suffix.length();
		pointer<byte> cp = _data + base;
		for (int i = 0; i < suffix.length(); i++)
			if (suffix[i] != cp[i])
				return false;
		return true;
	}

	public boolean equalIgnoreCase(string other) {
		return false;
	}
	/*
	 *	escapeC
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed C
	 *	string literal token with the same string value as 
	 *	this object, but which consists exclusively of 7-bit
	 *	ASCII characters.  All characters with a high-order bit
	 *	set are converted to hex escape sequences with two digits
	 *	each (e.g. \xff).
	 */
	string escapeC() {
		string output;

		if (_data == null)
			return null;
		if (_length == 0)
			return "";
		for (int i = 0; i < _length; i++) {
			switch (_data[i]) {
			case	'\\':	output.append("\\\\");	break;
			case	'\a':	output.append("\\a");	break;
			case	'\b':	output.append("\\b");	break;
			case	'\f':	output.append("\\f");	break;
			case	'\n':	output.append("\\n");	break;
			case	'\r':	output.append("\\r");	break;
			case	'\v':	output.append("\\v");	break;
			default:
				if (_data[i] >= 0x20 &&
					_data[i] < 0x7f)
					output.append(_data[i]);
				else
					output.printf("\\x%x", _data[i] & 0xff);
			}
		}
		return output;
	}
	/*
	 *	escapeJSON
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed JSON
	 *	string literal token with the same string value as 
	 *	this object.  This differs in C-escaping a string in that
	 *	all well-formed extended Unicode characters are converted to
	 *	\uNNNNN escape sequences.  Other sub-sequences of characters with
	 *	high-order bits set will be converted using hex sequences as for
	 *	escapeC.
	 */
	string escapeJSON() {
		string output;

		if (_data == null)
			return null;
		if (_length == 0)
			return "";
		for (int i = 0; i < _length; i++) {
			switch (_data[i]) {
			case	'\"':	output.append("\\\"");	break;
			case	'\\':	output.append("\\\\");	break;
			case	'\b':	output.append("\\b");	break;
			case	'\f':	output.append("\\f");	break;
			case	'\n':	output.append("\\n");	break;
			case	'\r':	output.append("\\r");	break;
			case	'\t':	output.append("\\t");	break;
			default:
				output.append(_data[i]);
			}
		}
		return output;
	}
	/*
	 *	escapeParasol
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed Parasol
	 *	string literal token with the same string value as 
	 *	this object.  This differs in C-escaping a string in that
	 *	all well-formed extended Unicode characters are converted to
	 *	\uNNNNN escape sequences.  Other sub-sequences of characters with
	 *	high-order bits set will be converted using hex sequences as for
	 *	escapeC.
	 */
	string escapeParasol() {
		string output;

		if (_data == null)
			return null;
		if (_length == 0)
			return "";
		for (int i = 0; i < _length; i++) {
			switch (_data[i]) {
			case	'\\':	output.append("\\\\");	break;
			case	'\a':	output.append("\\a");	break;
			case	'\b':	output.append("\\b");	break;
			case	'\f':	output.append("\\f");	break;
			case	'\n':	output.append("\\n");	break;
			case	'\r':	output.append("\\r");	break;
			case	'\v':	output.append("\\v");	break;
			default:
				if (_data[i] >= 0x20 &&
					_data[i] < 0x7f)
					output.append(_data[i]);
				else {
					// TODO: Implement \uNNNNN sequence
					//assert(false);
					output.printf("\\x%x", _data[i]);
				}
			}
		}
		return output;
	}
	/*
	 *	escapeShell
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed shell command-line
	 *  argument.
	 */
	string escapeShell() {
		string output;

		if (_data == null)
			return null;
		for (int i = 0; i < _length; i++) {
			switch (_data[i]) {
			case	'\\':	output.append("\\\\");	break;
			case	'\'':	output.append("\\'");	break;
			case	'"':	output.append("\\\"");	break;
			default:		output.append(_data[i]);
			}
		}
		return output;
	}


//	public long fingerprint() {
//		return 0;
//	}
	
	public char get(int index) {
		return _data[index];
	}
	
	public int hash() {
		if (_data == null)
			return 0;
		if (_length == 1)
			return _data[0];
		else
			return _data[0] + (_data[_length - 1] << 7);
	}
	/*
	 *	indexOf
	 *
	 *	Returns the index of the first occurrance of the byte c
	 *	in the string.
	 *
	 *	Returns -1 if the byte does not appear in the string
	 */
	public int indexOf(byte c) {
		return indexOf(c, 0);
	}
	/*
	 *	indexOf
	 *
	 *	Returns the index of the first occurance of the string s
	 *	in this object.
	 *
	 *	Returns -1 if the substring does not appear in the object.
	 */
	public int indexOf(string s) {
		return indexOf(s, 0);
	}
	/*
	 *	indexOf
	 *
	 *	Returns the index of the first occurrance of the byte c
	 *	in the string, starting with the index given by start.
	 *
	 *	Returns -1 if the byte does not appear in the string
	 */
	public int indexOf(byte c, int start) {
		if (_data == null)
			return -1;
		for (int i = start; i < _length; i++)
			if (_data[i] == c)
				return i;
		return -1;
	}
	/*
	 *	indexOf
	 *
	 *	Returns the index of the first occurrance of the string s
	 *	in the string, starting with the index given by start.
	 *
	 *	Returns -1 if the byte does not appear in the string
	 */
	public int indexOf(string s, int start) {
		if (_data == null)
			return -1;
		int tries =  1 + _length - s.length() - start;
		for (int i = 0; i < tries; i++){
			boolean matched = true;
			for (int j = 0; j < s.length(); j++) {
				if (_data[i + start + j] != s[j]) {
					matched = false;
					break;
				}
			}
			if (matched)
				return start + i;
		}
		return -1;
	}
	
	public int lastIndexOf(byte c) {
		if (_data != null) {
			for (int i = _length - 1; i >= 0; i--)
				if (_data[i] == c)
					return i;
		}
		return -1;
	}
	
	public int length() {
		if (_data != null)
			return _length;
		else
			return 0;
	}
	
	public string remove(RegularExpression pattern) {
		return null;
	}
		
	public void set(int index, char value) {
	}
	/*
	 *	split
	 *
	 *	Splits a string into one or more sub-strings and
	 *	stores them in the output vector.  If no instances of the
	 *	delimiter character are present, then the vector is
	 *	filled with a single element that is the entire
	 *	string.  The output vector always has as many elements
	 *	as the number of delimiters in the input string plus one.
	 *	The delimiter characters are not included in the output.
	 */
	string[] split(char delimiter) {
		string[] output;
		if (_data != null) {
			int tokenStart = 0;
			for (int i = 0; i < _length; i++) {
				if (_data[i] == delimiter) {
					output.append(string(_data + tokenStart, i - tokenStart));
					tokenStart = i + 1;
				}
			}
			if (tokenStart > 0)
				output.append(string(_data + tokenStart, _length - tokenStart));
			else
				output.append(string(*this));
		} else
			output.resize(1);
		return output;
	}
	/*
	 * startsWith - matches a prefix against the target string. If this string is a byte-by-byte match for the other
	 * string, this method returns true. If this string is null, this method returns false, regardless of the value of the
	 * prefix. 
	 */
	public boolean startsWith(string prefix) {
		if (_data == null)
			return false;
		// If the prefix is longer, it can't match
		if (_length < prefix.length())
			return false;
		// Check the first N bytes (N = the length of the shorter, the prefix).
		for (int i = 0; i < prefix.length(); i++) {
			if (_data[i] != prefix[i])
				return false;
		}
		return true;
	}


	public boolean startsWith(text.substring prefix) {
		if (_data == null)
			return false;
		if (prefix._length > _length)
			return false;
		for (int i = 0; i < prefix._length; i++)
			if (prefix._data[i] != _data[i])
				return false;
		return true;
	}
	/*
	 *	substring
	 *
	 *	Return a substring of this string, starting at the character
	 *	given by first and continuing to the end of the string.
	 */
	public text.substring substring(int first) {
		return this.substring(first, _length);
	}
	/*
	 *	substring
	 *
	 *	Return a substring of this string, starting at the character
	 *	given by first and continuing to (but not including) the
	 *	character given by last.
	 *
	 *	TODO: Out of range values should produce exceptions
	 */
	public text.substring substring(int first, int last) {
		return text.substring(_data + first, last - first);
	}
	
	public string toLowerCase() {
		if (_data == null)
			return null;
		if (_length == 0)
			return "";
		string out;
		for (int i = 0; i < _length; i++) {
			if (_data[i].isUpperCase())
				out.append(_data[i].toLowerCase());
			else
				out.append(_data[i]);
		}
		return out;
	}
	
	public string toUpperCase() {
		if (_data == null)
			return null;
		if (_length == 0)
			return "";
		string out;
		for (int i = 0; i < _length; i++) {
			if (_data[i].isLowerCase())
				out.append(_data[i].toUpperCase());
			else
				out.append(_data[i]);
		}
		return out;
	}
	
	public text.substring trim() {
		if (_data == null)
			return text.substring();
		for (int i = 0; i < _length; i++) {
			if (!_data[i].isSpace()) {
				for (int j = _length - 1; j > i; j--) {
					if (!_data[j].isSpace())
						return text.substring(_data + i, 1 + (j - i));
				}
				return text.substring(_data, 1);
			}
		}
		return text.substring(&""[0], 0);
	}
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
	 *		\xHH	hex escape
	 *		\0DDD	octal escape
	 *		\\		\
	 *
	 *	RETURNS
	 *		false	If the sequence is not well-formed.
	 *		string	The converted string (if the boolean is true).
	 */
	string,boolean unescapeC() {
		string output;
		
		if (_data == null)
			return null, true;
		if (_length == 0)
			return "", true;
		for (int i = 0; i < _length; i++) {
			if (_data[i] == '\\') {
				if (i == _length - 1)
					return output, false;
				else {
					int v;
					i++;
					switch (_data[i]) {
					case 'a':	output.append('\a');	break;
					case 'b':	output.append('\b');	break;
					case 'f':	output.append('\f');	break;
					case 'n':	output.append('\n');	break;
					case 'r':	output.append('\r');	break;
					case 't':	output.append('\t');	break;
					case 'v':	output.append('\v');	break;
					case 'x':
					case 'X':
						i++;;
						if (i >= _length)
							return output, false;
						if (!_data[i].isHexDigit())
							return output, false;
						v = 0;
						do {
							v <<= 4;
							if (v > 0xff)
								return output, false;
							if (_data[i].isDigit())
								v += _data[i] - '0';
							else
								v += 10 + _data[i].toLowerCase() - 'a';
							i++;
						} while (i < _length && _data[i].isHexDigit());
						output.append(v);
						break;
					case '0':
						i++;
						if (i >= _length)
							return output, false;
						if (!_data[i].isOctalDigit())
							return output, false;
						v = 0;
						do {
							v <<= 3;
							if (v > 0xff)
								return output, false;
							v += _data[i] - '0';
							i++;
						} while (i < _length && _data[i].isOctalDigit());
						output.append(byte(v));
						break;
					default:	
						output.append(_data[i]);
					}
				}
			} else
				output.append(_data[i]);
		}
		return output, true;
	}
	/*
	 *	unescapeJSON
	 *
	 *	Process the input string as if it were a C string literal.
	 *	Escape sequences are:
	 *
	 *		\b		backspace
	 *		\f		form-feed
	 *		\n		newline
	 *		\r		carriage return
	 *		\t		tab
	 *		\uNNNN	Unicode code point
	 *		\\		\
	 *		\/		/
	 *		\"		"
	 *
	 *	RETURNS
	 *		false	If the sequence is not well-formed.
	 *		string	The converted string (if the boolean is true).
	 */
	string, boolean unescapeJSON() {
		string output;
		
		if (_data == null)
			return null, true;
		if (_length == 0)
			return "", true;
		for (int i = 0; i < _length; i++) {
			if (_data[i] == '\\') {
				if (i == _length - 1)
					return output, false;
				else {
					int v;
					i++;
					switch (_data[i]) {
					case 'b':	output.append('\b');	break;
					case 'f':	output.append('\f');	break;
					case 'n':	output.append('\n');	break;
					case 'r':	output.append('\r');	break;
					case 't':	output.append('\t');	break;
					case '/':	output.append('/');		break;
					case '\\':	output.append('\\');	break;
					case '"':	output.append('"');		break;
					case 'u':
					case 'U':
						i++;;
						if (i >= _length)
							return output, false;
						if (!_data[i].isHexDigit())
							return output, false;
						v = 0;
						do {
							v <<= 4;
							if (v > 0xff)
								return output, false;
							if (_data[i].isDigit())
								v += _data[i] - '0';
							else
								v += 10 + _data[i].toLowerCase() - 'a';
							i++;
						} while (i < _length && _data[i].isHexDigit());
						// TODO: Implement Unicode escape sequence. 
						assert(v < 128);
						output.append(byte(v));
						i--;
						break;
						
					default:
						return output, false;
					}
				}
			} else
				output.append(_data[i]);
		}
		return output, true;
	}
	/*
	 *	unescapeParasol
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
	 *		\uNNNN	Unicode code point
	 *		\v		vertical tab
	 *		\xHH	hex escape
	 *		\0DDD	octal escape
	 *		\\		\
	 *
	 *	RETURNS
	 *		false	If the sequence is not well-formed.
	 *		string	The converted string (if the boolean is true).
	 */
	string,boolean unescapeParasol() {
		string output;
		
		if (_data == null)
			return null, true;
		if (_length == 0)
			return "", true;
		for (int i = 0; i < _length; i++) {
			if (_data[i] == '\\') {
				if (i == _length - 1)
					return output, false;
				else {
					int v;
					i++;
					switch (_data[i]) {
					case 'a':	output.append('\a');	break;
					case 'b':	output.append('\b');	break;
					case 'f':	output.append('\f');	break;
					case 'n':	output.append('\n');	break;
					case 'r':	output.append('\r');	break;
					case 't':	output.append('\t');	break;
					case 'v':	output.append('\v');	break;
					case 'u':
					case 'U':
					case 'x':
					case 'X':
						i++;;
						if (i >= _length)
							return output, false;
						if (!_data[i].isHexDigit())
							return output, false;
						v = 0;
						do {
							v <<= 4;
							if (v > 0xff)
								return output, false;
							if (_data[i].isDigit())
								v += _data[i] - '0';
							else
								v += 10 + _data[i].toLowerCase() - 'a';
							i++;
						} while (i < _length && _data[i].isHexDigit());
						output.append(byte(v));
						i--;
						break;
						
					case '0':
						i++;
						if (i >= _length)
							return output, false;
						if (!_data[i].isOctalDigit())
							return output, false;
						v = 0;
						do {
							v <<= 3;
							if (v > 0xff)
								return output, false;
							v += _data[i] - '0';
							i++;
						} while (i < _length && _data[i].isOctalDigit());
						output.append(v);
						break;
						
					default:
						output.append(_data[i]);
					}
				}
			} else
				output.append(_data[i]);
		}
		return output, true;
	}
}

public class StringReader extends Reader {
	private ref<string> _source;
	private int _cursor;
	
	public StringReader(ref<string> source) {
		_source = source;
	}
	
	public int _read() {
		if (_cursor >= _source.length())
			return -1;
		else
			return (*_source)[_cursor++];
	}
}

public class StringWriter extends Writer {
	private ref<string> _output;
	
	public StringWriter(ref<string> output) {
		_output = output;
	}
	
	public void _write(byte c) {
		_output.append(c);
	}
}

public void memDump(address buffer, int length) {
	memDump(buffer, length, long(buffer));
}

public void memDump(address buffer, long length, long startingOffset) {
	pointer<byte> printed = pointer<byte>(startingOffset);
	pointer<byte> firstRow = printed + -int(startingOffset & 15);
	pointer<byte> data = pointer<byte>(buffer) + -int(startingOffset & 15);
	pointer<byte> next = printed + int(length);
	pointer<byte> nextRow = next + ((16 - int(next) & 15) & 15);
	for (pointer<byte> p = firstRow; int(p) < int(nextRow); p += 16, data += 16) {
		dumpPtr(p);
		printf(" ");
		for (int i = 0; i < 8; i++) {
			if (int(p + i) >= int(printed) && int(p + i) < int(next))
				printf(" %2.2x", int(data[i]));
			else
				printf("   ");
		}
		printf(" ");
		for (int i = 8; i < 16; i++) {
			if (int(p + i) >= int(printed) && int(p + i) < int(next))
				printf(" %2.2x", int(data[i]));
			else
				printf("   ");
		}
		printf(" ");
		for (int i = 0; i < 16; i++) {
			if (int(p + i) >= int(printed) && int(p + i) < int(next)) {
				if (data[i].isPrintable())
					printf("%c", int(data[i]));
				else
					printf(".");
			} else
				printf(" ");
		}
		printf("\n");
	}
}

private void dumpPtr(address x) {
	pointer<long> np = pointer<long>(&x);
	printf("%16.16x", *np);
}


class RegularExpression {
}
