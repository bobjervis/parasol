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
import native:linux

import parasollanguage.org:debug;

private ref<log.Logger> logger = log.getLogger("pbug.manager");

ManagedState managedState;

monitor class ManagedState {
	ref<ProcessControl>[] _controllers;
	ref<Session>[] _sessions;
	boolean _shuttingdown;
	ref<LogInfo>[] _logs;

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
			if (_shuttingdown && _controllers.length() == 0)
				notify();
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

	public ref<Session>[] sessions() {
		ref<Session>[] result

		for (i in _sessions) {
			session := _sessions[i]
			session.addRef()
			result.append(session)
		}
		return result
	}

	public ref<ProcessControl>[] shutdown() {
		_shuttingdown = true;
		return _controllers;
	}

	public boolean waitForShutdown() {
		if (_controllers.length() > 0) {
			logger.info("manager waiting for shutdown");
			wait();
		}
		return _controllers.length() == 0;
	}

	public void disconnectFromSessions() {
		logger.info("%d sessions to shut down", _sessions.length());
		for (i in _sessions) {
			session := _sessions[i];
			session.notifications.shutdown();
		}
//		for (i in _sessions)
//			delete _sessions[i].notifications
		_sessions.clear()
	}

	public void processSpawned(ref<ProcessControl> source, time.Instant timestamp, int pid, string label) {
		ps := new ProcessInfoInternal(source, pid, label);
		_processes[{pid: pid, ip: source.socket.socket().connection().sourceIPv4()}] = ps;
		log(timestamp, "process pid %d spawned '%s'", pid, label)
	}

	public void stopped(ref<ProcessControl> source, time.Instant timestamp, int pid, int tid, int stopSig) {
		ps := _processes[{pid: pid, ip: source.socket.socket().connection().sourceIPv4()}];
		if (ps != null) {
			t := ps.getThread(tid)
			if (t != null) {
				t.state = ProcessState.STOPPED
				t.stopSig = stopSig
				for (i in _sessions) {
					session := _sessions[i]
					session.notifications.stopped(time.Time(timestamp), *ps, tid, stopSig)
				}
			} else
				logger.error("Could not find thread %d", tid)
		}
	}
	
	public void afterExec(ref<ProcessControl> source, time.Instant timestamp, int pid) {
		ps := _processes[{pid: pid, ip: source.socket.socket().connection().sourceIPv4()}];
		if (ps != null) {
			ps.state = ProcessState.STOPPED;
			t := ps.getThread(pid)
			if (t != null) {
				t.state = ProcessState.STOPPED
				t.stopSig = linux.SIGSTOP
			} else
				logger.error("Could not find thread %d", pid)
			for (i in _sessions) {
				session := _sessions[i];
				session.notifications.afterExec(time.Time(timestamp), *ps);
			}
			log(timestamp, "after exec pid %d state %s", pid, string(ps.state))
		} else
			logger.error("afterExec called with unknown pid %d or wrong source", pid);
	}

	public void exitCalled(ref<ProcessControl> source, time.Instant timestamp, int pid, int tid, int exitStatus) {
		ps := _processes[{pid: pid, ip: source.socket.socket().connection().sourceIPv4()}];
		if (ps != null) {
			ps.state = ProcessState.EXIT_CALLED;
			for (i in _sessions) {
				session := _sessions[i];
				session.notifications.exitCalled(time.Time(timestamp), *ps, tid, exitStatus);
			}
			log(timestamp, "exit called pid %d tid %d exit status %d", pid, tid, exitStatus)
		} else
			logger.error("afterExec called with unknown pid %d or wrong source", pid);
	}

	public void processKilled(ref<ProcessControl> source, time.Instant timestamp, int pid, int killSig) {
		ps := _processes[{pid: pid, ip: source.socket.socket().connection().sourceIPv4()}];
		if (ps != null) {
			ps.state = ProcessState.EXITED;
			for (i in _sessions) {
				session := _sessions[i];
				logger.info("sending session %d kill notification for %d", i, pid)
				session.notifications.killed(time.Time(timestamp), *ps, killSig);
				logger.info("session %d replied", i);
			}
		} else
			logger.error("afterExec called with unknown pid %d or wrong source", pid);
	}

	public void newThread(ref<ProcessControl> source, time.Instant timestamp, int pid, int tid) {
		log(timestamp, "new thread pid %d tid %d", pid, tid)
		p := getProcess(pid, source.socket.socket().connection().sourceIPv4())
		if (p == null) {
			logger.error("newThread found no process for pid %d", pid)
			return
		}
		p.newThread(tid)
	}


	public void exit(ref<ProcessControl> source, time.Instant timestamp, int pid, int tid, int exitStatus) {
		log(timestamp, "thread exit pid %d tid %d status %d", pid, tid, exitStatus)
	}

	public ManagerInfo getInfo() {
		ManagerInfo info;

		info.processCount = _processes.size();
		info.controllerCount = _controllers.length();
		info.sessionCount = _sessions.length();
		info.logsCount = _logs.length();
		return info;
	}

	public ProcessInfo[] getProcesses() {
		ProcessInfo[] info;

		for (i in _processes) {
			p := _processes[i];
			logger.info("get %d at %s (%s) state %s", p.pid, net.dottedIP(p.ip), p.label, string(p.state))
			p.exitStatus = -73
			info.append(*p);
		}
		return info;
	}
	
	public ThreadInfo[] getThreads(ref<ProcessInfoInternal> p) {
		return p.getThreads()
	}

	public LogInfo[] getLogs(int min, int max) {
		LogInfo[] info

		if (min > max || min >= _logs.length())
			return info
		if (max > _logs.length())
			max = _logs.length()
		info.resize(max - min)
		for (int i = min; i < max; i++) {
			li := *_logs[i]
			info[i - min] = li
		}
		return info
	}

	private void log(time.Instant at, string format, var... args) {
		string message
		message.printf(format, args)
		li := new LogInfo
		li.timestamp = at
		li.message = message
		_logs.append(li)
	}

	public boolean shuttingdown() {
		return _shuttingdown
	}

	public ref<ProcessInfoInternal> getProcess(int pid, unsigned ip) {
		if (pid == 0) {
			if (ip == 0) {
				if (_processes.size() == 1) {
					// use an iterator to find the one process without knowing it's identity
					for (i in _processes)
						return _processes[i]
				}
			}
		}
		return _processes[{pid: pid, ip: ip}]
	}
}

class ProcessInfoInternal extends ProcessInfo {
	private ref<ProcessControl> _source;
	private ref<ThreadInfoInternal>[] _threads;

	ProcessInfoInternal(ref<ProcessControl> source, int pid, string label) {
		this._source = source;
		this.state = ProcessState.RUNNING;
		this.pid = pid;
		this.label = label;
		this._threads.append(new ThreadInfoInternal(pid, ProcessState.RUNNING))
		logger.info("new %d (%s)", pid, label)
	}

	public boolean spawnedBy(ref<ProcessControl> source) {
		return source == _source;
	}

	public ref<ProcessControl> source() {
		return _source
	}
	
	public ThreadInfo[] getThreads() {
		ThreadInfo[] info
		
		for (i in _threads)
			info.append(*_threads[i])
		return info
	}
	
	public void newThread(int tid) {
		t := new ThreadInfoInternal(tid, ProcessState.RUNNING)
		logger.info("thread added at %d: %d", _threads.length(), tid)
		_threads.append(t)
	}
	
	public ref<ThreadInfoInternal> getThread(int tid) {
		for (i in _threads) {
			t := _threads[i]
			if (t.tid == tid)
				return t
		}
		return null
	}
}

class ThreadInfoInternal extends ThreadInfo {
	ThreadInfoInternal(int tid, ProcessState state) {
		this.tid = tid
		this.state = state
	}	
}
 
