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

import native:C;
import native:linux;
/**
 * A variant with undefined value.
 *
 * The global symbol 'undefined' can be used with var symbols to check whether
 * the var has any value at all. In other words, the default constructor for a
 * var object will create a value that compares equal to the symbol 'undefined'. 
 */
//@Constant
public var undefined;
/**
 * An object that can hold 'any' value.
 *
 * Substring and substring16 objects are converted to the corresponding string or
 * string16 class.y
 *
 * Integer numeric objects are converted to long.
 *
 * Floating point objects are converted to double.
 *
 * Pointers and references are stored with their class,
 * so you can query the class of the var object to determine
 * exactly which address type it contains.
 *
 * Enum's and flag's are not currently convertible to var's.
 *
 * Small class types, like Time, can be stored in a var object.
 *
 * Large class types, larger than a long, cannot be stored in a
 * var object.
 */
public class var {
//	private class _actualType;
	private address _actualType;
	private long _value;
	
	public var() {
	}
	
	public var(var other) {
		_actualType = *ref<address>(&other);
		_value = long(other);
	}
	
	public var(string other) {
		_actualType = string;
		new (&_value) string(other);
	}
	
	public var(string16 other) {
		_actualType = string16;
		new (&_value) string16(other);
	}
	
	public var(substring other) {
		_actualType = string;
		new (&_value) string(other);
	}
	
	public var(substring16 other) {
		_actualType = string16;
		new (&_value) string16(other);
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

	private var(address actualType, address opAdr, int opLen) {
		C.memcpy(&_value, opAdr, opLen);
		_actualType = actualType;
	}

	private void stringEllip(long value) {
		_actualType = string;
		_value = value;
	}

	private void string16Ellip(long value) {
		_actualType = string16;
		_value = value;
	}

	~var() {
//		if (this.class == string) {
//			(*ref<string>(&_value)).~();
//		else if (this.class == string16)
//			(*ref<string16>(&_value)).~();
	}

	public address actualType() { 
		return _actualType;
	}
	
	var add(var other) {
		if (this.class == string || other.class == string) {
			string otherValue = string(other);
			string value = *ref<string>(&_value);
			return value + otherValue;
		}
		long x = _value + long(other);
		return x;
	}

	var and(var other) {
		long x = _value & long(other);
		return x;
	}

	public int compare(var other) {
		if (this.class != other.class)
			return int.MIN_VALUE;
		if (this.class == string || other.class == string) {
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
	
	void copy(var source) {
//		this.~();
		_actualType = *ref<address>(&source);
//		if (source.class == string)
//			new (&_value) string(*ref<string>(&source._value));
//		else if (source.class == string16)
//			new (&_value) string16(*ref<string16>(&source._value));
//		else
			_value = pointer<long>(&source)[1];
	}

	void copyTemp(var source) {
		_actualType = *ref<address>(&source);
//		if (source.class == string)
//			new (&_value) string(*ref<string>(&source._value));
//		else if (source.class == string16)
//			new (&_value) string16(*ref<string16>(&source._value));
//		else
			_value = pointer<long>(&source)[1];
	}
	
	var divide(var other) {
		long x = _value / long(other);
		return x;
	}
	
	var exclusiveOr(var other) {
		long x = _value ^ long(other);
		return x;
	}

	string stringValue() {
		return *ref<string>(&_value);
	}
	
	string16 string16Value() {
		return *ref<string16>(&_value);
	}
	
	long integerValue() {
		// TODO: Validate type and convert when necessary
		return _value;
	}

	double floatValue() {
		return *ref<double>(&_value);
	}
	
	void classValue(address out, int len) {
		C.memcpy(out, &_value, len);
	}

	var leftShift(var other) {
		long x = _value << int(other);
		return x;
	}
	
	var multiply(var other) {
		long x = _value * long(other);
		return x;
	}
	
	var or(var other) {
		long x = _value | long(other);
		return x;
	}

	var remainder(var other) {
		long x = _value % long(other);
		return x;
	}

	var rightShift(var other) {
		long x = _value >> int(other);
		return x;
	}

	var subtract(var other) {
		long x = _value - long(other);
		return x;
	}

	var unsignedRightShift(var other) {
		long x = _value >>> int(other);
		return x;
	}
}

