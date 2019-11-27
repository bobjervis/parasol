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
import parasol:text.string16;
import parasol:exception.BoundsException;
import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;

import native:C;

@Constant
int MILLIS_PER_SECOND = 1000;
/**
 * The Unicode code point for the replacement character, used to substitute in a malformed input
 * stream for incorrect UTF encodings. It has the hexadecimal value of 0xFFFD.
 */
@Constant
public int REPLACEMENT_CHARACTER = 0xfffd;
/**
 * This converter will read a stream of UTF-8 byte text and return a UTF-32 stream
 * of Unicode code points.
 */
public class UTF8Reader {
	private ref<Reader> _reader;
	/*
	 * _lastChar is the last value returned by read
	 */

	private int _lastChar;
	/*
	 * _lastByte is the last byte read and pushed back  
	 */
	private int _lastByte;
	private int _errorByte;
	/**
	 * Constructs this Reader to consume the contents of the Reader object passed in.
	 *
	 * @param reader The byte-stream reader to use to obtain the Unicode data.
	 */
	public UTF8Reader(ref<Reader> reader) {
		_reader = reader;
		_lastByte = -1;
	}
	/**
	 * Read the next Unicode code point from the UTF-8 stream.
	 *
	 * @return The next Unicode code point in the stream. If the stream is not
	 * well-formed UTF-8, then a value of {@link REPLACEMENT_CHARACTER} is returned and the 
	 * incorrectly coded byte is skipped. The value of the skipped byte can be obtained by calling
	 * the {@link errorByte} method.
	 */
	public int read() {
		if (_lastChar < 0) {	// did we have EOF or an unget?
			if (_lastChar == -1)
				return EOF;		// EOF just keep returning EOF
			int result = -2 - _lastChar;
			_lastChar = result;	// unget was called, undo it's effects and return the last char again
			return result;
		}
		int x;
		if (_lastByte >= 0) {
			x = _lastByte;
			_lastByte = -1;
		} else
			x = _reader.read();
		int extraBytes;
		if (x < 0x80) { 		// THis is 7-bit ascii, return as is.
			_lastChar = x;
			return x;
		} else if (x < 0xe0) {
			if (x < 0xc0) {		// this is a trailing multi-byte value, not legal
				_lastChar = REPLACEMENT_CHARACTER;
				_errorByte = x;
				return REPLACEMENT_CHARACTER;
			} else {
				x &= 0x1f;
				extraBytes = 1;			// A two-byte sequence (0-7ff)
			}
		} else {
			if ((x & 0xf0) == 0xe0) {
				x &= 0xf;
				extraBytes = 2;			// A three-byte sequence (0-ffff)
			} else if ((x & 0xf8) == 0xf0) {
				x &= 0x7;
				extraBytes = 3;			// A four-byte sequence (0-1fffff)
			} else if ((x & 0xfc) == 0xf8) {
				x &= 0x3;
				extraBytes = 4;			// A five-byte sequence (0-3ffffff)
			} else if ((x & 0xfe) == 0xfc) {
				x &= 0x1;
				extraBytes = 5;			// A six-byte sequence (0-7fffffff)
			} else {
				_lastChar = REPLACEMENT_CHARACTER;
				_errorByte = x;
				return REPLACEMENT_CHARACTER;
			}
		}
		for (int i = 0; i < extraBytes; i++) {
			int n = _reader.read();
			if ((n & ~0x3f) != 0x80) {				// This is not a continuation byte
				_lastChar = REPLACEMENT_CHARACTER;
				_lastByte = n;
				_errorByte = -(x << (6 * (extraBytes - i)));
				return REPLACEMENT_CHARACTER;
			}
			int increment = n & 0x3f;
			x = (x << 6) + increment;
		}
		_lastChar = x;
		_errorByte = 0;
		return x;
	}
	/**
	 * Reads zero or more Unicode code points into the buffer
	 * argument.
	 *
	 * @param buffer The address where the Unicode code points should be stored.
	 * @param length The maximum number of code points to read into the buffer.
	 *
	 * @return The number of code points actually stored. A return value of zero indicates 
	 * end of stream.
	 */
	public int read(pointer<int> buffer, int length) {
		int count;
		while (length > 0) {
			int c = read();

			if (c == EOF)
				break;

			*buffer++ = c;
			length--;
			count++;
		}
		return count;
	}
	/**
	 * Read into an int array buffer. Code points are read up to the
	 * number of elements in the array. Any existing contents are over-written
	 * starting at index 0.
	 *
	 * @return The number of code points read. A return of 0 indicates end of stream.
	 */
	public int read(ref<int[]> buffer) {
		int count;
		while (count < buffer.length()) {
			int c = read();

			if (c == EOF)
				break;

			(*buffer)[count++] = c;
		}
		return count;
	}
	/**
	 * Ungets the last code point read from the stream. The next call to {@link read} will
	 * returieve the same value again.
	 */
	public void unget() {
		if (_lastChar >= 0)
			_lastChar = -2 - _lastChar;
	}
	/**
	 * The erronoeous byte that triggered the REPLACEMENT_CHARACTER last returned. 
	 *
	 * @return The byte that was unexpected and skipped. A negative value indicates that
	 * one or more bytes of an incomplete multi-byte sequence were processed. The magnitude of
	 * the value contains the high order bits of the bytes that were present. The number of
	 * missing low order bytes is indeterminate.
	 *
	 * If this method is called before any REPLACEMENT_VALUE code points are returned, the value
	 * is zero.
	 * If the stream actually contained a REPLACE_VALUE code point in it, the return value is zero.
 	 */
	public int errorByte() {
		return _errorByte;
	}
}

@Constant
int SURROGATE_START = 0xd800;
@Constant
int HI_SURROGATE_START = 0xd800;
@Constant
int HI_SURROGATE_END = 0xdbff;
@Constant
int LO_SURROGATE_START = 0xdc00;
@Constant
int LO_SURROGATE_END = 0xdfff;
@Constant
int SURROGATE_END = 0xdfff;

/**
 * This converter will read a stream of UTF-16 char text and return a UTF-32 stream
 * of Unicode code points.
 */
public class UTF16Reader {
	private ref<Reader> _reader;
	/*
	 * _lastChar is the last value returned by read
	 */
	private int _lastChar;
	/*
	 * The last code unit read and pushed back
	 */
	private int _lastCodeUnit;
	/**
	 * Constructs this Reader to consume the contents of the Reader object passed in.
	 *
	 * @param reader The byte-stream reader to use to obtain the Unicode data.
	 */
	public UTF16Reader(ref<Reader> reader) {
		_reader = reader;
		_lastCodeUnit = EOF;
	}
	/**
	 * Read the next Unicode code point from the UTF-8 stream.
	 *
	 * @return The next Unicode code point in the stream. If the stream is not
	 * well-formed UTF-16, then a value of {@link REPLACEMENT_CHARACTER} is returned.
	 */
	public int read() {
		if (_lastChar < 0) {	// did we have EOF or an unget?
			if (_lastChar == EOF)
				return EOF;		// EOF just keep returning EOF
			int result = -2 - _lastChar;
			_lastChar = result;	// unget was called, undo it's effects and return the last char again
			return result;
		}
		int x;
		if (_lastCodeUnit >= 0) {
			x = _lastCodeUnit;
			_lastCodeUnit = EOF;
		} else
			x = getCodeUnit();
		if (x < SURROGATE_START || x > SURROGATE_END) {		// Not a surrogate unit, return it as a code point
			_lastChar = x;
			return x;
		}
		if (x >= LO_SURROGATE_START)
			return REPLACEMENT_CHARACTER;		// The x code unit is a low surrogate unit

		_lastCodeUnit = getCodeUnit();
		if (_lastCodeUnit == EOF)
			return REPLACEMENT_CHARACTER;		// There is a high surrogate followed by nothing

		if (_lastCodeUnit < LO_SURROGATE_START || _lastCodeUnit > LO_SURROGATE_END)
			return REPLACEMENT_CHARACTER;		// A high surrogate unit has been followed by a non-low surrogate.

		_lastChar = ((x - HI_SURROGATE_START) << 10) + (_lastCodeUnit - LO_SURROGATE_START) + 0x10000;
		_lastCodeUnit = EOF;
		return _lastChar;
	}

	private int getCodeUnit() {
		int lo = _reader.read();
		if (lo == EOF)
			return EOF;
		int hi = _reader.read();
		if (hi == EOF)
			return EOF;
		return (hi << 8) | lo;
	}
	/**
	 * Reads zero or more Unicode code points into the buffer
	 * argument.
	 *
	 * @param buffer The address where the Unicode code points should be stored.
	 * @param length The maximum number of code points to read into the buffer.
	 *
	 * @return The number of code points actually stored. A return value of zero indicates 
	 * end of stream.
	 */
	public int read(pointer<int> buffer, int length) {
		int count;
		while (length > 0) {
			int c = read();

			if (c == EOF)
				break;

			*buffer++ = c;
			length--;
			count++;
		}
		return count;
	}
	/**
	 * Read into an int array buffer. Code points are read up to the
	 * number of elements in the array. Any existing contents are over-written
	 * starting at index 0.
	 *
	 * @return The number of code points read. A return of 0 indicates end of stream.
	 */
	public int read(ref<int[]> buffer) {
		int count;
		while (count < buffer.length()) {
			int c = read();

			if (c == EOF)
				break;

			(*buffer)[count++] = c;
		}
		return count;
	}
	/**
	 * Ungets the last code point read from the stream. The next call to {@link read} will
	 * returieve the same value again.
	 */
	public void unget() {
		if (_lastChar >= 0)
			_lastChar = -2 - _lastChar;
	}
}
/**
 * This converter will take a stream of UTF-32 Unicode code points and write them as a stream of
 * UTF-8 byte text.
 */
public class UTF8Writer {
	ref<Writer> _writer;
	/**
	 * Constructs this Writer to generate the octets of a UTF-8 text stream to be written as
	 * bytes to the writer parameter.
	 *
	 * @param writer The byte-stream Writer to use to generate the Unicode data.
	 */
	public UTF8Writer(ref<Writer> writer) {
		_writer = writer;
	}
	/**
	 * @param c The code point to write
	 *
	 * @return The number of bytes written to the underlying Writer.
	 *
	 * @exception IllegalArgumentException thrown if an invalid Unicode code point is written to the stream.
	 */
	public int write(int c) {
		unsigned x = unsigned(c);
		if (x > 0x10ffff ||
			(x >= unsigned(SURROGATE_START) && x <= unsigned(SURROGATE_END))) {
			string s;
			s.printf("%d", c);
			throw IllegalArgumentException(s);
		}
		if (c <= 0x7f) {
			_writer.write(byte(c));
			return 1;
		} else if (c <= 0x7ff) {
			_writer.write(byte(0xc0 + (c >> 6)));
			_writer.write(byte(0x80 + (c & 0x3f)));
			return 2;
		} else if (c <= 0xffff) {
			_writer.write(byte(0xe0 + (c >> 12)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
			return 3;
		} else {//if (c <= 0x1fffff) {
			_writer.write(byte(0xf0 + (c >> 18)));
			_writer.write(byte(0x80 + ((c >> 12) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
			return 4;
/*
		} else if (c <= 0x3ffffff) {
			_writer.write(byte(0xf8 + (c >> 24)));
			_writer.write(byte(0x80 + ((c >> 18) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 12) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
			return 5;
		} else if (c <= 0x7fffffff) {
			_writer.write(byte(0xfc + (c >> 30)));
			_writer.write(byte(0x80 + ((c >> 24) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 18) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 12) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
			return 6;
		} else {
			string s;
			s.printf("%d", c);
			throw IllegalArgumentException(s);
 */
		}
		// Bug in flow detector around 'throw' expressions TODO: Fix it.
		return -1;
	}
	/**
	 * Write zero or more Unicode code points to the stream.
	 *
	 * @param buffer The address of an array of Unicde code points.
	 * @param length The number of code points in the array.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 */
	public int write(pointer<int> buffer, int length) {
		int written;
		while (length > 0) {
			written += write(*buffer++);
			length--;
		}
		return written;
	}
	/**
	 * Write zero or more Unicode code points to the stream. The entire
	 * contents of the array are written to the Writer stream.
	 *
	 * @param buffer A reference to an array of Unicde code points.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 */
	public int write(ref<int[]> buffer) {
		int written;
		for (i in *buffer)
			written += write((*buffer)[i]);
		return written;
	}
	/**
	 * Write a UTF-16 char array.
	 * Write zero or more Unicode code points to the stream.
	 *
	 * If the input array contains malformed surrogate pairs, the
	 * malformed pairs are written as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param buffer The address of an array of UTF-16 text.
	 * @param length The number of UTF-16 characters in the array.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 */
	public int write(pointer<char> buffer, int length) {
		BufferReader r(buffer, length * char.bytes);
		UTF16Reader u(&r);

		int written;
		for (;;) {
			int c = u.read();
			if (c == EOF)
				break;
			written += write(c);
		}
		return written;
	}
	/**
	 * Write a UTF-16 char array.
	 * Write zero or more Unicode code points to the stream. The entire
	 * contents of the array are written to the Writer stream.
	 *
	 * If the input array contains malformed surrogate pairs, the
	 * malformed pairs are written as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param buffer A reference ot an array of UTF-16 text.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 */
	public int write(ref<char[]> buffer) {
		BufferReader r(&(*buffer)[0], buffer.length() * char.bytes);
		UTF16Reader u(&r);

		int written;
		for (;;) {
			int c = u.read();
			if (c == EOF)
				break;
			written += write(c);
		}
		return written;
	}
	/**
	 * Write a string.
	 * Write zero or more Unicode code points to the stream.
	 *
	 * No validation is performed on the contents of the string.
	 *
	 * @param s The string to be written.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 *
	 * @exception IllegalArgumentException thrown if an invalid Unicode code point is written to the stream.
	 */
	public int write(string s) {
		BufferReader r(&s[0], s.length());
		UTF8Reader u(&r);

		int written;
		for (;;) {
			int c = u.read();
			if (c == EOF)
				break;
			written += write(c);
		}
		return written;
	}
	/**
	 * Write a string.
	 * Write zero or more Unicode code points to the stream.
	 *
	 * If the input array contains malformed surrogate pairs, the
	 * malformed pairs are written as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param s The string to be written.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 */
	public int write(string16 s) {
		return write(s.c_str(), s.length());
	}
}
/**
 * This converter will take a stream of UTF-32 Unicode code points and write them as a stream of
 * UTF-16 char text.
 */
public class UTF16Writer {
	ref<Writer> _writer;
	/**
	 * Constructs this Writer to generate the octets of a UTF-16 text stream to be written as
	 * bytes to the writer parameter.
	 *
	 * @param writer The byte-stream Writer to use to generate the Unicode data.
	 */
	public UTF16Writer(ref<Writer> writer) {
		_writer = writer;
	}
	/**
	 * Write a code point to the stream.
	 *
	 * If the value is not a valid Unicode code point, a REPLACEMENT_CHARACTER
	 * is written to the Writer.
	 *
	 * @param c The code point to write
	 *
	 * @return The number of chars written to the underlying Writer.
	 */
	public int write(int c) {
		if (c >= 0x10000) {
			if (c > 0x10ffff)
				writeCodeUnit(char(REPLACEMENT_CHARACTER));
			else {
				c -= 0x10000;
				writeCodeUnit(char(HI_SURROGATE_START + (c >> 10)));
				writeCodeUnit(char(LO_SURROGATE_START + (c & 0x3ff)));
				return 2;
			}
		} else if (c >= SURROGATE_START && c <= SURROGATE_END)
			writeCodeUnit(char(REPLACEMENT_CHARACTER));
		else
			writeCodeUnit(char(c));
		return 1;
	}

	private void writeCodeUnit(char c) {
		_writer.write(byte(c & 0xff));
		_writer.write(byte(c >> 8));
	}
	/**
	 * Write zero or more Unicode code points to the stream.
	 *
	 * @param buffer The address of an array of Unicde code points.
	 * @param length The number of code points in the array.
	 *
	 * @return The number of chars written to the underlying Writer.
	 */
	public int write(pointer<int> buffer, int length) {
		int written;
		while (length > 0) {
			written += write(*buffer++);
			length--;
		}
		return written;
	}
	/**
	 * Write zero or more Unicode code points to the stream. The entire
	 * contents of the array are written to the Writer stream.
	 *
	 * @param buffer A reference to an array of Unicde code points.
	 *
	 * @return The number of chars written to the underlying Writer.
	 */
	public int write(ref<int[]> buffer) {
		int written;
		for (i in *buffer)
			written += write((*buffer)[i]);
		return written;
	}
	/**
	 * Write a UTF-16 char array.
	 * Write zero or more Unicode code points to the stream.
	 *
	 * If the input array contains malformed surrogate pairs, the
	 * malformed pairs are written as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param buffer The address of an array of UTF-16 text.
	 * @param length The number of UTF-16 characters in the array.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 */
	public int write(pointer<char> buffer, int length) {
		BufferReader r(buffer, length * char.bytes);
		UTF16Reader u(&r);

		int written;
		for (;;) {
			int c = u.read();
			if (c == EOF)
				break;
			written += write(c);
		}
		return written;
	}
	/**
	 * Write a UTF-16 char array.
	 * Write zero or more Unicode code points to the stream. The entire
	 * contents of the array are written to the Writer stream.
	 *
	 * If the input array contains malformed surrogate pairs, the
	 * malformed pairs are written as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param buffer A reference ot an array of UTF-16 text.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 */
	public int write(ref<char[]> buffer) {
		BufferReader r(&(*buffer)[0], buffer.length() * char.bytes);
		UTF16Reader u(&r);

		int written;
		for (;;) {
			int c = u.read();
			if (c == EOF)
				break;
			written += write(c);
		}
		return written;
	}
	/**
	 * Write a string.
	 * Write zero or more Unicode code points to the stream.
	 *
	 * No validation is performed on the contents of the string.
	 *
	 * @param s The string to be written.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 *
	 * @exception IllegalArgumentException thrown if an invalid Unicode code point is written to the stream.
	 */
	public int write(string s) {
		BufferReader r(&s[0], s.length());
		UTF8Reader u(&r);

		int written;
		for (;;) {
			int c = u.read();
			if (c == EOF)
				break;
			written += write(c);
		}
		return written;
	}
	/**
	 * Write a string.
	 * Write zero or more Unicode code points to the stream.
	 *
	 * If the input array contains malformed surrogate pairs, the
	 * malformed pairs are written as the {@link REPLACEMENT_CHARACTER}.
	 *
	 * @param s The string to be written.
	 *
	 * @return The number of bytes written to the underlying Writer.
	 */
	public int write(string16 s) {
		return write(s.c_str(), s.length());
	}
}
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
	 * Construct from the region of storage.
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
	 * @exception IOException Thrown if any error condition was encountered writing to the stream.
	 */
	protected abstract void _write(byte c);
	/**
	 * Write a byte to the output stream.
	 *
	 * @param c The byte to be written.
	 *
	 * @exception IOException Thrown if any error condition was encountered writing to the stream.
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
	 * @exception IOException Thrown if any error condition was encountered writing to the stream.
	 */
	public int writeCodePoint(int codePoint) {
		UTF8Writer w(this);

		return w.write(codePoint);
	}
	/**
	 * Flush any buffered data to the output stream.
	 *
	 * The call will return when all data has been written to the output stream.
	 *
	 * @exception IOException Thrown if any error condition was encountered writing to the stream.
	 */
	public void flush() {
	}
	/**
	 * Close any external connection associated with the Writer and rekease
	 * any buffered data held by the Writer.
	 *
	 * @exception parasol:exception.IOException Thrown if any error condition was encountered trying to close the stream.
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
	 * @exception IOException Thrown if any error condition was encountered writing to the stream.
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
	 */
	public int write(string s) {
		for (int i = 0; i < s.length(); i++)
			write(s[i]);
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
	 * Write a formatted string
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
	 *           is accessed as an integer.
	 * </ul>
	 *
	 * The value of width shall be non-negative. The value specifies the minimum width in characters. If the actual
	 * number of characters being formatted for the field value is less than the width, then pad characters are
	 * written to ensure that at least the width is filled. What character is used as the pad and whether the padding
	 * is placed on the left or right side of the field characters is determined by flags (see above).
	 *
	 * <b>Precision</b>
	 *
	 * <b>Conversions</b>
	 *
	 * @param format The format string to print
	 * @param arguments The argument list to print using the given format
	 *
	 * @return The number of bytes printed.
	 *
	 * @exception BoundsException Thrown when a formatting specifier designates an
	 * out-of-bounds elemenet in the arguments array.
	 * @exception IllegalArgumentExceptio Thrown when a formatting specifier is malformed
	 * in some way. The message should provides additional detail.
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
							case	'D':
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
								if (decimalPoint > 0)
									bytesWritten += int(write(result, decimalPoint));
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
									UTF8Writer w(this);
									bytesWritten += w.write(c);
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

								if (precisionSpecified && precision < len)
									len = precision;
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

public class BufferWriter extends Writer {
	pointer<byte> _buffer;
	int _length;

	public BufferWriter(address buffer, int length) {
		_buffer = pointer<byte>(buffer);
		_length = length;
	}

	public BufferWriter(ref<byte[]> buffer) {
		_buffer = &(*buffer)[0];
		_length = buffer.length();
	}

	public int _write(byte c) {
		if (_length > 0) {
			_length--;
			return *_buffer++;
		} else
			throw IllegalArgumentException(string(c));
		return -1;
	}
}

