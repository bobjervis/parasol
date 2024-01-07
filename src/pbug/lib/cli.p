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
namespace parasollanguage.org:cli;

import parasol:log;
import parasol:process;
import parasol:pbuild.Application;
import parasol:pbuild.Coordinator;
import parasol:pbuild.thisOS;
import parasol:pbuild.thisCPU;
import parasol:runtime;
import parasol:storage;

import native:linux;

import parasollanguage.org:debug;

logger := log.getLogger("pbug.cli");

@Constant
int PROC_STAT_COLUMNS		= 44;	// expected number of columns of data to be reported from /proc/<pid>/stat or 
									// /proc/<pid>/task/<tid>/stat

Notifier notifier;

public void consoleUI() {
	debug.session.listen(notifier);
	// Is the process connected up to a terminal?
	if (process.stdin.class == storage.StdinReader) {
		ref<debug.ThreadInfo> currentThread;
		for (;;) {
			line := process.stdin.readLine();
			if (line == null) {
				printf("\n");
				break;
			}
			line = line.trim();
			if (line.length() == 0)
				continue;
			string[] words;
			wordIndex := 0;
			for (i in line) {
				if (line[i].isSpace()) {
					if (i > wordIndex)
						words.append(line.substr(wordIndex, i));
					wordIndex = i + 1;
				}
			}
			if (wordIndex < line.length())
				words.append(line.substr(wordIndex));

			command := words[0];
			words.remove(0);

			if (currentThread == null) {
				if (debug.session.processCount() > 0)
					currentThread = debug.session.findThread(debug.session.getProcess(0).id());
			}
			switch (command) {
			case "clear":
				t = getThread(currentThread, words);
				if (t == null)
					break;
				state = t.state();
				switch (state) {
				case STOPPED:
					t.process().clearSignal(t);
					break;

				default:
					printf("Cannot clear signal for thread %d now. %s\n", t.tid(), string(state));
				}
				break;

			case "f":
				if (words.length() == 0) {
					printf("You must include a partial filename\n");
					break;
				}
				pattern := words[0];
				words.remove(0);
				t = getThread(currentThread, words);
				if (t == null)
					break;
				debug.session.perform(new File(t.process(), pattern));
				break;
				
			case "m":
				t = getThread(currentThread, words);
				if (t == null)
					break;
				state = t.process().state();
				switch (state) {
				case RUNNING:
				case STOPPED:
				case EXIT_CALLED:
					debug.session.perform(new Memory(t.process()));
					break;

				default:
					printf("Cannot fetch memory for process %d now. %s\n", t.process().id(), string(state));
				}
				break;

			case "p":
				for (int index = 0; (p := debug.session.getProcess(index)) != null; index++) {
					printf("Process %d\n", p.id());
					threads := p.getThreads();
					threads.sort(comparator, true);
					for (j in threads) {
						t := threads[j];
						printf("    ");
						statPath := "/proc/" + t.process().id() + "/task/" + t.tid() + "/stat";
						ref<Reader> r = storage.openTextFile(statPath);
						if (r != null) {
							stat := r.readAll();
							delete r;
							columns := stat.split(' ');
							if (columns.length() < PROC_STAT_COLUMNS) {		// Does not work for linux < v3.3
								logger.warn("thread /proc/stat data is not as much as expected. Expected: %d got: %d", 
											PROC_STAT_COLUMNS, columns.length());
							}
							printf("%s ", columns[2]); 
						} else
							logger.error("Could not open %s to get the actual thread status", statPath);

						printf("Thread %d %s", t.tid(), string(t.state()).toLowerCase());
						if (t.stopSig() != 0 && t.stopSig() != linux.SIGSTOP)
							printf(" signal %d", t.stopSig());
						printf("\n");
					}

				}
				break;

			case "ping":
				t = getThread(currentThread, words);
				if (t == null)
					break;
				if (!t.process().ping())
					printf("Ping returned false\n");
				break;

			case "q":
				for (int i = 0;; i++) {
					p := debug.session.getProcess(i);
					if (p == null)
						break;
					p.kill();
				}
				process.exit(0);

			case "r":
				t := getThread(currentThread, words);
				if (t == null)
					break;
				state := t.state();
				switch (state) {
				case RUNNING:
					printf("Thread %d already running.\n", t.tid());
					break;

				case STOPPED:
				case EXIT_CALLED:
					debug.session.perform(new RunThread(t));
					break;

				case EXITED:
					printf("Thread %d has ended.\n", t.tid());
					break;

				default:
					printf("ERROR: Unknown thread state: %x tid %d\n", int(state), t.tid());
				}
				break;

			case "run":
				t = getThread(currentThread, words);
				if (t == null)
					break;
				debug.session.perform(new RunProcess(t.process()));
				break;

			case "regs":
				t = getThread(currentThread, words);
				if (t == null)
					break;
				state = t.state();
				switch (state) {
				case STOPPED:
				case EXIT_CALLED:
					debug.session.perform(new Registers(t));
					break;

				default:
					printf("Cannot fetch registers for thread %d now.\n", t.tid());
				}
				break;

			case "s":
				t = getThread(currentThread, words);
				if (t == null)
					break;
				state = t.state();
				switch (state) {
				case RUNNING:
					debug.session.perform(new StopThread(t));
					break;

				case STOPPED:
					printf("Thread %d already stopped.\n", t.tid());
					break;

				case EXIT_CALLED:
				case EXITED:
					printf("Thread %d has ended.\n", t.tid());
					break;

				default:
					printf("ERROR: Unknown thread state: %x tid %d\n", int(state), t.tid());
				}
				break;

			case "stop":
				t = getThread(currentThread, words);
				if (t == null)
					break;
				debug.session.perform(new StopProcess(t.process()));
				break;

			case "t":
				t = getThread(currentThread, words);
				if (t == null)
					break;
				debug.session.perform(new StackTrace(t));
				break;

			case "?":
				printf("Debugging %d processes. ", debug.session.processCount());
				if (currentThread != null) {
					currentProcess := currentThread.process();
					status := currentProcess.exitStatus();
					stopsig := currentProcess.stopSig();
					switch (currentProcess.state()) {
					case RUNNING:
						printf("Process %d running.\n", currentProcess.id());
						break;

					case STOPPED:
						printf("Process %d stopped.\n", currentProcess.id());
						break;

					case EXIT_CALLED:
						if (stopsig > 0)
							printf("Process %d about to terminate, signaled %d.\n", currentProcess.id(), stopsig);
						else
							printf("Process %d about to terminate, status %d.\n", currentProcess.id(), status);
						break;

					case EXITED:
						if (stopsig > 0)
							printf("Process %d terminated, signaled %d.\n", currentProcess.id(), stopsig);
						else
							printf("Process %d terminated, status %d.\n", currentProcess.id(), status);
						break;

					default:
						printf("Unknown process state %d, status %d, signal %d\n", int(currentProcess.state()),
									currentProcess.id(), status, stopsig);
					}
				} else
					printf("No active process.\n");
				break;

			default:
				printf("Not a valid command '%s'\n", command);
				printf("   Valid commands:\n");
				printf("       f <pattern> [ pid ]   display binary files that match the pattern\n");
				printf("       m [ pid ]             display a memory map of a process\n");
				printf("       p                     display the state of all threads being debugged\n");
				printf("       ping                  test whether the current process is locked\n");
				printf("       q                     exit the debugger\n");
				printf("       r [ tid ]             run (tid specifies a stopped thread)\n");
				printf("       regs [ tid ]          print the registers for the current or specified thread\n");
				printf("       run [ pid ]           run all stopped threads (pid specifies a stopped process)\n");
				printf("       s [ tid ]             stop a running thread\n");
				printf("       stop [ pid ]          stop all running threads in process pid\n");
				printf("       t [ tid ]             stack trace for a stopped tid\n");
				printf("       ?                     print debugger state\n");
			}
		}
	} else {
		printf("stdio is not connected to a terminal. Cannot use a c onsoleUI\n");
		process.exit(1);
	}

	private static int comparator(debug.ThreadInfo left, debug.ThreadInfo right) {
		return left.tid() - right.tid();
	}
}

ref<debug.ThreadInfo> getThread(ref<debug.ThreadInfo> currentThread, string... words) {
	ref<debug.ThreadInfo> t;
	if (words.length() > 0) {
		int tid;
		boolean success;
	
		(tid, success) = int.parse(words[0]);
		if (!success) {
			printf("Not a valid thread id: %s\n", words[0]);
			return null;
		}
		t = debug.session.findThread(tid);
		if (t == null) {
			printf("Unknown thread id: %d\n", tid);
			return null;
		}
	} else
		t = currentThread;
	if (t == null)
		printf("No active thread.\n");
	return t;
}

class Notifier implements debug.Notifier {
	void exit(int pid, int exitStatus) {
		logger.info("    -> process %d exit, status is %d", pid, exitStatus);
	}

	void initialStop(int pid) {
		logger.info("    -> process %d initial stop", pid);
	}

	void initialTrap(int pid) {
		logger.info("    -> process %d initial trap", pid);
	}

	void stopped(int pid, int tid, int stopSig) {
		logger.info("    -> pid %d tid %d stopped, signal is %d", pid, tid, stopSig);
	}

	void exec(int pid) {
		logger.info("    -> process %d exec", pid);
	}

	void afterExec(int pid) {
		logger.info("    -> process %d after exec", pid);
	}

	void exitCalled(int pid) {
		logger.info("    -> process %d exit called", pid);
	}

	void killed(int pid, int stopSig) {
		logger.info("    -> process %d killed, signal is %d", pid, stopSig);
	}

	void newThread(int pid, int tid) {
		logger.info("    -> process %d new thread %d", pid, tid);
	}
}

class RunProcess extends debug.SessionWorkItem {
	ref<debug.TracedProcess> _process;

	RunProcess(ref<debug.TracedProcess> process) {
		_process = process;
	}

	void run() {
		if (!_process.runAllThreads())
			printf("Process %d cannot be run.\n", _process.id());
	}
}

class RunThread extends debug.SessionWorkItem {
	ref<debug.ThreadInfo> _thread;

	RunThread(ref<debug.ThreadInfo> t) {
		_thread = t;
	}

	void run() {
		if (!_thread.run())
			printf("Thread %d cannot be run.\n", _thread.tid());
	}
}

class StopProcess extends debug.SessionWorkItem {
	ref<debug.TracedProcess> _process;

	StopProcess(ref<debug.TracedProcess> process) {
		_process = process;
	}

	void run() {
		_process.stopAllThreads(false);
	}
}

class StopThread extends debug.SessionWorkItem {
	ref<debug.ThreadInfo> _thread;

	StopThread(ref<debug.ThreadInfo> t) {
		_thread = t;
	}

	void run() {
		if (!_thread.stop())
			printf("Thread %d cannot be run.\n", _thread.tid());
	}
}

class StackTrace extends debug.SessionWorkItem {
	ref<debug.ThreadInfo> _thread;

	StackTrace(ref<debug.ThreadInfo> t) {
		_thread = t;
	}

	void run() {
		switch (_thread.state()) {
		case STOPPED:
		case EXIT_CALLED:
			break;

		default:
			printf("ERROR: Attempt to trace the stack %s in state %s\n", _thread.label(), string(_thread.state()));
			return;
		}
		_thread.printStackTrace();
	}
}

class Registers extends debug.SessionWorkItem {
	ref<debug.ThreadInfo> _thread;

	Registers(ref<debug.ThreadInfo> t) {
		_thread = t;
	}

	void run() {
		switch (_thread.state()) {
		case STOPPED:
		case EXIT_CALLED:
			break;

		default:
			printf("ERROR: Attempt to print registers %s in state %s\n", _thread.label(), string(_thread.state()));
			return;
		}
		urs := _thread.registers();

		printf("Registers for %d:\n", _thread.tid());
		printf("    rip %16.16x\n", urs.rip);
		printf("    rax %16.16x rbx %16.16x rcx %16.16x rdx %16.16x\n", urs.rax, urs.rbx, urs.rcx, urs.rdx);
		printf("    rsp %16.16x rbp %16.16x rsi %16.16x rdi %16.16x\n", urs.rsp, urs.rbp, urs.rsi, urs.rdi);
		printf("    r8  %16.16x r9  %16.16x r10 %16.16x r11 %16.16x\n", urs.r8, urs.r9, urs.r10, urs.r11);
		printf("    r12 %16.16x r13 %16.16x r14 %16.16x r15 %16.16x\n", urs.r12, urs.r13, urs.r14, urs.r15);
		printf("    cs  %-16.4x ss  %-16.4x\n", urs.cs, urs.ss);
		printf("    ds  %-16.4x es  %-16.4x fs  %-16.4x gs  %-16.4x\n", urs.ds, urs.es, urs.fs, urs.gs);
	}
}

class Memory extends debug.SessionWorkItem {
	ref<debug.TracedProcess> _child;

	Memory(ref<debug.TracedProcess> p) {
		_child = p;
	}

	void run() {
		mm := _child.loadMemory();
		if (mm == null) {
			printf("Could not access memory map for process %s\n", _child.id());
			return;
		}
		mm.print();
	}
}

class File extends debug.SessionWorkItem {
	ref<debug.TracedProcess> _child;
	string _pattern;

	File(ref<debug.TracedProcess> p, string pattern) {
		_child = p;
		_pattern = pattern;
	}

	void run() {
		_child.showFileMemory(_pattern);
	}
}	

