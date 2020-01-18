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
 * Provides facilities for processing streams of characters or bytes, including
 * conversion between various UTF encodings.
 *
 * Streams are represented as either some kind of Reader class or some kind of Writer
 * class. 
 *
 * Readers iteratively return a stream of objects of some type. Whether a Reader
 * consumes an external resource (such as a network message) is dependent on the class.
 *
 * Writers take objects or arrays of objects of some type and arranges them into a stream.
 *
 * <h3>Text and encodings</h3>
 *
 * For historical reasons, the representation of files of text varies from one operating system
 * to another. For that reason, Parasol, like C and C++, differentiate between text and binary files.
 * Currently, this is an issue of sharing text files between Windows and Linux/UNIX systems.
 * Various formats have been used by other operating systems that are now obsolete. While it is 
 * possible that some future operating system may choose yet another format to promote, that seems
 * technically unlikely. Masses of modern software have been written to the surviving two text formats
 * (at least in part because the differences are so minor). As a result, none of that software could
 * cheaply migrate to an operating system that did not employ one or the other of the existing
 * formats.
 *
 * The text file format returned by a Reader contains lines of text separated by a single newline
 * character ('\n'). Each line of text is represented as a sequence of bytes. Whether the contents of the
 * lines of text are encoded using UTF-8 or some other encoding is not specified.
 *
 * The text file format written by a Writer expects lines of text separated by the single newline (0x0a).
 * As each line of text is written. The bytes of the text are written to the output stream without modification.
 * Line separators are written in the format appropriate to the host operating system. Any bytes inserted
 * into the output to represent a line separator are not counted in the bytes written by the call. Each line
 * separator is counted as one byte written to the stream, regardless of host operating system.
 *
 * The intention of the design of the various Reader and Writer streams is to allow a developer to choose
 * a class that is as simple as possible for the task at hand. For many applications, treating a file as
 * binary will still yield correct results for text files. For applications that are sensitive to text
 * line-separation may not need to care about which of a set of encodings (such as UTF-8 or ISO 8859-1) the 
 * file uses.
 *
 * @threading Readers are never thread safe. Writers may or may not be thread safe. Any
 * thread safety will be documented with the class.
 */
namespace parasol:stream;

import parasol:international;
import parasol:runtime;
import parasol:storage.File;
import parasol:storage.Seek;
import parasol:time.Time;
import parasol:text;
import parasol:text.string16;
import parasol:exception.BoundsException;
import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;

import native:C;
import native:linux;

@Constant
int MILLIS_PER_SECOND = 1000;
/**
 * An indicator of end of file returned by functions such as {@link Reader.read}.
 */
@Constant
public int EOF = -1;
/**
 * The general Reader class. Manipulation of input data is primarily driven through
 * Reader objects.
 *
 * An input stream is modeled by instances of the Reader class to provide a source for
 * a stream of bytes of data. Input streams have a variety of capabilities in keeping
 * with the specifics of the underlying technology the data streams are using. For example, 
 * files typically have a fixed size and can efficiently read the file contents continuously
 * from beginning to end, or can randomly seek to various file positions and read data
 * there. For another example, streams reading from a console device, like standard input, cannot
 * be randomly positioned at all and can continue to read bytes indefinitely.
 *
 * The Reader class itself is abstract. It relies on each of several subclasses implementing
 * a _read and an unread method that will actually interact with the underlying input source.
 *
 * There are also a number of methods provided that include default implementations. Sub-classes of Reader
 * shall preserve the semantics of the default implementation but may override the implementation with 
 * one optimized for the specific source of the Reader.
 */
public class Reader {
	/**
	 * Read the next byte from the input stream.
	 *
	 * This must be implemented by any sub-class of Reader.
	 *
	 * @return The next byte in the input stream. On end-of-file, the method returns {@link EOF}.
	 *
	 * @exception IOException Thrown if any error condition was encountered reading from the stream.
	 */
	protected abstract int _read();
	/**
	 * Read the next byte from the input stream.
	 *
	 * Each byte read will be converted to an int. This is done to permit the use of a distinct value
	 * for {@link EOF}. It will require, typically, that you use an explicit  conversion back to
	 * byte once you have determined that the method did not return {@link EOF}.
	 *
	 * @return The next byte in the input stream. On end-of-file, the method returns {@link EOF}.
	 *
	 * @exception {@link parasol:exception.IOException} Thrown if any error condition was encountered reading from the stream.
	 */
	public int read() {
		return _read();
	}
	/**
	 * Restore the last byte read.
	 *
	 * This method will adjust the position of the input stream to just before the last byte read.
	 * If the stream is at the initial position or has just been positioned using a {@link seek}
	 * method, this call has no effect.
	 *
	 * One byte of pushback is supported by all Readers. Each Reader class should document what
	 * happens when this method is called more than once with no intervening calls that read data
	 * from the stream. 
	 */
	public abstract void unread();
	/**
	 * Read the entire contents of a Reader into a string.
	 *
	 * @return The contents of the Reader. If the Reader immediately return EOF, an empty string is
	 * returned.
	 *
	 * @exception parasol:exception.IOException Thrown if any error condition was encountered reading from the stream.
	 *
	 * @exception parasol:memory.OutOfMemoryException Thrown if the Reader's contents are larger
	 * than {@link int.MAX_VALUE} bytes.
	 */
	public string readAll() {
		string s = "";
		for (;;) {
			int c = _read();
			if (c == EOF)
				return s;
			s.append(byte(c));
		}
	}
	/**
	 * Read bytes from the Reader.
	 *
	 * @param buffer he memory location of the buffer to hold the bytes that were read.
	 *
	 * @param length The number of bytes to read.
	 *
	 * @return The actual number of bytes read.
	 *
	 * @exception parasol:exception.IOException Thrown if any error condition was encountered reading from the stream.
	 */
	public long read(address buffer, long length) {
		pointer<byte> input = pointer<byte>(buffer);

		for (int i = 0; i < length; i++) {
			int c = _read();
			if (c == EOF)
				return i;
			input[i] = byte(c);
		}
		return length;
	}
	/**
	 * Reads text into a byte array buffer.
	 *
	 * @param buffer A reference to the byte array to populate. The maximum number of bytes
	 * that can be read is the length of the array before the call.
	 *
	 * @return The actual number of bytes read. The length of the array is not adjusted. Any
	 * bytes in the array beyond the bytes read are unchanged.
	 *
	 * @exception parasol:exception.IOException Thrown if any error condition was encountered reading from the stream.
	 */
	public int read(ref<byte[]> buffer) {
		return int(read(&(*buffer)[0], buffer.length()));
	}
	/**
	 * Reads text into a char array buffer. 
	 *
	 * @param buffer A reference to the char array to populate. The maximum number of chars
	 * that can be read is the length of the array before the call.
	 *
	 * @return The actual number of chars read. The length of the array is not adjusted. Any
	 * chars in the array beyond the bytes read are unchanged.
	 *
	 * If an odd number of bytes are read when the Reader encounters end-of-file, the last byte
	 * is pushed back on the Reader. Only full char's are returned.
	 *
	 * @exception parasol:exception.IOException Thrown if any error condition was encountered reading from the stream.
	 */
	public int read(ref<char[]> buffer) {
		int i;
		for (i = 0; i < buffer.length(); i++) {
			int lo = _read();
			if (lo == EOF)
				break;
			int hi = _read();
			if (hi == EOF) {
				unread();
				break;
			}
			(*buffer)[i] = char(lo | (hi << 8));
		}
		return i;
	}
	/**
	 * Read a line of text from the Reader.
	 *
	 * @return The line of text, excluding any line separator character. If the Reader
	 * reports end-of-file before any content bytes are read, the methoed return null.
	 * If a line separator is read and no content bytes appear on the line, an empty
	 * string is returned.
	 *
	 * @exception parasol:exception.IOException Thrown if any error condition was encountered reading from the stream.
	 */
	public string readLine() {
		string line = "";

		for (;;) {
			int c = _read();
			if (c == EOF) {
				if (line.length() == 0)
					return null;
				else
					return line;
			}
			if (c == '\r')
				continue;
			if (c == '\n')
				return line;
			line.append(byte(c));
		}
	}
	/**
	 * Close any external connection associated with the Reader and rekease
	 * any buffered data held by the Reader.
	 *
	 * @exception parasol:exception.IOException Thrown if any error condition was encountered trying to close the stream.
	 */
	public void close() {
	}
	/**
	 * Check whether the Reader has a specific length.
	 *
	 * Some Readers are connected to objects like strings or files and therefore have a length
	 * that can be interrogated.
	 *
	 * @return true if the {@link length} and {@link reset} methods can be called on this Reader, false otherwise.
	 */
	public boolean hasLength() {
		return false;
	}
	/**
	 * Fetch the remaining bytes to read.
	 *
	 * @eeturn The remaining number of bytes to be read from the Reader.
	 *
	 * @exception IllegalOperationException Thrown if the Reader returns false for the {@link hasLength} method.
	 */
	public long length() {
		throw IllegalOperationException("length");
		return 0;
	}
	/**
	 * Reset the Reader.
	 *
	 * If this method does not throw an exception, the Reader will be reset to read all of the bytes from the 
	 * input source. Note that if this Reader had been obtained from a File object that was not positioned at the
	 * start of the file, then resetting the Reader will cause the entire file to be read after the call to reset.
	 *
	 * @exception IllegalOperationException Thrown if the Reader returns false for the {@link hasLength} method.
	 *
	 * @exception parasol:exception.IOException Thrown if any error condition was encountered trying to close the stream.
	 */
	public void reset() {
		throw IllegalOperationException("reset");
	}
}
/**
 * Read bytes from a buffer.
 *
 * This Reader can be used to serialize any Parasol object, or an array of objects.
 * In general, it is only valid to deserialize such data into the same object type
 * using a {@link BufferWriter}.
 *
 * It is not portable to interpret the bytes returned from this Reader as any particular
 * member of a class. 
 * The order in memory of members of a class is unspecified. A Parasol compiler is free
 * to assign memory offsets to members without regard to lexical order, for example.
 *
 * It is portable to assume that the first bytes of elements of an array of objects are the bytes of
 * the first element selected for the BufferReader. The elements of an array are read in
 * ascending index order.
 */
public class BufferReader extends Reader {
	long _index;
	pointer<byte> _buffer;
	long _length;
	/**
	 * Construct from a region of storage.
	 *
	 * If the address passed in the buffer parameter is a simple object, it is an error
	 * to pass a length that is not the number of bytes in the class of the object.
	 *
	 * If the address passed in the buffer parameter is in an array of objects, it is an
	 * error to pass a length that is not a multiple of the number of bytes in the class
	 * of the array elements. Further, the range of object instances shall appear correctly
	 * within and correctly align with the elements of the array.
	 *
	 * @param buffer The address of an object in memory.
	 * @param length The number of bytes to read.
	 */
	public BufferReader(address buffer, long length) {
		_buffer = pointer<byte>(buffer);
		_length = length;
	}
	/**
	 * Construct from a byte array.
	 *
	 * @param buffer A non-null reference to the array object.
	 */
	public BufferReader(ref<byte[]> buffer) {
		_buffer = &(*buffer)[0];
		_length = buffer.length();
	}

	public int _read() {
		if (_index < _length) {
			return _buffer[_index++];
		} else
			return EOF;
	}

	public void unread() {
		if (_index > 0)
			--_index;
	}

	public boolean hasLength() {
		return true;
	}

	public long length() {
		return _length - _index;
	}

	public void reset() {
		_index = 0;
	}
}
/**
 * The general Writer class. Manipulation of output data is primarily driven through
 * Writer objects.
 *
 * An output stream is modeled by instances of the Writer class to provide a destination for
 * a stream of bytes of data. You may only write data to the end of a stream. A Writer may
 * buffer output data, so there is no guarantee that data written to different streams will
 * appear in any particular order unless you call the {@link flush} method to ensure that
 * any buffered data has been written to the destination.
 *
 * The Writer class itself is abstract. It relies on each of several subclasses implementing
 * a _write method that will actually interact with the underlying output destination.
 *
 * There are also a number of methods provided that include default implementations. Sub-classes of Writer
 * shall preserve the semantics of the default implementation but may override the implementation with 
 * one optimized for the specific destination of the Writer.
 */
public class Writer {
	/**
	 * Write a byte to the output stream.
	 *
	 * This must be implemented by any sub-class of Reader.
	 *
	 * @param c The byte to be written.
	 *
	 * @exception IOException Thrown if any device error condition was encountered writing to the stream.
	 *
	 * @exception IllegalOperationException Thrown if the stream has exceeded the capacity of the output
	 * and cannot accept any more data.
	 */
	protected abstract void _write(byte c);
	/**
	 * Write a byte to the output stream.
	 *
	 * @param c The byte to be written.
	 *
	 * @exception IOException Thrown if any device error condition was encountered writing to the stream.
	 *
	 * @exception IllegalOperationException Thrown if the stream has exceeded the capacity of the output
	 * and cannot accept any more data.
	 */
	public void write(byte c) {
		_write(c);
	}
	/**
	 * Write a Unicode code point to the output stream.
	 *
	 * The code point is written in UTF-8 format.
	 *
	 * @param codePoint The code point to be written.
	 *
	 * @return The actual number of bytes written to the output stream.
	 *
	 * @exception IOException Thrown if any device error condition was encountered writing to the stream.
	 *
	 * @exception IllegalOperationException Thrown if the stream has exceeded the capacity of the output
	 * and cannot accept any more data.
	 */
	public int writeCodePoint(int codePoint) {
		text.UTF8Encoder e(this);

		return e.encode(codePoint);
	}
	/**
	 * Flush any buffered data to the output stream.
	 *
	 * The call will return when all data has been written to the output stream.
	 *
	 * @exception IOException Thrown if any device error condition was encountered writing to the stream.
	 */
	public void flush() {
	}
	/**
	 * Close any external connection associated with the Writer and rekease
	 * any buffered data held by the Writer.
	 *
	 * @exception IOException Thrown if any device error condition was encountered trying to close the stream.
	 */
	public void close() {
	}
	/**
	 * Write object(s) to an output stream.
	 *
	 * If the address passed in the buffer parameter is a simple object, it is an error
	 * to pass a length that is not the number of bytes in the class of the object.
	 *
	 * If the address passed in the buffer parameter is in an array of objects, it is an
	 * error to pass a length that is not a multiple of the number of bytes in the class
	 * of the array elements. Further, the range of object instances shall appear correctly
	 * within and correctly align with the elements of the array.
	 *
	 * @param buffer The address of the memory to be written.
	 * @param length The number of bytes to write.
	 *
	 * @return The number of bytes written.
	 *
	 * @exception IOException Thrown if any device error condition was encountered writing to the stream.
	 *
	 * @exception IllegalOperationException Thrown if the stream has exceeded the capacity of the output
	 * and cannot accept any more data.
	 */
	public long write(address buffer, long length) {
		for (int i = 0; i < length; i++)
			_write(pointer<byte>(buffer)[i]);
		return length;
	}
	/**
	 * Write the contents of a string.
	 *
	 * The bytes of the string are written as they are stored. No validation of the text encoding is
	 * done.
	 *
	 * @param s The string to write.
	 *
	 * @return The number of bytes written.
	 *
	 * @exception IOException Thrown if any error condition was encountered writing to the stream.
	 *
	 * @exception IllegalOperationException Thrown if the stream has exceeded the capacity of the output
	 * and cannot accept any more data.
	 */
	public int write(string s) {
		for (int i = 0; i < s.length(); i++)
			_write(s[i]);
		return s.length();
	}
	/**
	 * Write the contents of a string.
	 *
	 * The char's of the string are written as they are stored. No validation of the text encoding is
	 * done. An even number of bytes will always be written.
	 *
	 * @param s The string to write.
	 *
	 * @return The number of bytes written.
	 *
	 * @exception IOException Thrown if any error condition was encountered writing to the stream.
	 *
	 * @exception IllegalOperationException Thrown if the stream has exceeded the capacity of the output
	 * and cannot accept any more data.
	 */
	public long write(string16 s) {
		return write(s.c_str(), s.length() * char.bytes);
	}
	/**
	 * Write the contents of a stream provided by a Reader.
	 *
	 * The bytes of the Reader are read and copied to this output stream until end-of-file is
	 * encountered. This call will block if the Reader has to wait for input.
	 *
	 * @param reader The Reader to use as the source for data.
	 *
	 * @return The number of bytes written.
	 *
	 * @exception IOException Thrown if any error condition was encountered reading from the
	 * input or writing to the output stream.
	 *
	 * @exception IllegalOperationException Thrown if the stream has exceeded the capacity of the output
	 * and cannot accept any more data.
	 */
	public long write(ref<Reader> reader) {
		byte[] b;
		b.resize(8096);
		long totalWritten = 0;
		for (;;) {
			int actual = reader.read(&b);
			if (actual <= 0)
				break;
			totalWritten += write(&b[0], actual);
		}
		return totalWritten;
	}
	/**
	 * Write a formatted string.
	 *
	 * The method writes characters from the format string to this Writer object until
	 * a percent character is encountered (%). The percent character introduces a formatting
	 * specifier which will describe a formatting operation that depends on zero or more
	 * arguments. Copying text to the Writer object resumes after the formatting specifier and
	 * continues copying text and processing formatting specifiers until the end of the format
	 * string is reached.
	 * 
	 * A formatting specifier uses the following syntax:
	 *
	 *  {@code %[argument_index$][flags][width][.precision]conversion}
	 *
	 * If a format specifier is malformed due to invalid flag or conversion characters or the
	 * conversion does not match the data type of the selected argument, the format specifier
	 * itself is written to the output stream.
	 *
	 * <b>Argument Index</b>
	 *
	 * The argument index may be the following:
	 *
	 *<ul>
	 *  <li> a sequence of decimal digits. The specific argument corresponding to
	 *       that decimal value will be formatted. If the number is outside the
	 *		 range of the arguments array, a BoundsException will be thrown.
	 *  <li> A less-than character (\<). If present on the first formatting specifier. an
	 *       IllegalArgumentException is thrown. On subsequent formatting specifiers, this
	 *		 designates that the same arguments value should be used as was used in the prior
	 *		 formatting specifier.
	 *</ul>
	 *
	 * <b>Flags</b>
	 *
	 * Flags may be a sequence of any or all of the following characters in any order.
	 *
	 *<table>
	 *  <tr>
	 *    <td><b>0</b></td>
	 *		  <td>Zero-fill. Numeric values should pad using a leading zero digit.
	 * 			  The default is a space character.</td>
	 *  </tr>
	 *    <td>(space)</td>
	 *		  <td>Leading space for positive. Positive numeric values will be written with at
	 *			  least a single space character before the value. The default is no sign character.</td>
	 *  <tr>
	 *  </tr>
	 *    <td><b>-</b></td>
	 *		  <td>Left-justified. The field value will be left-justified in the specified width. The
	 * 			  default is to right-justify.</td>
	 *  <tr>
	 *    <td><b>+</b></td>
	 *		  <td>Always include sign. Positive numeric values will be written with a Locale-dependent
	 *			  positive sign character before the field value. The default is no sign character.</td>
	 *  </tr>
	 *  <tr>
	 *    <td><b>#</b></td>
	 *		  <td>Alternate form. Numeric values will be formatted in an alternate form, depending on
	 *			  the conversion.</td>
	 *  </tr>
	 *  <tr>
	 *    <td><b>,</b></td>
	 *		  <td>Grouping separators. Large numeric values will will use a Locale-dependaent grouping separator.
	 *			  For example, in United States locales, every three digits to the left of any decimal point are
	 *			  separated by commas. The default is no grouping separators.</td>
	 *  </tr>
	 *  <tr>
	 *    <td><b>(</b></td>
	 *		  <td>Denote negative with parentheses. Negative numeric values will be enclosed in parenthese.
	 *		      The default is a Locale-dependent negative sign character before the field value.</td>
	 *  </tr>
	 *</table>
	 *
	 * <b>Width</b>
	 *
	 * Width may be:
	 *
	 * <ul>
	 *     <li> A sequence of one or more decimal digits.
	 *     <li> An asterisk (*) character. If present, the argument immediately after the last argument referenced
	 *           is accessed as an integer. That becomes the new last argument referenced.
	 * </ul>
	 *
	 * The value specifies the minimum width in characters. If the actual number of characters being formatted for
	 * the field value is less than the width, then pad characters are
	 * written to ensure that at least the width is filled. What character is used as the pad and whether the padding
	 * is placed on the left or right side of the field characters is determined by flags (see above).
	 *
	 * <b>Precision</b>
	 *
	 * Precision may be:
	 *
	 * <ul>
	 *     <li> A sequence of one or more decimal digits.
	 *     <li> An asterisk (*) character. If present, the argument immediately after the last argument referenced
	 *           is accessed as an integer. That becomes the new last argument referenced.
	 * </ul>
	 *
	 * The value  of precision is interpreted according to the conversion applied.
	 *
	 * <b>Conversions</b>
	 *
	 * A valid conversion is a single character from the following list:
	 *
	 * <table class=options>
	 *     <trh><th>Character</th><th>Description</th></tr>
	 *     <tr><td>%</td><td>
	 *			The percent (%) character itself is printed. The width field and alignment flag
	 *			are used to pad the field. Other flags and fields are ignored. No argument is
	 *			fetched from the argument list, but the identity of the last referenced argument
	 *			is set if the format specifier includes an argument index.
	 *     </td></tr>
	 *     <tr><td>c</td><td>
	 *			The next argument must be an integer. It's value is interpreted as a Unicode code point
	 *			and the corresponding character is written as UTF-8 text. If the value is not a valid Unicode code point,
	 *			an IllegalArgumentException is thrown. Precision is ignored.
	 *     </td></tr>
	 *     <tr><td>d</td><td>
	 *			The next argument must be a number. The value is converted to long and formatted
	 *			as a string of decimal digits. Leading zero digits are added to ensure that the
	 *			number of characters of output are at least the precision. The flags determine
	 *			how sign is written and whether grouping separators are used in the number.
	 *     </td></tr>
	 *     <tr><td>e, E</td><td>
	 *			Scientific notation decimal value.
	 *			<p>
	 *			The next argument must be a number. The value is converted to double and formatted
	 *			as a single digit, a locale-specific decimal point character, a string of decimal
	 *			digits representing the fraction with as many digits as specified by the precision,
	 *			followed by an exponent.
	 *			<p>
	 *			If the precision is not included in the format specifier the default precision is 6.
	 *			<p>
	 *			The exponent consists of an e or E (corresponding to the conversion character), a
	 *			locale-specific sign character and at least two decimal digits.
	 *     </td></tr>
	 *     <tr><td>f</td><td>
	 *			Fixed decimal point value.
	 *			<p>
	 *			The next argument must be a number. The value is converted to double and formatted
	 *			as one or more decimal digits, a locale-specific decimal point character, and a string
	 *			of decimal digits representing the fraction with as many digits as specified by the precision.
	 *			<p>
	 *			If the precision is not included in the format specifier the default precision is 6.
	 *     </td></tr>
	 *     <tr><td>g, G</td><td>
	 *			The next argument must be a number. The value is converted to double and formatted
	 *			using either fixed or scientific notation, whichever is shorter. If scientific notation
	 *			is used, the exponent begins with a lower-case letter e if this conversion character is
	 *			lower-case, otherwise an upper-case E is printed.
	 *     </td></tr>
	 *     <tr><td>p</td><td>
	 *			The next argument must be an address. The value is formatted in a manner consistent with
	 *			the way that address values are typically displayed on the system in question. Typically
	 *			this will be some form of hexadecimal display.
	 *     </td></tr>
	 *     <tr><td>s</td><td>
	 *			The next argument must be a {@link boolean}, {@link string}, {@link string16} or a 
	 *			{@code pointer<byte>}. Each type is converted to a Unicode string and written to the
	 *			output stream as utf-8 text. Width and precision are applied in terms of Unicode characters
	 *			not bytes. Thus a character that requires two or three bytes of utf-8 encoding would only
	 *			count as a single character for width or precision effects.
	 *			<p>
	 *			<table class=options>
	 *				<tr><th>Type</th><th>Formatting</th></tr>
	 *				<tr><td>boolean</td><td>
	 *					The value is converted to string. The result is either the string {@code true} or 
	 *					{@code false}.
	 *				</td></tr>
	 *				<tr><td>string</td><td>
	 *					The bytes of the string are converted to Unicode characters and then written 
	 *					encoded using utf-8. If any bytes of the string are not valid utf-8 encoded characters,
	 *					they are converted to Unicode substituTe characters.
	 *				</td></tr>
	 *				<tr><td>string16</td><td>
	 *					The string16 text is converted from utf-16 to utf-8.
	 *				</td></tr>
	 *				<tr><td>pointer<byte></td><td>
	 *					A string is constructed from the pointer value, thus including all bytes at
	 *					the pointer location up to the next null byte. The resulting string is then
	 *					converted to a number of Unicode characters and then encoded in utf-8. If any 
	 *					bytes of the CONSTRUCTED string are not valid utf-8 encoded characters,
	 *					they are converted to Unicode substituTe characters.
	 *				</td></tr>
	 *			</table>
	 *			<p>
	 *			Padding is applied sufficient to ensure at least width characters are written.
	 *			<p>
	 *			If a precision is specified then the initial characters of the text will be written
	 *			up to the value of precision. 
	 *     </td></tr>
	 *     <tr><td>t, T</td><td>
	 *			The next argument must be a long or a {@link parasol:time.Time Time} object. If the
	 *			argument is a long, a Time object is constructed from it. The resulting time value is then
	 *			formatted according to the second conversion character.
	 *			<p>
	 *			<table class=options>
	 *				<tr><th>Time Conversion</th><th>Formatting</th></tr>
	 *				<tr><td>a</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>A</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>b</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>B</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>c</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>C</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>d</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>D</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>e</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>F</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>H</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>I</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>j</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>k</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>l</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>L</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>m</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>M</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>N</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>p</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>Q</td><td>
	 *					Milliseconds since the beginning of the epoch, January 1, 1970 00:00:00 UTC.
	 *				</td></tr>
	 *				<tr><td>r</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>R</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>s</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>S</td><td>
	 *					Seconds since the beginning of the epoch, January 1, 1970 00:00:00 UTC.
	 *				</td></tr>
	 *				<tr><td>T</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>y</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>Y</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>z</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *				<tr><td>z</td><td>
	 *					Not yet implemented.
	 *				</td></tr>
	 *			</table>
	 *			<p>
	 *			Precision is ignored.
	 *     </td></tr>
	 *     <tr><td>x, X</td><td>
	 *			The next argument must be a number. The value is converted to long and formatted
	 *			as a string of hexadecimal digits. Leading zero digits are added to ensure that the
	 *			number of characters of output are at least the precision.
	 *			<p>
	 *			Any alphabetic characters in the output are lower-case if the conversion character is
	 *			lower-case, otherwise they are upper-case.
	 *			<p>
	 *			If the alternate form flag (#) is present, a leading {@code 0x} is added to the
	 *			field value. 
	 *     </td></tr>
	 * </table>
	 *
	 * @param format The format string to print
	 * @param arguments The argument list to print using the given format
	 *
	 * @return The number of bytes printed. Because of UTF encoding, this may be more than the number
	 * of Unicode characters written.
	 *
	 * @exception BoundsException Thrown when a formatting specifier designates an
	 * out-of-bounds elemenet in the arguments array.
	 * @exception IllegalArgumentExceptio Thrown when a formatting specifier is malformed
	 * in some way. The message should provide additional detail.
	 *
	 * @exception IOException Thrown if any error condition was encountered writing to the stream.
	 *
	 * @exception IllegalOperationException Thrown if the stream has exceeded the capacity of the output
	 * and cannot accept any more data.
	 */
	public int printf(string format, var... arguments) {
		ref<international.Locale> locale;
		int bytesWritten = 0;
		int nextArgument = 0;
		for (int i = 0; i < format.length(); i++) {
			if (format[i] == '%') {
				enum ParseState {
					INITIAL,
					INITIAL_DIGITS,
					AFTER_LT,
					IN_FLAGS,
					IN_WIDTH,
					BEFORE_DOT,
					AFTER_DOT,
					IN_PRECISION,
					AT_FORMAT,
					ERROR
				}
				
				ParseState current = ParseState.INITIAL;
				int accumulator = 0;
								
				int width = 0;
				boolean widthSpecified = false;
				int precision = 0;
				boolean precisionSpecified = false;
				
				// flags
				
				boolean leftJustified = false;
				boolean alternateForm = false;
				boolean alwaysIncludeSign = false;
				boolean leadingSpaceForPositive = false;
				boolean zeroPadded = false;
				boolean groupingSeparators = false;
				boolean negativeInParentheses = false;
				
				int formatStart = i;
				boolean done = false;
				do {
					i++;
					if (i < format.length()) {
						switch (format[i]) {
						case	'*':
							switch (current) {
							case INITIAL:
							case IN_FLAGS:
								width = int(arguments[nextArgument]);
								widthSpecified = true;
								nextArgument++;
								current = ParseState.BEFORE_DOT;
								break;
								
							case AFTER_DOT:
								precision = int(arguments[nextArgument]);
								precisionSpecified = true;
								nextArgument++;
								current = ParseState.AT_FORMAT;
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
							
						case	'<':
							switch (current) {
							case INITIAL:
								if (nextArgument > 0)
									current = ParseState.AFTER_LT;
								else
									throw new IllegalArgumentException("<$ on first formatting specifier");
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
							
						case	'0':
							switch (current) {
							case INITIAL:
								current = ParseState.IN_FLAGS;
							case IN_FLAGS:
								zeroPadded = true;
								break;
								
							case INITIAL_DIGITS:
							case IN_WIDTH:
							case IN_PRECISION:
								accumulator *= 10;
								break;

							case AFTER_DOT:
								current = ParseState.IN_PRECISION;
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
							
						case	'1':
						case	'2':
						case	'3':
						case	'4':
						case	'5':
						case	'6':
						case	'7':
						case	'8':
						case	'9':
							accumulator = accumulator * 10 + (format[i] - '0');
							switch (current) {
							case INITIAL:
								current = ParseState.INITIAL_DIGITS;
								break;
								
							case IN_FLAGS:
								current = ParseState.IN_WIDTH;
								break;
								
							case AFTER_DOT:
								current = ParseState.IN_PRECISION;
								break;
								
							case INITIAL_DIGITS:
							case IN_WIDTH:
							case IN_PRECISION:
								break;

							default:
								current = ParseState.ERROR;
							}
							break;
							
						case	'-':
							switch (current) {
							case INITIAL:
								current = ParseState.IN_FLAGS;
							case IN_FLAGS:
								leftJustified = true;
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
						
						case	'+':
							switch (current) {
							case INITIAL:
								current = ParseState.IN_FLAGS;
							case IN_FLAGS:
								alwaysIncludeSign = true;
							break;
							
						default:
							current = ParseState.ERROR;
						}
						break;

						case	' ':
							switch (current) {
							case INITIAL:
								current = ParseState.IN_FLAGS;
							case IN_FLAGS:
								leadingSpaceForPositive = true;
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
						
						case	'#':
							switch (current) {
							case INITIAL:
								current = ParseState.IN_FLAGS;
							case IN_FLAGS:
								alternateForm = true;
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
						
						case	',':
							switch (current) {
							case INITIAL:
								current = ParseState.IN_FLAGS;
							case IN_FLAGS:
								groupingSeparators = true;
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
						
						case	'(':
							switch (current) {
							case INITIAL:
								current = ParseState.IN_FLAGS;
							case IN_FLAGS:
								negativeInParentheses = true;
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
												
						case	'$':
							switch (current) {
							case INITIAL_DIGITS:
								nextArgument = accumulator;
								accumulator = 0;
								
							case AFTER_LT:
								nextArgument--;
								current = ParseState.IN_FLAGS;
								break;
								
							default:
								current = ParseState.ERROR;
							}
							break;
							
						case	'.':
							switch (current) {
							case INITIAL:
							case INITIAL_DIGITS:
							case IN_WIDTH:
								width = accumulator;
								widthSpecified = true;
								accumulator = 0;
							case BEFORE_DOT:
								current = ParseState.AFTER_DOT;
								break;
							
							default:
								current = ParseState.ERROR;
							}
							break;
							
						default:
							switch (current) {
							case IN_PRECISION:
								precision = accumulator;
								precisionSpecified = true;
								break;
								
							case INITIAL_DIGITS:
							case IN_WIDTH:
								width = accumulator;
								widthSpecified = true;
								break;
								
							case INITIAL:
							case AT_FORMAT:
							case BEFORE_DOT:
								break;
							
							case AFTER_DOT:
								current = ParseState.ERROR;
							}
							if (precision > width)
								width = precision;
							switch (format[i]) {
							case	'd':
								long ivalue = long(arguments[nextArgument]);
								nextArgument++;
								string formatted(ivalue);
								int nextChar = 0;
								
								int actualLength = 0;
								if (ivalue >= 0) {
									if (alwaysIncludeSign || leadingSpaceForPositive)
										actualLength++;
								} else {
									nextChar++;
									actualLength++;
									int negs = 1;
									if (negativeInParentheses) {
										actualLength++;
										negs = 2;
									}
									if (zeroPadded) {
										if (precision < width - negs)
											precision = width - negs;
									}
								}
								if (precision > formatted.length() - nextChar)
									actualLength += precision;
								else
									actualLength += formatted.length() - nextChar;

								if (groupingSeparators) {
									if (locale == null)
										locale = international.myLocale();
									actualLength += countGrouping(formatted.length() - nextChar, locale.decimalStyle()) * locale.decimalStyle().groupSeparator.length();
								}
								if (!leftJustified) {
									while (width > actualLength) {
										_write(byte(zeroPadded ? '0' : ' '));
										width--;
										bytesWritten++;
									}
								}
								if (ivalue >= 0) {
									if (alwaysIncludeSign) {
										if (locale == null)
											locale = international.myLocale();
										bytesWritten += write(locale.decimalStyle().positiveSign);
									} else if (leadingSpaceForPositive) {
										_write(' ');
										bytesWritten++;
									}
								} else {
									if (locale == null)
										locale = international.myLocale();
									if (negativeInParentheses)
										bytesWritten += write("(");
									else
										bytesWritten += write(locale.decimalStyle().negativeSign);
								}
								if (groupingSeparators) {
									formatted = insertSeparators(&formatted[nextChar], formatted.length() - nextChar, locale.decimalStyle());
									nextChar = 0;
								}
								
								while (precision > formatted.length() - nextChar) {
									_write('0');
									precision--;
									bytesWritten++;
								}
								while (nextChar < formatted.length()) {
									_write(formatted[nextChar]);
									nextChar++;
									bytesWritten++;
								}
								if (ivalue < 0 && negativeInParentheses)
									bytesWritten += write(")");
								if (leftJustified) {
									while (width > actualLength) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								break;
								
							case	'e':
							case	'E':
								double value = double(arguments[nextArgument]);
								nextArgument++;
								if (!precisionSpecified)
									precision = 6;
								int decimalPoint;
								int sign;
								string sep;
								pointer<byte> result = C.ecvt(value, precision + 1, &decimalPoint, &sign);
								if (value == 0)
									sign = 0;
								actualLength = precision + 6;
								if (locale == null)
									locale = international.myLocale();
								sep = locale.decimalStyle().decimalSeparator;
								actualLength += sep.length();
								if (sign != 0 || alwaysIncludeSign || leadingSpaceForPositive)
									actualLength++;
								if (!leftJustified) {
									while (actualLength < width) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								if (sign != 0)
									bytesWritten += write(locale.decimalStyle().negativeSign);
								else if (alwaysIncludeSign)
									bytesWritten += write(locale.decimalStyle().positiveSign);
								else if (leadingSpaceForPositive) {
									_write(' ');
									bytesWritten++;
								}
								_write(result[0]);
								bytesWritten += write(sep);
								write(result + 1, precision);
								_write(format[i]);
								printf("%+2.2d", decimalPoint);
								bytesWritten += 6;
								while (actualLength < width) {
									_write(' ');
									width--;
									bytesWritten++;
								}
								break;
								
							case	'f':
								value = double(arguments[nextArgument]);
								nextArgument++;
								if (!precisionSpecified)
									precision = 6;
								if (locale == null)
									locale = international.myLocale();
								sep = locale.decimalStyle().decimalSeparator;
								result = C.fcvt(value, precision, &decimalPoint, &sign);
								actualLength = decimalPoint + precision;
								if (precision > 0)
									actualLength += sep.length();
								if (sign != 0 || alwaysIncludeSign || leadingSpaceForPositive)
									actualLength++;
								if (!leftJustified) {
									while (actualLength < width) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								if (sign != 0)
									bytesWritten += write(locale.decimalStyle().negativeSign);
								else if (alwaysIncludeSign)
									bytesWritten += write(locale.decimalStyle().positiveSign);
								else if (leadingSpaceForPositive) {
									_write(' ');
									bytesWritten++;
								}
								if (decimalPoint > 0) {
									if (groupingSeparators) {
										string formatted = insertSeparators(&result[0], decimalPoint, locale.decimalStyle());
										bytesWritten += write(formatted);
									} else
										bytesWritten += int(write(result, decimalPoint));
								}
								if (precision > 0) {
									bytesWritten += write(sep);
									if (decimalPoint < 0) {
										for (int i = -decimalPoint; i > 0 && precision > 0; i--, precision--)
											bytesWritten += writeCodePoint(locale.decimalStyle().zeroDigit);
										decimalPoint = 0;
									}
									write(result + decimalPoint, precision);
									bytesWritten += precision;
								}
								while (actualLength < width) {
									_write(' ');
									width--;
									bytesWritten++;
								}
								break;
								
							case	'g':
							case	'G':
								value = double(arguments[nextArgument]);
								nextArgument++;
								string buffer;
								buffer.resize(80);
								if (!precisionSpecified)
									precision = 6;
								C.gcvt(value, precision, &buffer[0]);
								for (pointer<byte> b = &buffer[0]; *b != 0; b++) {
									if (*b == 'e') {
										if (format[i] == 'G')
											*b = 'E';
										b += 2; // skip the sign
										if (*b == '0' && b[1] != 0 && b[2] != 0) {
											pointer<byte> bnext = b + 1;
											
											while (*bnext == '0')
												bnext++;
											if (bnext[1] == 0)
												b++;
											C.strcpy(b, bnext);
										}
										break;
									}
								}
								int resultLen = C.strlen(&buffer[0]);
								actualLength = resultLen;
								if (value >= 0) {
									if (alwaysIncludeSign || leadingSpaceForPositive)
										actualLength++;
								}
								if (!leftJustified) {
									while (actualLength < width) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								if (value >= 0) {
									if (alwaysIncludeSign) {
										_write('+');
										bytesWritten++;
									} else if (leadingSpaceForPositive) {
										_write(' ');
										bytesWritten++;
									}
								}
								write(&buffer[0], resultLen);
								while (actualLength < width) {
									_write(' ');
									width--;
									bytesWritten++;
								}
								break;
								
							case	'p':
							case	'x':
							case	'X':
								ivalue = long(arguments[nextArgument]);
								nextArgument++;
								string hex();
								
								if (!precisionSpecified)
									precision = 1;
								if (alternateForm) {
									hex.append('0');
									if (format[i] == 'X')
										hex.append('X');
									else
										hex.append('x');
								}
								int digitCount = 16;
								while ((ivalue & 0xf000000000000000) == 0 && digitCount > precision) {
									ivalue <<= 4;
									digitCount--;
								}
								for (int k = 0; k < digitCount; k++) {
									int digit = int(ivalue >>> 60);
									if (digit < 10)
										hex.append('0' + digit);
									else if (format[i] == 'X')
										hex.append(('A' - 10) + digit);
									else
										hex.append(('a' - 10) + digit);
									ivalue <<= 4;
								}
								if (!leftJustified) {
									while (width > hex.length()) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								write(hex);
								bytesWritten += hex.length();
								if (leftJustified) {
									while (width > hex.length()) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								break;
								
							case	'i':
							case	'u':
							case	'o':
							case	'n':		// write to integer pointer parameter
								current = ParseState.ERROR;
								break;
								
							case	'%':
								if (!leftJustified) {
									while (width > 1) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								_write('%');
								bytesWritten++;
								if (leftJustified) {
									while (width > 1) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								break;
								
							case	'c':
								// Interpret the argument as a Unicode code point. Emit it as UTF8.
								int c = int(arguments[nextArgument]);
								nextArgument++;
								if (!leftJustified) {
									while (width > 1) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								if (!precisionSpecified || precision >= 1) {
									text.UTF8Encoder e(this);
									bytesWritten += e.encode(c);
								}
								if (leftJustified) {
									while (width > 1) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								break;
								
							case	's':
								pointer<byte> cp;
								int len;
								string s;
								
								if (arguments[nextArgument].class == pointer<byte>) {
									cp = pointer<byte>(arguments[nextArgument]);
									if (cp == null) {
										s = "<null>";
										cp = s.c_str();
										len = s.length();
									} else {
										len = C.strlen(cp);
									}
									nextArgument++;
								} else if (arguments[nextArgument].class == string) {
									s = string(arguments[nextArgument]);
									if (s == null)
										s = "<null>";
									nextArgument++;
									cp = s.c_str();
									len = s.length();
								} else if (arguments[nextArgument].class == string16) {
									s = string(string16(arguments[nextArgument]));

									if (s == null)
										s = "<null>";
									nextArgument++;
									cp = s.c_str();
									len = s.length();
								} else if (arguments[nextArgument].class == boolean) {
									s = string(boolean(arguments[nextArgument]));
									nextArgument++;
									cp = s.c_str();
									len = s.length();
								} else {
									current = ParseState.ERROR;
									break;
								}
								if (!leftJustified) {
									while (width > len) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								
								if (precisionSpecified && precision < len)
									len = precision;
								write(cp, len);
								if (leftJustified) {
									while (width > len) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								break;
							
							case	't':
							case	'T':
								if (i + 1 >= format.length()) {
									current = ParseState.ERROR;
									break;
								}
								i++;
								Time t;

								if (arguments[nextArgument].class == long)
									t = Time(long(arguments[nextArgument]));
								else
									t = Time(arguments[nextArgument]);
								switch (format[i]) {
								case	'a':
								case	'A':
								case	'b':
								case	'B':
								case	'c':
								case	'C':
								case	'd':
								case	'D':
								case	'e':
								case	'F':
								case	'H':
								case	'I':
								case	'j':
								case	'k':
								case	'l':
								case	'L':
								case	'm':
								case	'M':
								case	'N':
								case	'p':
									current = ParseState.ERROR;
									break;

								case	'Q':
									buffer.printf("%d", t.value());
									break;

								case	'r':
								case	'R':
									current = ParseState.ERROR;
									break;

								case	's':
									buffer.printf("%d", t.value() / MILLIS_PER_SECOND);
									break;

								case	'S':
								case	'T':
								case	'y':
								case	'Y':
								case	'z':
								case	'Z':
								default:
									current = ParseState.ERROR;
									break;
								}
								if (current == ParseState.ERROR)
									break;
								len = buffer.length();
								if (!leftJustified) {
									while (width > len) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}

								write(&buffer[0], len);
								if (leftJustified) {
									while (width > len) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								break;

							default:
								current = ParseState.ERROR;
							}
							done = true;
						}
					} else
						current = ParseState.ERROR;
					if (current == ParseState.ERROR) {
						while (formatStart <= i) {
							_write(format[formatStart]);
							formatStart++;
							bytesWritten++;
						}
						break;
					}
				} while (!done);
			} else {
				_write(format[i]);
				bytesWritten++;
			}
		}
		return bytesWritten;
	}
}

private int countGrouping(int digits, ref<international.DecimalStyle> style) {
	byte lastGrouping = 0;
	int separators = 0;
	for (i in style.grouping) {
		byte b = style.grouping[i];
		switch (b) {
		case byte.MAX_VALUE:
			return separators;

		case 0:
			if (lastGrouping == 0)
				return 0;
			else
				return separators + (digits - 1) / lastGrouping;

		default:
			if (b >= digits)
				return separators;
			digits -= b;
			lastGrouping = b;
			separators++;
		}
	}
	return separators;
}

private string insertSeparators(pointer<byte> digits, int length, ref<international.DecimalStyle> style) {
	byte lastGrouping = 0;
	int separatedDigits = 0;
	int remaining = length;
	pointer<byte> grouping = &style.grouping[style.grouping.length() - 1];
	string result;
	for (i in style.grouping) {
		if (style.grouping[i] != byte.MAX_VALUE)
			separatedDigits += style.grouping[i];
		if (separatedDigits >= length) {
			// This pathway handles the case where the digit string is not longer than the sum of the separations listed.
			separatedDigits -= style.grouping[i];

			while (separatedDigits < length) {
				result.append(*digits);
				digits++;
				length--;
			}
			while (i > 0) {
				result.append(style.groupSeparator);
				i--;
				int g = style.grouping[i];
				result.append(digits, g);
				digits += g;
			}
			return result;
		}
	}
	if (*grouping == 0) {
		if (grouping == &style.grouping[0])
			return string(digits, length);			// This is the weird case where a grouping string is just a 0 byte.
		// This is the case where the last grouping is repeated, like US locales do.
		grouping--;
		int rem = (length - separatedDigits) % *grouping;
		if (rem == 0)
			rem = *grouping;
		result.append(digits, rem);
		digits += rem;
		length -= rem;
		while (separatedDigits < length) {
			result.append(style.groupSeparator);
			result.append(digits, *grouping);
			digits += *grouping;
			length -= *grouping;
		}
	} else {
		if (grouping == &style.grouping[0])
			return string(digits, length);			// This is the weird case where a grouping string is just a MAX_VALUE byte.
		// This is the case where separations end. We also know separatedDigits < length.
		int rem = length - separatedDigits;
		result.append(digits, rem);
		digits += rem;
		length -= rem;
	}
	while (grouping >= &style.grouping[0]) {
		result.append(style.groupSeparator);
		result.append(digits, *grouping);
		digits += *grouping;
		grouping--;
	}
	return result;
}
/**
 * Write bytes to a buffer.
 *
 * This Writer can be used to deserialize a Parasol object, or an array of objects.
 * In general, it is only portable to deserialize such data into the same object type
 * as was serialized using a {@link BufferReader}.
 *
 * It is portable to assume that the first bytes of elements of an array of objects are the bytes of
 * the first element selected for the BufferWriter. The elements of an array are written in
 * ascending index order.
 */
public class BufferWriter extends Writer {
	pointer<byte> _buffer;
	long _length;
	/**
	 * Construct from a region of storage.
	 *
	 * If the address passed in the buffer parameter is a simple object, it is an error
	 * to pass a length that is not the number of bytes in the class of the object.
	 *
	 * If the address passed in the buffer parameter is in an array of objects, it is an
	 * error to pass a length that is not a multiple of the number of bytes in the class
	 * of the array elements. Further, the range of object instances shall appear correctly
	 * within and correctly align with the elements of the array.
	 *
	 * @param buffer The address of an object in memory.
	 * @param length The maximum number of bytes to write.
	 */
	public BufferWriter(address buffer, long length) {
		_buffer = pointer<byte>(buffer);
		_length = length;
	}
	/**
	 * Construct from a byte array.
	 *
	 * @param buffer A non-null reference to the array object.
	 */
	public BufferWriter(ref<byte[]> buffer) {
		_buffer = &(*buffer)[0];
		_length = buffer.length();
	}

	public int _write(byte c) {
		if (_length > 0) {
			_length--;
			return *_buffer++;
		} else
			throw IllegalOperationException(string(c));
		return -1;
	}
}

