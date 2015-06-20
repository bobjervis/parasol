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
 *	
 *	This is accomplished by import'ing the symbols that are defined for all 
 *	files and letting the normal scope rules do the rest.
 */
import parasol:text.string;

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

class short {
//	public static short MIN_VALUE = 0xffffffffffff8000;
//	public static short MAX_VALUE = 0x7fff;

	public short() {
	}
/*
	public short(short value) {
		*this = value;
	}
	
	public short compare(short other) {
		return *this - other;
	}
	
	public static short, boolean parse(string text) {
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
		return short(value), true;
	}
*/
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

class float {
	private static unsigned SIGN_MASK = 0x80000000;
	private static unsigned ONE = 0x3f800000;
	
	public float() {
	}
	
	public float(float value) {
		
	}
}

class double {
	private static long SIGN_MASK = 0x8000000000000000;
	private static long ONE =       0x3ff0000000000000;

	public double() {
	}
	
	public double(double value) {
		
	}
}

@Final 
class void {}

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
	
	public var(double value) {
		_value = *ref<long>(&value);
		_actualType = double;
	}
	
	public var(boolean b) {
		_value = long(b);
		_actualType = boolean;
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

	public double floatValue() {
		return *ref<double>(&_value);
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

