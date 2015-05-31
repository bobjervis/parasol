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
#pragma once
#include <stdio.h>
#include <time.h>
#include <windows.h>
#ifdef MSVC
#include <typeinfo.h>
#else
#include <typeinfo>
#endif

#include "dictionary.h"
#include "string.h"
#include "vector.h"

namespace fileSystem {

class StorageMap;

FILE* openTextFile(const string& filename);

FILE* createTextFile(const string& filename);

FILE* openBinaryFile(const string& filename);

FILE* createBinaryFile(const string& filename);

bool createBackupFile(const string& filename);

string basename(const string& filename);
string directory(const string& filename);
string absolutePath(const string& filename);
const char* extension(const string& filename);
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

class TimeStamp {
public:
	static TimeStamp UNDEFINED;

	TimeStamp() {
		_time = 0;
	}

	TimeStamp(time_t t) {
		_time = t * 10000000;			// Record as 100 nsec units.
	}

	TimeStamp(FILETIME& t) {
		// Use UNIX era
		_time = *(__int64*)&t - ERA_DIFF;
	}

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

	void setValue(__int64 t) { _time = t; }

	__int64 value() const { return _time; }

private:
	static const __int64 ERA_DIFF = 0x019DB1DED53E8000LL;

	__int64		_time;
};

TimeStamp lastModified(const string& filename);
TimeStamp lastModified(FILE* fp);

bool rename(const string& f1, const string& f2);
bool erase(const string& filename);
bool exists(const string& fn);
bool writable(const string& fn);
bool isDirectory(const string& filename);
bool ensure(const string& dir);
bool readAll(FILE* fp, string* output);
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
string pathRelativeTo(const string& filename, const string& baseFilename);
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
bool isRelativePath(const string& filename);
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
	HANDLE				_handle;
	WIN32_FIND_DATA		_data;
	string				_directory;
	string				_wildcard;
};

class Storage {
public:
	Storage(const string& filename, const StorageMap* map);

	~Storage();

	bool load();

	bool write();

	bool dump(const string& schemaFile);

	template<class T>
	int store(const T* t) {
		if (t == null)
			return 0;
		Writer* o = lookup(t);
		if (o == null) {
			o = new WriterT<T>(t);
			reserve(o);
		}
		return o->_index;
	}

	template<class T>
	bool fetch(int index, T** t) {
		return fetch(index, (void**)t, &typeid(T));
	}

	class Writer {
		friend class Storage;
	public:
		Writer() {
			_storage = null;
			_index = 0;
		}
		
		void write(const string& s);

		void write(const unsigned& u);

		void write(const int& i);

		void write(const short& i);

		void write(const __int64& x);

		void write(const float& f);

		template<class T>
		void write(const T* t) {
			int i = _storage->store(t);
			write(i);
		}

	protected:
		virtual void store() = 0;

		virtual const std::type_info* type() = 0;

		virtual void* object() = 0;

	private:
		void init(Storage* s, int index) {
			_storage = s;
			_index = index;
		}

		int				_index;
		Storage*		_storage;
	};

	class Reader {
		friend class Storage;

		Reader(Storage* storage, const string& contents);

		bool done() const { return _cursor >= _contents.size(); }

		bool errorsFound() const { return _errorsFound; }

		int nextRecord(int recordNumber);

		void finishRecord(int recordNumber, void* t, const std::type_info* type);

	public:
		bool read(unsigned* value);

		bool read(bool* value);

		bool read(string* value);

		bool read(int* value);

		bool read(short* value);

		bool read(float* value);

		template<class T>
		bool read(T** value) {
			unsigned v;

			if (!read(&v))
				return false;
			if (v) {
				*value = (T*)0xd00fdaab;
				fixup(v, (void**)value, &typeid(T));
			} else
				*value = null;
			return true;
		}

		bool endOfRecord();

		int remainingFieldCount();

		int recordNumber() const { return _recordNumber; }

		int tell() const { return _cursor; }

		void seek(int location) { _cursor = location; }

	private:
		class Fixup {
		public:
			void**					location;
			int						reference;
			const std::type_info*	type;
		};

		void fixup(int index, void** tp, const std::type_info* type);

		bool applyFixups();

		Storage*		_storage;
		const string&	_contents;
		int				_cursor;
		bool			_errorsFound;
		vector<Fixup>	_fixups;
		int				_recordNumber;
	};

private:

	template<class T>
	class WriterT : public Writer {
	public:
		WriterT(const T* t) {
			_object = t;
		}

		virtual void store() {
			_object->store((Writer*)this);
		}

		virtual const std::type_info* type() {
			return &typeid(*_object);
		}

		virtual void* object() { return (void*)_object; }

	private:
		const T*	_object;
	};

	class LoadedObject : public Writer {
		friend class Storage;
	public:
		LoadedObject(void* t, const std::type_info* type) {
			_object = t;
			_type = type;
		}

		virtual void store() {
			// Should trigger some sort of failure: exception?
		}

		virtual const std::type_info* type() {
			return _type;
		}

		virtual void* object() { return _object; }

	private:
		void*					_object;
		const std::type_info*	_type;
	};

	Writer* lookup(const void* t);

	void reserve(Writer* o);

	void startOfRecord(char recordKey);

	void recordInteger(unsigned u);

	void recordData(const char* buffer, int length);

	void endOfRecord();

	bool fetch(int index, void** tp, const std::type_info* type);

	vector<Writer*>		_objects;
	string				_filename;
	const StorageMap*	_map;
	FILE*				_file;
	dictionary<Writer*>	_index;
};

class StorageMap {
	friend class Storage;
public:
	StorageMap() {
	}

	template<class A>
	bool define(A* (*factory)(Storage::Reader* r)) {
		StorageMapEntry** lookup = _types.get(typeid(A).name());
		if (*lookup)
			return false;
		StorageMapEntry* s = new StorageMapEntry1<A>(factory);
		s->type = &typeid(A);
		s->recordKey = _factories.size() + 1;
		_types.insert(s->type->name(), s);
		_factories.push_back(s);
		return true;
	}

	char recordKey(const std::type_info* type) const;

private:
	class StorageMapEntry {
	public:
		virtual void* make(Storage::Reader* r) = 0;

		const std::type_info*	type;
		char					recordKey;
	};

	template <class A>
	class StorageMapEntry1 : public StorageMapEntry {
	public:
		StorageMapEntry1(A* (*factory)(Storage::Reader* r)) {
			_factory = factory;
		}

		virtual void* make(Storage::Reader* r) {
			return _factory(r);
		}

	private:
		A* (*_factory)(Storage::Reader* r);
	};

	dictionary<StorageMapEntry*>	_types;
	vector<StorageMapEntry*>		_factories;
};

}  // namespace fileSystem
