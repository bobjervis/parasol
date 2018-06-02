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
namespace parasol:stream;

import parasol:runtime;
import parasol:storage.File;
import parasol:storage.Seek;
import parasol:time.Time;
import parasol:text.string16;

import native:C;

@Constant
int MILLIS_PER_SECOND = 1000;

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
	
	public UTF8Reader(ref<Reader> reader) {
		_reader = reader;
		_lastByte = -1;
	}
	
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
				_errorByte = -1;
				return REPLACEMENT_CHARACTER;
			}
			int increment = n & 0x3f;
			x = (x << 6) + increment;
		}
		_lastChar = x;
		return x;
	}

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

	public void unget() {
		if (_lastChar >= 0)
			_lastChar = -2 - _lastChar;
	}
	
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

	public UTF16Reader(ref<Reader> reader) {
		_reader = reader;
		_lastCodeUnit = EOF;
	}

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
	
	public UTF8Writer(ref<Writer> writer) {
		_writer = writer;
	}
	
	public int write(int c) {
		if (c <= 0x7f) {
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
		} else if (c <= 0x1fffff) {
			_writer.write(byte(0xf0 + (c >> 18)));
			_writer.write(byte(0x80 + ((c >> 12) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
			return 4;
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
		}
		// Bug in flow detector around 'throw' expressions TODO: Fix it.
		return -1;
	}

	public int write(pointer<int> buffer, int length) {
		int written;
		while (length > 0) {
			written += write(*buffer++);
			length--;
		}
		return written;
	}

	public int write(ref<int[]> buffer) {
		int written;
		for (i in *buffer)
			written += write((*buffer)[i]);
		return written;
	}
	/**
	 * Write a UTF-16 char array
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
	 * Write a UTF-16 char array
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
}
/**
 * This converter will take a stream of UTF-32 Unicode code points and write them as a stream of
 * UTF-16 char text.
 */
public class UTF16Writer {
	ref<Writer> _writer;
	
	public UTF16Writer(ref<Writer> writer) {
		_writer = writer;
	}
	/**
	 * @return The number of 16-bit code units (char's) written.
	 */
	public int write(int c) {
		if (c >= 0x10000) {
			c -= 0x10000;
			writeCodeUnit(char(HI_SURROGATE_START + (c >> 10)));
			writeCodeUnit(char(LO_SURROGATE_START + (c & 0x3ff)));
			return 2;
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

	public int write(pointer<int> buffer, int length) {
		int written;
		while (length > 0) {
			written += write(*buffer++);
			length--;
		}
		return written;
	}

	public int write(ref<int[]> buffer) {
		int written;
		for (i in *buffer)
			written += write((*buffer)[i]);
		return written;
	}
	/**
	 * Write a UTF-8 byte array
	 */
	public int write(pointer<byte> buffer, int length) {
		BufferReader r(buffer, length);
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
	 * Write a UTF-8 byte array
	 */
	public int write(ref<byte[]> buffer) {
		BufferReader r(&(*buffer)[0], buffer.length());
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
	 * Write a string
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
}

@Constant
public int EOF = -1;

public class Reader {
	protected abstract int _read();

	public int read() {
		return _read();
	}

	public void unread() {
	}

	public string, boolean readAll() {
		return "", false;
	}

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
	 */
	public int read(ref<byte[]> buffer) {
		int i;
		for (i = 0; i < buffer.length(); i++) {
			int c = _read();
			if (c == EOF)
				break;
			(*buffer)[i] = byte(c);
		}
		return i;
	}
	/**
	 * Reads text into a char array buffer. 
	 */
	public int read(ref<char[]> buffer) {
		int i;
		for (i = 0; i < buffer.length(); i++) {
			int lo = _read();
			if (lo == EOF)
				break;
			int hi = _read();
			if (hi == EOF)
				break;
			(*buffer)[i] = char(lo | (hi << 8));
		}
		return i;
	}

	public string readLine() {
		string line;

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

	public void close() {
	}
}

public class BufferReader extends Reader {
	pointer<byte> _buffer;
	int _length;

	public BufferReader(address buffer, int length) {
		_buffer = pointer<byte>(buffer);
		_length = length;
	}

	public BufferReader(ref<byte[]> buffer) {
		_buffer = &(*buffer)[0];
		_length = buffer.length();
	}

	public int _read() {
		if (_length > 0) {
			_length--;
			return *_buffer++;
		} else
			return EOF;
	}
}

public class Writer {
	protected abstract void _write(byte c);

	public void write(byte c) {
		_write(c);
	}

	public void flush() {
	}

	public void close() {
	}

	public int write(address buffer, int length) {
		for (int i = 0; i < length; i++)
			_write(pointer<byte>(buffer)[i]);
		return length;
	}

	public int write(string s) {
		for (int i = 0; i < s.length(); i++)
			write(s[i]);
		return s.length();
	}

	public int write(string16 s) {
		return write(s.c_str(), s.length() * char.bytes);
	}

	public int printf(string format, var... arguments) {
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
									current = ParseState.ERROR;
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
								} else
									nextChar++;
								if (precision > formatted.length())
									actualLength += precision;
								else
									actualLength += formatted.length();

								if (!leftJustified) {
									while (width > actualLength) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								if (ivalue >= 0) {
									if (alwaysIncludeSign) {
										_write('+');
										bytesWritten++;
									} else if (leadingSpaceForPositive) {
										_write(' ');
										bytesWritten++;
									}
								} else {
									_write('-');
									bytesWritten++;
								}
								while (precision > formatted.length()) {
									_write('0');
									precision--;
									bytesWritten++;
								}
								while (nextChar < formatted.length()) {
									_write(formatted[nextChar]);
									nextChar++;
									bytesWritten++;
								}
								if (leftJustified) {
									while (width > formatted.length()) {
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
								pointer<byte> result = C.ecvt(value, precision + 1, &decimalPoint, &sign);
								if (value == 0)
									sign = 0;
								actualLength = precision + 7;
								if (sign != 0 || alwaysIncludeSign || leadingSpaceForPositive)
									actualLength++;
								if (!leftJustified) {
									while (actualLength < width) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								if (sign != 0) {
									_write('-');
									bytesWritten++;
								} else if (alwaysIncludeSign) {
									_write('+');
									bytesWritten++;
								} else if (leadingSpaceForPositive) {
									_write(' ');
									bytesWritten++;
								}
								_write(result[0]);
								_write('.');
								write(result + 1, precision);
								_write(format[i]);
								printf("%+2.2d", decimalPoint);
								bytesWritten += 7;
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
								result = C.fcvt(value, precision, &decimalPoint, &sign);
								actualLength = decimalPoint + precision;
								if (precision > 0)
									actualLength++;
								if (sign != 0 || alwaysIncludeSign || leadingSpaceForPositive)
									actualLength++;
								if (!leftJustified) {
									while (actualLength < width) {
										_write(' ');
										width--;
										bytesWritten++;
									}
								}
								if (sign != 0) {
									_write('-');
									bytesWritten++;
								} else if (alwaysIncludeSign) {
									_write('+');
									bytesWritten++;
								} else if (leadingSpaceForPositive) {
									_write(' ');
									bytesWritten++;
								}
								if (decimalPoint > 0) {
									write(result, decimalPoint);
									bytesWritten += decimalPoint;
								}
								if (precision > 0) {
									_write('.');
									bytesWritten++;
									if (decimalPoint < 0) {
										for (int i = -decimalPoint; i > 0 && precision > 0; i--, precision--) {
											_write('0');
											bytesWritten++;
										}
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
								if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
									C.gcvt(value, precision, &buffer[0]);
								} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
									runtime.parasol_gFormat(&buffer[0], buffer.length(), value, precision);
								} else
									assert(false);									
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

