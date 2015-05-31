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
#include "data.h"

namespace data {

Boolean::Boolean(bool b) {
	_value = b;
}

Boolean::Boolean() {
	_value = false;
}

void Boolean::set_value(bool v) {
	_value = v;
	changed.fire();
}

Integer::Integer(int b) {
	_value = b;
}

Integer::Integer() {
	_value = 0;
}

void Integer::set_value(int v) {
	_value = v;
	changed.fire();
}

bool Integer::parse(const string &value, int *result) {
	const char* start = value.c_str();
	char* endPtr;
	if (*start == 0)
		return false;
	*result = strtol(start, &endPtr, 10);
	if (*endPtr != 0)
		return false;
	return true;
}

}  // namespace data
