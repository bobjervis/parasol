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
namespace parasol:types;

public class address {
/*
	public int hash() {
		return int(*this);
	}

	public int compare(address a) {
		long diff = long(*this) - long(a);
		if (diff > 0)
			return 1;
		else if (diff < 0)
			return -1;
		else
			return 0;
	}
 */
}

public class boolean {
//	public boolean() {
//	}
	
//	public boolean(boolean value) {
//	}
}

@Final 
public class void {}

public class ClassInfo {}
public class `*Namespace*` {}
public class `*deferred*`{}
public class `*array*`{}
public class `*object*`{}

public class Array {
	private var[] _elements;
	
	public var get(int i) {
		return _elements[i];
	}
	
	public void set(int i, var x) {
		_elements[i] = x;
	}
	
	public void push(var x) {
		_elements.append(x);
	}
	
	public var pop() {
		if (_elements.length() > 0) {
			var x = _elements[_elements.length() - 1];
			_elements.resize(_elements.length() - 1);
			return x;
		} else
			return var();
	}
	
	public int length() {
		return _elements.length();
	}
}

public class Object {
	private var[string] _members;
	
	public var get(string key) {
		return _members[key];
	}
	
	public void set(string key, var value) {
		_members[key] = value;
	}
	
	public void remove(string key) {
		_members.remove(key);
	}

	public int size() {
		return _members.size();
	}
	
	public ref<var[string]> members() {
		return &_members;
	}

	public boolean contains(string member) {
		return _members.contains(member);
	}
}

public class Queue<class T> {
	@Constant
	private static int MIN_CAPACITY = 16;
	
	pointer<T> _items;
	int _capacity;
	int _first;
	int _last;
	
	
	public Queue() {
		resize(MIN_CAPACITY);
	}
	
	public ~Queue() {
		destroyItems();
		memory.free(_items);
	}
	
	public void clear() {
		destroyItems();
		_first = 0;
		_last = 0;
		resize(MIN_CAPACITY);
	}
	
	private void destroyItems() {
		// If the block of valid items is split, copy the high end first
		if (_first > _last) {
			for (int j = _first; j < _capacity; j++)
				_items[j].~();
			_first = 0;
		}
		for (int j = _first; j < _last; j++)
			_items[j].~();
	}

	public boolean isEmpty() {
		return _first == _last;
	}
	
	public int length() {
		if (_first <= _last)
			return _last - _first;
		else
			return _last + _capacity - _first;
	}

	public T peek(int i) {
		i += _first;
		i %= _capacity;
		return _items[i];
	}

	public void enqueue(T t) {
		if (length() >= _capacity - 1)
			resize(_capacity << 1);
		new (&_items[_last]) T();
		_items[_last] = t;
		_last++;
		if (_last >= _capacity)
			_last = 0;
	}
	
	public T dequeue() {
		if (_first == _last)
			throw BoundsException("dequeue of empty queue");
		T result = _items[_first];
		_items[_first].~();
		_first++;
		if (_first >= _capacity)
			_first = 0;
		if (_capacity > MIN_CAPACITY) {
			int halfCapacity = _capacity >> 1;
			if (length() < halfCapacity)
				resize(halfCapacity);
		}
		return result;
	}

	public void resize(int newLength) {
		pointer<T> a = pointer<T>(memory.alloc(newLength * T.bytes));
		if (_items != null) {
			int i = 0;
			// If the block of valid items is split, copy the high end first
			if (_first > _last) {
				for (int j = _first; j < _capacity; j++, i++)
					a[i] = _items[j];
				_first = 0;
			}
			for (int j = _first; j < _last; j++, i++)
				a[i] = _items[j];
			_first = 0;
			_last = i;
			memory.free(_items);
		}
		_items = a;
		_capacity = newLength;
	}
}