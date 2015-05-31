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
