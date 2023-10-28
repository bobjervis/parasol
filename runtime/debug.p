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
 */
namespace parasol:debug;

import parasol:exception;
import parasol:process;
import native:linux;
/**
 * This class provides the ability to either spawn a process and
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
public class DebugProcess extends process.Process {
	/** @ignore - for internal use only */
	public void childStartupHook() {
		result := linux.ptrace(linux.PTRACE_TRACEME, 0, null, null);
		if (result == -1) {
			err := linux.errno();
			if (err == linux.EPERM) 
				throw exception.IllegalOperationException("No permission");
			else
				throw exception.IllegalOperationException("Unexpected error: " + err + " (" + linux.strerror(err) + ")");
		}
	}
	/**
	 * Wait for a state change in the process being debugged.
	 *
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
	 */
	public DebugEvent, int wait() {
		int status;

		result := linux.waitpid(id(), &status, 0);
		if (result == -1) {
			err := linux.errno();
			if (err == linux.EINTR)
				return DebugEvent.INTERRUPTED, 0;
			else if (err == linux.ECHILD)
				throw exception.IllegalOperationException("The child process " + id() + " does not exist.");
			else if (err == linux.EINVAL)
				throw exception.IllegalArgumentException("The options are invalid.");
			else if (err == linux.ESRCH)
				throw exception.IllegalArgumentException("The process id is invalid.");
			else
				throw exception.IllegalOperationException("The child process " + id() + " produced an unexpected error " +
																err + " (" + linux.strerror(err) +")");
		}
		if (linux.WIFEXITED(status))
			return DebugEvent.EXIT, linux.WEXITSTATUS(status);
		else if (linux.WIFSIGNALED(status))
			return DebugEvent.KILLED, linux.WTERMSIG(status);
		else if (linux.WIFSTOPPED(status))
			return DebugEvent.STOPPED, linux.WSTOPSIG(status);
		else
			return DebugEvent.UNEXPECTED, status;
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
	/** The controlled process exited normally. */
	EXIT,
	/** The controlled process exited abnormally. */
	KILLED,
	/** The controlled process has stopped, typically due to a breakpoint. */
	STOPPED,
}

