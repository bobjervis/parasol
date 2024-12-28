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
import parasol:log
import parasol:net;
import parasol:pbuild
import parasol:process;
import parasol:storage
import parasollanguage.org:debug;

private ref<log.Logger> logger = log.getLogger("manager.sessionState")

class SessionState {
	boolean debugApplication(ref<ParsedScript> parsedScript, ref<Application> application) {
		coordinator := getCoordinator()
		if (coordinator == null) {
			logger.error("Build did not validate")
			return false
		}

		a := coordinator.getApplication(application.application)
		if (a == null) {
			printf("Application %s not found.\n", application.application)
			return false
		}
		if (!a.verify()) {
			printf("Application %s cannot be verified, cannot run it.", application.application)
			return false
		}
		targetPath := a.targetPath()
		buildDir := a.buildDir()
		logger.info("build %s target %s", buildDir, targetPath)

		targetPath = storage.path(buildDir, targetPath)

		exePath := storage.path(targetPath, "parasolrt")
		pxiPath := storage.path(targetPath, "application.pxi")

		cmdLine := process.getCommandLine()
		if (cmdLine.length() < 2) {
			logger.error("Command line incomplete")
			return false
		}
		if (!cmdLine[1].endsWith(".pxi")) {
			logger.error("First argument expected to name a .pxi file")
			return false
		}
		// We're all set to spawn the 'manager' process.
		controller := new process.Process()
		string[] ctrlrArgs
		ctrlrArgs.append(cmdLine[1])
		ctrlrArgs.append("--control=ws://" + net.dottedIP(net.hostIPv4()) + ":" + server.httpPort() + "/proc/control")
		if (parsedScript.environment.size() > 0)
			ctrlrArgs.append(parsedScript.environmentJSON())
		ctrlrArgs.append(exePath)
		ctrlrArgs.append(pxiPath)
		ctrlrArgs.append(application.arguments)
		if (!controller.spawn(cmdLine[0], ctrlrArgs)) {
			logger.error("Spawn of controller sub-process failed");
			return false;
		}
		return true;
	}

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

		parsedScript := validateScript(contents)
		delete reader
		if (parsedScript == null)
			return false
		delete parsedScript
		return true
	}

	ref<ParsedScript> validateScript(string script) {
		var parsedJSON
		boolean ok
		logger.debug("validateScript(\"%s\")", script)
		(parsedJSON, ok) = json.parse(script)
		if (!ok) {
			logger.error("Could not parse script %s as json", script)
			return null
		}
		if (parsedJSON.class != ref<Object>) {
			logger.error("Script body is not a json Object.")
			return null
		}
		object := ref<Object>(parsedJSON)
		string[string] environment
		if (object.contains("environmen")) {
			environmentV := (*object)["environment"]
			if (environmentV.class == ref<Object>) {
				env := ref<Object>(environmentV)
				for (key in *env) {
					value := (*env)[key]
					environment[key] = string(value)
				}
			} else {
				logger.error("The environment field of the script object is not itself a json Object.\n")
				return null
			}
		}
		for (key in environment)
			logger.debug(" [%s] = %s", key, environment[key])

		ref<Application>[] applications
		ref<Array> applicationsArray
		if (object.contains("applications")) {
			applicationsV := (*object)["applications"]
			if (applicationsV.class == ref<Array>)
				applicationsArray = ref<Array>(applicationsV)
			else {
				logger.error("The applications field of the script object is not itself a json Array.")
				return null
			}
		} else {
			logger.error("Script object must contain an applications field.")
			return null
		}

		for (i in *applicationsArray) {
			applicationV := (*applicationsArray)[i]
			if (applicationV.class == ref<Object>) {
				applicationObject := ref<Object>(applicationV)
				
				string[] arguments 
				if (applicationObject.contains("arguments")) {
					argumentsV := (*applicationObject)["arguments"]
					if (argumentsV.class == ref<Array>) {
						args := ref<Array>(argumentsV)
						for (j in *args) {
							argumentV := (*args)[j]
							if (argumentV.class == string)
								arguments.append(string(argumentV))
							else {
								logger.error("Expecting argument %d of entry %d in applications to be a string")
								return null
							}
						}
					} else {
						logger.error("Expecting the arguments in applications entry %d to be an array")
						return null
					}
				}
				if (applicationObject.contains("application")) {
					nameV := (*applicationObject)["application"]
					if (nameV.class == string) {
						name := string(nameV)
						logger.debug("[%d] %s", i, name)
						for (j in arguments)
							logger.debug("    [%d] '%s'", j, arguments[j])
						applications.append(new Application(name, arguments))
					} else {
						logger.error("Expecting application name in entry %d of applications to be a string", i)
						return null
					} 
				} else {
					logger.error("Expecting to see an application field in entry %d of applications", i)
					return null
				}
			}
		}
		logger.info("All validations pass")
		return new ParsedScript(environment, applications)
	}
}

ref<pbuild.Coordinator> getCoordinator() {
	static ref<pbuild.Coordinator> coordinator
	static boolean coordinatorValid = true

	if (!coordinatorValid)
		return null
	if (coordinator == null) {
		pbuild.BuildOptions buildOptions
		buildOptions.setOptionDefaults()

		coordinator = new pbuild.Coordinator(&buildOptions)
		if (!coordinator.validate()) {
			logger.error("FAIL: Errors encountered trying to find and parse build scripts.")
			coordinatorValid = false
			delete coordinator
			coordinator = null
		}
	}
	return coordinator
}


class ParsedScript {
	string[string] environment
	ref<Application>[] applications

	ParsedScript(string[string] environment, ref<Application>... applications) {
		this.environment = environment
		this.applications = applications
	}

	~ParsedScript() {
		applications.deleteAll()
	}

	string environmentJSON() {
		Object o
		for (key in environment)
			o[key] = environment[key]
		var refo = &o
		return json.stringify(refo)
	}
}


class Application {
	string application
	string[] arguments

	Application(string application, string... arguments) {
		this.application = application
		this.arguments = arguments
	}
}

