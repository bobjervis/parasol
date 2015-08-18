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
 *	files and letting the normal scope rules do the rest. This file's UnitScope
 *	gets inserted as the root scope of all other file UnitScope's. 
 */
import parasol:integers.short;
import parasol:integers.int;
import parasol:integers.long;
import parasol:integers.byte;
import parasol:integers.char;
import parasol:integers.unsigned;
import parasol:floatingPoint.float;
import parasol:floatingPoint.double;
import parasol:text.string;
import parasol:variant.var;
import parasol:types.address;
import parasol:types.boolean;
import parasol:types.void;
import parasol:types.ClassInfo;
import parasol:types.Exception;
import parasol:types.`*Namespace*`;
import parasol:types.`*deferred*`;

@Ref
class ref<class T> extends address {
}

@Pointer
class pointer<class T> extends address {
}

int printf(string format, var... arguments) {
	string s;
	
	s.printf(format, arguments);
	return print(s);
}

// Use printf instead
@Deprecated
abstract int print(string text);

abstract void assert(boolean test);

// Use native:C
@Deprecated
abstract address memset(address destination, byte value, int length);
@Deprecated
abstract address memcpy(address destination, address source, int length);
@Deprecated
abstract void free(address p);

// Use native:C.calloc
@Deprecated
abstract address allocz(long size);

// Note: compiler code requires that this definition of 'vector' appears first. TODO: Remove this dependency.
class vector<class E> extends vector<E, int>{
	public vector(int initialSize) {
	}
	
	public vector(vector<E> other) {
	}
	
	public vector(vector<E, int> other) {
	}
	
}

@Shape
class vector<class E, class I> {
	private static int MIN_CAPACITY = 0x10;

	private I _length;
	private I _capacity;
	private pointer<E> _data;
	
	public vector(I initialSize) {
		_length = I(0);
		_capacity = I(0);
		resize(initialSize);
	}
	
	public vector() {
		_capacity = I(0);
		_length = I(0);
	}
	
	public vector(vector<E, I> other) {
		_capacity = I(0);
		_length = I(0);
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
	
	public E getModulo(I index) {
		return _data[int(index) % int(_length)];
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
	
	public void setModulo(I index, E value) {
		_data[int(index) % int(_length)] = value;
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
	
//	public E addReduce() {
//		E sum = E(0);
		
//		for (I i = I(0); int(i) < int(_length); i = I(int(i) + 1))
//			sum = E(int(sum) + int(_data[int(i)]));
//		return sum;
//	}
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
