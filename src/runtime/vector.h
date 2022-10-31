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
class vector {
public:
	vector() {
		_elements = null;
		_elementCount = 0;
		_allocatedCount = 0;
	}

	~vector() {
		delete [] (A*)_elements;
	}

	int size() const { return _elementCount; }

	void clear() {
		delete [] (A*)_elements;
		_elements = null;
		_elementCount = 0;
		_allocatedCount = 0;
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
#endif // COMMON_VECTOR_H
