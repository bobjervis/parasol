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
#pragma once
#include <stdio.h>
#include <time.h>
#ifdef __WIN64
#include <windows.h>
#elif __linux__
#include <dirent.h>
#endif
#ifdef MSVC
#include <typeinfo.h>
#else
#include <typeinfo>
#endif

#include "dictionary.h"
#include "string.h"
#include "vector.h"

namespace fileSystem {

FILE* openBinaryFile(const string& filename);

//string basename(const string& filename);
string directory(const string& filename);
//string absolutePath(const string& filename);
//const char* extension(const string& filename);
/*
 *	Construct path
 *
 *	This function combines the elements of a filename in the following way:
 *
 *		1. If directory is not empty, the baseName is added to the directory 
 *		   string (with suitable directory separators added).  Otherwise the 
 *		   baseName is used.
 *		2. If the extension is not empty the extension portion of the result of
 *		   step 1 (if any) is stripped and the extension is added.  The
 *		   resulting string is returned.
 */
string constructPath(const string& directory, const string& baseName, const string& extension);
/*
static const long long UNITS_PER_SECOND = 10000000;			// Record as 100 nsec units.
static const long long NANOS_PER_TIMESTAMP = 100;

class TimeStamp {
public:
	static TimeStamp UNDEFINED;

	TimeStamp() {
		_time = 0;
	}

	TimeStamp(time_t t) {
		_time = t * UNITS_PER_SECOND;
	}

#if defined(__WIN64)
	TimeStamp(FILETIME& t) {
		// Use UNIX era
		_time = *(long long*)&t - ERA_DIFF;
	}
#elif __linux__
	TimeStamp(timespec& tspec) {
		_time = tspec.tv_sec * UNITS_PER_SECOND + tspec.tv_nsec / NANOS_PER_TIMESTAMP;
	}
#endif

	void clear() { _time = 0; }

	bool operator == (const TimeStamp& t2) const {
		return _time == t2._time;
	}

	bool operator != (const TimeStamp& t2) const {
		return _time != t2._time;
	}

	bool operator < (const TimeStamp& t2) const {
		return _time < t2._time;
	}

	bool operator > (const TimeStamp& t2) const {
		return _time > t2._time;
	}

	bool operator <= (const TimeStamp& t2) const {
		return _time <= t2._time;
	}

	bool operator >= (const TimeStamp& t2) const {
		return _time >= t2._time;
	}

	string toString();

	void touch();

	void setValue(long long t) { _time = t; }

	long long value() const { return _time; }

	time_t asTime_t() const { return _time / UNITS_PER_SECOND; }

#if __linux__
	timespec asTimespec() const {
		timespec spec;

		spec.tv_sec = _time / UNITS_PER_SECOND;
		spec.tv_nsec = (_time % UNITS_PER_SECOND) * NANOS_PER_TIMESTAMP;
	}
#endif
private:

#if defined(__WIN64)
	static const long long ERA_DIFF = 0x019DB1DED53E8000LL;
#endif

	long long _time;
};

TimeStamp lastModified(const string& filename);
TimeStamp lastModified(FILE* fp);
TimeStamp now();

bool rename(const string& f1, const string& f2);
bool erase(const string& filename);
bool exists(const string& fn);
bool writable(const string& fn);
bool isDirectory(const string& filename);
bool ensure(const string& dir);
bool readAll(FILE* fp, string* output);
*/
/*
 *	pathRelativeTo
 *
 *	Constructs a path from the 'filename' argument by the following
 *	rules:
 *
 *		If the 'filename' argument is not a relative path, return the
 *		argument unchanged.
 *
 *		If the 'filename' argument is a relative path, make a new path
 *		by combining it with the directory portion of the baseFilename.
 *		Note the resulting path is relative if the baseFilename path is
 *		relative.  If the baseFilename has no directory, then the 'filename'
 *		argument is returned with a '.' directory added.
 */
//string pathRelativeTo(const string& filename, const string& baseFilename);
/*
 *	isRelativePath
 *
 *	Returns true if the 'filename' argument contains a relative path string
 *	and false otherwise.  The contents of the string are not validated.  It
 *	is assumed that the string contains a valid path that is either relative
 *	or absolute.  In UNIX and Linux systems, a path is relative if it does
 *	not begin with a /.  In Windows it is relative if it contains neither a
 *	drive specifier (:) not does it begin with a / or a \.
 */
//bool isRelativePath(const string& filename);
/*
 *	makeCompactPath
 *
 *	Returns a path from the 'filename' argument.  If it is a relative path,
 *	it is returned unchanged.  If it is not, the 'filename' argument is
 *	compared with the 'baseFilename' argument.  If they share a common base
 *	directory, a relative path is constructed such that the return string is
 *	a path relative to the 'baseFilename' directory.  If necessary, the
 *	resulting string may begin with one or more '..' directories.
 *
 *	If no suitable relative path can be constructed, the absolutePath(filename)
 *	is returned.
 */
/*
string makeCompactPath(const string& filename, const string& baseFilename);

class Directory {
public:
	Directory(const string& path);

	~Directory();

	void pattern(const string& wildcard);

	bool first();

	bool next();

	string currentName();

private:
#if defined(__WIN64)
	HANDLE				_handle;
	WIN32_FIND_DATA		_data;
#elif __linux__
	DIR					*_dir;
	dirent				*_dirent;
#endif
	string				_directory;
	string				_wildcard;
};
 */
}  // namespace fileSystem
