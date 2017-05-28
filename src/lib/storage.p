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
namespace parasol:storage;

import parasol:runtime;
import parasol:pxi.SectionType;
import parasol:file;

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

public int FILENAME_MAX = 260;

public class FileSystem {
}

string absolutePath(string filename) {
	string buffer;
	buffer.resize(256);
	
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		unsigned len = GetFullPathName(filename.c_str(), unsigned(buffer.length()), buffer.c_str(), null);
		if (len == 0)
			return string();
		if (len >= unsigned(buffer.length())) {
			buffer.resize(int(len));
			GetFullPathName(filename.c_str(), unsigned(len + 1), buffer.c_str(), null);
		} else
			buffer.resize(int(len));
		return buffer.toLower();
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		pointer<byte> f = linux.realpath(filename.c_str(), null);
		string result = string(f);
		C.free(f);
		return result;
	} else
		return null;
}

public string basename(string filename) {
	for (int x = filename.length() - 1; x >= 0; x--)
		if (filename[x] == '\\' || filename[x] == '/')
			return filename.substring(x + 1);
	return filename;
}

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
		string b = basename(base);
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

public string directory(string filename) {
	for (int x = filename.length() - 1; x >= 0; x--) {
		if (filename[x] == '\\' || filename[x] == '/') {
			if (x == 0)
				return "/";
			else
				return filename.substring(0, x);
		}
	}
	return ".";
}

public boolean exists(string filename) {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		DWORD r = GetFileAttributes(&filename[0]);
		if (r == 0xffffffff)
			return false;
		else
			return true;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		linux.statStruct statb;
		
		int result = linux.stat(filename.c_str(), &statb);
		return result == 0;
	} else
		return false;
}

public boolean isDirectory(string filename) {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		DWORD r = GetFileAttributes(&filename[0]);
		if (r == 0xffffffff)
			return false;
		else
			return (r & FILE_ATTRIBUTE_DIRECTORY) != 0;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		linux.statStruct statb;
		
		int result = linux.stat(filename.c_str(), &statb);
		return result == 0 && linux.S_ISDIR(statb.st_mode);
	} else
		return false;
}

public boolean isLink(string filename) {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		DWORD r = GetFileAttributes(&filename[0]);
		if (r == 0xffffffff)
			return false;
		else
			return (r & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		linux.statStruct statb;
		
		int result = linux.stat(filename.c_str(), &statb);
		return result == 0 && linux.S_ISLNK(statb.st_mode);
	} else
		return false;
}

public boolean makeDirectory(string path) {
	return makeDirectory(path, false);
}

public boolean makeDirectory(string path, boolean shared) {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		if (!shared)
			return CreateDirectory(path.c_str(), null) != 0;
		else
			return false;								// TODO: There's much work to make a Windows file shared to others and/or read-only, so for now fail.
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
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
 */
public boolean ensure(string path) {
	if (isDirectory(path))
		return true;
	string dir = directory(path);
	if (!ensure(dir))
		return false;
	// The final component of the path is not a directory, but the rest of the path checks out, so try and create the path as a directory.
	return makeDirectory(path);
}

public boolean deleteFile(string path) {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		return DeleteFile(path.c_str()) != 0;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		return linux.unlink(path.c_str()) == 0;
	} else
		return false;
}

public boolean deleteDirectory(string path) {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		return RemoveDirectory(path.c_str()) != 0;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		return linux.rmdir(path.c_str()) == 0;
	} else
		return false;
}
/**
 * This function tries to delete n entire directory tree. It will try to delete each file in turn, in no particular order. If the
 * file cannot be deleted, then the whole operation stops immediately.
 */
public boolean deleteDirectoryTree(string path) {
	if (!isDirectory(path))
		return false;
	ref<file.Directory> dir = new file.Directory(path);
	dir.pattern("*");
	if (dir.first()) {
		do {
			if (dir.basename() == "." || dir.basename() == "..")
				continue;
			string filename = dir.path();
			if (isDirectory(filename) && !isLink(filename)) {
				if (!deleteDirectoryTree(filename)) {
					delete dir;
					return false;
				}
			} else if (!deleteFile(filename)) {
				delete dir;
				return false;
			}
		} while (dir.next());
	}
	delete dir;
	return deleteDirectory(path);
}
