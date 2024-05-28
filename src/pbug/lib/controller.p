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
namespace parasollanguage.org:debug.controller;

import parasol:http;
import parasol:log;
import parasol:pbuild;
import parasol:process;
import parasol:rpc;
import parasol:storage;
import parasollanguage.org:debug;
import parasollanguage.org:debug.manager;

private ref<log.Logger> logger = log.getLogger("pbug.controller");

public int run(ref<debug.PBugOptions> options, string exePath, string... arguments) {
	printf("controller exePath '%s'\n", exePath);
	for (i in arguments)
		printf("arguments[%d] '%s'\n", i, arguments[i]);
	cmdLine := process.getCommandLine();
	if (cmdLine.length() < 2) {
		printf("Command line incomplete\n");
		return 1;
	}
	if (!cmdLine[1].endsWith(".pxi")) {
		printf("First argument expected to name a .pxi file\n");
		return 1;
	}
	for (i in cmdLine)
		printf("cmdLine[%d] '%s'\n", i, cmdLine[i]);
	if (!connectToManager(options.controlOption.value)) {
		printf("Cannot connect to manager at %s\n", options.controlOption.value);
		return 1;
	}
	if (storage.isDirectory(exePath)) {
		printf("Launching application directory '%s'\n", exePath);
		if (!pbuild.Application.verify(exePath)) {
			printf("Application directory %s cannot be verified, cannot run it.\n", exePath);
			return 1;
		}
		debug.spawnApplication(options.applicationOption.value, exePath, arguments);
	} else if (storage.exists(exePath))
		debug.spawnParasolScript(options.parasolLocationOption.value, exePath, arguments);
	else {
		printf("Not a valid script: %s\n", exePath);
		return 1;
	}
	printf("Controller not yet implemented.\n");
	return 1;
}

boolean connectToManager(string url) {
	rpc.Client<manager.ProcessNotifications, manager.ProcessCommands> client(url, manager.PROCESS_CONTROL_PROTOCOL, processControl);
	client.onDisconnect(processControl);
	printf("Calling connect to manager process control\n");
	if (client.connect() == http.ConnectStatus.OK) {
		printf("manager Connected\n");
		ProcessControl.notifications = client.proxy();
		return true;
	} else {
		printf("manager not connected\n");
		return false;
	}
}

ProcessControl processControl;

class ProcessControl implements manager.ProcessCommands, http.DisconnectListener {
	manager.ProcessNotifications notifications;

	void disconnect(boolean normalClose) {
		logger.debug("ProcessControl upstream disconnect, normal close? %s", string(normalClose));
	}
}


