#include "../common/platform.h"
#include "script.h"
#include "internal.h"

namespace script {

string commandPrefix;

void MessageLog::log(fileOffset_t loc, const string& log) {
}

void MessageLog::error(fileOffset_t loc, const string& msg) {
	errorCount++;
}

MessageLog::~MessageLog() {
}

void setCommandPrefix(const string& command) {
	commandPrefix = command;
}

}  // namespace script