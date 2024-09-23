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
import parasol:types.map;

import parasollanguage.org:debug;

private ref<log.Logger> logger = log.getLogger("pbug.manager");

ManagedState managedState;

monitor class ManagedState {
	ref<ProcessControl>[] _controllers;
	ref<Session>[] _sessions;
	boolean _shuttingdown;

	// This is the session being debugged.

	class ProcessId {
		int pid;			// Device local process id
		unsigned ip;		// IPv4 address of the host

		public int hash() {
			return int(ip) + (pid << 4);
		}

		public int compare(ProcessId other) {
			if (ip > other.ip)
				return 1;
			if (ip < other.ip)
				return -1;
			return pid - other.pid;
		}
	}

	map<ref<ProcessInfoInternal>, ProcessId> _processes;

	public boolean registerController(ref<ProcessControl> controller) {
		if (_shuttingdown)
			return false;
		logger.info("registerController from %s", net.dottedIP(controller.socket.socket().connection().sourceIPv4()));
		i := _controllers.find(controller);
		if (i >= _controllers.length()) {
			_controllers.append(controller);
		}
		return true;
	}

	public void unregisterController(ref<ProcessControl> controller) {
		i := _controllers.find(controller);
		if (i < _controllers.length()) {
			logger.info("unregisterController from %s%s", net.dottedIP(controller.socket.socket().connection().sourceIPv4()),
					_shuttingdown ? " shutting down" : "");
			_controllers.remove(i);
			if (_shuttingdown && _controllers.length() == 0) {
				logger.info("%d sessions to shut down", _sessions.length());
				for (i in _sessions) {
					session := _sessions[i];
					session.notifications.shutdown();
				}
				notify();
			}
		} else
			logger.warn("Unexpected unregister of controller %p", controller);
	}

	public boolean registerSession(ref<Session> session) {
		if (_shuttingdown)
			return false;
		i := _sessions.find(session);
		if (i >= _sessions.length()) {
			_sessions.append(session);
		}
		return true;
	}

	public void unregisterSession(ref<Session> session) {
		i := _sessions.find(session);
		if (i < _sessions.length()) {
			_sessions.remove(i);
		}
	}

	public ref<ProcessControl>[] shutdown() {
		_shuttingdown = true;
		return _controllers;
	}

	public boolean waitForShutdown() {
		if (_controllers.length() > 0)
			wait();
		return _controllers.length() == 0;
	}

	public void processSpawned(ref<ProcessControl> source, int pid, string label) {
		ps := new ProcessInfoInternal(source, pid, label);
		_processes[{pid: pid, ip: source.socket.socket().connection().sourceIPv4()}] = ps;
	}

	public void afterExec(ref<ProcessControl> source, time.Instant timestamp, int pid) {
		ps := _processes[{pid: pid, ip: source.socket.socket().connection().sourceIPv4()}];
		if (ps != null) {
			ps.state = ProcessState.STOPPED;
			for (i in _sessions) {
				session := _sessions[i];
				session.notifications.afterExec(time.Time(timestamp), *ps);
			}
		} else
			logger.error("afterExec called with unknown pid %d or wrong source", pid);
	}

	public ManagerInfo getInfo() {
		ManagerInfo info;

		info.processCount = _processes.size();
		info.controllerCount = _controllers.length();
		info.sessionCount = _sessions.length();
		return info;
	}

	public ProcessInfo[] getProcesses() {
		ProcessInfo[] info;

		for (i in _processes) {
			p := _processes[i];
			info.append(*p);
		}
		return info;
	}

	public LogInfo[] getLogs(int min, int max) {
		LogInfo[] info;

		return info;
	}
}

class ProcessInfoInternal extends ProcessInfo {
	private ref<ProcessControl> _source;

	ProcessInfoInternal(ref<ProcessControl> source, int pid, string label) {
		this._source = source;
		this.state = ProcessState.RUNNING;
		this.pid = pid;
		this.label = label;
	}

	public boolean spawnedBy(ref<ProcessControl> source) {
		return source == _source;
	}
}
