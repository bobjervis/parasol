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
