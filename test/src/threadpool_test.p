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
import parasol:thread;
//import parasol:thread.ThreadPool;

ThreadPool<int> pool(4);

int value;

assert(value == 0);

pool.execute(f, &value);

thread.sleep(300);

assert(value == 17);

void f(address p) {
	ref<int> pvalue = ref<int>(p);
	*pvalue = 17;
}

private class WorkItem<class T> {
	public ref<WorkItem<T>> next;
	public ref<Future<T>> result;
	public T(address) valueGenerator;
	public address parameter;
}

private monitor class ThreadPoolData<class T> {
	ref<WorkItem<T>> _first;
	ref<WorkItem<T>> _last;
	boolean _shutdownRequested;
}

public class ThreadPool<class T> extends ThreadPoolData<T> {
	ref<thread.Thread>[] _threads;
	
	public ThreadPool(int threadCount) {
		resize(threadCount);
	}
	
	~ThreadPool() {
	}
	
	public void shutdown() {
		lock (*this) {
			while (_first != null) {
				ref<WorkItem<T>> wi = _first;
				_first = wi.next;
				if (wi.result != null)
					wi.result.cancel();
				delete wi;
			}
			_shutdownRequested = true;
			notifyAll();
		}
		for (int i = 0; i < _threads.length(); i++) {
			_threads[i].join();
		}
	}
	
	public ref<Future<T>> execute(T f(address p), address parameter) {
		ref<Future<T>> future = new Future<T>;
		ref<WorkItem<T>> wi = new WorkItem<T>;
		wi.result = future;
		wi.valueGenerator = f;
		wi.parameter = parameter;
		lock (*this) {
			if (_shutdownRequested) {
				delete wi;
				delete future;
				return null;			// Don't do it! It's a trap. (Bug: compiler does not unlock the _workload lock)
			}
			if (_first == null)
				_first = wi;
			else
				_last.next = wi;
			_last = wi;
			notify();
		}
		return future;
	}
	
	public boolean execute(void f(address p), address parameter) {
		ref<WorkItem<T>> wi = new WorkItem<T>;
		wi.result = null;
		wi.valueGenerator = T(address)(f);
		wi.parameter = parameter;
		lock (*this) {
			if (_shutdownRequested) {
				delete wi;
				return false;			// Don't do it! It's a trap. (Bug: compiler does not unlock the _workload lock)
			}
			if (_first == null)
				_first = wi;
			else
				_last.next = wi;
			_last = wi;
			notify();
		}
		return true;
	}
	
	public void resize(int newThreadCount) {
		if (newThreadCount < _threads.length()) {
			assert(false);		// Need to have a way to shut down threads.
		} else {
			while (newThreadCount > _threads.length()) {
				ref<thread.Thread> t = new thread.Thread();
				_threads.append(t);
				t.start(workLoop, this);
			}
		}
	}

	private static void workLoop(address p) {
		ref<ThreadPool<T>> pool = ref<ThreadPool<T>>(p);
		while (pool.getEvent())
			;
	}

	private boolean getEvent() {
		ref<WorkItem<T>> wi;

		lock(*this) {
			if (_shutdownRequested)
				return false;			// Don't do it! It's a trap. (Bug: compiler does not unlock the _workload lock)
			wait();
			if (_shutdownRequested)		// Note: _first will be null
				return false;			// Don't do it! It's a trap. (Bug: compiler does not unlock the _workload lock)
			wi = _first;
			_first = wi.next;
		}
		if (wi.result != null) {
			try {
				if (wi.result.calculating())
					wi.result.post(wi.valueGenerator(wi.parameter));
			} catch (Exception e) {
				wi.result.postFailure(e.clone());
			}
		} else {
			void(address) f = void(address)(wi.valueGenerator);
			f(wi.parameter);
		}
		delete wi;
		return true;
	}
}

public monitor class Future<class T> {
	T _value;
	boolean _calculating;
	boolean _posted;
	boolean _cancelled;
	ref<Exception> _uncaught;
	
	public T get() {
		if (!_posted)
			wait();
		return _value;
	}
	
	public boolean success() {
		if (!_posted)
			wait();
		return !_cancelled && _uncaught == null;
	}
	
	public ref<Exception> uncaught() {
		if (!_posted)
			wait();
		return _uncaught;
	}
	
	public boolean cancelled() {
		if (!_posted)
			wait();
		return _cancelled;
	}
	
	public void post(T value) {
		_value = value;
		_posted = true;
		_calculating = false;
		notifyAll();
	}
	
	public void postFailure(ref<Exception> e) {
		_uncaught = e;
		_posted = true;
		_calculating = false;
		notifyAll();
	}
	
	boolean calculating() {
		if (!_cancelled)
			_calculating = true;
		return _calculating;
	}
	
	public boolean cancel() {
		if (!_posted && !_calculating) {
			_cancelled = true;
			_posted = true;
			notifyAll();
		}
		return _cancelled;
	}
}


