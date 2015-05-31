#pragma once
#define null 0
#include "../common/atom.h"

namespace test {

extern bool listAllTests;		// Set to true to get a printed list of tests that are run.
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
