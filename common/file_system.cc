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
#include "atom.h"
#include "machine.h"
#include "parser.h"

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

enum FieldType {
	FT_BOOL,
	FT_INT,
	FT_UNSIGNED,
	FT_FLOAT,
	FT_DOUBLE,
	FT_LONG,
	FT_MINUTES,
	FT_STRING,
	FT_RECORD,
	FT_GROUP,
};

static FieldType lookupFieldType(const string& s) {
	if (s == "bool")
		return FT_BOOL;
	else if (s == "int")
		return FT_INT;
	else if (s == "unsigned")
		return FT_UNSIGNED;
	else if (s == "float")
		return FT_FLOAT;
	else if (s == "double")
		return FT_DOUBLE;
	else if (s == "long")
		return FT_LONG;
	else if (s == "minutes")
		return FT_MINUTES;
	else if (s == "string")
		return FT_STRING;
	else if (s == "group")
		return FT_GROUP;
	else
		return FT_RECORD;
}

class Record;

class Field {
public:
	string		name;
	FieldType	type;
	string		reference;
	Record*		record;
	int			repeat;

	Field(const string& name, FieldType type, const string& reference, Record* record, int repeat) {
		this->name = name;
		this->type = type;
		this->reference = reference;
		this->record = record;
		this->repeat = repeat;
	}

	bool resolve(const dictionary<Record*>& index) {
		if (type == FT_RECORD) {
			Record* const * r = index.get(reference);
			record = *r;
			if (*r == null) {
				printf("Undefined reference to record type '%s'\n", reference.c_str());
				return false;
			}
		}
		return true;
	}
};
	
class Record {
public:
	Record() {
		_base = null;
	}

	string				name;
	string				inherits;
	int					index;

	bool parseGroup(const string& prefix, script::Atom* node) {
		script::Atom& contents = *node->get("content");
		for (int i = 0; i < contents.size(); i++) {
			script::Atom* tag = contents[i]->get("tag");
			if (tag == null) {
				printf("Not a tagged object\n");
				return false;
			}
			script::Atom* type = contents[i]->get("type");
			if (type == null) {
				printf("Field '%s.%s' has no type.\n", prefix.c_str(), tag->toString().c_str());
				return false;
			}
			FieldType ft = lookupFieldType(type->toString());
			int repeat;
			script::Atom* repeatAtom = contents[i]->get("repeat");
			if (repeatAtom && i != contents.size() - 1) {
				printf("Cannot specify a repeatable field other than last\n");
				return false;
			}
			if (repeatAtom) {
				if (repeatAtom->toString() == "any")
					repeat = -1;
				else
					repeat = repeatAtom->toString().toInt();
			} else
				repeat = 1;
			if (ft == FT_GROUP) {
				Record* subRecord = new Record();
				subRecord->parseGroup(prefix + "." + tag->toString(), contents[i]);
				if (!defineGroup(tag->toString(), subRecord, repeat)) {
					printf("Duplicate field id '%s.%s'\n", prefix.c_str(), tag->toString().c_str());
					return false;
				}
			} else {
				if (!defineField(tag->toString(), ft, type->toString(), repeat)) {
					printf("Duplicate field id '%s.%s'\n", prefix.c_str(), tag->toString().c_str());
					return false;
				}
			}
		}
		return true;
	}

	bool defineField(const string& name, FieldType type, const string& reference, int repeat) {
		Field* const* fx = _index.get(name);
		if (*fx)
			return false;
		Field* f = new Field(name, type, reference, null, repeat);
		_fields.push_back(f);
		_index.insert(name, f);
		return true;
	}

	bool defineGroup(const string& name, Record* record, int repeat) {
		Field* const* fx = _index.get(name);
		if (*fx)
			return false;
		Field* f = new Field(name, FT_GROUP, string(), record, repeat);
		_fields.push_back(f);
		_index.insert(name, f);
		return true;
	}

	bool resolve(const dictionary<Record*>& index) {
		if (inherits.size()) {
			Record* const * r = index.get(inherits);
			_base = *r;
			if (*r == null) {
				printf("Undefined base reference to record type '%s'\n", inherits.c_str());
				return false;
			}
		} else
			_base = null;
		for (int i = 0; i < _fields.size(); i++)
			if (!_fields[i]->resolve(index))
				return false;
		return true;
	}

	bool dump(int indent, Storage::Reader& r) {
		if (_base) {
			if (!_base->dump(indent, r))
				return false;
		}
		for (int i = 0; i < _fields.size(); i++) {
			switch (_fields[i]->repeat) {
			case	-1:
				while (!r.endOfRecord()) {
					if (!dumpField(indent, _fields[i], r))
						return false;
				}
				break;

			default:
				for (int j = 0; j < _fields[i]->repeat; j++)
					if (!dumpField(indent, _fields[i], r))
						return false;
			}
		}
		return true;
	}

	bool dumpField(int indent, Field* f, Storage::Reader& r) {
		unsigned v;
		string s;

		printf("%*c%-20s", indent * 4, ' ', f->name.c_str());
		switch (f->type) {
		case	FT_BOOL:
			if (!r.read(&v) ||
				v < 0 ||
				v > 1) {
				printf("Failure to read\n");
				return false;
			}
			printf("%s\n", v ? "true" : "false");
			break;

		case	FT_INT:
			if (!r.read(&v)) {
				printf("Failure to read\n");
				return false;
			}
			printf("%d\n", v);
			break;

		case	FT_UNSIGNED:
			if (!r.read(&v)) {
				printf("Failure to read\n");
				return false;
			}
			printf("%u\n", v);
			break;

		case	FT_FLOAT:
			if (!r.read(&v)) {
				printf("Failure to read\n");
				return false;
			}
			printf("%g\n", *(float*)&v);
			break;

		case	FT_MINUTES:
			if (!r.read(&v)) {
				printf("Failure to read\n");
				return false;
			}
			printf("%s %s\n", fromGameDate(v).c_str(), fromGameTime(v).c_str());
			break;

		case	FT_STRING:
			if (!r.read(&s)) {
				printf("Failure to read length\n");
				return false;
			}
			printf("'%s'\n", s.c_str());
			break;

		case	FT_RECORD:
			if (!r.read(&v)) {
				printf("Failure to read\n");
				return false;
			}
			printf("->%d\n", v);
			break;

		case	FT_GROUP:
			printf("\n");
			f->record->dump(indent + 1, r);
			break;

		default:
			printf("Unknown type %d\n", f->type);
			return false;
		}
		return true;
	}

private:
	Record*				_base;
	vector<Field*>		_fields;
	dictionary<Field*>	_index;
};

class StorageSchema {
public:
	void clear() {
		_index.deleteAll();
		_records.clear();
	}

	bool defineRecord(Record* record) {
		if (!defineBase(record))
			return false;
		record->index = _records.size() + 1;
		_records.push_back(record);
		return true;
	}

	bool defineBase(Record* record) {
		Record* const* r = _index.get(record->name);
		if (*r)
			return false;
		_index.insert(record->name, record);
		record->index = 0;
		return true;
	}

	bool resolve() {
		dictionary<Record*>::iterator i = _index.begin();
		while (i.hasNext()) {
			Record* record = *i;
			record->resolve(_index);
			i.next();
		}
		return true;
	}

	Record* record(int i) const { return _records[i]; }

	int record_size() const { return _records.size(); }
private:
	vector<Record*>		_records;
	dictionary<Record*>	_index;
};

static StorageSchema dumpSchema;

class HsvObject : script::Object {
public:
	static script::Object* factory() {
		return new HsvObject();
	}

	HsvObject() {}

	virtual bool validate(script::Parser* parser) {
		return true;
	}

	virtual bool run() {
		return runAnyContent();
	}

};

class RecordObject : script::Object {
public:
	static script::Object* factory() {
		return new RecordObject();
	}

	RecordObject() {}

	virtual bool validate(script::Parser* parser) {
		script::Atom* a = get("id");
		if (a == null) {
			printf("No id: attribute for record\n");
			return false;
		}
		Record* record = new Record();
		record->name = a->toString();
		a = get("inherits");
		if (a)
			record->inherits = a->toString();
		if (get("tag")->toString() == "record") {
			if (!dumpSchema.defineRecord(record)) {
				printf("Duplicate record id: '%s'\n", record->name.c_str());
				return false;
			}
		} else {
			if (!dumpSchema.defineBase(record)) {
				printf("Duplicate base id: '%s'\n", record->name.c_str());
				return false;
			}
		}
		return record->parseGroup(record->name, this);
	}

	virtual bool run() {
		return true;
	}

private:
	bool				_record;
	string				_id;
	string				_inherits;
	script::Atom*		_contents;
};

class StorageHeader {
public:
	StorageHeader() {
		magic[0] = 'E';
		magic[1] = 'g';
		magic[2] = '1';
		magic[3] = '0';
		keyTest[0] = 0;
		keyTest[1] = 0;
		keyTest[2] = 0;
		keyTest[3] = 0;
	}

	bool valid() {
		if (magic[0] == 'E' &&
			magic[1] == 'g' &&
			magic[2] == '1' &&
			magic[3] == '0' &&
			keyTest[0] == 0 &&
			keyTest[1] == 0 &&
			keyTest[2] == 0 &&
			keyTest[3] == 0)
			return true;
		else
			return false;
	}

	char magic[4];
	char keyTest[4];				// Used to verify the encryption key
};

Storage::Storage(const string& filename, const StorageMap* map) {
	_filename = filename;
	_map = map;
	_file = null;
}

Storage::~Storage() {
	_objects.deleteAll();
}

bool Storage::load() {
	_file = openBinaryFile(_filename);
	string s;
	bool result = readAll(_file, &s);
	fclose(_file);
	_file = null;
	if (!result)
		return false;
	StorageHeader* h = (StorageHeader*)s.c_str();
	if (!h->valid())
		return false;
	Reader r(this, s);
	int i = 1;
	while (!r.done()) {
		int index = r.nextRecord(i);
		if (index <= 0)
			return false;
		index--;			// record type bytes are 1-based
		if (index >= _map->_factories.size())
			return false;
		StorageMap::StorageMapEntry* e = _map->_factories[index];
		void* o = e->make(&r);
		if (o == null) {
			debugPrint(string(e->type->name()) + ": errors making object " + _objects.size() + "\n");
			return false;
		}
		r.finishRecord(i, o, e->type);
		if (r.errorsFound()) {
			debugPrint(string(e->type->name()) + ": errors parsing object " + _objects.size() + "\n");
			return false;
		}
		i++;
	}
	return r.applyFixups();
}

bool Storage::write() {
	if (!createBackupFile(_filename))
		return false;

	_file = createBinaryFile(_filename);
	if (_file == null)
		return false;
	StorageHeader h;
	if (fwrite(&h,
			sizeof (StorageHeader),
			1,
			_file) != 1) {
		fclose(_file);
		_file = null;
		erase(_filename);
		return false;
	}
	// TODO: write the schema

	for (int i = 0; i < _objects.size(); i++) {
		char recordKey = _map->recordKey(_objects[i]->type());
		if (recordKey == 0) {
			debugPrint(string(_objects[i]->type()->name()) + ": undefined type\n");
			fclose(_file);
			_file = null;
			erase(_filename);
			return false;
		}
		startOfRecord(recordKey);
		_objects[i]->store();
		endOfRecord();
	}

	fclose(_file);
	_file = null;
	return true;
}

bool Storage::dump(const string& schemaFile) {
	script::objectFactory("hsv", HsvObject::factory);
	script::objectFactory("record", RecordObject::factory);
	script::objectFactory("base", RecordObject::factory);
	script::Parser* p = script::Parser::load(schemaFile);
	if (p == null) {
		printf("Failed to load schema\n");
		return false;
	}
	vector<script::Atom*> atoms;
	dumpSchema.clear();

	p->content(&atoms);
	if (!p->parse()) {
		printf("Failed to parse schema\n");
		return false;
	}
	delete p;
	if (atoms.size() != 1 ||
		typeid(*atoms[0]) != typeid(HsvObject)) {
		printf("Schema must consist of a single hsv tag\n");
		return false;
	}
	if (!atoms[0]->run())
		return false;
	if (!dumpSchema.resolve())
		return false;

	_file = openBinaryFile(_filename);
	string s;
	bool result = readAll(_file, &s);
	fclose(_file);
	_file = null;
	if (!result) {
		printf("Couldn't read '%s'\n", _filename.c_str());
		return false;
	}
	StorageHeader* h = (StorageHeader*)s.c_str();
	printf("Header:\n"
		   "   Magic: %02x %02x '%c%c'\n"
		   "   Version: %c.%c\n"
		   "   Key Test: %02x %02x %02x %02x\n",
		   h->magic[0] & 0xff,
		   h->magic[1] & 0xff,
		   h->magic[0] & 0xff,
		   h->magic[1] & 0xff,
		   h->magic[2] & 0xff,
		   h->magic[3] & 0xff,
		   h->keyTest[0] & 0xff,
		   h->keyTest[1] & 0xff,
		   h->keyTest[2] & 0xff,
		   h->keyTest[3] & 0xff);

	if (!h->valid()) {
		printf("Invalid header\n");
		return false;
	}
	Reader r(this, s);
	int i = 1;
	while (!r.done()) {
		int index = r.nextRecord(i);
		if (index <= 0) {
			printf("Record %d index too low (%d)\n", i, index);
			return false;
		}
		index--;			// record type bytes are 1-based
		if (index >= _map->_factories.size()) {
			printf("Record %d index too high (%d) - max is %d\n", i, index + 1, _map->_factories.size());
			return false;
		}
		if (index >= dumpSchema.record_size()) {
			printf("Record %s index too high for schema (%d) - max is %d\n", i, index + 1, dumpSchema.record_size());
			return false;
		}
		StorageMap::StorageMapEntry* e = _map->_factories[index];
		Record* record = dumpSchema.record(index);
		printf("@x%08x [%d] %s\n", r._cursor - 1, i, e->type->name());
		if (!record->dump(1, r))
			return false;
		r.finishRecord(i, null, e->type);
		if (r.errorsFound()) {
			printf("%d: errors parsing object type '%s'\n", i, e->type->name());
			return false;
		}
		i++;
	}
	return true;
}


Storage::Writer* Storage::lookup(const void* t) {
	string s;

	char* buf = s.buffer_(sizeof t);
	*(const void**)buf = t;
	return *_index.get(s);
}

void Storage::reserve(Storage::Writer* o) {
	o->init(this, _objects.size() + 1);
	_objects.push_back(o);
	string s;

	char* buf = s.buffer_(sizeof (void*));
	*(void**)buf = o->object();
	_index.insert(s, o);
}

void Storage::startOfRecord(char recordKey) {
	fputc(recordKey, _file);
}

void Storage::recordInteger(unsigned u) {
	// Note: code relies on sizeof (unsigned) <= 8
	char buffer[10];
	int i = 0;
	while (u >= 0x7f) {
		buffer[i] = 0x80 | (u & 0x7f);
		i++;
		u >>= 7;
	}
	buffer[i] = u;
	fwrite(buffer, 1, i + 1, _file);
}

void Storage::recordData(const char* buffer, int length) {
	fwrite(buffer, 1, length, _file);
}

void Storage::endOfRecord() {
	fputc(0x7f, _file);
}

bool Storage::fetch(int index, void **tp, const std::type_info *type) {
	*tp = null;
	if (index < 1 || index > _objects.size())
		return false;
	index--;
/*
	// This equality does not hold when the loaded object is of a type
	// derived from the declared type (which is the type stored in the
	// fixup, because that was determined from the template object.
	// C++ provides no way to test the more useful relationship
	// _objects[index]->type().derivesFromOrEquals(type)).
	if (_objects[index]->type() != type)
		return false;
 */
	*tp = _objects[index]->object();
	return true;
}

void Storage::Writer::write(const unsigned& u) {
	_storage->recordInteger(u);
}

void Storage::Writer::write(const int& i) {
	_storage->recordInteger(i);
}

void Storage::Writer::write(const short& i) {
	_storage->recordInteger(i);
}

void Storage::Writer::write(const float& f) {
	_storage->recordInteger(*(int*)&f);
}

void Storage::Writer::write(const string& s) {
	_storage->recordInteger(s.size());
	_storage->recordData(s.c_str(), s.size());
}

Storage::Reader::Reader(Storage* storage, const string& contents) : _contents(contents) {
	_storage = storage;
	_cursor = sizeof (StorageHeader);
	_errorsFound = false;
}

int Storage::Reader::nextRecord(int recordNumber) {
	_recordNumber = recordNumber;
	int x = _contents[_cursor] & 0xff;
	if (x < 0x7f) {
		_cursor++;
		return x;
	} else
		return -1;
}

void Storage::Reader::finishRecord(int recordNumber, void* t, const std::type_info* type) {
	if (_cursor < _contents.size() &&
		_contents[_cursor] == 0x7f) {
		if (t) {
			_storage->_objects.push_back(new LoadedObject(t, type));
			if (recordNumber != _storage->_objects.size()) {
				_errorsFound = true;
				_cursor = _contents.size();
			}
		}
		_cursor++;
	} else {
		_errorsFound = true;
		_cursor = _contents.size();
	}
}

bool Storage::Reader::endOfRecord() {
	return _cursor < _contents.size() &&
		   _contents[_cursor] == 0x7f;
}

int Storage::Reader::remainingFieldCount() {
	int loc = _cursor;
	int i = 0;
	while (!endOfRecord()) {
		unsigned x;
		if (!read(&x)) {
			_errorsFound = true;
			_cursor = _contents.size();
			return 0;
		}
		i++;
	}
	_cursor = loc;
	return i;
}

bool Storage::Reader::read(unsigned* value) {
	*value = 0;
	int shiftBy = 0;
	for (;;) {
		if (_cursor >= _contents.size()) {
			_errorsFound = true;
			return false;
		}
		int x = _contents[_cursor] & 0xff;
		if (x & 0x80) {
			_cursor++;
			*value += (x & 0x7f) << shiftBy;
		} else if (x == 0x7f) {
			_errorsFound = true;
			return false;
		} else {
			_cursor++;
			*value += x << shiftBy;
			break;
		}
		shiftBy += 7;
		if (shiftBy > 32) {
			_errorsFound = true;
			return false;
		}
	}
	return true;
}

bool Storage::Reader::read(bool* value) {
	unsigned v;
	if (!read(&v))
		return false;
	if (v > 1) {
		_errorsFound = true;
		return false;
	}
	*value = v != 0;
	return true;
}

bool Storage::Reader::read(string* value) {
	unsigned len;
	if (!read(&len))
		return false;
	if (_cursor + len >= (unsigned)_contents.size()) {
		_errorsFound = true;
		return false;
	}
	char* buf = value->buffer_(len);
	memcpy(buf, _contents.c_str() + _cursor, len);
	_cursor += len;
	return true;
}

bool Storage::Reader::read(int* value) {
	unsigned v;
	if (!read(&v))
		return false;
	*value = v;
	return true;
}

bool Storage::Reader::read(float* value) {
	unsigned v;
	if (!read(&v))
		return false;
	*value = *(float*)&v;
	return true;
}

bool Storage::Reader::read(short* value) {
	unsigned v;
	if (!read(&v))
		return false;
	*value = v;
	return true;
}

void Storage::Reader::fixup(int index, void** tp, const std::type_info* type) {
	int i = _fixups.size();
	_fixups.resize(i + 1);
	_fixups[i].location = tp;
	_fixups[i].reference = index;
	_fixups[i].type = type;
}

bool Storage::Reader::applyFixups() {
	for (int i = 0; i < _fixups.size(); i++)
		if (!_storage->fetch(_fixups[i].reference, _fixups[i].location, _fixups[i].type))
			return false;
	return true;
}

char StorageMap::recordKey(const std::type_info* type) const {
	StorageMapEntry*const * s = _types.get(type->name());
	if (*s == null)
		return 0;
	else
		return (*s)->recordKey;
}

}  // namespace fileSystem

static string fromGameDate(unsigned m) {
	if (m == 0)
		return "";

	long long t = ((long long)m) * oneMinute;
	SYSTEMTIME d;
	if (!FileTimeToSystemTime((FILETIME*)&t, &d))
		return "";

	int y = d.wYear;
	if (y > 1900 && y < 1999)
		y -= 1900;
	return string(d.wMonth) + "/" + d.wDay + "/" + y;
}

static string fromGameTime(unsigned m) {
	if (m == 0)
		return "";
	long long t = ((long long)m) * oneMinute;
	SYSTEMTIME d;
	if (!FileTimeToSystemTime((FILETIME*)&t, &d))
		return "";

	char buffer[10];
	sprintf(buffer, "%02d:%02d", d.wHour, d.wMinute);
	return buffer;
}
