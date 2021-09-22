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
namespace parasol:rpc;

import parasol:exception.IllegalArgumentException;
import parasol:stream;

void marshalBoolean(ref<string> output, ref<boolean> object) {
	(*output).append(*object ? 't' : 'f');
}

boolean unmarshalBoolean(ref<stream.Reader> value) {
	int ch = value.read();
	switch (ch) {
	case 't':
		return true;

	case 'f':
		return false;
	}
	string s;
	s.printf("Unexpected byte: %c", ch);
	throw IllegalArgumentException(s);
}

void marshalInt(ref<string> output, ref<int> object) {
	int value = *object;
	if (value >= -128 && value <= 127) {
		(*output).append('1');
		(*output) += substring(pointer<byte>(&value), 1);
	} else if (value >= -32768 && value <= 32767) {
		(*output).append('S');
		(*output) += substring(pointer<byte>(&value), 2);
	} else {
		(*output).append('i');
		(*output) += substring(pointer<byte>(&value), 4);
	}
}

int unmarshalInt(ref<stream.Reader> value) {
	int ch = value.read();
	switch (ch) {
	case '1':
		return value.read();

	case 'S':
		ch = value.read();
		return ch + (value.read() << 8);

	case 'i':
		ch = value.read();
		int c2 = value.read();
		int c3 = value.read();
		return ch + (c2 << 8) + (c3 << 16) + (value.read() << 24);
	}
	string s;
	s.printf("Unexpected prefix: %c", ch);
	throw IllegalArgumentException(s);
}

void marshalLong(ref<string> output, ref<long> object) {
	long value = *object;
	if (value >= -128 && value <= 127) {
		(*output).append('1');
		(*output) += substring(pointer<byte>(&value), 1);
	} else if (value >= -32768 && value <= 32767) {
		(*output).append('S');
		(*output) += substring(pointer<byte>(&value), 2);
	} else if (value >= int.MIN_VALUE && value <= int.MAX_VALUE) {
		(*output).append('i');
		(*output) += substring(pointer<byte>(&value), 4);
	} else {
		(*output).append('L');
		(*output) += substring(pointer<byte>(&value), 8);
	}
}

long unmarshalLong(ref<stream.Reader> value) {
	int ch = value.read();
	switch (ch) {
	case '1':
		return value.read();

	case 'S':
		ch = value.read();
		return ch + (value.read() << 8);

	case 'i':
		ch = value.read();
		int c2 = value.read();
		int c3 = value.read();
		return ch + long(c2 << 8) + (c3 << 16) + (value.read() << 24);

	case 'L':
		ch = value.read();
		c2 = value.read();
		c3 = value.read();
		int c4 = value.read();
		int c5 = value.read();
		int c6 = value.read();
		int c7 = value.read();
		return ch + (c2 << 8) + (c3 << 16) + (c4 << 24) + (long(c5) << 32) + (long(c6) << 40) + (long(c7) << 48) + (long(value.read()) << 56);
	}
	string s;
	s.printf("Unexpected prefix: %c", ch);
	throw IllegalArgumentException(s);
}

void marshalUnsigned(ref<string> output, ref<unsigned> object) {
	unsigned value = *object;
	if (value <= unsigned(byte.MAX_VALUE)) {
		(*output).append('b');
		(*output) += substring(pointer<byte>(&value), 1);
	} else if (value <= unsigned(char.MAX_VALUE)) {
		(*output).append('c');
		(*output) += substring(pointer<byte>(&value), 2);
	} else {
		(*output).append('u');
		(*output) += substring(pointer<byte>(&value), 4);
	}
}

unsigned unmarshalUnsigned(ref<stream.Reader> value) {
	int ch = value.read();
	switch (ch) {
	case 'b':
		return unsigned(value.read());

	case 'c':
		ch = value.read();
		return unsigned(ch + (value.read() << 8));

	case 'u':
		ch = value.read();
		int c2 = value.read();
		int c3 = value.read();
		return unsigned(ch + (c2 << 8) + (c3 << 16) + (value.read() << 24));
	}
	string s;
	s.printf("Unexpected prefix: %c", ch);
	throw IllegalArgumentException(s);
}


void marshalString(ref<string> output, ref<string> object) {
	if (object == null)
		(*output).append('N');
	else if (object.length() == 0)
		(*output).append('Z');
	else {
		int len = object.length();
		marshalInt(output, &len);
		(*output).append(*object);
	}
}

string unmarshalString(ref<stream.Reader> value) {
	int ch = value.read();
	switch (ch) {
	case 'N':
		return null;

	case 'Z':
		return "";
	}
	value.unread();
	int len = unmarshalInt(value);
	byte[] result;
	for (int i = 0; i < len; i++)
		result.append(byte(value.read()));
	return string(result);
}

