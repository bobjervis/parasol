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
import parasol:context;
import parasol:process;
import parasol:storage;

public int main(string[] args) {
	return pcontextCommand.run(args);
}

PContextCommand pcontextCommand;

class PContextCommand extends process.Command {
	PContextCommand() {
		commandName("pcontext");
		description("This is command inspects or updates the user's Parasol language." + 
					"contexts. " +
					"It performs many different functions." +
					"");
		finalArguments(1, int.MAX_VALUE, "[ <arguments> ]");
		helpOption('?', "help",
				"Displays this help.");

		subCommand("create", &create);
		subCommand("ls", &ls);
	}

	Create create;
	Ls ls;
}

class Create extends process.Command {
	Create() {
		finalArguments(1, 2, "<context-name> ( <path> | <url> )");
		description("Create or define a new context. " + 
					"If no path or url are given, then a new context database is created. " +
					"If a path to an existing, readable directory is supplied, it must be a " +
					"context database, or a copy of one. " +
					"The named directory will be used to hold any newly installed packages " +
					"or other updated information. " +
					"If a path to a directory that can be created is given, but does not exist, the " +
					"directory is created. " +
					"");
	}

	public int main(string[] args) {
		if (!context.validateContextName(args[0])) {
			printf("The first argument must be a validly formatted context name, found '%s'\n", args[0]);
			return 0;
		}
		if (context.get(args[0]) != null) {
			printf("Context '%s' already exists\n", args[0]);
			return 0;
		}
		if (args.length() == 1) {
			ref<context.Context> ctx = context.create(args[0]);
			if (ctx == null) {
				printf("Could not create context '%s'\n", args[0]);
				return 0;
			}
		} else {	// args.length() == 2
			// If the directory does not exist, make it.
			if (!storage.exists(args[1])) {
				if (!storage.makeDirectory(args[1], false)) {
					printf("Cannot make the database directory '%s', aborting.\n", args[1]);
					return 0;
				}
			} else if (!storage.isDirectory(args[1]) ||
					   !(storage.getUserAccess(args[1]) & storage.AccessFlags.WRITE)) {
				printf("The second argument, if it names and existing file, must name a writable directory, '%s' does not.\n", args[1]);
				return 0;
			}
			ref<context.Context> ctx = context.createFromDirectory(args[0], args[1]);
			if (ctx == null) {
				printf("Could not create context '%s' from directory '%s'\n", args[0], args[1]);
				return 0;
			}
		}
		return 1;
	}
}

class Ls extends process.Command {
	Ls() {
		finalArguments(0, 0, "");
		description("List all contexts." + 
					"");
	}

	public int main(string[] args) {
		ref<context.Context>[] contexts = context.listAll();

		for (i in contexts) {
			printf("%s\n", contexts[i].name());
		}

		return 1;
	}
}

