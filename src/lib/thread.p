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
import native:windows.Sleep;
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
import native:linux;
import native:C;
import parasol:exception.HardwareException;
import parasol:pxi.SectionType;
import parasol:runtime;

parasolThread(new Thread());

public class Thread {
	private string _name;
	private HANDLE _threadHandle;
	private linux.pthread_t _threadId;
	private linux.pid_t _pid;
	private void(address) _function;
	private address _parameter;
	private address _context;
	
	public Thread() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			_name.printf("TID-%d", GetCurrentThreadId());
			_threadHandle = INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			_threadId = linux.pthread_self();
			_pid = linux.gettid();
			_name.printf("TID-%d", _pid);			
		}
	}
	
	public Thread(string name) {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			if (name != null)
				_name = name;
			else
				_name.printf("TID-%d", GetCurrentThreadId());
			_threadHandle = INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			_threadId = linux.pthread_self();
			_pid = linux.gettid();
			if (name != null)
				_name = name;
			else
				_name.printf("TID-%d", _pid);			
		}
	}
	
	~Thread() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			if (_threadHandle != INVALID_HANDLE_VALUE)
				CloseHandle(_threadHandle);
		}
	}
	
	public boolean start(void func(address p), address parameter) {
		_function = func;
		_parameter = parameter;
		_context = dupExecutionContext();
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			address x = _beginthreadex(null, 0, wrapperFunction, this, 0, null);
			_threadHandle = *ref<HANDLE>(&x);
			return _threadHandle != INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			int result = linux.pthread_create(&_threadId, null, linuxWrapperFunction, this);
			return result == 0;
		} else
			return false;
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
	
	private static address linuxWrapperFunction(address wrapperParameter) {
		ref<Thread> t = ref<Thread>(wrapperParameter);
		t._threadId = linux.pthread_self();
		t._pid = linux.gettid();
		enterThread(t._context, &t);
		nested(t);
		exitThread();
		return null;
	}
	/**
	 * This provides a default exception handler for threads. See above for an explanation as to why this can't be in the
	 * same function as above.
	 */
	private static void nested(ref<Thread> t) {
		try {
			t._function(t._parameter);
		} catch (Exception e) {
			if (runtime.compileTarget == SectionType.X86_64_WIN) {
				printf("\nUncaught exception! (thread %d)\n\n%s\n", long(_threadHandle), e.message());
			} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
				printf("\nUncaught exception! (thread %d)\n\n%s\n", _threadId, e.message());
			}
			e.printStackTrace();
		}
	}

	public void join() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			DWORD dw = WaitForSingleObject(_threadHandle, INFINITE);
			if (dw == WAIT_FAILED) {
				printf("WaitForSingleObject failed %x\n", GetLastError());
			}
			CloseHandle(_threadHandle);
			_threadHandle = INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			address retval;
			
			int result = linux.pthread_join(_threadId, &retval);
		}
	}
	
	public string name() {
		return _name;
	}
	
	public long id() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			return GetCurrentThreadId();
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			return _pid;
		} else
			return -1;
	}

	public static void sleep(long milliseconds) {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			while (milliseconds > 1000000000) {
				Sleep(1000000000);
				milliseconds -= 1000000000;
			}
			if (milliseconds > 0)
				Sleep(DWORD(milliseconds));
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			if (milliseconds >= 1000) {
				C.sleep(unsigned(milliseconds / 1000));
				milliseconds %= 1000;
			}
			if (milliseconds > 0) {
				linux.usleep(linux.useconds_t(milliseconds * 1000));
			}
		}
	}
}
/*
 * This is the runtime implementation class for the monitor feature. It supplies the public methods that are
 * implied in a declared monitor object.
 */
class Monitor {
	private Mutex _mutex;
	private HANDLE	_semaphore;
	private linux.sem_t _linuxSemaphore;
	private int _waiting;
	
	public Monitor() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			_semaphore = HANDLE(CreateSemaphore(null, 0, int.MAX_VALUE, null));
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			if (linux.sem_init(&_linuxSemaphore, 0, 0) != 0)
				linux.perror("sem_init".c_str());
		}
	}
	
	~Monitor() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			CloseHandle(_semaphore);
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.sem_destroy(&_linuxSemaphore);
		}
	}
	
	private void take() {
		_mutex.take();
	}
	
	private void release() {
		_mutex.release();
	}
	
	public void notify() {
		_mutex.take();
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			ReleaseSemaphore(_semaphore, 1, null);
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.sem_post(&_linuxSemaphore);
		}
		--_waiting;
		_mutex.release();
	}
	
	public void notifyAll() {
		_mutex.take();
		if (_waiting > 0) {
			if (runtime.compileTarget == SectionType.X86_64_WIN) {
				ReleaseSemaphore(_semaphore, _waiting, null);
			} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
				while (_waiting > 0) {
					linux.sem_post(&_linuxSemaphore);
					_waiting--;
				}
			}
			_waiting = 0;
		}
		_mutex.release();
	}
	
	public void wait() {
		_mutex.take();
		_waiting++;
		int level = _mutex.releaseForWait();
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			WaitForSingleObject(_semaphore, INFINITE);
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.sem_wait(&_linuxSemaphore);
		}
		_mutex.takeAfterWait(level - 1);
	}
	
	public void wait(long timeout) {
		long upper = timeout >> 31;
		int lower = int(timeout & ((long(1) << 31) - 1));
		_mutex.take();
		_waiting++;
		int level = _mutex.releaseForWait();
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			DWORD outcome = WaitForSingleObject(_semaphore, DWORD(lower));
			if (outcome == WAIT_TIMEOUT) {
				for (int i = 0; i < upper; i++) {
					outcome = WaitForSingleObject(_semaphore, DWORD(int.MAX_VALUE));
					if (outcome != WAIT_TIMEOUT)
						break;
				}
			}
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.timespec expirationTime;
			linux.clock_gettime(linux.CLOCK_REALTIME, &expirationTime);
			if (timeout >= 1000) {
				expirationTime.tv_sec += timeout / 1000;
				timeout %= 1000;
			}
			expirationTime.tv_nsec += timeout * 1000000;
			if (expirationTime.tv_nsec >= 1000000000) {
				expirationTime.tv_sec++;
				expirationTime.tv_nsec -= 1000000000;
			}
			linux.sem_timed_wait(&_linuxSemaphore, &expirationTime);
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
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			DWORD outcome = WaitForSingleObject(_semaphore, DWORD(lower));
			if (outcome == WAIT_TIMEOUT) {
				for (int i = 0; i < upper; i++) {
					outcome = WaitForSingleObject(_semaphore, DWORD(int.MAX_VALUE));
					if (outcome != WAIT_TIMEOUT)
						break;
				}
			}
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.timespec expirationTime;
			linux.clock_gettime(linux.CLOCK_REALTIME, &expirationTime);
			if (timeout >= 1000) {
				expirationTime.tv_sec += timeout / 1000;
				timeout %= 1000;
			}
			expirationTime.tv_nsec += timeout * 1000000 + nanos;
			while (expirationTime.tv_nsec >= 1000000000) { // this loop might repeat twice if nanos, millis and current time all have a big nanos value.
				expirationTime.tv_sec++;
				expirationTime.tv_nsec -= 1000000000;
			}
			linux.sem_timed_wait(&_linuxSemaphore, &expirationTime);
		}
		_mutex.takeAfterWait(level - 1);
	}
}

class Mutex {
	private int _level;
	private HANDLE _mutex;
	private DWORD _ownerThreadId;
	private linux.pthread_mutex_t _linuxMutex;
	private linux.pthread_t _linuxOwnerThreadId;
	
	public Mutex() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			_mutex = HANDLE(CreateMutex(null, 0, null));
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.pthread_mutexattr_t attr;
			linux.pthread_mutexattr_settype(&attr, linux.PTHREAD_MUTEX_RECURSIVE);
			linux.pthread_mutex_init(&_linuxMutex, &attr);
		}
	}
	
	~Mutex() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			CloseHandle(_mutex);
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.pthread_mutex_destroy(&_linuxMutex);
		}
	}
	
	void take() {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			WaitForSingleObject(_mutex, INFINITE);
			DWORD currentThreadId = GetCurrentThreadId(); 
			if (_ownerThreadId == currentThreadId) {
				_level++;
			} else {
				_level = 1;
				_ownerThreadId = currentThreadId;
			}
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.pthread_mutex_lock(&_linuxMutex);
			linux.pthread_t currentThreadId = linux.pthread_self();
			if (_linuxOwnerThreadId == currentThreadId) {
				_level++;
			} else {
				_level = 1;
				_linuxOwnerThreadId = currentThreadId;
			}
		}
	}
	
	void release() {
		_level--;
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			ReleaseMutex(_mutex);
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.pthread_mutex_unlock(&_linuxMutex);
		}
	}
	
	int releaseForWait() {
		int priorLevel = _level;
		while (_level > 0)
			release();
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
	public T(address) valueGenerator;
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
		wi.valueGenerator = f;
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
		wi.valueGenerator = T(address)(f);
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

public ref<Thread> currentThread() {
	return ref<Thread>(parasolThread(null));
}

private abstract address dupExecutionContext();
private abstract void enterThread(address newContext, address stackTop);
private abstract void exitThread();
private abstract address parasolThread(address newThread);
