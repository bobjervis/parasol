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
namespace parasollanguage.org:debug.manager;

import parasol:json
import parasol:net;
import parasol:process;
import parasol:storage
import parasollanguage.org:debug;

class SessionState {

	boolean debugApplication(ref<debug.PBugOptions> options, string exePath, string... arguments) {
		cmdLine := process.getCommandLine();
		if (cmdLine.length() < 2) {
			printf("Command line incomplete\n");
			return false;
		}
		if (!cmdLine[1].endsWith(".pxi")) {
			printf("First argument expected to name a .pxi file\n");
			return false;
		}
		// We're all set to spawn the 'manager' process.
		controller := new process.Process();
		string[] ctrlrArgs;
		ctrlrArgs.append(cmdLine[1]);
		ctrlrArgs.append("-c");
		ctrlrArgs.append("ws://" + net.dottedIP(net.hostIPv4()) + ":" + string(options.managerOption.value) + "/proc/control");
		ctrlrArgs.append(options.copiedOptions());
		if (arguments.length() > 0 && arguments[0].length() > 0 && arguments[0][0] == '-')
			ctrlrArgs.append("--")
		ctrlrArgs.append(arguments)
		if (!controller.spawn(cmdLine[0], ctrlrArgs)) {
			printf("Spawn of controller sub-process failed\n");
			return false;
		}
		return true;
	}

	boolean debugScript(ref<debug.PBugOptions> options, string scriptPath, string... arguments) {
		reader := storage.openTextFile(scriptPath)
		contents := reader.readAll()
		delete reader
		var parsedScript
		boolean ok
		(parsedScript, ok) = json.parse(contents)
		if (!ok) {
			printf("Could not parse script file %s as json\n", scriptPath)
			return false
		}
		if (parsedScript.class != ref<Object>) {
			printf("Script body is not a json Object.\n")
			return false;
		}
		object := ref<Object>(parsedScript)
		environment := process.environment.fetch()
		if (object.contains("environmen")) {
			environmentV := (*object)["environment"]
			if (environmentV.class == ref<Object>) {
				env := ref<Object>(environmentV)
				for (key in *env) {
					value := (*env)[key]
					if (value == null)
						environment.remove(key)
					else
						(*environment)[key] = string(value)
				}
			} else {
				printf("The environment field of the script object is not itself a json Object.\n")
				return false
			}
		}
		for (key in *environment)
			printf(" [%s] = %s\n", key, (*environment)[key])

		ref<Array> applications
		if (object.contains("applications")) {
			applicationsV := (*object)["applications"]
			if (applicationsV.class == ref<Array>)
				applications = ref<Array>(applicationsV)
			else {
				printf("The applications field of the script object is not itself a json Array.\n")
				return false
			}
		} else {
			printf("Script object must contain an applications field.\n")
			return false
		}

		for (i in *applications) {
			applicationV := (*applications)[i]
			if (applicationV.class == ref<Object>) {
				application := ref<Object>(applicationV)
				
				string[] arguments 
				if (application.contains("arguments")) {
					argumentsV := (*application)["arguments"]
					if (argumentsV.class == ref<Array>) {
						args := ref<Array>(argumentsV)
						for (j in *args) {
							argumentV := (*args)[i]
							if (argumentV.class == string)
								arguments.append(string(argumentV))
							else {
								printf("Expecting argument %d of entry %d in applications to be a string\n")
								return false
							}
						}
					} else {
						printf("Expecting the arguments in applications entry %d to be an array\n")
						return false
					}
				}
				if (application.contains("application")) {
					nameV := (*application)["application"]
					if (nameV.class == string) {
						name := string(nameV)
						printf("[%d] %s\n", i, name)
						for (j in arguments)
							printf("    [%d] '%s'\n", j, arguments[j])
							
					} else {
						printf("Expecting application name in entry %d of applications to be a string\n", i)
						return false;
					} 
				} else {
					printf("Expecting to see an application field in entry %d of applications\n", i)
					return false
				}
			}
		}
		printf("All validations pass\n");
		return false
	}

	boolean validateScript(string script) {
		var parsedScript
		boolean ok
		(parsedScript, ok) = json.parse(script)
		if (!ok) {
			printf("Could not parse script %s as json\n", script)
			return false
		}
		if (parsedScript.class != ref<Object>) {
			printf("Script body is not a json Object.\n")
			return false;
		}
		object := ref<Object>(parsedScript)
		environment := process.environment.fetch()
		if (object.contains("environmen")) {
			environmentV := (*object)["environment"]
			if (environmentV.class == ref<Object>) {
				env := ref<Object>(environmentV)
				for (key in *env) {
					value := (*env)[key]
					if (value == null)
						environment.remove(key)
					else
						(*environment)[key] = string(value)
				}
			} else {
				printf("The environment field of the script object is not itself a json Object.\n")
				return false
			}
		}
		for (key in *environment)
			printf(" [%s] = %s\n", key, (*environment)[key])

		ref<Array> applications
		if (object.contains("applications")) {
			applicationsV := (*object)["applications"]
			if (applicationsV.class == ref<Array>)
				applications = ref<Array>(applicationsV)
			else {
				printf("The applications field of the script object is not itself a json Array.\n")
				return false
			}
		} else {
			printf("Script object must contain an applications field.\n")
			return false
		}

		for (i in *applications) {
			applicationV := (*applications)[i]
			if (applicationV.class == ref<Object>) {
				application := ref<Object>(applicationV)
				
				string[] arguments 
				if (application.contains("arguments")) {
					argumentsV := (*application)["arguments"]
					if (argumentsV.class == ref<Array>) {
						args := ref<Array>(argumentsV)
						for (j in *args) {
							argumentV := (*args)[i]
							if (argumentV.class == string)
								arguments.append(string(argumentV))
							else {
								printf("Expecting argument %d of entry %d in applications to be a string\n")
								return false
							}
						}
					} else {
						printf("Expecting the arguments in applications entry %d to be an array\n")
						return false
					}
				}
				if (application.contains("application")) {
					nameV := (*application)["application"]
					if (nameV.class == string) {
						name := string(nameV)
						printf("[%d] %s\n", i, name)
						for (j in arguments)
							printf("    [%d] '%s'\n", j, arguments[j])
							
					} else {
						printf("Expecting application name in entry %d of applications to be a string\n", i)
						return false;
					} 
				} else {
					printf("Expecting to see an application field in entry %d of applications\n", i)
					return false
				}
			}
		}
		printf("All validations pass\n");
		return true
	}
}

