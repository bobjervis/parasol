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
