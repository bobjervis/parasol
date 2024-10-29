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
import parasol:thread;
import parasol:time;

import parasollanguage.org:debug.manager

Tracer tracer;

class Tracer extends debug.Tracer {
	private Monitor _monitor;
	private ref<TracerWorkItem> _workload;
	private ref<thread.Thread> _tracerThread;				// the 'tracer' of the child processes.
	private boolean _stopTracing;

	Tracer() {}

	~Tracer() {
		if (_tracerThread != null) {
			_stopTracing = true;
			perform(new StopTracing());
			_tracerThread.join();
			delete _tracerThread;
		}
	}

	void perform(ref<TracerWorkItem> item) {
		lock (_monitor) {
//			logger.info("perform tracer = %p", _tracerThread);
			if (_tracerThread == null) {
				_tracerThread = new thread.Thread("tracer");
				_tracerThread.start(processTracer, null);
			}
			item.next = _workload;
			_workload = item;
			_monitor.notify();
		}
	}

	ref<TracerWorkItem> nextItem() {
		lock (_monitor) {
//			logger.info("about to wait in nextItem");
			_monitor.wait();
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
	}

}

private void processTracer(address object) {
	for (;;) {
		w := tracer.nextItem();
		if (w == null)
			break;
		w.run();
		delete w;
	}
}

class Shutdown extends TracerWorkItem {
	boolean _kill;
	ref<TracedProcess> _process;

	Shutdown(ref<TracedProcess> process, boolean kill) {
		_process = process;
		_kill = kill;
	}

	void run() {
		if (_process.state() == manager.ProcessState.EXIT_CALLED) {
			threads := _process.getThreads()
			// Resume all the 'exit_called' threads, if any are pending
			for (i in threads) {
				t := threads[i]
				if (t.state() == manager.ProcessState.EXIT_CALLED)
					t.run()
			}
		}
		if (_kill)
			_process.kill();
		else
			_process.terminate();
	}
}
/**
 * Does nothing, but it does awaken the tracer thread.
 */
private class StopTracing extends TracerWorkItem {
	void run() {
	}
}

class TracerWorkItem {
	ref<TracerWorkItem> next;

	public abstract void run();
}


