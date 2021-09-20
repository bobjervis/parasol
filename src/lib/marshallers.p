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

