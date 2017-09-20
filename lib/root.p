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
import parasol:text.substring;
import parasol:variant.var;
import parasol:types.address;
import parasol:types.boolean;
import parasol:types.void;
import parasol:types.ClassInfo;
import parasol:exception.Exception;
import parasol:exception.AssertionFailedException;
import parasol:exception.BoundsException;
//import parasol:collections.vector;

// Eventually, we need another way to get these 'built ins' plumbed through.

import parasol:types.`*Namespace*`;
import parasol:types.`*deferred*`;
import parasol:types.`*array*`;
import parasol:types.`*object*`;
import parasol:types.Array;
import parasol:types.Object;
import parasol:thread.Monitor;
/*
 * The global symbol 'undefined' can be used with var symbols to check whether
 * the var has any value at all. In other words, the default constructor for a
 * var object will create a value that compares equal to the symbol 'undefined',
 * and since it is a @Constant, user code cannot change it. 
 */
//@Constant
var undefined;

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

void assert(boolean test) {
	if (!test)
		throw AssertionFailedException();
}

// Use native:C
@Deprecated
abstract void free(address p);

// Use native:C.calloc
@Deprecated
abstract address allocz(long size);

import parasol:memory;

// Note: compiler code requires that this definition of 'vector' appears first. TODO: Remove this dependency.
class vector<class E> extends vector<E, int> {
	public vector() {
	}
	
	public vector(int initialSize) {
		super(initialSize);
	}
	
	public vector(vector<E> other) {
		super(other);
	}
	
	public vector(vector<E, int> other) {
		super(other);
	}
	
	~vector() {
	}
}

@Shape
class vector<class E, class I> {
	@Constant
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
		for (int i = 0; i < int(_length); i++)
			_data[i].~();
		memory.free(_data);
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

	public void append(E other, ref<memory.Allocator> allocator) {
		resize(I(int(_length) + 1), allocator);
//		print("resize done\n");
		_data[int(_length) - 1] = other;
	}

	/*
	 *	binarySearchClosestGreater
	 *
	 *	This function does a binary search on an already sorted array.
	 *	The key class must define a compare method that returns < 0
	 *	if the key is less than its argument, > 0 if it is greater and
	 *	0 if they are equal.
	 *
	 *	RETURNS:
	 *		-1			If there are no elements in the array.
	 *		N < size	If element N is the smallest greater than the key.
	 *		size		If no element is greater than the key.
	 */
	I binarySearchClosestGreater(E key) {
		int min = 0;
		int max = int(_length) - 1;
		int mid = -1;
		int relation = -1;

		while (min <= max) {
			mid = (max + min) / 2;
			relation = key.compare(_data[I(mid)]);
			if (relation == 0)
				return I(mid + 1);
			if (relation < 0)
				max = mid - 1;
			else
				min = mid + 1;
		}
		if (relation > 0)
			mid++;
		return I(mid);
	}

	public void clear() {
		memory.free(_data);
		_data = null;
		_length = I(0);
		_capacity = I(0);
	}
	
	public void clear(ref<memory.Allocator> allocator) {
		allocator.free(_data);
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
	
	void copyTemp(vector<E, I> other) {
		// a temp is assumed to be random stack trash - so clear it first.
		_data = null;
		_length = I(0);
		_capacity = I(0);
		append(other);
	}
	
	public void deleteAll() {
		for (int i = 0; i < _length; i++)
			delete _data[i];
		clear();
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
		if (int(index) < 0 || int(index) >= int(_length))
			return;
		for (int j = int(index); j < int(_length) - 1; j++)
			_data[j] = _data[j + 1];
		resize(I(int(_length) - 1));
	}
	
	public void remove(I index, I count) {
	}
	
	public void resize(I newLength) {
		I newSize;
		if (_data != null) {
			if (int(_length) >= int(newLength)) {
				for (int i = int(newLength); i < int(_length); i++)
					_data[i].~();
				if (int(newLength) == 0)
					clear();
				else
					_length = newLength;
				return;
			}
			newSize = reservedSize(newLength);
			if (_capacity == newSize) {
				for (int i = int(_length); i < int(newLength); i++)
					new (&_data[i]) E();
				_length = newLength;
				return;
			}
		} else {
			_length = I(0);
			if (int(newLength) == 0)
				return;
			newSize = reservedSize(newLength);
		}
		pointer<E> a = pointer<E>(memory.alloc(int(newSize) * E.bytes));
		if (_data != null) {
			for (I i = I(0); int(i) < int(_length); i = I(int(i) + 1))
				a[int(i)] = _data[int(i)];
			memory.free(_data);
		}
		for (int i = int(_length); i < int(newLength); i++)
			new (&a[i]) E();
		_capacity = newSize;
		_data = a;
		_length = newLength;
	}
	
	public void resize(I newLength, ref<memory.Allocator> allocator) {
		I newSize;
		if (_data != null) {
			if (int(_capacity) >= int(newLength)) {
				if (int(newLength) == 0)
					clear(allocator);
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
		pointer<E> a = pointer<E>(allocator.alloc(int(newSize) * E.bytes));
		if (_data != null) {
			for (I i = I(0); int(i) < int(_length); i = I(int(i) + 1))
				a[int(i)] = _data[int(i)];
			allocator.free(_data);
		}
		_capacity = newSize;
		_data = a;
		_length = newLength;
	}
	
	private I reservedSize(I length) {
		I usedSize = length;
		I allocSize = I(MIN_CAPACITY);
		while (int(allocSize) < int(usedSize)) {
			I nextAllocSize = I(int(allocSize) << 1);
			if (int(nextAllocSize) <= 0)
				return I((int(allocSize) << 1) - 1);
			allocSize = nextAllocSize;
		}
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
	/*
	   sort - sorts using the quick sort routine

	Background

	The Quicker Sort algorithm was first described by C.A.R.Hoare in the
	Computer Journal, No. 5 (1962), pp.10..15, and in addition is frequently
	described in computing literature, notably in D. Knuth's Sorting and
	Searching.  The method used here includes a number of refinements:

	- The median-of-three technique described by Singleton (Communications
	  of the A.C.M., No 12 (1969) pp 185..187) is used, where the median
	  operation is also the special case sort for 3 elements.  This slightly
	  improves the average speed, especially when comparisons are slower
	  than exchanges, but more importantly it prevents worst-case behavior
	  on partly sorted files.  If a simplistic quicker-sort is run on a file
	  which is only slightly disordered (a common need in some applications)
	  then it is as slow as a bubble-sort.  The median technique prevents
	  this.

	  Another serious problem with the plain algorithm is that worst-case
	  behavior causes very deep recursion (almost one level per table
	  element !), so again it is best to use the median technique.

		The comparison function accepts two arguments, elem1
	        and elem2, each a pointer to an entry in the table. The
	        comparison function compares each of the pointed-to items
	        (*elem1 and *elem2), and returns an integer based on the result
	        of the comparison.

	                        If the items            fcmp returns

	                        *elem1 <  *elem2         an integer < 0
	                        *elem1 == *elem2         0
	                        *elem1 >  *elem2         an integer > 0

	        In the comparison, the less than symbol (<) means that the left
	        element should appear before the right element in the final,
	        sorted sequence. Similarly, the greater than (>) symbol
	        means that the left element should appear after the right
	        element in the final, sorted sequence.

	  The internal contents of the records are never inspected by qsort.  It
	  depends entirely upon compare to decide the format and value of the records.
	  This allows the content of the records to be of any fixed length type -
	  formatted text, floating point, pointer to variable length record, etc. -
	  so long as each record is understood by compare.

	  The quicker sort algorithm will in general change the relative ordering
	  of records which may compare as equal.  For example, if it is attempted
	  to use two passes of quick sort on an order file, first by date and then
	  by customer name, the result will be that the second sort pass randomly
	  jumbles the dates.  It is necessary to design the compare() function to
	  consider all the keys and sort in one pass.

		- After the compare pass is made over the array, the pivot is moved
		  to the final boundary point, and the remaining parts of the array
		  are sorted.  The code avoids having to sort pivot again, and also
		  uses tail recursion on the larger portion of the array.  This will
		  tend to minimize the depth of the recursion.
	*/
	public void sort(boolean ascending) {
		if (int(_length) == 0)
			return;
		int descendingAdjust = 1;
		if (!ascending)
			descendingAdjust = -1;
		qsort(_data, int(_length), descendingAdjust);
	}
	
	private static void qsort(pointer<E> pivot, int nElem, int descendingAdjust) { 
		pointer<E> left, right;
		int lNum;

		for	(;;) {
			if (nElem <= 2){
				if (nElem == 2 &&
					pivot[0].compare(pivot[1]) * descendingAdjust > 0)
					exchange(pivot, pivot + 1);
				return;
			}

			right = pivot + (nElem - 1);
			left  = pivot + (nElem >> 1);

				/*  sort the pivot, left, and 
					right elements for "median of 3" */

			if (left.compare(*right) * descendingAdjust > 0)
				exchange(left, right);

				// assert *right >= *left

			if (left.compare(*pivot) * descendingAdjust > 0)
				exchange(left, pivot);
			else if (pivot.compare(*right) * descendingAdjust > 0)
				exchange(pivot, right);

				// assert *right >= *pivot >= *left

			if (nElem == 3) {

					// for exactly three elements, we need to
					// fix pivot and left.

				exchange(pivot, left);
				return;
			}

				//  now for the classic Hoare algorithm

			left = pivot + 1;

			int compareDirection;	// -1 from above, +1 from below

			do {
				compareDirection = +1;
				while (left.compare(*pivot) * descendingAdjust < 0)
					if (left < right)
						left++;
					else
						break;

				while (left < right) {
					compareDirection = -1;
					if (pivot.compare(*right) * descendingAdjust <= 0)
						right--;
					else {
						exchange(left, right);
						left++;
						break;
					}
				}
			} while (left < right);

				// This puts the pivot into the middle if needed.

			left--;
			lNum = int(right - pivot);	// lNum is lower 'half' size
			if (left > pivot)
				exchange(pivot, left);
			if ((nElem >> 1) > lNum) {

					// lower 'half' has fewest elements

				qsort(pivot, lNum - 1, descendingAdjust);
				nElem -= lNum;
				pivot = right;
			} else {
				qsort(right, nElem - lNum, descendingAdjust);
				nElem = lNum - 1;
			}
		}
	}
	
	public void sort(int comparator(E a, E b), boolean ascending) {
		if (int(_length) == 0)
			return;
		int descendingAdjust = 1;
		if (!ascending)
			descendingAdjust = -1;
		qsort(_data, int(_length), comparator, descendingAdjust);
	}
	
	private static void qsort(pointer<E> pivot, int nElem, int comparator(E a, E b), int descendingAdjust) { 
		pointer<E> left, right;
		int lNum;

		for	(;;) {
			if (nElem <= 2){
				if (nElem == 2 &&
					comparator(pivot[0], pivot[1]) * descendingAdjust > 0)
					exchange(pivot, pivot + 1);
				return;
			}

			right = pivot + (nElem - 1);
			left  = pivot + (nElem >> 1);

				/*  sort the pivot, left, and 
					right elements for "median of 3" */

			if (comparator(*left, *right) * descendingAdjust > 0)
				exchange(left, right);

				// assert *right >= *left

			if (comparator(*left, *pivot) * descendingAdjust > 0)
				exchange(left, pivot);
			else if (comparator(*pivot, *right) * descendingAdjust > 0)
				exchange(pivot, right);

				// assert *right >= *pivot >= *left

			if (nElem == 3) {

					// for exactly three elements, we need to
					// fix pivot and left.

				exchange(pivot, left);
				return;
			}

				//  now for the classic Hoare algorithm

			left = pivot + 1;

			int compareDirection;	// -1 from above, +1 from below

			do {
				compareDirection = +1;
				while (comparator(*left, *pivot) * descendingAdjust < 0)
					if (left < right)
						left++;
					else
						break;

				while (left < right) {
					compareDirection = -1;
					if (comparator(*pivot, *right) * descendingAdjust <= 0)
						right--;
					else {
						exchange(left, right);
						left++;
						break;
					}
				}
			} while (left < right);

				// This puts the pivot into the middle if needed.

			left--;
			lNum = int(right - pivot);	// lNum is lower 'half' size
			if (left > pivot)
				exchange(pivot, left);
			if ((nElem >> 1) > lNum) {

					// lower 'half' has fewest elements

				qsort(pivot, lNum - 1, comparator, descendingAdjust);
				nElem -= lNum;
				pivot = right;
			} else {
				qsort(right, nElem - lNum, comparator, descendingAdjust);
				nElem = lNum - 1;
			}
		}
	}
	/*
		Exchange records.
	 */
	private static void exchange(ref<E> left, ref<E> right) {
		E temp = *left;
		*left = *right;
		*right = temp;
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
		_data = pointer<E>(memory.alloc(I.length * E.bytes));
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
@Shape
class map<class V, class K> {
	@Constant
	private static int INITIAL_TABLE_SIZE	= 64;		// must be power of two
	@Constant
	private static int REHASH_SHIFT = 3;				// rehash at ((1 << REHASH_SHIFT) - 1) / (1 << REHASH_SHIFT) keys filled

	private pointer<Entry>	_entries;
	private int				_entriesCount;
	private int				_deletedEntriesCount;
	private int				_allocatedEntries;
	private int				_rehashThreshold;

	public map() {
	}
	
	~map() {
		clear();
	}
	
	public void clear() {
		int e = _entriesCount;
		_entriesCount = 0;
		_deletedEntriesCount = 0;
		for (int i = 0; e > 0; i++) {
			if (_entries[i].valid) {
				e--;
				if (!_entries[i].deleted)
					_entries[i].value.~();
			}
		}
		memory.free(_entries);
		_entries = null;
		_allocatedEntries = 0;
		_rehashThreshold = 0;
	}
	
	public void clear(ref<memory.Allocator> allocator) {
		int e = _entriesCount;
		_entriesCount = 0;
		_deletedEntriesCount = 0;
		for (int i = 0; e > 0; i++) {
			if (_entries[i].valid) {
				e--;
				if (!_entries[i].deleted)
					_entries[i].value.~();
			}
		}
		allocator.free(_entries);
		_allocatedEntries = 0;
		_rehashThreshold = 0;
	}

	public int size() {
		return _entriesCount - _deletedEntriesCount;
	}
	
	public boolean contains(K key) {
		ref<Entry> e = findEntryReadOnly(key);
		if (e != null)
			return e.valid && !e.deleted;
		else
			return false;
	}

	public boolean deleteOne(K key) {
		ref<Entry> e = findEntry(key);
		if (e.valid) {
			if (!e.deleted) {
				delete e.value;
				e.value.~();
				e.deleted = true;
				_deletedEntriesCount++;
				return true;
			}
		}
		return false;
	}
	
	public boolean deleteOne(K key, ref<memory.Allocator> allocator) {
		ref<Entry> e = findEntry(key, allocator);
		if (e.valid) {
			if (!e.deleted) {
				allocator delete e.value;
				e.value.~();
				e.deleted = true;
				return true;
			}
		}
		return false;
	}
	
	public void deleteAll() {
		int e = _entriesCount;
		_entriesCount = 0;
		for (int i = 0; e > 0; i++) {
			if (_entries[i].valid) {
				e--;
				if (!_entries[i].deleted) {
					delete _entries[i].value;
					_entries[i].value.~();
				}
			}
		}
		memory.free(_entries);
		_allocatedEntries = 0;
		_rehashThreshold = 0;
	}
	
	public void deleteAll(ref<memory.Allocator> allocator) {
		int e = _entriesCount;
		_entriesCount = 0;
		for (int i = 0; e > 0; i++) {
			if (_entries[i].valid) {
				e--;
				if (!_entries[i].deleted) {
					allocator delete _entries[i].value;
					_entries[i].value.~();
				}
			}
		}
		allocator.free(_entries);
		_allocatedEntries = 0;
		_rehashThreshold = 0;
	}

	public V get(K key) {
		ref<Entry> e = findEntryReadOnly(key);
		if (e == null)
			return V(null);
		if (e.valid && !e.deleted)
			return e.value;
		else
			return V(null);
	}

	public V first() {
		for (int i = 0; i < _allocatedEntries; i++)
			if (_entries[i].valid && !_entries[i].deleted)
				return _entries[i].value;
		static V v;
		return v;
	}

	public boolean insert(K key, V value, ref<memory.Allocator> allocator) {
		ref<Entry> e = findEntry(key, allocator);
		if (e.valid && !e.deleted)
			return false;
		else {
			if (hadToRehash(allocator))
				e = findEntry(key, allocator);
			_entriesCount++;
			e.valid = true;
			if (e.deleted) {
				_deletedEntriesCount--;
				e.deleted = false;
			}
			e.key = key;
			new (&e.value) V();
			e.value = value;
			return true;
		}
	}
	
	public boolean insert(K key, V value) {
		ref<Entry> e = findEntry(key);
		if (e.valid && !e.deleted)
			return false;
		else {
			if (hadToRehash())
				e = findEntry(key);
			_entriesCount++;
			if (e.deleted) {
				_deletedEntriesCount--;
				e.deleted = false;
			}
			e.valid = true;
			e.key = key;
			new (&e.value) V();
			e.value = value;
			return true;
		}
	}
	
	public V replace(K key, V value) {
		ref<Entry> e = findEntry(key);
		V result;
		if (e.valid && !e.deleted) {
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
		if (e.valid && !e.deleted)
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
		if (e.deleted) {
			_deletedEntriesCount--;
			e.deleted = false;
		}
		e.key = key;
		new (&e.value) V();
		return &e.value;
	}
	
	public boolean remove(K key) {
		ref<Entry> e = findEntry(key);
		if (e.valid) {
			if (!e.deleted) {
				e.value.~();
				e.deleted = true;
				_deletedEntriesCount++;
				return true;
			}
		}
		return false;
	}
	
	public boolean remove(K key, ref<memory.Allocator> allocator) {
		ref<Entry> e = findEntry(key, allocator);
		if (e.valid) {
			if (!e.deleted) {
				e.value.~();
				e.deleted = true;
				_deletedEntriesCount++;
				return true;
			}
		}
		return false;
	}
	
	public void set(K key, V value) {
		*createEmpty(key) = value;
	}
	
	private ref<Entry> findEntryReadOnly(K key) {
		if (_entries == null)
			return null;
		int x = key.hash() & (_allocatedEntries - 1);
		int startx = x;
		for(;;) {
			ref<Entry> e = ref<Entry>(_entries + x);
			if (!e.valid || e.deleted || e.key.compare(key) == 0)
				return e;
			x++;
			if (x >= _allocatedEntries)
				x = 0;
		}
	}

	private ref<Entry> findEntry(K key, ref<memory.Allocator> allocator) {
		if (_entries == null) {
			_entries = pointer<Entry>(allocator.alloc(INITIAL_TABLE_SIZE * Entry.bytes));
			_allocatedEntries = INITIAL_TABLE_SIZE;
			setRehashThreshold();
		}
		int x = key.hash() & (_allocatedEntries - 1);
		int startx = x;
		ref<Entry> deletedE = null;
		for(;;) {
			ref<Entry> e = ref<Entry>(_entries + x);
			if (!e.valid) {
				if (deletedE != null)
					return deletedE;
				else
					return e;
			}
			if (e.key.compare(key) == 0)
				return e;
			if (e.deleted)
				deletedE = e;
			x++;
			if (x >= _allocatedEntries)
				x = 0;
		}
	}

	private ref<Entry> findEntry(K key) {
		if (_entries == null) {
			_entries = pointer<Entry>(memory.alloc(INITIAL_TABLE_SIZE * Entry.bytes));
			_allocatedEntries = INITIAL_TABLE_SIZE;
			setRehashThreshold();
		}
		int x = key.hash() & (_allocatedEntries - 1);
		int startx = x;
		ref<Entry> deletedE = null;
		for(;;) {
			ref<Entry> e = ref<Entry>(_entries + x);
			if (!e.valid) {
				if (deletedE != null)
					return deletedE;
				else
					return e;
			}
			if (e.key.compare(key) == 0)
				return e;
			if (e.deleted)
				deletedE = e;
			x++;
			if (x >= _allocatedEntries)
				x = 0;
		}
	}

	private boolean hadToRehash(ref<memory.Allocator> allocator) {
		if (_entriesCount >= _rehashThreshold) {
			pointer<Entry> oldE = _entries;
			_allocatedEntries *= 2;
			_entries = pointer<Entry>(allocator.alloc(_allocatedEntries * Entry.bytes));
			int e = _entriesCount;
			_entriesCount = 0;
			for (int i = 0; e > 0; i++) {
				if (oldE[i].valid && !oldE[i].deleted) {
					insert(oldE[i].key, oldE[i].value);
					e--;
					oldE[i].value.~();
				}
			}
			setRehashThreshold();
			allocator.free(oldE);
			return true;
		} else
			return false;
	}
	
	private boolean hadToRehash() {
		if (_entriesCount >= _rehashThreshold) {
			pointer<Entry> oldE = _entries;
			_allocatedEntries *= 2;
			_entries = pointer<Entry>(memory.alloc(_allocatedEntries * Entry.bytes));
			int e = _entriesCount - _deletedEntriesCount;
			_entriesCount = 0;
			for (int i = 0; e > 0; i++) {
//				printf("[%d/%d] %s %s\n", i, e, oldE[i].valid ? "valid" : "empty", oldE[i].deleted ? "deleted" : "");
				if (oldE[i].valid && !oldE[i].deleted) {
					insert(oldE[i].key, oldE[i].value);
					e--;
					oldE[i].value.~();
				}
			}
			setRehashThreshold();
			memory.free(oldE);
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
		public boolean	deleted;
	}

	public iterator begin() {
		iterator i(this);
		if (size() == 0)
			i._index = _allocatedEntries;
		else {
			for (i._index = 0; i._index < _allocatedEntries; i._index++)
				if (_entries[i._index].valid && !_entries[i._index].deleted)
					break;
		}
		return i;
	}

	public class iterator {
		int				_index;
		ref<map<V, K>>	_dictionary;

		// This is to suppress the dumb rule that you can't initialize a variable with a value when there is no
		// default constructor for the object.
		iterator() {
		}
		
		iterator(ref<map<V, K>> dict) {
			_dictionary = dict;
			_index = 0;
		}

		public boolean hasNext() {
			return _index < _dictionary._allocatedEntries;
		}

		public void next() {
			do
				_index++;
			while (_index < _dictionary._allocatedEntries &&
				   !(_dictionary._entries[_index].valid && !_dictionary._entries[_index].deleted));
		}

		public V get() {
			return _dictionary._entries[_index].value;
		}

		public K key() {
			return _dictionary._entries[_index].key;
		}

	};
}

import parasol:text;

void splat(var x) {
	printf("Splat %s:\n", x);
	text.memDump(&x, 600);
}