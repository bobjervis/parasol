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
import parasol:log;
import parasol:stream;
import parasol:text;
import parasol:thread;

ref<log.Logger> logger = log.getLogger("rpc");

void marshalBoolean(ref<string> output, ref<boolean> object) {
	(*output).append(*object ? 't' : 'f');
}

boolean unmarshalBoolean(ref<pointer<byte>> value) {
	int ch = **value;
	++*value;
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

void marshalShort(ref<string> output, ref<short> object) {
	short value = *object;
	if (value >= -128 && value <= 127) {
		(*output).append('1');
		(*output) += substring(pointer<byte>(&value), 1);
	} else {
		(*output).append('S');
		(*output) += substring(pointer<byte>(&value), 2);
	}
}

short unmarshalShort(ref<pointer<byte>> value) {
	int ch = **value;
	++*value;
	switch (ch) {
	case '1':
		return short(short(*(*value)++ << 8) >> 8);

	case 'S':
		short s = *ref<short>(*value);
		*value += short.bytes;
		return s;
	}
	string s;
	s.printf("Unexpected prefix: %c", ch);
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

int unmarshalInt(ref<pointer<byte>> value) {
	int ch = **value;
	++*value;
	switch (ch) {
	case '1':
		return (*(*value)++ << 24) >> 24;

	case 'S':
		short s = *ref<short>(*value);
		*value += short.bytes;
		return s;

	case 'i':
		int v = *ref<int>(*value);
		*value += int.bytes;
		return v;
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

long unmarshalLong(ref<pointer<byte>> value) {
	int ch = **value;
	++*value;
	switch (ch) {
	case '1':
		return (*(*value)++ << 56) >> 56;

	case 'S':
		short s = *ref<short>(*value);
		*value += short.bytes;
		return s;

	case 'i':
		int v = *ref<int>(*value);
		*value += int.bytes;
		return v;

	case 'L':
		long lv = *ref<long>(*value);
		*value += long.bytes;
		return lv;
	}
	string s;
	s.printf("Unexpected prefix: %c", ch);
	throw IllegalArgumentException(s);
}

void marshalByte(ref<string> output, ref<byte> object) {
	(*output).append(*object);
}

byte unmarshalByte(ref<pointer<byte>> value) {
	return *(*value)++;
}

void marshalChar(ref<string> output, ref<char> object) {
	char value = *object;
	if (value <= byte.MAX_VALUE) {
		(*output).append('b');
		(*output) += substring(pointer<byte>(&value), 1);
	} else {
		(*output).append('c');
		(*output) += substring(pointer<byte>(&value), 2);
	}
}

char unmarshalChar(ref<pointer<byte>> value) {
	int ch = **value;
	++*value;
	switch (ch) {
	case 'b':
		return char(*(*value)++);

	case 'c':
		char c = *ref<char>(*value);
		*value += char.bytes;
		return c;
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

unsigned unmarshalUnsigned(ref<pointer<byte>> value) {
	int ch = **value;
	++*value;
	switch (ch) {
	case 'b':
		return unsigned(*(*value)++);

	case 'c':
		char c = *ref<char>(*value);
		*value += char.bytes;
		return c;

	case 'u':
		unsigned u = *ref<unsigned>(*value);
		*value += unsigned.bytes;
		return u;
	}
	string s;
	s.printf("Unexpected prefix: %c", ch);
	throw IllegalArgumentException(s);
}

void marshalString(ref<string> output, ref<string> object) {
	if (*object == null)
		(*output).append('N');
	else if (object.length() == 0)
		(*output).append('Z');
	else {
		int len = object.length();
		marshalInt(output, &len);
		(*output).append(*object);
	}
}

string unmarshalString(ref<pointer<byte>> value) {
	int ch = **value;
	switch (ch) {
	case 'N':
		++*value;
		return null;

	case 'Z':
		++*value;
		return "";
	}
	int len = unmarshalInt(value);
	string result(*value, len);
	*value += len;
	return result;
}

