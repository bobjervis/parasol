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

import parasol:file.File;
import parasol:file.Seek;

public class Utf8Reader {
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
	
	public Utf8Reader(ref<Reader> reader) {
		_reader = reader;
		_lastByte = -1;
	}
	
	public int read() {
		if (_lastChar < 0) {	// did we have EOF or an unget?
			if (_lastChar == -1)
				return -1;		// EOF just keep returning EOF
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

public class Utf8Writer {
	ref<Writer> _writer;
	
	public Utf8Writer(ref<Writer> writer) {
		_writer = writer;
	}
	
	public void write(int c) {
		if (c <= 0x7f)
			_writer.write(byte(c));
		else if (c <= 0x7ff) {
			_writer.write(byte(0xc0 + (c >> 6)));
			_writer.write(byte(0x80 + (c & 0x3f)));
		} else if (c <= 0xffff) {
			_writer.write(byte(0xe0 + (c >> 12)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
		} else if (c <= 0x1fffff) {
			_writer.write(byte(0xf0 + (c >> 18)));
			_writer.write(byte(0x80 + ((c >> 12) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
		} else if (c <= 0x3ffffff) {
			_writer.write(byte(0xf8 + (c >> 24)));
			_writer.write(byte(0x80 + ((c >> 18) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 12) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
		} else if (c <= 0x7fffffff) {
			_writer.write(byte(0xfc + (c >> 30)));
			_writer.write(byte(0x80 + ((c >> 24) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 18) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 12) & 0x3f)));
			_writer.write(byte(0x80 + ((c >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (c & 0x3f)));
		}
	}
}

public class Reader {
	public abstract int read();
}

public class Writer {
	public abstract void write(byte c);

	public int write(string s) {
		for (int i = 0; i < s.length(); i++)
			write(s[i]);
		return s.length();
	}

	public int printf(string format, var... args) {
		string s;

		s.printf(format, args);
		return write(s);
	}
}

public class StringReader extends Reader {
	private ref<string> _source;
	private int _cursor;
	
	public StringReader(ref<string> source) {
		_source = source;
	}
	
	public int read() {
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
	
	public void write(byte c) {
		_output.append(c);
	}
}

public class FileReader {
	private File _file;
	
	public FileReader(File file) {
		_file = file;
	}
	
	public int read() {
		return _file.read();
	}
}

