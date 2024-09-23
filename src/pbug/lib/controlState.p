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

import parasol:debug;
import parasol:exception.IllegalOperationException;
import parasol:thread;
import parasol:types.Set;
import parasollanguage.org:debug.manager;

monitor class ControlState {
	ref<TracedProcess>[] _processes;
	manager.ProcessNotifications _notifier;
	ref<thread.ThreadPool<boolean>> _backgroundTasks;
	Set<int> _stoppedThreads;				// These are a map of thread ids that will probably get a process association soon.	
	map<ref<ThreadInfo>, int> _threadMap;

	ControlState() {
		_backgroundTasks = new thread.ThreadPool<boolean>(4);
	}

	~ControlState() {
		_backgroundTasks.shutdown();
		delete _backgroundTasks;
	}

	public void listen(manager.ProcessNotifications notifier) {
		_notifier = notifier;
		for (i in _processes) {
			p := _processes[i];
			_notifier.processSpawned(p.launchedAt(), p.id(), p.label());
		}
	}

	public void threadStopped(int tid) {
		if (_stoppedThreads.contains(tid)) {
			logger.warn("Detected a second stop on an unassociated thread (%d), how did that happen?", tid);
			return;
		}
		_stoppedThreads.add(tid);
	}
	/**
	 * Checks to see if we've booked a stray thread stop.
	 *
	 * This is called from the new-thread event handler once it's gotten onto the tracer thread.
	 *
	 * @param tid The thread id of the new thread being registered.
	 *
	 * @return true if there was a thread with this id in the pending list, false otherwise. Note that
	 * the pending thread, if found, will be removed. This informs the debugger that the new thread shold be marked as stopped.
	 */
	public boolean pullStoppedThread(int tid) {
		if (_stoppedThreads.contains(tid)) {
			_stoppedThreads.remove(tid);
			return true;
		} else
			return false;
	}

	public void attendTo(ref<TracedProcess> p) {
		_processes.append(p);
		if (_notifier != null)
			_notifier.processSpawned(p.launchedAt(), p.id(), p.label());
		events.listen();
	}

	public void declareThread(ref<ThreadInfo> t) {
		existing := _threadMap[t.tid()];
		if (existing != null) {
			if (existing != t)
				logger.error("Trying to declare tid %d, but map shows a different value", t.tid());
			return;
		}
		_threadMap[t.tid()] = t;
	}

	public ref<ThreadInfo> findThread(int tid) {
		return _threadMap[tid];
	}

	public int processCount() {
		return _processes.length();
	}

	public ref<TracedProcess> getProcess(int index) {
		if (index < _processes.length())
			return _processes[index];
		else
			return null;
	}

	public boolean removeProcess(ref<TracedProcess> process) {
		for (i in _processes) {
			if (_processes[i] == process) {
				_processes.remove(i);
				if (_processes.length() == 0)
					controllerDone.notify();
				return true;
			}
		}
		return false;
	}

	public manager.ProcessNotifications notifier() {
		return _notifier;
	}
}

