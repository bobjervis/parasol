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
 * These classes implement distinct copies of their text contents and can be modified. The
 * subscript operator can be used, as can the for-in collection iterator. They automatically
 * convert to one another so you can freely assign instances of one class to the other. All
 * Unicode code points can be represented in either UTF-8 and UTF-16. While there are higher costs
 * in translating from one format to ther other, there is never any information loss.
 *
 * You can also use the addition operator to concatenate strings. You may mix operands of
 * scalar numeric type as well as any string or substring class in a sequence of additions.
 * All necessary conversions are performed to produce the correct result text.
 *
 * You can compare string objects or use them as operands in a switch statement.
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
 * This can prove handy when parsing large quantities of text, for example.
 *
 * All four classes represent sequences of Unicode characters, so there is no notion of 'width' that
 * affects the conversion of numeric types, for example. As far as operations like copying or string
 * addition, all four types can be readily converted without loss of information. Any of the four classes
 * can coerce to any of the other four. Converting to either of the primary string classes will involve
 * copying text and may require a conversion between UTF-8 and UTF-16.
 *
 * It's important to note that while Parasol code assumes that UTF-8 is the encoding for string objects,
 * If you use a Decoder to validate and filter input data, you can be assured that the resulting string or
 * string16 objects are correct UTF and all characters are stored with the fewest bytes possible. Nevertheless,
 * the performance cost of such validation has to be weighed against the benefit for downstream computations.
 * Many methods on the string classes will produce 'correct' results for data that is not UTF text. An
 * application may choose to read text into a string object without deciding what the encoding is. It may
 * prove to be convenient to delay the decoding process until other contextual information is available. It
 * may also be desirable to retain the raw bytes of the input so that one can recover the original content when
 * a iece of text is decoded using the wrong format.
 *
 * Strings can be compared using Parasol relational and equality operators, but the comparison should not be
 * regarded as appropriate for a locale-specific
 * textual sort. It is designed to be efficient, so using {@link string.compare} to sort a set of Unicode
 * strings may not produce very satisfactory results. Also, if a UTF-8 encoded string is not encoded with the
 * shortest encodings possible, you may encounter strings that display identically and produce an identical
 * sequence of code points (through a {@link Decoder} for example), but still report as not-equal. Cirrectly
 * encoded UTF-16 strings will always compare equal to another UTF-16 string that contains the same sequence of
 * code points.
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
import parasol:international;
import parasol:memory;
import parasol:stream;
import parasol:stream.EOF;
import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;
/**
 * This is the preferred representation for text in Parasol.
 *
 * While all string literals are encoded as UTF-8 and a number of methods assume UTF-8
 * text, a string is an array of bytes. The documentation of the individual methods indicate 
 * where UTF-8 encoding is assumed and where other encodings will work.
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
	/**
	 * A constructor from a sub-string.
	 *
	 * The contents of the source string, beginning at the startOffset are copied. The resulting string is never
	 * null.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The startOffset is a byte offset. If that offset is in the middle of a multi-byte sequence, the newly
	 * constructed string will be malformed.
	 *
	 * @param source An existing string.
	 * @param startOffset The index of the first byte of the source string to copy. If this value is
	 * exactly the same as the length of source, the newly constructed string is the empty string.
	 *
	 * @exception IllegalArgumentException Thrown if source is null or the startOffset is negative or 
	 * greater than the length of source.
	 */
	public string(string source, int startOffset) {
		if (source != null) {
			if (unsigned(startOffset) > unsigned(source.length()))
				throw IllegalArgumentException("startOffset");
			resize(source.length() - startOffset);
			C.memcpy(&_contents.data, pointer<byte>(&source._contents.data) + startOffset, _contents.length);
			pointer<byte>(&source._contents.data)[_contents.length] = 0;
		} else
			throw IllegalArgumentException("source");
	}
	/**
	 * A constructor from a sub-string.
	 *
	 * The contents of the source string, beginning at the startOffset up to the endOffset are copied.
	 * The resulting string is never null.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The startOffset and endOffset are byte offsets. If either offset is in the middle of a multi-byte
	 * sequence, the newly constructed string will be malformed.
	 *
	 * @param source An existing string.
	 * @param startOffset The index of the first byte of the source string to copy. If this value is
	 * exactly the same as the length of source, the newly constructed string is the empty string.
	 * @param endOffset The index of the next byte after the last byte to copy.
	 *
	 * @exception IllegalArgumentException Thrown if source is null, the startOffset is negative or 
	 * greater than the length of source or the endOffset is less than the startOffset or greater
	 * than the source length.
	 */
	public string(string source, int startOffset, int endOffset) {
		if (source != null) {
			if (unsigned(startOffset) > unsigned(source.length()) || startOffset > endOffset || endOffset > source.length())
				throw IllegalArgumentException("startOffset");
			resize(endOffset - startOffset);
			C.memcpy(&_contents.data, pointer<byte>(&source._contents.data) + startOffset, endOffset - startOffset);
			pointer<byte>(&source._contents.data)[_contents.length] = 0;
		} else
			throw IllegalArgumentException("source");
	}
	/**
	 * A constructor from a substring object.
	 *
	 * If the source string is null, the constructed string will be 
	 * @param source The source string to copy.
	 */
	public string(substring source) {
		if (source._data != null) {
			resize(source._length);
			C.memcpy(&_contents.data, source._data, source._length);
		}
	}
	/**
	 * A constructor from a substring object.
	 *
	 * The contents of the source string, beginning at the startOffset are copied. The resulting string is never
	 * null.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The startOffset is a byte offset. If that offset is in the middle of a multi-byte sequence, the newly
	 * constructed string will be malformed.
	 *
	 * @param source An existing string.
	 * @param startOffset The index of the first byte of the source string to copy. If this value is
	 * exactly the same as the length of source, the newly constructed string is the empty string.
	 *
	 * @exception IllegalArgumentException Thrown if source is null or the startOffset is negative or 
	 * greater than the length of source.
	 */
	public string(substring source, int startOffset) {
		if (source._data != null) {
			if (unsigned(startOffset) > unsigned(source.length()))
				throw IllegalArgumentException("startOffset");
			resize(source._length - startOffset);
			C.memcpy(&_contents.data, source._data + startOffset, source._length - startOffset);
		} else
			throw IllegalArgumentException("source");
	}
	/**
	 * A constructor from a sub-string.
	 *
	 * The contents of the source string, beginning at the startOffset up to the endOffset are copied.
	 * The resulting string is never null.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The startOffset and endOffset are byte offsets. If either offset is in the middle of a multi-byte
	 * sequence, the newly constructed string will be malformed.
	 *
	 * @param source An existing string.
	 * @param startOffset The index of the first byte of the source string to copy. If this value is
	 * exactly the same as the length of source, the newly constructed string is the empty string.
	 * @param endOffset The index of the next byte after the last byte to copy.
	 *
	 * @exception IllegalArgumentException Thrown if source is null, the startOffset is negative or 
	 * greater than the length of source or the endOffset is less than the startOffset or greater
	 * than the source length.
	 */
	public string(substring source, int startOffset, int endOffset) {
		if (source._data != null) {
			if (unsigned(startOffset) > unsigned(source.length()) || startOffset > endOffset || endOffset > source.length())
				throw IllegalArgumentException("startOffset");
			resize(endOffset - startOffset);
			C.memcpy(&_contents.data, source._data + startOffset, endOffset - startOffset);
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
	public string(pointer<byte> cString) {
		if (cString != null) {
			int len = C.strlen(cString);
			resize(len);
			C.memcpy(&_contents.data, cString, len);
		}
	}
	/**
	 * A constructor from a byte array.
	 *
	 * @param value The byte array.
	 */
	public string(byte[] value) {
		resize(value.length());
		C.memcpy(&_contents.data, &value[0], value.length());
	}
	/**
	 * A constructor from a substring within a byte array object.
	 *
	 * The contents of the source string, beginning at the startOffset are copied. The resulting string is never
	 * null.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The startOffset is a byte offset. If that offset is in the middle of a multi-byte sequence, the newly
	 * constructed string will be malformed.
	 *
	 * @param source An existing string.
	 * @param startOffset The index of the first byte of the source string to copy. If this value is
	 * exactly the same as the length of source, the newly constructed string is the empty string.
	 *
	 * @exception IllegalArgumentException Thrown if source is null or the startOffset is negative or 
	 * greater than the length of source.
	 */
	public string(byte[] value, int startOffset) {
		if (startOffset < 0)
			throw IllegalArgumentException(string(startOffset));
		if (startOffset >= value.length()) {
			resize(0);
			return;
		}
		resize(value.length() - startOffset);
		C.memcpy(&_contents.data, &value[startOffset], length());
	}
	/**
	 * A constructor from a sub-string in a byte arrya object.
	 *
	 * The contents of the source string, beginning at the startOffset up to the endOffset are copied.
	 * The resulting string is never null.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The startOffset and endOffset are byte offsets. If either offset is in the middle of a multi-byte
	 * sequence, the newly constructed string will be malformed.
	 *
	 * @param source An existing string.
	 * @param startOffset The index of the first byte of the source string to copy. If this value is
	 * exactly the same as the length of source, the newly constructed string is the empty string.
	 * @param endOffset The index of the next byte after the last byte to copy.
	 *
	 * @exception IllegalArgumentException Thrown if source is null, the startOffset is negative or 
	 * greater than the length of source or the endOffset is less than the startOffset or greater
	 * than the source length.
	 */
	public string(byte[] value, int startOffset, int endOffset) {
		if (startOffset < 0 || endOffset < 0)
			throw IllegalArgumentException(string(startOffset));
		if (endOffset > value.length())
			endOffset = value.length();
		if (startOffset >= endOffset) {
			resize(0);
			return;
		}
		resize(endOffset - startOffset);
		C.memcpy(&_contents.data, &value[startOffset], length());
	}
	/**
	 * A constructor from a range of bytes.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The source bytes will be copied unchanged. The data could be binary or any
	 * text encoding format.
	 *
	 * @param buffer The address of the first byte to copy.
	 * @param length The number of bytes to copy.
	 *
	 * @exception IllegalArgumentException Thrown if buffer is null.
	 */
	public string(pointer<byte> buffer, int len) {
		if (buffer != null) {
			resize(len);
			C.memcpy(&_contents.data, buffer, len);
		} else
			throw IllegalArgumentException("buffer");
	}
	/**
	 * A constructor converting from a signed integer
	 *
	 * This constructs a string consisting of decimal digits possibly
	 * preceded by a locale-specific negative sign character.
	 *
	 * @param value The integral value to convert.
	 */	
	public string(long value) {
		if (value == 0) {
			append('0');
			return;
		} else if (value < 0) {
			append(international.myLocale().decimalStyle().negativeSign);
			if (value == long.MIN_VALUE) {
				append("9223372036854775808");
				return;
			}
			value = -value;
		}
		appendDigits(value);		
	}
	/**
	 * A constructor converting from a boolean
	 *
	 * This constructs a string consisting of either {@code true} or
	 * {@code false}.
	 *
	 * @value The boolean value to convert.
	 */	
	public string(boolean value) {
		if (value)
			append("true");
		else
			append("false");
	}
	/**
	 * A constructor converting from a string16.
	 *
	 * The content of the argument is converted from UTF-16 to
	 * UTF-8.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Any text in the source string that is not a valid Unicode
	 * code point is copied as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param other The UTF-16 string to convert.
	 */
	public string(string16 other) {
		if (other == null)
			return;
		resize(0);				// This makes the value != null (i.e. the empty string), if other is the empty string

		StringWriter w(this);
		UTF8Encoder ue(&w);

		ue.encode(other);
	}
	/**
	 * A constructor converting from a substring16.
	 *
	 * The content of the argument is converted from UTF-16 to
	 * UTF-8.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Any text in the source string that is not a valid Unicode
	 * code point is copied as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param other The UTF-16 string to convert.
	 */
	public string(substring16 other) {
		if (other.isNull())
			return;
		resize(0);				// This makes the value != null (i.e. the empty string), if other is the empty string

		StringWriter w(this);
		UTF8Encoder ue(&w);

		ue.encode(other);
	}
	/**
	 * A constructor converting from a sequence of char's.
	 *
	 * The content of the argument is converted from UTF-16 to
	 * UTF-8.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Any text in the source string that is not a valid Unicode
	 * code point is copied as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param buffer The first UTF-16 char to convert.
	 * @param The number of char's to convert.
	 */
	public string(pointer<char> buffer, int len) {
		if (buffer == null)
			return;

		stream.BufferReader r(buffer, len * char.bytes);
		UTF16Decoder ud(&r);

		*this = ud.decode();
	}
	/**
	 * A constructor converting from a floatng-point double
	 *
	 * This constructs a string using the %g format from {@link parasol:stream.Writer.printf printf}..
	 *
	 * @value The double value to convert.
	 */	
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

	private void appendDigits(long value) {
		if (value > 9)
			appendDigits(value / 10);
		value %= 10;
		append('0' + int(value));
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
	// TODO: Remove this when cast from string -> String<byte> works.
	/**
	 * Append a string
	 *
	 * The source string is copied byte-for-byte.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Bytes are appended without regard to encodings. If both this string
	 * and other are well-formed UTF-8, the result will be as well.
	 *
	 * @param other The string to copy.
	 */
	public void append(string other) {
		int len = other.length();
		if (len > 0) {
			int oldLength = length();
			resize(oldLength + len);
			C.memcpy(pointer<byte>(&_contents.data) + oldLength, &other._contents.data, len + 1);
		}
	}
	/**
	 * Append a string
	 *
	 * The source string is converted from UTF-16.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * If the source string contains improper UTF-16, {@link REPLACEMENT_CHARACTER}
	 * value are substituted in the copy.
	 *
	 * @param other The string to copy.
	 */
	public void append(string16 other) {
		String16Reader sr(&other);
		UTF16Decoder d(&sr);

		for (;;) {
			int c = d.decodeNext();
			if (c < 0)
				break;
			append(c);
		}
	}
	/**
	 * Append a string
	 *
	 * The source string is converted from UTF-16 and appended to any existing
	 * contents.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * If the source string contains improper UTF-16, {@link REPLACEMENT_CHARACTER}
	 * values are substituted in the copy.
	 *
	 * @param other The string to copy.
	 */
	public void append(substring16 other) {
		Substring16Reader sr(&other);
		UTF16Decoder d(&sr);

		for (;;) {
			int c = d.decodeNext();
			if (c < 0)
				break;
			append(c);
		}
	}
	/**
	 * Append a string
	 *
	 * The source string is appended to any existing contents..
	 *
	 * <h4>Encoding:</h4>
	 *
	 * No validation of the UTF-8 is done. The bytes are copied without modification.
	 *
	 * @param other The string to copy.
	 */
	public void append(substring other) {
		if (other._length > 0) {
			int oldLength = length();
			resize(oldLength + other._length);
			C.memcpy(pointer<byte>(&_contents.data) + oldLength, other._data, other._length);
		}
	}
	/**
	 * Append a string
	 *
	 * The source char's are converted from UTF-16 and appended to any existing
	 * contents.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * If the source char's contain improper UTF-16, {@link REPLACEMENT_CHARACTER}
	 * values are substituted in the copy.
	 *
	 * @param cp The first char to copy.
	 * @param length The number of char's to copy.
	 */
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
	 * {@link REPLACEMENT_CHARACTER} is stored instead.
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
	public string center(int size, int pad) {
		StringReader r(this);
		UTF8Decoder d(&r);

		int characters = d.count();

		int margin = size - characters;
		if (margin <= 0)
			return *this;
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
	 * This function implements string compares for the equality and relational operators.
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
	public int compareIgnoreCase(string other) {
		throw IllegalOperationException("not yet implemented");
		return 0;
	}
	/**
	 * The implementation function of the string assignment operator.
	 *
	 * The assignment operator makes the left hand operand the value of this and the
	 * right-hand operand the argument value.
	 *
	 * Assigning a string to itself has no effect.
	 *
	 * @param other The string value to copy.
	 */
	void copy(string other) {
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
	/**
	 *
	 * @exception IllegalOperationException Thrown always. This function is not yet implemented
	 * and calling will fail. 
	 */
	public string encrypt(string salt) {
		throw IllegalOperationException("not yet implemented");
		return *this;
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
		return substring(*this).escapeC();
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
		String<byte> s = escapeJSON_T();

		return *ref<string>(&s);
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
		if (length() == 0)
			return *this;
		else
			return substring(*this).escapeParasol();
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
	/**
	 * Calculate a 32-bit hash of the string value.
	 *
	 * This hash is used in arrays indexed by string type as well as in {@link parasol:types.map map}
	 * objects whose key type is string.
	 *
	 * @return A pseudo-random value derived from the contents of the string.
	 */	
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
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = start; i < len; i++)
			if (cp[i] == c)
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
		pointer<byte> cp = pointer<byte>(&_contents.data);
		int tries =  1 + len - s.length() - start;
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
	/**
	 * Insert a byte into an existing string.
	 *
	 * @param index The index of the byte where the insertion should take place.
	 * @param value The byte to insert.
	 *
	 * @exception IllegalArgumentException Thrown if the index is less than zero or
	 * greater than the length of the string.
	 */
	public void insert(int index, byte value) {
		int len = length();
		if (index < 0 || index > len)
			throw IllegalArgumentException(string(index));
		resize(len + 1);
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int j = _contents.length - 1; j > index; j--)
			cp[j] = cp[j - 1];
		cp[index] = value;
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
		return lastIndexOf(c, length() - 1);
	}
	/**
	 * Find the last instance, before a starting point, of a byte value.
	 *
	 * Returns the index of the last occurrance of the byte c
	 * in the string before the start index.
	 *
	 * If you want to search for a multi-byte Unicode value, you
	 * will need to pass the sought-after value as a string.
	 *
	 * @param c The byte to search for.
	 * @param start The index of this string at which to start searching.
	 *
	 * @return The index of the last occarrance of c in the string before
	 * start, or -1 if the byte does not appear in the string before start.
	 *
	 * @exception IllegalArgumentException Thrown if the start is less than zero or
	 * greater than the length of the string.
	 */
	public int lastIndexOf(byte c, int start) {
		if (_contents != null) {
			if (start < 0 || start > _contents.length)
				throw IllegalArgumentException(string(start));
			pointer<byte> cp = pointer<byte>(&_contents.data);
			for (int i = start; i >= 0; i--)
				if (cp[i] == c)
					return i;
		} else if (start != 0)
			throw IllegalArgumentException(string(start));
		return -1;
	}
	/**
	 * Find the last instance of a sub-string.
	 *
	 * Returns the index of the last occurrance of the sub-string s
	 * in this string.
	 *
	 * @param s The value to search for.
	 *
	 * @return The index of the last occurrance of s in the string, or
	 * -1 if the sub-string does not appear in the string.
	 */
	public int lastIndexOf(string s) {
		return lastIndexOf(s, length() - 1);
	}
	/**
	 * Find the last instance, before a starting point, of a sub-string.
	 *
	 * Returns the index of the last occurrance of the sub-string s
	 * in the string before the start index.
	 *
	 * @param s The value to search for.
	 * @param start The index of this string at which to start searching.
	 *
	 * @return The index of the last occurrance of s in the string before
	 * start, or -1 if the sub-string does not appear in the string before start.
	 *
	 * @exception IllegalArgumentException Thrown if the start is less than zero or
	 * greater than the length of the string.
	 */
	public int lastIndexOf(string s, int start) {
		if (start < 0 || start > length())
			throw IllegalArgumentException(string(start));
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
	/**
	 * Write a formatted message onto the end of this string.
	 *
	 * @param format A format string as defined in {@link parasol:stream.Writer.printf printf}.
	 * @param arguments Zero or more arguments, as determined by the format string.
	 *
	 * @return The number of bytes appended to this string.
	 */
	public int printf(string format, var... arguments) {
		StringWriter w(this);
		return w.printf(format, arguments);
	}
	/**
 	 * Replaces each instance of the match string with the replacement.
	 *
	 * @param match The sub-string to look for.
	 * @param replacement The text to substitute for each matching sub-string.
	 *
	 * @return The original string with each instance of match replaced by replacement.
	 */
	public string replaceAll(string match, string replacement) {
		string result;

		int start = 0;
		for (;;) {
			int idx = indexOf(match, start);
			if (idx < 0) {
				result.append(substr(start));
				break;
			} else {
				result.append(substr(start, idx));
				result.append(replacement);
				start = idx + match.length();
			}
		}
		return result;
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
		pointer<byte>(&_contents.data)[index] = value;
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
		if (_contents != null) {
			int tokenStart = 0;
			for (int i = 0; i < _contents.length; i++) {
				if (pointer<byte>(&_contents.data)[i] == delimiter) {
					output.append(string(pointer<byte>(&_contents.data) + tokenStart, i - tokenStart));
					tokenStart = i + 1;
				}
			}
			if (tokenStart > 0) {
				output.append(string(pointer<byte>(&_contents.data) + tokenStart, _contents.length - tokenStart));
			} else
				output.append(*this);
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
		return substring(pointer<byte>(&_contents.data) + first, length() - first);
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
		return substring(pointer<byte>(&_contents.data) + first, last - first);
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
				return string(cp + i, 1);
			}
		}
		return "";
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
					case '?':	output.append('?');		break;
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
		String<byte> result;
		boolean success;

		(result, success) = super.unescapeParasolT();
		// This makes some big assumptions about the relationship between the base template class
		// and the derived class, but if the language runtime can't know about the intricacies of
		// its own implementation, who can?
		return *ref<string>(&result), success;
	}
}
/**
 * This class contains a UTF-16 encoded string.
 *
 * While a number of methods assume UTF-16 text, a string16 is an array of char's. The documentation
 * of the individual methods indicate where UTF-16 encoding is assumed and where other encodings will work.
 */
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
	/**
	 * The default constructor.
	 *
	 * By default, the string value is null.
	 */
	public string16() {
	}
	/**
	 * A constructor converting from a string.
	 *
	 * The content of the argument is converted from UTF-8 to
	 * UTF-16.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Any text in the source string that is not a valid Unicode
	 * code point is copied as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param other The UTF-8 string to convert.
	 */
	public string16(string other) {
		if (other == null)
			return;
		// Assure that we have at least an empty string and not null
		resize(0);
		String16Writer w(this);
		UTF16Encoder u16(&w);

		u16.encode(other);
	}
	/**
	 * A copy constructor.
	 *
	 * The contents of the source string are copied. If source is
	 * null, the newly constructed string is null as well.
	 *
	 * @param source An existing string.
	 */
	public string16(string16 source) {
		if (source != null) {
			resize(source.length());
			C.memcpy(&_contents.data, &source._contents.data, (source._contents.length + 1) * char.bytes);
		}
	}
	/**
	 * A constructor from a substring object.
	 *
	 * If the other string is null, the constructed string will be null as well.
	 *
	 * The content of the argument is converted from UTF-8 to
	 * UTF-16.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Any text in the source string that is not a valid Unicode
	 * code point is copied as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param other The source string to copy.
	 */
	public string16(substring other) {
		if (other.isNull())
			return;
		resize(0);
		assert(_contents != null);
		String16Writer w(this);
		UTF16Encoder u16(&w);

		u16.encode(other);
	}
	/**
	 * A constructor from a substring object.
	 *
	 * If the other string is null, the constructed string will be as well.
	 *
	 * @param other The source string to copy.
	 */
	public string16(substring16 other) {
		if (!other.isNull()) {
			resize(other.length());
			C.memcpy(&_contents.data, other.c_str(), other.length() * char.bytes);
		}
	}
	/**
	 * A constructor from a range of char's.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * The source char's will be copied unchanged. The data could be binary or any
	 * text encoding format.
	 *
	 * @param buffer The address of the first char to copy.
	 * @param length The number of char's to copy.
	 *
	 * @exception IllegalArgumentException Thrown if buffer is null.
	 */
	public string16(pointer<char> buffer, int len) {
		if (buffer != null) {
			resize(len);
			C.memcpy(&_contents.data, buffer, len * char.bytes);
		} else
			throw IllegalArgumentException("buffer");
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
	/**
	 * Append a string
	 *
	 * The source string is converted from UTF-8.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * If the source string contains improper UTF-8, {@link REPLACEMENT_CHARACTER}
	 * value are substituted in the copy.
	 *
	 * @param other The string to copy.
	 */
	public void append(string other) {
		StringReader sr(&other);
		UTF8Decoder d(&sr);

		for (;;) {
			int c = d.decodeNext();
			if (c < 0)
				break;
			append(c);
		}
	}
	// TODO: Remove this when cast from string -> String<byte> works.
	/**
	 * Append a string
	 *
	 * The source string is copied char-for-char.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * Bytes are appended without regard to encodings. If both this string
	 * and other are well-formed UTF-16, the result will be as well.
	 *
	 * @param other The string to copy.
	 */
	public void append(string16 other) {
		int len = other.length();
		if (len > 0) {
			int oldLength = length();
			resize(oldLength + len);
			C.memcpy(pointer<char>(&_contents.data) + oldLength, &other._contents.data, (len + 1) * char.bytes);
		}
	}
	/**
	 * Append a string
	 *
	 * The source string is appended to any existing contents..
	 *
	 * <h4>Encoding:</h4>
	 *
	 * No validation of the UTF-16 is done. The char's are copied without modification.
	 *
	 * @param other The string to copy.
	 */
	public void append(substring16 other) {
		if (other._length > 0) {
			int oldLength = length();
			resize(oldLength + other._length);
			C.memcpy(pointer<char>(&_contents.data) + oldLength, other._data, other._length * char.bytes);
		}
	}
	/**
	 * Append a string
	 *
	 * The source string is converted from UTF-8 and appended to any existing
	 * contents.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * If the source string contains improper UTF-8, {@link REPLACEMENT_CHARACTER}
	 * values are substituted in the copy.
	 *
	 * @param other The string to copy.
	 */
	public void append(substring other) {
		SubstringReader sr(&other);
		UTF8Decoder d(&sr);

		for (;;) {
			int c = d.decodeNext();
			if (c < 0)
				break;
			append(c);
		}
	}
	/**
	 * This function implements string compares for the equality and relational operators.
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
	/**
	 * Compare this to a UTF-8 string.
	 *
	 * <h4>Encoding:</h4>
	 *
	 * If the argument string contains malformed UTF-8 text, the malformed
	 * characters will be converted to the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param other The string to compare this with.
	 *
	 * @return <0 if this string is less than the other, 0 if they are equal
	 * and >0 if this string is greater than the other string.
	 */
	public int compare(string other) {
		return compare(string16(other));
	}
	/**
	 * The implementation function of the string assignment operator.
	 *
	 * The assignment operator makes the left hand operand the value of this and the
	 * right-hand operand the argument value.
	 *
	 * Assigning a string to itself has no effect.
	 *
	 * @param other The string value to copy.
	 */
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
	public substring16 substr(int first) {
		if (first < 0 || first > length())
			throw IllegalArgumentException("first " + first);
		return substring16(pointer<char>(&_contents.data) + first, length() - first);
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
	public substring16 substr(int first, int last) {
		if (first < 0 || first > length())
			throw IllegalArgumentException("first " + first);
		if (last < first || last > length())
			throw IllegalArgumentException("last " + last);
		return substring16(pointer<char>(&_contents.data) + first, last - first);
	}
}

class String<class T> {
	protected class allocation {
		public int length;
		public T data;
	}

	protected static int MIN_SIZE = 0x10;

	protected ref<allocation> _contents;
/*
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
 */
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

	public T get(int index) {
		return _contents.data[index];
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
		assert(newLength >= 0);
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
	 *	Process the input string as if it were a Parasol string literal.
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
/**
 * A Reader for string objects.
 *
 * A StringReader can report its length and can be reset.
 *
 * A StringReader can unread the entire string at any point.
 */
public class StringReader extends Reader {
	private ref<string> _source;
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
/**
 * A Writer for string objects.
 *
 * Output written to the Writer will be appended to any text
 * already in the string. You may alter the string in other
 * ways between writing data through the StringWriter and the
 * next output to the string will append the data to whatever
 * contents the string has at the moment the write takes place.
 */
public class StringWriter extends Writer {
	private ref<string> _output;
	/**
	 * Constructor.
	 *
	 * @param output A reference to the string object to populate.
	 */
	public StringWriter(ref<string> output) {
		_output = output;
	}
	
	public void _write(byte c) {
		_output.append(c);
	}
}
/**
 * A Reader for string objects.
 *
 * A StringReader can report its length and can be reset.
 *
 * A StringReader can unread the entire string at any point.
 * Take care when unreading data so that you don't confuse the
 * char boundaries and potentially corrupt any UTF-16 data in
 * the byte stream.
 *
 * Since a Reader reads bytes, the char's of a {@link string16}
 * will be read one byte at a time, thus requiring two reads for
 * each char. EOF will be reported when the last full char is exhausted.
 */
public class String16Reader extends Reader {
	private ref<string16> _source;
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
/**
 * A Writer for string objects.
 *
 * Output written to the Writer will be appended to any text
 * already in the string. You may alter the string in other
 * ways between writing data through the StringWriter and the
 * next output to the string will append the data to whatever
 * contents the string has at the moment the write takes place.
 *
 * The first byte of a char is written to a buffer in the Writer
 * object and does not affect the value of the underlying string. 
 * Only when the second byte of the char is written will the underlying
 * string be modified. Use care when mixing write's through this
 * Writer and other manipulations of the underlying string to ensure
 * that correct text is properly written.
 */
public class String16Writer extends Writer {
	private short _lo;
	private ref<string16> _output;
	/**
	 * Constructor.
	 *
	 * @param output A reference to the string object to populate.
	 */
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
/**
 * The Unicode code point for the replacement character, used to substitute in a malformed input
 * stream for incorrect UTF encodings. It has the hexadecimal value of 0xFFFD.
 */
@Constant
public int REPLACEMENT_CHARACTER = 0xfffd;
