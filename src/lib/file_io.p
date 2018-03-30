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
namespace parasol:storage;

import native:C;
import native:windows;
import native:windows.HANDLE;
import native:linux;
import parasol:runtime;

@Constant
public int EOF = -1;

public class File {
	private long _fd;

	File(long fd) {
		_fd = fd;
	}

	public File() {
		_fd = -1;
	}

	public boolean open(string filename) {
		return open(filename, Access.READ);
	}

	public boolean open(string filename, Access access) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD rights;
			windows.DWORD sharing;
			windows.DWORD disposition;
			if (access & Access.READ) {
				rights = windows.GENERIC_READ;
				if (access & Access.WRITE)
					rights |= windows.GENERIC_WRITE;
				else
					sharing = windows.FILE_SHARE_READ;
				disposition = windows.OPEN_EXISTING;
			} else if (access & Access.WRITE) {
				rights = windows.GENERIC_WRITE;
			}
			windows.HANDLE handle = windows.CreateFile(filename.c_str(), rights, sharing, null, 
													disposition, windows.FILE_ATTRIBUTE_NORMAL, null);
			if (handle != windows.INVALID_HANDLE_VALUE) {
				_fd = long(handle);
				return true;
			}
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int openFlags;

			if (access & Access.READ) {
				if (access & Access.WRITE)
					openFlags = linux.O_RDWR;
				else
					openFlags = linux.O_RDONLY;
			} else if (access & Access.WRITE) {
				openFlags = linux.O_WRONLY;
			}
		
			_fd = linux.open(filename.c_str(), openFlags);
			if (_fd >= 0)
				return true;
		}
		return false;
	}

	public boolean create(string filename) {
		return create(filename, Access.WRITE);
	}

	public boolean create(string filename, Access access) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD rights;
			if (access & Access.READ) {
				rights = windows.GENERIC_READ;
				if (access & Access.WRITE)
					rights |= windows.GENERIC_WRITE;
			} else if (access & Access.WRITE) {
				rights = windows.GENERIC_WRITE;
			}
			windows.HANDLE handle = windows.CreateFile(filename.c_str(), rights, 0, null, 
													windows.CREATE_ALWAYS, windows.FILE_ATTRIBUTE_NORMAL, null);
			if (handle != windows.INVALID_HANDLE_VALUE) {
				_fd = long(handle);
				return true;
			}
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int openFlags;

			if (access & Access.READ) {
				if (access & Access.WRITE)
					openFlags = linux.O_RDWR;
				else
					openFlags = linux.O_RDONLY;
			} else if (access & Access.WRITE) {
				openFlags = linux.O_WRONLY;
			}
			openFlags |= linux.O_CREATE|linux.O_TRUNC;
		
			_fd = linux.open(filename.c_str(), openFlags);
			if (_fd >= 0)
				return true;
		}
		return false;
	}

	public boolean append(string filename) {
		return append(filename, Access.WRITE);
	}

	public boolean append(string filename, Access access) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			// append always fails on Windows
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int openFlags;

			if (access & Access.READ) {
				if (access & Access.WRITE)
					openFlags = linux.O_RDWR;
				else
					openFlags = linux.O_RDONLY;
			} else if (access & Access.WRITE) {
				openFlags = linux.O_WRONLY;
			}
			openFlags |= linux.O_CREATE|linux.O_APPEND;
			_fd = linux.open(filename.c_str(), openFlags);
			if (_fd >= 0)
				return true;
		}
		return false;
	}

	public boolean isOpen() {
		return _fd >= 0;
	}

	public boolean close() {
		if (_fd >= 0) {
			if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
				if (windows.CloseHandle(windows.HANDLE(_fd)) != 0) {
					_fd = -1;
					return true;
				}
			} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
				if (linux.close(int(_fd)) == 0) {
					_fd = -1;
					return true;
				}
			}
		}
		return false;
	}
/*
	
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
			if (c == '\r')
				continue;
			if (c == '\n')
				return line, true;
			line.append(byte(c));
		}
	}
 */
	/**
	 * @RETURN A value greater then or equal to zero on success, with the size of the file.
	 * A negative return value indicates an error. In the event of an error, the file position
	 * for any subsequent read or write operation is undefined.
	 */
	public long tell() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			long current;
			long end;
			if (windows.SetFilePointerEx(windows.HANDLE(_fd), 0, &current, windows.FILE_CURRENT) == 0)
				return -1;
			if (windows.SetFilePointerEx(windows.HANDLE(_fd), 0, &end, windows.FILE_END) == 0)
				return -1;
			if (windows.SetFilePointerEx(windows.HANDLE(_fd), current, null, windows.FILE_BEGIN) == 0)
				return -1;
			return end;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.off_t current = linux.lseek(int(_fd), 0, C.SEEK_CUR);
			linux.off_t end = linux.lseek(int(_fd), 0, C.SEEK_END);
			linux.lseek(int(_fd), current, C.SEEK_SET);
			return end;
		}
		return -1;
	}

	public long seek(long offset, Seek whence) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			long result;
			if (windows.SetFilePointerEx(windows.HANDLE(_fd), offset, &result, windows.DWORD(whence)) == 0)
				return -1;
			return result;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.lseek(int(_fd), offset, int(whence));
		}
		return -1;
	}

	public int write(byte[] buffer) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.WriteFile(windows.HANDLE(_fd), &buffer[0], windows.DWORD(buffer.length()), &result, null) == 0)
				return -1;
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.write(int(_fd), &buffer[0], buffer.length());
		}
		return -1;
	}

	public int write(string buffer) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.WriteFile(windows.HANDLE(_fd), &buffer[0], windows.DWORD(buffer.length()), &result, null) == 0)
				return -1;
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.write(int(_fd), &buffer[0], buffer.length());
		}
		return -1;
	}

	public int write(address buffer, int length) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.WriteFile(windows.HANDLE(_fd), buffer, windows.DWORD(length), &result, null) == 0)
				return -1;
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.write(int(_fd), buffer, length);
		}
		return -1;
	}
	/**
	 * Force the file contents to disk.
	 */
	public boolean sync() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return windows.FlushFileBuffers(windows.HANDLE(_fd)) != 0;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.fdatasync(int(_fd)) == 0;
		} else
			return false;
	}

	public int read(ref<byte[]> buffer) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.ReadFile(windows.HANDLE(_fd), &(*buffer)[0], windows.DWORD(buffer.length()), &result, null) == 0)
				return -1;
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.read(int(_fd), &(*buffer)[0], buffer.length());
		}
		return -1;
	}

	public int read(address buffer, int length) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.ReadFile(windows.HANDLE(_fd), buffer, windows.DWORD(length), &result, null) == 0)
				return -1;
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.read(int(_fd), buffer, length);
		}
		return -1;
	}
}

flags Access {
	READ,
	WRITE
}

enum Seek {
	START,
	CURRENT,
	END
}

@Constant
int BUFFER_SIZE = 64 * 1024;

public class FileReader = BinaryFileReader;

public class BinaryFileReader extends Reader {
	private File _file;
	private byte[] _buffer;
	private int _cursor;
	private int _length;

	BinaryFileReader(File file) {
		_file = file;
		_buffer.resize(BUFFER_SIZE);
	}

	~BinaryFileReader() {
		_file.close();
	}

	public string, boolean readAll() {
		seek(0, Seek.END);
		long pos = tell();
		seek(0, Seek.START);
		string data;

		if (pos > int.MAX_VALUE)
			return "", false;
		data.resize(int(pos));
		
		int n = _file.read(&data[0], int(pos));
		if (n < 0)
			return "", false;
		data.resize(n);
		return data, true;
	}

	public int read() {
		if (_cursor >= _length) {
			_length = _file.read(&_buffer);
			if (_length == 0)
				return EOF;
			_cursor = 1;
			return _buffer[0];
		}
		return _buffer[_cursor++];
	}

	public void unread() {
		if (_cursor > 0)
			_cursor--;
	}

	public long tell() {
		return _file.seek(0, Seek.CURRENT) + _cursor - _length;
	}

	public long seek(long offset, Seek whence) {
		_length = 0;
		_cursor = 0;
		return _file.seek(offset, whence);
	}

	public void close() {
		_file.close();
		_buffer.clear();			// Release the file buffer now since we won't need it any more
		_length = 0;
		_cursor = 0;
	}
}

public class TextFileReader extends BinaryFileReader {
	TextFileReader(File file) {
		super(file);
	}

	public int read() {
		int c;

		do {
			c = super.read();
			if (c == 26) { // A ctrl-Z marks a text file EOF
				unread();
				return EOF;
			}
		} while (c == '\r');
		return c;
	}
}

public class FileWriter = BinaryFileWriter;

public class BinaryFileWriter extends Writer {
	private File _file;
	private byte[] _buffer;
	private int _fill;

	BinaryFileWriter(File file) {
		_file = file;
		_buffer.resize(BUFFER_SIZE);
	}

	~BinaryFileWriter() {
		flush();
		_file.close();
	}

	public void write(byte c) {
		_buffer[_fill] = c;
		_fill++;
		if (_fill >= BUFFER_SIZE)
			flush();
	}

	public long tell() {
		return _file.seek(0, Seek.CURRENT) + _fill;
	}

	public long seek(long offset, Seek whence) {
		flush();
		return _file.seek(offset, whence);
	}

	public void flush() {
		if (_fill > 0) {
			_file.write(&_buffer[0], _fill);
			_fill = 0;
		}
	}

	public void close() {
		flush();
		_file.close();
		_buffer.clear();			// Release the file buffer now since we won't need it any more
	}
}

public class BinaryFileAppendWriter extends BinaryFileWriter {
	BinaryFileAppendWriter(File file) {
		super(file);
	}

	public void flush() {
		seek(0, Seek.END);
		super.flush();
	}
}

public class TextFileWriter extends BinaryFileWriter {
	TextFileWriter(File file) {
		super(file);
	}

	public void write(byte c) {
		if (c == '\n')
			super.write('\r');
		super.write(c);
	}
}
/**
 * NOte: This class should nly be needed for Windows, which has no Append mode for files.
 */
public class TextFileAppendWriter extends TextFileWriter {
	TextFileAppendWriter(File file) {
		super(file);
	}

	public void flush() {
		seek(0, Seek.END);
		super.flush();
	}
}

public ref<FileReader> openTextFile(string filename) {
	File f;

	if (f.open(filename))
		return new TextFileReader(f);
	else
		return null;
}

public ref<FileWriter> appendTextFile(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		windows.HANDLE handle = windows.CreateFile(filename.c_str(), windows.GENERIC_WRITE, 0, null, 
												windows.OPEN_ALWAYS, windows.FILE_ATTRIBUTE_NORMAL, null);
		if (handle == windows.INVALID_HANDLE_VALUE)
			return null;
		return new TextFileAppendWriter(File(long(handle)));
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		File f;

		if (f.append(filename))
			return new TextFileWriter(f);
	}
	return null;
}

public ref<FileWriter> createTextFile(string filename) {
	File f;

	if (f.create(filename))
		return new TextFileWriter(f);
	else
		return null;
}

public ref<FileReader> openBinaryFile(string filename) {
	File f;

	if (f.open(filename))
		return new BinaryFileReader(f);
	else
		return null;
}

public ref<FileWriter> appendBinaryFile(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		windows.HANDLE handle = windows.CreateFile(filename.c_str(), windows.GENERIC_WRITE, 0, null, 
												windows.OPEN_ALWAYS, windows.FILE_ATTRIBUTE_NORMAL, null);
		if (handle == windows.INVALID_HANDLE_VALUE)
			return null;
		return new BinaryFileAppendWriter(File(long(handle)));
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		File f;

		if (f.append(filename))
			return new BinaryFileWriter(f);
	}
	return null;
}

public ref<FileWriter> createBinaryFile(string filename) {
	File f;

	if (f.create(filename))
		return new BinaryFileWriter(f);
	else
		return null;
}

public class Directory {
	private windows.HANDLE						_handle;
	private address								_data;
	private ref<linux.dirent>					_dirent;
	private string								_directory;
	private string								_wildcard;

	public Directory(string path) {
		_handle = windows.INVALID_HANDLE_VALUE;
//		if (path.length() == 0)
//			assert(false);
		_directory = path;
		_wildcard = "*";
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			_data = memory.alloc(windows.sizeof_WIN32_FIND_DATA);
	}

	~Directory() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			if (_handle != windows.INVALID_HANDLE_VALUE)
				windows.FindClose(_handle);
			memory.free(_data);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.closedir(ref<linux.DIR>(_data));
		}
	}
	
	public void pattern(string wildcard) {
		_wildcard = wildcard;
	}

	boolean first() {
		string s = _directory + "\\" + _wildcard;
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			_handle = HANDLE(windows.FindFirstFile(s.c_str(), ref<windows.WIN32_FIND_DATA>(_data)));
			return _handle != windows.INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			_data = linux.opendir(_directory.c_str());
			if (_data == null)
				return false;
			return next();
		} else
			return false;
	}

	boolean next() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			int result = windows.FindNextFile(_handle, ref<windows.WIN32_FIND_DATA>(_data));
			if (result != 0)
				return true;
			windows.FindClose(_handle);
			_handle = windows.INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			if (_dirent == null) {
				int name_max = linux.pathconf(_directory.c_str(), linux._PC_NAME_MAX);
				if (name_max == -1)         /* Limit not defined, or error */
				    name_max = 255;         /* Take a guess */
				int len = linux.dirent.bytes + name_max + 1;	// dirent is a dummy structure, the offset of d_name is 1 less than dirent.bytes
				_dirent = ref<linux.dirent>(memory.alloc(len));
			}
			ref<linux.dirent> resultbuf;
			int result = linux.readdir_r(ref<linux.DIR>(_data), _dirent, &resultbuf);
			if (result == 0) {
				return resultbuf != null;
			} else
				return false;
		}
		return false;
	}

	public string path() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return _directory + "/" + ref<windows.WIN32_FIND_DATA>(_data).fileName();
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return _directory + "/" + string(pointer<byte>(&_dirent.d_name));
		} else
			return null;
	}

	public string basename() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return ref<windows.WIN32_FIND_DATA>(_data).fileName();
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return string(pointer<byte>(&_dirent.d_name));
		} else
			return null;
	}
}

