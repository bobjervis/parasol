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
#pragma once
#if defined(__WIN64)
#include <windows.h>
#elif __linux__
#include <pthread.h>
static const int INFINITE = -1;
#endif
#include "event.h"
#include "string.h"
#include "vector.h"

namespace process {

class Thread;
class ThreadPool;

typedef unsigned exception_t;

enum exception_t_values {
	NO_EXCEPTION,
	ABORT,
	BREAKPOINT,
	TIMEOUT,							// debugSpawn exceeded specified timeout
	TOO_MANY_EXCEPTIONS,				// too many exceptions raised by child process
	ACCESS_VIOLATION,					// hardware memory access violation
	UNKNOWN_EXCEPTION,					// A system or application exception not known to the
										// runtime
};

extern const char* exceptionNames[];

class Process {
public:
	Process();

	~Process();

	void setTls(Thread* t);

	Thread* getTls();

private:
#if defined(__WIN64)
	int	_tlsIndex;
#endif
};

class Pipe {
public:
	Pipe();

#if defined(__WIN64)
	HANDLE writer() const { return _writer; }
	HANDLE reader() const { return _reader; }
#elif __linux__
	int writer() const { return _writer; }
	int reader() const { return _reader; }
#endif

private:
#if defined(__WIN64)
	HANDLE			_writer;
	HANDLE			_reader;
#elif __linux__
	int _writer;
	int _reader;
#endif
};

class DebugSpawnCookie {
public:
	Pipe		pipe;
	string*		captureData;
};

class Thread  {
	friend class Process;
public:
	template<class T>
	static Thread* start(T* object, void (T::*func)()) {
		Thread* t = new Thread();
		t->startAt(object, func);
		return t;
	}

	static Thread* start(void (*func)()) {
		Thread* t = new Thread();
		t->startAt(func);
		return t;
	}

	template<class M>
	static Thread* start(void (*func)(M), M m) {
		Thread* t = new Thread();
		t->startAt(func, m);
		return t;
	}

	template<class M, class N>
	static Thread* start(void (*func)(M, N), M m, N n) {
		Thread* t = new Thread();
		t->startAt(func, m, n);
		return t;
	}

	int allocateThreadLocal() { return _local++; }

	void* local(int id) const {
		if (id >= _locals.size())
			return null;
		else
			return _locals[id];
	}

	void setLocal(int id, void* value) {
		while (id >= _locals.size())
			_locals.push_back(null);
		_locals[id] = value;
	}

#if defined(__WIN64)
	HANDLE hThread() const { return _hThread; }
#endif

	Event idle;

	~Thread();

private:
	Thread();

	template<class T>
	void startAt(T* object, void (T::*func)()) {
		_handler = new ObjectHandler<T>(object, func);
		start();
	}

	void startAt(void (*func)()) {
		_handler = new FunctionHandler(func);
		start();
	}

	template <class M>
	void startAt(void (*func)(M), M m) {
		_handler = new Function1Handler<M>(func, m);
		start();
	}

	template <class M, class N>
	void startAt(void (*func)(M, N), M m, N n) {
		_handler = new Function2Handler<M, N>(func, m, n);
		start();
	}

	class Handler {
	public:
		virtual void start() = 0;
	};

	template<class T>
	class ObjectHandler : public Handler { 
	public:
		ObjectHandler(T* object, void (T::*func)()) {
			_object = object;
			_func = func;
		}

		virtual void start() {
			(_object->*_func)();
		}

	private:
		T* _object;
		void (T::*_func)();
	};

	class FunctionHandler : public Handler {
	public:
		FunctionHandler(void (*func)()) {
			_func = func;
		}

		virtual void start() {
			_func();
		}

	private:
		void (*_func)();
	};

	template<class M>
	class Function1Handler : public Handler {
	public:
		Function1Handler(void (*func)(M), M m) {
			_func = func;
			_m = m;
		}

		virtual void start() {
			_func(_m);
		}

	private:
		void (*_func)(M);
		M _m;
	};

	template<class M, class N>
	class Function2Handler : public Handler {
	public:
		Function2Handler(void (*func)(M, N), M m, N n) {
			_func = func;
			_m = m;
			_n = n;
		}

		virtual void start() {
			_func(_m, _n);
		}

	private:
		void (*_func)(M, N);
		M _m;
		N _n;
	};

	void start();

#if defined(__WIN64)
	static DWORD WINAPI threadProc(void* data);

	DWORD			_threadId;
	HANDLE			_hThread;
#elif __linux__
	static void *threadProc(void *data);

	pthread_t _threadId;
#endif
	Handler*		_handler;
	int				_local;
	vector<void*>	_locals;
};

class Mutex {
	friend class MutexLock;
public:
	Mutex() {
#if defined(__WIN64)
		InitializeCriticalSection(&_lock);
#elif __linux__
		pthread_mutexattr_t attr;

		_lock = PTHREAD_MUTEX_INITIALIZER;
		pthread_mutex_init(&_lock, &attr);
#endif
	}

	~Mutex() {
#if defined(__WIN64)
		DeleteCriticalSection(&_lock);
#elif __linux__
		pthread_mutex_destroy(&_lock);
#endif
	}

private:
#if defined(__WIN64)
	CRITICAL_SECTION		_lock;
#elif __linux__
	pthread_mutex_t _lock;
#endif
};

class MutexLock {
public:
	MutexLock(Mutex* m) {
		_mutex = m;
		lock();
	}

	~MutexLock() {
		if (_locked)
			unlock();
	}

	void lock() {
#if defined(__WIN64)
		EnterCriticalSection(&_mutex->_lock);
#elif __linux__
		pthread_mutex_lock(&_mutex->_lock);
#endif
		_locked = true;
	}

	void unlock() {
		_locked = false;
#if defined(__WIN64)
		LeaveCriticalSection(&_mutex->_lock);
#elif __linux__
		pthread_mutex_unlock(&_mutex->_lock);
#endif
	}

private:
	Mutex *_mutex;
	bool _locked;
};

class WaitableEvent {
	friend int wait2(WaitableEvent* a, WaitableEvent* b, unsigned millisecondsWait);
public:
	WaitableEvent() {
#if defined(__WIN64)
		_handle = null;
#endif
	}

	virtual ~WaitableEvent() {
#if defined(__WIN64)
		CloseHandle(_handle);
#endif
	}

	bool wait(unsigned millisecondsWait = INFINITE) {
#if defined(__WIN64)
		DWORD value = WaitForSingleObject(_handle, millisecondsWait);
		return value == WAIT_OBJECT_0;
#endif
	}

protected:
#if defined(__WIN64)
	HANDLE	_handle;
#endif
};

class SignalingEvent : public WaitableEvent {
public:
	SignalingEvent() {
#if defined(__WIN64)
		_handle = CreateEvent(null, FALSE, FALSE, null);
#endif
	}

	void signal() {
#if defined(__WIN64)
		SetEvent(_handle);
#endif
	}
};

class Semaphore : public WaitableEvent {
public:
	static const int MAX_COUNT = int(~0u >> 1);

	Semaphore(int initialCount, int maximumCount = MAX_COUNT) {
#if defined(__WIN64)
		_handle = CreateSemaphore(null, initialCount, maximumCount, null);
#endif
	}

	void release() {
#if defined(__WIN64)
		ReleaseSemaphore(_handle, 1, null);
#endif
	}
};

#if 0
int wait2(WaitableEvent* a, WaitableEvent* b, unsigned millisecondsWait = INFINITE);

class ThreadPool {
public:
	ThreadPool(int threadCount);

	~ThreadPool();

	bool run(void (*func)()) {
		Handler* h = new FunctionHandler(func);
		if (!enqueue(h, false)) {
			delete h;
			return false;
		} else
			return true;
	}

	template<class T>
	bool run(T* object, void (T::*func)()) {
		Handler* h = new ObjectHandler<T>(object, func);
		if (!enqueue(h, false)) {
			delete h;
			return false;
		} else
			return true;
	}

	template<class T, class M>
	bool run(T* object, void (T::*func)(M), M m) {
		Handler* h = new Object1Handler<T, M>(object, func, m);
		if (!enqueue(h, false)) {
			delete h;
			return false;
		} else
			return true;
	}

	bool busy();

	void flushActions();

	Event				idle;

	/*
	 *	runOne
	 *
	 *	If an action is ready, it is run on this
	 *	thread immediately and then control returns
	 *	from this function.
	 *
	 *	If no action is ready, the thread will wait
	 *	until an action is available or until
	 *	any 'interruptWhen' event happens.
	 *
	 *	RETURNS:
	 *		true if either an interruptWhen event happened
	 *		or an action was run.  Returns false if no action
	 *		could be run (because none were ready and no
	 *		threads were busy).
	 */
	bool runOne(WaitableEvent* interruptWhen = null);

	int idleThreads() const { return _idleThreads; }

private:
	class Handler {
	public:
		virtual void run() = 0;

		class Handler*		next;
	};

	class FunctionHandler : public Handler {
	public:
		FunctionHandler(void (*func)()) {
			_func = func;
		}

		virtual void run() {
			_func();
		}

	private:
		void (*_func)();
	};

	template<class T>
	class ObjectHandler : public Handler {
	public:
		ObjectHandler(T* object, void (T::*func)()) {
			_object = object;
			_func = func;
		}

		virtual void run() {
			(_object->*_func)();
		}

	private:
		T* _object;
		void (T::*_func)();
	};

	template<class T, class M>
	class Object1Handler : public Handler {
	public:
		Object1Handler(T* object, void (T::*func)(M), M m) {
			_object = object;
			_func = func;
			_m = m;
		}

		virtual void run() {
			(_object->*_func)(_m);
		}

	private:
		T* _object;
		void (T::*_func)(M);
		M _m;
	};

	static void loop(ThreadPool* tp);

	void stop();

	bool enqueue(Handler* h, bool duringShutdown);

	Handler* dequeue();

	Handler* takeOne(WaitableEvent* interruptWhen = null);

	Semaphore				_actionQueue;
	Mutex					_lock;
	vector<Thread*>			_threads;
	Handler*				_actions;			// guarded by _lock
	int						_idleThreads;		// guarded by _lock
	Semaphore*				_shutdownSemaphore;	// guarded by _lock
	int						_waitingThreads;
};
#endif

int debugSpawn(const string& cmd, string* captureData, exception_t* exception, time_t timeout);

int debugSpawnInteractive(const string& cmd, string* captureData, exception_t* exception, string stdin, time_t timeout);

#if defined(__WIN64)
const DWORD WINDOWS_ABORT_EXCEPTION = 0xc1000001;
const DWORD WINDOWS_DEBUGGER_TERMINATED = 0xc3770001;
#endif

extern Process me;

#if 0
string binaryFilename();
#endif

Thread* currentThread();

#if defined(__WIN64)
void dumpExceptionRecord(const EXCEPTION_RECORD *xr, int firstChance);
#endif
}  // namespace process
