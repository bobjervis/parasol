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

public string PROCESS_CONTROL_PROTOCOL = "ProcessControl";
/**
 * These are the notifications sent to a manager describing state changes
 * detected in the client. There are also a set of control messages that
 * the controller uses to coordinate with the manager.
 */
public interface ProcessNotifications {
	/**
	 * Tell the manager that all processes being debugged have exited and
	 * can provide no more information.
	 *
	 * This will be followed by a close of the Web Socket.
	 */
	void shutdown();

	void processSpawned(time.Instant timestamp, int pid, string label);

	void exit(time.Instant timestamp, int pid, int exitStatus);

	void initialStop(time.Instant timestamp, int pid);

	void initialTrap(time.Instant timestamp, int pid);

	void stopped(time.Instant timestamp, int pid, int tid, int stopSig);

	void exec(time.Instant timestamp, int pid);

	void afterExec(time.Instant timestamp, int pid);

	void exitCalled(time.Instant timestamp, int pid);

	void killed(time.Instant timestamp, int pid, int killSig);

	void newThread(time.Instant timestamp, int pid, int tid);
}
/**
 * These are the commands the manager send to the controller to intervene
 * in one way or another with the operation of the client. These may also include
 * queries about the state of the process and it's memory.
 */
public interface ProcessCommands {
	/**
	 * Direct the controller to terminate any active debug processes and shut
	 * down.
	 */
	void shutdown(time.Duration timeout);
}
