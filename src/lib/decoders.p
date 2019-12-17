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

import parasol:stream;
import parasol:stream.EOF;
import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;

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
 * This class defines the framework for converting text in some external file encoding
 * to a string representation.
 */
public class Decoder {
	/**
	 * The action to take on an input encoding error. Note that for some encodings, all byte
	 * sequences are valid input. For example, all byte values in ISO 8859-1 have Unicode code
	 * points assigned.
	 */
	public enum ErrorAction {
		/**
		 * Replace malformed input with the Unicode REPLACEMENT_CHARACTER character
		 */
		REPLACE,
		/**
		 * Throw an IllegalOperationException exception at the point that malformed input was detected.
		 */
		THROW,
		/**
		 * Ignore the malformed input.
		 */ 
		IGNORE
	}

	private ErrorAction _errorAction;
	private boolean _deleteReader;
	/**
	 * The Reader that the decoder should use for input.
	 */
	protected ref<Reader> _reader;
	/**
	 * Decode from a Reader.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param reader The Reader to use for input.
	 */
	public Decoder(ref<Reader> reader) {
		_reader = reader;
	}
	/**
	 * Decode from a Reader and set the error action.
	 *
	 * @param reader The Reader to use for input.
	 * @param errorAction The action to take on malformed input.	
	 */
	public Decoder(ref<Reader> reader, ErrorAction errorAction) {
		_reader = reader;
		_errorAction = errorAction;
	}
	/**
	 * Decode from a byte array.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param buffer The array to use for input.
	 */
	public Decoder(byte[] buffer) {
		_reader = new stream.BufferReader(&buffer[0], buffer.length());
		_deleteReader = true;
	}
	/**
	 * Decode from a byte array and set the error action.
	 *
	 * @param buffer The array to use for input.
	 * @param errorAction The action to take on malformed input.	
	 */
	public Decoder(byte[] buffer, ErrorAction errorAction) {
		_reader = new stream.BufferReader(&buffer[0], buffer.length());
		_deleteReader = true;
		_errorAction = errorAction;
	}
	/**
	 * Decode from a byte buffer.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param buffer The address to use for input.
	 * @param length The number of bytes to read.
	 */
	public Decoder(address buffer, long length) {
		_reader = new stream.BufferReader(buffer, length);
		_deleteReader = true;
	}
	/**
	 * Decode from a byte buffer and set the error action.
	 *
	 * @param buffer The address to use for input.
	 * @param length The number of bytes to read.
	 * @param errorAction The action to take on malformed input.	
	 */
	public Decoder(address buffer, long length, ErrorAction errorAction) {
		_reader = new stream.BufferReader(buffer, length);
		_deleteReader = true;
		_errorAction = errorAction;
	}

	~Decoder() {
		if (_deleteReader)
			delete _reader;
	}
	/**
	 * Read the next Unicode character from the input source.
	 *
	 * If the Decoder detects an incomplete final character, it should return MALFORMED_INPUT
	 * and then EOF on the next call.
	 *
	 * @return A positive integer Unicode code point on successfully reading the 
	 * next character from the input. Returns -1 (stream.EOF) on end of input.
	 * Returns MALFORMED_INPUT if the next character could not be read because of an encoding
	 * error.
	 */
	protected abstract int _decode();

	@Constant
	protected static int MALFORMED_INPUT = -2;
	/**
	 * Read the next Unicode character from the input source.
	 *
	 * @return A positive integer Unicode code point on successfully reading the
	 * next character from the input.
	 *
	 * @exception IllegalOperationException Thrown if there was malformed input and
	 * the error action was (@link ErrorAction.THROW}.
	 */
	public int decodeNext() {
		for (;;) {
			int c = _decode();
	
			if (c == MALFORMED_INPUT) {
				switch (_errorAction) {
				case REPLACE:
					return REPLACEMENT_CHARACTER;
	
				case THROW:
					throw IllegalOperationException("encoding");
	
				case IGNORE:
					break;
				}
			} else
				return c;
		}
	}
	/**
	 * Decode the input source into a string
	 *
	 * All of the characters of the source stream are read into a string.
	 *
	 * @return A string containing the characters encoded in the source.
	 *
	 * @exception IllegalOperationException Thrown if there was maflormed input and
	 * the error action was (@link ErrorAction.THROW}.
	 */
	public string decode() {
		string s;

		for (;;) {
			int c = decodeNext();

			if (c < 0)
				return s;
			s.append(c);
		}
		return s;
	}
	/**
	 * Decode the input source into a string16
	 *
	 * All of the characters of the source stream are read into a string16.
	 *
	 * @return A string containing the characters encoded in the source.
	 *
	 * @exception IllegalOperationException Thrown if there was maflormed input and
	 * the error action was (@link ErrorAction.THROW}.
	 */
	public string16 decode16() {
		string16 s;

		for (;;) {
			int c = decodeNext();

			if (c < 0)
				return s;
			s.append(c);
		}
		return s;
	}
	/**
	 * Calculate the count of Unicode characters.
	 *
	 * @return The count of decoded Unicode characters.
	 */
	public int count() {
		int result;

		for (;;) {
			int c = decodeNext();

			if (c < 0)
				return result;
			result++;
		}
	}
}
/**
 * This class defines the framework for converting text stored in strings to some specific
 * external file encoding.
 *
 * 
 */
public class Encoder {
	ref<Writer> _writer;
	boolean _deleteWriter;
	/**
	 * Encode some text to a Writer.
	 *
	 * @param writer The Writer to send output to.
	 */
	public Encoder(ref<Writer> writer) {
		_writer = writer;
	}
	/**
	 * Encode some text to a byte array.
	 *
	 * @param buffer The byte array to fill.
	 */
	public Encoder(ref<byte[]> buffer) {
		_writer = new stream.BufferWriter(&(*buffer)[0], buffer.length());
		_deleteWriter = true;
	}
	/**
	 * Encode some text to a buffer.
	 *
	 * @param buffer The address of the buffer to fill.
	 * @param length The size of the buffer in bytes.
	 */
	public Encoder(address buffer, long length) {
		_writer = new stream.BufferWriter(buffer, length);
		_deleteWriter = true;
	}

	~Encoder() {
		if (_deleteWriter)
			delete _writer;
	}
	/**
	 * Write the next Unicode character to the output destination.
	 *
	 * If the method fails, the output is not modified.
	 *
	 * @param codePoint The value of a valid Unicode code point.
	 *
	 * @return The number of bytes output. If the code point could not be mapped, the
	 * return value is zero.
	 *
	 * @exception IllegalArgumentException Thrown if the argument is not a valid Unicode code point.
	 */
	public int encode(int codePoint) {
		if ((unsigned(codePoint) >= unsigned(SURROGATE_START) &&
			 unsigned(codePoint) <= unsigned(SURROGATE_END)) ||
			unsigned(codePoint) > 0x10ffff)
			throw IllegalArgumentException("Invalid code point");
		return _encode(codePoint);
	}
	/**
	 * Encode a verified valid code point to the output.
	 *
	 * @param codePoint The value of a valid Unicode code point.
	 *
	 * @return The number of bytes output. If the code point could not be mapped, the
	 * return value is zero.
	 */
	protected abstract int _encode(int codePoint);
	/**
	 * Encode the contents of a string.
	 *
	 * @param s The string to encode.
	 *
	 * @return true if the entire string could be successfully encoded, false otherwise.
	 */
	public boolean encode(string s) {
		StringReader sr(&s);
		UTF8Decoder d(&sr);

		for (;;) {
			int c = d.decodeNext();

			if (c < 0)
				break;
			if (_encode(c) == 0)
				return false;
		}
		return true;
	}
	/**
	 * Encode the contents of a substring.
	 *
	 * @param s The substring to encode.
	 *
	 * @return true if the entire substring could be successfully encoded, false otherwise.
	 */
	public boolean encode(substring s) {
		SubstringReader sr(&s);
		UTF8Decoder d(&sr);

		for (;;) {
			int c = d.decodeNext();

			if (c < 0)
				break;
			if (_encode(c) == 0)
				return false;
		}
		return true;
	}
	/**
	 * Encode the contents of a string.
	 *
	 * @param s The string to encode.
	 *
	 * @return true if the entire string could be successfully encoded, false otherwise.
	 */
	public boolean encode(string16 s) {
		String16Reader sr(&s);
		UTF16Decoder d(&sr);

		for (;;) {
			int c = d.decodeNext();

			if (c < 0)
				break;
			if (_encode(c) == 0)
				return false;
		}
		return true;
	}
	/**
	 * Encode the contents of a substring.
	 *
	 * @param s The substring to encode.
	 *
	 * @return true if the entire substring could be successfully encoded, false otherwise.
	 */
	public boolean encode(substring16 s) {
		Substring16Reader sr(&s);
		UTF16Decoder d(&sr);

		for (;;) {
			int c = d.decodeNext();

			if (c < 0)
				break;
			if (_encode(c) == 0)
				return false;
		}
		return true;
	}
}
/**
 * A UTF-8 Decoder
 */
public class UTF8Decoder extends Decoder {
	/**
	 * Decode from a Reader.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param reader The Reader to use for input.
	 */
	public UTF8Decoder(ref<Reader> reader) {
		super(reader);
	}
	/**
	 * Decode from a Reader and set the error action.
	 *
	 * @param reader The Reader to use for input.
	 * @param errorAction The action to take on malformed input.	
	 */
	public UTF8Decoder(ref<Reader> reader, ErrorAction errorAction) {
		super(reader, errorAction);
	}
	/**
	 * Decode from a byte array.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param buffer The array to use for input.
	 */
	public UTF8Decoder(byte[] buffer) {
		super(buffer);
	}
	/**
	 * Decode from a byte array and set the error action.
	 *
	 * @param buffer The array to use for input.
	 * @param errorAction The action to take on malformed input.	
	 */
	public UTF8Decoder(byte[] buffer, ErrorAction errorAction) {
		super(buffer, errorAction);
	}
	/**
	 * Decode from a byte buffer.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param buffer The address to use for input.
	 * @param length The number of bytes to read.
	 */
	public UTF8Decoder(address buffer, long length) {
		super(buffer, length);
	}
	/**
	 * Decode from a byte buffer and set the error action.
	 *
	 * @param buffer The address to use for input.
	 * @param length The number of bytes to read.
	 * @param errorAction The action to take on malformed input.	
	 */
	public UTF8Decoder(address buffer, long length, ErrorAction errorAction) {
		super(buffer, length, errorAction);
	}

	protected int _decode() {
		int x = _reader.read();
		int extraBytes;
		if (x < 0x80) 		// This is 7-bit ascii, return as is.
			return x;
		else if (x < 0xe0) {
			if (x < 0xc0) {		// this is a trailing multi-byte value, not legal
				return MALFORMED_INPUT;
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
			} else
				return MALFORMED_INPUT;
		}
		for (int i = 0; i < extraBytes; i++) {
			int n = _reader.read();
			if ((n & ~0x3f) != 0x80) {				// This is not a continuation byte
				return MALFORMED_INPUT;
			}
			int increment = n & 0x3f;
			x = (x << 6) + increment;
		}
		if (x >= SURROGATE_START && x <= SURROGATE_END)
			return MALFORMED_INPUT;
		return x;
	}
}
/**
 * This class implements an Encoder to produce UTF-8 bytes.
 *
 */
public class UTF8Encoder extends Encoder {
	/**
	 * Encode some text to a Writer.
	 *
	 * @param writer The Writer to send output to.
	 */
	public UTF8Encoder(ref<Writer> writer) {
		super(writer);
	}
	/**
	 * Encode some text to a byte array.
	 *
	 * @param buffer The byte array to fill.
	 */
	public UTF8Encoder(ref<byte[]> buffer) {
		super(buffer);
	}
	/**
	 * Encode some text to a buffer.
	 *
	 * @param buffer The address of the buffer to fill.
	 * @param length The size of the buffer in bytes.
	 */
	public UTF8Encoder(address buffer, long length) {
		super(buffer, length);
	}

	protected int _encode(int codePoint) {
		unsigned x = unsigned(codePoint);
		if (x <= 0x7f) {
			_writer.write(byte(x));
			return 1;
		} else if (x <= 0x7ff) {
			_writer.write(byte(0xc0 + (x >> 6)));
			_writer.write(byte(0x80 + (x & 0x3f)));
			return 2;
		} else if (x <= 0xffff) {
			if (x >= unsigned(SURROGATE_START) && x <= unsigned(SURROGATE_END))
				return 0;
			_writer.write(byte(0xe0 + (x >> 12)));
			_writer.write(byte(0x80 + ((x >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (x & 0x3f)));
			return 3;
		} else if (x <= 0x10ffff) {
			_writer.write(byte(0xf0 + (x >> 18)));
			_writer.write(byte(0x80 + ((x >> 12) & 0x3f)));
			_writer.write(byte(0x80 + ((x >> 6) & 0x3f)));
			_writer.write(byte(0x80 + (x & 0x3f)));
			return 4;
		} else
			return 0;
	}
}
/**
 * A UTF-16 Decoder.
 */
public class UTF16Decoder extends Decoder {
	/**
	 * The last code unit read and pushed back.
	 *
	 * If the value is not EOF, then it is a code unit that was previously read.
	 *
	 * This 'push-back' state arises when a hi surrogate is not followed by a low
	 * surrogate. The high surrogate itself is discarded.
	 */
	private int _lastCodeUnit;
	/**
	 * Decode from a Reader.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param reader The Reader to use for input.
	 */
	public UTF16Decoder(ref<Reader> reader) {
		super(reader);
		_lastCodeUnit = EOF;
	}
	/**
	 * Decode from a Reader and set the error action.
	 *
	 * @param reader The Reader to use for input.
	 * @param errorAction The action to take on malformed input.	
	 */
	public UTF16Decoder(ref<Reader> reader, ErrorAction errorAction) {
		super(reader, errorAction);
		_lastCodeUnit = EOF;
	}
	/**
	 * Decode from a byte array.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param buffer The array to use for input.
	 */
	public UTF16Decoder(byte[] buffer) {
		super(buffer);
		_lastCodeUnit = EOF;
	}
	/**
	 * Decode from a byte array and set the error action.
	 *
	 * @param buffer The array to use for input.
	 * @param errorAction The action to take on malformed input.	
	 */
	public UTF16Decoder(byte[] buffer, ErrorAction errorAction) {
		super(buffer, errorAction);
		_lastCodeUnit = EOF;
	}
	/**
	 * Decode from a byte buffer.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param buffer The address to use for input.
	 * @param length The number of bytes to read.
	 */
	public UTF16Decoder(address buffer, long length) {
		super(buffer, length);
		_lastCodeUnit = EOF;
	}
	/**
	 * Decode from a byte buffer and set the error action.
	 *
	 * @param buffer The address to use for input.
	 * @param length The number of bytes to read.
	 * @param errorAction The action to take on malformed input.	
	 */
	public UTF16Decoder(address buffer, long length, ErrorAction errorAction) {
		super(buffer, length, errorAction);
		_lastCodeUnit = EOF;
	}

	protected int _decode() {
		int x;
		if (_lastCodeUnit >= 0) {
			x = _lastCodeUnit;
			_lastCodeUnit = EOF;
		} else {
			x = getCodeUnit();
			if (x == MALFORMED_INPUT)	// There Reader coughed up an odd number of bytes.
				return x;
		}
		if (x < SURROGATE_START || x > SURROGATE_END)		// Not a surrogate unit, return it as a code point
			return x;

		if (x >= LO_SURROGATE_START)
			return MALFORMED_INPUT;		// The x code unit is a low surrogate unit

		_lastCodeUnit = getCodeUnit();

		if (_lastCodeUnit < LO_SURROGATE_START || _lastCodeUnit > LO_SURROGATE_END)
										// true for either EOF or MALFORMED_INPUT as well as non-low surrogates
			return MALFORMED_INPUT;		// A high surrogate unit has been followed by a non-low surrogate.

		x = ((x - HI_SURROGATE_START) << 10) + (_lastCodeUnit - LO_SURROGATE_START) + 0x10000;
		_lastCodeUnit = EOF;
		return x;
	}

	private int getCodeUnit() {
		int lo = _reader.read();
		if (lo == EOF)
			return EOF;
		int hi = _reader.read();
		if (hi == EOF)
			return MALFORMED_INPUT;
		return (hi << 8) | lo;
	}
}
/**
 * This class implements an Encoder to produce UTF-16 bytes.
 *
 */
public class UTF16Encoder extends Encoder {
	/**
	 * Encode some text to a Writer.
	 *
	 * @param writer The Writer to send output to.
	 */
	public UTF16Encoder(ref<Writer> writer) {
		super(writer);
	}
	/**
	 * Encode some text to a byte array.
	 *
	 * @param buffer The byte array to fill.
	 */
	public UTF16Encoder(ref<byte[]> buffer) {
		super(buffer);
	}
	/**
	 * Encode some text to a buffer.
	 *
	 * @param buffer The address of the buffer to fill.
	 * @param length The size of the buffer in bytes.
	 */
	public UTF16Encoder(address buffer, long length) {
		super(buffer, length);
	}

	protected int _encode(int codePoint) {
		if (codePoint >= 0x10000) {
			if (codePoint > 0x10ffff)
				writeCodeUnit(char(REPLACEMENT_CHARACTER));
			else {
				codePoint -= 0x10000;
				writeCodeUnit(char(HI_SURROGATE_START + (codePoint >> 10)));
				writeCodeUnit(char(LO_SURROGATE_START + (codePoint & 0x3ff)));
				return 4;
			}
		} else if (codePoint >= SURROGATE_START && codePoint <= SURROGATE_END)
			writeCodeUnit(char(REPLACEMENT_CHARACTER));
		else
			writeCodeUnit(char(codePoint));
		return 2;
	}

	private void writeCodeUnit(char c) {
		_writer.write(byte(c & 0xff));
		_writer.write(byte(c >> 8));
	}
}
/**
 * An ISO 8859-1 Decoder.
 */
public class ISO8859_1Decoder extends Decoder {
	/**
	 * Decode from a Reader.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param reader The Reader to use for input.
	 */
	public ISO8859_1Decoder(ref<Reader> reader) {
		super(reader);
	}
	/**
	 * Decode from a Reader and set the error action.
	 *
	 * @param reader The Reader to use for input.
	 * @param errorAction The action to take on malformed input.	
	 */
	public ISO8859_1Decoder(ref<Reader> reader, ErrorAction errorAction) {
		super(reader, errorAction);
	}
	/**
	 * Decode from a byte array.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param buffer The array to use for input.
	 */
	public ISO8859_1Decoder(byte[] buffer) {
		super(buffer);
	}
	/**
	 * Decode from a byte array and set the error action.
	 *
	 * @param buffer The array to use for input.
	 * @param errorAction The action to take on malformed input.	
	 */
	public ISO8859_1Decoder(byte[] buffer, ErrorAction errorAction) {
		super(buffer, errorAction);
	}
	/**
	 * Decode from a byte buffer.
	 *
	 * The error action is {@link ErrorAction.REPLACE}.
	 *
	 * @param buffer The address to use for input.
	 * @param length The number of bytes to read.
	 */
	public ISO8859_1Decoder(address buffer, long length) {
		super(buffer, length);
	}
	/**
	 * Decode from a byte buffer and set the error action.
	 *
	 * @param buffer The address to use for input.
	 * @param length The number of bytes to read.
	 * @param errorAction The action to take on malformed input.	
	 */
	public ISO8859_1Decoder(address buffer, long length, ErrorAction errorAction) {
		super(buffer, length, errorAction);
	}
	/**
	 * Decode the next byte. Decoding is trivial, because all valid input bytes are the
	 * same value as the Unicode code points for the same characters.
	 */
	protected int _decode() {
		return _reader.read();
	}
}
/**
 * This class implements an Encoder to produce UTF-16 bytes.
 *
 */
public class ISO8859_1Encoder extends Encoder {
	/**
	 * Encode some text to a Writer.
	 *
	 * @param writer The Writer to send output to.
	 */
	public ISO8859_1Encoder(ref<Writer> writer) {
		super(writer);
	}
	/**
	 * Encode some text to a byte array.
	 *
	 * @param buffer The byte array to fill.
	 */
	public ISO8859_1Encoder(ref<byte[]> buffer) {
		super(buffer);
	}
	/**
	 * Encode some text to a buffer.
	 *
	 * @param buffer The address of the buffer to fill.
	 * @param length The size of the buffer in bytes.
	 */
	public ISO8859_1Encoder(address buffer, long length) {
		super(buffer, length);
	}

	protected int _encode(int codePoint) {
		if (codePoint > 255)
			return 0;
		_writer.write(byte(codePoint));
		return 1;
	}
}
