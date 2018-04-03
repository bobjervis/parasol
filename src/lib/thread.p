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
import parasol:runtime;

Thread.init();

private monitor class ActiveThreads {
	ref<Thread>[] _activeThreads;

	void enlist(ref<Thread> newThread) {
		for (int i = 0; i < _activeThreads.length(); i++)
			if (_activeThreads[i] == null) {
				newThread._index = i;
				_activeThreads[i] = newThread;
				return;
			}
		newThread._index = _activeThreads.length();
		_activeThreads.append(newThread);
	}

	void delist(ref<Thread> oldThread) {
		_activeThreads[oldThread._index] = null;
	}

	void activeThreads(ref<ref<Thread>[]> a) {
		(*a) = _activeThreads;					// trigger the copy here, since the return statement will lazily copy (outside the lock).
	}

	void suspendAllOtherThreads() {
		ref<Thread> me = currentThread();
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int tgid = linux.getpid();
			for (int i = 0; i < _activeThreads.length(); i++)
				if (_activeThreads[i] != me)
					linux.tgkill(tgid, int(_activeThreads[i].id()), linux.SIGTSTP);
		}
	}
}

private ActiveThreads threads;

public ref<Thread>[] getActiveThreads() {
	ref<Thread>[] a;

	threads.activeThreads(&a);
	return a;
}
/*
 * This is a hacky debug API to dump all threads. It can deadlock, if one of the other threads is inside, say, a memory allocator.
 */
public void suspendAllOtherThreads() {
	threads.suspendAllOtherThreads();
}

public class Thread {
	private string _name;
	private HANDLE _threadHandle;
	private linux.pthread_t _threadId;
	private linux.pid_t _pid;
	private void(address) _function;
	private address _parameter;
	private address _context;
	int _index;
	
	public Thread() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			_threadHandle = INVALID_HANDLE_VALUE;
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			_pid = -1;
		_index = -1;
	}
	
	public Thread(string name) {
		_name = name;
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			_threadHandle = INVALID_HANDLE_VALUE;
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			_pid = -1;
		_index = -1;
	}
	
	~Thread() {
		if (_index != -1)
			threads.delist(this);
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			if (_threadHandle != INVALID_HANDLE_VALUE)
				CloseHandle(_threadHandle);
		}
	}
	
	static void init() {
		ref<Thread> t = new Thread();
		t._name.printf("TID-%d", getCurrentThreadId());
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			t._threadHandle = INVALID_HANDLE_VALUE;
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			t._pid = linux.gettid();
		parasolThread(t);
//		printf("init of %s\n", t._name);
		threads.enlist(t);
//		printf("-\n");
	}

	public boolean start(void func(address p), address parameter) {
		_function = func;
		_parameter = parameter;
		_context = dupExecutionContext();
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			address x = _beginthreadex(null, 0, wrapperFunction, this, 0, null);
			_threadHandle = *ref<HANDLE>(&x);
			return _threadHandle != INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
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
		threads.enlist(t);
		parasolThread(t);
		if (t._name == null)
			t._name.printf("TID-%d", getCurrentThreadId());
		nested(t);
		exitThread();
		threads.delist(t);
		return 0;
	}
	
	private static address linuxWrapperFunction(address wrapperParameter) {
		ref<Thread> t = ref<Thread>(wrapperParameter);
		t._threadId = linux.pthread_self();
		t._pid = linux.gettid();
		if (t._name == null)
			t._name.printf("TID-%d", t._pid);
		enterThread(t._context, &t);
		threads.enlist(t);
		parasolThread(t);
		nested(t);
		threads.delist(t);
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
			printf("\nUncaught exception! (thread %s)\n\n%s\n", t._name, e.message());
			e.printStackTrace();
		}
	}
	/*
	 * These are prone to deadlocks. Use with caution.
	 */
	public void suspend() {
		linux.tgkill(linux.getpid(), _pid, linux.SIGTSTP);
	}

	public void resume() {
		linux.tgkill(linux.getpid(), _pid, linux.SIGCONT);
	}

	public void join() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			DWORD dw = WaitForSingleObject(_threadHandle, INFINITE);
			if (dw == WAIT_FAILED) {
				printf("WaitForSingleObject failed %x\n", GetLastError());
			}
			CloseHandle(_threadHandle);
			_threadHandle = INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			address retval;
			
			int result = linux.pthread_join(_threadId, &retval);
			if (result != 0) {
				printf("%s pthread_join %s: %d\n", currentThread().name(), _name, result);
				assert(false);
			}
		}
	}
	
	public string name() {
		return _name;
	}
	
	public long id() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			return GetCurrentThreadId();
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			return _pid;
		} else
			return -1;
	}

	public static void sleep(long milliseconds) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			while (milliseconds > 1000000000) {
				Sleep(1000000000);
				milliseconds -= 1000000000;
			}
			if (milliseconds > 0)
				Sleep(DWORD(milliseconds));
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.timespec ts;
			linux.timespec remaining;

			ts.tv_sec = milliseconds / 1000;
			ts.tv_nsec = (milliseconds % 1000) * 1000000;
			for (;;) {
				int result = linux.nanosleep(&ts, &remaining);
				if (result == 0)
					break;
				ts = remaining;
			}
		}
	}
}

public void exit(int code) {
	linux.pthread_exit(address(code));
}

/*
 * This is the runtime implementation class for the monitor feature. It supplies the public methods that are
 * implied in a declared monitor object.
 */
public class Monitor {
	private Mutex _mutex;
	private HANDLE	_semaphore;
	private linux.sem_t _linuxSemaphore;
	private int _waiting;
	
	public Monitor() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			_semaphore = HANDLE(CreateSemaphore(null, 0, int.MAX_VALUE, null));
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			if (linux.sem_init(&_linuxSemaphore, 0, 0) != 0)
				linux.perror("sem_init".c_str());
		}
	}
	
	~Monitor() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			CloseHandle(_semaphore);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.sem_destroy(&_linuxSemaphore);
		}
	}
	
	public boolean isLocked() {
		return _mutex.isLocked();
	}
	
	public ref<Thread> owner() {
		return _mutex.owner();
	}
	
	private void take() {
		_mutex.take();
	}
	
	private void release() {
		_mutex.release();
	}
	
	public void notify() {
//		printf("Entering notify\n");
		_mutex.take();
//		printf("taken\n");
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			ReleaseSemaphore(_semaphore, 1, null);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.sem_post(&_linuxSemaphore);
		}
		--_waiting;
//		printf("About to release\n");
		_mutex.release();
	}
	
	public void notifyAll() {
		_mutex.take();
		if (_waiting > 0) {
			if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
				ReleaseSemaphore(_semaphore, _waiting, null);
			} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
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
//		printf("%s %p entering wait\n", currentThread().name(), this);
		_mutex.take();
//		printf("%s %p taken\n", currentThread().name(), this);
		_waiting++;
		int level = _mutex.releaseForWait();
//		printf("%s %p mutex %s\n", currentThread().name(), this, _mutex.isLocked() ? "isLocked" : "is not locked");
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			WaitForSingleObject(_semaphore, INFINITE);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.sem_wait(&_linuxSemaphore);
		}
//		printf("%s %p Got the semaphore: level %d\n", currentThread().name(), this, level);
		_mutex.takeAfterWait(level - 1);
	}
	
	public void wait(long timeout) {
		long upper = timeout >> 31;
		int lower = int(timeout & ((long(1) << 31) - 1));
		_mutex.take();
		_waiting++;
		int level = _mutex.releaseForWait();
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			DWORD outcome = WaitForSingleObject(_semaphore, DWORD(lower));
			if (outcome == WAIT_TIMEOUT) {
				for (int i = 0; i < upper; i++) {
					outcome = WaitForSingleObject(_semaphore, DWORD(int.MAX_VALUE));
					if (outcome != WAIT_TIMEOUT)
						break;
				}
			}
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
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
			linux.sem_timedwait(&_linuxSemaphore, &expirationTime);
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
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			DWORD outcome = WaitForSingleObject(_semaphore, DWORD(lower));
			if (outcome == WAIT_TIMEOUT) {
				for (int i = 0; i < upper; i++) {
					outcome = WaitForSingleObject(_semaphore, DWORD(int.MAX_VALUE));
					if (outcome != WAIT_TIMEOUT)
						break;
				}
			}
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
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
			linux.sem_timedwait(&_linuxSemaphore, &expirationTime);
		}
		_mutex.takeAfterWait(level - 1);
	}
}

class Mutex {
	private int _level;
	private HANDLE _mutex;
	private ref<Thread> _owner;
	private linux.pthread_mutex_t _linuxMutex;
	private static boolean _alreadySet;
	
	public Mutex() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			_mutex = HANDLE(CreateMutex(null, 0, null));
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.pthread_mutexattr_t attr;
			linux.pthread_mutexattr_settype(&attr, linux.PTHREAD_MUTEX_RECURSIVE);
			if (long(this) == long(&threads) + 8) {
				if (_alreadySet)
					assert(false);
				_alreadySet = true;
			}
			linux.pthread_mutex_init(&_linuxMutex, &attr);
		}
	}
	
	~Mutex() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			CloseHandle(_mutex);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.pthread_mutex_destroy(&_linuxMutex);
		}
	}
	
	public boolean isLocked() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			DWORD code = WaitForSingleObject(_mutex, 0);
			if (code == WAIT_TIMEOUT)
				return true;
			else if (code == 0)
				ReleaseMutex(_mutex);
			return false;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int result = linux.pthread_mutex_trylock(&_linuxMutex);
			if (result == 0) {
				int level = _level;
				linux.pthread_mutex_unlock(&_linuxMutex);
				if (level > 0)
					return true;
			}
			return result == linux.EBUSY;
		} else
			return false;
	}
	
	public ref<Thread> owner() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			DWORD code = WaitForSingleObject(_mutex, 0);
			if (code == WAIT_TIMEOUT)
				return _owner;
			else if (code == 0)
				ReleaseMutex(_mutex);
			return null;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int result = linux.pthread_mutex_trylock(&_linuxMutex);
			if (result == 0) {
				linux.pthread_mutex_unlock(&_linuxMutex);
				if (_level > 0)
					return _owner;
			}
			if (result == linux.EBUSY)
				return _owner;
		}
		return null;
	}
	
	void take() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			WaitForSingleObject(_mutex, INFINITE);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
//			printf("%p try lock by %s (level = %d)\n", this, currentThread() != null ? currentThread().name() : "?", _level);
			int x = linux.pthread_mutex_lock(&_linuxMutex);
			assert(x == 0);
		}
		_level++;
		_owner = currentThread();
//		printf("%p take by %s (level = %d)\n", this, _owner != null ? _owner.name() : "?", _level);
	}
	
	void release() {
//		printf("%p release by %s (level = %d)\n", this, _owner.name(), _level);
		_level--;
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			ReleaseMutex(_mutex);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			assert(linux.pthread_mutex_unlock(&_linuxMutex) == 0);
		}
	}
	
	int releaseForWait() {
		int priorLevel = _level;
		for (int i = 0; i < priorLevel; i++)
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

private monitor class ThreadPoolData<class T> {
	ref<WorkItem<T>> _first;
	ref<WorkItem<T>> _last;
	boolean _shutdownRequested;
}

public class ThreadPool<class T> extends ThreadPoolData<T> {
	ref<Thread>[] _threads;
	
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
				return null;
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
				return false;
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

		lock(*this) {
			if (_shutdownRequested)
				return false;
			wait();
			if (_shutdownRequested)		// Note: _first will be null
				return false;
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

public ref<Thread> currentThread() {
	return ref<Thread>(parasolThread(null));
}

private int getCurrentThreadId() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN)
		return int(GetCurrentThreadId());
	else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
		return linux.gettid();
	else
		return -1;
}

private abstract address dupExecutionContext();
private abstract void enterThread(address newContext, address stackTop);
private abstract void exitThread();
/*
 * Declare to the C runtime code the location of the Parasol Thread object for this thread.
 */
private abstract address parasolThread(address newThread);

private class Monitor_Poly extends Monitor {
	// THis exists to trick the compiler into generating a table for this class.
	public ref<Thread> owner() {
		return null;
	}
}

