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
namespace parasol:compiler;

import native:C;
import parasol:stream;

public class CompileString {
	pointer<byte> data;
	int length;

	CompileString() {
	}

	CompileString(ref<byte[]> value) {
		length = value.length();
		data = &(*value)[0];
	}
	
	CompileString(pointer<byte> value) {
		length = C.strlen(value);
		data = value;
	}
	
	CompileString(pointer<byte> value, int length) {
		this.length = length;
		data = value;
	}
	
	CompileString(string s) {
		length = s.length();
		data = &s[0];
	}

	public int compare(CompileString other) {
		if (length < other.length) {
			for (int i = 0; i < length; i++) {
				int diff = data[i] - other.data[i];
				if (diff != 0)
					return diff;
			}
			return -1;
		} else {
			for (int i = 0; i < other.length; i++) {
				int diff = data[i] - other.data[i];
				if (diff != 0)
					return diff;
			}
			return length - other.length;
		}
	}
	
	public boolean equals(CompileString other) {
		if (length != other.length)
			return false;
		for (int i = 0; i < length; i++)
			if (data[i] != other.data[i])
				return false;
		return true;
	}

	public boolean equals(pointer<byte> other) {
		if (length != C.strlen(other))
			return false;
		for (int i = 0; i < length; i++)
			if (data[i] != other[i])
				return false;
		return true;
	}
	
	public string asString() {
		if (data != null)
			return string(data, length);
		else
			return null;
	}
}

class CompileStringReader extends stream.Reader {
	CompileString _source;
	int _cursor;
	
	CompileStringReader(CompileString source) {
		_source = source;
	}
	
	public int _read() {
		if (_cursor >= _source.length)
			return stream.EOF;
		else
			return _source.data[_cursor++];
	}

	public void unread() {
		if (_cursor > 0)
			--_cursor;
	}
}

public class Location {
	public static Location OUT_OF_FILE(-1);

	public int		offset;
	
	public Location() {
	}
	
	public Location(int v) {
		offset = v;
	}

	public int compare(Location loc) {
		return offset - loc.offset;
	}

	public boolean isInFile() {
		return offset != OUT_OF_FILE.offset;
	}
}
