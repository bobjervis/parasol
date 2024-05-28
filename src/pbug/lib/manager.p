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

import parasol:http;
import parasol:log;
import parasol:net;
import parasol:process;
import parasol:rpc;
import parasollanguage.org:debug;

private ref<log.Logger> logger = log.getLogger("pbug.manager");

/**
 * Run the manager role of the debugger.
 *
 * The architecture of the pbug debugger requires at least three processes:
 *
 *<ul>
 *	<li>A UI proces. 
 *		This translates user input into commands sent to the manager.
 *		This also accepts notifications from the manager.
 *		The UI is intended to give the user the information they need to debug
 *		an issue.
 *	<li>A Manager process. 
 *		This accepts commands and queries from the UI and sends notifications to it.
 *		This also issues commandds to controller instances and receives notifications
 *		from them.
 *		The manager maintains a global data structure describing the environment
 *		being debugger, from a single process running a simple script, to a dynamic
 *		collection of processes running across a network of machines.
 *	<li>One or more Controller processes.
 *		These accept commands from the manager, interact with the process being debugged
 *		and sends notifications to the manager.
 *		The controller is generally stateless. It monitors the process and handles messages.
 *</ul>
 *
 * The Manager, once launched, remains active indefinitely.
 * The Controller's are designed to monitor process activity and detect forks and execs to
 * ensure that a coherent multi-process 'state' is always available to the manager.
 *
 * The Manager itself consists of an HTTP Server hosting HTTPS connections to both controller's
 * and UI processes. These services use Parasol interfaces define the interactions.
 */
public int run(ref<debug.PBugOptions> options, string exePath, string... arguments) {
	printf("manager exePath '%s'\n", exePath);
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
	if (options.applicationOption.set()) {
		if (!sessionState.debugApplication(options, exePath, arguments)) {
			printf("Could not debug application %s\n", options.applicationOption.value);
			return 1;
		}
	} else {
		printf("Controller only debugs applications\n");
		return 1;
	}
	printf("Manager port %d\n", options.managerOption.value);
	server := new http.Server();
	server.disableHttp();
	server.setHttpsPort(char(options.managerOption.value));
	processControl.webSocketProtocol(PROCESS_CONTROL_PROTOCOL, new ProcessControlFactory());
	session.webSocketProtocol("Session", new SessionFactory());
	server.httpsService("/proc/control", &processControl);
	server.httpsService("/session", &session);
	server.start(net.ServerScope.INTERNET);
	server.wait();
	return 0;
}

http.WebSocketService processControl;
http.WebSocketService session;

SessionState sessionState;

class ProcessControlFactory extends rpc.WebSocketFactory<ProcessNotifications, ProcessCommands> {
	public boolean notifyCreation(ref<http.Request> request, 
								  ref<rpc.WebSocket<ProcessNotifications, ProcessCommands>> socket) {
		ref<ProcessControl> s = new ProcessControl(socket);
		socket.setObject(s);
		socket.onDisconnect(s);
		return true;
	}
}

class ProcessControl implements ProcessNotifications, http.DisconnectListener {
	ref<rpc.WebSocket<ProcessNotifications, ProcessCommands>> socket;

	ProcessControl(ref<rpc.WebSocket<ProcessNotifications, ProcessCommands>> socket) {
		this.socket = socket;
	}

	void disconnect(boolean normalClose) {
		logger.debug("ProcessControl upstream disconnect, normal close? %s", string(normalClose));
	}
}

class SessionFactory extends rpc.WebSocketFactory<SessionNotifications, SessionCommands> {
	public boolean notifyCreation(ref<http.Request> request, 
								  ref<rpc.WebSocket<SessionNotifications, SessionCommands>> socket) {
		ref<Session> s = new Session(socket);
		socket.setObject(s);
		socket.onDisconnect(s);
		return true;
	}
}

class Session implements SessionNotifications, http.DisconnectListener {
	ref<rpc.WebSocket<SessionNotifications, SessionCommands>> socket;

	Session(ref<rpc.WebSocket<SessionNotifications, SessionCommands>> socket) {
		this.socket = socket;
	}

	void disconnect(boolean normalClose) {
		logger.debug("upstream disconnect, normal close? %s", string(normalClose));
	}
}

