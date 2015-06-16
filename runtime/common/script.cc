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
