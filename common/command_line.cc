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
#include "command_line.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include "windows.h"

namespace commandLine {

Command::Command() {
	_finalMin = 0;
	_finalMax = 0;
	_finalArgumentsHelpText = null;
	_description = null;
	_finalArgc = 0;
	_finalArgv = null;
	_command = null;
	_helpArgument = null;
}

void Command::finalArguments(int min, int max, const char *helpText) {
	_finalMin = min;
	_finalMax = max;
	_finalArgumentsHelpText = helpText;
}

void Command::description(const char *helpText) {
	_description = helpText;
}

Argument<string> *Command::stringArgument(char shortOption, const char *longOption, const char *helpText) {
	Argument<string> *arg = new Argument<string>(AC_STRING, shortOption, longOption, helpText);
	if (defineOption(shortOption, longOption, arg))
		return arg;
	else
		return null;
}

Argument<bool> *Command::booleanArgument(char shortOption, const char *longOption, const char *helpText) {
	Argument<bool> *arg = new Argument<bool>(AC_BOOLEAN, shortOption, longOption, helpText);
	if (defineOption(shortOption, longOption, arg))
		return arg;
	else
		return null;
}

bool Command::helpArgument(char shortOption, const char *longOption, const char *helpText) {
	if (_helpArgument)
		return false;
	Argument<bool> *arg = new Argument<bool>(AC_HELP, shortOption, longOption, helpText);
	if (defineOption(shortOption, longOption, arg)) {
		_helpArgument = arg;
		return true;
	} else
		return false;
}

bool Command::defineOption(char shortOption, const char *longOption, BaseArgument *arg) {
	_allArguments.push_back(arg);
	if (shortOption) {
		string s;
		s.append(&shortOption, 1);
		if (!_shortOptions.put(s, arg))
			return false;
	}
	if (longOption) {
		if (!_longOptions.put(longOption, arg))
			return false;
	}
	return true;
}

bool Command::parse(int argc, char **argv) {
	_command = argv[0];
	int i;
	for (i = 1; i < argc; i++) {
		if (argv[i][0] == '-') {
			if (argv[i][1] == '-') {
				// -- argument forces transition to final arguments.
				if (argv[i][2] == 0)
					break;
				// --X long argument, might be --X=Y or just --X
				const char *argument = argv[i] + 2;
				const char *equals = strchr(argument, '=');
				string key;
				string value;
				if (equals != null) {
					key = string(argument, equals - argument);
					value = string(equals + 1);
				} else
					key = string(argument);
				BaseArgument **b = _longOptions.get(key);
				if (*b == null) {
					printf("Unknown argument: %s\n", key.c_str());
					return false;
				}
				(*b)->setValue(value);
			} else if (argv[i][1]) {
				// -xyz short option, might be -x val
				const char *argument = argv[i] + 1;
				while (*argument) {
					string key;
					key.append(argument, 1);
					argument++;
					BaseArgument **b = _shortOptions.get(key);
					if (*b == null) {
						printf("Unknown argument: %s\n", key.c_str());
						return false;
					}
					string value;
					if ((*b)->argumentClass() == AC_STRING) {
						if (*argument) {
							value = string(argument);
							argument = "";
						} else if (i < argc - 1) {
							value = string(argv[i + 1]);
							i++;
						}
					}
					(*b)->setValue(value);
				}
			}
		} else
			break;
	}
	_finalArgv = argv + i;
	_finalArgc = argc - i;
	if (_helpArgument && _helpArgument->value())
		help();
	return _finalArgc >= _finalMin && _finalArgc <= _finalMax;
}

static void newLine(int indent, int newLineCount) {
	for (int i = 0; i < newLineCount; i++)
		printf("\n");
	if (indent > 0)
		printf("%*c", indent, ' ');
}

static void wrapTo(int alreadyPrinted, int indent, int lineLength, const char *text) {
	lineLength -= indent;
	if (alreadyPrinted < indent) {
		printf("%*c", indent - alreadyPrinted, ' ');
		alreadyPrinted = 0;
	}
	while (*text) {
		const char *cp = text;
		while (*cp && !isspace(*cp))
			cp++;
		int wordLength = cp - text;
		if (alreadyPrinted > 0) {
			if (alreadyPrinted + wordLength + 1 > lineLength) {
				newLine(indent, 1);
				printf("%*.*s", wordLength, wordLength, text);
				alreadyPrinted = wordLength;
				text += wordLength;
			} else {
				printf(" %*.*s", wordLength, wordLength, text);
				alreadyPrinted += wordLength + 1;
				text += wordLength;
			}
		} else {
			printf("%*.*s", wordLength, wordLength, text);
			alreadyPrinted += wordLength;
			text += wordLength;
		}
		if (*text == '\n') {
			text++;
			newLine(indent, 2);
			alreadyPrinted = 0;
		} else if (*text == '\r') {
			text++;
			newLine(indent, 1);
			alreadyPrinted = 0;
		} else {
			while (isspace(*text)) {
				if (*text == '\n') {
					newLine(indent, 2);
					alreadyPrinted = 0;
				} else if (*text == '\r') {
					text++;
					newLine(indent, 1);
					alreadyPrinted = 0;
				}
				text++;
			}
		}
	}
	printf("\n");
}

void Command::help() {
	CONSOLE_SCREEN_BUFFER_INFO screenBuffer;

	int lineLength = 80;
	int indent = 22;
	if (GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &screenBuffer)) {
		lineLength = screenBuffer.dwSize.X - 1;
		if (lineLength < 60)
			indent = lineLength / 3;
	}
	printf("Use is: %s", _command);
	if (_allArguments.size() > 0) {
		printf(" [options]");
	}
	if (_finalArgumentsHelpText)
		wrapTo(8 + strlen(_command), lineLength / 4, lineLength, _finalArgumentsHelpText);
	else
		printf("\n");
	if (_allArguments.size() > 0) {
		printf("\nOptions:\n");
		_allArguments.sort();
		for (int i = 0; i < _allArguments.size(); i++) {
			printf("    ");
			if (_allArguments[i]->shortOption())
				printf("-%c", _allArguments[i]->shortOption());
			else
				printf("  ");
			printf("  ");
			int alreadyPrinted;
			if (_allArguments[i]->longOption()) {
				printf("--%s", _allArguments[i]->longOption());
				alreadyPrinted = 10 + strlen(_allArguments[i]->longOption());
			} else
				alreadyPrinted = 8;
			if (alreadyPrinted >= indent) {
				printf("\n");
				alreadyPrinted = 0;
			}
			wrapTo(alreadyPrinted, indent, lineLength, _allArguments[i]->helpText());
		}
		printf("\n");
	}
	if (_description)
		wrapTo(0, 0, lineLength, _description);
	exit(1);
}

BaseArgument::BaseArgument(ArgumentClass argumentClass, char shortOption, const char *longOption, const char *helpText) {
	_argumentClass = argumentClass;
	_shortOption = shortOption;
	_longOption = longOption;
	_helpText = helpText;
	_set = false;
}

void BaseArgument::setValue(const string &value) {
	switch (_argumentClass) {
	case	AC_STRING: {
		Argument<string> *arg = (Argument<string>*)this;
		arg->_value = value;
	}break;
	case	AC_BOOLEAN:
	case	AC_HELP: {
		Argument<bool> *arg = (Argument<bool>*)this;
		if (value == "false")
			arg->_value = false;
		else
			arg->_value = true;
	}break;
	}
	_set = true;
}

int BaseArgument::compare(const BaseArgument *other) const {
	if (_longOption) {
		if (other->_longOption == null)
			return 1;
		int result = strcmp(_longOption, other->_longOption);
		if (result != 0)
			return result;
	} else if (other->_longOption)
		return -1;
	return other->_shortOption - _shortOption;
}

} // namespace commandLine
