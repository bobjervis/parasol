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
#include "../common/platform.h"
#include "file_system.h"

#ifdef MSVC
#include <typeinfo.h>
#else
#include <typeinfo>
#endif
#include <windows.h>
#include <io.h>
#include "machine.h"

const long long oneMinute = 60 * 10000000;

static string fromGameDate(unsigned t);
static string fromGameTime(unsigned t);

namespace fileSystem {

FILE* openTextFile(const string& filename) {
	return fopen(filename.c_str(), "r");
}

FILE* openBinaryFile(const string& filename) {
	return fopen(filename.c_str(), "rb");
}

FILE* createTextFile(const string& filename) {
	return fopen(filename.c_str(), "w");
}

FILE* createBinaryFile(const string& filename) {
	return fopen(filename.c_str(), "wb");
}

bool createBackupFile(const string& filename) {
	if (!exists(filename))
		return true;
	string bakFile = filename + ".bak";
	if (exists(bakFile)) {
		if (!erase(bakFile)) {
//			warningMessage("Couldn't save because " + bakFile + " exists can could not be deleted");
			return false;
		}
	}
	if (!rename(filename, bakFile)) {
//		warningMessage("Couldn't rename " + filename + " to " + bakFile);
		return false;
	}
	return true;
}

string directory(const string& filename) {
	for (int x = filename.size() - 1; x >= 0; x--) {
		if (filename[x] == '\\' || filename[x] == '/') {
			if (x == 0)
				return "/";
			else
				return filename.substr(0, x);
		}
	}
	return ".";
}

string basename(const string& filename) {
	for (int x = filename.size() - 1; x >= 0; x--)
		if (filename[x] == '\\' || filename[x] == '/')
			return filename.substr(x + 1);
	return filename;
}

string absolutePath(const string& filename) {
	char buffer[256];
	int len = GetFullPathName(filename.c_str(), sizeof buffer, buffer, null);
	if (len == 0)
		return string();
	if (len >= sizeof buffer) {
		string s;
		char* output = s.buffer_(len);
		GetFullPathName(filename.c_str(), len + 1, output, null);
		return s;
	}
	return string(buffer, len).tolower();
}

const char* extension(const string& filename) {
	for (int x = filename.size() - 1; x >= 0; x--)
		if (filename[x] == '\\' || filename[x] == '/')
			break;
		else if (filename[x] == '.')
			return filename.c_str() + x;
	return "";
}

string constructPath(const string& directory, const string& baseName, const string& extension) {
	string base;
	if (directory.size()) {
		char c = directory[directory.size() - 1];
		if (c == ':' || c == '\\' || c == '/')
			base = directory + baseName;
		else
			base = directory + "/" + baseName;
	} else
		base = baseName;
	if (extension.size()) {
		string b = basename(base);
		int i = b.rfind('.');
		if (i != string::npos) {
			int extSize = b.size() - i;
			base.resize(base.size() - extSize);
		}
		if (extension[0] != '.')
			base = base + ".";
		base = base + extension;
	}
	return base;
}

static FILETIME t = { 0x0, 0x80000000 };
TimeStamp TimeStamp::UNDEFINED(t);

string TimeStamp::toString() {
	long long t = _time + ERA_DIFF;
	SYSTEMTIME d;
	if (!FileTimeToSystemTime((FILETIME*)&t, &d))
		return "";

	int y = d.wYear;
	if (y > 1900 && y < 1999)
		y -= 1900;
	return string(d.wMonth) + "/" + d.wDay + "/" + y + " " + d.wHour + ":" + d.wMinute + ":" + d.wSecond;
}

void TimeStamp::touch() {
	static __int64 lastTouched = 0;
	__int64 now = time(null) * 10000000;

	if (lastTouched >= now)
		now = lastTouched + 1;
	lastTouched = now;
	if (_time < now)
		_time = now;
}

TimeStamp lastModified(const string& filename) {
	HANDLE fh = CreateFile(filename.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
	if (fh == INVALID_HANDLE_VALUE)
		return 0;
	FILETIME ftCreate, ftAccess, ftWrite;

	TimeStamp t;
	if (GetFileTime(fh, &ftCreate, &ftAccess, &ftWrite) != FALSE)
		t = ftWrite;
	CloseHandle(fh);
	return t;
}

TimeStamp lastModified(FILE* fp) {
	int fd = _fileno(fp);
	HANDLE fh = (HANDLE)_get_osfhandle(fd);
	FILETIME ftCreate, ftAccess, ftWrite;

	if (GetFileTime(fh, &ftCreate, &ftAccess, &ftWrite) != FALSE)
		return ftWrite;
	return 0;
}

bool rename(const string& f1, const string& f2) {
   if (MoveFileEx(f1.c_str(), f2.c_str(), MOVEFILE_COPY_ALLOWED) != FALSE)
		return true;
   else
		return false;
}

bool erase(const string& filename) {
	if (DeleteFile(filename.c_str()) != FALSE)
		return true;
	else
		return false;
}

bool exists(const string& fn) {
	DWORD r = GetFileAttributes(fn.c_str());
	if (r == 0xffffffff)
		return false;
	else
		return true;
}

bool writable(const string& fn) {
	DWORD r = GetFileAttributes(fn.c_str());
	if (r == 0xffffffff)
		return false;
	else if (r & FILE_ATTRIBUTE_READONLY)
		return false;
	else
		return true;
}

bool isDirectory(const string &filename) {
	DWORD r = GetFileAttributes(filename.c_str());
	if (r == 0xffffffff)
		return false;
	else
		return (r & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

bool ensure(const string& dir) {
	if (isDirectory(dir))
		return true;
	if (exists(dir))
		return false;
	if (!ensure(directory(dir)))
		return false;
	if (CreateDirectory(dir.c_str(), null) != FALSE)
		return true;
	else
		return false;
}

bool readAll(FILE* fp, string* output) {
	fseek(fp, 0, SEEK_END);
	long pos = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	char* cp = output->buffer_(pos);
	int n = fread(cp, 1, pos, fp);
	if (ferror(fp)) {
		output->clear();
		return false;
	}
	output->resize(n);
	return true;
}

string pathRelativeTo(const string& filename, const string& baseFilename) {
	if (isRelativePath(filename))
		return directory(baseFilename) + "\\" + filename;
	else
		return filename;
}

bool isRelativePath(const string& filename) {
	if (filename.size() == 0 || filename[0] == '\\' || filename[0] == '/' || filename.find(':') != string::npos)
		return false;
	else
		return true;
}

string makeCompactPath(const string& filename, const string& baseFilename) {
	if (isRelativePath(filename))
		return filename;
	string a1 = absolutePath(filename);
	string a2 = absolutePath(baseFilename);

	int span;
	if (a1.size() < a2.size())
		span = a1.size();
	else
		span = a2.size();
	int i;
	int firstSlash = -1;
	int lastSlash = -1;
	for (i = 0; i < span; i++) {
		if (a1[i] != a2[i]) {
			if (firstSlash == lastSlash)
				break;

				// There is a common directory prefix!

			int slashCount = 0;
			for (int j = i + 1; j < a2.size(); j++)
				if (a2[j] == '\\')
					slashCount++;
			if (slashCount == 0)
				return a1.substr(lastSlash + 1);
			string result;
			while (slashCount > 0) {
				result.append("../");
				slashCount--;
			}
			return result + a1.substr(lastSlash + 1);
		}
		if (a1[i] == '\\') {
			lastSlash = i;
			if (firstSlash < 0)
				firstSlash = i;
		}
	}
	return a1;
}

Directory::Directory(const string &path) {
	memset(&_data, 0, sizeof _data);
	_handle = INVALID_HANDLE_VALUE;
	_directory = path;
	_wildcard = "*";
}

void Directory::pattern(const string &wildcard) {
	_wildcard = wildcard;
}

Directory::~Directory() {
	if (_handle != INVALID_HANDLE_VALUE)
		FindClose(_handle);
}

bool Directory::first() {
	string s = _directory + "\\" + _wildcard;
	_handle = FindFirstFile(s.c_str(), &_data);
	return _handle != INVALID_HANDLE_VALUE;
}

bool Directory::next() {
	BOOL result = FindNextFile(_handle, &_data);
	if (result)
		return true;
	FindClose(_handle);
	_handle = INVALID_HANDLE_VALUE;
	return false;
}

string Directory::currentName() {
	return _directory + "/" + _data.cFileName;
}

}
