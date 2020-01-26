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
 * Modifying the contents of the string through this object, other substrings or the original
 * object will be reflected as all share common byte storage for the characters of the string.
 *
 * Once defined, you may modify individual bytes in a substring. You may not modify the length
 * of the substring. You may construct a new substring from an existing one.
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
	 * @param source The string that this substring will describe. 
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
	/**
	 * Fetch a pointer to the first byte in the substring.
	 *
	 * @return The address of the first byte of the substring, or null
	 * if the substring compares equal to null.
	 */
	public pointer<byte> c_str() {
		return _data;
	}
	/**
	 * Center the string.
	 *
	 * If the string has more characters than the size parameter, a copy of the
	 * string is returned.
	 *
	 * It is important to note that this is at best a rough scheme for centering
	 * text that is only suitable for fixed-width fonts and will not accurately
	 * reflect certain combining forms and special characters.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The existing string is scanned to count the number of Unicode characters
	 * encoded in the string using UTF-8. If the string is not valid UTF-8, the
	 * count will be unreliable.
	 *
	 * @param size The size in characters to fill with space characters (0x20).
	 *
	 * @return The string centered inside space characters.
	 */
	public string center(int size) {
		return center(size, ' ');
	}
	/**
	 * Center the string.
	 *
	 * If the string has more characters than the size parameter, a copy of the
	 * string is returned.
	 *
	 * It is important to note that this is at best a rough scheme for centering
	 * text that is only suitable for fixed-width fonts and will not accurately
	 * reflect certain combining forms and special characters.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The existing string is scanned to count the number of Unicode characters
	 * encoded in the string using UTF-8. If the string is not valid UTF-8, the
	 * count will be unreliable.
	 *
	 * @param size The size in characters to fill with space characters (0x20).
	 * @param pad The Unicode character to use on each end to pad short strings..

	 * @return The string centered inside space characters.
	 */
	public string center(int size, char pad) {
		SubstringReader r(this);
		UTF8Decoder d(&r);

		int characters = d.count();

		int margin = size - characters;
		if (margin <= 0)
			return string(*this);
		string result = "";
		int half = margin / 2;
		for (int i = 0; i < half; i++, margin--)
			result.append(pad);
		result.append(*this);
		for (int i = 0; i < margin; i++)
			result.append(pad);
		return result;
	}
	/**
	 * Reset the substring to the null value.
	 */
	public void clear() {
		_data = null;
		_length = 0;
	}
	/**
	 * This function implements substring compares for the equality and relational operators.
	 *
	 * The function carries out a byte-by-byte comparison of the strings. The null value is equal to
	 * null and less than any other string value. If two strings are of different lengths and all of the
	 * bytes of the shorter string match the initial bytes of the longer, then the longer string is
	 * greater.
	 *
	 * In usage as operators, the left hand operand is the object and the right-hand operand 
	 * is passed as the argument value.
	 *
	 * @param other The string value to compare this string to.
	 *
	 * @return A negative value if this string is less than the other, zero if they are equal or
	 * a positive value if this string is greater than the other.
	 */
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
	/**
	 * Compare this to a string.
	 *
	 * This method does a byte-by-byte compare to the string's contents
	 * exactly as if the argument were first converted to a substring.
	 *
	 * @param other The string to compare this with.
	 *
	 * @return <0 if this string is less than the other, 0 if they are equal
	 * and >0 if this string is greater than the other string.
	 */
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
	/**
	 * Compare two strings, ignoring differences in lower and upper-case letters.
	 *
	 * @param other The string value to compare this string to.
	 *
	 * @return A negative value if this string is less than the other, zero if they are equal or
	 * a positive value if this string is greater than the other.
	 *
	 * @exception IllegalOperationException Thrown always. This function is not yet implemented
	 * and calling will fail. 
	 */
	public int compareIgnoreCase(substring other) {
		throw IllegalOperationException("not yet implemented");
		return 0;
	}

	pointer<byte> elementAddress(int i) {
		if (_data != null)
			return _data + i;
		else
			throw IllegalOperationException(string(i));
	}
	/**
	 *
	 * @exception IllegalOperationException Thrown always. This function is not yet implemented
	 * and calling will fail. 
	 */
	public string encrypt(string salt) {
		throw IllegalOperationException("not yet implemented");
		return string(*this);
	}
	/**
	 * Determine whether a string ends with the given suffix.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The comparison is done byte-by-byte, so if the suffix string begins in the middle
	 * of a multi-byte sequence, this method will return true for any multi-byte sequence
	 * that ends with the suffix.
	 *
	 * @param suffix The suffix string to look for.
	 *
	 * @return true if this string ends with the bytes of the suffix. The method returns false if
	 * the suffix is longer than this string. The method returns true for any value of this string
	 * if the suffix is either null or the empty string,.
	 */
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
	/**
	 * Compare two strings, ignoring differences in lower and upper-case letters.
	 *
	 * @param other The string value to compare this string to.
	 *
	 * @return true if the only differences between the strings is the case of letters, false
	 * otherwise. A null string is still equal to another null string.
	 *
	 * @exception IllegalOperationException Thrown always. This function is not yet implemented
	 * and calling will fail. 
	 */
	public boolean equalIgnoreCase(string other) {
		throw IllegalOperationException("not yet implemented");
		return false;
	}
	/**
	 * Escape possibly non-printable characters using C escape syntax.
	 *
	 * Take the string and convert it to a form that, when
	 * wrapped with double-quotes would be a well-formed C
	 * string literal token with the same string value as 
	 * this object, but which consists exclusively of 7-bit
	 * ASCII characters.  All characters with a high-order bit
	 * set are converted to hex escape sequences with one or two digits
	 * each (e.g. \xff).
	 *
	 * Two consecutive question marks will escape the first to avoid trigraphs.
	 *
	 * Any character that requires a hex escape will also force the next
	 * character to be escaped if it happens to be a hexadecimal digit. This
	 * avoids confusing the C compiler about where the first hex escape ends.
	 * The primary application of this and related 'escape' functions is for
	 * machine-generated source code, where readabililty is of less concern
	 * than producing the correct compiled string literal value.
	 *  
	 * Note: Because apostrophes are also escaped, this can be used to escape C
	 * character constants as well as string literals.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Regardless of text encoding used in the string, or even if it is binary
	 * data, the resulting C string literal will produce the same sequence of
	 * bytes as are contained in this string.
	 *
	 * @return The escaped text.
	 */
	public string escapeC() {
		string output;

		if (length() == 0)
			return *this;
		boolean escapeNext;
		for (int i = 0; i < _length; i++) {
			if (escapeNext) {
				output.printf("\\x%x", _data[i] & 0xff);
				if (!_data[i + 1].isHexDigit())
					escapeNext = false;
			}
			switch (_data[i]) {
			case	'\\':	output.append("\\\\");	break;
			case	'\a':	output.append("\\a");	break;
			case	'\b':	output.append("\\b");	break;
			case	'\f':	output.append("\\f");	break;
			case	'\n':	output.append("\\n");	break;
			case	'\r':	output.append("\\r");	break;
			case	'\v':	output.append("\\v");	break;
			case	'\'':	output.append("\\'");	break;
			case	'"':	output.append("\\\"");	break;
			case	'?':
				if (_data[i + 1] == '?')
					output.append("\\x3f");
				else
					output.append('?');
				break;

			default:
				if (_data[i] >= 0x20 &&
					_data[i] < 0x7f)
					output.append(_data[i]);
				else {
					output.printf("\\x%x", _data[i] & 0xff);
					if (_data[i + 1].isHexDigit())
						escapeNext = true;
				}
			}
		}
		return output;
	}
	/**
	 * Escape possibly non-printable characters using JSON escape syntax.
	 *
	 * Take the string and convert it to a form that, when
	 * wrapped with double-quotes would be a well-formed JSON
	 * string literal token with the same string value as 
	 * this object.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Regardless of text encoding used in the string, or even if it is binary
	 * data, the resulting JSON string literal will produce the same sequence of
	 * bytes as are contained in this string.
	 *
	 * @return The escaped text.
	 */
	public string escapeJSON() {
		if (length() == 0)
			return string(*this);
		else
			return string(*this).escapeJSON();
	}
	/**
	 * Escape possibly non-printable characters using Parasol escape syntax.
	 *
	 * Take the string and convert it to a form that, when
	 * wrapped with double-quotes would be a well-formed Parasol
	 * string literal token with the same string value as 
	 * this object.
	 *
	 * Note: Because apostrophes are also escaped, this can be used to escape Parasol
	 * character constants as well.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Regardless of text encoding used in the string, or even if it is binary
	 * data, the resulting Parasol string literal will produce the same sequence of
	 * bytes as are contained in this string.
	 *
	 * @return The escaped text.
	 */
	public string escapeParasol() {
		string output;

		if (length() == 0)
			return *this;
		boolean escapeNext;
		for (int i = 0; i < _length; i++) {
			if (escapeNext) {
				output.printf("\\x%x", _data[i] & 0xff);
				if (!_data[i + 1].isHexDigit())
					escapeNext = false;
			}
			switch (_data[i]) {
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
				if (_data[i] >= 0x20 &&
					_data[i] < 0x7f)
					output.append(_data[i]);
				else {
					output.printf("\\x%x", _data[i] & 0xff);
					if (_data[i + 1].isHexDigit())
						escapeNext = true;
				}
			}
		}
		return output;
	}
	/**
	 * Escape characters using Shell escape syntax.
	 *
	 * Process the contents of the string so that, when quoted on a UNIX or
	 * Linux shell command-line, the string will be processed as a single 
	 * command-line parameter with the same value as the contents of this string.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Regardless of text encoding used in the string, or even if it is binary
	 * data, the resulting Parasol string literal will produce the same sequence of
	 * bytes as are contained in this string.
	 *
	 * @return The escaped text.
	 */
	public string escapeShell() {
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
	/**
	 * Get the byte at a position within the substring.
	 *
	 * @param index The index of the byte to get.
	 *
	 * @return The value of the byte at position {@code index}.
	 */
	public char get(int index) {
		return _data[index];
	}
	/**
	 * Calculate a 32-bit hash of the string value.
	 *
	 * This hash is used in arrays indexed by string type as well as in {@link parasol:types.map map}
	 * objects whose key type is string.
	 *
	 * @return A pseudo-random value derived from the contents of the string.
	 */	
	public int hash() {
		if (_data == null)
			return 0;
		if (_length == 1)
			return _data[0];
		else {
			int sum = 0;
			for (int i = 0; i < _length; i++)
				sum += _data[i] << (i & 0x1f);
			return sum;
		}
	}
	/**
	 * Find the first instance of a byte value.
	 *
	 * Returns the index of the first occurrance of the byte c
	 * in the string.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * If you want to search for a multi-byte Unicode value, you
	 * will need to pass the sought-after value as a string.
	 *
	 * @param c The byte to search for.
	 *
	 * @return The index of the first occurrance of c in the string, or
	 * -1 if the byte does not appear in the string.
	 */
	public int indexOf(byte c) {
		return indexOf(c, 0);
	}
	/**
	 * Find the first instance of a sub-string.
	 *
	 * Returns the index of the first occurrance of the sub-string s
	 * in this string.
	 *
	 * @param s The value to search for.
	 *
	 * @return The index of the first occurrance of s in the string, or
	 * -1 if the sub-string does not appear in the string.
	 */
	public int indexOf(string s) {
		return indexOf(s, 0);
	}
	/**
	 * Find the first instance, after a starting point, of a byte value.
	 *
	 * Returns the index of the first occurrance of the byte c
	 * in the string after the start index, inclusive.
	 *
	 * If you want to search for a multi-byte Unicode value, you
	 * will need to pass the sought-after value as a string.
	 *
	 * @param c The byte to search for.
	 * @param start The index of this string at which to start searching.
	 *
	 * @return The index of the first occurrance of c in the string after
	 * start, or -1 if the byte does not appear in the string after start.
	 *
	 * @exception IllegalArgumentException Thrown if the index is less than zero or
	 * greater than the length of the string.
	 */
	public int indexOf(byte c, int start) {
		int len = length();
		if (start < 0 || start > len)
			throw IllegalArgumentException(string(start));
		if (_data == null)
			return -1;
		for (int i = start; i < len; i++)
			if (_data[i] == c)
				return i;
		return -1;
	}
	/**
	 * Find the first instance, after a starting point, of a sub-string.
	 *
	 * Returns the index of the first occurrance of the sub-string s
	 * in the string after the start index, inclusive.
	 *
	 * @param s The value to search for.
	 * @param start The index of this string at which to start searching.
	 *
	 * @return The index of the first occurrance of s in the string after
	 * start, or -1 if the sub-string does not appear in the string after start.
	 *
	 * @exception IllegalArgumentException Thrown if the index is less than zero or
	 * greater than the length of the string.
	 */
	public int indexOf(string s, int start) {
		int len = length();
		if (start < 0 || start > len)
			throw IllegalArgumentException(string(start));
		if (_data == null)
			return -1;
		int tries =  1 + len - s.length() - start;
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
	/**
	 * Return whether this substirng is null.
	 *
	 * @return true if the substring value is null, false otherwise.
	 */
	public boolean isNull() {
		return _data == null;
	}
	/**
	 * Find the last instance of a byte value.
	 *
	 * Returns the index of the last occurrance of the byte c
	 * in the string.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * If you want to search for a multi-byte Unicode value, you
	 * will need to pass the sought-after value as a string.
	 *
	 * @param c The byte to search for.
	 *
	 * @return The index of the last occarrance of c in the string, or
	 * -1 if the byte does not appear in the string.
	 */
	public int lastIndexOf(byte c) {
		if (_data != null) {
			for (int i = _length - 1; i >= 0; i--)
				if (_data[i] == c)
					return i;
		}
		return -1;
	}
	/**
	 * Get the length of the ubstring.
	 *
	 * @return the length of the substring in bytes, or 0 if the value is null.
	 */
	public int length() {
		if (_data != null)
			return _length;
		else
			return 0;
	}
	/**
	 * Set the value of a byte in the string.
	 *
	 * @param index The index of the byte to set.
	 * @param value The new value to set.
	 *
	 * @exception IllegalArgumentException Thrown if the start is less than zero or
	 * greater than or equal to the length of the string.
	 */
	public void set(int index, byte value) {
		if (index < 0 || index > length())
			throw IllegalArgumentException(string(index));
		_data[index] = value;
	}
	/**
	 * Split a string into parts.
	 *
	 * Splits a string into one or more sub-strings and
	 * stores them in the output vector. If no instances of the
	 * delimiter character are present, then the vector is
	 * filled with a single element that is the entire
	 * string. The output vector always has as many elements
	 * as the number of delimiters in the input string plus one.
	 * The delimiter characters are not included in the output.
	 *
	 * If two or more delimiters are adjacent, then the intervening
	 * element of the output is the empty string.
	 *
	 * @param delimiter The delimiter byte to split the string.
	 *
	 * @return An array of one or more strings that are the delimited
	 * parts of the original.
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
	/**
	 * Match a prefix.
	 *
	 * Both the prefix value null and the empty string match all possible strings, except
	 * null.
	 *
	 * @param prefix The prefix string to look for.
	 *
 	 * @return true if the initiall bytes of the string match, byte-for-byte, the prefix,
	 * false otherwise.
	 */
	public boolean startsWith(substring prefix) {
		if (_data == null)
			return false;
		// If the prefix is longer, it can't match
		if (_length < prefix.length())
			return false;
		// Check the first N bytes (N = the length of the shorter, the prefix).
		for (int i = 0; i < prefix._length; i++) {
			if (_data[i] != prefix[i])
				return false;
		}
		return true;
	}
	/**
	 * Identify a sub-string of this string.	
	 *
	 * @param first The first character position of the sub-string.
	 *
	 * @return a substring of this string, starting at the character
	 * given by first and continuing to the end of the string.
	 *
	 * @exception IllegalArgumentException Thrown if the first is less than zero or
	 * greater than the length of the string.
	 */
	public substring substr(int first) {
		if (first < 0 || first > length())
			throw IllegalArgumentException("first " + first);
		return this.substr(first, _length);
	}
	/**
	 * Identify a sub-string of this string.
	 *
	 * Return a substring of this string, starting at the character
	 * given by first and continuing to (but not including) the
	 * character given by last.
	 *
	 * @exception IllegalArgumentException Thrown if the first is less than zero or
	 * greater than the length of the string, if the last is less than the first or
	 * greater than the length of the string.
	 */
	public substring substr(int first, int last) {
		if (first < 0 || first > length())
			throw IllegalArgumentException("first " + first);
		if (last < first || last > length())
			throw IllegalArgumentException("last " + last);
		return substring(_data + first, last - first);
	}
	/**
	 * Convert the string to lower case.
	 *
	 * This conversion only applies to the ASCII letters, not to all Unicode 
	 * characters. Any byte that is not an upper-case ASCII letter is unchanged.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Converting upper-case to lower-case letters across all Unicode characters
	 * is complex and this method does not try to do that. 
	 *
	 * @return The string with all upper-case ASCII letter converted to lower-case.
	 * The null value is returned as null.
	 */
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
	/**
	 * Convert the string to upper case.
	 *
	 * This conversion only applies to the ASCII letters, not to all Unicode 
	 * characters. Any byte that is not a lower-case ASCII letter is unchanged.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Converting lower-case to upper-case letters across all Unicode characters
	 * is complex and this method does not try to do that. 
	 *
	 * @return The string with all lower-case ASCII letter converted to upper-case.
	 * The null value is returned as null.
	 */
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
	/**
	 * Trim white-space from the ends of a string.
	 *
	 * Any byte for which the {@link byte.isSpace} method returns true
	 * is considered white space. White space in the interior of the string
	 * is retained, but any number of white space characters at either end of
	 * the string is removed.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * There are a number of Unicode characters beyond the ASCII range that
	 * are alternative white space. They are not recognized and are not trimmed.
	 *
	 * @return The string with any ASCII white space bytes at either end
	 * of the string removed. The null value is returned as null.
	 */
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
	/**
	 * Un-escape a text string according to the C string literal syntax
	 *
	 * Process the input string as if it were a C string literal.
	 *
	 * Escape sequences are:
	 *
	 * <table>
	 *		<tr><td>\\a</td><td>audible bell</td></tr>
	 *		<tr><td>\\b</td><td>backspace</td></tr>
	 *		<tr><td>\\f</td><td>form-feed</td></tr>
	 *		<tr><td>\\n</td><td>newline</td></tr>
	 *		<tr><td>\\r</td><td>carriage return</td></tr>
	 *		<tr><td>\\t</td><td>tab</td></tr>
	 *		<tr><td>\\v</td><td>vertical tab</td></tr>
	 *		<tr><td>\\?</td><td>question mark</td></tr>
	 *		<tr><td>\\xH</td><td>hex escape</td></tr>
	 *		<tr><td>\\0DDD</td><td>octal escape</td></tr>
	 *		<tr><td>\\\\</td><td>\\</td></tr>
	 * </table>
	 *
	 * @return The converted string, or an unspecified value if the second return expression is false.
	 * @return true if the string could be unescaped (the string conforms to C literal syntax), false
	 * otherwise.
	 */
	public string, boolean unescapeC() {
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
					case '?':	output.append('?');		break;
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
	/**
	 * Un-escape a text string according to JSON string literal syntax
	 *
	 * Process the input string as if it were a JSON string literal.
	 * Escape sequences are:
	 *
	 * <table>
	 *		<tr><td>\\b</td><td>backspace</td></tr>
	 *		<tr><td>\\f</td><td>form-feed</td></tr>
	 *		<tr><td>\\n</td><td>newline</td></tr>
	 *		<tr><td>\\r</td><td>carriage return</td></tr>
	 *		<tr><td>\\t</td><td>tab</td></tr>
	 *		<tr><td>\\uNNNN</td><td>Unicode code point</td></tr>
	 *		<tr><td>\\\\</td><td>\\</td></tr>
	 *		<tr><td>\\/</td><td>/</td></tr>
	 *		<tr><td>\\"</td><td>"</td></tr>
	 * </table>
	 *
	 * @return The converted string, or an unspecified value if the second return expression is false.
	 * @return true if the string could be unescaped (the string conforms to JSON syntax), false
	 * otherwise.
	 */
	public string, boolean unescapeJSON() {
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
	/**
	 * Un-escape a text string according to Parasol string literal syntax
	 *
	 * Process the input string as if it were a Parasol string literal.
	 * Escape sequences are:
	 *
	 * <table>
	 *		<tr><td>\\a</td><td>audible bell</td></tr>
	 *		<tr><td>\\b</td><td>backspace</td></tr>
	 *		<tr><td>\\f</td><td>form-feed</td></tr>
	 *		<tr><td>\\n</td><td>newline</td></tr>
	 *		<tr><td>\\r</td><td>carriage return</td></tr>
	 *		<tr><td>\\t</td><td>tab</td></tr>
	 *		<tr><td>\\uNNNN</td><td>Unicode code point</td></tr>
	 *		<tr><td>\\v</td><td>vertical tab</td></tr>
	 *		<tr><td>\\xHH</td><td>hex escape</td></tr>
	 *		<tr><td>\\0DDD</td><td>octal escape</td></tr>
	 *		<tr><td>\\\\</td><td>\\</td></tr>
	 * </table>
	 *
	 * @return The converted string, or an unspecified value if the second return expression is false.
	 * @return true if the string could be unescaped (the string conforms to Parasol syntax), false
	 * otherwise.
	 */
	public string, boolean unescapeParasol() {
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
/**
 * This class implements a read-only sub-string of a string object.
 *
 * A substring relies on some region of memory that must remain alive for the lifetime
 * of this substring. If the substring is set to be part or all of a string16 or char array,
 * the underlying string or array cannot change size, be deleted or go out of scope.
 * Modifying the contents of the string through this object, other substring16s or the original
 * object will be reflected as all share common char storage for the characters of the string.
 *
 * Once defined, you may modify individual char's in a substring16. You may not modify the length
 * of the substring16. You may construct a new substring16 from an existing one.
 *
 * While a number of methods assume UTF-16 text, a string16 is an array of char's. The
 * documentation of the individual methods indicate where UTF-16 encoding is assumed and
 * where other encodings will work.
 */
public class substring16 {
	pointer<char> _data;
	int _length;
	/**
	 * The default constructor.
	 *
	 * By default, the string value is null.
	 */
	public substring16() {
	}
	/**
	 * A constructor to make this substring a synonym for the argument string.
	 *
	 * @param source The string16 object that this substring16 will describe.
	 */
	public substring16(string16 source) {
		if (source != null) {
			_data = source.c_str();
			_length = source.length();
		}
	}
	/**
	 * A constructor from a range of char's.
	 *
	 * @param data The address of the first char of the substring.
	 * @param length The number of char's in the substring.
	 */
	public substring16(pointer<char> data, int length) {
		_data = data;
		_length = length;
	}
	/**
	 * Fetch a pointer to the first char in the substring.
	 *
	 * @return The address of the first char of the substring, or null
	 * if the substring compares equal to null.
	 */
	public pointer<char> c_str() {
		return _data;
	}
	/**
	 * This function implements substring16 compares for the equality and relational operators.
	 *
	 * The function carries out a char-by-char comparison of the strings. The null value is equal to
	 * null and less than any other string value. If two strings are of different lengths and all of the
	 * char's of the shorter string match the initial char's of the longer, then the longer string is
	 * greater.
	 *
	 * In usage as operators, the left hand operand is the object and the right-hand operand 
	 * is passed as the argument value.
	 *
	 * @param other The string value to compare this string to.
	 *
	 * @return A negative value if this string is less than the other, zero if they are equal or
	 * a positive value if this string is greater than the other.
	 */
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
	/**
	 * Compare this to a string.
	 *
	 * This method does a char-by-char compare to the string's contents
	 * exactly as if the argument were first converted to a substring16.
	 *
	 * @param other The string to compare this with.
	 *
	 * @return <0 if this string is less than the other, 0 if they are equal
	 * and >0 if this string is greater than the other string.
	 */
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
	/**
	 * Compare this to a string.
	 *
	 * This method does a char-by-char compare to the string's contents
	 * exactly as if the argument were first converted to a string16.
	 *
	 * @param other The string to compare this with.
	 *
	 * @return <0 if this string is less than the other, 0 if they are equal
	 * and >0 if this string is greater than the other string.
	 */
	public int compare(string other) {
		return compare(string16(other));
	}	

	pointer<char> elementAddress(int i) {
		if (_data != null)
			return _data + i;
		else
			throw IllegalOperationException(string(i));
	}
	/**
	 * Return whether this substirng is null.
	 *
	 * @return true if the substring value is null, false otherwise.
	 */
	public boolean isNull() {
		return _data == null;
	}
	/**
	 * Get the length of the ubstring.
	 *
	 * @return the length of the substring in char's, or 0 if the value is null.
	 */
	public int length() {
		if (_data != null)
			return _length;
		else
			return 0;
	}
	/**
	 * Set the value of a byte in the string.
	 *
	 * @param index The index of the byte to set.
	 * @param value The new value to set.
	 *
	 * @exception IllegalArgumentException Thrown if the start is less than zero or
	 * greater than or equal to the length of the string.
	 */
	public void set(int index, char value) {
		_data[index] = value;
	}
}
/**
 * A Reader for substring objects.
 *
 * A SubstringReader can report its length and can be reset.
 *
 * A SubstringReader can unread the entire substring at any point.
 */
public class SubstringReader extends Reader {
	private ref<substring> _source;
	private int _cursor;
	/**
	 * Constructor.
	 *
	 * The Reader is positioned at the beginning of the
	 * string and will report EOF when the last character
	 * of the string is read.
	 *
	 * @param source The string to read from.
	 */
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
/**
 * A Writer for substring objects.
 *
 * This Writer is initially positioned at the beginning of the
 * substring. If you write more bytes than the length of the
 * substring, the write operation throws an {@link IllegalOperationException}.
 *
 * Modifying the value of the substring in between write operations
 * can produce unexpected results.
 */
public class SubstringWriter extends Writer {
	private ref<substring> _output;
	private int _index;
	/**
	 * Constructor.
	 *
	 * @param output A reference to the substring object to populate.
	 */
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
/**
 * A Reader for substring16 objects.
 *
 * A SubstringReader can report its length and can be reset.
 *
 * A SubstringReader can unread the entire substring16 at any point.
 */
public class Substring16Reader extends Reader {
	private ref<substring16> _source;
	private int _cursor;
	/**
	 * Constructor.
	 *
	 * The Reader is positioned at the beginning of the
	 * string and will report EOF when the last character
	 * of the string is read.
	 *
	 * @param source The string to read from.
	 */
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
/**
 * A Writer for substring objects.
 *
 * This Writer is initially positioned at the beginning of the
 * substring. If you write more bytes than the length of the
 * substring, the write operation throws an {@link IllegalOperationException}.
 *
 * Modifying the value of the substring in between write operations
 * can produce unexpected results.
 *
 * The first byte of a char is written to a buffer in the Writer
 * object and does not affect the value of the underlying string. 
 * Only when the second byte of the char is written will the underlying
 * string be modified. Use care when mixing write's through this
 * Writer and other manipulations of the underlying string to ensure
 * that correct text is properly written.
 */
public class Substring16Writer extends Writer {
	private short _lo;
	private ref<substring16> _output;
	private int _index;
	/**
	 * Constructor.
	 *
	 * @param output A reference to the substring16 object to populate.
	 */
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

