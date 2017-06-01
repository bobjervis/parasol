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
#ifndef COMMON_VECTOR_H
#define COMMON_VECTOR_H
#define null 0

template<class A>
class vector;

template<class A>
void sort(vector<A*>* a, int min, int max, bool ascending) {
	if (min >= max)
		return;
	A* pivot = (*a)[min];
	int greaterFillPoint = max;
	int i = min + 1;
	while (i < greaterFillPoint) {
		int relation = pivot->compare((*a)[i]);
		if (!ascending)
			relation = -relation;
		if (relation < 0) {
			greaterFillPoint--;
			A* high = (*a)[greaterFillPoint];
			(*a)[greaterFillPoint] = (*a)[i];
			(*a)[i] = high;
		} else {
			(*a)[i - 1] = (*a)[i];
			i++;
		}
	}
	(*a)[i - 1] = pivot;
	sort(a, min, i - 1, ascending);
	sort(a, i, max, ascending);
}

template<class A>
class vector {
public:
	vector(int initialSize) {
		_elements = null;
		_elementCount = 0;
		_allocatedCount = 0;
		resize(initialSize);
	}

	vector() {
		_elements = null;
		_elementCount = 0;
		_allocatedCount = 0;
	}

	~vector() {
		delete [] (A*)_elements;
	}
	/*
	 * Takes ownership of the array represented by data and length.
	 */
	void transfer(A *data, int length) {
		clear();
		_elements = data;
		_elementCount = length;
		_allocatedCount = length;
	}

	int size() const { return _elementCount; }

	void clear() {
		delete [] (A*)_elements;
		_elements = null;
		_elementCount = 0;
		_allocatedCount = 0;
	}

	void deleteAll() {
		if (_elements) {
			for (int i = 0; i < _elementCount; i++)
				delete _elements->data[i];
		}
		clear();
	}

	static const int npos = -1;

	int find(A a) {
		if (_elements) {
			for (int i = 0; i < _elementCount; i++)
				if (_elements->data[i] == a)
					return i;
		}
		return npos;
	}

	void resize(int length) {
		int new_size;
		if (_elements) {
			if (_allocatedCount >= length) {
				if (length == 0)
					clear();
				else
					_elementCount = length;
				return;
			}
			new_size = reserved_size(length);
			if (_allocatedCount == new_size) {
				_elementCount = length;
				return;
			}
		} else {
			if (length == 0)
				return;
			new_size = reserved_size(length);
		}
		A* a = new A[new_size];
		if (_elements) {
			for (int i = 0; i < _elementCount; i++)
				a[i] = _elements->data[i];
			delete [] (A*)_elements;
		}
		_allocatedCount = new_size;
		_elements = (SA*)a;
		_elementCount = length;
	}

	void push_back(A a) {
		resize(_elementCount + 1);
		_elements->data[_elementCount - 1] = a;
	}

	A pop_back() {
		A a = _elements->data[_elementCount - 1];
		resize(_elementCount - 1);
		return a;
	}

	A peek_back() {
		return _elements->data[_elementCount - 1];
	}

	void remove(int i, int count = 1) {
		if (i < 0 || i >= _elementCount)
			return;
		if (i + count > _elementCount)
			count = _elementCount - i;
		for (int j = i + count; j < _elementCount; j++)
			_elements->data[j - count] = _elements->data[j];
		resize(_elementCount - count);
	}

	void insert(int i, A a) {
		if (i < 0 || i > _elementCount)
			return;
		resize(_elementCount + 1);
		for (int j = _elementCount - 1; j > i; j--)
			_elements->data[j] = _elements->data[j - 1];
		_elements->data[i] = a;
	}

	void sort(bool ascending = true) {
		::sort(this, 0, _elementCount, ascending);
	}

	bool contains(A x) const {
		for (int i = 0; i < _elementCount; i++) {
			if (x == _elements->data[i])
				return true;
		}
		return false;
	}

	void setAll(A x) {
		for (int i = 0; i < _elementCount; i++)
			_elements->data[i] = x;
	}

	double mean() {
		double m = 0;
		for (int i = 0; i < _elementCount; i++) {
			m += _elements->data[i];
		}
		return m / _elementCount;
	}

	double variance() {
		double m = mean();
		double v = 0;
		for (int i = 0; i < _elementCount; i++) {
			double d = (_elements->data[i] - m);
			v += d * d;
		}
		return v / _elementCount;
	}

	A& operator [](int i) {
		return _elements->data[i];
	}

	const A& operator [] (int i) const {
		return _elements->data[i];
	}

private:
	static const int MIN_SIZE = 0x10;

	int reserved_size(int length) {
		int used_size = length;
		int alloc_size = MIN_SIZE;
		while (alloc_size < used_size)
			alloc_size <<= 1;
		return alloc_size;
	}

	struct SA {
		A		data[5];
	};

	SA*			_elements;
	int			_elementCount;
	int			_allocatedCount;
};

template<class A, class Key>
int binarySearch(const vector<A>& a, const Key& key) {
	int min = 0;
	int max = a.size();

	while (min <= max) {
		int mid = (max + min) / 2;
		int relation = key.compare(a[mid]);
		if (relation == 0)
			return mid;
		if (relation < 0)
			max = mid - 1;
		else
			min = mid + 1;
	}
	return -1;
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
template<class A, class Key>
int binarySearchClosestGreater(const vector<A>& a, const Key& key) {
	int min = 0;
	int max = a.size() - 1;
	int mid = -1;
	int relation = -1;

	while (min <= max) {
		mid = (max + min) / 2;
		relation = key.compare(a[mid]);
		if (relation == 0)
			return mid;
		if (relation < 0)
			max = mid - 1;
		else
			min = mid + 1;
	}
	if (relation > 0)
		mid++;
	return mid;
}

#endif // COMMON_VECTOR_H
