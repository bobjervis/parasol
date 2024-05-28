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
namespace parasollanguage.org:debug;

import parasol:debug;
import parasol:exception.IllegalOperationException;
import parasol:thread;
import parasol:types.Set;

public Session session;
public debug.Tracer tracer;
	
public interface Notifier {
	void exit(int pid, int exitStatus);

	void initialStop(int pid);

	void initialTrap(int pid);

	void stopped(int pid, int tid, int stopSig);

	void exec(int pid);

	void afterExec(int pid);

	void exitCalled(int pid);

	void killed(int pid, int killSig);

	void newThread(int pid, int tid);
}

monitor class Session {
	ref<TracedProcess>[] _processes;
	Notifier _notifier;
	ref<SessionWorkItem> _workload;
	ref<thread.Thread> _tracer;				// the 'tracer' of the child processes.
	ref<thread.Thread> _events;
	ref<thread.ThreadPool<boolean>> _backgroundTasks;
	boolean _stopTracing;
	boolean _stopEvents;
	Set<int> _stoppedThreads;				// These are a map of thread ids that will probably get a process association soon.	
	map<ref<ThreadInfo>, int> _threadMap;

	Session() {
		_backgroundTasks = new thread.ThreadPool<boolean>(4);
	}

	~Session() {
		logger.info("Session stopping");
		if (_tracer != null) {
			_stopTracing = true;
			perform(new StopTracing());
			_tracer.join();
			delete _tracer;
			logger.info("Tracing stopped");
		}
		if (_events != null) {
			_stopEvents = true;
			_events.interrupt();
			_events.join();
			delete _events;
			logger.info("Events stopped");
		}
		_backgroundTasks.shutdown();
		delete _backgroundTasks;
		logger.info("Background tasks stopped");
	}

	public void listen(Notifier notifier) {
		_notifier = notifier;
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
		if (_events == null) {
			_events = new thread.Thread("events");
			_events.start(eventsHandler, null);
		}
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

	public Notifier notifier() {
		return _notifier;
	}

	public void perform(ref<SessionWorkItem> item) {
		if (_tracer == null) {
			_tracer = new thread.Thread("tracer");
			_tracer.start(processTracer, null);
		}
		item.next = _workload;
		_workload = item;
		notify();
	}

	public ref<SessionWorkItem> nextItem() {
		wait();
		if (_stopTracing) {
			while (_workload != null) {
				w := _workload;
				_workload = w.next;
				delete w;
			}
			return null;
		}
		w := _workload;
		_workload = w.next;
		return w;
	}

	public void cleanupEventsHandler() {
		if (_events != null) {
			id := _events.id();
			_events.join();
			logger.info("events thread id %d collected", id);
		} else
			logger.info("no events thread to collect");
	}

	public boolean stopEvents() {
		return _stopEvents;
	}
}

void processTracer(address unused) {
	for (;;) {
		w := session.nextItem();
		if (w == null)
			break;
		w.run();
		delete w;
	}
}
/**
 * Does nothing, but it does awaken the tracer thread.
 */
class StopTracing extends SessionWorkItem {
	void run() {
	}
}

class SessionWorkItem {
	ref<SessionWorkItem> next;

	public abstract void run();
}
