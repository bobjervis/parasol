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
namespace parasol:process;

import native:C;

public class Command {
	ref<BaseArgument>[string] _shortOptions;
	ref<BaseArgument>[string] _longOptions;
	int _finalMin;
	int _finalMax;
	string _finalArgumentsHelpText;
	string _description;
	string[] _finalArgs;
	ref<Argument<boolean>> _helpArgument;
	ref<BaseArgument>[] _allArguments;

	~Command() {
		for (a in _allArguments)
			if (_allArguments[a].argumentClass() == ArgumentClass.STRING)
				ref<Argument<string>>(_allArguments[a]).value = null;
		_allArguments.deleteAll();
	}

	public void finalArguments(int min, int max, string helpText) {
		_finalMin = min;
		_finalMax = max;
		_finalArgumentsHelpText = helpText;
	}

	public void description(string helpText) {
		_description = helpText;
	}

	public ref<Argument<int>> integerArgument(string longOption, string helpText) {
		return integerArgument(0, longOption, helpText);
	}
	
	public ref<Argument<int>> integerArgument(char shortOption, string longOption, string helpText) {
		ref<Argument<int>> arg = new Argument<int>(ArgumentClass.INTEGER, shortOption, longOption, helpText);
		if (defineOption(shortOption, longOption, arg))
			return arg;
		else {
			delete arg;
			return null;
		}
	}
	
	public ref<Argument<string>> stringArgument(string longOption, string helpText) {
		return stringArgument(0, longOption, helpText);
	}
	
	public ref<Argument<string>> stringArgument(char shortOption, string longOption, string helpText) {
		ref<Argument<string>> arg = new Argument<string>(ArgumentClass.STRING, shortOption, longOption, helpText);
		if (defineOption(shortOption, longOption, arg))
			return arg;
		else {
			delete arg;
			return null;
		}
	}

	public ref<Argument<boolean>> booleanArgument(string longOption, string helpText) {
		return booleanArgument(0, longOption, helpText);
	}
	
	public ref<Argument<boolean>> booleanArgument(char shortOption, string longOption, string helpText) {
		ref<Argument<boolean>> arg = new Argument<boolean>(ArgumentClass.BOOLEAN, shortOption, longOption, helpText);
		if (defineOption(shortOption, longOption, arg))
			return arg;
		else {
			delete arg;
			return null;
		}
	}

	public boolean helpArgument(string longOption, string helpText) {
		return helpArgument(0, longOption, helpText);
	}

	public boolean helpArgument(char shortOption, string longOption, string helpText) {
		if (_helpArgument != null)
			return false;
		ref<Argument<boolean>> arg = new Argument<boolean>(ArgumentClass.HELP, shortOption, longOption, helpText);
		if (defineOption(shortOption, longOption, arg)) {
			_helpArgument = arg;
			return true;
		} else
			return false;
	}

	public boolean parse(string[] args) {
		int i;
		for (i = 0; i < args.length(); i++) {
			if (args[i][0] == '-') {
				if (args[i][1] == '-') {
					// -- argument forces transition to final arguments.
					if (args[i][2] == 0) {
						i++;
						break;
					}
					// --X long argument, might be --X=Y or just --X
					int equals = args[i].indexOf('=', 2);
					string key;
					string value;
					if (equals >= 0) {
						key = args[i].substr(2, equals);
						value = args[i].substr(equals + 1);
					} else
						key = args[i].substr(2);
					ref<BaseArgument> b = _longOptions[key];
					if (b == null) {
						printf("Unknown argument: %s\n", key);
						return false;
					}
					if (!b.setValue(value)) {
						printf("Argument format incorrect: %s\n", args[i]);
						return false;
					}
				} else if (args[i].length() > 1) {
					// -xyz short option, might be -x val
					pointer<byte> argument = &args[i][1];
					while (*argument != 0) {
						string key;
						key.append(argument, 1);
						argument++;
						ref<BaseArgument> b = _shortOptions[key];
						if (b == null) {
							printf("Unknown argument: %s\n", key);
							return false;
						}
						switch (b.argumentClass()) {
						case BOOLEAN:
						case HELP:
							b.setValue("true");
							break;
							
						case STRING:
						case INTEGER:
							string value;
							int lastI = i;

							if (*argument != 0) {
								value = string(argument);
								argument = &""[0];
							} else if (i < args.length() - 1) {
								value = string(args[i + 1]);
								lastI = i + 1;
							} else {
								printf("Argument %s requires a value\n", key);
								return false;
							}
							if (!b.setValue(value)) {
								printf("Argument format incorrect: %s %s\n", args[i]);
								return false;
							}
							i = lastI;
						}
					}
				}
			} else
				break;
		}
//		_finalArgs = args[i..args.length()];
		_finalArgs.slice(args, i, args.length());
		if (_helpArgument != null && _helpArgument.value)
			help();
		return _finalArgs.length() >= _finalMin && _finalArgs.length() <= _finalMax;
	}

	public string[] finalArgs() { 
		return _finalArgs; 
	}

	public void help() {		// Does not return
//		CONSOLE_SCREEN_BUFFER_INFO screenBuffer;

		int lineLength = 80;
		int indent = 22;
/*
		if (GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &screenBuffer)) {
			lineLength = screenBuffer.dwSize.X - 1;
			if (lineLength < 60)
				indent = lineLength / 3;
		}
 */
 		printf("Use is: ");
 		string prototype = binaryFilename();
 		
		if (_allArguments.length() > 0)
			prototype.append(" [options]");
		if (_finalArgumentsHelpText != null) {
			prototype.append(" ");
			prototype.append(_finalArgumentsHelpText);
		}
		wrapTo(8, 8, lineLength, prototype);
		if (_allArguments.length() > 0) {
			printf("\nOptions:\n");
			// TODO: Fix this somehow - sort doesn't like this array.
//			_allArguments.sort();
			for (int i = 0; i < _allArguments.length(); i++) {
				printf("    ");
				if (_allArguments[i].shortOption() != 0)
					printf("-%c", _allArguments[i].shortOption());
				else
					printf("  ");
				printf("  ");
				int alreadyPrinted;
				if (_allArguments[i].longOption() != null) {
					printf("--%s", _allArguments[i].longOption());
					alreadyPrinted = 10 + _allArguments[i].longOption().length();
				} else
					alreadyPrinted = 8;
				if (alreadyPrinted >= indent) {
					printf("\n");
					alreadyPrinted = 0;
				}
				wrapTo(alreadyPrinted, indent, lineLength, _allArguments[i].helpText());
			}
			printf("\n");
		}
		if (_description != null)
			wrapTo(0, 0, lineLength, _description);
		exit(1);
	}

	private boolean defineOption(char shortOption, string longOption, ref<BaseArgument> arg) {
		_allArguments.append(arg);
		if (shortOption != 0) {
			string s;
			s.append(shortOption);
			if (_shortOptions[s] == null)
				_shortOptions[s] = arg;
			else
				return false;
		}
		if (longOption != null) {
			if (_longOptions[longOption] == null)
				_longOptions[longOption] = arg;
			else
				return false;
		}
		return true;
	}

};

public class Argument<class T> extends BaseArgument {
	public T value;
	
	public Argument(ArgumentClass argumentClass, char shortOption, string longOption, string helpText) {
		super(argumentClass, shortOption, longOption, helpText);
		C.memset(pointer<byte>(&value), 0, value.bytes);
	}

};

class BaseArgument {
	private ArgumentClass _argumentClass;
	private string _helpText;
	private char _shortOption;
	private string _longOption;
	private boolean _set;

	public BaseArgument(ArgumentClass argumentClass, char shortOption, string longOption, string helpText) {
		_argumentClass = argumentClass;
		_shortOption = shortOption;
		_longOption = longOption;
		_helpText = helpText;
	}

	public int compare(ref<BaseArgument> other)  {
		if (_longOption != null) {
			if (other._longOption == null)
				return 1;
			int result = _longOption.compare(other._longOption);
			if (result != 0)
				return result;
		} else if (other._longOption != null)
			return -1;
		return other._shortOption - _shortOption;
	}

	public ArgumentClass argumentClass() { 
		return _argumentClass; 
	}

	public string helpText() { 
		return _helpText; 
	}

	public char shortOption() { 
		return _shortOption; 
	}

	public boolean set() { 
		return _set; 
	}

	public string longOption() { 
		return _longOption; 
	}

	boolean setValue(string value) {
		switch (_argumentClass) {
		case	STRING:
			ref<Argument<string>>(this).value = value;
			break;
			
		case	INTEGER:
			ref<Argument<int>> iarg = ref<Argument<int>>(this);
			int v;
			boolean success;
			
			(v, success) = int.parse(value);
			
			if (success)
				iarg.value = v;
			else
				return false;
			break;
			
		case	BOOLEAN:
		case	HELP:
			ref<Argument<boolean>> arg = ref<Argument<boolean>>(this);
			if (value == "false")
				arg.value = false;
			else
				arg.value = true;
			break;
		}
		_set = true;
		return true;
	}

};

enum ArgumentClass {
	STRING,
	BOOLEAN,
	INTEGER,
	HELP
};

private void newLine(int indent, int newLineCount) {
	for (int i = 0; i < newLineCount; i++)
		printf("\n");
	if (indent > 0)
		printf("%*.*c", indent, indent, ' ');
}

private void wrapTo(int alreadyPrinted, int indent, int lineLength, string textString) {
	if (textString != null) {
		lineLength -= indent;
		if (alreadyPrinted < indent) {
			printf("%*.*c", indent - alreadyPrinted, indent - alreadyPrinted, ' ');
			alreadyPrinted = 0;
		}
		pointer<byte> text = textString.c_str();
		while (*text != 0) {
			pointer<byte> cp = text;
			while (*cp != 0 && !(*cp).isSpace())
				cp++;
			int wordLength = int(cp - text);
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
				while ((*text).isSpace()) {
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
	}
	printf("\n");
}
