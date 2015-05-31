#include "../common/platform.h"
#include "process.h"

#include <windows.h>
#include "machine.h"
#include "file_system.h"

namespace process {

static const int MS_VC_EXCEPTION = 0x406d1388;
static void	drain(HANDLE reader, string* captureData);
static void dumpException(const DEBUG_EVENT& dbg, unsigned processId);
static const char* exceptionName(DWORD x);
static void initStartupInfo(STARTUPINFO* info, HANDLE stdoutHandle, HANDLE stderrHandle);
static int monitorDebugEvents(HANDLE hProcess, unsigned processId, exception_t* exception, time_t timeout);

const char* exceptionNames[] = {
	"NO_EXCEPTION",
	"ABORT",
	"BREAKPOINT",
	"TIMEOUT",
	"TOO_MANY_EXCEPTIONS",
	"ACCESS_VIOLATION",
	"UNKNOWN_EXCEPTION"
};

Process me;

Process::Process() {
	_tlsIndex = TlsAlloc();

	Thread* t = new Thread();

	t->_hThread = GetCurrentThread();
	t->_threadId = GetCurrentThreadId();
	setTls(t);
}

Process::~Process() {
	delete getTls();
}

void Process::setTls(Thread* t) {
	if (_tlsIndex != TLS_OUT_OF_INDEXES)
		TlsSetValue(_tlsIndex, t);
}

Thread* Process::getTls() {
	if (_tlsIndex != TLS_OUT_OF_INDEXES)
		return (Thread*)TlsGetValue(_tlsIndex);
	else
		return null;
}

Thread* currentThread() {
	return me.getTls();
}

Pipe::Pipe() {
	if (CreatePipe(&_reader, &_writer, null, 0) == FALSE) {
		_reader = INVALID_HANDLE_VALUE;
		_writer = INVALID_HANDLE_VALUE;
	}
}

Thread::Thread() {
	_threadId = 0;
	_hThread = null;
	_handler = null;
	_local = 0;
}

Thread::~Thread() {
	_locals.deleteAll();
	delete _handler;
}

void Thread::start() {
	_hThread = CreateThread(null, 0, threadProc, (void*)this, 0, &_threadId);
}

DWORD WINAPI Thread::threadProc(void* data) {
	Thread* t = (Thread*)data;

	t->_handler->start();
	me.setTls(t);
	return 0;
}

ThreadPool::ThreadPool(int threadCount) : _actionQueue(0) {
	_actions = null;
	_idleThreads = 0;
	_waitingThreads = 0;
	_shutdownSemaphore = null;
	for (int i = 0; i < threadCount; i++)
		_threads.push_back(Thread::start(&ThreadPool::loop, this));
}

ThreadPool::~ThreadPool() {
	ObjectHandler<ThreadPool> stopHandler(this, &ThreadPool::stop);

	{
		MutexLock m(&_lock);
		_shutdownSemaphore = new Semaphore(0);
		flushActions();
	}
	for (int i = 0; i < _threads.size(); i++) {
		enqueue(&stopHandler, true);
		_shutdownSemaphore->wait();
	}
	delete _shutdownSemaphore;
	_threads.deleteAll();
}

void ThreadPool::stop() {
	_shutdownSemaphore->release();
	// This won't return, which we rely on so that the shutdown
	// stopHandler doesn't get deleted.
	ExitThread(0);
}

bool ThreadPool::busy() {
	MutexLock m(&_lock);

	// There is a race condition where a thread pool may have all
	// threads 'idle' but there is work queued.  This can happen
	// because all threads could have piled up at the semaphore
	// after they incremented their own idle count, but before
	// they re-acquired the lock that will allow them to collect
	// the pending _actions.  Therefore, the idle thread count is
	// really an 'at most' count of idle threads.
	if (_idleThreads != _threads.size())
		return true;
	else
		return _actions != null;
}

void ThreadPool::flushActions() {
	MutexLock m(&_lock);

	while (_actions != null) {
		Handler* a = _actions;
		_actions = a->next;
		delete a;
	}
}

bool ThreadPool::runOne(WaitableEvent* interruptWhen) {
	{
		MutexLock m(&_lock);

		_waitingThreads++;
		if (_idleThreads + _waitingThreads == _threads.size() && _actions == null) {
			_waitingThreads--;
			return false;
		}
	}
	Handler* h = takeOne(interruptWhen);
	{
		MutexLock m(&_lock);

		_waitingThreads--;
		_idleThreads++;			// to counteract the decrement inside takeOne
	}
	if (h != null) {
		h->run();
		delete h;
	}
	return true;
}

bool ThreadPool::enqueue(Handler* h, bool duringShutdown) {
	{
		MutexLock m(&_lock);

		if (_shutdownSemaphore && !duringShutdown)
			return false;
		h->next = null;
		if (_actions == null)
			_actions = h;
		else {
			for (Handler* last = _actions; ; last = last->next) {
				if (last->next == null) {
					last->next = h;
					break;
				}
			}
		}
	}
	_actionQueue.release();
	return true;
}

ThreadPool::Handler* ThreadPool::dequeue() {
	{
		MutexLock m(&_lock);

		_idleThreads++;
		// The idle threads count may count threads that are actually
		// about to pick up a new action to do.  If actions are posted
		// asynchronously from non-worker threads, this idle condition
		// may be transient.  The usage of the thread pool will determine
		// whether an 'idle' event represents a permanent or transient
		// condition.
		if (_idleThreads == _threads.size() && _actions == null)
			idle.fire();
	}
	return takeOne();
}

ThreadPool::Handler* ThreadPool::takeOne(WaitableEvent* interruptWhen) {
	int result = wait2(&_actionQueue, interruptWhen);
	{
		MutexLock m(&_lock);

		_idleThreads--;
		if (result == 1)
			return null;
		Handler* h = _actions;
		if (h)
			_actions = h->next;
		return h;
	}
}

void ThreadPool::loop(ThreadPool* tp) {
	for (;;) {
		Handler* h = tp->dequeue();
		if (h == null)
			break;
		h->run();
		delete h;
	}
}

int wait2(WaitableEvent* a, WaitableEvent* b, unsigned millisecondsWait) {
	if (a == null) {
		if (b == null)
			return -1;
		else {
			DWORD result = WaitForSingleObject(b->_handle, millisecondsWait);
			if (result == WAIT_OBJECT_0)
				return 0;
			else
				return -1;
		}
	} else if (b == null) {
		DWORD result = WaitForSingleObject(a->_handle, millisecondsWait);
		if (result == WAIT_OBJECT_0)
			return 0;
		else
			return -1;
	} else {
		HANDLE handles[2];
		handles[0] = a->_handle;
		handles[1] = b->_handle;
		DWORD result = WaitForMultipleObjects(2, handles, FALSE, millisecondsWait);
		if (result == WAIT_TIMEOUT)
			return -1;
		else
			return result - WAIT_OBJECT_0;
	}
}

string binaryFilename() {
	char filename[FILENAME_MAX + 1];
	GetModuleFileName(NULL, filename, sizeof filename);
	return string(filename);
}

int debugSpawn(const string& cmd, string* captureData, exception_t* exception, time_t timeout) {
	PROCESS_INFORMATION pinfo;
	STARTUPINFO info;
	Pipe pipe;
	
	SetHandleInformation(pipe.reader(), HANDLE_FLAG_INHERIT, 0);
	initStartupInfo(&info, pipe.writer(), pipe.writer());
	BOOL result = CreateProcess(null, (LPSTR)cmd.c_str(), null, null, TRUE,
													DEBUG_PROCESS, null/*environment*/, null, &info, &pinfo);
	CloseHandle(pipe.writer());
	if (result == FALSE){
		CloseHandle(pipe.reader());
		return -1;
	} else {
		Thread* t = Thread::start(drain, pipe.reader(), captureData);
		int exitValue = monitorDebugEvents(pinfo.hProcess, pinfo.dwProcessId, exception, timeout);
		WaitForSingleObject(t->hThread(), INFINITE);
		delete t;
		return exitValue;
	}
}

static void initStartupInfo(STARTUPINFO* info, HANDLE stdoutHandle, HANDLE stderrHandle) {
	fflush(stdout);
	fflush(stderr);

	info->cb = sizeof (STARTUPINFO);
	info->lpReserved = null;
	info->lpDesktop = null;;
	info->lpTitle = null;
	info->dwX = 0;
	info->dwY = 0;
	info->dwXSize = 0;
	info->dwYSize = 0;
	info->dwXCountChars = 0;
	info->dwYCountChars = 0;
	info->dwFillAttribute = 0;
	info->dwFlags = STARTF_USESTDHANDLES;
	info->wShowWindow = 0;
	info->cbReserved2 = 0;
	info->lpReserved2 = null;
	info->hStdInput = GetStdHandle(STD_INPUT_HANDLE);
	if (stdoutHandle != null) {
		info->hStdOutput = stdoutHandle;
		SetHandleInformation(stdoutHandle, HANDLE_FLAG_INHERIT, 1);
	} else
		info->hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
	if (stderrHandle != null) {
		info->hStdError = stderrHandle;
		SetHandleInformation(stderrHandle, HANDLE_FLAG_INHERIT, 1);
	} else
		info->hStdError = GetStdHandle(STD_ERROR_HANDLE);
}
/*	
	dumpData: ref[DumpData]
*/	
static int monitorDebugEvents(HANDLE hProcess, unsigned processId, exception_t* exception, time_t timeout) {
	bool sawAnException = false;
	bool loaderBreakpointHit = false;
	int totalExceptions = 0;
	DWORD otherProcessId = 0;
	int totalOtherExceptions = 0;
	
	for (;;) {
		DEBUG_EVENT dbg;
		fflush(stdout);
		
		time_t millis = timeout * 1000;
		DWORD wTimeout;
		if (timeout <= 0 || millis > INFINITE)
			wTimeout = INFINITE;
		else
			wTimeout = DWORD(millis);
		BOOL result = WaitForDebugEvent(&dbg, wTimeout);
		if (result == FALSE) {
			// This is probably a timeout, any other error probably deserves this
			// treatment too.
			TerminateProcess(hProcess, WINDOWS_DEBUGGER_TERMINATED);
			*exception = TIMEOUT;
			return -2;
		}
		if (result == FALSE) {
			printf("Unexpected FALSE from WaitForDebugEvent\n");
			exit(1);
		}
		DWORD handling = DBG_EXCEPTION_NOT_HANDLED;
		switch (dbg.dwDebugEventCode) {
		case	EXCEPTION_DEBUG_EVENT:
			{
				if (dbg.dwProcessId != processId){
					if (otherProcessId != dbg.dwProcessId){
						otherProcessId = dbg.dwProcessId;
						totalOtherExceptions = 0;
					} else {
						totalOtherExceptions++;
	//						dumpData = new DumpData(&dbg, processId, dumpData)
						if (totalOtherExceptions > 100) {
							HANDLE pHandle = OpenProcess(PROCESS_TERMINATE, FALSE, dbg.dwProcessId);
							TerminateProcess(pHandle, WINDOWS_DEBUGGER_TERMINATED);
							CloseHandle(pHandle);
							*exception = TOO_MANY_EXCEPTIONS;
							sawAnException = true;
							break;
						}
					}
					break;
				}
				EXCEPTION_DEBUG_INFO& ue = dbg.u.Exception;
				DWORD e = ue.ExceptionRecord.ExceptionCode;
				if (e == WINDOWS_ABORT_EXCEPTION) {
					totalExceptions++;
					*exception = ABORT;
				} else if (e == 0x80000003) {
					if (!loaderBreakpointHit) {
						loaderBreakpointHit = true;
						handling = DBG_CONTINUE;
						break;
					}
					totalExceptions++;
					*exception = BREAKPOINT;
				} else if (e == STATUS_ACCESS_VIOLATION) {
					if (ue.dwFirstChance != 0)
						break;
					*exception = ACCESS_VIOLATION;
					dumpException(dbg, processId);
					TerminateProcess(hProcess, WINDOWS_DEBUGGER_TERMINATED);
				} else if (e == MS_VC_EXCEPTION) {			// VC++ 5 debugger exception - ignore it.
					break;
				} else {
					if (ue.dwFirstChance != 0)
						break;
					dumpException(dbg, processId);
					*exception = UNKNOWN_EXCEPTION;
					totalExceptions++;
				}
				sawAnException = true;
				if (totalExceptions > 100) {
	//				printf("Too many exceptions captured - abandoning all hope\n");
					TerminateProcess(hProcess, WINDOWS_DEBUGGER_TERMINATED);
					*exception = TOO_MANY_EXCEPTIONS;
					sawAnException = true;
					break;
				}
			}
			break;
		
		case	CREATE_PROCESS_DEBUG_EVENT:
			{
				CREATE_PROCESS_DEBUG_INFO& cpe = dbg.u.CreateProcessInfo;
				if (CloseHandle(cpe.hFile) == FALSE) {
					printf("Could not close process image file handle %x\n", cpe.hFile);
					exit(1);
				}
			}
			break;
			
		case	EXIT_PROCESS_DEBUG_EVENT:
			if (dbg.dwProcessId == processId) {
				ContinueDebugEvent(dbg.dwProcessId, dbg.dwThreadId, DBG_CONTINUE);
/*
				if (dumpData != null) {
					dumpData.dump();
					printf("totalExceptions: %d\n", totalExceptions);
				}
 */
				if (sawAnException)
					return -2;
				else
					return dbg.u.ExitProcess.dwExitCode;
			}
			break;
			
		case	LOAD_DLL_DEBUG_EVENT:
			{
				LOAD_DLL_DEBUG_INFO& le = dbg.u.LoadDll;
//				if (le.lpImageName != null){
//					s: string = null
				
//					if (!readProcessString(hProcess, le.lpImageName, &s, le.fUnicode))
//						print("Could not read DLL name from image at " + text.toHex(*pointer[int](&le.lpImageName)))
//					else if (s == null)
//						print("*image pointer in DLL is NULL")
//					else
//						print("Loading DLL " + s)
//				}
				if (CloseHandle(le.hFile) == FALSE) {
					printf("Could not close process image file handle %x\n", le.hFile);
					exit(1);
				}
			}
			break;
		}
		ContinueDebugEvent(dbg.dwProcessId, dbg.dwThreadId, handling);
	}
}
/*	
	DumpData: type = struct {
		dbg: windows.DEBUG_EVENT
		processId: unsigned
		next: ref[DumpData]
		
		new: (dbg: pointer[windows.DEBUG_EVENT], processId: unsigned, next: ref[DumpData])
		{
			this.dbg = *dbg
			this.processId = processId
			this.next = next
		}
		
		dump: function ()
		{
			if (next != null)
				next.dump()
			dumpException(&dbg, processId)
		}
	}
 */
static void dumpException(const DEBUG_EVENT& dbg, unsigned processId) {
	printf("    Pid: %d", dbg.dwProcessId);
	if (dbg.dwProcessId == processId)
		printf(" (spawned process)");
	const EXCEPTION_RECORD& xr = dbg.u.Exception.ExceptionRecord;
	dumpExceptionRecord(&dbg.u.Exception.ExceptionRecord, dbg.u.Exception.dwFirstChance);
	printf("\n");
}

void dumpExceptionRecord(const EXCEPTION_RECORD *xr, int firstChance) {
	printf(" Exception: %x '%s'", xr->ExceptionCode, exceptionName(xr->ExceptionCode));
	printf(" FirstChance: %d", firstChance);
	printf(" Address: %x flags: %x", xr->ExceptionAddress, xr->ExceptionFlags);

	// breakpoint exceptions don't use ExceptionInformation
	if (xr->ExceptionCode != 0x80000003){
		if (xr->ExceptionInformation[0] == 0)
			printf(" reading");
		else if (xr->ExceptionInformation[0] == 1)
			printf(" writing");
		else if (xr->ExceptionInformation[0] == 8)
			printf(" user mode DEP");
		else {
			printf(" unknown cause (%x)\n", xr->ExceptionInformation[0]);
			return;
		}
		printf(" @%8.8x", xr->ExceptionInformation[1]);
	}
}

static void drain(HANDLE inStream, string* output) {
	char buffer[4096];

	for (;;) {
		DWORD n;
		if (ReadFile(inStream, buffer, sizeof buffer, &n, null) == FALSE) {
			CloseHandle(inStream);
			return;
		}
		if (n > 0)
			output->append(buffer, n);
	}
}

static const char* exceptionName(DWORD x) {
	switch (x) {
	case	0x80000003:							return "breakpoint";
	case	0xc1000001:							return "process.abort";
	case	STATUS_ACCESS_VIOLATION:			return "ACCESS_VIOLATION";
	case	STATUS_IN_PAGE_ERROR:				return "IN_PAGE_ERROR";
	case	STATUS_INVALID_HANDLE:				return "INVALID_HANDLE";
	case	STATUS_NO_MEMORY:					return "NO_MEMORY";
	case	STATUS_ILLEGAL_INSTRUCTION:			return "ILLEGAL_INSTRUCTION";
	case	STATUS_NONCONTINUABLE_EXCEPTION:	return "NONCONTINUABLE_EXCEPTION";
	case	STATUS_INVALID_DISPOSITION:			return "INVALID_DISPOSITION";
	case	STATUS_ARRAY_BOUNDS_EXCEEDED:		return "ARRAY_BOUNDS_EXCEEDED";
	case	STATUS_FLOAT_DENORMAL_OPERAND:		return "FLOAT_DENORMAL_OPERAND";
	case	STATUS_FLOAT_DIVIDE_BY_ZERO:		return "FLOAT_DIVIDE_BY_ZERO";
	case	STATUS_FLOAT_INEXACT_RESULT:		return "FLOAT_INEXACT_RESULT";
	case	STATUS_FLOAT_INVALID_OPERATION:		return "FLOAT_INVALID_OPERATION";
	case	STATUS_FLOAT_OVERFLOW:				return "FLOAT_OVERFLOW";
	case	STATUS_FLOAT_STACK_CHECK:			return "FLOAT_STACK_CHECK";
	case	STATUS_FLOAT_UNDERFLOW:				return "FLOAT_UNDERFLOW";
	case	STATUS_INTEGER_DIVIDE_BY_ZERO:		return "INTEGER_DIVIDE_BY_ZERO";
	case	STATUS_INTEGER_OVERFLOW:			return "INTEGER_OVERFLOW";
	case	STATUS_PRIVILEGED_INSTRUCTION:		return "PRIVILEGED_INSTRUCTION";
	case	STATUS_STACK_OVERFLOW:				return "STACK_OVERFLOW";
	case	STATUS_CONTROL_C_EXIT:				return "CONTROL_C_EXIT";
//	case	STATUS_FLOAT_MULTIPLE_FAULTS:		return "FLOAT_MULTIPLE_FAULTS";
//	case	STATUS_FLOAT_MULTIPLE_TRAPS:		return "FLOAT_MULTIPLE_TRAPS";
//	case	STATUS_REG_NAT_CONSUMPTION:			return "REG_NAT_CONSUMPTION";
	default:									return "* unknown exception *";
	}
}

}  // namespace process
