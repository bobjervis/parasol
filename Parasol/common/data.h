#pragma once
#include "event.h"
#include "string.h"

namespace data {

class Boolean {
public:
	Boolean(bool b);

	Boolean();

	bool value() const { return _value; }

	void set_value(bool b);

	Event changed;

private:
	bool	_value;

};

class Integer {
public:
	Integer(int b);

	Integer();

	int value() const { return _value; }

	void set_value(int v);

	Event changed;

	static bool parse(const string &value, int *result);

private:
	int		_value;
};

}  // namespace data
