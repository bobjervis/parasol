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
 * The pbug command-line UI os desogned to run in the xterm window using mouse and 
 * keyboard controls.
 * It is one of the sub-commands that can be launched using the pbug application.
 * The idea is that a manager process serves as the focal point of a debug session,
 * with controller processes managing a set of one or more debugee processes on a single
 * machine. There also may be multiple UI processes attached to the same manager.
 *
 * Thie command-line UI is intended to provide basic access to the debugging resources
 * of Parasol, while permitting anyone to develop their own more sophisticated UI.
 *
 * UI Layout
 *
 * Several pieces of information are essential to conduct a productive debugging session.
 *
 *<ul>
 * <li> You must know where in the source code the current sttae of execution has gotten
 *      to.
 * <li> You must know the call stack that got you here.
 * <li> You must be able to find the data values that are relevant to what you are looking at.
 * <li> You must be able to see the console output of the program.
 *</ul>
 *
 * IDE's have rightfully devoted most of the display space to program source. A debugger
 * should probably strive to keep the design focus there as well.
 *
 * The basic model is to think about the the terimnal window being divided into tiles by
 * a set of splits. Starting with the outer-most perimeter of the terimnal os one tile, a
 * horizontal or vertical divider is added to each tile until the final goemetry is arrived at.
 *
 * It seems tradiitonal now to talk in terms of the way that IDE's usually divide their
 * primary window. There is normally a horizontal split in the lower portion of the main
 * panel. Below it is a display area for different functions such as multi-file search,
 * debugging, build errors, etc. The area above the main split is further divided by a
 * vertical split a little to the left of center. To the right of the vertical split is a
 * text editor window showing source code or other text data files. The left will usually
 * contain some sort of project or directory outline.
 *
 * Many if not all of these dividers can be moved back and forth as the user desires to
 * customize the appearance.
 *
 * The contents of each tile consist of a @{link Scroll}. In it's most simple form, it is a
 * vector of strings. Each element of the vector is displayed as a line of text. When
 * a particular scroll is posted to a tile, scroll bars will be included if the tile
 * is too small to display all of the text.
 *
 * Augmenting that text is a vector of spans. Each span lists the beginning and the end
 * of that span. Spans may overlap. Spans provide attribute information about how the
 * span will be displayed in the tile.
 *
 * Several sub-classes of {@link Scroll} exist:
 *
 *<ul>
 *	<li>Static text. This is the simplest implementation. All of the text is added
 *		when the Scroll is created and is not modified.
 *	<li>Event Log. This implements a sequence of lines that can be added to, but not
 *		modified.
 *	<li>Form. This defines a form with labels and data entry fields. Spans define
 *		input behavior, i.e. type-in fields, buttons, drop-downs, etc.
 *	<li>Source Text. Derived from static text, this adds spans to express color-highlighting.
 *</ul>
 *
 * There are a set of standard commands that a user expects to be able to issue:
 *<ul>
 *	<li> Rerun the debugger from the beginning
 *	<li> Stop the debugging session
 *	<li> Pause program execution
 *	<li> Resume program execution
 *	<li> Step over (execute one source statement, and executae the entirety of any system call
 *		 in that statement)
 *	<li> Step into (execute one source statement, and stop at the beginning of any function called
 *       by the statement)
 *	<li> Step out of (execute until the current function returns and stop at the return address)
 *  <li> Set or clear brakpoints 
 *</ul>
 */
namespace parasollanguage.org:cli;

import parasol:http;
import parasol:log;
import parasol:net;
import parasol:process;
import parasol:pbuild.Application;
import parasol:pbuild.Coordinator;
import parasol:pbuild.thisOS;
import parasol:pbuild.thisCPU;
import parasol:rpc
import parasol:runtime;
import parasol:storage;
import parasol:text
import parasol:thread;
import parasol:time;

import native:C;
import native:linux;

import parasollanguage.org:debug;
import parasollanguage.org:debug.manager;
import parasollanguage.org:tty;

logger := log.getLogger("pbug.cli");

@Constant
int PROC_STAT_COLUMNS		= 44;	// expected number of columns of data to be reported from /proc/<pid>/stat or 
									// /proc/<pid>/task/<tid>/stat

//Notifier notifier;
ref<tty.Terminal> terminal;
ref<tty.Tile> mainWindow;
ref<Monitor> cliDone;
string managerUrl
boolean shuttingDown

public int run(ref<debug.PBugOptions> options, string exePath, string... arguments) {
	cmdLine := process.getCommandLine();
	if (cmdLine.length() < 2) {
		printf("Command line incomplete\n");
		return 1;
	}
	if (!cmdLine[1].endsWith(".pxi")) {
		printf("First argument expected to name a .pxi file\n");
		return 1;
	}
	cliDone = new Monitor();
	socket := net.Socket.create();
	if (socket == null) {
		printf("Couldn't create a socket");
		return 1;
	}
	// We're all set to spawn the 'manager' process.
	manager := new process.Process();
	string[] manArgs;
	manArgs.append(cmdLine[1]);
	manArgs.append("-m");
	if (!socket.bind(0, net.ServerScope.LOCALHOST)) {
		printf("Could not bind the test manager port\n");
		return 1;
	}
	managerPort := socket.port();
	manArgs.append(string(managerPort));
	socket.close();
	delete socket;
	if (options.scriptOption.set()) {
		manArgs.append("-s")
		manArgs.append(options.scriptOption.value)
	}
	manArgs.append(options.copiedOptions());
	if (arguments.length() > 0 && arguments[0].length() > 0 && arguments[0][0] == '-')
		manArgs.append("--")
	manArgs.append(arguments)
	if (!manager.spawn(cmdLine[0], manArgs)) {
		printf("Spawn of manager sub-process failed\n");
		return 1;
	}
	thread.sleep(100);
	managerUrl = "ws://" + net.dottedIP(net.hostIPv4()) + ":" + string(managerPort) + "/session";
	if (!connectToManager(managerUrl)) {
		printf("Cannot connect to manager at %s\n", managerUrl);
		return 1;
	}
	
	terminal = tty.Terminal.initialize(0, 2);		// puts fd 0 and 2 (if they're both connected to a tty) into raw mode.
	if (terminal == null) {
		printf("fd 0 and 2 are not both a tty\n");
		cleanup();
		return 1;
	}
	logger.info("Terminal initialized - configuring ui");
	C.atexit(resetTerminal);

	setTerminal();

	mainWindow = new tty.Tile(terminal);

	upperTier := mainWindow.top();
	lowerTier := mainWindow.next();
	status := mainWindow.next();

	statusLog := new tty.LogScroll(100);
	status.bind(statusLog);

	directoryOutline := upperTier.left();
	sourceFile := upperTier.next();

	processes := session.commands.getProcesses()
	if (processes.length() > 0) {
		for (i in processes) {
			p := &processes[i]
			switch (p.state) {
			case STOPPED:
				process.stderr.printf("Process %d (%s) has stopped.\r\n", p.pid, p.label)

			default:
				logger.info("Process %d (%s) in state %s exit status %d.", p.pid, p.label, string(p.state), p.exitStatus)
			}
		}
	} else
		logger.info("No processes to report.")
	logger.info("Starting input loop");
	inputLoop();

	resetTerminal();
	cleanup();
	logger.info("Cli returning normally.");
	return 0;
}
/*
	Session cleanup:

	There are at least four processes in the picture:
		a) This cli process itself
		b) The manager process this cli spawned to start things off
		c) The controller process on the target machine that is monitoring the app being debugged
		d) The app being debugged

	Sending a shutdown message to the manager triggers a process to clean up all the subordinate processes.

	The shutdown command to the manager from the controlling cli returns only when the controllers have all
	shut down.

		
 */
void cleanup() {
	logger.info("CLI cleanup")
	shuttingDown = true
	result := session.commands.shutdown(time.Duration.zero)
	logger.info("manager reported shutdown result %s", result)
	cliDone.wait()
}

void inputLoop() {
	for (;;) {
		tty.Key key;
		int c, shifts, button, row, column;

		(key, c) = terminal.getKeystroke();
		switch (key) {
		case NOT_A_KEY:
//			logger.info("NOT_A_KEY %d", c);
			break;

		case MouseClick:
		case MouseDoubleClick:
		case MouseDown:
		case MouseDrag:
		case MouseDrop:
		case MouseReport:
			shifts = c & 0xff;
			button = (c >> 8) & 0xff;
			column = (c >> 16) & 0xff;
			row = (c >> 24) & 0xff;
			if (button != 0)
				logger.info("%s @(%d,%d) button %d%s%s%s", string(key), row, column, button, (shifts & 1) != 0 ? " shift" : "",
					(shifts & 2) != 0 ? " alt" : "", (shifts & 4) != 0 ? " ctl" : "");
			break;

		case MouseMove:
			column = (c >> 16) & 0xff;
			row = (c >> 24) & 0xff;
//			printf("%s @(%d,%d)\r\n", string(key), row, column);
			break;

		case MouseWheel:
			logger.info("%s %s", string(key), c > 0 ? "down" : "up");
			break;

		case CodePoint:
			logger.info("key = %s c = %x '%c'", string(key), c, c);
			switch (c) {
			case 'q':
				return;

			case 'l':
				logs := session.commands.getLogs(0, 1000)
				time.Formatter formatter("yyyy/MM/dd HH:mm:ss.SSS")
				for (i in logs) {
					time.Date d(logs[i].timestamp, &time.UTC)
					process.stderr.printf("%s %s\r\n", formatter.format(&d), logs[i].message)
				}
				break

			case 'R':
				if (session.commands.resumeProcess(0, 0))
					process.stderr.printf("Process resumed\r\n")
				else
					process.stderr.printf("Process not resumed\r\n")
				break
			}
			break;

		case EOF:
			logger.info("key = EOF");
			return;

		default:
			logger.info("key = %s c = %x - ignored", string(key), c);
		}
	}
}

void resetTerminal() {
	terminal.switchToNormalBuffer();
	if (!terminal.switchToCooked())
		printf("Terminal not reset to cooked\r\n");
	terminal.disableMouseTracking();
}

void setTerminal() {
	terminal.switchToAlternateBuffer();
	if (!terminal.switchToRaw())
		printf("Terminal not reset to cooked\r\n");
	terminal.enableMouseTracking();
	terminal.gotoStartOfLine();
}

boolean connectToManager(string url) {
	rpc.Client<manager.SessionCommands, manager.SessionNotifications> client(url, manager.SESSION_PROTOCOL, session);
	client.onDisconnect(session);
	logger.info("Calling connect to manager session");
	if (client.connect() == http.ConnectStatus.OK) {
		logger.info("manager session Connected");
		session.commands = client.proxy();
		return true;
	} else {
		logger.error("manager session not connected");
		return false;
	}
}

Session session;

class Session implements manager.SessionNotifications, http.DisconnectListener {
	manager.SessionCommands commands;

	void disconnect(boolean normalClose) {
		logger.debug("SessionNotifications downstream disconnect, normal close? %s", string(normalClose));
		if (shuttingDown)
			cliDone.notify()
		else {
			ok := connectToManager(managerUrl)
			if (!ok)
				logger.error("Could not reconnect to manager at %s", managerUrl)
		}
	}

	void afterExec(time.Time at, manager.ProcessInfo info) {
		logger.format(at, log.INFO, "Process %d (%s) has stopped after a system exec call.", info.pid, info.label);
		process.stderr.printf("Process %d (%s) has stopped after a system exec call.\r\n", info.pid, info.label);
	}

	void exitCalled(time.Time at, manager.ProcessInfo info, int tid, int exitStatus) {
		logger.format(at, log.INFO, "Process %d (%s), tid %d has called exit with exit status %d.", info.pid, info.label, tid, exitStatus)
		process.stderr.printf("Process %d, thread %d has called exit with status %d.\r\n", info.pid, tid, exitStatus)
	}

	void killed(time.Time at, manager.ProcessInfo info, int killSig) {
		logger.format(at, log.INFO, "!!! Process %d (%s) has terminated, killSig=%d", info.pid, info.label, killSig);
	}
	/**
	 * First notification that shutdown has begun. At this point, the CLI should be prepared for imminent disconnect
	 * from the manager.
	 *
	 * All calls to SessionCommands will return an error and have no effect.
	 */
	void shutdownInitiated() {
		logger.info("manager notification of shutdown initiated")
	}
	/**
	 * final notification of shutdown by manager
	 */
	void shutdown() {
		logger.info("Manager notification of shutdown")
	}
}

/*
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
*/
