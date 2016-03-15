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
namespace parasol:file;

import native:C;
import native:windows;
import native:windows.HANDLE;

public int EOF = -1;

public class File {
	
	private ref<C.FILE> _handle;
	
	public File(ref<C.FILE> handle) {
		_handle = handle;
	}
	
	public File() {
	}

	public boolean opened() {
		return _handle != null;
	}
	
	public boolean close() {
		if (_handle != null) {
			boolean result = C.fclose(_handle) == 0;
			_handle = null;
			return result;
		} else
			return false;
	}
	
	public string, boolean readAll() {
		seek(0, Seek.END);
		int pos = tell();
		seek(0, Seek.START);
		string data;
		
		data.resize(pos);
		unsigned n = C.fread(&data[0], 1, unsigned(pos), _handle);
		if (C.ferror(_handle) != 0)
			return "", false;
		data.resize(int(n));
		return data, true;
	}
	
	public string, boolean readLine() {
		string line;
		
		for (;;) {
			int c = read();
			if (c == EOF) {
				if (C.ferror(_handle) == 0) {
					if (line.length() == 0)
						return null, true;
					else
						return line, true;
				} else if (line.length() == 0)
					return null, false;
				else
					return line, false;
			}
			line.append(byte(c));
			if (c == '\n')
				return line, true;
		}
	}
	public int read() {
		return C.fgetc(_handle);
	}
	
	public int tell() {
		return C.ftell(_handle);
	}
	
	public int seek(int offset, Seek whence) {
		switch (whence) {
		case START:
			return C.fseek(_handle, offset, C.SEEK_SET);
			
		case CURRENT:
			return C.fseek(_handle, offset, C.SEEK_CUR);
			
		case END:
			return C.fseek(_handle, offset, C.SEEK_END);
		}
		return -1;
	}
	
	public int printf(string format, var... args) {
		string s;
		
		s.printf(format, args);
		return write(&s[0], s.length());
	}
	
	public int write(byte[] buffer) {
		unsigned n = C.fwrite(&buffer[0], 1, unsigned(buffer.length()), _handle);
		if (C.ferror(_handle) != 0)
			return -1;
		return int(n);
	}

	public int write(string buffer) {
		unsigned n = C.fwrite(&buffer[0], 1, unsigned(buffer.length()), _handle);
		if (C.ferror(_handle) != 0)
			return -1;
		return int(n);
	}

	public int write(address buffer, int length) {
		unsigned n = C.fwrite(buffer, 1, unsigned(length), _handle);
		if (C.ferror(_handle) != 0)
			return -1;
		return int(n);
	}
	
	public int read(byte[] buffer) {
		unsigned n = C.fread(&buffer[0], 1, unsigned(buffer.length()), _handle);
		if (C.ferror(_handle) != 0)
			return -1;
		return int(n);
	}

	public int read(address buffer, int length) {
		unsigned n = C.fread(buffer, 1, unsigned(length), _handle);
		if (C.ferror(_handle) != 0)
			return -1;
		return int(n);
	}
	
	public boolean hasError() {
		return C.ferror(_handle) != 0;
	}
}

enum Seek {
	START,
	CURRENT,
	END
}

public File openTextFile(string filename) {
	ref<C.FILE> f = C.fopen(filename.c_str(), "r".c_str());
	if (f == null) {
//		throw new 
	}
	File h(f);
	return h;
}
	
public File createTextFile(string filename) {
	ref<C.FILE> f = C.fopen(filename.c_str(), "w".c_str());
	if (f == null) {
//		throw new 
	}
	File h(f);
	return h;
}

public File openBinaryFile(string filename) {
	ref<C.FILE> f = C.fopen(filename.c_str(), "rb".c_str());
	if (f == null) {
//		throw new 
	}
	File h(f);
	return h;
}
	
public File createBinaryFile(string filename) {
	ref<C.FILE> f = C.fopen(filename.c_str(), "wb".c_str());
	if (f == null) {
//		throw new 
	}
	File h(f);
	return h;
}

public class Directory {
	private windows.HANDLE						_handle;
	private ref<windows.WIN32_FIND_DATA>		_data;
	private string								_directory;
	private string								_wildcard;

	public Directory(string path) {
		_handle = windows.INVALID_HANDLE_VALUE;
		_directory = path;
		_wildcard = "*";
		_data = ref<windows.WIN32_FIND_DATA>(memory.alloc(windows.sizeof_WIN32_FIND_DATA));
	}
/*
	~Directory() {
		memory.free(_data);
		if (_handle != windows.INVALID_HANDLE_VALUE)
			windows.FindClose(_handle);
	}
*/
	public void pattern(string wildcard) {
		_wildcard = wildcard;
	}

	boolean first() {
		string s = _directory + "\\" + _wildcard;
		_handle = HANDLE(windows.FindFirstFile(s.c_str(), _data));
		return _handle.isValid();
	}

	boolean next() {
		int result = windows.FindNextFile(_handle, _data);
		if (result != 0)
			return true;
		windows.FindClose(_handle);
		_handle = windows.INVALID_HANDLE_VALUE;
		return false;
	}

	public string currentName() {
		return _directory + "/" + _data.fileName();
	}

}

