/*
   Copyright 2015 Rovert Jervis

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
namespace parasol:thread;

import native:windows.GetCurrentThreadId;
import native:windows.CloseHandle;
import native:windows.CreateSemaphore;
import native:windows.ReleaseSemaphore;
import native:windows.CreateMutex;
import native:windows.ReleaseMutex;
import native:windows.WaitForSingleObject;
import native:windows._beginthreadex;
import native:windows.HANDLE;
import native:windows.INVALID_HANDLE_VALUE;
import native:windows.DWORD;
import native:windows.BOOL;
import native:windows.SIZE_T;
import native:windows.WAIT_FAILED;
import native:windows.WAIT_TIMEOUT;
import native:windows.INFINITE;
import native:windows.GetLastError;
import parasol:exception.HardwareException;

public class Thread {
	private string _name;
	private HANDLE _threadHandle;
	private void(address a) _function;
	private address _parameter;
	private address _context;
	
	public Thread() {
		_name.printf("TID-%d", GetCurrentThreadId());
		_threadHandle = INVALID_HANDLE_VALUE;
	}
	
	public Thread(string name) {
		if (name != null)
			_name = name;
		else
			_name.printf("TID-%d", GetCurrentThreadId());
		_threadHandle = INVALID_HANDLE_VALUE;
	}
	
	~Thread() {
		if (_threadHandle.isValid())
			CloseHandle(_threadHandle);
	}
	
	public boolean start(void func(address p), address parameter) {
		_function = func;
		_parameter = parameter;
		_context = dupExecutionContext();
		address x = _beginthreadex(null, 0, wrapperFunction, this, 0, null);
		_threadHandle = *ref<HANDLE>(&x);
		return _threadHandle.isValid();
	}
	/**
	 * This is a wrapper function that sets up the environment, but for reasons that are not all that great,
	 * the stack walker doesn't like to see the try/catch in the same method as the 'stackTop' variable, which is &t.
	 */
	private static unsigned wrapperFunction(address wrapperParameter) {
		ref<Thread> t = ref<Thread>(wrapperParameter);
		enterThread(t._context, &t);
		nested(t);
		exitThread();
		return 0;
	}
	/**
	 * This provides a default exception handler for threads. See above for an explanation as to why this can't be in the
	 * same function as above.
	 */
	private static void nested(ref<Thread> t) {
		try {
			t._function(t._parameter);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public void join() {
		DWORD dw = WaitForSingleObject(_threadHandle, INFINITE);
		if (dw == WAIT_FAILED) {
			printf("WaitForSingleObject failed %x\n", GetLastError());
		}
		CloseHandle(_threadHandle);
		_threadHandle = INVALID_HANDLE_VALUE;
	}
	
	public string name() {
		return _name;
	}
}
/*
 * This is the runtime implementation class for the monitor feature. It supplies the public methods that are
 * implied in a declared monitor object.
 */
class Monitor {
	private Mutex _mutex;
	private HANDLE	_semaphore;
	private int _waiting;
	
	public Monitor() {
		_semaphore = HANDLE(CreateSemaphore(null, 0, int.MAX_VALUE, null));
	}
	
	~Monitor() {
		CloseHandle(_semaphore);
	}
	
	private void take() {
		_mutex.take();
	}
	
	private void release() {
		_mutex.release();
	}
	
	public void notify() {
		_mutex.take();
		ReleaseSemaphore(_semaphore, 1, null);
		--_waiting;
		_mutex.release();
	}
	
	public void notifyAll() {
		_mutex.take();
		if (_waiting > 0) {
			ReleaseSemaphore(_semaphore, _waiting, null);
			_waiting = 0;
		}
		_mutex.release();
	}
	
	public void wait() {
		_mutex.take();
		_waiting++;
		int level = _mutex.releaseForWait();
		WaitForSingleObject(_semaphore, INFINITE);
		_mutex.takeAfterWait(level - 1);
	}
	
	public void wait(long timeout) {
		long upper = timeout >> 31;
		int lower = int(timeout & ((long(1) << 31) - 1));
		_mutex.take();
		_waiting++;
		int level = _mutex.releaseForWait();
		DWORD outcome = WaitForSingleObject(_semaphore, DWORD(lower));
		if (outcome == WAIT_TIMEOUT) {
			for (int i = 0; i < upper; i++) {
				outcome = WaitForSingleObject(_semaphore, DWORD(int.MAX_VALUE));
				if (outcome != WAIT_TIMEOUT)
					break;
			}
		}
		_mutex.takeAfterWait(level - 1);
	}
	// Sorry, Windows doesn't support nano second timing on semaphores.
	public void wait(long timeout, int nanos) {
		long upper = timeout >> 31;
		int lower = int(timeout & ((long(1) << 31) - 1));
		_mutex.take();
		_waiting++;
		int level = _mutex.releaseForWait();
		DWORD outcome = WaitForSingleObject(_semaphore, DWORD(lower));
		if (outcome == WAIT_TIMEOUT) {
			for (int i = 0; i < upper; i++) {
				outcome = WaitForSingleObject(_semaphore, DWORD(int.MAX_VALUE));
				if (outcome != WAIT_TIMEOUT)
					break;
			}
		}
		_mutex.takeAfterWait(level - 1);
	}
}

class Mutex {
	private int _level;
	private HANDLE _mutex;
	private DWORD _ownerThreadId;
	
	public Mutex() {
		_mutex = HANDLE(CreateMutex(null, 0, null));
	}
	
	~Mutex() {
		CloseHandle(_mutex);
	}
	
	void take() {
		WaitForSingleObject(_mutex, INFINITE);
		DWORD currentThreadId = GetCurrentThreadId(); 
		if (_ownerThreadId == currentThreadId) {
			_level++;
		} else {
			_level = 1;
			_ownerThreadId = currentThreadId;
		}
	}
	
	void release() {
		_level--;
		ReleaseMutex(_mutex);
	}
	
	int releaseForWait() {
		int priorLevel = _level;
		while (_level > 0) {
			_level--;
			ReleaseMutex(_mutex);
		}
		return priorLevel;
	}
	
	void takeAfterWait(int level) {
		for (int i = 0; i < level; i++)
			take();
	}
}

private class WorkItem<class T> {
	public ref<WorkItem<T>> next;
	public ref<Future<T>> result;
	public T(address p) func;
	public address parameter;
}

public class ThreadPool<class T> {
	private monitor _workload {
		ref<WorkItem<T>> _first;
		ref<WorkItem<T>> _last;
		boolean _shutdownRequested;
	}
	
	ref<Thread>[] _threads;
	
	public ThreadPool(int threadCount) {
		resize(threadCount);
	}
	
	~ThreadPool() {
	}
	
	public void shutdown() {
		lock (_workload) {
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
		wi.func = f;
		wi.parameter = parameter;
		lock (_workload) {
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
		wi.func = T(address p)(f);
		wi.parameter = parameter;
		lock (_workload) {
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
				ref<Thread> t = new Thread();
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

		lock(_workload) {
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
					wi.result.post(wi.func(wi.parameter));
			} catch (Exception e) {
				wi.result.postFailure(e.clone());
			}
		} else {
			void(address p) f = void(address p)(wi.func);
			f(wi.parameter);
		}
		delete wi;
		return true;
	}
}

public class Future<class T> {
	private monitor _resources {
		T _value;
		boolean _calculating;
		boolean _posted;
		boolean _cancelled;
		ref<Exception> _uncaught;
	}
	
	public T get() {
		T val;
		lock (_resources) {
			if (!_posted)
				wait();
			val = _value;
		}
		return val;
	}
	
	public boolean success() {
		boolean result;
		lock (_resources) {
			if (!_posted)
				wait();
			result = !_cancelled && _uncaught == null;
		}
		return result;
	}
	
	public ref<Exception> uncaught() {
		ref<Exception> e;
		lock (_resources) {
			if (!_posted)
				wait();
			e = _uncaught;
		}
		return e;
	}
	
	public boolean cancelled() {
		boolean c;
		lock (_resources) {
			if (!_posted)
				wait();
			c = _cancelled;
		}
		return c;
	}
	
	public void post(T value) {
		lock (_resources) {
			_value = value;
			_posted = true;
			_calculating = false;
			notifyAll();
		}
	}
	
	public void postFailure(ref<Exception> e) {
		lock (_resources) {
			_uncaught = e;
			_posted = true;
			_calculating = false;
			notifyAll();
		}
	}
	
	boolean calculating() {
		boolean result;
		lock (_resources) {
			if (!_cancelled)
				_calculating = true;
			result = _calculating;
		}
		return result;
	}
	
	public boolean cancel() {
		boolean result;
		lock (_resources) {
			if (!_posted && !_calculating) {
				_cancelled = true;
				_posted = true;
				notifyAll();
			}
			result = _cancelled;
		}
		return result;
	}
}

private abstract address dupExecutionContext();
private abstract void enterThread(address newContext, address stackTop);
private abstract void exitThread();
