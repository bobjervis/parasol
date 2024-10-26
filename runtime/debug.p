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
 * Provides facilities for debugging a process.
 *
 * I wrote my first debugger in 1974. It was a simple command-line tool that let you do the classical debugging tasks:
 *
 *<ul>
 *		<li>Set breakpoints
 *		<li>Start a program running
 *		<li>Inspect data when the program hits a breakpoint
 *		<li>Detect hardware errors and report them
 *</ul>
 *
 * I don't actually recall the language we used. 
 * It might have been Univac 1100 Assembly Language.
 * It was part of a larger multi-semester student project to build
 * an assembler and simulator for the <a href=https://en.wikipedia.org/wiki/MIX>MIX computer</a>, a computer design that Donald Knuth
 * created as a hypothetical machine to illustrate the computer science concepts and algoithms he was discussing in his The Art of 
 * Computer Programming.
 *
 * Interactive software development was a relatively novel concept at the time (I'd only given up my punched cards that year).
 * So this was state-of-the-art at the time.
 *
 * In the 1980's I helped create the first modern IDE, Turbo C. It combined a text editor to write code, a full-function compiler
 * to build a native executable, and a debugger to run the program and interactively control it.
 *
 * Today, debugging is a far more complex task that in that first student project.
 * Instead of a text command-line, we use multi-windowed graphic displays with a mouse as well as a keyboard.
 * Instead of a simple, single-threaded application being debugged, we need to debug multi-threaded multi-process systems
 * spanning multiple machines.
 *
 * In the classic debugger, you have one process that is ether running or stopped.
 * When running, about the only thing you can do is interact with the program being dbeugged, or interrupt it.
 * When stopped, you can inspect data, set or clear breakpoints and continue execution.
 *
 * In the class debugger, you had:
 *
 *<ul>
 *		<li> the ability to resume execution at full speed to run until it hit another breakpoint, called
 *			 exit or hit some hardware-detected error, like a bad memory reference.
 *		<li> single-step, advancing one statement. For assembly language this was a single machine instruction,
 *			 but for higher level languages like Parasol this has become understood to mean one statement in
 *			 that language, however many machine instructions that might be.
 *		<li> As programs grew, a number of convenience options were added, so that you could step over a function call.
 *			 Where the conventional 'single-step' would have put you at the first line of the new function, the 'step-over'
 *			 function would complete the entire function call before stopping.
 *		<li> Now you can step out-of as well. The program would run to the return statement of the current function,
 *			 then follow the return and stop at the end of that statement.
 *		<li> As multi-threading has become more common, debuggers have had to allow you to resume execution on just
 *			 one of the threads, leaving the others stopped.
 *		<li> The capability to debug multiple processes has been added in the form of following any child processes
 *			 a debuggee might have spawned.
 *</ul>
 *
 * While the variety of execution controls has proliferated, the complexity of managing that environment has exploded.
 *
 * For a modern debugger, this complexity is managed by maintaining a set of three kinds of threads:
 *
 *<ul>
 *		<li> An event thread that monitors all processes under the control of the debugger. 
 *		<li> A tracer thread that issues commands to processes and threads being debugged.
 *			 This thread also attaches to the processes to be debugged, or launches any child
 *			 processes.
 *		<li> A UI thread that collects user commands and transmits them to the appropriate
 *			 tracer threads.
 *</ul>
 *
 * The event and tracer threads must run in a process on the same machine as the processes being
 * debugged.
 *
 * The debugger process itself runs in a central location and is responsible for maintaining
 * a state model of everything under its control.
 * Such a model begins with a Configuration which describes a set of one or more processes to be debugged.
 * This Configuration can be cloned, amended, or discarded and will be backed up by a database, so it is persitent.
 *
 * From the Configuration, the Debugger launches processes as necessary, perhaps enlisting new machines to hold them, 
 * and maintains this Menagerie
 */
namespace parasol:debug;

import parasol:exception;
import parasol:log;
import parasol:process;
import parasol:storage;
import parasol:time;
import native:linux;
import native:C;

logger := log.getLogger("parasol.debug");

@Constant
int SEQUENCE_COMPLETE = 1;
/**
 * This class provides the ability to spawn a process and
 * act as its debugger.
 *
 * The underlying debugging facilities of the operaating system are
 * leveraged to accomplish this task.
 *
 * If the process being debugged is a Parasol program, special
 * access is made available of the relevant Parasol symbols in the
 * runtime symbol table.
 *
 * There are two basic scenarios available to use this class:
 *
 * <ol>
 *     <li> spawn a new process. Use the spawn method of the base class
 *          to create the process.
 *	   <li> attach to a running process. Use the attach method of this
 *			class to gain control of a running process.
 * </ol>
 *
 * Whichever method is used to establish control, this class can be
 * used to interact with the process in
 *			various ways to control the progress of program execution,
 *			inspect data values and collect information about the 
 *			process being debugged.
 *
 * A debugger or trace utility should spawn a thread that calls {@link wait}
 * to detect any state changes in the process being debugged.
 */
public class Process extends process.Process {
	private short _handshakeStep;

	/** @ignore - for internal use only */
	protected void childStartupHook() {
		result := linux.ptrace(linux.PTRACE_TRACEME, 0, null, null);
		if (result == -1) {
			err := linux.errno();
			if (err == linux.EPERM) 
				throw exception.IllegalOperationException("No permission");
			else
				throw exception.IllegalOperationException("Unexpected error: " + err + " (" + linux.strerror(err) + ")");
		}
		linux.kill(linux.getpid(), linux.SIGSTOP);
	}

	protected void declareChild() {
	}

	public DebugEvent interpretExec() {
		if (_handshakeStep == 0) {
			_handshakeStep++;
			return DebugEvent.INITIAL_EXEC;
		}
		return DebugEvent.EXEC;
	}

	public boolean stop(int tid) {
		result := linux.tgkill(id(), tid, linux.SIGSTOP);
		if (result == -1) {
			err := linux.errno();
			if (err == linux.EPERM ||
				err == linux.ESRCH) {
				logger.error("pid %d trying to stop tid %d: %s", id(), tid, linux.strerror(err));
				return false;
			} else
				throw exception.IllegalOperationException("The child process " + id() + " thread " + tid + " produced an unexpected error " +
																err + " (" + linux.strerror(err) +")");
		}
		return true;
	}

	public boolean kill() {
		result := linux.kill(id(), linux.SIGKILL);
		if (result == -1) {
			err := linux.errno();
			if (err == linux.EPERM ||
				err == linux.ESRCH) {
				logger.error("trying to kill pid %d: %s", id(), linux.strerror(err));
				return false;
			} else
				throw exception.IllegalOperationException("Trying to kill child process " + id() + " produced an unexpected error " +
																err + " (" + linux.strerror(err) +")");
		}
		return true;
	}

	public boolean terminate() {
		result := linux.kill(id(), linux.SIGTERM);
		if (result == -1) {
			err := linux.errno();
			if (err == linux.EPERM ||
				err == linux.ESRCH) {
				logger.error("trying to kill pid %d: %s", id(), linux.strerror(err));
				return false;
			} else
				throw exception.IllegalOperationException("Trying to terminate child process " + id() + " produced an unexpected error " +
																err + " (" + linux.strerror(err) +")");
		}
		return true;
	}
}

/**
 * Wait for a state change in any of the process(es) being debugged.
 *
 *
 * @return The process id of the process that generated this event.

 * @return The event that caused the state change.
 *
 * @return An integer value whose meaning depends on the event:
 *
 * <ul>
 *     <li> DebugEvent.EXIT - The process terminated normally.
 *			The value is the exit code of the process.
 *
 *	   <li> DebugEvent.KILLED - The process terminated abnormally.
 *			The value is the cause of the termination.
 *
 *	   <li> DebugEvent.STOPPED - The process stopped.
 *			The value is the cause for the stoppage.
 *
 *	   <li> DebugEvent.INTERRUPTED - The wait was interrupted.
 *			Always 0.
 *
 *	   <LI> DebugEvent.UNEXPECTED - None of the above events caused this to return.
 *			The actual returned status.
 *
 * @exception IllegalArgumentException thrown if either the process id is not valid or the options are invalid.
 *
 * @exception IllegalOperationException thrown if the call produced an unexpected error condition.
 */
public int, DebugEvent, int, time.Instant eventWait() {
	int status;
	int ptraceEvent;

	for (;;) {
		pid := linux.waitpid(-1, &status, linux.__WALL);
		now := time.Instant.now();
		if (pid == -1) {
			err := linux.errno();
			if (err == linux.EINTR)
				return -1, DebugEvent.INTERRUPTED, 0, now;
			else if (err == linux.ECHILD)
				throw exception.IllegalOperationException("No child process to wait for");
			else if (err == linux.EINVAL)
				throw exception.IllegalArgumentException("The options are invalid.");
			else if (err == linux.ESRCH)
				throw exception.IllegalArgumentException("The process id is invalid.");
			else
				throw exception.IllegalOperationException("The child process " + pid + " produced an unexpected error " +
																err + " (" + linux.strerror(err) +")");
		}
		if (linux.WIFEXITED(status))
			return pid, DebugEvent.EXIT, linux.WEXITSTATUS(status), now;
		else if (linux.WIFSIGNALED(status))
			return pid, DebugEvent.KILLED, linux.WTERMSIG(status), now;
		else if (linux.WIFSTOPPED(status)) {
			int signal = linux.WSTOPSIG(status);
			ptraceEvent = status >>> 16;
			switch (ptraceEvent) {
			case 0:
				if (signal == (0x80 | linux.SIGTRAP))
					return pid, DebugEvent.SYSCALL, signal, now;
				break;

			case linux.PTRACE_EVENT_CLONE:
				return pid, DebugEvent.NEW_THREAD, signal, now;

			case linux.PTRACE_EVENT_EXEC:
				return pid, DebugEvent.EXEC, signal, now;

			case linux.PTRACE_EVENT_EXIT:
				return pid, DebugEvent.EXIT_CALLED, signal, now;
			}
			return pid, DebugEvent.STOPPED, signal, now;
		} else
			return pid, DebugEvent.UNEXPECTED, status, now;
	}
}

/**
 * Defines the category of event that caused the {@link DebugProcess.wait} method to return.
 */
public enum DebugEvent {
	/** The event has an unknown status value. */
	UNEXPECTED,
	/** Not a notification from the controlled process, but the wait was interrupted in this process */
	INTERRUPTED,
	/** The a thread in the controlled process is about to exit - normally if signal is zero, abnormally if not. */
	EXIT_CALLED,
	/** The controlled process exited normally. */
	EXIT,
	/** The controlled process exited abnormally. */
	KILLED,
	/** The controlled process has stopped, typically due to a breakpoint. */
	STOPPED,
	/** The controlled process is about to, or just has executed an execve(). */
	EXEC,
	/** The controlled process has stopped at a syscall. */
	SYSCALL,
	/** The controlled process has stopped at the outset of debugging. */
	INITIAL_STOP,
	/** The controlled process has stopped at the outset of debugging. */
	INITIAL_EXEC,
	/** A new thread has been started. */
	NEW_THREAD,
}

/**
 * This class is used to control threads and processes, as well as inspect their data.
 *
 * All operations on this object must be executed by the same thread that spawns the {@link Process} being controlled,
 * or by attaching to an unrelated process.
 *
 * 
 */
public class Tracer {
	/**
	 * Fetch the general purpose registers of the given thread.
	 *
	 * @param tid The thread id of the thread whose register values are to be retrieved.
	 *
	 * @return true if the register values could be copied out, false if there was an error.
	 *
	 * @exception IllegalOperationException thrown if the call failed with an unexpected error.
	 * On linux, for example, it is an expected error for the indicated thread to have been
	 * killed by some other process in a way that produces no debug event. That circumstance will
	 * produce the less drastic error return value.
	 */
	public static boolean fetchRegisters(int tid, ref<linux.user_regs_struct> out) {
		linux.iovec iov = { 
					iov_base: out, 
					iov_len: linux.user_regs_struct.bytes 
			};

		result := ptrace(Ptrace.GETREGSET, tid, address(linux.NT_PRSTATUS), &iov);
		if (result == -1)
			return false;
		else
			return true;
	}
	/**
	 * This is appropriate in response to a NEW_THREAD event to fetch the new thread id.
	 *
	 * @param tid The id of the thread that received the NEW_THREAD event.
	 *
	 * @return The id of the new thread, or -1 if this call failed.
	 *
	 * @exception IllegalOperationException thrown if the call failed with an unexpected error.
	 * On linux, for example, it is an expected error for the indicated thread to have been
	 * killed by some other process in a way that produces no debug event. That circumstance will
	 * produce the less drastic error return value.
	 */
	public static int getNewThread(int tid) {
		int message;
		result := ptrace(Ptrace.GETEVENTMSG, tid, null, &message);
		if (result == -1)
			return -1;
		else
			return message;
	}
	/**
	 * This is appropriate in response to a EXIT_CALLED, EXIT or KILLED event to fetch the exit
	 * status and any signal responsible for the termination.
	 *
	 * @param tid The thread id of the thread receiving the event.
	 *
	 * @return The exit status of the terminating process or thread, or zero if a signal caused abonormal termination.
	 * @return If not zero, this is the signal number causing the (abnormal) termination event. For normal
	 * termination, this is zero.
	 *
	 * @exception IllegalOperationException thrown if the call failed with an unexpected error.
	 * On linux, for example, it is an expected error for the indicated thread to have been
	 * killed by some other process in a way that produces no debug event. That circumstance will
	 * produce the less drastic error return value.
	 */
	public static int, int getExitInformation(int tid) {
		int message;
		result := ptrace(Ptrace.GETEVENTMSG, tid, null, &message);
		if (result == -1)
			return -1, -1;
		if (linux.WIFEXITED(message))
			return linux.WEXITSTATUS(message), 0;
		else if (linux.WIFSIGNALED(message))
			return 0, linux.WTERMSIG(message);
		else
			return -1, message;
	}
	/**
	 * Resume execution of a thread.
	 *
	 * Note that resuming a thread will only resume that one thread. In a multi-threaded program, other threads will be
	 * unaffected by resuming this thread.
	 *
	 * @param tid The thread to be resumed.
	 * @param signal The number of a signal to be sent to the given thread. Note that the event that caused this thread to stop
	 * may not have the same or any signal as this value. A value of zero indicates that no signal will be passed to the
	 * thread.
	 *
	 * @return true if the call succeeded, false otherwise.
	 *
	 * @exception IllegalOperationException thrown if the call failed with an unexpected error.
	 * On linux, for example, it is an expected error for the indicated thread to have been
	 * killed by some other process in a way that produces no debug event. That circumstance will
	 * produce the less drastic error return value.
	 */
	public static boolean resume(int tid, int signal) {
		result := ptrace(Ptrace.CONT, tid, null, address(signal));
		if (result == -1)
			return false;
		else
			return true;
	}
	/**
	 * Resume execution of a thread, stopping at the next system call.
	 *
	 * On linux, running to a system call will actually stop twice. The first stop will have the register values
	 * as they are at the moment the call is being made. Calling this method a second time will stop again after
	 * the system call has completed, so the return values can be inspected.
	 *
	 * Note that resuming a thread will only resume that one thread. In a multi-threaded program, other threads will be
	 * unaffected by resuming this thread.
	 *
	 * @param tid The thread to be resumed.
	 * @param signal The number of a signal to be sent to the given thread. Note that the event that caused this thread to stop
	 * may not have the same or any signal as this value. A value of zero indicates that no signal will be passed to the
	 * thread.
	 *
	 * @return true if the call succeeded, false otherwise.
	 *
	 * @exception IllegalOperationException thrown if the call failed with an unexpected error.
	 * On linux, for example, it is an expected error for the indicated thread to have been
	 * killed by some other process in a way that produces no debug event. That circumstance will
	 * produce the less drastic error return value.
	 */
	public static boolean runToSyscall(int tid, int signal) {
		result := ptrace(Ptrace.SYSCALL, tid, null, address(signal));
		if (result == -1)
			return false;
		else
			return true;
	}
	/**
	 * Resume execution of a thread for one instruction.
	 *
	 * Resuming for one instruction permits a debugger to implement assembly language debugging, or more
	 * commonly to step through a breakpoint.
	 * A breakpoint, is implemented by placing a special breakpoint instruction at the location where you want the
	 * program to stop. To stop over the bearkpoint, the special instruction must be replaced with the original
	 * instruction value, execute a single-step to get past that point and then restore the breakpoint instruction before
	 * resuming normally.
	 *
	 * Note that resuming a thread will only resume that one thread. In a multi-threaded program, other threads will be
	 * unaffected by resuming this thread.
	 *
	 * @param tid The thread to be resumed.
	 * @param signal The number of a signal to be sent to the given thread. Note that the event that caused this thread to stop
	 * may not have the same or any signal as this value. A value of zero indicates that no signal will be passed to the
	 * thread.
	 *
	 * @return true if the call succeeded, false otherwise.
	 *
	 * @exception IllegalOperationException thrown if the call failed with an unexpected error.
	 * On linux, for example, it is an expected error for the indicated thread to have been
	 * killed by some other process in a way that produces no debug event. That circumstance will
	 * produce the less drastic error return value.
	 */
	public static boolean singleStep(int tid, int signal) {
		result := ptrace(Ptrace.SINGLESTEP, tid, null, address(signal));
		if (result == -1)
			return false;
		else
			return true;
	}
	/**
	 * Set the debug options that will control which events the system will report to the tracer.
	 *
	 * @return true if the call succeeded, false otherwise.
	 *
	 * @exception IllegalOperationException thrown if the call failed with an unexpected error.
	 * On linux, for example, it is an expected error for the indicated thread to have been
	 * killed by some other process in a way that produces no debug event. That circumstance will
	 * produce the less drastic error return value.
	 */
	public static boolean setDebugOptions(int tid, long options) {
		result := ptrace(Ptrace.SETOPTIONS, tid, null, address(options));
		if (result == -1)
			return false;
		else
			return true;
	}

	public static linux.siginfo_t, boolean getSigInfo(int tid) {
		linux.siginfo_t siginfo;

		result := ptrace(Ptrace.GETSIGINFO, tid, null, &siginfo);
		if (result == -1)
			return siginfo, false;
		else
			return siginfo, true;
	}

	public static boolean copy(int tid, long remoteAddress, address localAddress, int length) {
		pointer<address> local = pointer<address>(localAddress);
		while (length > 0) {
			long contents;
			boolean success;
//			printf("peek(%d, %x) remaining = %x\n", tid, remoteAddress, length);
			(contents, success) = peek(tid, remoteAddress);
			if (!success)
				return false;
			if (length >= address.bytes) {
				*local = address(contents);
				length -= address.bytes;
				local++;
				remoteAddress += address.bytes;
			} else {
				C.memcpy(local, &contents, length);
				break;
			}
		}
		return true;
	}

	public static long, boolean peek(int tid, long addr) {
		linux.set_errno(0);
		result := ptrace(Ptrace.PEEKDATA, tid, address(addr), null);
		if (linux.errno() != 0)
			return result, false;
		else
			return result, true;
	}

	private static long ptrace(Ptrace request, int pid, address addr, address data) {
		result := linux.ptrace(request.linuxValue(), pid, addr, data);
		if (result == -1) {
			err := linux.errno();
			if (request == Ptrace.PEEKDATA ||
				request == Ptrace.PEEKTEXT)
				return result;
			if (err == linux.EPERM ||
				err == linux.ESRCH)
				logger.error("ptrace PTRACE_%s tid %d: %s", string(request), pid, linux.strerror(err));
			else
				throw exception.IllegalOperationException("The process/thread " + pid + " " + string(request) + 
															" produced an unexpected error " +
															err + " (" + linux.strerror(err) +")");
		}
		return result;
	}

	enum Ptrace {
			TRACEME(linux.PTRACE_TRACEME),
			PEEKTEXT(linux.PTRACE_PEEKTEXT),
			PEEKDATA(linux.PTRACE_PEEKDATA),
			PEEKUSE(linux.PTRACE_PEEKUSR),
			POKETEXT(linux.PTRACE_POKETEXT),
			POKEDATA(linux.PTRACE_POKEDATA),
			POKEUSE(linux.PTRACE_POKEUSR),
			CONT(linux.PTRACE_CONT),
			KILL(linux.PTRACE_KILL),
			SINGLESTEP(linux.PTRACE_SINGLESTEP),
			ATTACH(linux.PTRACE_ATTACH),
			DETACH(linux.PTRACE_DETACH),
			SYSCALL(linux.PTRACE_SYSCALL),
			SETOPTIONS(linux.PTRACE_SETOPTIONS),
			GETEVENTMSG(linux.PTRACE_GETEVENTMSG),
			GETSIGINFO(linux.PTRACE_GETSIGINFO),
			SETSIGINFO(linux.PTRACE_SETSIGINFO),
			GETREGSET(linux.PTRACE_GETREGSET),
/*
#define PTRACE_SETREGSET        0x4205

#define PTRACE_SEIZE            0x4206
#define PTRACE_INTERRUPT        0x4207
#define PTRACE_LISTEN           0x4208

#define PTRACE_PEEKSIGINFO      0x4209
*/
		;
		private int _linuxValue;

		Ptrace(int linuxValue) {
			_linuxValue = linuxValue;
		}

		long linuxValue() {
			return _linuxValue;
		}
	}
}


