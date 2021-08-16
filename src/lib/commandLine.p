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

import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;
import native:C;
/**
 * Provide command-line parsing.
 *
 * Currently, the Parasol command-line parsing logic follows UNIX/Linux
 * conventions. Support for Windows-conforming command parsing is not
 * supported.
 *
 * The supported command-line syntax is based on the POSIX standard for
 * command-line arguments. Check <a href="http://www.eg.bucknell.edu/~mead/Java-tutorial/essential/attributes/_posix.html">here</a>
 * for a description of the syntax.
 *
 * The general form of a UNIX/Linux command line is as follows:
 *
 * <pre>
 *            <i><b>command-name</b> options arguments</i>
 * </pre>
 *
 * The <b><i>command-name</i></b> is parsed by the operating system's command processor
 * and it cannot be readily determined, especially the way Parasol programs are launched.
 *
 * Options can be defined with either or both of two forms: short and long.
 *
 * The short form of an option uses a single alphanumeric character, case-sensitive and
 * is preceded by a single dash, as in {@code -c -l -r}. Non-boolean options take arguments.
 * These must follow the option letter with optional white-space between, as in {@code -o <i>argument</i>}
 * or {@code -o<i>argument</i>}.
 *
 * Boolean short form arguments can be combined, thus {@code -c -l -r} and {@code -clr} are equivalent.
 *
 * The long form of an option starts with two dashes and is followed by a string of alphanumric
 * and dash characters. Non-boolean options use an equal sign and no white space to denote the
 * argument, as in {@code --port=5004}.
 *
 * An argument consisting of two dashes alone ({@code\--}) denotes the end of options. Otherwise,
 * the first argument that does not begin with a dash ends the interpretation of options.
 *
 * Most options may only appear once. However, a command can specify that ann option may appear
 * more than once by declaring it as a multi-string option.
 *
 * <h3>Sub-commands.</h3>
 *
 * More complex commands, such as git, use a scheme of sub-commands.
 *
 * <pre>
 *            <i><b>command-name</b> options sub-command sub-command-options arguments</i>
 * </pre>
 *
 * In this scheme, the first argument after the options is the sub-command. This starts a new
 * list of options specific to that sub-command.
 *
 * <h3>Use of {@code run} versus {@code parse}</h3>
 *
 * The {@link run} method interprets the command-line options and if the command-line is well-formed, calls the {@link main} method
 * with the final arguments to the command (after all options and any sub-commands). If the command-line is not well formed, the {@link run}
 * method calls the {@link help} method and terminates the program.
 *
 * The {@link parse} method is available to process simple commands or provide more control over the program's behavior. The parse
 * method allow you to decide how to respond to parsing errors. You can inspect the completed Command object to identify the selected
 * sub-command and obtain the final argument list.
 */
public class Command {
	ref<Command> _baseCommand;
	string _commandName;
	ref<BaseArgument>[string] _shortOptions;
	ref<BaseArgument>[string] _longOptions;
	int _finalMin;
	int _finalMax;
	string _finalArgumentsHelpText;
	string _description;
	string[] _finalArgs;
	ref<Argument<boolean>> _helpArgument;
	ref<BaseArgument>[] _allArguments;
	ref<Command>[string] _subCommands;
	ref<Command> _defaultSubCommand;

	ref<Command> _selectedSubCommand;

	~Command() {
		for (a in _allArguments)
			if (_allArguments[a].argumentClass() == ArgumentClass.STRING)
				ref<Argument<string>>(_allArguments[a]).value = null;
		_allArguments.deleteAll();
	}

	public void commandName(string name) {
		_commandName = name;
	}

	public void finalArguments(int min, int max, string helpText) {
		_finalMin = min;
		_finalMax = max;
		_finalArgumentsHelpText = helpText;
	}

	public void description(string helpText) {
		_description = helpText;
	}
	/**
	 * Define a sub-command of this command.
	 *
	 * In general, the command line has options (starting with a dash)
	 * followed by zero or more arguments that are processed by the command.
	 *
	 * A command can define 
	 */
	public void subCommand(string name, ref<Command> command) {
		if (name == null) {
			if (_defaultSubCommand != null)
				throw IllegalArgumentException("duplicate default subCommand");
			_defaultSubCommand = command;
		} else {
			if (_subCommands.contains(name))
				throw IllegalArgumentException("duplicate subCommand: " + name);
			_subCommands[name] = command;
			command.commandName(name);
			command._baseCommand = this;
		}
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

	public int run(string[] args) {
		if (!parse(args))
			help();
		return runParsed();
	}

	public int main(string[] args) {
		throw IllegalOperationException("did not override main");
	}

	private int runParsed() {
		if (_selectedSubCommand != null)
			return _selectedSubCommand.runParsed();
		else
			return main(_finalArgs);
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
		if (_subCommands.size() > 0 || _defaultSubCommand != null) {
			if (i >= args.length())
				return false;
			ref<Command> c = _subCommands[args[i]];
			if (c == null)
				c = _defaultSubCommand;
			if (c == null)
				return false;
			_selectedSubCommand = c;
			_finalArgs.slice(args, i + 1, args.length());
			if (!c.parse(_finalArgs))
				return false;
			if (_helpArgument != null && _helpArgument.value)
				help();
			return true;
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

	public ref<Command> selectedSubCommand() {
		return _selectedSubCommand;
	}

	public void help() {		// Does not return
//		CONSOLE_SCREEN_BUFFER_INFO screenBuffer;

		int lineLength = 80;
/*
		if (GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &screenBuffer)) {
			lineLength = screenBuffer.dwSize.X - 1;
		}
 */
 		printf("Use is: ");
		helpDetails(lineLength, 0, 8, 8);
		exit(1);
	}

	private string prototype() {
 		string prototype = _commandName != null ? _commandName : binaryFilename();
 		
		if (_allArguments.length() > 0)
			prototype.append(" [options]");
		if (_subCommands.size() > 0 || _defaultSubCommand != null)
			prototype.append(" <sub-command>");
		if (_finalArgumentsHelpText != null) {
			prototype.append(" ");
			prototype.append(_finalArgumentsHelpText);
		}
		return prototype;
	}

	private static int commandComparator(ref<Command> left, ref<Command> right) {
		return left._commandName.compare(right._commandName);
	}

	private void helpDetails(int lineLength, int inset, int alreadyPrinted, int prototypeIndent) {
		wrapTo(alreadyPrinted, prototypeIndent, lineLength, prototype());

		int indent = 22;
		if (lineLength < 60)
			indent = lineLength / 3;
		indent += inset;
		if (_allArguments.length() > 0) {
			printf("\n");
			wrapTo(0, inset, lineLength, "Options:");
			// TODO: Fix this somehow - sort doesn't like this array.
			_allArguments.sort(BaseArgument.comparator, true);
			for (int i = 0; i < _allArguments.length(); i++) {
				string option;

				if (_allArguments[i].shortOption() != 0)
					option.printf("-%c", _allArguments[i].shortOption());
				else
					option.printf("  ");
				option.printf("  ");
				if (_allArguments[i].longOption() != null) {
					option.printf("--%s", _allArguments[i].longOption());
				}
				printf("%*.*c%s", inset + 4, inset + 4, ' ', option);
				int alreadyPrinted = inset + 4 + option.length();
				if (option.length() + inset + 5 >= indent) {
					printf("\n");
					alreadyPrinted = 0;
				}
				wrapTo(alreadyPrinted, indent, lineLength, _allArguments[i].helpText());
			}
		}
		if (_description != null) {
			printf("\n");
			wrapTo(0, inset, lineLength, _description);
		}
		if (_subCommands.size() > 0) {
			ref<Command>[] list;

			for (name  in _subCommands)
				list.append(_subCommands[name]);
			list.sort(commandComparator, true);

			printf("\n");
			wrapTo(0, inset, lineLength, "Sub-commands:");
			for (i in list) {
				printf("\n");
				list[i].helpDetails(lineLength, inset + 6, 0, inset + 3);
			}
		}

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

	public static int comparator(ref<BaseArgument> left, ref<BaseArgument> right)  {
		if (left._longOption != null) {
			if (right._longOption == null)
				return 1;
			int result = left._longOption.compare(right._longOption);
			if (result != 0)
				return result;
		} else if (right._longOption != null)
			return -1;
		return right._shortOption - left._shortOption;
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
