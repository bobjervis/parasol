/*
   Copyright 2015 Robert Jervis

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

#include "dictionary.h"
#include "string.h"
#include "vector.h"

namespace commandLine {

enum ArgumentClass {
	AC_STRING,
	AC_BOOLEAN,
	AC_HELP
};

class Command;

class BaseArgument {
	friend class Command;
public:
	BaseArgument(ArgumentClass argumentClass, char shortOption, const char *longOption, const char *helpText);

	int compare(const BaseArgument *other) const;

	ArgumentClass argumentClass() { return _argumentClass; }

	const char *helpText() { return _helpText; }

	char shortOption() { return _shortOption; }

	bool set() { return _set; }

	const char *longOption() { return _longOption; }
protected:
	void setValue(const string &value);

private:
	ArgumentClass _argumentClass;
	const char *_helpText;
	char _shortOption;
	const char *_longOption;
	bool _set;
};

template<class T>
class Argument : public BaseArgument {
	friend class BaseArgument;
public:
	Argument(ArgumentClass argumentClass, char shortOption, const char *longOption, const char *helpText) : BaseArgument(argumentClass, shortOption, longOption, helpText) {
		memset(&_value, 0, sizeof _value);
	}

	T value() { return _value; }

private:
	T _value;
};

class Command {
public:
	Command();

	void finalArguments(int min, int max, const char *helpText);

	void description(const char *helpText);

	Argument<string> *stringArgument(char shortOption, const char *longOption, const char *helpText);

	Argument<bool> *booleanArgument(char shortOption, const char *longOption, const char *helpText);

	bool helpArgument(char shortOption, const char *longOption, const char *helpText);

	bool parse(int argc, char **argv);

	int finalArgc() { return _finalArgc; }

	char **finalArgv() { return _finalArgv; }

	const char *command() { return _command; }

	void help();		// Does not return

private:
	bool defineOption(char shortOption, const char *longOption, BaseArgument *arg);

	dictionary<BaseArgument*> _shortOptions;
	dictionary<BaseArgument*> _longOptions;
	int _finalMin;
	int _finalMax;
	const char *_finalArgumentsHelpText;
	const char *_description;
	int _finalArgc;
	char **_finalArgv;
	const char *_command;
	Argument<bool> *_helpArgument;
	vector<BaseArgument *> _allArguments;
};

} // namespace commandLine
