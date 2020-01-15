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
/**
 * This namespace defines facilities for defined various general purpose classes.
 *
 * The classes include numeric classes for native machine arithmetic, address
 * classes for objects that are machine addresses, boolean for the value of test
 * conditions in looping and alternation statements, var as a class that can hold a
 * value of a variety of types, and an assortment of collection classes.
 *
 * Collection classes tend to be templates as they are designed to be flexibly usable
 * across a broad range of applications.
 *
 * <h3>Collections</h3>
 *
 * Parasol supports a variety of collections of objects.
 *
 * <h4>Object arrays</h4>
 *
 * There is currently no supported syntax to declare an object array. An object array is
 * a contiguous region of memory containing a number of distinct objects, all of the same 
 * type and with no space between the objects. There is no information embedded in the memory
 * to indicate the number of objects in the array.
 *
 * Vector and string types encapsulate object arrays. They provide additional information
 * about the length of the object array they utilize and may re-allocate the object array
 * when you change the length of the vector or string.
 *
 * Pointer objects can be used to iterate through an object array. The difference between
 * two pointer objects only makes sense if they point to elements of the same object
 * array. It is guaranteed that a pointer can be positioned at any element of the object
 * array and can access the element stored there.
 *
 * A Parasol compiler must allocate memory in such a way that the address of the next byte
 * after an object array has to be in the valid range of machine addresses and must compare
 * greater than any machine addresses in the object array itself. There is no promise about
 * the ability to read or write memory at that location, only that when doing address
 * arithmetic, machine addresses get larger and a construct of the form below works all the
 * time:
 *
 *<pre>{@code
 *        byte[] a;
 *        for (pointer\<byte\> p = &a[0]; p \< &a[0] + a.length(); p++) ...
 *}</pre>
 *
 * <h4>Vectors</h4>
 *
 * A vector is a resizable collection of objects of the same type. Like many collections,
 * items in a vector can be identified by a key. A vector's key must have some scalar integral
 * type or an {@code enum} class. The items in a vector are stored as elements of an object
 * array, with each element's key being it's index within the object array.
 *
 * Any operator that is valid for some scalar type can be applied to a vector of that scalar
 * type. Any function or method that takes some scalar type for one of it's arguments
 * can take a vector at that same argument. The operations or calls are carried out for
 * each of the elements of the vector in an unspecified order (possibly in parallel).
 *
 * Multiple vector arguments can be supplied,
 * provided they have a common <i>shape</i>. Two vectors have the same shape if the type
 * of their key is the same. For example, all vectors declared with a given enum class as
 * their key can be used together in vector expressions, while none of them could be used
 * in a vector expression with a vector keyed by int (the default vector key type).
 *
 * <h4>Maps</h4>
 *
 * A map is a collection of objects of the same type, keyed by any scalar object type that
 * has a defined {@code hash} method and a {@code compare} method. A map supports inserting
 * new elements into the map, getting an existing element based on it's key, and for detecting
 * whether the key is present. It must also provide a reasonably efficient scheme for
 * iterating over the elements of the map, in no particular order.
 *
 * Elements of a map can be deleted.
 *
 * <h4>Array and Object</h4>
 *
 * These classes are named to correspond to the equivalent Javascript types. They are intended
 * to help full-stack developers who have to work with exchanging JSON payloads with a browser.
 *
 * The Array type is just a synonym for {@code var[]}. You can therefore subscript an Array object,
 * use it in a vectorized statement, or use it in a for-in statement.
 *
 * Similarly, Object is a synonym for {@code var[string]}. You can therefore use subscripting and
 * the for-in statement with Object objects.
 */
namespace parasol:types;

import parasol:memory;
import parasol:exception.BoundsException;
/**
 * This class holds a machine address.
 *
 * There is no associated type information about the memory at that location.
 *
 * An address object is an unordered class. You can only cmopare addresses for
 * equality.
 *
 * The distinguished value null is distinct from the address of any valid object.
 *
 * The keyword {@code null} has this type. Null can, however, be converted to any string,
 * reference or pointer type.
 */
public class address {
}
/**
 * This class is the type of any comparison operator.
 *
 * A boolean can only be assigned the value of another boolean or the keywords
 * {@code true} and {@code false}.
 *
 * Boolean values are unordered. You can only compare two boolean values for equality.
 *
 * You may apply the bit-wise and ({@code &}), or ({@code |}) and exclusive-or {@code ^}
 * binary operators as well as the unary not ({@code !} operator. This permits you to
 * perform boolean arithmetic when needed. Both operands of the binary operators are
 * evaluated, including side-effects.
 *
 * The most common combination can be expressed as the short-cut operators and-andd ({@code &&})
 * and or-or ({@code ||}). These carry out the appropriate boolean operations, but unlike 
 * the above binary operators, these will only evaluate and apply the side-effects of
 * the left-hand operand and if that operand's value determines the result, the right-hand
 * operand is not evaluated and no side-effects are produced. For an and-and operator, if the
 * left-hand side is false, the value of the right-hand side is not calculated. For an or-or
 * operator, if the left-hand operand is true, the value of the right-hand side is not evaluated.
 */
public class boolean {
}
/**
 * A pseudo-class that serves a primarily syntactic function.
 *
 * This can only appear as the single return type of a function. In that one instance,
 * the type 'void' is re-interpreted to mean that the function returns no value at all.
 *
 * The identifier 'void' can be used at runtime to refer to the void class itself, although
 * what purpose that could serve is unclear.
 */
public class void {}

public class ClassInfo {}
public class `*Namespace*` {}
public class `*deferred*`{}
public class `*array*`{}
public class `*object*`{}
/**
 * A reference to an object.
 *
 * This is a machine address of an object of known type.
 *
 * A null constant can be coerced into any reference type.
 *
 * References are unordered. You can only compare references for equality.
 *
 * You can use the indirect operator to obtain the object the reference designates.
 *
 * You may also use the dot operator to select a method or member of the referenced
 * object. Like an address, references have no methods or members of their own.
 */
@Ref
public class ref<class T> extends address {
}
/**
 * A pointer to an array of objects.
 *
 * This is a machine address of an array of objects of known type.
 *
 * A null constant can be coerced into any pointer type.
 *
 * Pointers are fully ordered. You can compare pointers as you can for any
 * integral type. The null value will compare less than any other pointer value.
 *
 * You can use the indirect or subscript operators to obtain an object the pointer designates.
 *
 * You may also use the dot operator to select a method or member of the referenced
 * object. Like an address, references have no methods or members of their own.
 */
@Pointer
public class pointer<class T> extends address {
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