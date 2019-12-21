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

import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;
import native:C;
/**
 * This class implements a read-only sub-string of a string object.
 *
 * A substring relies on some region of memory that must remain alive for the lifetime
 * of this substring. If the substring is set to be part or all of a string or byte array,
 * the underlying string or array cannot change size, be deleted or go out of scope.
 * MOdifying the contents of the string through this object, other substrings or the original
 * object will be reflected as all share common byte storage for the characters of the string.
 *
 * Once defined, you may modify individual bytes in a substring. You may not modify the length
 * of the substring. You may construct a new substring from an existing one and copy the
 * new value over the old.
 *
 * While all string literals are encoded as UTF-8 and a number of methods assume UTF-8
 * text, a string is an array of bytes. The documentation of the individual methods indicate 
 * where UTF-8 encoding is assumed and where other encodings will work.
 */
public class substring {
	pointer<byte> _data;
	int _length;
	/**
	 * The default constructor.
	 *
	 * By default, the string value is null.
	 */
	public substring() {
	}
	/**
	 * A constructor to make this substring a synonym for the argument string.
	 *
	 * @param source The string that this substring 
	 */
	public substring(string source) {
		if (source != null) {
			_data = &source[0];
			_length = source.length();
		}
	}
	/**
	 * A constructor from a sub-string.
	 *
	 * The specificed subrange of characters in the string are set as the value of a contents of the
	 * source string, beginning at the start offset are copied. The resulting string is never
	 * null.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The start is a byte offset. If that offset is in the middle of a multi-byte sequence, the newly
	 * constructed string will be malformed.
	 *
	 * @param source An existing string.
	 * @param start The index of the first byte of the source string to copy. If this value is
	 * exactly the same as the length of source, the newly constructed string is the empty string.
	 *
	 * @exception IllegalArgumentException Thrown if source is null or the startOffset is negative or 
	 * greater than the length of source.
	 */
	public substring(string source, int start) {
		if (source != null) {
			if (unsigned(start) > unsigned(source.length()))
				throw IllegalArgumentException("start");
			_data = &source[start];
			_length = source.length() - start;
		} else
			throw IllegalArgumentException("source");
	}
	/**
	 * A constructor from a sub-string.
	 *
	 * The specificed subrange of characters in the string are set as the value of a contents of the
	 * source string, beginning at the start offset are copied. The resulting string is never
	 * null.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The start and end are byte offsets. If either offset is in the middle of a multi-byte
	 * sequence, the newly constructed string will be malformed.
	 *
	 * @param source An existing string.
	 * @param start The index of the first byte of the source string to copy. If this value is
	 * exactly the same as the length of source, the newly constructed string is the empty string.
	 * @param end The index of the next byte after the last byte to copy.
	 *
	 * @exception IllegalArgumentException Thrown if source is null, the start is negative or 
	 * greater than the length of source or the end is less than the start or greater
	 * than the source length.
	 */
	public substring(string source, int start, int end) {
		if (source != null) {
			if (unsigned(start) > unsigned(source.length()) || start > end || end > source.length())
				throw IllegalArgumentException("start");
			_data = &source[start];
			_length = end - start;
		} else
			throw IllegalArgumentException("source");
	}
	/**
	 * A constructor from a C language string.
	 *
	 * C stores strings as null-terminated pointers (a char* in C). In Parasol the corresponding type is
	 * pointer<byte>. Note that in Parasol, the byte type is unsigned, while the C char type is often treated
	 * as signed. Parasol has no signed-byte type to use for this.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The constructor assumes the source encoding does not use the null byte for any multi-byte encodings.
	 *
	 * @param cString The C pointer value.	 
	 */
	public substring(pointer<byte> cString) {
		if (cString != null) {
			_length = C.strlen(cString);
			_data = cString;
		}
	}
	/**
	 * A constructor from a byte array.
	 *
	 * @param value The byte array.
	 */
	public substring(ref<byte[]> value) {
		_length = value.length();
		_data = &(*value)[0];
	}
	/**
	 * A constructor from a range of bytes.
	 *
	 * @param buffer The address of the first byte of the substring.
	 * @param length The number of bytes in the substring.
	 *
	 * @exception IllegalArgumentException Thrown if buffer is null.
	 */
	public substring(pointer<byte> buffer, int len) {
		if (buffer != null) {
			_length = len;
			_data = buffer;
		} else
			throw IllegalArgumentException("buffer");
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
	
	public int compare(ref<substring> other) {
		assert(other != null);
		if (_data == null) {
			if (other._data == null)
				return 0;
			else
				return -1;
		} else if (other._data == null)
			return 1;
		if (_length < other._length) {
			for (int i = 0; i < _length; i++) {
				if (_data[i] != other._data[i])
					return _data[i] < other._data[i] ? -1 : 1;
			}
			return -1;
		} else {
			for (int i = 0; i < other._length; i++) {
				if (_data[i] != other._data[i])
					return _data[i] < other._data[i] ? -1 : 1;
			}
			if (_length > other._length)
				return 1;
			else
				return 0;
		}
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
		for (int i = 0; i < tries; i++){
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
	
	public boolean isNull() {
		return _data == null;
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
		
	public void set(int index, byte value) {
		_data[index] = value;
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
	public string[] split(byte delimiter) {
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


	public boolean startsWith(substring prefix) {
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
	public substring substr(int first) {
		return this.substr(first, _length);
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
	public substring substr(int first, int last) {
		return substring(_data + first, last - first);
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
	
	public substring trim() {
		if (_data == null)
			return substring();
		for (int i = 0; i < _length; i++) {
			if (!_data[i].isSpace()) {
				for (int j = _length - 1; j > i; j--) {
					if (!_data[j].isSpace())
						return substring(_data + i, 1 + (j - i));
				}
				return substring(_data, 1);
			}
		}
		return substring(&""[0], 0);
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
	string, boolean unescapeParasol() {
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

public class substring16 {
	pointer<char> _data;
	int _length;

	public substring16() {
	}

	public substring16(string16 source) {
		if (source != null) {
			_data = source.c_str();
			_length = source.length();
		}
	}

	public substring16(pointer<char> data, int length) {
		_data = data;
		_length = length;
	}

	public pointer<char> c_str() {
		return _data;
	}

	public int compare(ref<substring16> other) {
		assert(other != null);
		if (_data == null) {
			if (other._data == null)
				return 0;
			else
				return -1;
		} else if (other._data == null)
			return 1;
		if (_length < other._length) {
			for (int i = 0; i < _length; i++) {
				if (_data[i] != other._data[i])
					return _data[i] < other._data[i] ? -1 : 1;
			}
			return -1;
		} else {
			for (int i = 0; i < other._length; i++) {
				if (_data[i] != other._data[i])
					return _data[i] < other._data[i] ? -1 : 1;
			}
			if (_length > other._length)
				return 1;
			else
				return 0;
		}
	}

	public int compare(string16 other) {
		if (_data == null) {
			if (other == null)
				return 0;
			else
				return -1;
		} else if (other == null)
			return 1;
		pointer<char> ocp = other.c_str();
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

	public int compare(string other) {
		return compare(string16(other));
	}	
	public boolean isNull() {
		return _data == null;
	}

	public int length() {
		if (_data != null)
			return _length;
		else
			return 0;
	}
	
	public void set(int index, char value) {
		_data[index] = value;
	}
}

public class SubstringReader extends Reader {
	private ref<substring> _source;
	private int _cursor;
	
	public SubstringReader(ref<substring> source) {
		_source = source;
	}
	
	public int _read() {
		if (_cursor >= _source.length())
			return -1;
		else
			return (*_source).get(_cursor++);
	}

	public void unread() {
		if (_cursor > 0)
			--_cursor;
	}

	public boolean hasLength() {
		return true;
	}

	public long length() {
		return _source.length() - _cursor;
	}

	public void reset() {
		_cursor = 0;
	}
}

public class SubstringWriter extends Writer {
	private ref<substring> _output;
	private int _index;
	
	public SubstringWriter(ref<substring> output) {
		_output = output;
	}
	
	public void _write(byte c) {
		if (_index < _output.length())
			_output.set(_index++, c);
		else
			throw IllegalOperationException("overflow");
	}
}

public class Substring16Reader extends Reader {
	private ref<substring16> _source;
	private int _cursor;

	public Substring16Reader(ref<substring16> source) {
		_source = source;
	}

	public int _read() {
		if (_cursor >= _source.length() * char.bytes)
			return -1;
		else
			return pointer<byte>(_source.c_str())[_cursor++];
	}

	public void unread() {
		if (_cursor > 0)
			--_cursor;
	}

	public boolean hasLength() {
		return true;
	}

	public long length() {
		return _source.length() * char.bytes - _cursor;
	}

	public void reset() {
		_cursor = 0;
	}
}

public class Substring16Writer extends Writer {
	private short _lo;
	private ref<substring16> _output;
	private int _index;
	
	public Substring16Writer(ref<substring16> output) {
		_output = output;
		_lo = short.MIN_VALUE;
	}
	
	public void _write(byte c) {
		if (_lo >= 0) {
			if (_index < _output.length())
				_output.set(_index++, char(_lo | (int(c) << 8)));
			else
				throw IllegalOperationException("overflow");
			_lo = short.MIN_VALUE;
		} else
			_lo = c;
	}
}

