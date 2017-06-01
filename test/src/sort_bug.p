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
class vec<class E, class I> {
	private I _length;
	private I _capacity;
	private pointer<E> _data;
	
	public vec() {
		_capacity = I(0);
		_length = I(0);
	}
	
	~vec() {
		memory.free(_data);
	}
	
	public void append(E other) {
		resize(I(int(_length) + 1));
		_data[int(_length) - 1] = other;
	}

	public void clear() {
		memory.free(_data);
		_data = null;
		_length = I(0);
		_capacity = I(0);
	}
	
	public E get(I index) {
		return _data[int(index)];
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
		pointer<E> a = pointer<E>(memory.alloc(int(newSize) * E.bytes));
		if (_data != null) {
			for (I i = I(0); int(i) < int(_length); i = I(int(i) + 1))
				a[int(i)] = _data[int(i)];
			memory.free(_data);
		}
		_capacity = newSize;
		_data = a;
		_length = newLength;
	}
	
	private I reservedSize(I length) {
		return 0x10;
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
}

int f1 = 1;
int f2 = 2;
int f3 = 3;
int f4 = 4;

vec<ref<int>, int> a;

a.append(&f3);
a.append(&f4);
a.append(&f2);
a.append(&f1);

int comparator(ref<int> a, ref<int> b) {
	return *a - *b;
}

a.sort(comparator, true);

assert(*a.get(0) == 1);
assert(*a.get(1) == 2);
assert(*a.get(2) == 3);
assert(*a.get(3) == 4);

