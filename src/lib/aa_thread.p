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
/**
 * Provides facilities for starting and controlling threads.
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
import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;
import parasol:runtime;
import parasol:process;
import parasol:international.Locale;
import parasol:time;

Thread.init();

private monitor class ActiveThreads {
	ref<Thread>[] _activeThreads;

	~ActiveThreads() {
		Thread.destruct();
	}

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
		oldThread._index = -1;
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
/**
 * Fetch the set of active Parasol threads.
 *
 * Threads that were initiated by C code and which have not interacted with
 * the Parasol runtime are not included.
 *
 * @threading Note that under the current implementation, the returned Thread
 * objects may be deleted while these references are live. The Thread object
 * should be guarded in situations like this to avoid races.
 *
 * In general, this call is only safe after a call to {@link suspendAllOtherThreads}
 * and before resuming any of those threads.
 *
 * @return An array of references to Threads.
 */
public ref<Thread>[] getActiveThreads() {
	ref<Thread>[] a;

	threads.activeThreads(&a);
	return a;
}
/**
 * Suspend all other threads.
 *
 * @threading This can cause all sorts of problems if one of the suspended threads is
 * holding locks, such as in a memory allocator.
 */
public void suspendAllOtherThreads() {
	threads.suspendAllOtherThreads();
}
/**
 * This class holds per-thread data.
 */
public class Thread {
	public ref<Locale> locale;
	public ref<runtime.Profiler> profiler;
	public ref<runtime.Coverage> coverage;
	private string _name;
	private HANDLE _threadHandle;
	private linux.pthread_t _threadId;
	private linux.pid_t _pid;
	private void(address) _function;
	private address _parameter;
	private address _context;
	int _index;
	/**
	 * The default constructor.
	 *
	 * The Thread object is created in a dormant state before any
	 * operating system initialization. As a result, a Parasol program
	 * can create millions of such objects, but could not start them all.
	 *
	 * A THread object that has never been started will not appear in the list
	 * of active Thread's until the thread has started executing.
	 *
	 * The thread has no name assigned to it.
	 */
	public Thread() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			_threadHandle = INVALID_HANDLE_VALUE;
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			_pid = -1;
		_index = -1;
	}
	/**
	 * The constructor for a named thread.
	 *
	 * The Thread object is created in a dormant state before any
	 * operating system initialization. As a result, a Parasol program
	 * can create millions of such objects, but could not start them all.
	 *
	 * @param name The name the Thread will report during it's lifetime.
	 * This information is primarily for debugging purposes.
	 */
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

	static ref<Thread> mainThread;
	/*
	 * Initialize a Thread object for the 'main' thread of the process.
	 */
	static void init() {
		mainThread = new Thread();
		mainThread._name.printf("TID-%d", getCurrentThreadId());
		if (runtime.compileTarget == runtime.Target.X86_64_WIN)
			mainThread._threadHandle = INVALID_HANDLE_VALUE;
		else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
			mainThread._pid = linux.gettid();
		runtime.setParasolThread(mainThread);
		threads.enlist(mainThread);
		mainThread.initializeInstrumentation();
	}

	static void destruct() {
		mainThread.checkpointInstrumentation();
	}
	/**
	 * Start a Thread running.
	 *
	 * @param func The function to call on start-up. The thread exists when this
	 * function returns or calls {@link parasol:thread.exit}.
	 *
	 * @param parameter This value is passed to the functionon startup.
	 *
	 * @return true if the Thread started successfully, false otherwise.
	 *
	 * @threading This method should not be called on the same Thread object by more
	 * than one thread at a time.
	 *
	 * @exception IllegalArgumentException Thrown if the func argument is null.
	 *
	 * @exception IllegalOperationException Throw if this thread has already been started.
	 */
	public boolean start(void func(address p), address parameter) {
		if (func == null)
			throw IllegalArgumentException("func");
		if (_function != null)
			throw IllegalOperationException("thread.start");
		_function = func;
		_parameter = parameter;
		_context = dupExecutionContext();
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			address x = _beginthreadex(null, 0, wrapperFunction, this, 0, null);
			_threadHandle = *ref<HANDLE>(&x);
			if (_threadHandle == INVALID_HANDLE_VALUE)
				func = null;
			return _threadHandle != INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int result = linux.pthread_create(&_threadId, null, linuxWrapperFunction, this);
			if (result != 0) {
				func = null;
				_threadId = null;
			}
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
		t._pid = getCurrentThreadId();
		nested(t);
		return 0;
	}
	
	private static address linuxWrapperFunction(address wrapperParameter) {
		ref<Thread> t = ref<Thread>(wrapperParameter);
		t._pid = linux.gettid();
		// All set up, now call the thread main function
		nested(t);
		return null;
	}
	/**
	 * This provides a default exception handler for threads. See above for an explanation as to why this can't be in the
	 * same function as above.
	 */
	private static void nested(ref<Thread> t) {
		enterThread(t._context, &t);
		threads.enlist(t);
		runtime.setParasolThread(t);
		t.initializeInstrumentation();
		try {
			t._function(t._parameter);
		} catch (Exception e) {
			printf("\nUncaught exception! (thread %s)\n\n%s\n", t._name, e.message());
			e.printStackTrace();
			process.stdout.flush();
		}
		t.checkpointInstrumentation();
		threads.delist(t);
		exitThread();
	}

	private void initializeInstrumentation() {
	}

	private void checkpointInstrumentation() {
	}
	/**
	 * Suspend this Thread.
	 *
	 * @threading This is prone to deadlocks. Use with caution.
	 */
	public void suspend() {
		linux.tgkill(linux.getpid(), _pid, linux.SIGTSTP);
	}
	/**
	 * Resume this Thread.
	 *
	 * If the indicated Thread is not stopped, this call has no effect.
	 */
	public void resume() {
		linux.tgkill(linux.getpid(), _pid, linux.SIGCONT);
	}
	/**
	 * Wait for a Thread to exit.
	 *
	 * If the Thread is currently running, the caller waits for the Thread to exit.
	 *
	 * When this method returns, the Thread may be started again.
	 *
	 * @exception IllegalOperationException THrown if the Thread object has not been
	 * started, or if this is the main thread of the process.
	 */
	public void join() {
		if (_function == null)
			throw IllegalOperationException("join");
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			DWORD dw = WaitForSingleObject(_threadHandle, INFINITE);
			if (dw == WAIT_FAILED) {
				printf("WaitForSingleObject failed %x\n", GetLastError());
			}
			CloseHandle(_threadHandle);
			_threadHandle = INVALID_HANDLE_VALUE;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int result = linux.pthread_join(_threadId, null);
			if (result != 0) {
				printf("%s pthread_join %s: %d\n", currentThread().name(), _name, result);
				assert(false);
			}
		}
		_function = null;
		_pid = -1;
	}
	/**
	 * Fetch the Thread's name.
	 *
	 * An un-named thread will report a name of the form "TID-NNNN" where NNNN
	 * is the operating system thread id when the Thread is running. The 'name' of
	 * an un-started (or started but not yet running), un-named thread is a single qustion mark.
	 */
	public string name() {
		if (_name != null)
			return _name;
		else if (_pid != -1)
			return "TID-" + _pid;
		else
			return "?";
	}
	/**
	 * Fetch the Thread's id.
	 *
	 * @return If the Thread has been started and is running. If the thread has not been started,
	 * has been started but has not begun running, or has exited and has been joined the value is -1.
	 */
	public int id() {
		return _pid;
	}
	/**
	 * A handy mechanism for sorting Thread's. For active Thread's they will be in id order.
	 */
	public int compare(ref<Thread> other) {
		if (this == other)
			return 0;
		else if (_pid > other._pid)
			return 1;
		else
			return -1;
	}
	/**
	 * A hash function useful for map's of Thread objects.
	 */
	public int hash() {
		return int(long(this) >> 8);
	}
}
/**
 * Exit the current thread.
 */
public void exit() {
	linux.pthread_exit(null);
}

/**
 * This class implements a thread synchronization Monitor object.
 *
 * Monitor's were created by Brinch Hanson and C.A.R. Hoare in the early 1970's (see this
 * <a href='https://en.wikipedia.org/wiki/Monitor_(synchronization)'>Wikipedia article</a>).
 *
 * A Monitor provides both the capabilities of a Mutex (allowing for mutual exclusion between
 * threads) along with semaphore semantics (wait and notify).
 *
 * While it is reasonable to create a Monitor object and call the wait and notify methods directly,
 * you should use the lock statement, naming the Monitor to gain exclusive access for a region of
 * code.. The lock statement will ensure that all control flow paths out of the lock statement,
 * including uncaught exceptions will release any taken locks.
 *
 * @threading This object is thread-safe. You may call any method on this object at any time from as many
 * threads as you wish.
 */
public class Monitor {
	private Mutex _mutex;
	private HANDLE	_semaphore;
	private linux.sem_t _linuxSemaphore;
	private int _waiting;
	private boolean _initialized;
	/**
	 * The constructor.
	 *
	 * The Monitor is created in an unlocked state.
	 */
	public Monitor() {
	}
	
	~Monitor() {
		if (_initialized) {
			if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
				CloseHandle(_semaphore);
			} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
				linux.sem_destroy(&_linuxSemaphore);
			}
		}
	}
	
	private void initialize() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			_semaphore = HANDLE(CreateSemaphore(null, 0, int.MAX_VALUE, null));
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			if (linux.sem_init(&_linuxSemaphore, 0, 0) != 0)
				linux.perror("sem_init".c_str());
		}
		_initialized = true;
	}
	/**
	 * Detect whether a Monitor is currently locked.
	 *
	 * If the conditions causing the lock are transient, whether or not this
	 * method returns true at any point in time says nothing about it's condition
	 * the moment the condition is tested and acted upon.
	 *
	 * @return true if the Monitor is locked and false if it is not.
	 */
	public boolean isLocked() {
		return _mutex.isLocked();
	}
	/**
	 * Return the current owner of the lock on this Monitor.
	 *
	 * @return A reference to the Thread that owns this ock, or null if the Montior
	 * is not currently locked.
	 */
	public ref<Thread> owner() {
		return _mutex.owner();
	}
	/**
	 * Take the Monitor (set a lock on it).
	 *
	 * If the Monitor is currently unlocked, the MOnitor becomes locked. If it is
	 * currently locked by another Thread, the calling Thread blocks until the Monitor
	 * becomes unlocked due to a call to {@link release}. Thread's will be given control
	 * of the MOnitor in the order in which they call this method.
	 *
	 * If a Thread already holds a lock on this Monitor, a nested lock is granted. In
	 * this way, a Thread can take as many lock's on a Monitor as it likes and can reliably
	 * unwind them by calling {@link release} for each lock taken.
	 */
	private void take() {
		_mutex.take();
	}
	/**
	 * Release the Monitor (clear a lock on it).
	 *
	 * If the current Thread holds a lock on this Monitor, the lock is released. If this is the
	 * last lock held by the Thread, then a Thread waiting for a lock (in the {@link take}
	 * method) will be unblocked and take it's lock.
	 */
	private void release() {
		_mutex.release();
	}
	/**
	 * Notify the first waiting thread.
	 *
	 * If there are threads waiting on this Monitor, the first such thread is notified and
	 * returns from it's wait call.
	 *
	 * If no thread is currently waiting on this Monitor, then for each call to notify, one
	 * corresponding call to wait will immediately return.
	 */
	public void notify() {
//		printf("Entering notify\n");
		_mutex.take();
//		printf("taken\n");
		if (!_initialized)
			initialize();
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			ReleaseSemaphore(_semaphore, 1, null);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.sem_post(&_linuxSemaphore);
		}
		--_waiting;
//		printf("About to release\n");
		_mutex.release();
	}
	/**
	 * Notify all currently waiting threads.
	 *
	 * If there are threads waiting on this MOnitor, then all are notified and immediately
	 * return from their wait call.
	 *
	 * If no threads are currently waiting, this method has no effect.
	 */
	public void notifyAll() {
		_mutex.take();
		if (!_initialized)
			initialize();
		if (_waiting > 0) {
			if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
				ReleaseSemaphore(_semaphore, _waiting, null);
				_waiting = 0;
			} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
				while (_waiting > 0) {
					linux.sem_post(&_linuxSemaphore);
					_waiting--;
				}
			}
		}
		_mutex.release();
	}
	/**
	 * The current thread waits.
	 *
	 * If no un-matched call to notify has occurred, the current thread will block
	 * waiting for a {@link notify} or {@link notifyAll} call to occur.
	 */
	public void wait() {
//		printf("%s %p entering wait\n", currentThread().name(), this);
		_mutex.take();
		if (!_initialized)
			initialize();
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
	/**
	 * THe current thread waits for some time to pass.
	 *
	 * If no un-matched call to notify has occurred, the current thread will block
	 * waiting for a {@link notify} or {@link notifyAll} call to occur.
	 * 
	 * If the indicated timeout period elapses before any notify call happens, the
	 * wait is cancelled and the calling thread resumes execution. The thread must determine
	 * whether the conditions of the wait were satisfied by some other means.
	 *
	 * @param timeout The amount of time to wait.
	 */
	public void wait(time.Duration timeout) {
		if (timeout.isInfinite()) {
			wait();
			return;
		}
		_mutex.take();
		if (!_initialized)
			initialize();
		_waiting++;
		int level = _mutex.releaseForWait();
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			long millis = timeout.milliseconds();
			long upper = millis >> 31;
			int lower = int(millis & ((long(1) << 31) - 1));
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
			expirationTime.tv_sec += timeout.seconds();
			expirationTime.tv_nsec += timeout.nanoseconds();
			if (expirationTime.tv_nsec >= 1000000000) {
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
	
	boolean isLocked() {
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
	
	ref<Thread> owner() {
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
//			string s;
//			s.printf("%p try lock by %s (level = %d)\n", this, currentThread() != null ? currentThread().name() : "?", _level);
//			print(s);
			int x = linux.pthread_mutex_lock(&_linuxMutex);
			if (x != 0) {
				printf("mutex_lock returned %d at %p\n", x, runtime.returnAddress());
				linux._exit(1);
			}
		}
		_level++;
		_owner = currentThread();
//		string s;
//		s.printf("%p take by %s (level = %d)\n", this, _owner != null ? _owner.name() : "?", _level);
//		print(s);
	}
	
	void release() {
//		printf("%p release by %s (level = %d)\n", this, _owner.name(), _level);
		_level--;
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			ReleaseMutex(_mutex);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			int x = linux.pthread_mutex_unlock(&_linuxMutex);
			if (x != 0)
				printf("mutex_unlock returned %d\n", x);
			assert(x == 0);
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
/**
 * A pool of threads available to share work.
 *
 * It is often more efficient to create a set of threads once and then feed them units of
 * work, rather than spawn and terminate threads constantly.Particularly, if the work is CPU
 * intensive it may not make sense to have more than the number of CPU's in the processor
 * allocated to doing work at one time. Additional threads will consume more memory and 
 * overhead as well as contention for available CPU's.
 *
 * Calls to the {@link execute} method add work items to the pool, forming a queue. Idle
 * threads each take one work item at a time from the queue and return when that work item
 * is completed.
 *
 * @threading ThreadPool objects are thread-safe and can be called from any number of threads.
 */
public class ThreadPool<class T> extends ThreadPoolData<T> {
	ref<Thread>[] _threads;
	int _idle;
	/**
	 * Construct a pool of N threads.
	 *
	 * @param threadCount The number of threads to start in the pool.
	 */
	public ThreadPool(int threadCount) {
		resize(threadCount);
	}
	
	~ThreadPool() {
		shutdown();
	}
	/**
	 * Shut down all of the threads in the pool.
	 *
	 * Any unstarted work items are cancelled.
	 */
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
//		for (i in _threads)
		for (int i = 0; i < _threads.length(); i++)
			_threads[i].join();
		_threads.clear();
	}
	/**
	 * Execute some work and create a {@link Future} to track completion
	 * of the work.
	 *
	 * If the pool is being shut down, no work item is queued.
	 *
	 * @param f A function to call to perform the work.
	 *
	 * @param parameter A value to be passed to the function when the work
	 * gets performed.
	 *
	 * @return A reference to a Future that was allocated to track the work.
	 * If the pool is being shut down null is returned.
	 */
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
	/**
	 * Execute some work.
	 *
	 * If the pool is being shut down, no work item is queued.
	 *
	 * @param f A function to call to perform the work.
	 *
	 * @param parameter A value to be passed to the function when the work
	 * gets performed.
	 *
	 * @return true if the work was queued successfully, or false if the
	 * pool is being shut down.
	 */
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
	/**
	 * Increase the number of threads in the pool.
	 *
	 * @param newThreadCount The number of threads the pool should contain.
	 *
	 * @exception IllegalArgumentException THrown if the new number of threads
	 * is less than the current number of threads.
	 */
	public void resize(int newThreadCount) {
		lock (*this) {
			if (newThreadCount < _threads.length())
				throw IllegalArgumentException("new threads < " + _threads.length());
			else {
				while (newThreadCount > _threads.length()) {
					ref<Thread> t = new Thread();
					_threads.append(t);
					t.start(workLoop, this);
				}
			}
		}
	}
	/**
	 * Get the total number of threads in the pool.
	 *
	 * @return The number of threads currently running in the pool.
	 */
	public int totalThreads() {
		lock (*this) {
			return _threads.length();
		}
	}
	/**
	 * Get the number of idle threads.
	 *
	 * @return The current number of idle threads in the pool.
	 */
	public int idleThreads() {
		lock (*this) {
			return _idle;
		}
	}
	/**
	 * Get the number of busy threads.
	 *
	 * @return The current number of busy threads in the pool.
	 */
	public int busyThreads() {
		lock (*this) {
			return _threads.length() - _idle;
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
			_idle++;
			wait();
			_idle--;
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
				printf("Failed ThreadPool work item: Uncaught exception! %s\n%s", 
								e.message(), e.textStackTrace());
				process.stdout.flush();
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
/**
 * A 'future' value.
 *
 * This object tracks the eventual completion of a work-item and the production of a
 * value of type T.
 *
 * There are several attributes of a Future aside from the computed value. For example,
 * the Future could have been cancelled, successful or might have produced an uncaught
 * exception. Methods can be used to interrogate those attributes.
 *
 * The general pattern for using Future's is to ubmit a set of work items to a thread pool,
 * collecting the Future's in an array. When all owrk-items are submitted, you can then
 * iterate over the Future's, either just calling {@link wait} on each one, or by calling
 * one of the methods that fetches a value that is computed as a result of the work being
 * done. Those that are already finished by the time you call one of these methods won't wait
 * but will immediately return with whatever value you care about, while those that are not
 * finished will wait until the work item is finished.
 *
 * @threading All methods on this object are thread-safe.
 */
public monitor class Future<class T> {
	T _value;
	boolean _calculating;
	boolean _posted;
	boolean _cancelled;
	ref<Exception> _uncaught;
	/**
	 * Get the computed value.
	 *
	 * This method waits for the work item to finish. 
	 *
	 * @return The return value of the function called to perform the work item.
	 */
	public T get() {
		if (!_posted)
			wait();
		return _value;
	}
	/**
	 * Determine whether the work item completed successfully.
	 *
	 * This method waits for the work item to finish.
	 *
	 * @return true if the function successfully returned a value, false otherwise.
	 */
	public boolean success() {
		if (!_posted)
			wait();
		return !_cancelled && _uncaught == null;
	}
	/**
	 * Fetch any uncaught Exception thrown by the called function.
	 *
	 * This method waits for the work item to finish.
	 *
	 * @return A reference to an Exception, or null if the function was either
	 * cancelled or succeeded.
	 */
	public ref<Exception> uncaught() {
		if (!_posted)
			wait();
		return _uncaught;
	}
	/**
	 * Determine whether a work item was cancelled.
	 *
	 * This method waits for the work item to finish.
	 *
	 * @return true if the Future was cancelled before any work was done,
	 * false if the work was done.
	 */
	public boolean cancelled() {
		if (!_posted)
			wait();
		return _cancelled;
	}
	
	void post(T value) {
		_value = value;
		_posted = true;
		_calculating = false;
		notifyAll();
	}
	
	void postFailure(ref<Exception> e) {
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
	/**
	 * Cancel a pending work item.
	 *
	 * If work has not begun on the owrk item (it is still queued in the
	 * thread pool), the item will be marked as cancelled.
	 *
	 * @return true if the work item was cancelled, false if it is either already
	 * complete or at least has started (the function has been called).
	 */
	public boolean cancel() {
		if (!_posted && !_calculating) {
			_cancelled = true;
			_posted = true;
			notifyAll();
		}
		return _cancelled;
	}
}
/**
 * Get the current running Thread object.
 *
 * @return The Thread object of the currently running thread.
 */
public ref<Thread> currentThread() {
	return runtime.parasolThread();
}
/**
 * Pause the current Thread for some interval of time.
 *
 * @param milliseconds The time to pause in milliseconds.
 */
public void sleep(long milliseconds) {
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

private int getCurrentThreadId() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN)
		return int(GetCurrentThreadId());
	else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
		return linux.gettid();
	else
		return -1;
}

@Linux("libparasol.so.1", "dupExecutionContext")
@Windows("parasol.dll", "dupExecutionContext")
private abstract address dupExecutionContext();

@Linux("libparasol.so.1", "enterThread")
@Windows("parasol.dll", "enterThread")
private abstract void enterThread(address newContext, address stackTop);

@Linux("libparasol.so.1", "exitThread")
@Windows("parasol.dll", "exitThread")
private abstract void exitThread();

private class Monitor_Poly extends Monitor {
	// This exists to trick the compiler into generating a table for this class.
	public ref<Thread> owner() {
		return null;
	}
}

