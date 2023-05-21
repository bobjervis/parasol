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
import parasol:stream.EOF;
import parasol:text.UTF8Encoder;
import parasol:text.StringWriter;
import parasol:time;
import parasol:exception.IllegalOperationException;
import parasol:exception.IOException;
/**
 * DO NOT CALL THIS FUNCTION
 *
 * This is an internal support function called early in the runtime startup. 
 * It is not intended for general use and calling it can cause memory leaks and loss
 * of any buffered input or output.
 *
 * @ignore - do not document this function
 */
public void setProcessStreams(boolean restore) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		process.stdin = new TextFileReader(0, false);
		process.stdout = new TextFileWriter(1, false);
		process.stderr = new TextFileWriter(2, false);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		if (restore) {
			int fd = linux.open("/dev/tty".c_str(), linux.O_RDONLY);
			if (fd < 0) {
				int fd = linux.creat("console.err".c_str(), 0666);
				linux.write(fd, "Cannot open /dev/tty for reading\n".c_str(), 33);
				linux.close(fd);
			}				
			linux.dup2(fd, 0);
			linux.close(fd);
			fd = linux.open("/dev/tty".c_str(), linux.O_WRONLY);
			if (fd < 0) {
				int fd = linux.creat("console.err".c_str(), 0666);
				linux.write(fd, "Cannot open /dev/tty for writing\n".c_str(), 33);
				linux.close(fd);
			}				
			if (linux.dup2(fd, 1) < 0) {
				int fd = linux.creat("console.err".c_str(), 0666);
				linux.write(fd, "Cannot dup2 /dev/tty for writing stdout\n".c_str(), 40);
				linux.close(fd);
			}
			linux.dup2(fd, 2);
			linux.close(fd);
		}
		if (linux.isatty(1) == 1) {
			process.stdout = new LineWriter(1, false);
			if (linux.isatty(0) == 1)
				process.stdin = new StdinReader(0, false);
			else
				process.stdin = new FileReader(0, false);
		} else {
			process.stdin = new FileReader(0, false);
			process.stdout = new FileWriter(1, false);
		}
		if (linux.isatty(2) == 1)
			process.stderr = new ErrorWriter(2, false);
		else
			process.stderr = new FileWriter(2, false);
	}
}
/**
 * This class is available for operations on a file. If this class is
 * used to access devices, some file operations may not succeed.
 *
 * A File object is automatically closed when the File object is destroyed. Do not
 * try to copy File objects around.
 *
 * You may obtain a Reader or Writer from an open File object. Reader's and
 * Writer's obtained this way differ from those obtained through the {@link openTextFile},
 * {@link createBinaryFile}, etc. because deleting those objects will close the 
 * (anonymous) underlying File. The goal of the design is to allow you to implement
 * various strategies to perform random I/O on a file either through the {@link read}
 * and {@link write} methods of this class, which are not buffered, and the more flexible
 * operations of Reader's and Writer's which are buffered.
 *
 * Note that reading or writing data both through Reader's and/or Writer's and the File
 * object requires some care, since buffered data may adjust the file position in ways
 * that are not entirely predictable. In general, you should {@link Writer.flush flush}
 * any Writer's and delete any Reader's that were used to read or write data before you
 * either get any new Reader's or Writer's or call methods directly on the File object itself.
 */
public class File {
	private long _fd;
	/**
	 * @ignore - this has to be public to be useful to the parasol:net namespace, but this needs to
	 * be actively discouraged.
	 */
	public File(long fd) {
		_fd = fd;
	}
	/**
	 * Create a new File object in closed state.
 	 */
	public File() {
		_fd = -1;
	}
	/**
	 * Set the file descriptor directly.
	 *
	 * This allows Readers and Writers to hold a File object and populate it.
	 */
	void setFd(long fd) {
		_fd = fd;
	}
	/**
	 * Called from Readers and Writers to implment 'dontCloseOnDelete'
	 *
	 * @ignore - This has to be public to be useful to the parasol:net namespace, but this needs to
	 * be actively discouraged.
	 */
	public void dontCloseOnDestructor() {
		_fd = -1;
	}
	/**
	 * Called from support functions to create Readers and Writers.
	 */
	long transferFd() {
		long fd = _fd;
		_fd = -1;
		return fd;
	}

	~File() {
		if (_fd != -1)
			close();
	}
	/**
	 * Get a Reader appropriate for the binary file format of the native operating system.
	 *
	 * Deleting the returned Reader will not close the File object.
	 *
	 * @return A Reader positioned at the current File position.
	 */
	public ref<Reader> getBinaryReader() {
		return new BinaryFileReader(_fd, false);
	}
	/**
	 * Get a Reader appropriate for the text file format of the native operating system.
	 *
	 * Deleting the returned Reader will not close the File object.
	 *
	 * @return A Reader positioned at the current File position.
	 */
	public ref<Reader> getTextReader() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return new TextFileReader(_fd, false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return new BinaryFileReader(_fd, false);
		} else
			return null;
	}
	/**
	 * Get a Writer appropriate for the binary file format of the native operating system.
	 *
	 * Deleting the returned Writer will not close the File object.
	 *
	 * @return A Writer positioned at the current File position.
	 */
	public ref<Writer> getBinaryWriter() {
		return new BinaryFileWriter(_fd, false);
	}
	/**
	 * Get a Writer appropriate for the text file format of the native operating system.
	 *
	 * Deleting the returned Writer will not close the File object.
	 *
	 * @return A Writer positioned at the current File position.
	 */
	public ref<Writer> getTextWriter() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return new TextFileWriter(_fd, false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			if (linux.isatty(int(_fd)) == 1)
				return new LineWriter(_fd, false);
			else
				return new BinaryFileWriter(_fd, false);
		} else
			return null;
	}
	/**
	 * Open an existing file for reading.
	 *
	 * @param filename The path of the file to open.
	 *
	 * @return true if the file was successfully opened, false otherwise.
	 */
	public boolean open(string filename) {
		return open(filename, AccessFlags.READ);
	}
	/**
	 * Open an existing file for reading and/or writing.
	 *
	 * @param filename The path of the file to open.
	 *
	 * @param access AccessFlags describing the intended operations. The {@link AccessFlags.EXECUTE EXECUTE}
	 * flag is ignored.
	 *
	 * @return true if the file was successfully opened, false otherwise.
	 */
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
	/**
	 * Create a new file for writing.
	 *
	 * If the file already exists, its contents are truncated.
	 *
	 * @param filename A path to a file to be created.
	 *
	 * @param access AccessFlags describing the intended operations. The {@link AccessFlags.EXECUTE EXECUTE}
	 * flag is ignored.
	 *
	 * @return true if the create operation succeeded, false otherwise.
	 */
	public boolean create(string filename) {
		return create(filename, AccessFlags.WRITE);
	}
	/**
	 * Create a new file for reading and/or writing.
	 *
	 * If the file already exists, its contents are truncated.
	 *
	 * @param filename A path to a file to be created.
	 *
	 * @return true if the create operation succeeded, false otherwise.
	 */
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
	/**
	 * Open an existing file to append data.
	 *
	 * All write operations to an append-mode File will write the data
	 * at the end of the file, regardless of the file position before
	 * the write call.
	 *
	 * @param filename A path to an existing file to be appended to.
	 *
	 * @return true if the open operation succeeded, false otherwise.
	 */
	public boolean appendTo(string filename) {
		return appendTo(filename, AccessFlags.WRITE);
	}
	/**
	 * Open an existing file to read and/or append data.
	 *
	 * Note that this method with only AccessFlags.READ set is equivalent to a call
	 * to {@link open}.
	 *
	 * @param filename A path to an existing file to be appended to.
	 *
	 * @param access AccessFlags describing the intended operations. The {@link AccessFlags.EXECUTE EXECUTE}
	 * flag is ignored.
	 *
	 * @return true if the open operation succeeded, false otherwise.
	 */
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
	/**
	 * Check whether a File is currently open.
	 *
	 * @return true if the file is open, false otherwise.
	 */
	public boolean isOpen() {
		return _fd >= 0;
	}
	/**
	 * Close an open file.
	 *
	 * @return true if the file was open and successfully was closed, false
	 * otherwise.
	 */
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
	/**
	 * Return the current file position.
	 *
	 * @return A value greater then or equal to zero on success, with the size of the file.
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
	 * Return the size of a file.
	 *
	 * This operation fails if the File is not open.
	 *
	 * @return A value greater then or equal to zero on success, with the size of the file in bytes.
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
	/**
	 * Set the file position.
	 *
	 * @param offset The position, in bytes, to set, relative to the whence paramter.
	 *
	 * @param whence The starting point for calculating the File position.
	 *
	 * @return The new file position, or -1 if there was an error.
	 */
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
	/**
	 * Write the contents of a byte array to the File.
	 *
	 * @param buffer The bytes to write.
	 *
	 * @return The number of bytes actually written.
	 *
	 * @exception IllegalOperationException Thrown if the file is not open or the operating system does not support this operation.
	 *
	 * @exception IOException Thrown if any device error was detected during the write operation.
	 */
	public int write(byte[] buffer) {
		if (_fd == -1)
			throw IllegalOperationException("write");
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.WriteFile(windows.HANDLE(_fd), &buffer[0], windows.DWORD(buffer.length()), &result, null) == 0)
				throw IOException(string(_fd));
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			long result = linux.write(int(_fd), &buffer[0], buffer.length());
			if (result >= 0)
				return int(result);
			else
				throw IOException(string(_fd) + ": " + linux.strerror(linux.errno()));
		}
		throw IllegalOperationException("write");
		return -1; // TODO: fix when compiler handles throw statements orrectly
	}
	/**
	 * Write the contents of a string to the File.
	 *
	 * @param buffer The string to write.
	 *
	 * @return The number of bytes actually written.
	 *
	 * @exception IllegalOperationException Thrown if the file is not open or the operating system does not support this operation.
	 *
	 * @exception IOException Thrown if any device error was detected during the write operation.
	 */
	public int write(string buffer) {
		if (_fd == -1)
			throw IllegalOperationException("write");
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.WriteFile(windows.HANDLE(_fd), &buffer[0], windows.DWORD(buffer.length()), &result, null) == 0)
				throw IOException(string(_fd));
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			long result = linux.write(int(_fd), &buffer[0], buffer.length());
			if (result >= 0)
				return int(result);
			else
				throw IOException(string(_fd) + ": " + linux.strerror(linux.errno()));
		}
		throw IllegalOperationException("write");
		return -1; // TODO: fix when compiler handles throw statements orrectly
	}
	/**
	 * Write the contents of a buffer to the File.
	 *
	 * @param buffer The address of the buffer to write.
	 *
	 * @param length The number of bytes to write.
	 *
	 * @return The number of bytes actually written.
	 *
	 * @exception IllegalOperationException Thrown if the file is not open or the operating system does not support this operation.
	 *
	 * @exception IOException Thrown if any device error was detected during the write operation.
	 */
	public long write(address buffer, long length) {
		if (_fd == -1)
			throw IllegalOperationException("write");
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.WriteFile(windows.HANDLE(_fd), buffer, windows.DWORD(length), &result, null) == 0)
				throw IOException(string(_fd));
			return long(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			long result = linux.write(int(_fd), buffer, length);
			if (result >= 0)
				return result;
			else
				throw IOException(string(_fd) + ": " + linux.strerror(linux.errno()));
		}
		throw IllegalOperationException("write");
		return -1; // TODO: fix when compiler handles throw statements orrectly
	}
	/**
	 * Force the file contents to disk.
	 *
	 * Modern operating systems buffer data in memory, so applications may wish to guarantee
	 * that data is actually written to disk before proceeding.
	 *
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean sync() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return windows.FlushFileBuffers(windows.HANDLE(_fd)) != 0;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return linux.fdatasync(int(_fd)) == 0;
		} else
			return false;
	}
	/**
	 * Read data from a file to fill a byte array.
	 *
	 * @param buffer The array to fill.
	 *
	 * @return The number of bytes actually read.
	 *
	 * @exception IllegalOperationException Thrown if the file is not open or the operating system does not support this operation.
	 *
	 * @exception IOException Thrown if any device error was detected during the write operation.
	 */
	public int read(ref<byte[]> buffer) {
		if (_fd == -1)
			throw IllegalOperationException("read");
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.ReadFile(windows.HANDLE(_fd), &(*buffer)[0], windows.DWORD(buffer.length()), &result, null) == 0)
				throw IOException(string(_fd));
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			long result = linux.read(int(_fd), &(*buffer)[0], buffer.length());
			if (result >= 0)
				return int(result);
			else
				throw IOException(string(_fd) + ": " + linux.strerror(linux.errno()));
		}
		throw IllegalOperationException("read");
		return -1; // TODO: fix when compiler handles throw statements orrectly
	}
	/**
	 * Read data from a file to fill a byte buffer.
	 *
	 * @param buffer The address of the buffer to fill.
	 *
	 * @param length The number of bytes in the buffer.
	 *
	 * @return The number of bytes actually read.
	 *
	 * @exception IllegalOperationException Thrown if the file is not open or the operating system does not support this operation.
	 *
	 * @exception IOException Thrown if any device error was detected during the write operation.
	 */
	public long read(address buffer, long length) {
		if (_fd == -1)
			throw IllegalOperationException("read");
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.DWORD result;
			if (windows.ReadFile(windows.HANDLE(_fd), buffer, windows.DWORD(length), &result, null) == 0)
				throw IOException(string(_fd));
			return int(result);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			long result = linux.read(int(_fd), buffer, length);
			if (result >= 0)
				return result;
			else
				throw IOException(string(_fd) + ": " + linux.strerror(linux.errno()));
		}
		throw IllegalOperationException("read");
		return -1; // TODO: fix when compiler handles throw statements orrectly
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

public class BinaryFileReader = FileReader;
/**
 * A Reader that does buffered reading from files.
 *
 * This Reader implements the basic functionality for all variations needed for Linux and Windows
 * files. Windows text files must use a TextFileReader, which extends this class.
 *
 * Because of buffering, the {@link unread} method only guarantees one byte of pushback.
 */
public class FileReader extends Reader {
	private File _file;
	private byte[] _buffer;
	private int _cursor;
	private int _length;
	private boolean _closeOnDelete;

	FileReader(long fd, boolean closeOnDelete) {
		_file.setFd(fd);
		_closeOnDelete = closeOnDelete;
		_buffer.resize(BUFFER_SIZE);
	}

	~FileReader() {
		if (!_closeOnDelete)
			_file.dontCloseOnDestructor();
	}

	public string readAll() {
		seek(0, Seek.END);					// seek the stream to flush the buffer.
		long pos = _file.tell();
		_file.seek(0, Seek.START);
		string data;

		if (pos > int.MAX_VALUE)
			throw IllegalOperationException("too large");
		data.resize(int(pos));

		long n = _file.read(&data[0], pos);
		if (n < 0)
			return "";
		data.resize(int(n));
		return data;
	}

	public int _read() {
		if (_cursor >= _length) {
			// If we don't reset the buffer contents until we know we are not at EOF,
			// then when we do, unread will still work.
			int len = _file.read(&_buffer);
			if (len == 0)
				return EOF;
			_length = len;
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

	public boolean hasLength() {
		return true;
	}

	public long length() {
		long here = tell();
		long len = _file.seek(0, Seek.END) - here;
		_file.seek(here, Seek.START);
		return len;
	}

	public void reset() {
		seek(0, Seek.START);
	}
}
/**
 * This class implements reading Windows text files.
 *
 * A ctrl-Z character acts as an end-of-file marker and the line
 * separator is a carriage-return +  newline sequence. So all
 * carriage return characters are discarded.
 */
public class TextFileReader extends FileReader {
	TextFileReader(long fd, boolean closeOnDelete) {
		super(fd, closeOnDelete);
	}

	public int _read() {
		int c;

		do {
			c = super._read();
			if (c == 26) { // A ctrl-Z marks a text file EOF
				unread();
				return EOF;
			}
		} while (c == '\r');
		return c;
	}
}

public class BinaryFileWriter = FileWriter;
/**
 * A Writer that does buffered writing to files.
 *
 * This Writer implements the basic functionality for all variations needed for Linux and Windows
 * files. Windows text files must use a TextFileWriter, which extends this class.
 *
 * @threading This class implements all of it's public methods to use a lock for exclusive access.
 * Thus, separate threads can write to a common FileWriter and output is written in atomic chunks.
 * The main advantage of this is that threads can simple call printf (which defaults to the stdout
 * stream) and get lines of text written as discrete units, allowing a reasonable performance.
 */
public class FileWriter extends Writer {
	protected Monitor _lock;
	protected File _file;
	private byte[] _buffer;
	private int _fill;
	private boolean _closeOnDelete;

	FileWriter(long fd, boolean closeOnDelete) {
		_file.setFd(fd);
		_closeOnDelete = closeOnDelete;
		_buffer.resize(BUFFER_SIZE);
	}

	~FileWriter() {
		flush();
		if (!_closeOnDelete)
			_file.dontCloseOnDestructor();
	}

	protected void _write(byte c) {
		_buffer[_fill] = c;
		_fill++;
		if (_fill >= BUFFER_SIZE)
			flush();
	}

	public void write(byte c) {
		lock (_lock) {
			_write(c);
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

	public long write(address buffer, int length) {
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

	public int writeCodePoint(int codePoint) {
		string s;
		StringWriter sw(&s);
		UTF8Encoder e(&sw);

		e.encode(codePoint);
		lock (_lock) {
			return super.write(s);
		}
	}
	/*
	 * This method is called by a subclass to clear the buffer and release any consumed memory.
	 * In order for this to be safe, both the _write and flush methods need to be overridden.
	 */
	void clearBuffer() {
		lock (_lock) {
			_buffer.clear();
		}
	}	
}
/**
 * This Writer implements append-mode writing without native operating system
 * support. It is used on Windows.
 */
public class BinaryFileAppendWriter extends BinaryFileWriter {
	BinaryFileAppendWriter(long fd, boolean closeOnDelete) {
		super(fd, closeOnDelete);
	}

	public void flush() {
		lock(_lock) {
			_file.seek(0, Seek.END);
			super.flush();
		}
	}
}
/**
 * This Writer creates a Windows text file.
 *
 * It does this by writing a carriage-return character before
 * each newline character.
 *
 * Note that the ctrl-Z character that denotes end-of-file is optional. There
 * is no reason to append one to a file. It might be useful to explicitly insert
 * one, knowing that it allows you to inject extra text after the ctrl-Z that
 * many Windows applications would not read. 
 */
public class TextFileWriter extends FileWriter {
	TextFileWriter(long fd, boolean closeOnDelete) {
		super(fd, closeOnDelete);
	}

	protected void _write(byte c) {
		if (c == '\n')
			super._write('\r');
		super._write(c);
	}
}
/**
 * This Reader is suitable for a process where both stdin and
 * stdout are connected to terminals.
 *
 * Initially, if stdin and stdout are both connected to a terminal, then
 * stdin is set up with this class.
 *
 * Afterwards, whenever the process reads from stdin, if stdout is still
 * connected to a LineWriter, an indicator that stdout is connected to a
 * terminal, the stdout stream is automatically flushed.
 */
public class StdinReader extends FileReader {
	StdinReader(long fd, boolean closeOnDelete) {
		super(fd, closeOnDelete);
	}

 	public int _read() {
		if (process.stdout.class == LineWriter)
			process.stdout.flush();
		return super._read();
	}
}

/**
 * This is a line-buffered Writer appropriate for terminal devices.
 *
 * This will be the form a Writer returned whenever you open a Writer
 * to a terminal device.
 */
public class LineWriter extends FileWriter {
	LineWriter(long fd, boolean closeOnDelete) {
		super(fd, closeOnDelete);
	}

	protected void _write(byte c) {
//		print("Writing!\n");
		super._write(c);
		if (c == '\n')
			flush();
	}
}
/**
 * Thie is an unbuffered Writer appropriate for stderr.
 *
 * Writing to stderr when it is connected to a terminal flushes at every operation.
 * Performance in that situation is less than critical. Getting the text written to
 * the terminal as soon as possible is the prime motivation.
 */
public class ErrorWriter extends FileWriter {
	ErrorWriter(long fd, boolean closeOnDelete) {
		super(fd, closeOnDelete);
		clearBuffer();
	}

	protected void _write(byte c) {
		_file.write(&c, 1);
	}

	public void flush() {
	}
}
/**
 * This Writer is designed to implement append mode for an output file.
 *
 * This class is usefil for Windows, which has no Append mode for files.
 */
class TextFileAppendWriter extends TextFileWriter {
	TextFileAppendWriter(long fd, boolean closeOnDelete) {
		super(fd, closeOnDelete);
	}

	public void flush() {
		_file.seek(0, Seek.END);
		super.flush();
	}
}
/**
 * Open a text file for reading.
 *
 * @param filename A path naming an existing file.
 *
 * @return A FileReader appropriate to read the native text file format
 * of the host operating system. The function returns null if the file
 * could not be opened.
 */
public ref<FileReader> openTextFile(string filename) {
	File f;

	if (f.open(filename)) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			return new TextFileReader(f.transferFd(), true);
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			return new FileReader(f.transferFd(), true);
	}
	return null;
}
/**
 * Append to an existing text file.
 *
 * All data is written after any file contents already present.
 *
 * @param filename A path naming an existing file.
 *
 * @return A FileWriter appropriate to write the native text file format
 * of the host operating system. The function returns null if the file
 * could not be opened.
 */
public ref<FileWriter> appendTextFile(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		windows.HANDLE handle = windows.CreateFile(filename.c_str(), windows.GENERIC_WRITE, 0, null, 
												windows.OPEN_ALWAYS, windows.FILE_ATTRIBUTE_NORMAL, null);
		if (handle == windows.INVALID_HANDLE_VALUE)
			return null;
		return new TextFileAppendWriter(long(handle), true);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		File f;

		if (f.appendTo(filename))
			return new FileWriter(f.transferFd(), true);
	}
	return null;
}
/**
 * Create a new text file.
 *
 * If the file already exists, its contents are truncated.
 *
 * @param filename A path naming an existing file.
 *
 * @return A FileWriter appropriate to write the native text file format
 * of the host operating system. The function returns null if the file
 * could not be opened.
 */
public ref<FileWriter> createTextFile(string filename) {
	File f;

	if (f.create(filename)) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			return new TextFileWriter(f.transferFd(), true);
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			return new FileWriter(f.transferFd(), true);
	}
	return null;
}
/**
 * Open a binary file for reading.
 *
 * @param filename A path naming an existing file.
 *
 * @return A FileReader appropriate to read the native binary file format
 * of the host operating system. The function returns null if the file
 * could not be opened.
 */
public ref<FileReader> openBinaryFile(string filename) {
	File f;

	if (f.open(filename))
		return new BinaryFileReader(f.transferFd(), true);
	else
		return null;
}
/**
 * Append to an existing binary file.
 *
 * All data is written to the end of any file contens that exists when
 * the Writer is opened.
 *
 * @param filename A path naming an existing file.
 *
 * @return A FileWriter appropriate to write the native binary file format
 * of the host operating system. The function returns null if the file
 * could not be opened.
 */
public ref<FileWriter> appendBinaryFile(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		windows.HANDLE handle = windows.CreateFile(filename.c_str(), windows.GENERIC_WRITE, 0, null, 
												windows.OPEN_ALWAYS, windows.FILE_ATTRIBUTE_NORMAL, null);
		if (handle == windows.INVALID_HANDLE_VALUE)
			return null;
		return new BinaryFileAppendWriter(long(handle), true);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		File f;

		if (f.appendTo(filename))
			return new FileWriter(f.transferFd(), true);
	}
	return null;
}
/**
 * Create a new binary file.
 *
 * If the file already exists, its contents are truncated.
 *
 * @param filename A path naming an existing file.
 *
 * @return A FileWriter appropriate to write the native binary file format
 * of the host operating system. The function returns null if the file
 * could not be opened.
 */
public ref<FileWriter> createBinaryFile(string filename) {
	File f;

	if (f.create(filename))
		return new BinaryFileWriter(f.transferFd(), true);
	else
		return null;
}
/**
 * Create and open for writing a temporary file.
 *
 * Once created, the file will remain in existence until temporary storage is cleared, usually at the next system reboot.
 *
 * The caller may use the return Writer object to add contents to the file. Deleting the Writer object will close the file.
 * This Writer writes text data.
 *
 * @param template A valid filename string ending in XXXXXX. These X's will be replaced
 * in the actual filename by unique characters.
 *
 * @return The actual filename.
 *
 * @return A text Writer object opened to the file.
 */
public string, ref<FileWriter> createTempFile(string template) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		string result = "/tmp/" + template;
		int fd = linux.mkstemp(&result[0]);

		if (fd < 0)
			return result, null;
		else
			return result, new FileWriter(fd, true);
	}
	return null, null;
}
/**
 * Create and open for writing a temporary binary file.
 *
 * Once created, the file will remain in existence until temporary storage is cleared, usually at the next system reboot.
 *
 * The caller may use the return Writer object to add contents to the file. Deleting the Writer object will close the file.
 * This Writer writes binary data.
 *
 * @param template A valid filename string ending in XXXXXX. These X's will be replaced
 * in the actual filename by unique characters.
 *
 * @return The actual filename.
 *
 * @return A binary Writer object opened to the file.
 */
public string, ref<FileWriter> createBinaryTempFile(string template) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		string result = "/tmp/" + template;
		int fd = linux.mkstemp(&result[0]);

		if (fd < 0)
			return result, null;
		else
			return result, new BinaryFileWriter(fd, true);
	}
	return null, null;
}

/**
 * The Directory class is used to scan the contents of a directory using a wildcard pattern.
 *
 * The pattern must conform to the rules of the native operating system.
 *
 * TODO: For Linux, the wildcard string is ignored and effectively is treated as '*'. This
 * needs to be fixed.
 *
 * The calling pattern is:
 *
 *<pre>{@code        ref<Directory> d = new Directory(path);
 *        if (d.first()) { 
 *            do { 
 *                string path = d.path();
 *                ...
 *            \} while (d.next());
 *        \} 
 *        delete d;
 *}</pre>
 */
public class Directory {
	private windows.HANDLE						_handle;
	private address								_data;
	private ref<linux.dirent>					_dirent;
	private string								_directory;
	private string								_wildcard;
	/**
	 * Constructo a Directory object that will read all entries
	 * of the named path.
	 *
	 * @param path A path naming a readable directory.
	 */
	public Directory(string path) {
		_handle = windows.INVALID_HANDLE_VALUE;
		_directory = path;
		_wildcard = "*";
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			_data = memory.alloc(windows.sizeof_WIN32_FIND_DATA);
	}
	/**
	 * Constructo a Directory object that will read all entries
	 * of the named path that match the given pattern.
	 *
	 * All characters in the pattern string will match exactly the
	 * corresponding character in the directory, except for the
	 * following:
	 * <ul>
	 *     <li>An asterisk matches any number of characters.
	 *     <li> A question mark matches exactly one character.
	 * </ul>
	 *
	 * @param path A path naming a readable directory.
	 * @param pattern A wildcard pattern. Only entries matching the
	 * pattern will be returned.
	 */
	public Directory(string path, string pattern) {
		_handle = windows.INVALID_HANDLE_VALUE;
		_directory = path;
		_wildcard = pattern;
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
			delete _dirent;
		}
	}
	/**
	 * Advance to the first directory entry.
	 *
	 * @return true if there is at least one entry in the directory that matched the
	 * pattern, false if not, or if the directory is not readable.
	 */
	public boolean first() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			string s = _directory + "\\" + _wildcard;
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
	/**
	 * Advance to the next directory entry,
	 *
	 * @return true if there is another directory entry to read, false otherwise.
	 */
	public boolean next() {
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
	/**
	 * Get the path entry from the Directory, including the directory path passed in the constructor.
	 *
 	 * If the Directory returns true from either {@link first} or {@link next}, then
	 * the value of this method is the path of the entry read. If the previous call to
	 * either function returns false, then the value of this method is undefined.
	 *
	 * @return the path last read from the Directory.
	 */
	public string path() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return _directory + "/" + ref<windows.WIN32_FIND_DATA>(_data).fileName();
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return _directory + "/" + string(pointer<byte>(&_dirent.d_name));
		} else
			return null;
	}
	/**
	 * Get the filename entry from the Directory, excluding the directory path.
	 *
 	 * If the Directory returns true from either {@link first} or {@link next}, then
	 * the value of this method is the filename of the entry read. If the previous call to
	 * either function returns false, then the value of this method is undefined.
	 *
	 * @return the filename last read from the Directory.
	 */
	public string filename() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return ref<windows.WIN32_FIND_DATA>(_data).fileName();
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return string(pointer<byte>(&_dirent.d_name));
		} else
			return null;
	}
}

