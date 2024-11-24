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
/**
 * The controller operates with three primary threads:
 *
 * <ul>
 *		<li>tracer. Spawns/attaches to the process being debugged.
 *		Starts and stops threads, reads and writes data, reads and writes
 *		register values, sends signals and whatever other ptrace related
 *		interactions that demand one thread does all the work.
 *
 *		<li>events. Listens for debugging events from the process
 *		being debugged. State management on this thread execute finite state
 *		machines designed to interact asynchronously with the debuggee.
 *		For example, a process starting up (to be debugged) has to execute
 *		a certain dance of stopping, resuming and stopping again in order
 *		to reach a state where the debugger is ready to let a user interact
 *		with it.
 *
 *		<li>reader. This thread operates inside the rpc facility
 *		to read ProcessControlCommand's from the manager over a Web Socket.
 *		
 * </ul>
 */
namespace parasollanguage.org:debug.controller;

import parasol:http;
import parasol:log;
import parasol:pbuild;
import parasol:process;
import parasol:rpc;
import parasol:storage;
import parasol:time;

import parasollanguage.org:debug;
import parasollanguage.org:debug.manager;

private ref<log.Logger> logger = log.getLogger("pbug.controller");

public ControlState controlState;
ref<Monitor> controllerDone;

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
	controllerDone = new Monitor();
	for (i in cmdLine)
		printf("cmdLine[%d] '%s'\n", i, cmdLine[i]);
	if (!connectToManager(options.controlOption.value)) {
		printf("Cannot connect to manager at %s\n", options.controlOption.value);
		return 1;
	}
	if (storage.isDirectory(exePath)) {
		logger.info("Launching application directory '%s'", exePath);
		if (!pbuild.Application.verify(exePath)) {
			logger.error("Application directory %s cannot be verified, cannot run it.", exePath);
			return 1;
		}
		spawnApplication(options.applicationOption.value, exePath, arguments);
	} else if (storage.exists(exePath))
		spawnParasolScript(options.parasolLocationOption.value, exePath, arguments);
	else {
		printf("Not a valid script: %s\n", exePath);
		return 1;
	}
	controllerDone.wait();
	processControl.notifications.shutdown();
	delete processControl.notifications;
	logger.info("Controller returning normally.");
	return 0;
}

boolean connectToManager(string url) {
	rpc.Client<manager.ProcessNotifications, manager.ProcessCommands> client(url, manager.PROCESS_CONTROL_PROTOCOL, processControl);
	client.onDisconnect(processControl);
	logger.info("Calling connect to manager process control");
	if (client.connect() == http.ConnectStatus.OK) {
		logger.info("manager Connected");
		processControl.notifications = client.proxy();
		controlState.listen(processControl.notifications);
		return true;
	} else {
		logger.error("manager not connected");
		return false;
	}
}

ProcessControl processControl;

class ProcessControl implements manager.ProcessCommands, http.DisconnectListener {
	manager.ProcessNotifications notifications;

	void disconnect(boolean normalClose) {
		logger.debug("ProcessControl downstream disconnect, normal close? %s", string(normalClose));
		controllerDone.notify();
	}

	void shutdown(time.Duration timeout) {
		logger.info("Controller shutdown called with %d processes active", controlState.processCount());
		controlState.shutdown(timeout)
	}

	boolean resumeProcess(int pid) {
		p := controlState.findProcess(pid)
		if (p == null) {
			logger.warn("No process in this controller, pid %d", pid)
			return false
		}
		tracer.perform(new RunProcess(p))
		return true
	}

}

public void spawnApplication(string name, string exePath, string... arguments) {
	tracer.perform(new SpawnApplication(name, exePath, arguments));
}

class SpawnApplication extends TracerWorkItem {
	string _name;
	string _applicationDirectory;
	string[] _args;

	SpawnApplication(string name, string exePath, string... args) {
		_name = name;
		_applicationDirectory = exePath;
		_args = args;
	}

	void run() {
		p := new TracedProcess(_name);
		if (p.spawnApplication(null, _name, _applicationDirectory, process.useParentEnvironment, _args)) {
			logger.info("application %s spawned to id %d", _name, p.id());
			p.addThread(p.id(), time.Instant.now());		// There's always one thread
			controlState.attendTo(p);
		} else {
			logger.error("Could not spawn %s", _name);
			delete p;
		}
	}
}

public void spawnParasolScript(string parasolLocation, string exePath, string... arguments) {
	tracer.perform(new SpawnParasolScript(parasolLocation, exePath, arguments));
}

class SpawnParasolScript extends TracerWorkItem {
	string _script;
	string _parasolLocation;
	string[] _args;
	/**
	 * Note: on Linux, the spawning thread is the tracer of the target process.
	 */
	SpawnParasolScript(string parasolLocation, string script, string... args) {
		_script = script;
		_parasolLocation = parasolLocation;
		_args = args;
	}

	void run() {
		ref<TracedProcess> p;

		p = new TracedProcess(_script);
		if (p.spawnParasolScript(null, _script, _parasolLocation, process.useParentEnvironment, _args)) {
			p.addThread(p.id(), time.Instant.now());		// There's always one thread
			controlState.attendTo(p);
		} else {
			logger.error("Could not spawn %s", _script);
			delete p;
		}
	}
}

class RunProcess extends TracerWorkItem {
	ref<TracedProcess> _process;

	RunProcess(ref<TracedProcess> process) {
		_process = process;
	}

	void run() {
		if (!_process.runAllThreads())
			printf("Process %d cannot be run.\n", _process.id());
	}
}



