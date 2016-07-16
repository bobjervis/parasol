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
import parasol:exception.hardwareExceptionHandler;

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

private abstract address dupExecutionContext();
private abstract void enterThread(address newContext, address stackTop);
private abstract void exitThread();
