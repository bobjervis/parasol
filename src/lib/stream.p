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

import parasol:storage.File;
import parasol:storage.Seek;
import native:C;

public class UTF8Reader {
	private ref<Reader> _reader;
	/*
	 * _lastChar is the last value returned by getc
	 */
	private int _lastChar;
	/*
	 * _lastByte is the last character read and pushed back  
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
				_lastChar = int.MAX_VALUE;			// unget will turn this into int.MIN_VALUE
				_errorByte = x;
				return int.MAX_VALUE;
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
				_lastChar = int.MAX_VALUE;			// unget will turn this into int.MIN_VALUE
				_errorByte = x;
				return int.MAX_VALUE;
			}
		}
		for (int i = 0; i < extraBytes; i++) {
			int n = _reader.read();
			if ((n & ~0x3f) != 0x80) {				// This is not a continuation byte
				_lastChar = int.MAX_VALUE;			// unget will turn this into int.MIN_VALUE
				_lastByte = n;
				_errorByte = -1;
				return int.MAX_VALUE;
			}
			int increment = n & 0x3f;
			x = (x << 6) + increment;
		}
		_lastChar = x;
		return x;
	}

	public void unget() {
		if (_lastChar >= 0)
			_lastChar = -2 - _lastChar;
	}
	
	public int errorByte() {
		return _errorByte;
	}
}

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
								ivalue = long(arguments[nextArgument]);
								nextArgument++;
								string hex();
								
								if (!precisionSpecified)
									precision = 1;
								if (alternateForm)
									hex.append("0x");
								int digitCount = 16;
								while ((ivalue & 0xf000000000000000) == 0 && digitCount > precision) {
									ivalue <<= 4;
									digitCount--;
								}
								for (int k = 0; k < digitCount; k++) {
									int digit = int(ivalue >>> 60);
									if (digit < 10)
										hex.append('0' + digit);
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
								
							case	'X':
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
