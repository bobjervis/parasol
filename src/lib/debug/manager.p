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
import parasol:time;

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
 *		being debugged, from a single process running a simple script, to a dynamic
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
 * and UI processes. These services use Parasol interfaces to define the interactions.
 */
public int run(ref<debug.PBugOptions> options, string exePath, string... arguments) {
	if (options.scriptOption.set()) {
		printf("script option: %s\n", options.scriptOption.value)
		if (!sessionState.debugScript(options, options.scriptOption.value, arguments)) {
			printf("Could not initialize script %s\n", options.scriptOption.value);
			return 1;
		}
	} else {
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
	}
	printf("Manager port %d\n", options.managerOption.value);
	server = new http.Server();
	server.disableHttps();
	server.setHttpPort(char(options.managerOption.value));
	processControlService.webSocketProtocol(PROCESS_CONTROL_PROTOCOL, new ProcessControlFactory());
	sessionService.webSocketProtocol(SESSION_PROTOCOL, new SessionFactory());
	server.httpService("/proc/control", &processControlService);
	server.httpService("/session", &sessionService);
	server.start(net.ServerScope.INTERNET);
	server.wait();
	logger.info("HTTP server shut down");
	managedState.disconnectFromSessions();
	logger.info("Manager returning normally.");
	return 0;
}

http.WebSocketService processControlService;
http.WebSocketService sessionService;

ref<http.Server> server;

SessionState sessionState;

class ProcessControlFactory extends rpc.WebSocketFactory<ProcessNotifications, ProcessCommands> {
	public boolean notifyCreation(ref<http.Request> request, 
								  ref<rpc.WebSocket<ProcessNotifications, ProcessCommands>> socket) {
		ref<ProcessControl> s = new ProcessControl(socket);
		socket.setObject(s);
		socket.onDisconnect(s);
		return managedState.registerController(s);
	}
}

class ProcessControl implements ProcessNotifications, http.DisconnectListener {
	ref<rpc.WebSocket<ProcessNotifications, ProcessCommands>> socket;
	ProcessCommands commands;

	ProcessControl(ref<rpc.WebSocket<ProcessNotifications, ProcessCommands>> socket) {
		this.socket = socket;
		this.commands = socket.proxy();
	}

	void disconnect(boolean normalClose) {
		logger.debug("ProcessNotifications upstream disconnect, normal close? %s", string(normalClose));
		managedState.unregisterController(this);
	}
	/**
	 * Notify manager of controller shutdown.
	 */
	void shutdown() {
//		managedState.unregisterController(this);
		logger.info("=== ProcessControl === shutdown");
	}

	void processSpawned(time.Instant timestamp, int pid, string label) {
		logger.info("=== ProcessControl === Process %d '%s' spawned", pid, label);
		managedState.processSpawned(this, timestamp, pid, label);
	}

	void exit(time.Instant timestamp, int pid, int tid, int exitStatus) {
		logger.info("=== ProcessControl === Process %d Thread %d exited %d", pid, tid, exitStatus);
		managedState.exit(this, timestamp, pid, tid, exitStatus)
	}

	void initialStop(time.Instant timestamp, int pid) {
		logger.info("=== ProcessControl === Process %d initial stop", pid);
	}

	void initialTrap(time.Instant timestamp, int pid) {
		logger.info("=== ProcessControl === Process %d initial trap", pid);
	}

	void stopped(time.Instant timestamp, int pid, int tid, int stopSig) {
		logger.info("=== ProcessControl === Process %d thread %d stopped %d", pid, tid, stopSig);
		managedState.stopped(this, timestamp, pid, tid, stopSig)
	}

	void exec(time.Instant timestamp, int pid) {
		logger.info("=== ProcessControl === Process %d exec", pid);
	}

	void afterExec(time.Instant timestamp, int pid) {
		logger.info("=== ProcessControl === Process %d after exec", pid);
		managedState.afterExec(this, timestamp, pid);
	}

	void exitCalled(time.Instant timestamp, int pid, int tid, int exitStatus) {
		logger.info("=== ProcessControl === Process %d thread %d exit called with status %d", pid, tid, exitStatus);
		managedState.exitCalled(this, timestamp, pid, tid, exitStatus);
	}

	void killed(time.Instant timestamp, int pid, int killSig) {
		logger.info("=== ProcessControl === Process %d killed %d", pid, killSig);
		managedState.processKilled(this, timestamp, pid, killSig)
	}

	void newThread(time.Instant timestamp, int pid, int tid) {
		logger.info("=== ProcessControl === Process %d new thread %d", pid, tid);
		managedState.newThread(this, timestamp, pid, tid)
	}
}

class SessionFactory extends rpc.WebSocketFactory<SessionCommands, SessionNotifications> {
	public boolean notifyCreation(ref<http.Request> request, 
								  ref<rpc.WebSocket<SessionCommands, SessionNotifications>> socket) {
		ref<Session> s = new Session(socket);
		if (!managedState.registerSession(s)) {
			delete s;
			return false;
		}
		socket.setObject(s);
		socket.onDisconnect(s);
		return true;
	}
}

monitor class SessionVolatileData {
	int _references

	SessionVolatileData() {
		_references = 1
	}

	void addRef() {
		_references++
	}

	protected boolean lockedRelease() {
		_references--
		return _references == 0
	}
}

class Session extends SessionVolatileData implements SessionCommands, http.DisconnectListener {
	ref<rpc.WebSocket<SessionCommands, SessionNotifications>> socket;
	SessionNotifications notifications;

	Session(ref<rpc.WebSocket<SessionCommands, SessionNotifications>> socket) {
		this.socket = socket;
		this.notifications = socket.proxy();
	}

	void disconnect(boolean normalClose) {
		logger.debug("SessionCommands upstream disconnect, normal close? %s", string(normalClose));
	}

	boolean shutdown(time.Duration timeout) {
		// First get a stabilized list of sessions and notify them all that the manager is shutting down.
		sessions := managedState.sessions()
		for (i in sessions) {
			session := sessions[i]
			session.notifications.shutdownInitiated()
		}
		controllers := managedState.shutdown();
		logger.info("shutdown called with timeout(%d,%d) and %d controllers", timeout.seconds(), timeout.nanoseconds(), controllers.length());
		for (i in controllers) {
			controller := controllers[i];
			controller.commands.shutdown(timeout);
		}
		result := managedState.waitForShutdown();
		logger.info("manager waited for shutdown %s", result);
		if (result) {
			logger.info("http server stop initiating")
			server.stop();
			logger.info("http server stopped")
		}
		return result;
	}

	ManagerInfo getManagerInfo() {
		return managedState.getInfo();
	}

	ProcessInfo[] getProcesses() {
		return managedState.getProcesses();
	}

	LogInfo[] getLogs(int min, int max) {
		return managedState.getLogs(min, max);
	}

	ThreadInfo[], boolean getThreads(int pid, unsigned ip) {
		ThreadInfo[] info

		p := managedState.getProcess(pid, ip)
		if (p == null) {
			logger.warn("no process matched pid %d ip %s", pid, net.dottedIP(ip))
			return info, false
		}
		info = managedState.getThreads(p)
		logger.info("threads recorded for pid %d ip %s", pid, net.dottedIP(ip))
		return info, true
	}

	boolean resumeProcess(int pid, unsigned ip) {
		// TODO: stabilize this object, add a ref count
		// obtain this under a lock
		p := managedState.getProcess(pid, ip)
		if (p == null) {
			logger.warn("no process matched pid %d ip %s", pid, net.dottedIP(ip))
			return false
		}
		return p.source().commands.resumeProcess(p.pid)
	}
}

void shutdownSequence(address args) {
}


