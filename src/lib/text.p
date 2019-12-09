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
 * Provides facilities for manipulating strings of text.
 *
 * Parasol provides robust facilities for manipulating text data. These facilities
 * are designed for general purpose use and may not be suitable for applications
 * that need to store and process large volumes of text in complex ways. Nevertheless,
 * Parasol's objects can be used to write efficient code for a broad class of applications.
 *
 * The Parasol text namespace includes two primary and two secondary classes that are most
 * useful for representing strings of Unicode text.
 *
 * The primary classes are:
 *
 * <ul>
 *     <li>{@link string}: Represents a sequence of Unicode characters stored in UTF-8.
 *     <li>{@link string16}: Represents a sequence of Unicode characters stored in UTF-16.
 * </ul>
 *
 * The secondary classes are:
 *
 * <ul>
 *     <li>{@link substring}: Represents a sub-sequence of Unicode characters stored in UTF-8.
 *     <li>{@link substring16}: Represents a sub-sequence of Unicode characters stored in UTF-16.
 * </ul>
 *
 * Each of the above 'sub' classes is constructed from an instance of the corresponding primary
 * classes. For example, a substring instance is a portion of a string object's contents. Operations on
 * substring's provide relatively light-weight ways to search and select ranges of larger string objects.
 *
 * All four classes represent sequences of Unicode characters, so there is no notion of 'width' that
 * affects the conversion of numeric types, for example. As far as operations like copying or string
 * addition, all four types can be readily converted without loss of information. Any of the four classes
 * can coerce to any of the other four. Converting to either of the primary string classes will involve
 * copying text and may require a conversion between UTF-8 and UTF-16.
 *
 * This namespace provides full support for two encodings: UTF-8 and UTF-16 for textual data. One additional
 * encoding, ISO 8859-1, can be safely stored in a string, but is not fully supported. Several of the 
 * methods that construct, extend or modify string objects are agnostic and will function correctly
 * regardless of the encoding actually present in the bytes or chars of the string. You should be aware 
 * of the sources of your text data before you apply functions or methods that do explicitly depend on
 * text having a specific encoding. The individual methods will indicate whether they depend on having correct
 * Unicode text stored in their operands. Obviously, conversion between UTF-8 and UTF-16 encodings will
 * result in unpredictable and probably garbled results if the source string does not contain valid Unicode
 * text.
 */
namespace parasol:text;

import native:C;
import parasol:memory;
import parasol:stream;
import parasol:stream.EOF;
import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;

private class substringClass = substring;

/**
 * This is the preferred representation for text in Parasol.
 *
 */
public class string extends String<byte> {
	//** DO NOT MOVE THIS ** THIS MUST BE THE FIRST CONSTRUCTOR ** THE COMPILER RELIES ON THIS PLACEMENT **//
	/*
	 * This constructor is used in certain special cases where the compiler can determine that the current string object
	 * can simply take ownership of whatever content the source string is (and avoid a copy of the contents).
	 */
	private string(ref<allocation> other) {
		_contents = other;
	}
	//** DO NOT MOVE THIS ** THIS MUST BE THE FIRST CONSTRUCTOR ** THE COMPILER RELIES ON THIS PLACEMENT **//
	
	// The special 'stringAllocationConstructor' allocation class has to be in the string class.
	// TODO: fix this
	protected class allocationX {
		public int length;
		public byte data;
	}
	// TODO: remove this when the compiler is looking for 
	private string(ref<allocationX> other) {
		_contents = ref<allocation>(other);
	}
	/**
	 * The default constructor.
	 *
	 * By default, the string value is null.
	 */
	public string() {
	}
	/**
	 * A copy constructor.
	 *
	 * The contents of the source string are copied. If source is
	 * null, the newly constructed string is null as well.
	 *
	 * @param source An existing string.
	 */
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

	public string(substringClass source) {
		if (source._data != null) {
			resize(source._length);
			C.memcpy(&_contents.data, source._data, source._length);
		}
	}

	public string(substringClass source, int startOffset) {
		if (source._data != null) {
			resize(source._length - startOffset);
			C.memcpy(&_contents.data, source._data + startOffset, source._length - startOffset);
		}
	}

	public string(substringClass source, int startOffset, int endOffset) {
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
	
	public string(byte[] value, int startAt) {
		if (startAt < 0)
			throw IllegalArgumentException(string(startAt));
		if (startAt >= value.length()) {
			resize(0);
			return;
		}
		resize(value.length() - startAt);
		C.memcpy(&_contents.data, &value[startAt], length());
	}
	
	public string(byte[] value, int startAt, int endAt) {
		if (startAt < 0 || endAt < 0)
			throw IllegalArgumentException(string(startAt));
		if (endAt > value.length())
			endAt = value.length();
		if (startAt >= endAt) {
			resize(0);
			return;
		}
		resize(endAt - startAt);
		C.memcpy(&_contents.data, &value[startAt], length());
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
	
	public string(boolean b) {
		if (b)
			append("true");
		else
			append("false");
	}

	public string(string16 other) {
		if (other.isNull())
			return;
		resize(0);				// This makes the value != null (i.e. the empty string), if other is the empty string

		StringWriter w(this);
		UTF8Encoder ue(&w);

		ue.encode(other);
	}

	public string(substring16 other) {
		if (other.isNull())
			return;
		resize(0);				// This makes the value != null (i.e. the empty string), if other is the empty string

		StringWriter w(this);
		UTF8Encoder ue(&w);

		ue.encode(other);
	}

	public string(pointer<char> buffer, int len) {
		if (buffer == null)
			return;

		stream.BufferReader r(buffer, len * char.bytes);
		UTF16Decoder ud(&r);

		string s = ud.decode();
		_contents = s._contents;
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
	/**
	 * Open a Reader from the contents of the string.
	 *
	 * If you modify a string while a Reader is open to the string,
	 * the Reader will not produce any exceptions. Each read operation
	 * takes the contents of the string at the moment it is being read.
	 * If a string is shortened to a length less than the current read
	 * position of the Reader, the next read operation will return end-of-file.
	 *
	 * Reading from a string's Reader after the string's lifetime produces
	 * undefined behavior.
	 * 
	 * @return A Reader positioned at the beginning of the current contents of the
	 * string.
	 */
	public ref<Reader> openReader() {
		return new StringReader(this);
	}
	/**
	 * Open a Writer to the string.
	 *
	 * Any write operations through the Writer will be appended to the string.
	 * Other modifications of any kind can take place and the next write operation
	 * will append its data to the contents at the time of the write.
	 *
	 * Writing through a string's Writer after the string's lifetime produces
	 * undefined behavior.
	 *
	 * @return a Writer positioned at the end of the current contents of
	 * the sring.
	 */
	public ref<Writer> openWriter() {
		return new StringWriter(this);
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
	
	public void append(substringClass other) {
		if (other._length > 0) {
			int oldLength = length();
			resize(oldLength + other._length);
			C.memcpy(pointer<byte>(&_contents.data) + oldLength, other._data, other._length);
		}
	}

	public void append(pointer<char> cp, int length) {
		stream.BufferReader r(cp, length * char.bytes);
		UTF16Decoder ud(&r);
		StringWriter w(this);
		UTF8Encoder ue(&w);

		for (;;) {
			int c = ud.decodeNext();
			if (c == EOF)
				break;
			ue.encode(c);
		}
	}
	/**
	 * Append a Unicode character.
	 *
	 * If the argument value is not a valid Unicode code point, the 
	 * {@link REPLACEMENT_CHARACTER) is stored instead.
	 *
	 * @param ch The character to append.
	 */
	public void append(int ch) {
		if (ch <= 0x7f)
			append(byte(ch));
		else if (ch <= 0x7ff) {
			append(byte(0xc0 + (ch >> 6)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0xffff) {
			if (ch < SURROGATE_START ||
				ch > SURROGATE_END) {
				append(byte(0xe0 + (ch >> 12)));
				append(byte(0x80 + ((ch >> 6) & 0x3f)));
				append(byte(0x80 + (ch & 0x3f)));
			} else
				append(REPLACEMENT_CHARACTER);
		} else if (ch <= 0x10ffff) {
			append(byte(0xf0 + (ch >> 18)));
			append(byte(0x80 + ((ch >> 12) & 0x3f)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		} else {
			append(REPLACEMENT_CHARACTER);
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
	public string escapeJSON() {
		String<byte> s = escapeJSON_T();

		return *ref<string>(&s);
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
		else {
			int sum = 0;
			for (int i = 0; i < _contents.length; i++)
				sum += pointer<byte>(&_contents.data)[i] << (i & 0x1f);
			return sum;
//			return pointer<byte>(&_contents.data)[0] + (pointer<byte>(&_contents.data)[_contents.length - 1] << 7);
		}
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
		for (int i = 0; i < tries; i++){
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
		for (int i = 0; i < tries; i++){
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

	public int printf(string format, var... arguments) {
		StringWriter w(this);
		return w.printf(format, arguments);
	}

	public string remove(RegularExpression pattern) {
		return null;
	}
	/**
 	 * Replaces each instance of the match string with the replacement.
	 *
	 * @param match The sub-string to look for.
	 * @param replacement The text to substitute for each matching sub-string.
	 *
	 * @return The original string with each instance of match replacemby replacement.
	 */
	public string replaceAll(string match, string replacement) {
		string result;

		int start = 0;
		for (;;) {
			int idx = indexOf(match, start);
			if (idx < 0) {
				result.append(substring(start));
				break;
			} else {
				result.append(substring(start, idx));
				result.append(replacement);
				start = idx + match.length();
			}
		}
		return result;
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
	/**
	 * Matches a prefix byte against the target string.
	 *
	 * @param prefix The byte to match against the first byte of the string.
	 *
	 * @return true if the first byte of the string is the prefix. If the string is empty, null or has any
	 * other value in the first byte, the return value is false.
	 */
	public boolean startsWith(byte prefix) {
		if (length() <= 0)
			return false;
		return _contents.data == prefix;
	}

	public boolean startsWith(substringClass prefix) {
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
		
		if (first == last)
			return "";
		if (first > last || first > length())
			throw IllegalArgumentException("substring");
		if (last > length())
			last = length();
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

	string, boolean unescapeParasol() {
		String<byte> result;
		boolean success;

		(result, success) = super.unescapeParasolT();
		// This makes some big assumptions about the relationship between the base template class
		// and the derived class, but if the language runtime can't know about the intricacies of
		// its own implementation, who can?
		return *ref<string>(&result), success;
	}
	// TODO: Remove this when cast from string -> String<byte> works.
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
}

public class string16 extends String<char> {
	//** DO NOT MOVE THIS ** THIS MUST BE THE FIRST CONSTRUCTOR ** THE COMPILER RELIES ON THIS PLACEMENT **//
	/*
	 * This constructor is used in certain special cases where the compiler can determine that the current string object
	 * can simply take ownership of whatever content the source string is (and avoid a copy of the contents).
	 */
	private string16(ref<allocation> other) {
		_contents = other;
	}
	//** DO NOT MOVE THIS ** THIS MUST BE THE FIRST CONSTRUCTOR ** THE COMPILER RELIES ON THIS PLACEMENT **//

	public string16() {
	}

	public string16(string other) {
		if (other == null)
			return;
		resize(0);
		assert(_contents != null);
		String16Writer w(this);
		UTF16Encoder u16(&w);

		u16.encode(other);
	}

	public string16(substringClass other) {
		if (other.isNull())
			return;
		resize(0);
		assert(_contents != null);
		String16Writer w(this);
		UTF16Encoder u16(&w);

		u16.encode(other);
	}

	public string16(substring16 other) {
		if (other.isNull())
			return;
		resize(0);
		assert(_contents != null);
		String16Writer w(this);
		UTF16Encoder u16(&w);

		u16.encode(other);
	}

	public string16(pointer<char> buffer, int len) {
		if (buffer != null) {
			resize(len);
			C.memcpy(&_contents.data, buffer, len * char.bytes);
		}
	}

	public int compare(string16 other) {
		if (_contents == null) {
			if (other._contents == null)
				return 0;
			else
				return -1;
		} else if (other._contents == null)
			return 1;
		pointer<char> cp = pointer<char>(&_contents.data);
		pointer<char> ocp = pointer<char>(&other._contents.data);
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
	
	public void copy(string16 other) {
		if (other._contents != null) {
			if (_contents == other._contents)
				return;
			resize(other._contents.length);
			C.memcpy(&_contents.data, &other._contents.data, (other._contents.length + 1) * char.bytes);
		} else {
			if (_contents != null) {
				memory.free(_contents);
				_contents = null;
			}
		}
	}

	public string16 escapeJSON() {
		String<char> s = escapeJSON_T();

		return *ref<string16>(&s);
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
	public string16 substring(int first) {
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
	public string16 substring(int first, int last) {
		string16 result;
		
		result.append(pointer<char>(&_contents.data) + first, last - first);
		return result;
	}
	/**
	 * Append a Unicode character.
	 *
	 * If the argument value is not a valid Unicode code point, the 
	 * {@link REPLACEMENT_CHARACTER) is stored instead.
	 *
	 * @param ch The character to append.
	 */
	public void append(int ch) {
		if (ch < SURROGATE_START)
			append(char(ch));
		else if (ch <= SURROGATE_END)
			append(REPLACEMENT_CHARACTER);
		else if (ch <= 0xffff)
			append(char(ch));
		else if (ch <= 0x10ffff) {
			ch -= 0x10000;
			append(char(HI_SURROGATE_START + (ch >> 10)));
			append(char(LO_SURROGATE_START + (ch & 0x3ff)));
		} else
			append(REPLACEMENT_CHARACTER);
	}
}

class String<class T> {
	protected class allocation {
		public int length;
		public T data;
	}

	protected static int MIN_SIZE = 0x10;

	protected ref<allocation> _contents;

	public void append(String<T> other) {
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
			C.memcpy(pointer<T>(&_contents.data) + oldLength, &other._contents.data, (len + 1) * T.bytes);
//			print("appended\n");
		}
//		print("=");
//		print(*this);
//		print("\n");
	}

	public void append(pointer<T> p, int length) {
		if (_contents == null) {
			resize(length);
			C.memcpy(&_contents.data, p, length * T.bytes);
		} else {
			int len = _contents.length;
			resize(len + length);
			C.memcpy(pointer<T>(&_contents.data) + len, p, length * T.bytes);
		}
		*(pointer<T>(&_contents.data) + _contents.length) = 0;
	}

	public void append(T b) {
		if (_contents == null) {
			resize(1);
			_contents.data = b;
		} else {
			int len = _contents.length;
			resize(len + 1);
			*(pointer<T>(&_contents.data) + len) = b;
		}
	}
	
	public pointer<T> c_str() {
		return pointer<T>(&_contents.data);
	}

	public void clear() {
		if (_contents != null) {
			memory.free(_contents);
			_contents = null;
		}
	}
	/*
	 *	escapeJSON
	 *
	 *	Take the string and convert it to a form, that when
	 *	wrapped with double-quotes would be a well-formed JSON
	 *	string literal token with the same string value as 
	 *	this object.
	 */
	String<T> escapeJSON_T() {
		String<T> output;

		if (length() == 0)
			return *this;
		pointer<T> cp = pointer<T>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			switch (cp[i]) {
			case	'\\':	output.append('\\');	output.append('\\');	break;
			case	'\b':	output.append('\\');	output.append('b');		break;
			case	'\f':	output.append('\\');	output.append('f');		break;
			case	'\n':	output.append('\\');	output.append('n');		break;
			case	'\r':	output.append('\\');	output.append('r');		break;
			case	'\t':	output.append('\\');	output.append('t');		break;
			case	'"':	output.append('\\');	output.append('"');		break;
			default:
				if (cp[i] < 0x20) {
					output.append('\\');
					output.append('u');
					int mask = 0xf000;
					int value = cp[i];
					int shift = 12;
					for (int i = 0; i < 4; i++, shift -= 4, mask >>= 4) {
						int nibble = (value & mask) >> shift;
						if (nibble <= 9)
							output.append(T('0' + nibble));
						else
							output.append(T('a' + nibble - 10));
					}
				} else
					output.append(cp[i]);
			}
		}
		return output;
	}

	public boolean isNull() {
		return _contents == null;
	}

	public int length() {
		if (_contents != null)
			return _contents.length;
		else
			return 0;
	}

	private long reservedSize(int length) {
		long usedSize = length + int.bytes + 1;
		if (usedSize > int.MAX_VALUE)
			// size overflow, indicates the new string length is too long
			throw memory.OutOfMemoryException(length);

		long allocSize = MIN_SIZE;
		while (allocSize < usedSize)
			allocSize <<= 1;
		return allocSize * T.bytes;
	}
	
	public void resize(int newLength) {
		long newSize = reservedSize(newLength);
		if (_contents != null) {
			if (_contents.length >= newLength) {
				_contents.length = newLength;
				*(pointer<T>(&_contents.data) + newLength) = 0;
				return;
			}
			long oldSize = reservedSize(_contents.length);
			if (oldSize == newSize) {
				_contents.length = newLength;
				*(pointer<T>(&_contents.data) + newLength) = 0;
				return;
			}
		}
		ref<allocation> a = ref<allocation>(memory.alloc(newSize));
		if (_contents != null) {
			C.memcpy(&a.data, &_contents.data, (_contents.length + 1) * T.bytes);
			memory.free(_contents);
		}
		a.length = newLength;
		*(pointer<T>(&a.data) + newLength) = 0;
		_contents = a;
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
	String<T>, boolean unescapeParasolT() {
		String<T> output;
		
		if (length() == 0)
			return *this, true;
		for (int i = 0; i < _contents.length; i++) {
			if (pointer<T>(&_contents.data)[i] == '\\') {
				if (i == _contents.length - 1)
					return output, false;
				else {
					int v;
					i++;
					switch (pointer<T>(&_contents.data)[i]) {
					case 'a':	output.append('\a');	break;
					case 'b':	output.append('\b');	break;
					case 'f':	output.append('\f');	break;
					case 'n':	output.append('\n');	break;
					case 'r':	output.append('\r');	break;
					case 't':	output.append('\t');	break;
					case 'v':	output.append('\v');	break;
					case 'u':
					case 'U':
						i++;;
						if (i >= _contents.length)
							return output, false;
						if (!pointer<T>(&_contents.data)[i].isHexDigit())
							return output, false;
						v = 0;
						do {
							v <<= 4;
							if (v > 0xff)
								return output, false;
							if (pointer<T>(&_contents.data)[i].isDigit())
								v += pointer<T>(&_contents.data)[i] - '0';
							else
								v += 10 + pointer<T>(&_contents.data)[i].toLowerCase() - 'a';
							i++;
						} while (i < _contents.length && pointer<T>(&_contents.data)[i].isHexDigit());
						if (T.bytes == byte.bytes)
							ref<string>(&output).append(v);			// emits UTF-8.
						else
							ref<string16>(&output).append(v);			// emits UTF-16.
						i--;
						break;
						
					case 'x':
					case 'X':
						i++;;
						if (i >= _contents.length)
							return output, false;
						if (!pointer<T>(&_contents.data)[i].isHexDigit())
							return output, false;
						v = 0;
						do {
							v <<= 4;
							if (v > 0xff)
								return output, false;
							if (pointer<T>(&_contents.data)[i].isDigit())
								v += pointer<T>(&_contents.data)[i] - '0';
							else
								v += 10 + pointer<T>(&_contents.data)[i].toLowerCase() - 'a';
							i++;
						} while (i < _contents.length && pointer<T>(&_contents.data)[i].isHexDigit());
						if (T.bytes == byte.bytes)
							ref<string>(&output).append(byte(v));			// emits UTF-8.
						else
							ref<string16>(&output).append(char(v));			// emits UTF-16.
						i--;
						break;
						
					case '0':
						i++;
						if (i >= _contents.length ||
							!pointer<T>(&_contents.data)[i].isOctalDigit()) {
							i--;
							output.append(T(0));
							break;
						}
						v = 0;
						do {
							v <<= 3;
							if (v > 0xff)
								return output, false;
							v += pointer<T>(&_contents.data)[i] - '0';
							i++;
						} while (i < _contents.length && pointer<T>(&_contents.data)[i].isOctalDigit());
						if (T.bytes == byte.bytes)
							ref<string>(&output).append(v);			// emits UTF-8.
						else
							ref<string16>(&output).append(v);			// emits UTF-16.
						break;
						
					default:
						output.append(pointer<T>(&_contents.data)[i]);
					}
				}
			} else
				output.append(pointer<T>(&_contents.data)[i]);
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

public class StringWriter extends Writer {
	private ref<string> _output;
	
	public StringWriter(ref<string> output) {
		_output = output;
	}
	
	public void _write(byte c) {
		_output.append(c);
	}
}

public class String16Reader extends Reader {
	private ref<string16> _source;
	private int _cursor;

	public String16Reader(ref<string16> source) {
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
		return _source.length() - _cursor;
	}

	public void reset() {
		_cursor = 0;
	}
}

public class String16Writer extends Writer {
	private short _lo;
	private ref<string16> _output;
	
	public String16Writer(ref<string16> output) {
		_output = output;
		_lo = short.MIN_VALUE;
	}
	
	public void _write(byte c) {
		if (_lo >= 0) {
			_output.append(char(_lo | (int(c) << 8)));
			_lo = short.MIN_VALUE;
		} else
			_lo = c;
	}
}
/**
 * Write a memory dump to stdout.
 *
 * This is a debugging function that is useful for examining
 * the contents of memory. The memory contents are displayed
 * in hexadecimal and as displayable ASCII characters. Each line
 * of output displays up to 16 bytes of memory and is labeled
 * with the memory address.
 *
 * If the memory address to be dumped is not a multiple of
 * sixteen, the first line of output with use the address
 * truncated to the nearest multiple of sixteen and white space
 * will fill the bytes that precede the first byte of data to be dumped.
 *
 * You may display the contents of an entire object with a call
 * like:
 *<pre>{@code
 *        memDump(&x, x.bytes);
 *}</pre>
 *
 * You can display all the elements of an array or string using
 * the following:
 *<pre>{@code
 *        T[] a;
 *
 *        memDump(&a[0], a.length() * T.bytes);
 *}</pre>
 * or
 *<pre>{@code
 *        string s;
 *
 *        memDump(&s[0], s.length());
 *}</pre>
 *
 * Supplying a length value larger than the object or array
 * being dumped produces undefined behavior.
 *
 * @param buffer The address of memory to dump.
 * @param length The number of bytes to dump.
 */
public void memDump(address buffer, long length) {
	memDump(buffer, length, long(buffer));
}
/**
 * Write a memory dump to stdout.
 *
 * This is a debugging function that is useful for examining
 * the contents of memory. The memory contents are displayed
 * in hexadecimal and as displayable ASCII characters. Each line
 * of output displays up to 16 bytes of memory and is labeled
 * with an offset. The startingOffset parameter can be useful 
 * in labelling dumped data. For example, if you want to compare
 * the contents of two large arrays, dumping them both with the
 * same starting offset allows you to use automated text comparison
 * without much effort.
 *
 * If the memory address to be dumped is not a multiple of
 * sixteen, the first line of output with use the address
 * truncated to the nearest multiple of sixteen and white space
 * will fill the bytes that precede the first byte of data to be dumped.
 * with the memory address. If the memory address to be dumped is not
 * a multiple of sixteen, the first line of output with use the
 * address truncated to the nearest multiple of sixteen and
 * white space will fill the bytes that precede the first byte
 * of data to be dumped.
 *
 * You may display the contents of an entire object with a call
 * like:
 *<pre>{@code
 *        memDump(&x, x.bytes, 0);
 *}</pre>
 *
 * You can display all the elements of an array or string using
 * the following:
 *<pre>{@code
 *        T[] a;
 *
 *        memDump(&a[0], a.length() * T.bytes, 0);
 *}</pre>
 * or
 *<pre>{@code
 *        string s;
 *
 *        memDump(&s[0], s.length(), 0);
 *}</pre>
 *
 * Supplying a length value larger than the object or array
 * being dumped produces undefined behavior.
 *
 * @param buffer The address of memory to dump.
 * @param length The number of bytes to dump.
 * @param startingOffset The offset of the first byte to be displayed. 
 */
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
/**
 * The Unicode code point for the replacement character, used to substitute in a malformed input
 * stream for incorrect UTF encodings. It has the hexadecimal value of 0xFFFD.
 */
@Constant
public int REPLACEMENT_CHARACTER = 0xfffd;
