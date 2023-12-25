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
import parasol:exception;
import parasol:exception.IllegalOperationException;
import parasol:log;
import parasol:process;
import parasol:pbuild.Application;
import parasol:pbuild.Coordinator;
import parasol:pbuild.thisOS;
import parasol:pbuild.thisCPU;
import parasol:pxi;
import parasol:runtime;
import parasol:storage;
import parasol:thread;
import parasol:x86_64;

import native:linux;
import native:linux.elf;

logger := log.getLogger("pbug.debug");

public void spawnParasolScript(string parasolLocation, string exePath, string... arguments) {
	session.perform(new SpawnParasolScript(parasolLocation, exePath, arguments));
}

enum ProcessState {
	RUNNING,			// All threads in the process are running.
	STOPPED,			// The process is not running, all threads are stopped. The process data state can be inspected.
	EXIT_CALLED,		// The process has called exit, but the debugger event has not returned, so the process 
						// is in a 'pre-zombie' state.
	EXITED				// Process has been cleaned up.
}

monitor class EventActions {
	class Event {
		ref<Monitor> _monitor;

		boolean checkThread(ref<ThreadInfo> t) {
			return false;
		}
	}

	class ProcessStoppedEvent extends Event {
		ref<TracedProcess> _process;

		ProcessStoppedEvent(ref<TracedProcess> p, ref<Monitor> m) {
			_process = p;
			_monitor = m;
		}

		boolean checkThread(ref<ThreadInfo> t) {
			if (_process == t.process()) {
				if (_process.state() != ProcessState.RUNNING) {
//					logger.info("checkThread tid %d %s pid %d %s", t.tid(), string(t.state()), _process.id(), string(_process.state()));
					_monitor.notify();
					return true;
				}
			}
			return false;
		}
	}

	ref<Event>[] _events;

	void onProcessStopped(ref<TracedProcess> p, ref<Monitor> m) {
		if (p.state() != ProcessState.RUNNING)
			m.notify();
		else
			_events.append(new ProcessStoppedEvent(p, m));
	}

	void reportThreadStopped(ref<ThreadInfo> t) {
		for (i in _events) {
			e := _events[i];
			if (e.checkThread(t)) {
				_events.remove(i);
				delete e;
			}
		}
	}
}

EventActions actions;

enum StopAction {
	PAUSE,
	STOP,
	NOT_STOPPED,
}

//Monitor pause;

void eventsHandler(address unused) {
	for (;;) {
//		boolean pauseBeforeContinue;
		int tid;
		debug.DebugEvent de;
		int extra;
		ref<TracedProcess> p;
		if (session.stopEvents())
			break;
		try {
			(tid, de, extra) = debug.eventWait();
//			logger.info("--** tid %d de %s extra %d", tid, string(de), extra);
		} catch (IllegalOperationException e) {
			logger.error("%s - no more events", e.message());
			session.perform(new CleanupEventsHandler());
			break;
		}
		t := session.findThread(tid);
		if (t != null)
			p = t.process();
		switch (de) {
		case EXIT:
			if (p == null) {
				logger.warn("Unexpected EXIT event: tid %d extra %d", tid, extra);
				continue;
			}
			p.reportExit(extra);
			n := session.notifier();
			if (n != null)
				n.exit(tid, extra);
			break;

		case STOPPED:
			if (p == null) {
				// This may arrive before the 'new thread' event gets around to discovering the thread id
				session.threadStopped(tid);
				continue;
			}
			switch (p.reportStopped(tid, extra)) {
			case PAUSE:
				// The stop event requires diagnosis before another event-wait can be done
//				pauseBeforeContinue = true;
			case STOP:
				n = session.notifier();
				if (n != null)
					n.stopped(p.id(), tid, extra);
				if (t != null)
					actions.reportThreadStopped(t);
			}
			break;

		case NEW_THREAD:
			// An existing thread in the process that will own some new thread report the clone.
			p.reportNewThread(tid);
			break;

		case EXEC:
			if (p == null) {
				logger.warn("Unexpected EXEC event: tid %d extra %d", tid, extra);
				continue;
			}
			if (p.reportExec(t)) {
				n = session.notifier();
				if (n != null)
					n.exec(tid);
			}
			break;

		case SYSCALL:
			if (p == null) {
				logger.warn("Unexpected SYSCALL event: pid %d extra %d", tid, extra);
				continue;
			}
			p.reportSyscall(tid);
			n = session.notifier();
			if (n != null)
				n.afterExec(tid);
			break;

		case EXIT_CALLED:
			if (p == null) {
				logger.warn("Unexpected EXIT_CALLED event: pid %d extra %d", tid, extra);
				continue;
			}
			p.reportExitCalled(tid);
			n = session.notifier();
			if (n != null)
				n.exitCalled(tid);
			break;

		case KILLED:
			if (p == null) {
				logger.warn("Unexpected KILLED event: pid %d extra %d", tid, extra);
				continue;
			}
			p.reportKilled(extra);
			n = session.notifier();
			if (n != null)
				n.killed(tid, extra);
			break;

		case INTERRUPTED:
			logger.info("Interrupt!");
			break;

		default:
			throw IllegalOperationException(tid + " de " + string(de) + " unexpected");
		}
//		if (pauseBeforeContinue)
//			pause.wait();
	}
}

class TracedProcess extends debug.Process {
	ref<thread.Thread> _eventHandler;
	ref<ElfFile>[string] _elfMap;
	ref<MemoryMap> _memoryMap;
	long _threadContextAddress;
	boolean _threadContextResolved;

	TracedProcess() {
		_state = ProcessState.RUNNING;
		_stale = true;
	}

	ProcessState _state;
	int _exitCode;
	int _killSig;
	boolean _hardFault;					// If true, the process is winding down from a hard fault
										// while the faul diagnosis is underway,
	boolean _stale;

	map<ref<ThreadInfo>, int> _threads;

	public void reportExit(int exitCode) lock (*this) {
		_exitCode = exitCode;
		_state = ProcessState.EXITED;		// 
		for (tid in _threads) {
			t := _threads[tid];
			t.reportExit(exitCode);
		}
	}

	public StopAction reportStopped(int tid, int signal) lock (*this) {
		t := _threads[tid];
		if (t == null)
			return StopAction.NOT_STOPPED;
		if (t.reportStopped(signal)) {
			session.perform(new InitialStop(t));
			return StopAction.NOT_STOPPED;
		} else {
			switch (signal) {
			case linux.SIGSEGV:
				session.perform(new HardFault(t));
				return StopAction.PAUSE;
			}
			return StopAction.STOP;
		}
	}

	public boolean reportExec(ref<ThreadInfo> t) lock (*this) {
		t.reportStopped(0);
		de := interpretExec();
		switch (de) {
		case EXEC:
			logger.info("pid %d: EXEC", id());
			break;

		case INITIAL_EXEC:
			session.perform(new InitialExec(this));
			return false;

		default:
			logger.error("pid %d: Unknown interpretExec value: %s", id(), string(de));
		}
		return true;
	}

	public void reportSyscall(int tid) lock (*this) {
		t := _threads[tid];
		if (t == null)
			return;

		t.reportStopped(0);
		session.perform(new Syscall(t));
	}

	public void reportNewThread(int reportingTid) lock (*this) {
		t := _threads[reportingTid];
		if (t == null) {
			logger.error("Unexpected reportNewThread reporting tid %d", reportingTid);
			return;
		}

//		t.reportStopped(0);
		session.perform(new NewThread(this, reportingTid));
	}

	public int addThread(int tid) lock (*this) {
		if (_threads.contains(tid)) {
			logger.error("Process %d has a new (duplicate) thread %d", id(), tid);
			return -1;
		}
		t := new ThreadInfo(this, tid);
		session.declareThread(t);
		_threads[tid] = t;
		if (session.pullStoppedThread(tid)) {
			t.reportStopped(0);
			t.run();
		}
		n := session.notifier();
		if (n != null)
			n.newThread(id(), tid);
		return tid;
	}

	public boolean containsThread(int tid) lock (*this) {
		return _threads.contains(tid);
	}

	public ref<ThreadInfo> getThread(int tid) lock (*this) {
		return _threads[tid];
	}

	public ThreadInfo[] getThreads() lock (*this) {
		ThreadInfo[] results;
		for (tid in _threads) {
			t := _threads[tid];
			if (t.state() != ProcessState.EXITED)
				results.append(*t);
		}
		return results;
	}

//	public void syscall() lock (*this) {
//		
//	}

	public void reportExitCalled(int tid) lock (*this) {
		t := _threads[tid];
		if (t == null)
			return;

		_state = ProcessState.EXIT_CALLED;
		t.reportExitCalled();
		session.perform(new ExitCalled(this));
	}

	public void reportKilled(int signal) lock (*this) {
		_state = ProcessState.EXITED;
		_exitCode = -1;
		_killSig = signal;
	}

	public void fetchExitCalledInfo() {
		(_exitCode, _killSig) = controller.getExitInformation(id());
		logger.info("   process %d exit called status %d termination signal %d", id(), _exitCode, _killSig);
	}

	public ref<MemoryMap> loadMemory() {
		if (_stale) {
			delete _memoryMap;
			_memoryMap = null;
			_stale = false;
		}
		if (_memoryMap == null)
			_memoryMap = MemoryMap.load(this);
		return _memoryMap;
	}

	public void showFileMemory(string pattern) {
		mm := loadMemory();
		if (mm == null) {
			printf("Could not access memory map for process %s\n", id());
			return;
		}
		st := state();
		if (st == ProcessState.STOPPED || st == ProcessState.EXIT_CALLED)
			mm.printFile(this, pattern);
		else
			printf("Process %d cannot be viewed\n", id());
	}

	/**
	 * Run all the threads in the process.
	 */
	public boolean run() lock (*this) {
		if (_hardFault)
			return false;
		success := true;
		for (tid in _threads) {
			t := _threads[tid];
			if (t.state() == ProcessState.STOPPED) {
				if (!t.run()) {
					logger.error("Could not start thread %d in process %d", t.tid());
					success = false;
				} else
					_stale = true;
			}
		}
		return success;
	}

	public void stopAllThreads(boolean hardFault) lock (*this) {
		_hardFault = hardFault;
		for (tid in _threads) {
			t := _threads[tid];
			if (t.state() == ProcessState.RUNNING) {
				if (!t.stop())
					logger.error("Could not stop thread %d in process %d", t.tid());
			}
		}
	}

	public void clearHardFault() lock (*this) {
		_hardFault = false;
	}

	public ProcessState state() {
		switch (_state) {
		case EXIT_CALLED:
		case EXITED:
			return _state;

		default:				// RUNNING
			for (tid in _threads) {
				t := _threads[tid];
				if (t.state() == ProcessState.RUNNING)
					return ProcessState.RUNNING;
			}
		}
		return ProcessState.STOPPED;
	}

	public int exitStatus() {
		return _exitCode;
	}
	/**
	 * Fetch a consensus stop signal.
	 *
	 * @return The signal number of the signal that caused any thread in the process. 
	 * If more than one signal caused stoppage, -1 is returned. If no thread is stopped
	 * or if all that are stopped had no associated signal, the return alue is zero.
	 */
	public int stopSig() {
		int stopSig;
		for (tid in _threads) {
			t := _threads[tid];
			if (t.state() == ProcessState.STOPPED &&
				t.stopSig() != 0) {
				if (stopSig != 0 && stopSig != t.stopSig())
					return -1;
				stopSig = t.stopSig();
			}
		}
		return stopSig;
	}
	/**
	 * Find a symbol defined for the given machine address.
	 *
	 * There are three possible outcomes:
	 *
	 *	- An ELF symbol was found for the address parameter.
	 *	- A Parasol source location was found for the address parameter.
	 *	- No symbol was found for the address paramter.
	 *
	 * @return The Elf64_Sym, if any, for any symbol found.
	 * @return If the first return value is not null, this is the ELF symbol name.
	 * For C++ symbols, this is a mangled name.
	 * If the first return value is null and this value is not null, it is a
	 * Parasol source location.
	 * If both the first and second return expressions are null, no symbols was found.
	 * @return If a ELF symbol was location, this is the relative offset within that symbol of the address
	 * parameter.
	 * If a Parasol source location was found, the offset is always 0.
	 * If neither was found, the value is an 'reason' for no symbol being found:
	 *
	 * </ul>
	 *		<li>-1 The ELF file named in the memory segment has no symbols.
	 *		<li>-2 The strings segment for the symbol table in the ELF file is invalid.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-3 The link from the symbol table names a non-strings section header.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-4 The offset of the symbol table's string section header is invalid.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-5 The offset of the symbol table's section header is invalid.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-6 None of the symbols defined in the ELF file's symbol table enclosed
	 *		the given address.
	 *		<li>-10 The address is not in mapped memory. No memory segment encloses this
	 *		address.
	 *		<li>-11 The memory map for this address does not name an ELF file.
	 *		This is likely to be because the segment is in a memory-mapped data file.
	 *		<li>-12 The address lies within an anonymous memory segment, like a thread stack,
	 *		or the heap.
	 *		<li>-13 The ELF file has no LOAD program table entries.
	 *		This indicates a possibly corrupted ELF file.
	 *		<li>-14 The Parasol image this address lies within could not be copied into 
	 *		local memory.
	 */
	public ref<elf.Elf64_Sym>, string, long findSymbol(long addr) {
//		logger.info("    _process.findSymbol(%x)", addr);
		mm := loadMemory();
		seg := mm.findSegment(addr);
		if (seg == null) {
//			logger.info("    Target address is not in mapped memory (%p)", addr);
			return null, null, -10;
		}
		if (seg.file != null) {
			e := seg.file.reader();
			if (e == null) {
//				logger.info("    Target address %x is in a non-ELF file, %s. (%s)", addr, seg.filename, string(seg.file.type()));
				return null, null, -11;
			}
			header := e.header();
			success := false;
			baseAddress := seg.start;
			for (int i = 0; i < header.e_phnum; i++) {
				ph := e.programHeader(i);
				if (ph.p_type == 1) {
//					logger.info("    ph %d Elf vaddr is %p / target address %x", i, ph.p_vaddr, addr);
					success = true;
					baseAddress += ph.p_vaddr;
//					logger.info("    baseAddress of symbols %p Target address %x segment relative offset %x", baseAddress, addr, 
//									addr - baseAddress);
					dynsym := e.dynsym();
					symtab := e.symtab();
/*
					if (symtab != null)
						logger.info("    Binary %s has symbols in segment %d", seg.filename, symtab);
					else if (dynsym != null)
						logger.info("    Binary %s has only dynammic link symbols in segment %d", seg.filename, dynsym);
					else
						logger.info("    Binary %s has no symbol information at all", seg.filename);
 */
					ref<elf.Elf64_Sym> sym;
					string name;
					long offset;
					(sym, name, offset) = e.findSymbol(addr - baseAddress);
/*
					if (sym != null)
						logger.info("    Symbol found at %s+%d (%p)", name, offset, addr);
					else
						logger.info("    No symbol for address %p: cause %d", addr, offset);
 */
					return sym, name, offset;
				}
			}
//			logger.info("    File %s has no LOAD program header entries", seg.filename);
			return null, null, -13;
		} else if (seg.prot == Protections.ALL) {
//			logger.info("    Target address %p is possibly in a Parasol image (image offset = %x)", addr, addr - seg.start);
			image := seg.loadImage(id());
			if (image == null)
				return null, null, -14;
			s := image.formattedLocation(addr, int(addr - seg.start));
			return null, s, 0;
/*
			addr = threadContextAddress();
			if (addr != 0) {
				long contents;
				boolean success;
				(contents, success) = controller.peek(id(), addr);
				if (!success) {
					logger.error("    Could not peek at address %p for tid %d", addr, id());
					return null, null, -7;
				}
				logger.info("    contents = %p @ %p", contents, addr);
				long offset;
				(offset, success) = controller.peek(id(), addr + 8);
				logger.info("    offset = %x", offset);
/*
				mm.print();
				runtime.ExecutionContext ec;
				if (!controller.copy(id(), contents, &ec, ec.bytes)) {
					logger.error("    Could not copy data from pid %d @ %x [%x]", id(), contents, ec.bytes);
					return null, null, -14;
				}
				logger.info("stack top      %x", ec._stackTop);
				logger.info("exception      %x", ec._exception);
				logger.info("pxi header     %x", ec._pxiHeader);
				logger.info("image          %x", ec._image);
				logger.info("argv           %x", ec._argv);
				logger.info("argc           %d.", ec._argc);
				logger.info("thread         %x", ec._parasolThread);
				logger.info("runtime params %x", ec._runtimeParameters);
				logger.info("params count   %d.", ec._runtimeParametersCount);
*/
				return null, null, -8;
			}
			logger.error("    libparasol.so is inconsistent, does not contains parasol::ThreadContext::threadContextValue");
			return null, null, -9;
 */
		}
//		logger.error("    Target address is in an anonymous page (%p)", addr);
		return null, null, -12;
	}

	public long threadContextAddress() {
		if (!_threadContextResolved) {
			_threadContextResolved = true;
			mm := loadMemory();
			f := mm.findFile("libparasol.so", 0);
			if (f == null) {
				logger.warn("    This is not a Parasol program - there is no libparasol.so present");
				return 0;
			}
			e := f.reader();
			logger.info("    reader %p type %s", e, string(f.type()));
			sym := e.findSymbol("_ZN7parasol13ThreadContext19_threadContextValueE");
			if (sym == null) {
				logger.warn("    This is not a Parasol program - the libparasol.so does not have" +
							" parasol::ThreadContext::threadContextValue");
				return 0;
			}
			if ((sym.st_info & 0xf) != 6) {
				logger.warn("    This is not a Parasol program - parasol::ThreadContext::threadContextValue is not TLS");
				return 0;
			}
			if (sym.st_size != 8) {
				logger.warn("    This is not a Parasol program - parasol::ThreadContext::threadContextValue is not a pointer");
				return 0;
			}
			section := e.sectionHeader(sym.st_shndx);
			if (section == null) {
				logger.warn("    This is not a Parasol program - parasol::ThreadContext::threadContextValue has no section header");
				return 0;
			}
			// sym_addr == file-relative offset of this memory location
			//
			sym_addr := sym.st_value + section.sh_addr;
			logger.info("    parasol::ThreadContext::threadContextValue @ file address %p", sym_addr);
			for (int i = 0; ; i++) {
				ph := e.programHeader(i);
				if (ph == null)
					break;
				logger.debug("    ph vaddr = %p symbol %p end = %p", ph.p_vaddr, sym_addr, 
									ph.p_vaddr + ph.p_memsz);
				if (ph.p_type == 1 && 
					ph.p_vaddr <= sym_addr && sym_addr < ph.p_vaddr + ph.p_memsz &&
					(ph.p_flags & 0x7) == 6) {
					seg := f.segment(1);			// This should be the firsst 'data' segment, either a read-only
													// or read-write segment. 
					if (seg == null) {
						logger.error("    libparasol.so should have more than 1 memory segment");
						return 0;			
					}
					if (seg.prot == Protections.READ_ONLY ||
						seg.prot == Protections.READ_WRITE) {
						addr := seg.start + sym_addr - ph.p_vaddr;
						logger.info("    parasol::ThreadContext::threadContextValue @ address %p", addr);
						return addr;
					} else {
						logger.error("    libparasol.so should have a data segment second in the address space");
						return 0;
					}
				}
			}
			logger.error("libparasol.so is inconsistent, no program header contains parasol::ThreadContext::threadContextValue");
		}
		return _threadContextAddress;
	}
}

public class ThreadInfo {
	private ref<TracedProcess> _process;
	private int _tid;
	private ProcessState _state;
	private boolean _stale;				// if true, all registers and detailed state information about this thread is stale
	private boolean _restartNextStop;
	private int _exitCode;
	private int _stopSig;
	private linux.user_regs_struct _registers;

	ThreadInfo(ref<TracedProcess> process, int tid) {
		_process = process;
		_tid = tid;
		_state = ProcessState.RUNNING;
		_restartNextStop = true;
		_stale = true;
	}

	public ThreadInfo() {
	}

	ThreadInfo(ref<ThreadInfo> source) {
		*this = *source;
	}

	void reportExit(int exitCode) {
		if (_state == ProcessState.EXITED)
			return;
		_exitCode = exitCode;
		_state = ProcessState.EXITED;		// 
		_stopSig = 0;
	}

	void reportExitCalled() {
		_state = ProcessState.EXIT_CALLED;
		_exitCode = -1;
		_stopSig = 0;
	}

	boolean reportStopped(int signal) {
		_state = ProcessState.STOPPED;
		if (signal != linux.SIGSTOP)
			_stopSig = signal;

		switch (signal) {
		case 0:
		case linux.SIGSTOP:
			result := _restartNextStop;
			_restartNextStop = false;
			return result;

		default:
			//logger.error("Possible program fault! tid %d signal %d", _tid, signal);
			;
		}
		return false;
	}

	public boolean stop() {
		switch (_state) {
		case RUNNING:
			return _process.stop(_tid);

		case STOPPED:
			return true;
		}
		return false;
	}

	public boolean run() {
		if (_state == ProcessState.STOPPED) {
			if (controller.resume(_tid, _stopSig)) {
				_state = ProcessState.RUNNING;
				_stale = true;
//				logger.info("-->> pid %d tid %d STARTED", _process.id(), _tid);
				return true;
			}
		} else
			logger.error("Attempt to run pid %d tid %d in state %s", _process.id(), _tid, string(_state));
		return false;
	}
	/**
	 * This will cause the debugger to diagnose a hard fault that occurred.
	 * At the point when this is called, the process should be stopped.
	 */
	public void diagnose(ref<linux.siginfo_t> siginfo) {
		switch (_stopSig) {
		case linux.SIGSEGV:
			logger.error("Segmentation Violation - Bad memory reference %p", siginfo.si_addr());
			break;
		}
		regs := registers();
		ref<elf.Elf64_Sym> sym;
		string name;
		long offset;
		(sym, name, offset) = _process.findSymbol(regs.rip);
		if (name != null) {
			if (offset != 0)
				offStr := "+" + offset;
			else
				offStr = "";
			logger.info("*-> %s%s", name, offStr);
		} else
			logger.warn(" -> %p rbp %p (no symbol cause %d)", regs.rip, regs.rbp, offset);
		mm := process().loadMemory();
		sseg := mm.findSegment(regs.rsp);
		if (sseg == null) {
			logger.warn("This thread's rsp (%p) does not appear to be in live memory - no stack dump.", regs.rsp);
			return;
		}

		DebugStack ds(this);
		long frame, ip;
		long lastFrame = regs.rbp;

		if (ds.nextFrame(regs.rbp) == 0) {
			logger.info("        No valid frame pointer - likely C/C++ code running");
		}
		for (;;) {
			(frame, ip) = ds.nextFrame(lastFrame);
			if (frame == 0)
				break;
			(sym, name, offset) = _process.findSymbol(ip - 1);		// the minus one picks up line numbers correctly.
																	// these are return addresses, and some lines end after
																	// the call instruction, so would report a line below.
																	// ip - 1 will always fall within whatever call instruction
																	// was used.

			if (name != null) {
				if (offset != 0)
					offStr := "+" + offset;
				else
					offStr = "";
				logger.info("    %s%s", name, offStr);
			} else if (offset != -12)
				logger.warn("    %p rbp %p (no symbol cause %d)", ip, frame, offset);
			else
				logger.info("    %p rbp %p", ip, frame);
			lastFrame = frame;
		}
	}

	public ref<linux.user_regs_struct> registers() {
		if (_stale)
			refresh();
		return &_registers;
	}

	public void refresh() {
		if (controller.fetchRegisters(_tid, &_registers))
			_stale = false;
		else
			printf("ERROR: Attempt to print registers %s failed\n", label());
	}

	public ref<TracedProcess> process() {
		return _process;
	}

	public int tid() {
		return _tid;
	}

	public boolean isStopped() {
		return _state == ProcessState.STOPPED;
	}

	public string label() {
		return "pid[" + _process.id() + ":" + _tid + "]";
	}

	public ProcessState state() {
		return _state;
	}

	public int exitCode() {
		return _exitCode;
	}

	public int stopSig() {
		return _stopSig;
	}
}

class SpawnParasolScript extends SessionWorkItem {
	string _script;
	string _parasolLocation;
	string[] _args;
	/**
	 * Note: on Linux, the spawning thread is the tracer of the target process.
	 */
	SpawnParasolScript(string parasolLocation, string script, string... args) {
		_script = script;
		_parasolLocation = parasolLocation;
		_args = args;
	}

	void run() {
		ref<TracedProcess> p;

		p = new TracedProcess;
		if (p.spawnParasolScript(null, _script, _parasolLocation, process.useParentEnvironment, _args)) {
			p.addThread(p.id());		// There's always one thread
			session.attendTo(p);
		} else {
			logger.error("Could not spawn %s", _script);
			delete p;
		}
	}
}

class HardFault extends SessionWorkItem {
	ref<ThreadInfo> _thread;

	HardFault(ref<ThreadInfo> t) {
		_thread = t;
	}

	void run() {
		p := _thread.process();
		Monitor m;

		linux.siginfo_t sig;
		boolean success;
		(sig, success) = controller.getSigInfo(_thread.tid());
		if (!success)
			logger.error("Attempt to obtain sig info for thread %d failed", _thread.tid());
		actions.onProcessStopped(p, &m);
		p.stopAllThreads(true);				// Set this process under hard fault - do not allow it to start up
											// until diagnosis is complete.
		m.wait();
		logger.info("Process %d stopped", p.id());
		if (success)
			_thread.diagnose(ref<linux.siginfo_t>(&sig));
		p.clearHardFault();
//		pause.notify();
	}
}

private boolean sawInitialStop;

class InitialStop extends SessionWorkItem {
	ref<ThreadInfo> _thread;

	InitialStop(ref<ThreadInfo> t) {
		_thread = t;
	}

	void run() {
		if (!sawInitialStop) {
			// This is a one-time call to (on Linux) set options and otherwise initialize the debugging
			// environment. There would probably also be some reasonable symbols to look up as they might be
			// smart candidates for implicit breakpoints.
			controller.setDebugOptions(_thread.process().id(), 
							   linux.PTRACE_O_TRACESYSGOOD|
							   linux.PTRACE_O_TRACEEXEC|
							   linux.PTRACE_O_TRACEEXIT|
							   linux.PTRACE_O_TRACECLONE);
			sawInitialStop = true;
		}
		if (!_thread.run())
			logger.error("initialStop restart failed: pid %d tid %d", _thread.process().id(), _thread.tid());
	}
}

class NewThread extends SessionWorkItem {
	ref<TracedProcess> _child;					// A child process of the debugger
	int _reportingTid;
	
	NewThread(ref<TracedProcess> p, int reportingTid) {
		_child = p;
		_reportingTid = reportingTid;
	}

	void run() {
		tid := controller.getNewThread(_reportingTid);
		if (tid > 0) {
			_child.addThread(tid);
			controller.resume(_reportingTid, 0);
		}
	}
}

class Syscall extends SessionWorkItem {
	ref<ThreadInfo> _thread;

	Syscall(ref<ThreadInfo> t) {
		_thread = t;
	}

	void run() {
		linux.user_regs_struct urs;

		if (!controller.fetchRegisters(_thread.tid(), &urs)) {
			logger.error("Couldn't fetch registers for %s", _thread.label());
			return;
		}
//		printf("Orig_rax (system call: %d\n", urs.orig_rax);
	}
}

class InitialExec extends SessionWorkItem {
	ref<TracedProcess> _child;

	InitialExec(ref<TracedProcess> p) {
		_child = p;
	}

	void run() {
		controller.runToSyscall(_child.id(), 0);
	}
}

class ExitCalled extends SessionWorkItem {
	ref<TracedProcess> _child;

	ExitCalled(ref<TracedProcess> p) {
		_child = p;
	}
	
	void run() {
		_child.fetchExitCalledInfo();
	}
}

class CleanupEventsHandler extends SessionWorkItem {
	void run() {
		session.cleanupEventsHandler();
	}
}

