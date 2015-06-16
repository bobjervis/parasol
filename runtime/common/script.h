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
#include "string.h"

namespace script {

typedef __int64 fileOffset_t;

const fileOffset_t FILE_OFFSET_ZERO = 0;
const fileOffset_t FILE_OFFSET_UNDEFINED = -1;
const fileOffset_t FILE_OFFSET_MAX = 0x7fffffff;

class OffsetConverter {
public:
	virtual int lineNumber(fileOffset_t f);
};

class MessageLog {
public:
	string	filename;
	OffsetConverter* converter;
	int errorCount;

	MessageLog() : _baseLocation(0) {}

	virtual ~MessageLog();

	fileOffset_t location() const { return _baseLocation; }
	void set_location(fileOffset_t loc) { _baseLocation = loc; }

	void log(const string& msg) { log(_baseLocation, msg); }

	virtual void log(fileOffset_t loc, const string& msg);

	void log(int offset, const string& msg) { log(_baseLocation + offset, msg); }

	void error(const string& msg) { error(_baseLocation, msg); }

	virtual void error(fileOffset_t loc, const string& msg);

	void error(int offset, const string& msg) { error(_baseLocation + offset, msg); }

private:
	fileOffset_t _baseLocation;
};

void setCommandPrefix(const string& command);

}  // namespace script
