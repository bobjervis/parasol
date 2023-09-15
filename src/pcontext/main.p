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
import parasol:json;
import parasol:process;
import parasol:storage;

public int main(string[] args) {
	return pcontextCommand.run(args);
}

PContextCommand pcontextCommand;

class PContextCommand extends process.Command {
	PContextCommand() {
		commandName("pcontext");
		description("This command manages the user's Parasol language " + 
					"contexts. " +
					"It performs many different functions." +
					"");
		finalArguments(1, int.MAX_VALUE, "[ <arguments> ]");
		helpOption('?', "help",
				"Displays this help.");

		subCommand("create", &create);
		subCommand("ls", &ls);
		subCommand("install", &install);
	}

	Create create;
	Ls ls;
	Install install;
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
			return 1;
		}
		if (context.get(args[0]) != null) {
			printf("Context '%s' already exists\n", args[0]);
			return 1;
		}
		if (args.length() == 1) {
			ref<context.Context> ctx = context.create(args[0]);
			if (ctx == null) {
				printf("Could not create context '%s'\n", args[0]);
				return 1;
			}
		} else {	// args.length() == 2
			// If the directory does not exist, make it.
			if (!storage.exists(args[1])) {
				if (!storage.makeDirectory(args[1], false)) {
					printf("Cannot make the database directory '%s', aborting.\n", args[1]);
					return 1;
				}
			} else if (!storage.isDirectory(args[1]) ||
					   !(storage.getUserAccess(args[1]) & storage.AccessFlags.WRITE)) {
				printf("The second argument, if it names and existing file, must name a writable directory, '%s' does not.\n", args[1]);
				return 1;
			}
			ref<context.Context> ctx = context.createFromDirectory(args[0], args[1]);
			if (ctx == null) {
				printf("Could not create context '%s' from directory '%s'\n", args[0], args[1]);
				return 1;
			}
		}
		return 0;
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
		active := context.getActiveContext();

		for (i in contexts) {
			printf("%s %s\n", active == contexts[i] ? "*" : " ", contexts[i].name());
		}

		return 0;
	}
}

class Install extends process.Command {
	Install() {
		finalArguments(1, 1, "<directory>");
		description("Install a package into a context. " + 
					"The named directory must contain a Parasol package. " +
					"");
		contextOption = stringOption('c', "context", "If present, install the package to this context.");
	}

	ref<process.Option<string>> contextOption;

	public int main(string[] args) {
		ref<context.Context> installLocation;
		string installContext;
		if (contextOption.set()) {
			installContext = contextOption.value;
			if (!context.validateContextName(installContext)) {
				printf("The context option must be a validly formatted context name, found '%s'\n", 
							installContext);
				return 1;
			}
			installLocation = context.get(installContext);
		} else {
			installLocation = context.getActiveContext();
			installContext = installLocation.name();
		}
		if (installLocation == null) {
			printf("No context named %s\n", installContext);
			return 1;
		}
		if (!storage.isDirectory(args[0])) {
			printf("Package path '%s' is not a directory.\n", args[0]);
			return 1;
		}
		metadataSlug := storage.path(args[0], "package.json");
		if (!storage.exists(metadataSlug) || storage.isDirectory(metadataSlug)) {
			printf("Package does not a contain a normal file named 'package.json'.\n");
			return 1;
		}
		reader := storage.openTextFile(metadataSlug);
		if (reader == null) {
			printf("Could not open the 'package.json' file in the package directory.\n");
			return 1;
		}
		contents := reader.readAll();
		delete reader;

		var jsonBlob;
		boolean success;
		(jsonBlob, success) = json.parse(contents);
		if (!success) {
			printf("The 'package.json' file does not contain valid JSON.\n");
			return 1;
		}
		if (jsonBlob.class != ref<Object>) {
			printf("The 'package.json' file does not contain a JSON Object.\n");
			return 1;
		}
		object := ref<Object>(jsonBlob);
		name := getStringField(object, "name");
		if (name == null)
			return 1;
		version := getStringField(object, "version");
		if (version == null)
			return 1;
		pkg := installLocation.getPackage(name);
		if (pkg != null) {
			printf("The package already exists.\n");
		} else {
			printf("This is a new package.\n");
		}
		printf("Installing package %s version %s to context %s\n", name, version, installLocation.name());
		return 0;
	}

	static string getStringField(ref<Object> object, string field) {
		if (!object.contains(field)) {
			printf("The 'package.json' object does not contain a field named '%s'.\n", field);
			return null;
		}
		var nameV = object.get(field);
		if (nameV.class != string) {
			printf("The 'package.json' %s field is not a string.\n", field);
			return null;
		}
		return string(nameV);
	}
}
