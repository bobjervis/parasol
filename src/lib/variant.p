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
namespace parasol:variant;

public class var {
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

