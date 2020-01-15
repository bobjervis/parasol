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

import parasol:math;
import parasol:process;
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
import native:windows.GetFullPathName;
import native:windows.RemoveDirectory;
/*
public class FileSystem {
}
 */
/**
 * Construct an absoluute path to the file system entity described by the argument.
 *
 * If the argument names an existing file system entity, then native operating system 
 * facilities are used to construct an absolute path. Thus, under Linux, for example,
 * symbolic links are followed so that the resulting path may have no common elements
 * with the original file path.
 *
 * If the argument does not name an existing file system entity, then a general algorithm
 * will be used that will not recognize things like symbolic links. The general algorithm 
 * will:
 * <ol>
 *   <li> convert any relative path to a fully qualified path by taking the current working
 *        directory and combining that with the function argument.
 *   <li> the resulting fully qualified path has any empty path elements removed.
 *   <li> the resulting fully qualified path has any path elements in it that are '.'
 *        removed.
 *   <li> any path elelments that are '..' are removed as well as the prior path component as well.
 *        If there are unmatched '..' path elements, they are discarded. For example, the path 
 *        {@code /aa/../../bb} will return {@code /bb}.
 *
 * @param filepath The filename path convert to an absolute path.
 *
 * @return The constructed absolute path, or null if no meaningful absolute path could be constructed.
 */
public string absolutePath(string filepath) {
	string buffer;
	buffer.resize(256);
	
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		unsigned len = GetFullPathName(filepath.c_str(), unsigned(buffer.length()), buffer.c_str(), null);
		if (len == 0)
			return string();
		if (len >= unsigned(buffer.length())) {
			buffer.resize(int(len));
			GetFullPathName(filepath.c_str(), unsigned(len + 1), buffer.c_str(), null);
		} else
			buffer.resize(int(len));
		return buffer.toLowerCase();
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		pointer<byte> f = linux.realpath(filepath.c_str(), null);
		if (f != null) {
			string result(f);
			C.free(f);
			return result;
		}
	}
	if (isRelativePath(filepath)) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return null;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			pointer<byte> cwdbuf = linux.getcwd(null, 0);
			string cwd(cwdbuf);
			C.free(cwdbuf);
			string[] components;
			string path = constructPath(cwd, filepath);
			components = path.split('/');
			return composeAbsolutePath(components);
		} else
			return null;
	} else if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return filepath;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			string[] components;
			components = filepath.split('/');
			return composeAbsolutePath(components);
	} else
			return filepath;
}

private string composeAbsolutePath(string[] components) {
	string[] results;

	for (i in components) {
		if (components[i].length() == 0)
			continue;
		if (components[i] == ".")
			continue;
		if (components[i] == "..") {
			if (results.length() > 0)
				results.resize(results.length() - 1);
			continue;
		}
		results.append(components[i]);
	}
	string path;
	for (i in results)
		path += "/" + results[i];
	return path;
}
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
 * Returns the last component (the filename part) of a path string.
 *
 * @param filename Absolute or relative path for a file.
 *
 * @return The substring following the last path separator character recognized by the host operating system.
 * If the string contains no such separator, the function returns the filename parameter.
 */
public string filename(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		for (int x = filename.length() - 1; x >= 0; x--)
			if (filename[x] == '\\' || filename[x] == '/')
				return filename.substr(x + 1);
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		int idx = filename.lastIndexOf('/');
		if (idx >= 0)
			return filename.substr(idx + 1);
	}
	return filename;
}
/**
 * Construct a path from a directory and a file name.
 *
 * The resulting path is created by combining the directory and filename portions
 * with a path separator. If the directory portion ends with such a separator, the
 * filename is simply appended to the directory and the resulting string is returned.
 *
 * @param directory The directory portion of the path. This string may end with a path
 * separator character.
 *
 * @param filename The filename portion of the path.
 *
 * @return The resulting file path. 
 */
public string constructPath(string directory, string filename) {
	return constructPath(directory, filename, null);
}
/**
 * Construct a path from a directory, baseName and extension.
 *
 * If the baseName already has an extension, that extension is replaced with the extension
 * string. Otherwise, the the extension is appended to the baseName with a period.
 *
 * If the baseName had an extension that extension is ignored and replaced with the new extension.
 *
 * @param directory The directory portion of the path. This string may end with a path
 * separator character.
 * @param baseName A base file name, which may contian an extension.
 * @param extension The new extension for the resulting filename path.
 *
 * @return The constructed path name. Only one path separator character appears between
 * the directory and baseName parts of the path.
 */
public string constructPath(string directory, string baseName, string extension) {
	string base;
	if (directory.length() > 0) {
		byte c = directory[directory.length() - 1];
		if (c == ':' || c == '\\' || c == '/')
			base = directory + baseName;
		else
			base = directory + "/" + baseName;
	} else
		base = baseName;
	if (extension.length() > 0) {
		string b = filename(base);
		int i = b.lastIndexOf('.');
		if (i != -1) {
			int extSize = b.length() - i;
			base.resize(base.length() - extSize);
		}
		if (extension[0] != '.')
			base = base + ".";
		base = base + extension;
	}
	return base;
}
/**
 * Extract the directory portion of a file path.
 *
 * The portion of the string after the last path separator is returned.
 * If the last path separator character appears as the first character in the
 * string (e.g. '/abc', then the directory "/" is returned. If no path
 * separator at all appears in the filename, the directory "." is returned.
 *
 * @param filename The filename path.
 *
 * @return The directory portion.
 */
public string directory(string filename) {
	for (int x = filename.length() - 1; x >= 0; x--) {
		if (filename[x] == '\\' || filename[x] == '/') {
			if (x == 0)
				return "/";
			else
				return filename.substr(0, x);
		}
	}
	return ".";
}
/**
 * This function determines whether, on the host operating system, the given prefix
 * names the initial directory in the path.
 *
 * @return true if the following is true:
 *
 * <ul>
 *   <li>
 *		path.startsWith(prefix) - up to case sensitivity in the host 
 *		  operating system. Note that for some file systems mounted on Linux, the file
 *		  system may not distinguish upper- and lower-case letters even though native
 *		  Linux file systems do. In such a case, this function will not check the
 *		  paths to determine whether they refer to files in such a file system.
 *   <li>
 *		The next character in the path is a directory delimiter character;
 *		  in other words the prefix names a complete directory component in 
 *		  the path.
 * </ul>
 */
public boolean pathStartsWith(string path, string prefix) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		// TODO: cannot modify a string parameter - fix this when this constraint is relaxed.
		string lprefix = prefix.toLowerCase();
		string lpath = path.toLowerCase();
		if (!lpath.startsWith(lprefix))
			return false;
		if (path.length() == prefix.length())
			return true;
		byte b = path[prefix.length()];
		if (b == '\\' || b == '/')
			return true;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		if (!path.startsWith(prefix))
			return false;
		if (path.length() == prefix.length())
			return true;
		if (path[prefix.length()] == '/')
			return true;
	}
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
 * Returns the current user's home directory path.
 *
 * @return The path to the user's home directory.
 */
public string homeDirectory() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		// TODO: Implement this
		return null;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return process.environment.get("HOME");
	} else
		return null;
}
/**
 * This call ensures that the given path exists and that the final element of the path is indeed a directory (or a link to one).
 * 
 * If it fails, that is because one or more of the directories in the path do not exist and you do not have permissions to create
 * it, or it does exist and is not a directory.
 *
 * @param path A file system path of a directory that exists or willl be created
 *
 * @return true if the directory did exist or could be created. False if the directory did not exist and either it or some
 * directory in the path could not be created.
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
	// The final component of the path is not a directory, but the rest of the path checks out, so try and create the path as a directory.
	return makeDirectory(path);
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
			string destFilename = constructPath(destination, dir.filename());
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
					if (!tryAllFiles)
						deleteDirectoryTree(destination);
					return false;
				}
				if (!createSymLink(target, destFilename)) {
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
 * Expand a wild card path.
 *
 * The native operating system rules for wild card expansion are applied to the pattern
 * to construct a list of matching paths.
 *
 * @param pattern The file path, possibly containing wild card characters.
 *
 * @return An array containing all of the matching file paths for the given pattern.
 * If the pattern was well formed, but did not match any files, the returned array will
 * be empty but the next return expression will be true.
 *
 * @return true if the operation succeeded, false otherwise.
 */
public string[], boolean expandWildCard(string pattern) { 
	string[] results;
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		return results, false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.glob_t gl;

		int result = linux.glob(pattern.c_str(), 0, null, &gl);
		if (result == linux.GLOB_NOMATCH)
			return results, true;
		if (result != 0)
			return results, false;
		for (int i = 0; i < gl.gl_pathc; i++)
			results.append(string(gl.gl_pathv[i]));
		linux.globfree(&gl);
		return results, true;
	} else
		return results, false;
}
/**
 * Resolve a path relative to the directory of a base file name.
 *
 * For example, if you have a relative path in an HTML link, it is found relative to
 * the directory containing the HTML file that contains the link.
 *
 * @param filename The (possibly relative) path to a file.
 * @param baseFilename The path to a file.
 *
 * @return If the filename argument contains a relative path, the result is found by combining the 
 * directory portion of the baseFilename with the contents of filename. If filename contains an
 * absolute path, then the function returns filename.
 */
public string pathRelativeTo(string filename, string baseFilename) {
	if (isRelativePath(filename))
		return constructPath(directory(baseFilename), filename);
	else
		return filename;
}
/**
 * Determine whether a path string is a relative path. 
 *
 * The path is not checked to see if it names an actual file.
 *
 * @param filename The path to be checked.
 *
 * @return true if the path is relative, false if it is absolute or empty or null.
 */
public boolean isRelativePath(string filename) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		if (filename.length() == 0 || filename[0] == '\\' || filename[0] == '/' || filename.indexOf(':') >= 0)
			return false;
		else
			return true;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		if (filename.length() == 0 || filename[0] == '/')
			return false;
		else
			return true;
	} else
			return false;
}
/**
 * Construct a relative file path.
 *
 * Numerous applications read files containing paths to other files. In many
 * cases these embedded file names are determined relative to the directory
 * containing the application's file. For example, include statements in C source
 * files are calculated in this way.
 *
 * Given two file paths, return a file path that would identify the file
 * of filename, but be relative to the directory containing baseFilename.
 *
 * If filename or baseFilename are themselves relative, they are assumed to be
 * relative to the current working directory.
 *
 * For example:
 *
 *{@code
 *    "../bb/cc.x" = makeCompactPath("aa/bb/cc.x", "aa/dd/ee.y");
 *}
 *
 * In this case, the common prefix directory {@code aa} is shared. in order to navigate
 * from the {@code dd} directory containing the base file to the common directory, one
 * {@code ..} directory must be used.
 *
 * @param filename The path to a file.
 * If the path named by filename does not exist, then the path must be absolute.
 * A relative path to a non-existent file will cause unpredictable results.
 *
 * @param baseFilename The path to another file that will serve as the base
 * for the returned relative path.
 *
 * @return A path, possibly containing leading '..' directories, that identifies
 * filename relative to baseFilename.
 * If there is no common directory in the paths, the filename string is returned.
 */
public string makeCompactPath(string filename, string baseFilename) {
//	if (isRelativePath(filename))
//		return filename;
	string a1 = absolutePath(filename);
	string a2 = absolutePath(baseFilename);

	int span = math.min(a1.length(), a2.length());
//		printf("span %d a1 = '%s' a2 = '%s'\n", span, a1, a2);
	int i;
	int firstSlash = -1;
	int lastSlash = -1;
	for (i = 0; i < span; i++) {
		if (a1[i] != a2[i]) {
			if (firstSlash == lastSlash)
				break;

				// There is a common directory prefix!

			int slashCount = 0;
			for (int j = i + 1; j < a2.length(); j++)
				if (a2[j] == '/')
					slashCount++;
//			printf("slashCount %d\n", slashCount);
			if (slashCount == 0) {
				return a1.substr(lastSlash + 1);
			}
			string result;
			while (slashCount > 0) {
				result.append("../");
				slashCount--;
			}
			return result + a1.substr(lastSlash + 1);
		}
		if (a1[i] == '/') {
			lastSlash = i;
			if (firstSlash < 0)
				firstSlash = i;
		}
	}
	return a1;
}

