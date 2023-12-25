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
/**
 * Provides facilities for manipulation of file paths, as well as various file system
 * operations, such as copying, renaming or deleting files and directories.
 *
 * The purpose of these functions is to provide a portable means to manage the local
 * file system for a running process. 
 */
namespace parasol:storage;

import parasol:exception.IllegalArgumentException;
import parasol:runtime;
import parasol:time;
import native:C;
import native:linux;
import native:windows.CreateDirectory;
import native:windows.DeleteFile;
import native:windows.DWORD;
import native:windows.FILE_ATTRIBUTE_DIRECTORY;
import native:windows.FILE_ATTRIBUTE_REPARSE_POINT;
import native:windows.GetFileAttributes;
import native:windows.RemoveDirectory;
/**
 * File Access flags.
 *
 * The only portable file access settings are the current user's settings. Each file
 * in the local file system can be accessed in one of three ways: read, write or execute.
 *
 * The runtime allows you to query or set these values. Having access to a file does not
 * necessarily permit you to change those permissions.
 */
public flags AccessFlags {
	/**
	 * The calling user has permission to execute this file.
	 */
	EXECUTE,
	/**
	 * The calling user has permission to write data to this file.
	 */
	WRITE,
	/**
	 * The calling user has permission to read data from this file.
	 */
	READ
}
/**
 * Get the current user's access permissions for a file.
 *
 * @param filename The file to read permissions from.
 *
 * @return The access values for the current user. If the value of the second return expression
 * is false, this value is zero.
 *
 * @return true if the access flags could be read for the named file, or false otherwise. 
 * For example, if the file does not exist, this return expression would be false.
 */
public AccessFlags, boolean getUserAccess(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return 0, false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(&filename[0], &s) != 0)
			return 0, false;
		return AccessFlags((s.st_mode & (linux.S_IXUSR | linux.S_IRUSR | linux.S_IWUSR)) >> 6), true;
	} else
		return 0, false;
}
/**
 * Set the owner's access permissions for a file.
 *
 * This function will succeed if the current user owns the file or has special permissions. For
 * example, on Linux, if the user is root, this function sets the owner's permissions, whether the
 * file is owned by root or by any other user.
 * 
 * @param filename The file to set permissions for.
 *
 * @return true if the access flags could be set for the named file, or false otherwise. For example,
 * if the file does not exist, this value would be false.
 */
public boolean setUserAccess(string filename, AccessFlags newAccess) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(filename.c_str(), &s) != 0)
			return false;
		linux.mode_t newMode = s.st_mode & ~linux.S_IRWXU;		// Turn off all user modes.
		newMode |= linux.mode_t(newAccess) << 6;
		if (linux.chmod(filename.c_str(), newMode) == 0)
			return true;
	}
	return false;
}
/**
 * Make the named file executable (or not) for the owner.
 *
 * This function will succeed if the current user owns the file or has special permissions. For
 * example, on Linux, if the user is root, this function sets the owner's permissions, whether the
 * file is owned by root or by any other user.
 * 
 * @param filename The file to set permissions for.
 *
 * @param executable True to make the file executable, or false to make the file not executable.
 *
 * @return true if the executable flag could be set or cleared for the named file, or false otherwise. For example,
 * if the file does not exist, this value would be false.
 */
public boolean setExecutable(string filename, boolean executable) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(&filename[0], &s) != 0)
			return false;
		if (executable)
			return linux.chmod(&filename[0], s.st_mode | (linux.S_IXUSR | linux.S_IXGRP)) == 0;
		else
			return linux.chmod(&filename[0], s.st_mode & ~(linux.S_IXUSR | linux.S_IXGRP | linux.S_IXOTH)) == 0;
	} else
		return false;
}
/**
 * Test whether the named file is executable (or not) for the owner.
 *
 * Executable means in this context a file that the host operating system considers executable.
 * A host operating system will often have ways to execute a file that is not written in the native binary format.
 * For example, on Windows certain file extensions indicate that a file is a command script.
 * On UNIX and Linux systems, on the other hand, file system permissions are used to make that determination.
 *
 * This is not an exhaustive test.
 * The contents of the file are not verified to determine that they are valid.
 * It also only tests whether the file's owner can execute this file.
 * For example, by convention on Linux, permissions bits follow the basic progression:
 *
 * {@code
 *              user-bit >= group-bit >= other-users-bit
 * }
 *
 * Thus, if the owner has execute permissions the file can be considered executable, but users other than
 * the owner may still not have permissions to execute it.
 * A file on Linux or UNIX could use unconventional settings to make a file executable to everyone but the owner, but
 * that is almost never actually done.
 *
 * @param filename The file to test permissions for.
 *
 * @return true if the file exists, the path to it is searchable and it is executable by its owner, false otherwise.
 */
public boolean isExecutable(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(&filename[0], &s) != 0)
			return false;
		if ((s.st_mode & linux.S_IFDIR) != 0)
			return false;							// A directory is NOT executable, since the 'execute' bits
													// mean 'searchable' for directories.
		return (s.st_mode & linux.S_IXUSR) != 0;
	} else
		return false;
}
/**
 * Make the named file read-only (or writable) for the owner.
 *
 * This function will succeed if the current user owns the file or has special permissions. For
 * example, on Linux, if the user is root, this function sets the owner's permissions, whether the
 * file is owned by root or by any other user.
 * 
 * @param filename The file to set permissions for.
 *
 * @param executable True to make the file read-only, or false to make the file writable.
 *
 * @return true if the write access flag could be set for the named file, or false otherwise. For example,
 * if the file does not exist, this value would be false.
 */
public boolean setReadOnly(string filename, boolean readOnly) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(&filename[0], &s) != 0)
			return false;
		if (readOnly)
			return linux.chmod(&filename[0], s.st_mode & ~(linux.S_IWUSR | linux.S_IWGRP | linux.S_IWOTH)) == 0;
		else
			return linux.chmod(&filename[0], s.st_mode | (linux.S_IWUSR | linux.S_IWGRP)) == 0;
	} else
		return false;
}
/**
 * Check for the existence of a file.
 *
 * @param filename The path of the file being checked.
 *
 * @return true if the path names an existing file, false otherwise.
 * If any of the directories named in the path exist but the user does not
 * have permission to search that directory, this call will return false.
 */
public boolean exists(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		DWORD r = GetFileAttributes(&filename[0]);
		if (r == 0xffffffff)
			return false;
		else
			return true;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct statb;
		
		int result = linux.stat(filename.c_str(), &statb);
		return result == 0;
	} else
		return false;
}
/**
 * Check whether a filename is a symbolic link.
 *
 * Note that if a path names a symbolic link, the {@link exists} method may
 * return false because the target of the link does not exist, but this method will
 * return true because the link does exist.
 *
 * @param filename The path of the file being checked.
 *
 * @return true if the path names a symbolic link, false otherwise.
 * If any of the directories named in the path exist but the user does not
 * have permission to search that directory, this call will return false.
 */
public boolean isSymLink(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		DWORD r = GetFileAttributes(&filename[0]);
		if (r == 0xffffffff)
			return false;
		else
			return (r & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct statb;

		int result = linux.lstat(filename.c_str(), &statb);
		return result == 0 && linux.S_ISLNK(statb.st_mode);
	} else
		return false;
}
/**
 * Delete a symbolic link.
 *
 * The target of the link is unaffected by this call.
 *
 * @param filename The path of the symbolic link being deleted.
 *
 * @return true if the path names a symbolic link and it was deleted, false otherwise.
 * If any of the directories named in the path exist but the user does not
 * have permission to search that directory, this call will return false.
 */
public boolean deleteSymLink(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
		return deleteFile(filename);
	else
		return false;
}
/**
 * Check whether a filename is a directory.
 *
 * @param filename The path of the file being checked.
 *
 * @return true if the path names a directory, false otherwise.
 * If any of the directories named in the path exist but the user does not
 * have permission to search that directory, this call will return false.
 */
public boolean isDirectory(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		DWORD r = GetFileAttributes(&filename[0]);
		if (r == 0xffffffff)
			return false;
		else
			return (r & FILE_ATTRIBUTE_DIRECTORY) != 0;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct statb;
		
		int result = linux.stat(filename.c_str(), &statb);
		return result == 0 && linux.S_ISDIR(statb.st_mode);
	} else
		return false;
}
/**
 * Get the size, in bytes, of a file.
 *
 * @param filename The file path to check.
 *
 * @return The size, in bytes, of the file. If the file does not exist or otherwise
 * cannot determine a size, -1 is returned.
 *
 * @return true if the file size can be determined, false otherwise.
 */
public long, boolean size(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(filename.c_str(), &s) == 0)
			return s.st_size, true;
	}
	return -1, false;
}
/**
 * Check whether any files under a path are newer than some reference time.
 *
 * If path is a directory, then all contents of the directory are recursively checked.
 * The first entry (excluding .. or .) under a directory to have a modification time
 * greater than the reference time will stop the search and return.
 *
 * If any sym links or inaccessible files are encountered, they are treated as not
 * having anything newer.
 *
 * @param path The path to start searching for a newer file. This can indicate a file.
 * Note that if this path names a symbolic link, it is not followed and the time stamp
 * of the link itself is checked.
 *
 * @param referenceTime The time against which all directory entries are checked.
 *
 * @return true if there is at least one directory entry that is newer than the
 * reference time, false otherwise.
 */
public boolean anyFilesNewer(string path, time.Instant referenceTime) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.lstat(path.c_str(), &s) == 0) {
			time.Instant modified(s.st_mtim);
			if (modified > referenceTime)
				return true;
			if ((s.st_mode & linux.S_IFMT) == linux.S_IFLNK)
				return false;
			if (!linux.S_ISDIR(s.st_mode))
				return false;
		} else
			return false;
	} else
		return false;
	// Directories fall through to here
	Directory dir(path);
	if (dir.first()) {
		do {
			if (dir.filename() == "." || dir.filename() == "..")
				continue;
			if (anyFilesNewer(dir.path(), referenceTime))
				return true;
		} while (dir.next());
	}
	return false;
}
/**
 * This function returns the modified, accessed and created times for a given filename,
 * if the underlying operating system and file system provide all three times.
 *
 * @param filename The path to the file for which time stamps are desired.
 *
 * @return The last access time.
 * @return The last modified time.
 * @return The file creation time.
 * @return true if the file information could be obtained, false otherwise (such as the 
 * file did not exist or the user did not have permissions to obtain this information).
 */
public time.Instant, time.Instant, time.Instant, boolean fileTimes(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(filename.c_str(), &s) == 0) {
			time.Instant accessed(s.st_atim);
			time.Instant modified(s.st_mtim);
			time.Instant created(s.st_ctim);

			return accessed, modified, created, true;
		}
	}
	return time.Instant(-1, -1), time.Instant(-1, -1), time.Instant(-1, -1), false;
}
/**
 * Create a symbolic link to a path.
 *
 * @param oldPath The path that should become the target of the link.
 *
 * @param newPath The symbolic link to create.
 *
 * @return true if the symbolic link could be created, false otehrwise.
 */
public boolean createSymLink(string oldPath, string newPath) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return linux.symlink(oldPath.c_str(), newPath.c_str()) == 0;
	} else
		return false;
}
/**
 * Read the target of a symbolic link.
 *
 * @param path The path to the symbolic link.
 *
 * @return The target of the symbolic link, or null if the symbolic link does not 
 * exist or otherwise could not be read.
 */
public string readSymLink(string path) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		string buffer;
		linux.statStruct s;
		if (linux.lstat(path.c_str(), &s) != 0)
			return null;
		buffer.resize(int(s.st_size));						// Parasol strings null terminate
		int length = linux.readlink(path.c_str(), &buffer[0], buffer.length());
		if (length == s.st_size)
			return buffer;
	}
	return null;
}
/**
 * Get the process' current working directory.
 *
 * @return The path of the current working directory.
 */
public string currentWorkingDirectory() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		pointer<byte> cwd = linux.getcwd(null, 0);
		string buffer(cwd);
		C.free(cwd);
		return buffer;
	}
	return null;
}

/**
 * Create a directory.
 *
 * The resulting directory will not be readable, writable or searchable by another user.
 *
 * @param path The path of the new directory to create.
 *
 * @return true if the directory could be created, false otherwise.
 */
public boolean makeDirectory(string path) {
	return makeDirectory(path, false);
}
/**
 * Create a directory.
 *
 * The resulting directory may be readable or searchable by another user.
 * On linux systems, for example, there is a default user mask that may disable
 * some or all shared access to the directory.
 *
 * @param path The path of the new directory to create.
 *
 * @param shared true if the directory should be readable and searchable by other
 * users, false if the directory should be private to the user.
 *
 * @return true if the directory could be created, false otherwise.
 */
public boolean makeDirectory(string path, boolean shared) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		if (!shared)
			return CreateDirectory(path.c_str(), null) != 0;
		else
			return false;								// TODO: There's much work to make a Windows file shared to others and/or read-only, so for now fail.
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.mode_t mode = 0777;
		
		if (!shared)
			mode &= unsigned(~0007);			// zero out the 'world' bits
		return linux.mkdir(path.c_str(), mode) == 0;
	} else
		return false;
}
/**
 * This call ensures that the given path exists and that the final element of the path is indeed a directory (or a link to one).
 * 
 * If it fails, that is because one or more of the directories in the path do not exist and you do not have permissions to create
 * it, or it does exist and is not a directory.
 *
 * @param path A file system path of a directory that exists or willl be created
 *
 * @return true if the directory did exist or was successfully created. False if the directory did not exist and either it or some
 * directory in the path could not be read or created.
 */
public boolean ensure(string path) {
	if (isDirectory(path))
		return true;
//	printf("path %s does not exist - creating it\n", path);
	string dir = directory(path);
	if (!ensure(dir)) {
//		printf("could not ensure %s\n", dir);
		return false;
	}
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return CreateDirectory(path.c_str(), null) != 0;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.mode_t mode = 0770;
		
		if (linux.mkdir(path.c_str(), mode) == 0)
			return true;
		if (linux.errno() == linux.EEXIST &&
			isDirectory(path))
			return true;
		return false;
	} else
		return false;
}
/**
 * Link a name to a file.
 *
 * This function is not supported on all native operating systems or even on
 * some file systems in an operating system that does support them. For example,
 * a native Linux file system allows path to link to the same underlying file,
 * but would not extend to a memory stick formatted to be compatible with Windows.
 *
 * @param existingFile The path to an existing file.
 *
 * @param newFile The path to be created.
 *
 * @return true if the link operation succeeded, false otherwise.
 */
public boolean linkFile(string existingFile, string newFile) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return linux.link(existingFile.c_str(), newFile.c_str()) == 0;
	} else
		return false;
}
/**
 * Rename an existing file.
 *
 * Files can be renamed to appear in any directory of the
 * same mounted volume.
 *
 * Rename operations are atomic. If the newName exists before the call, another process
 * will eitehr see the previously existing file or the new one. The other process will not
 * detect a state where the newName does not exist. 
 *
 * @param oldName The name of an existing file.
 *
 * @param newName The new name for that file.
 *
 * @return true if the rename operation succeeded, false otherwise.
 */
public boolean rename(string oldName, string newName) {
	return C.rename(oldName.c_str(), newName.c_str()) == 0;
}
/**
 * Copy an existing file.
 *
 * If the destination path names a pre-existing file, it is removed and the source
 * file copied to the same name. Whether the copy can be opened by another process
 * while the copy operation is under way is dependent on the native operating system.
 *
 * Access flags and, access and modification times are preserved.
 *
 * @param source The existing file.
 *
 * @param destination The file to create.
 *
 * @return true if the copy completed successfully, false otherwise.
 *
 * @exception IOException Thrown if the copy operation encountered an I/O device error
 * either on the source or destination. 
 */
public boolean copyFile(string source, string destination) {
	File r, w;
	if (!r.open(source))
		return false;
	if (!w.create(destination)) {
		r.close();
		return false;
	}
	byte[] buffer;
	buffer.resize(4096);
	for (;;) {
		int actual = r.read(&buffer);
		if (actual < 0) {
			r.close();
			w.close();
			deleteFile(destination);
			return false;
		}
		if (actual == 0)
			break;
		w.write(&buffer[0], actual);
	}
	r.close();
	w.close();
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(source.c_str(), &s) != 0) {
			deleteFile(destination);
			return false;
		}
		// Only try to duplicate the source file mode bits, not setuid/setgid, etc.
		linux.chmod(destination.c_str(), s.st_mode & (linux.S_IRWXO | linux.S_IRWXG | linux.S_IRWXU));
		linux.timevalPair times;
		times.accessTime.tv_sec = s.st_atim.tv_sec;
		times.accessTime.tv_usec = s.st_atim.tv_nsec / 1000;
		times.modificationTime.tv_sec = s.st_mtim.tv_sec;
		times.modificationTime.tv_usec = s.st_mtim.tv_nsec / 1000;
		linux.utimes(destination.c_str(), &times);
	}
	return true;
}
/**
 * Copy a whole directory tree.
 *
 * This code will detect symbolic links and copy the value of the link's target. If that target is relative it
 * will be preserved. If the link target is an absolute path, the path is copied without modification.
 *
 * Access flags and, access and modification times are preserved.
 *
 * @param source The path of an existing, accessible directory.
 *
 * @param destination The path where a directory can be created by the user.
 *
 * @param tryAllFiles true if the copy operation should try to copy all files and keep the ones that
 *			succeeded, false if the copy operation should stop on the first failure and delete
 *			the destination directory tree if there were any failures.
 *
 * @return true if the operation succeeded, false otherwise. The status of the destination directory
 * after a failure is determined by the tryAllFiles parameter.
 *
 * @exception IOException Thrown if the copy operation encountered an I/O device error
 * either on the source or destination. 
 */
public boolean copyDirectoryTree(string source, string destination, boolean tryAllFiles) {
	if (!isDirectory(source))
		return false;
	if (!makeDirectory(destination))
		return false;
	ref<Directory> dir = new Directory(source);
	if (dir.first()) {
		do {
			if (dir.filename() == "." || dir.filename() == "..")
				continue;
			string filepath = dir.path();
			string destFilename = path(destination, dir.filename());
			if (isDirectory(filepath)) {
				if (!copyDirectoryTree(filepath, destFilename, tryAllFiles)) {
					delete dir;
					if (!tryAllFiles)
						deleteDirectoryTree(destination);
					return false;
				}
			} else if (isSymLink(filepath)) {
				string target = readSymLink(filepath);
				if (target == null) {
					delete dir;
					if (!tryAllFiles)
						deleteDirectoryTree(destination);
					return false;
				}
				if (!createSymLink(target, destFilename)) {
					delete dir;
					if (!tryAllFiles)
						deleteDirectoryTree(destination);
					return false;
				}
			} else if (!copyFile(filepath, destFilename)) {
				delete dir;
				if (!tryAllFiles)
					deleteDirectoryTree(destination);
				return false;
			}
		} while (dir.next());
	}
	delete dir;
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.statStruct s;
		if (linux.stat(source.c_str(), &s) != 0 && !tryAllFiles) {
			deleteDirectoryTree(destination);
			return false;
		}
		// Only try to duplicate the source file mode bits, not setuid/setgid, etc.
		linux.chmod(destination.c_str(), s.st_mode & (linux.S_IRWXO | linux.S_IRWXG | linux.S_IRWXU));
		linux.timevalPair times;
		times.accessTime.tv_sec = s.st_atim.tv_sec;
		times.accessTime.tv_usec = s.st_atim.tv_nsec / 1000;
		times.modificationTime.tv_sec = s.st_mtim.tv_sec;
		times.modificationTime.tv_usec = s.st_mtim.tv_nsec / 1000;
		linux.utimes(destination.c_str(), &times);
	}
	return true;
}
/**
 * Delete a file.
 *
 * This operation will fail on a directory.
 *
 * @param path The path of the file to be deleted.
 *
 * @return true if the delete operation succeeded, false otherwise.
 */
public boolean deleteFile(string path) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return DeleteFile(path.c_str()) != 0;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return linux.unlink(path.c_str()) == 0;
	} else
		return false;
}
/**
 * Delete a directory.
 *
 * If the directory contains files, this operation will fail.
 *
 * @param path The path of an existing directory.
 *
 * @return true if the directory could be deleted, false otherwise.
 */
public boolean deleteDirectory(string path) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return RemoveDirectory(path.c_str()) != 0;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return linux.rmdir(path.c_str()) == 0;
	} else
		return false;
}
/**
 * Delete a whole directory tree.
 *
 * This function tries to delete n entire directory tree. It will try to delete each file in turn, in no particular order. If the
 * file cannot be deleted, then the whole operation stops immediately.
 *
 * @param path The path of an existing directory.
 *
 * @return true if the directory could be deleted, false otherwise.
 */
public boolean deleteDirectoryTree(string path) {
	if (!isDirectory(path))
		return false;
	ref<Directory> dir = new Directory(path);
	if (dir.first()) {
		do {
			if (dir.filename() == "." || dir.filename() == "..")
				continue;
			string filepath = dir.path();
			if (isDirectory(filepath)) {
				if (!deleteDirectoryTree(filepath)) {
					delete dir;
					return false;
				}
			} else if (isSymLink(filepath)) {
				if (!deleteSymLink(filepath)) {
					delete dir;
					return false;
				}
			} else if (!deleteFile(filepath)) {
				delete dir;
				return false;
			}
		} while (dir.next());
	}
	delete dir;
	return deleteDirectory(path);
}
/**
 * Memory-map a file.
 *
 * Map a file into memory, allowing a program to manipulate the
 * contents of the file as if it were program memory.
 *
 * @param path The path of a file to be mapped.
 *
 * @param access The access rights to be given to the memory.
 *
 * @param offset The memory region begins at the specified offset in
 * the file.
 *
 * @param length The desired length of the mapped region.
 *
 * @return The address of the memory area containing the file contents.
 * If the file named by path does not exist or cannot be read, null is returned.
 * If the host environment does not support memory mapped files, null is returned.
 *
 * @return The actual length of the memory area mapped.
 * If the file named by path does not exist or cannot be mapped, -1 is returned.
 * If the host environment does not support memory mapped files, {@link long.MIN_VALUE} is returned.
 *
 * @exception IllegalArgumentException Is thrown when
 *  the offset and length define an interval that falls entirely outside
 * the file contents when the call is made. 
 */
public address, long memoryMap(string path, AccessFlags access, long offset, long length) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return null, long.MIN_VALUE;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		File f;

		if (!f.open(path))
			return null, -1;
		fileSize := f.size();
		if (fileSize < offset || offset + length < 0) {
			f.close();
			throw IllegalArgumentException("Map window [" + offset + ":" + length + "] file [0:" + fileSize + "]");
		}
		// trim the mapping window to be no longer than the file.
		if (offset + length > fileSize)
			length = fileSize - offset;
		int protections;

		if (access & AccessFlags.READ)
			protections |= linux.PROT_READ;
		if (access & AccessFlags.WRITE)
			protections |= linux.PROT_WRITE;
		if (access & AccessFlags.EXECUTE)
			protections |= linux.PROT_EXEC;
		fileAddress := pointer<byte>(linux.mmap(null, length, protections, linux.MAP_SHARED, f.fd(), offset));
		f.close();
		if (fileAddress == null)
			return null, -1;
		else
			return fileAddress, length;
	} else
		return null, long.MIN_VALUE;
}
/**
 * Unmap a memory mapped file.
 *
 * @param location The address returned from the memoryMap call.
 * @param length The length returned from the memoryMap call.
 *
 * @return true if the operation succeeded, false otherwise.
 */
public boolean unmap(address location, long length) {
	return linux.munmap(location, length) == 0;
}

