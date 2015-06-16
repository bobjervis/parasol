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
#ifndef PARASOL_BASIC_TYPES_H
#define PARASOL_BASIC_TYPES_H

#include "common/string.h"
#include "common/vector.h"
/*
 * Date and Copyright holder of this code base.
 */
#define COPYRIGHT_STRING "2011 Robert Jervis"
/*
 * Major Release: Incremented when a breaking change is released
 * Minor Feature Release: Incremented when significant new features
 * are released.
 * Fix Release: Incremented when big fixes are released.
 */
#define RUNTIME_VERSION "1.0.0"

namespace parasol {

class CompileString {
public:
	template<class A>
	void set(A *object, const vector<char> &value) {
		length = value.size();
		data = (const char *) memcpy((char *)(object + 1), &value[0], length);
	}

	template<class A>
	void set(A *object, const string &value) {
		length = value.size();
		data = (const char *) memcpy((char *)(object + 1), &value[0], length);
	}

	CompileString() {
	}

	CompileString(const vector<char> *value) {
		length = value->size();
		data = &(*value)[0];
	}

	CompileString(const char *value) {
		if (value != null)
			length = strlen(value);
		else
			length = -1;
		data = value;
	}

	bool operator==(const CompileString &other) const {
		if (length != other.length)
			return false;
		for (int i = 0; i < length; i++)
			if (data[i] != other.data[i])
				return false;
		return true;
	}

	bool operator!=(const CompileString &other) const {
		if (length != other.length)
			return true;
		for (int i = 0; i < length; i++)
			if (data[i] != other.data[i])
				return true;
		return false;
	}

	bool operator==(const char *other) const {
		if (other == null)
			return data == null;
		for (int i = 0; i < length; i++) {
			if (other[i] == 0)
				return false;
			if (data[i] != other[i])
				return false;
		}
		return other[length] == 0;
	}

	bool operator!=(const char *other) const {
		if (other == null)
			return data != null;
		for (int i = 0; i < length; i++) {
			if (other[i] == 0)
				return true;
			if (data[i] != other[i])
				return true;
		}
		return other[length] != 0;
	}

	string asString() const {
		return string(data, length);
	}

	const char *data;
	int length;
};

class Location {
public:
	static Location OUT_OF_FILE;

	int		offset;

	bool operator==(Location loc) const {
		return offset == loc.offset;
	}

	bool operator>(Location loc) const {
		return offset > loc.offset;
	}

	bool operator<(Location loc) const {
		return offset < loc.offset;
	}

	int compare(const Location loc) const {
		return offset - loc.offset;
	}

	bool isInFile() const {
		return offset != OUT_OF_FILE.offset;
	}
};

enum TypeFamily {
	TF_SIGNED_8,
	TF_SIGNED_16,
	TF_SIGNED_32,
	TF_SIGNED_64,
	TF_UNSIGNED_8,
	TF_UNSIGNED_16,
	TF_UNSIGNED_32,
	TF_UNSIGNED_64,
	TF_FLOAT_32,
	TF_FLOAT_64,
	TF_BOOLEAN,
	TF_STRING,
	TF_VAR,
	TF_ADDRESS,
	TF_VOID,
	TF_ERROR,
	TF_CLASS_VARIABLE,
	TF_CLASS_DEFERRED,
	TF_NAMESPACE,
	TF_BUILTIN_TYPES,
	TF_CLASS,
	TF_ENUM,
	TF_TYPEDEF,
	TF_FUNCTION,
	TF_VECTOR,
	TF_TEMPLATE,
	TF_TEMPLATE_INSTANCE,
	TF_MAX_TYPES,
	TF_MIN_TYPE = TF_SIGNED_8
};

class Type;

class ParasolStringParameter {
	ParasolStringParameter() : _contents(0) {
	}
public:

	~ParasolStringParameter() {
	}

	int size() const {
		if (_contents)
			return _contents->length;
		else
			return 0;
	}

	const char* c_str() const {
		if (_contents)
			return _contents->data;
		else
			return "";
	}

	string toString() const {
		if (_contents)
			return string(_contents->data, _contents->length);
		else
			return string();
	}

	const char& operator [] (int i) const {
		if (_contents)
			return _contents->data[i];
		else
			return dummy;
	}

private:
	static char dummy;

	struct allocation {
		int length;
		char data[1];
	};

	allocation* _contents;
};

} // namespace parasol
#endif // PARASOL_BASIC_TYPES_H
