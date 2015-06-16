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
#define null 0
#include "../common/atom.h"

namespace test {
/*
 *	launch
 *
 *	The app is being started as a test runner.
 *	Depending on the contents of the scripts being
 *	specified, this may trigger unit tests, whole
 *	app tests, or whatever.
 */
int launch(int argc, char** argv);
/*
 *	run
 *
 *	This entry point is called instead of the
 *	display::loop method when the app initializes.
 *	Tests will use this flag to initialize the
 *	the whole app as we want, then switch here
 *	to run whatever test procedure has been selected.
 */
void run();

template<class T>
bool deepCompare(T* a, T* b) {
	if (a == null)
		return b == null;
	else if (b == null)
		return false;
	else
		return a->equals(b);
}

class RepeatObject : script::Object {
public:
	static script::Object* factory();

	RepeatObject() {}

	virtual bool isRunnable() const;

	virtual bool validate(script::Parser* parser);

	virtual bool run();

	int count() const { return _count;}
private:
	int		_count;
};

}  // namespace test
