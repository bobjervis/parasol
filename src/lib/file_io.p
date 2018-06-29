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
import parasol:memory;
import parasol:runtime;
import parasol:process;
/**
 * DO NOT CALL THIS FUNCTION
 *
 * This is an internal support function called early in the runtime startup. 
 * It is not intended for general use and calling it can cause memory leaks and loss
 * of any buffered input or output.
 */
public void setProcessStreams() {
	boolean stdinIsATTY;
	boolean stdoutIsATTY;
	boolean stderrIsATTY;

//	print("setProcessStreams\n");
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		process.stdin = new TextFileReader(File(0), true);
		process.stdout = new TextFileWriter(File(1), true);
		process.stderr = new TextFileWriter(File(2), true);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		process.stdin = new FileReader(File(0), true);
		process.stdout = new FileWriter(File(1), true);
		process.stderr = new FileWriter(File(2), true);
		if (linux.isatty(0) == 1)
			stdinIsATTY = true;
		if (linux.isatty(1) == 1)
			stdoutIsATTY = true;
		if (linux.isatty(2) == 1)
			stderrIsATTY = true;
	}
	if (stdoutIsATTY) {
//		print("stdout tty\n");
		process.stdout = new LineWriter(process.stdout);
		if (stdinIsATTY) {
			process.stdin = new StdinReader(process.stdin);
//			print("stdin tty\n");
		}
	}
	if (stderrIsATTY) {
		process.stderr = new ErrorWriter(process.stderr);
//		print("stderr tty\n");
	}
//	print("Process streams set up\n");
}

class FileShutdown {
	~FileShutdown() {
		process.stdout.flush();
	}
}

private FileShutdown f;

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

	public ref<Reader> getBinaryReader() {
		return new BinaryFileReader(*this, false);
	}

	public ref<Reader> getTextReader() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return new TextFileReader(*this, false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return new BinaryFileReader(*this, false);
		} else
			return null;
	}

	public ref<Writer> getBinaryWriter() {
		return new BinaryFileWriter(*this, false);
	}

	public ref<Writer> getTextWriter() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return new TextFileWriter(*this, false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return new BinaryFileWriter(*this, false);
		} else
			return null;
	}

	public boolean open(string filename) {
		return open(filename, AccessFlags.READ);
	}

	public boolean open(string filename, AccessFlags access) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD rights;
			windows.DWORD sharing;
			windows.DWORD disposition;
			if (access & AccessFlags.READ) {
				rights = windows.GENERIC_READ;
				if (access & AccessFlags.WRITE)
					rights |= windows.GENERIC_WRITE;
				else
					sharing = windows.FILE_SHARE_READ;
				disposition = windows.OPEN_EXISTING;
			} else if (access & AccessFlags.WRITE) {
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

			if (access & AccessFlags.READ) {
				if (access & AccessFlags.WRITE)
					openFlags = linux.O_RDWR;
				else
					openFlags = linux.O_RDONLY;
			} else if (access & AccessFlags.WRITE) {
				openFlags = linux.O_WRONLY;
			}
		
			_fd = linux.open(filename.c_str(), openFlags);
			if (_fd >= 0)
				return true;
		}
		return false;
	}

	public boolean create(string filename) {
		return create(filename, AccessFlags.WRITE);
	}

	public boolean create(string filename, AccessFlags access) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD rights;
			if (access & AccessFlags.READ) {
				rights = windows.GENERIC_READ;
				if (access & AccessFlags.WRITE)
					rights |= windows.GENERIC_WRITE;
			} else if (access & AccessFlags.WRITE) {
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

			if (access & AccessFlags.READ) {
				if (access & AccessFlags.WRITE)
					openFlags = linux.O_RDWR;
				else
					openFlags = linux.O_RDONLY;
			} else if (access & AccessFlags.WRITE) {
				openFlags = linux.O_WRONLY;
			}
			openFlags |= linux.O_CREATE|linux.O_TRUNC;
		
			_fd = linux.open(filename.c_str(), openFlags, 0666);
			if (_fd >= 0)
				return true;
		}
		return false;
	}

	public boolean appendTo(string filename) {
		return appendTo(filename, AccessFlags.WRITE);
	}

	public boolean appendTo(string filename, AccessFlags access) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			// append always fails on Windows
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int openFlags;

			if (access & AccessFlags.READ) {
				if (access & AccessFlags.WRITE)
					openFlags = linux.O_RDWR;
				else
					openFlags = linux.O_RDONLY;
			} else if (access & AccessFlags.WRITE) {
				openFlags = linux.O_WRONLY;
			}
			openFlags |= linux.O_CREATE|linux.O_APPEND;
			_fd = linux.open(filename.c_str(), openFlags, 0666);
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
			if (windows.SetFilePointerEx(windows.HANDLE(_fd), 0, &current, windows.FILE_CURRENT) == 0)
				return -1;
			return current;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.lseek(int(_fd), 0, C.SEEK_CUR);
		}
		return -1;
	}
	/**
	 * @RETURN A value greater then or equal to zero on success, with the size of the file.
	 * A negative return value indicates an error. In the event of an error, the file position
	 * for any subsequent read or write operation is undefined.
	 */
	public long size() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.statStruct statb;

			int result = linux.fstat(int(_fd), &statb);
			if (result != 0)
				return -1;
			return statb.st_size;
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
/**
 * File seek operations are relative to one of three places in the file.
 *
 * Positions in a file are always numbered from 0 at the start of the file.
 * File systems may provide sparse file implementations that permit unused sections
 * of the file to be unallocated, but at this level, the illusion of a contiguous
 * array of bytes is maintained.
 */
public enum Seek {
	/**
	 * The offset for the seek operation is relative to the start of the file.
	 */
	START,
	/**
	 * The offset for the seek operation is relative to the current offset of the file.
	 */
	CURRENT,
	/**
	 * The offset for the seek operation is relative to the end of the file.
	 */
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
	private boolean _closeOnDelete;

	BinaryFileReader(File file, boolean closeOnDelete) {
		_file = file;
		_closeOnDelete = closeOnDelete;
		_buffer.resize(BUFFER_SIZE);
	}

	~BinaryFileReader() {
		if (_closeOnDelete)
			_file.close();
	}

	public string, boolean readAll() {
		seek(0, Seek.END);					// seek the stream to flush the buffer.
		long pos = _file.tell();
		_file.seek(0, Seek.START);
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

	public int _read() {
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
	TextFileReader(File file, boolean closeOnDelete) {
		super(file, closeOnDelete);
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
	private Monitor _lock;
	private File _file;
	private byte[] _buffer;
	private int _fill;
	private boolean _closeOnDelete;

	BinaryFileWriter(File file, boolean closeOnDelete) {
		_file = file;
		_closeOnDelete = closeOnDelete;
		_buffer.resize(BUFFER_SIZE);
	}

	~BinaryFileWriter() {
		flush();
		if (_closeOnDelete)
			_file.close();
	}

	public void _write(byte c) {
		_buffer[_fill] = c;
		_fill++;
		if (_fill >= BUFFER_SIZE)
			flush();
	}

	public long tell() {
		lock (_lock) {
			return _file.seek(0, Seek.CURRENT) + _fill;
		}
	}

	public long seek(long offset, Seek whence) {
		lock (_lock) {
			flush();
			return _file.seek(offset, whence);
		}
	}

	public void flush() {
		lock (_lock) {
			if (_fill > 0) {
				_file.write(&_buffer[0], _fill);
				_fill = 0;
			}
		}
	}

	public void close() {
		lock (_lock) {
			flush();
			_file.close();
			_buffer.clear();			// Release the file buffer now since we won't need it any more
		}
	}

	public int write(address buffer, int length) {
		lock (_lock) {
			return super.write(buffer, length);
		}
	}

	public int write(string s) {
		lock (_lock) {
			return super.write(s);
		}
	}

	public int printf(string format, var... arguments) {
		lock (_lock) {
			return super.printf(format, arguments);
		}
	}
}

public class BinaryFileAppendWriter extends BinaryFileWriter {
	BinaryFileAppendWriter(File file, boolean closeOnDelete) {
		super(file, closeOnDelete);
	}

	public void flush() {
		seek(0, Seek.END);
		super.flush();
	}
}

public class TextFileWriter extends BinaryFileWriter {
	TextFileWriter(File file, boolean closeOnDelete) {
		super(file, closeOnDelete);
	}

	public void _write(byte c) {
		if (c == '\n')
			super._write('\r');
		super._write(c);
	}
}
/*
 * Reading from stdin when it is connected to a terminal triggers the stdout
 * stream to flush.
 */
public class StdinReader extends Reader {
	private ref<Reader> _reader;

	StdinReader(ref<Reader> reader) {
		_reader = reader;
	}

	protected int _read() {
		process.stdout.flush();
		return _reader._read();
	}
}
/*
 * Writing to stdout when it is connected to a terminal flushes at every newline.
 */
public class LineWriter extends Writer {
	private ref<Writer> _writer;

	LineWriter(ref<Writer> writer) {
		_writer = writer;
	}

	protected void _write(byte c) {
//		print("Writing!\n");
		_writer._write(c);
		if (c == '\n')
			_writer.flush();
	}

	public void flush() {
		_writer.flush();
	}
}
/*
 * Writing to stderr when it is connected to a terminal flushes at every operation.
 */
public class ErrorWriter extends Writer {
	private ref<Writer> _writer;

	ErrorWriter(ref<Writer> writer) {
		_writer = writer;
	}

	protected void _write(byte c) {
		_writer._write(c);
		_writer.flush();
	}
}
/**
 * Note: This class should only be needed for Windows, which has no Append mode for files.
 */
public class TextFileAppendWriter extends TextFileWriter {
	TextFileAppendWriter(File file, boolean closeOnDelete) {
		super(file, closeOnDelete);
	}

	public void flush() {
		seek(0, Seek.END);
		super.flush();
	}
}

public ref<FileReader> openTextFile(string filename) {
	File f;

	if (f.open(filename)) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			return new TextFileReader(f, true);
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			return new FileReader(f, true);
	}
	return null;
}

public ref<FileWriter> appendTextFile(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		windows.HANDLE handle = windows.CreateFile(filename.c_str(), windows.GENERIC_WRITE, 0, null, 
												windows.OPEN_ALWAYS, windows.FILE_ATTRIBUTE_NORMAL, null);
		if (handle == windows.INVALID_HANDLE_VALUE)
			return null;
		return new TextFileAppendWriter(File(long(handle)), true);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		File f;

		if (f.appendTo(filename))
			return new FileWriter(f, true);
	}
	return null;
}

public ref<FileWriter> createTextFile(string filename) {
	File f;

	if (f.create(filename)) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			return new TextFileWriter(f, true);
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			return new FileWriter(f, true);
	}
	return null;
}

public ref<FileReader> openBinaryFile(string filename) {
	File f;

	if (f.open(filename))
		return new BinaryFileReader(f, true);
	else
		return null;
}

public ref<FileWriter> appendBinaryFile(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		windows.HANDLE handle = windows.CreateFile(filename.c_str(), windows.GENERIC_WRITE, 0, null, 
												windows.OPEN_ALWAYS, windows.FILE_ATTRIBUTE_NORMAL, null);
		if (handle == windows.INVALID_HANDLE_VALUE)
			return null;
		return new BinaryFileAppendWriter(File(long(handle)), true);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		File f;

		if (f.appendTo(filename))
			return new FileWriter(f, true);
	}
	return null;
}

public ref<FileWriter> createBinaryFile(string filename) {
	File f;

	if (f.create(filename))
		return new BinaryFileWriter(f, true);
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

	public string filename() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return ref<windows.WIN32_FIND_DATA>(_data).fileName();
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return string(pointer<byte>(&_dirent.d_name));
		} else
			return null;
	}
}

