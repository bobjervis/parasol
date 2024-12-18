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
namespace parasollanguage.org:debug.manager;

import parasol:time;

public string SESSION_PROTOCOL = "Session";

/*
 * These messages notify the session of any important state changes
 * in the client processes.
 */
public interface SessionNotifications {
	/**
	 * The process described in the info has stopped after an exec system call.
	 *
	 * @param at The time when the event happened
	 * @param info a ProcessInfo object describing the process that stopped.
	 */
	void afterExec(time.Time at, ProcessInfo info);

	void exitCalled(time.Time at, ProcessInfo info, int tid, int exitStatus);
	/**
	 * The process described in the info has terminated.
	 *
	 * @param at The time when the event happened
	 * @param info a ProcessInfo object describing the process that terminated.
	 */
	void killed(time.Time at, ProcessInfo info, int killSig);
	/**
	 * The thread described by the process info and the thread id has stopped because of
	 * the given stop signal.
	 */ 
	void stopped(time.Time at, ProcessInfo info, int tid, int stopSig)
	/**
	 * The debug manager has been commanded to shut down. The sessions that receive
	 * this message may no longer reliably send messages to the SessionCommands	
	 * proxy.
	 *
	 */
	void shutdownInitiated();
	/**
	 * The debug manager process is about to shutdown.
	 */
	void shutdown();
}
/**
 * These messages direct the manager to make some change or report
 * on some information of the debug state.
 */
public interface SessionCommands {
	/**
	 * Shutdown the manager and all it's controllers and the processes
	 * being debugged.
	 *
	 * If the timeout parameter is zero, all processes being debugged
	 * are sent a SIGKILL immediately.
	 */
	boolean shutdown(time.Duration timeout);

	// Queries

	ManagerInfo getManagerInfo();

	ProcessInfo[] getProcesses();

	ThreadInfo[], boolean getThreads(int pid, unsigned ip)
	/**
	 * Collect oneor more logs
	 */
	LogInfo[] getLogs(int min, int max)

	// Actions

	boolean resumeProcess(int pid, unsigned ip)
}

public class ProcessInfo {
	public int pid;
	public unsigned ip;
	public string label;
	public ProcessState state;
	public int exitStatus;
}

public class ThreadInfo {
	public int tid
	public ProcessState state
	public int stopSig			// If the state is STOPPED, this is why
	public int exitStatus
}

public enum ProcessState {
	RUNNING,			// All threads in the process are running.
	STOPPED,			// The process is not running, all threads are stopped. The process data state can be inspected.
	EXIT_CALLED,		// The process has called exit, but the debugger event has not returned, so the process 
						// is in a 'pre-zombie' state.
	EXITED				// Process has been cleaned up.
}

public class LogInfo {
	public time.Instant timestamp;
	public string message;
//	public string[string] metadata;
}
/*
 * General information about the manager's state information
 */
public class ManagerInfo {
	public int processCount;
	public int controllerCount;
	public int sessionCount;
	public int logsCount;
}

