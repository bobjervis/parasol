/*
   Copyright 2015 Rovert Jervis

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
/*
 *	Parasol root scope symbols.
 *
 *	These symbols are defined for all compilations.  No special
 *	declarations are needed to have these names defined.
 */
class boolean {
	public boolean() {
	}
	
	public boolean(boolean value) {
	}
}
class char {
	public static char MAX_VALUE = 65535;
	
	public char() {
	}
	
	public char(char value) {
	}
	
	public int compare(char other) {
		return *this - other;
	}

	boolean isSpace() {
		switch (int(*this)) {
		case	' ':
		case	'\t':
		case	'\n':
		case	'\v':
		case	'\r':
			return true;
			
		default:
			return false;
		}
		return false;
	}
}
class byte {
	public static byte MIN_VALUE = 0;
	public static byte MAX_VALUE = 255;
	
	public byte() {
	}

	public byte(byte value) {
	}

	public static byte, boolean parse(string text) {
		int value = 0;
		for (int i = 0; i < text.length(); i++) {
			byte x = text[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (value >= MIN_VALUE && value <= MAX_VALUE)
			return byte(value), true;
		else
			return 0, false;
	}
	
	public int compare(byte other) {
		return *this - other;
	}

	public boolean isPrintable() {
		if (*this < 0x20)
			return false;
		else
			return *this < 0x7f;
	}
	
	public boolean isSpace() {
		switch (*this) {
		case	' ':
		case	'\t':
		case	'\n':
		case	'\v':
		case	'\r':
			return true;
			
		default:
			return false;
		}
		return false;
	}

	public boolean isAlphanumeric() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'G':
		case 'H':
		case 'I':
		case 'J':
		case 'K':
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		case 'Y':
		case 'Z':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
			return true;
		}
		return false;
	}
	
	public boolean isDigit() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			return true;
		}
		return false;	
 	}
	
	public boolean isOctalDigit() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
			return true;
		}
		return false;	
 	}
	
	public boolean isHexDigit() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
			return true;
		}
		return false;	
 	}
	
	public boolean isAlpha() {
		switch (*this) {
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'G':
		case 'H':
		case 'I':
		case 'J':
		case 'K':
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		case 'Y':
		case 'Z':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
			return true;
		}
		return false;
	}
	
	public boolean isUppercase() {
		switch (*this) {
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'G':
		case 'H':
		case 'I':
		case 'J':
		case 'K':
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		case 'Y':
		case 'Z':
			return true;
		}
		return false;
	}

	public boolean isLowercase() {
		switch (*this) {
		case 'a':
		case 'b':
		case 'C':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
			return true;
		}
		return false;
	}
	
	byte toUppercase() {
		if ((*this).isLowercase())
			return byte(*this + ('A' - 'a'));
		else
			return *this;
	}
	
	byte toLowercase() {
		if ((*this).isUppercase())
			return byte(*this + ('a' - 'A'));
		else
			return *this;
	}
}

class int {
	public static int MIN_VALUE = 0xffffffff80000000;
	public static int MAX_VALUE = 0x7fffffff;

	public int() {
	}
	
	public int(int value) {
		*this = value;
	}
	
	public int compare(int other) {
		return *this - other;
	}
	
	public static int, boolean parse(string text) {
		int value = 0;
		int i = 0;
		boolean negative = false;
		if (text[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (negative)
			value = -value;
		return value, true;
	}
}

class unsigned {
	public static unsigned MIN_VALUE = 0x00000000;
	public static unsigned MAX_VALUE = 0xffffffff;

	public unsigned() {
	}
	
	public unsigned(unsigned value) {
	}
/*	
	public int compare(unsigned other) {
		return int(*this - other);
	}
 */
}

class long {
	public static long MIN_VALUE = 0x8000000000000000;
	public static long MAX_VALUE = 0x7fffffffffffffff;
	
	public long() {
	}
	
	public long(long value) {
	}
}

@Final 
class void {}

class double {
	public double() {
	}
	
	public double(double value) {
	}
}
class Exception {}
class ClassInfo {}
class `*Namespace*` {}
class `*deferred*`{}
class address {}

class Pair<class K, class V> {
	public K key;
	public V value;
	
	public Pair() {
	}
	
	public Pair(K k, V v) {
		key = k;
		value = v;
	}
}

int printf(string formatX, var... argumentsX) {
	string s;
	
	s.printf(formatX, argumentsX);
	return print(s);
}

abstract int print(string text);

abstract void assert(boolean test);

abstract address memset(address destination, byte value, int length);
abstract address memcpy(address destination, address source, int length);

abstract boolean exposeException(ref<Exception> exception);

class vector<class E> extends vector<E, int>{
	public vector(int initialSize) {
	}
	
	public vector(vector<E> other) {
	}
	
	public vector(vector<E, int> other) {
	}
	
}

class vector<class E, class I> {
	private static int MIN_CAPACITY = 0x10;

	private I _length;
	private I _capacity;
	private pointer<E> _data;
	
	public vector(I initialSize) {
		_length = I(0);
		resize(initialSize);
	}
	
	public vector() {
		_length = I(0);
	}
	
	public vector(vector<E, I> other) {
		append(other);
	}
	
	~vector() {
	}
	
	public void append(vector<E, I> other) {
		int copyAmount = int(other._length);
		int base = int(_length);
		resize(I(base + copyAmount));
		for (int i = 0; i < copyAmount; i++)
			_data[base + i] = other._data[i];
	}
	
	public void append(pointer<E> other, int length) {
		int base = int(_length);
		resize(I(base + length));
		for (int i = 0; i < length; i++)
			_data[base + i] = other[i];
	}
	
	public void append(E other) {
		resize(I(int(_length) + 1));
//		print("resize done\n");
		_data[int(_length) - 1] = other;
	}

	public void clear() {
		free(_data);
		_data = null;
		_length = I(0);
		_capacity = I(0);
	}
	
	public boolean contains(E probe) {
		return false;
	}
	
	public void copy(vector<E, I> other) {
		clear();
		append(other);
	}
	
	public void deleteAll() {
//		for (int i = 0; i < _length; i++)
//			delete _data[i];
//		clear();
	}

	public I find(E key) {
		return I(0);
	}
	
	public E get(I index) {
		return _data[int(index)];
	}
	
	public void insert(I index, E value) {
		if (int(index) < 0 || int(index) > int(_length))
			return;
		resize(I(int(_length) + 1));
		for (int j = int(_length) - 1; j > int(index); j--)
			_data[j] = _data[j - 1];
		_data[int(index)] = value;
	}
	
	public void insert(I index, vector<E, I> value) {
	}
	
	public I length() {
		return _length;
	}
	
	public E peek() {
		return get(I(int(_length) - 1));
	}
	
	public E pop() {
		E e = get(I(int(_length) - 1));
		resize(I(int(_length) - 1));
		return e;
	}
	
	public void push(E value) {
		resize(I(int(_length) + 1));
		_data[int(_length) - 1] = value;
	}
	
	public void remove(I index) {
	}
	
	public void remove(I index, I count) {
	}
	
	public void resize(I newLength) {
		I newSize;
		if (_data != null) {
			if (int(_capacity) >= int(newLength)) {
				if (int(newLength) == 0)
					clear();
				else
					_length = newLength;
				return;
			}
			newSize = reservedSize(newLength);
			if (_capacity == newSize) {
				_length = newLength;
				return;
			}
		} else {
			if (int(newLength) == 0)
				return;
			newSize = reservedSize(newLength);
		}
		pointer<E> a = pointer<E>(allocz(int(newSize) * E.bytes));
		if (_data != null) {
			for (I i = I(0); int(i) < int(_length); i = I(int(i) + 1))
				a[int(i)] = _data[int(i)];
			free(_data);
		}
		_capacity = newSize;
		_data = a;
		_length = newLength;
	}
	
	private I reservedSize(I length) {
		I usedSize = length;
		I allocSize = I(MIN_CAPACITY);
		while (int(allocSize) < int(usedSize))
			allocSize = I(int(allocSize) << 1);
		return allocSize;
	}
	
	public void set(I index, E value) {
		_data[int(index)] = value;
	}
	
	public pointer<E> elementAddress(I index) {
		return _data + int(index);
	}
	
	public void slice(vector<E, I> source, I beginIndex, I endIndex) {
		I len = I(int(endIndex) - int(beginIndex));
		resize(len);
		for (int i = 0; i < int(len); i++)
			_data[i] = source[I(i + int(beginIndex))];
	}
	
	public void sort() {
		sort(true);
	}
	
	public void sort(boolean ascending) {
	}
}
/*
class vector<class E, enum I> {
	private pointer<E> _data;
	
	public vector() {
		_data = pointer<E>(allocz(I.length * E.bytes));
	}
	
	public vector(vector<E, I> other) {
	}
	
	~vector() {
	}
	
	public void clear() {
		memset(_data, 0, I.length * E.bytes);
	}
	
	public boolean contains(E probe) {
		return false;
	}
	
	public I find(E key) {
		return null;
	}
	
	public E get(I index) {
		return _data[index.index];
	}
	
	public int length() {
		return I.length;
	}
	
	public void set(I index, E value) {
		_data[index.index] = value;
	}
	
	public pointer<E> elementAddress(I index) {
		return _data + index.index;
	}
	
	public void sort() {
		sort(true);
	}
	
	public void sort(boolean ascending) {
	}
}
*/
class EnumBase {
	int length;
}

class EnumInstanceBase {
	int index;
}

class string {
	private class allocation {
		public int length;
		public byte data;
	}
	
	private static int MIN_SIZE = 0x10;

	private ref<allocation> _contents;
	
	public string() {
	}
	
	public string(string source) {
		if (source != null) {
			resize(source.length());
			memcpy(&_contents.data, &source._contents.data, source._contents.length + 1);
		}
	}
	
	public string(pointer<byte> cString) {
		if (cString != null) {
			int len = strlen(cString);
			resize(len);
			memcpy(&_contents.data, cString, len);
		}
	}
	
	public string(byte[] value) {
		resize(value.length());
		memcpy(&_contents.data, &value[0], value.length());
	}
	
	public string(pointer<byte> buffer, int len) {
		if (buffer != null) {
			resize(len);
			memcpy(&_contents.data, buffer, len);
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
	
	private void appendDigits(long value) {
		if (value > 9)
			appendDigits(value / 10);
		value %= 10;
		append('0' + int(value));
	}
	
	public string(double value) {
	}
	
	~string() {
		if (_contents != null) {
			free(_contents);
		}
	}
	
	public pointer<byte> c_str() {
		return pointer<byte>(&_contents.data);
	}
	
	@Deprecated
	public void assign(string other) {
		if (_contents != null) {
			free(_contents);
			_contents = null;
		}
		if (other != null) {
			resize(other._contents.length);
			memcpy(&_contents.data, &other._contents.data, other._contents.length + 1);
		}
	}
	
	public string append(string other) {
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
			memcpy(pointer<byte>(&_contents.data) + oldLength, &other._contents.data, len + 1);
//			print("appended\n");
		}
//		print("=");
//		print(*this);
//		print("\n");
		return *this;
	}
	
	public string append(byte b) {
		if (_contents == null) {
			resize(1);
			_contents.data = b;
		} else {
			int len = _contents.length;
			resize(len + 1);
			*(pointer<byte>(&_contents.data) + len) = b;
		}
		return *this;
	}
	
	public string append(pointer<byte> p, int length) {
		if (_contents == null) {
			resize(length);
			memcpy(&_contents.data, p, length);
		} else {
			int len = _contents.length;
			resize(len + length);
			memcpy(pointer<byte>(&_contents.data) + len, p, length);
		}
		*(pointer<byte>(&_contents.data) + _contents.length) = 0;
		return *this;
	}
	
	public string append(int ch) {
		if (ch <= 0x7f)
			append(byte(ch));
		else if (ch <= 0x7ff) {
			append(byte(0xc0 + (ch >> 6)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0xffff) {
			append(byte(0xe0 + (ch >> 12)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0x1fffff) {
			append(byte(0xf0 + (ch >> 18)));
			append(byte(0x80 + ((ch >> 12) & 0x3f)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0x3ffffff) {
			append(byte(0xf8 + (ch >> 24)));
			append(byte(0x80 + ((ch >> 18) & 0x3f)));
			append(byte(0x80 + ((ch >> 12) & 0x3f)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		} else if (ch <= 0x7fffffff) {
			append(byte(0xfc + (ch >> 30)));
			append(byte(0x80 + ((ch >> 24) & 0x3f)));
			append(byte(0x80 + ((ch >> 18) & 0x3f)));
			append(byte(0x80 + ((ch >> 12) & 0x3f)));
			append(byte(0x80 + ((ch >> 6) & 0x3f)));
			append(byte(0x80 + (ch & 0x3f)));
		}
		return *this;
	}
	
	public boolean beginsWith(string prefix) {
		if (prefix.length() > length())
			return false;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		pointer<byte> pcp = pointer<byte>(&prefix._contents.data);
		for (int i = 0; i < prefix.length(); i++)
			if (pcp[i] != cp[i])
				return false;
		return true;
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
		if (_contents != null) {
			free(_contents);
			_contents = null;
		}
		if (other != null) {
			resize(other._contents.length);
			memcpy(&_contents.data, &other._contents.data, other._contents.length + 1);
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
	 */
	string escapeC() {
		string output;

		if (length() == 0)
			return output;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			switch (cp[i]) {
			case	'\\':	output.printf("\\\\");	break;
			case	'\a':	output.printf("\\a");	break;
			case	'\b':	output.printf("\\b");	break;
			case	'\f':	output.printf("\\f");	break;
			case	'\n':	output.printf("\\n");	break;
			case	'\r':	output.printf("\\r");	break;
			case	'\v':	output.printf("\\v");	break;
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

		if (length() == 0)
			return output;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			switch (cp[i]) {
			case	'\\':	output.printf("\\\\");	break;
			case	'\a':	output.printf("\\a");	break;
			case	'\b':	output.printf("\\b");	break;
			case	'\f':	output.printf("\\f");	break;
			case	'\n':	output.printf("\\n");	break;
			case	'\r':	output.printf("\\r");	break;
			case	'\v':	output.printf("\\v");	break;
			default:
				if (cp[i] >= 0x20 &&
					cp[i] < 0x7f)
					output.append(cp[i]);
				else {
					// TODO: Implement \uNNNNN sequence
					//assert(false);
					output.printf("\\x%x", cp[i] & 0xff);
				}
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
		return 5;
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
	
	public int lastIndexOf(byte c) {
		if (_contents != null) {
			pointer<byte> cp = pointer<byte>(&_contents.data) + _contents.length;
			for (int i = _contents.length - 1; i >= 0; i--)
				if (cp[i] == c)
					return i;
		}
		return -1;
	}
	
	public int length() {
		if (_contents != null)
			return _contents.length;
		else
			return 0;
	}
	
	public int printf(string format, var... arguments) {
		int beforeLength = length();
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
								
				int width;
				boolean widthSpecified = false;
				int precision = int.MAX_VALUE;
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
							if (precision < width)
								width = precision;
							switch (format[i]) {
							case	'd':
							case	'D':
								var xx = arguments[nextArgument];
								long i = (pointer<long>(&xx))[1];
								nextArgument++;
								string formatted(i);
								
								if (!leftJustified) {
									while (width > formatted.length()) {
										append(' ');
										width--;
									}
								}
								if (alwaysIncludeSign && i >= 0)
									append('+');
								append(formatted);
								if (leftJustified) {
									while (width > formatted.length()) {
										append(' ');
										width--;
									}
								}
								break;
																
							case	'p':
							case	'x':
								xx = arguments[nextArgument];
								i = (pointer<long>(&xx))[1];
								nextArgument++;
								string hex;
								
								if (!precisionSpecified)
									precision = 1;
								if (alternateForm)
									hex.append("0x");
								int digitCount = 16;
								while ((i & 0xf000000000000000) == 0 && digitCount > precision) {
									i <<= 4;
									digitCount--;
								}
								for (int k = 0; k < digitCount; k++) {
									int digit = int(i >>> 60);
									if (digit < 10)
										hex.append('0' + digit);
									else
										hex.append(('a' - 10) + digit);
									i <<= 4;
								}
								if (!leftJustified) {
									while (width > hex.length()) {
										append(' ');
										width--;
									}
								}
								append(hex);
								if (leftJustified) {
									while (width > hex.length()) {
										append(' ');
										width--;
									}
								}
								break;
								
							case	'X':
							case	'i':
							case	'u':
							case	'f':
							case	'F':
							case	'e':
							case	'E':
							case	'g':
							case	'G':
							case	'o':
							case	'n':		// write to integer pointer parameter
								current = ParseState.ERROR;
								break;
								
							case	'%':
								if (!leftJustified) {
									while (width > 1) {
										append(' ');
										width--;
									}
								}
								append('%');
								if (leftJustified) {
									while (width > 1) {
										append(' ');
										width--;
									}
								}
								break;
								
							case	'c':
								char c = char(arguments[nextArgument]);
								nextArgument++;
								if (!leftJustified) {
									while (width > 1) {
										append(' ');
										width--;
									}
								}
								if (precision >= 1)
									append(c);
								if (leftJustified) {
									while (width > 1) {
										append(' ');
										width--;
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
										len = strlen(cp);
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
										append(' ');
										width--;
									}
								}
								
								if (precision < len)
									len = precision;
								append(cp, len);
								if (leftJustified) {
									while (width > len) {
										append(' ');
										width--;
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
							append(format[formatStart]);
							formatStart++;
						}
						break;
					}
				} while (!done);
			} else
				append(format[i]);
		}
		return length() - beforeLength;
	}
	
	public string remove(RegularExpression pattern) {
		return null;
	}
	
	public void resize(int newLength) {
		int newSize = reservedSize(newLength);
		if (_contents != null) {
			if (_contents.length >= newLength) {
				_contents.length = newLength;
				return;
			}
			int oldSize = reservedSize(_contents.length);
			if (oldSize == newSize) {
				_contents.length = newLength;
				return;
			}
		}
		ref<allocation> a = ref<allocation>(allocz(newSize));
		if (_contents != null) {
			memcpy(&a.data, &_contents.data, _contents.length + 1);
			free(_contents);
		}
		a.length = newLength;
		*(pointer<byte>(&a.data) + newLength) = 0;
		_contents = a;
	}

	private int reservedSize(int length) {
		int usedSize = length + int.bytes + 1;
		int allocSize = MIN_SIZE;
		while (allocSize < usedSize)
			allocSize <<= 1;
		return allocSize;
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
		
		result.append(pointer<byte>(&_contents.data) + first, last - first);
		return result;
	}
	
	public string toLower() {
		if (length() == 0)
			return *this;
		string out;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			if (cp[i].isUppercase())
				out.append(cp[i].toLowercase());
			else
				out.append(cp[i]);
		}
		return out;
	}
	
	public string toUpper() {
		if (length() == 0)
			return *this;
		string out;
		pointer<byte> cp = pointer<byte>(&_contents.data);
		for (int i = 0; i < _contents.length; i++) {
			if (cp[i].isLowercase())
				out.append(cp[i].toUppercase());
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
								v += 10 + pointer<byte>(&_contents.data)[i].toLowercase() - 'a';
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
						output.append(v);
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
	string,boolean unescapeParasol() {
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
								v += 10 + pointer<byte>(&_contents.data)[i].toLowercase() - 'a';
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
						output.append(v);
						break;
					default:
						// TODO: Check for unicode \uNNNN sequences
						output.append(pointer<byte>(&_contents.data)[i]);
					}
				}
			} else
				output.append(pointer<byte>(&_contents.data)[i]);
		}
		return output, true;
	}
}

class map<class K, class V> {
	private static int INITIAL_TABLE_SIZE	= 64;		// must be power of two
	private static int REHASH_SHIFT = 3;				// rehash at ((1 << REHASH_SHIFT) - 1) / (1 << REHASH_SHIFT) keys filled

	private pointer<Entry>	_entries;
	private int				_entriesCount;
	private int				_allocatedEntries;
	private int				_rehashThreshold;

	public map() {
	}
	
	~map() {
	}
	
	public void clear() {
	}
	
	public int size() {
		return _entriesCount;
	}
	
	public boolean contains(K key) {
		ref<Entry> e = findEntry(key);
		return e.valid;
	}

	public void deleteAll() {
	}
	
	public V get(K key) {
		ref<Entry> e = findEntry(key);
		if (e.valid)
			return e.value;
		else
			return V(null);
	}

	public V first() {
		for (int i = 0; i < _allocatedEntries; i++)
			if (_entries[i].valid)
				return _entries[i].value;
		static V v;
		return v;
	}

	public boolean insert(K key, V value) {
		ref<Entry> e = findEntry(key);
		if (e.valid)
			return false;
		else {
			if (hadToRehash())
				e = findEntry(key);
			_entriesCount++;
			e.valid = true;
			e.key = key;
			e.value = value;
			return true;
		}
	}
	
	public V replace(K key, V value) {
		ref<Entry> e = findEntry(key);
		V result;
		if (e.valid) {
			result = e.value;
			e.value = value;
		} else {
			result = V(null);
			insert(key, value);
		}
		return result;
	}
	
	public ref<V> elementAddress(K key) {
		ref<Entry> e = findEntry(key);
		if (e.valid)
			return &e.value;
		else
			return null;
	}
	
	public ref<V> createEmpty(K key) {
		ref<Entry> e = findEntry(key);
		if (!e.valid) {
			if (hadToRehash())
				e = findEntry(key);
			_entriesCount++;
		}
		e.valid = true;
		e.key = key;
		return &e.value;
	}
	
	public void set(K key, V value) {
		*createEmpty(key) = value;
	}
	
	private ref<Entry> findEntry(K key) {
		if (_entries == null) {
			_entries = pointer<Entry>(allocz(INITIAL_TABLE_SIZE * Entry.bytes));
			_allocatedEntries = INITIAL_TABLE_SIZE;
			setRehashThreshold();
		}
		int x = key.hash() & (_allocatedEntries - 1);
		int startx = x;
		for(;;) {
			ref<Entry> e = ref<Entry>(_entries + x);
			if (!e.valid || e.key.compare(key) == 0)
				return e;
			x++;
			if (x >= _allocatedEntries)
				x = 0;
		}
	}

	private boolean hadToRehash() {
		if (_entriesCount >= _rehashThreshold) {
			pointer<Entry> oldE = _entries;
			_allocatedEntries *= 2;
			_entries = pointer<Entry>(allocz(_allocatedEntries * Entry.bytes));
			int e = _entriesCount;
			_entriesCount = 0;
			for (int i = 0; e > 0; i++) {
				if (oldE[i].valid) {
					insert(oldE[i].key, oldE[i].value);
					e--;
				}
			}
			setRehashThreshold();
			free(oldE);
			return true;
		} else
			return false;
	}
	
	private void setRehashThreshold() {
		_rehashThreshold = (_allocatedEntries * ((1 << REHASH_SHIFT) - 1)) >> REHASH_SHIFT;
	}
	
	private class Entry {
		public K		key;
		public V		value;
		public boolean	valid;
	}

	public iterator begin() {
		iterator i(this);
		if (_entriesCount == 0)
			i._index = _allocatedEntries;
		else {
			for (i._index = 0; i._index < _allocatedEntries; i._index++)
				if (_entries[i._index].valid)
					break;
		}
		return i;
	}

	public class iterator {
		public boolean hasNext() {
			return _index < _dictionary._allocatedEntries;
		}

		public void next() {
			do
				_index++;
			while (_index < _dictionary._allocatedEntries &&
				   !_dictionary._entries[_index].valid);
		}

		public V get() {
			return _dictionary._entries[_index].value;
		}

		public K key() {
			return _dictionary._entries[_index].key;
		}

		iterator(ref<map<K, V>> dict) {
			_dictionary = dict;
			_index = 0;
		}

		int				_index;
		ref<map<K, V>>	_dictionary;
	};
}

class ref<class T> extends address {
}

class pointer<class T> extends address {
}

class var {
//	private class _actualType;
	private address _actualType;
	private long _value;
	
	public var() {
	}
	
	public var(var other) {
		_actualType = other.class;
		_value = long(other);
	}
	
	public var(string other) {
		_actualType = string;
		*ref<string>(&_value) = other;
	}
	
	public var(long value) {
		_value = value;
		_actualType = long;
	}
	
	public var(address p) {
		_value = long(p);
		_actualType = address;
	}
	
	public var(pointer<byte> p) {
		_value = long(p);
		_actualType = pointer<byte>;
	}
	/*
	 * This constructor is for internally generated conversions that have to store a specific type and value. The
	 * types for the arguments are arbitrary since the code generation will create calls to this after type analysis. 
	 */
	private var(address actualType, long value) {
		_value = value;
		_actualType = actualType;
	}
	
	public address actualType() { 
		return _actualType;
	}
	
	public var add(var other) {
		if (_actualType == string || other.class == string) {
			string otherValue = string(other);
			string value = *ref<string>(&_value);
			return value + otherValue;
		}
		long x = _value + long(other);
		return x;
	}

	public var and(var other) {
		long x = _value & long(other);
		return x;
	}

	public int compare(var other) {
		if (_actualType != other.class)
			return int.MIN_VALUE;
		if (_actualType == string || other.class == string) {
			string otherValue = string(other);
			string value = *ref<string>(&_value);
			return value.compare(otherValue);
		} else {
			long otherValue = long(other);
			if (_value < otherValue)
				return -1;
			else if (_value > otherValue)
				return 1;
			else
				return 0;
		}
	}
	
	public void copy(var source) {
//		_actualType = source._actualType;
//		_value = source._value;
		memcpy(this, &source, var.bytes);
	}
	
	public var divide(var other) {
		long x = _value / long(other);
		return x;
	}
	
	public var exclusiveOr(var other) {
		long x = _value ^ long(other);
		return x;
	}
	
	public long integerValue() {
		// TODO: Validate type and convert when necessary
		return _value;
	}

	public var leftShift(var other) {
		long x = _value << int(other);
		return x;
	}
	
	public var multiply(var other) {
		long x = _value * long(other);
		return x;
	}
	
	public var or(var other) {
		long x = _value | long(other);
		return x;
	}

	public var remainder(var other) {
		long x = _value % long(other);
		return x;
	}

	public var rightShift(var other) {
		long x = _value >> int(other);
		return x;
	}

	public var subtract(var other) {
		long x = _value - long(other);
		return x;
	}

	public var unsignedRightShift(var other) {
		long x = _value >>> int(other);
		return x;
	}
}

class RegularExpression {
}

abstract address allocz(long size);

abstract void free(address p);

int strlen(pointer<byte> cp) {
	pointer<byte> start = cp;
	while (*cp != 0)
		cp++;
	return int(cp - start);
}

void memDump(address buffer, long length, long startingOffset) {
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
void memDump(address buffer, int length) {
	pointer<byte> start = pointer<byte>(buffer);
	pointer<byte> firstRow = start + -(int(buffer) & 15);
	pointer<byte> next = start + length;
	pointer<byte> nextRow = next + ((16 - int(next) & 15) & 15);
	for (pointer<byte> p = firstRow; int(p) < int(nextRow); p += 16) {
		dumpPtr(p);
		printf(" ");
		for (int i = 0; i < 8; i++) {
			if (int(p + i) >= int(start) && int(p + i) < int(next))
				printf(" %2.2x", int(p[i]));
			else
				printf("   ");
		}
		printf(" ");
		for (int i = 8; i < 16; i++) {
			if (int(p + i) >= int(start) && int(p + i) < int(next))
				printf(" %2.2x", int(p[i]));
			else
				printf("   ");
		}
		printf(" ");
		for (int i = 0; i < 16; i++) {
			if (int(p + i) >= int(start) && int(p + i) < int(next)) {
				if (p[i].isPrintable())
					printf("%c", int(p[i]));
				else
					printf(".");
			} else
				printf(" ");
		}
		printf("\n");
	}
}

void dumpPtr(address x) {
	pointer<long> np = pointer<long>(&x);
	printf("%16.16x", *np);
}

