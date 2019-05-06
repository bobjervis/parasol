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
namespace parasol:process;

import parasol:exception.IllegalOperationException;
import parasol:log;
import parasol:pxi;
import parasol:runtime;
import parasol:storage;
import parasol:time;
import parasol:memory;
import parasol:thread;
import parasol:thread.Thread;
import native:windows;
import native:linux;
import native:linux.CLD_EXITED;
import native:linux.CLD_STOPPED;
import native:linux.CLD_CONTINUED;
import native:C;

int FILENAME_MAX = 260;		// A reasonable maximum size for a string that might contain a filename path.

private ref<log.Logger> logger = log.getLogger("parasol.process");

public ref<Reader> stdin;
public ref<Writer> stdout;
public ref<Writer> stderr;

public int printf(string format, var... arguments) {
	return stdout.printf(format, arguments);
}

C.atexit(flushBuffers);

private void flushBuffers() {
	stderr.flush();
	stdout.flush();
}

public string binaryFilename() {
	byte[] filename;
	filename.resize(FILENAME_MAX + 1);
	int length = 0;
	
	if (runtime.compileTarget == runtime.Target.X86_64_WIN)
		length = windows.GetModuleFileName(null, &filename[0], filename.length());
	else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
		length = linux.readlink("/proc/self/exe".c_str(), &filename[0], filename.length());
	filename.resize(length);
	string s(filename);
	return s;
}

public enum exception_t {
	NO_EXCEPTION,
	ABORT,
	BREAKPOINT,
	TIMEOUT,							// debugSpawn exceeded specified timeout
	TOO_MANY_EXCEPTIONS,				// too many exceptions raised by child process
	ACCESS_VIOLATION,					// hardware memory access violation
	UNKNOWN_PLATFORM,					// The running runtime is not recognized where custom code is needed.
	UNKNOWN_EXCEPTION					// A system or application exception not known to the
										// runtime
}

private class SpawnPayload {
	public pointer<byte> output;
	public int outputLength;
	public int outcome;
}

public int getpid() {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return linux.getpid();
	} else
		return -1;
}

public boolean isPrivileged() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		// TODO: Check for this being a process with elevated privileges, for now, ignore this possibility.
		return false;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return linux.geteuid() == 0;
	} else
		return false;
}

// Do this in a function so the 'set' local variable is reclaimed.
init();
private void init() {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.sigset_t set;

		// Mask SIGCHLD - we will spawn a waiter thread as soon as we exec a process. 

		linux.sigemptyset(&set);
		linux.sigaddset(&set, linux.SIGCHLD);
		linux.pthread_sigmask(linux.SIG_BLOCK, &set, null);
	}
}

private monitor class ProcessVolatileData {
	int _exitStatus;
	boolean _running;
	/**
	 * Returns whether a process is running or stopped.
	 *
	 * @return Returns true if the process successfully forked, but has not yet returned
	 * exit status. The method returns false otherwise.
	 */
	public boolean running() {
		return _running;
	}

}
/**
 * Process allows creation and management of a child process. 
 *
 * Depending on the parameters defined, that interaction can be a simple command execution or a more
 * complex interactive exchange of data through the standard input and output files of the child.
 *
 * To launch a child process, you must go through several steps, depending on the complexity of the
 * interaction you want with the child.
 *
 * After constructing a Process, you may choose to make configuration calls to declare your intent to
 * collect output or to declare that you want the child process to execute under a different user identity.
 *
 * Once fully configured, you may {@link Process.spawn spawn} the child process, and wait for completion by calling
 * {@link Process.waitForExit waitForExit}. The {@link Process.execute execute} methods combine spawning and waiting into a single convenience
 * call.
 *
 * After the child process has actually started running, you can read all the child's output by calling
 * {@link Process.collectOutput collectOutput} or you can process the output yourself by asking for the standard output file
 * descriptor with the {@link Process.stdout stdout} method.
 */
public class Process extends ProcessVolatileData {
	private int _stdout;							// The process output fd when the spawn returns and _captureOutput is true
	private linux.pid_t _pid;

	private enum StdioHandling {
		IGNORE,
		CAPTURE_OUTPUT,
		INTERACTIVE
	}

	private boolean _setpgrp;
	private StdioHandling _stdioHandling;
	private linux.uid_t _user;
	private int _fdLimit;
	/**
	 * Create a Process with default behavior.
	 */
	public Process() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.rlimit rlim = { rlim_cur: 1024 };

			linux.getrlimit(linux.RLIMIT_NOFILE, &rlim);
			if (rlim.rlim_cur == linux.RLIM_INFINITY)
				_fdLimit = int.MAX_VALUE;
			else
				_fdLimit = int(rlim.rlim_cur);
		}
		_stdout = -1;
		_pid = -1;
	}

	~Process() {
		pendingChildren.cancelChild(_pid);
		if (_stdout >= 0)
			linux.close(_stdout);
	}
	/**
	 * Set the spawn to use a pipe to collect output from stdout and stderr. THis also will redirect
	 * standard input from /dev/null, which will cause the process to see an end-of-file on the first
	 * read from stdin (if any).
	 *
	 * The return value of the {@link Process.stdout stdout} method will be the read end of the pipe.
	 */
	public void captureOutput() {
		_stdioHandling = StdioHandling.CAPTURE_OUTPUT;
	}
	/**
	 * This method ssets the spawn mode to use setpgrp so that the child process is a new process group
	 * leader.
	 *
	 * This is a UNIX and Linux feature. Calling this method on Windows has no effect.
	 *
	 * Calling this function when the {@link running} method returns true (i.e. when the child process
	 * is actually running) will throw an {@link IllegalOperationException}.
	 */
	public void setpgrp() {
		if (running())
			throw IllegalOperationException("setpgrp - already running");
		_setpgrp = true;
	}
	/**
	 * Set the spawn to use a PTY to interact with the spawned process. It will be launched
	 * under a new session, with the newly opened PTY as the controlling terminal (so all children
	 * will receive SIGHUP when the PTY is closed by the parent process (the process with this object
	 * in it).
	 *
	 * The return value of the {@link Process.stdout stdout} method will be the master side of the PTY.
	 */
	public void runInteractive() {
		_stdioHandling = StdioHandling.INTERACTIVE;
	}

	public boolean user(string username) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.passwd pwd;
			ref<linux.passwd> out;

			byte[] buffer;
			buffer.resize(linux.sysconf(int(linux.SysConf._SC_GETPW_R_SIZE_MAX)));
			int result = linux.getpwnam_r(username.c_str(), &pwd, &buffer[0], buffer.length(), &out);
			if (out == null) {
				if (result == 0)
					printf("User '%s' not found\n", username);
				else {
					printf("getpwnam_r failed for user '%s'\n", username);
					linux.perror("getpwnam_r".c_str());
				}
				return false;
			}
			_user = pwd.pw_uid;
		}
		return true;
	}

	public boolean, int execute(string command, string... args) {
		return execute(null, command, null, args);
	}
	/**
	 * Execute a command in the Process.
	 *
 	 * This method will spawn and wait for the spawned process to complete before returning.
	 *
	 * If you called {@link captureOutput}, this call may hang if the quantity of captured output
	 * fills the pty device used to collect it. If so, you will have to use spawn explicitly and
	 * begin collecting output before you wait for the process to exit.
	 *
	 * @param workingDirectory The worknig directory the child process will use when executing the
	 * command. If workingDirectory is null, the child process runs in the same directory as the parent.
	 *
	 * @param command The path to the command file to run. The file must be a proper filename path.
	 * No command-line path search for the command will occur. The file must be executable by the user
	 * running in the child process.
	 *
	 * @param environ If not null, a reference to a map of environment variable definitions that should
	 * be added to the parent's environment strings for the child process. The environment variable name
	 * is the key of each element in the map and the value is the environment variable value.
	 *
	 * @param args Zero or more string arguments to be passed to the command.
	 *
	 * @return true if the process spawned successfully and the resulitng exit code was zero.
	 * In the event of an error during spawn, or a subsequent non-zero exit code, false is returned.
.	 *
	 * @return The actual exit code returned by the spawned process, or {@code int.MIN_VALUE} if the
	 * spawn itself failed.
	 */
	public boolean, int execute(string workingDirectory, string command, ref<string[string]> environ, string... args) {
		if (spawn(workingDirectory, command, environ, args)) {
			int exitStatus = waitForExit();
			if (exitStatus == 0)
				return true, 0;
			else {
//				logger.format(log.DEBUG, "exit = %d", exitStatus);
				return false, exitStatus;
			}
		} else
			logger.debug("spawn failed");
		return false, int.MIN_VALUE;
	}

	public boolean spawn(string command, string... args) {
		return spawn(null, command, null, args);
	}

	public boolean spawn(string workingDirectory, string command, ref<string[string]> environ, string... args) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
//			SpawnPayload payload;
			
//			int result = debugSpawnImpl(&command[0], &payload, timeout.value());
//			string output = string(payload.output, payload.outputLength);
//			exception_t outcome = exception_t(payload.outcome);
//			disposeOfPayload(&payload);
//			return result, output, outcome;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			pointer<byte>[] fullArgs;

			fullArgs.append(command.c_str());
			for (int i= 0; i < args.length(); i++)
				fullArgs.append(args[i].c_str());
			fullArgs.append(null);

			pointer<pointer<byte>> argv = &fullArgs[0];

			int ptyMasterFd;
			int[] pipeFd;

			switch (_stdioHandling) {
			case INTERACTIVE:
				ptyMasterFd = linux.posix_openpt(linux.O_RDWR);
				if (ptyMasterFd < 0)
					return false;
//				logger.format(log.DEBUG, "ptyMasterFd = %d", ptyMasterFd);
				linux.termios t;

				linux.tcgetattr(ptyMasterFd, &t);
				t.c_oflag |= linux.ONLRET;
				if (linux.tcsetattr(ptyMasterFd, 0, &t) != 0)
					logger.error("tcsetattr failed: %d", linux.errno());
				int result = linux.grantpt(ptyMasterFd);
				if (result != 0) {
					logger.error("grantpt failed: %d", linux.errno());
					return false;
				}
				result = linux.unlockpt(ptyMasterFd);
				if (result != 0) {
					logger.error("unlockpt failed: %d", linux.errno());
					return false;
				}
				break;

			case CAPTURE_OUTPUT:
				pipeFd.resize(2);
				if (linux.pipe(&pipeFd[0]) != 0) {
					logger.error("pipe failed: %d", linux.errno());
					return false;
				}
				break;
			}

/*
			printf("About to exec '%s'", command);
			for (int i = 0; i < args.length(); i++)
				printf(" '%s'", args[i]);
			printf("\n");
 */
			byte[] buffer;
			buffer.resize(linux.PATH_MAX);

			// This will guarantee that our handler does not race the SIG_CHLD signal
			lock (pendingChildren) {
				_pid = linux.fork();
				if (_pid == 0) {
					// This is the child process
					switch (_stdioHandling) {
					case INTERACTIVE:
						// If the child process changes users, the open has to happen with ruid == _user and euid == 0
						if (_user != 0) {
							if (linux.setreuid(_user, 0) != 0) {
								stderr.printf("setreuid to %d FAILED\n", _user);
								linux._exit(-1);
							}
						}
						linux.pid_t pid = linux.getpid();
						if (linux.ptsname_r(ptyMasterFd, &buffer[0], buffer.length()) != 0) {
							stderr.printf("ptsname_r failed: %d\n", linux.errno());
							linux._exit(-4);
						}
						int fd = linux.open(&buffer[0], linux.O_RDWR);
						if (fd < 3) {
							stderr.printf("pty open failed: %s %d %d", string(&buffer[0]), fd, linux.errno());
							linux._exit(-5);
						}
						if (linux.setsid() < 0) {
							linux.perror("setsid".c_str());
							linux._exit(-2);
						}
						int ioc = linux.ioctl(ptyMasterFd, linux.TIOCSCTTY, 0);
						if (ioc < 0) {
							linux.perror("ioctl".c_str());
							linux._exit(-3);
						}
						linux.close(ptyMasterFd);
						if (linux.dup2(fd, 0) != 0) {
							stderr.printf("dup2 failed: %d -> 0 %d\n", fd, linux.errno());
							linux._exit(-9);
						}
						if (linux.dup2(fd, 1) != 1) {
							stderr.printf("dup2 failed: %d -> 1 %d\n", fd, linux.errno());
							linux._exit(-10);
						}
						if (linux.dup2(fd, 2) != 2) {
							stderr.printf("dup2 failed: %d -> 2 %d\n", fd, linux.errno());
							linux._exit(-11);
						}
						break;

					case CAPTURE_OUTPUT:
						linux.setpgrp();
						int devNull = linux.open("/dev/null".c_str(), linux.O_RDONLY);
						if (devNull < 0 || linux.dup2(devNull, 0) != 0) {
							stderr.printf("dup2 failed: %d -> 0 %d\n", fd, linux.errno());
							linux._exit(-12);
						}
						if (linux.dup2(pipeFd[1], 1) != 1) {
							stderr.printf("dup2 failed: %d -> 1 %d\n", fd, linux.errno());
							linux._exit(-13);
						}
						if (linux.dup2(pipeFd[1], 2) != 2) {
							stderr.printf("dup2 failed: %d -> 2 %d\n", fd, linux.errno());
							linux._exit(-14);
						}
						linux.close(pipeFd[0]);
						linux.close(pipeFd[1]);
						break;

					default:
						if (_setpgrp)
							linux.setpgrp();
					}
					// Okay, lock it down now.
					if (_user != 0) {
						if (linux.setuid(_user) != 0) {
							stderr.printf("setreuid to %d FAILED\n", _user);
							linux._exit(-15);
						}
					}
					/*
						In the child process is the only reliable place we can
						ensure that all open network handles get closed. Otherwise,
						there is a race between the moment the fd gets opened in the
						'accept' system call and when we could use fcntl to set the 
						FD_CLOEXEC bit. Since we know we are about to call execv, we
						might as well just close the potential network connections
						here.
					 */
					for (int i = 3; i < _fdLimit; i++)
						linux.close(i);

					if (workingDirectory != null) {
						linux.chdir(workingDirectory.c_str());
					}
					if (environ != null) {
						for (string[string].iterator i = environ.begin(); i.hasNext(); i.next())
							environment.set(i.key(), i.get());
					}
					linux.execv(argv[0], argv);
					linux._exit(-16);
				} else {
					switch (_stdioHandling) {
					case INTERACTIVE:
						_stdout = ptyMasterFd;
						break;

					case CAPTURE_OUTPUT:
						_stdout = pipeFd[0];
						linux.close(pipeFd[1]);
						break;
					}
					pendingChildren.declareChild(_pid, processExitInfoWrapper, this);
					lock (*this) {
						_running = true;
					}
				}
			}
			return true;		// Only the parent process gets here.
		}
		return false;
	}

	public int waitForExit() {
		lock (*this) {
//			logger.format(log.DEBUG, "wait for %d running? %s", _pid, string(_running));
			if (_running)
				wait();
			return _exitStatus;
		}
	}
	/**
	 * Return the native operating system process id of the process.
	 *
	 * @return If the process has been successfully started, returns the process
	 * id. If the process has never been started returns -1. 
	 */
	public int id() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
//			SpawnPayload payload;
			
//			int result = debugSpawnImpl(&command[0], &payload, timeout.value());
//			string output = string(payload.output, payload.outputLength);
//			exception_t outcome = exception_t(payload.outcome);
//			disposeOfPayload(&payload);
//			return result, output, outcome;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			lock (*this) {
				return _pid;
			}
		}
		return -1;
	}

	public boolean kill(int signal) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
//			SpawnPayload payload;
			
//			int result = debugSpawnImpl(&command[0], &payload, timeout.value());
//			string output = string(payload.output, payload.outputLength);
//			exception_t outcome = exception_t(payload.outcome);
//			disposeOfPayload(&payload);
//			return result, output, outcome;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			lock (*this) {
				if (_running)
					return linux.kill(-_pid, signal) == 0;
			}
		}
		return false;
	}
	/**
	 * This method will spawn a thread to read the standard output of the spawned process.
	 * Note that if the process was configured by the {@link Process.runInteractive runInteractive}
	 * method, this method will not return until an end-of-file is detected. For en interactive
	 * process using a PTY, this will appear as an error condition with errno set to EIO.
	 *
	 * @return the output of the process, or null if the process is ignoring output (the
	 * default behavior).
	 */
	public string collectOutput() {
		if (_stdioHandling == StdioHandling.IGNORE)
			return null;

		// Spawn a thread to drain the process output into a string.
		ref<Thread> drainer = new Thread();
		DrainData dd;

		dd.fd = _stdout;
		dd.output = "";
		dd.stopOnZero = true;
		drainer.start(drain, &dd);
		drainer.join();
		delete drainer;
		linux.close(_stdout);
		_stdout = -1;
		return dd.output;
	}
	/**
	 */
	public int stdout() {
		if (_stdioHandling != StdioHandling.IGNORE)
			return _stdout;
		else
			return -1;
	}

	public linux.uid_t uid() {
		return _user;
	}

	private static void processExitInfoWrapper(int exitCode, address arg) {
		ref<Process>(arg).processExitInfo(exitCode);
	}

	protected void processExitInfo(int exitCode) {
//		printf("processExitInfo pid = %d: %d %d\n", info.si_pid, info.si_code, info.si_status);
//		logger.format(log.DEBUG, "child exit %d with %d", _pid, exitCode);
		lock (*this) {
			_running = false;
			_exitStatus = exitCode;
			notifyAll();
		}
	}
}
/**
 *	Use this as the third parameter to the Process.spawn or Process.execute methods to provide
 *	a self-documenting value where 'null' might cause confusion (or where the compiler needs help).
 *	The equivalent (but not at all obvious) expression is: ref&lt;string[string]&gt;(null).
 */
public ref<string[string]> useParentEnvironment;

private monitor class PendingChildren {
	private ref<PendingChild>[] _children;
	private ref<Thread> _waiter;

	void declareChild(linux.pid_t pid, void (int, address) handler, address arg) {
		ref<PendingChild> pc = new PendingChild(pid, handler, arg);
		if (_waiter == null) {
			_waiter = new Thread();
			_waiter.start(childWaiter, null);
		}
		for (int i = 0; i < _children.length(); i++)
			if (_children[i] == null) {
				_children[i] = pc;
				return;
			}
		_children.append(pc);
	}

	void cancelChild(linux.pid_t pid) {
		for (int i = 0; i < _children.length(); i++)
			if (_children[i] != null && _children[i].pid == pid) {
				_children[i].handler = null;
				return;
			}
	}

	void reportChildStateChange(linux.pid_t pid, int exitStatus) {
		if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			if (linux.WIFEXITED(exitStatus))
				exitStatus = linux.WEXITSTATUS(exitStatus);
			else
				exitStatus = -linux.WTERMSIG(exitStatus);
			for (int i = 0; i < _children.length(); i++)
				if (_children[i] != null && _children[i].pid == pid) {
					if (_children[i].handler != null)
						_children[i].handler(exitStatus, _children[i].arg);
					delete _children[i];
					_children[i] = null;
					break;
				}
		}
	}
}

private void childWaiter(address arg) {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		for (;;) {
			int exitStatus;
			linux.pid_t pid = linux.waitpid(-1, &exitStatus, 0);
			if (pid > 0) {
//				logger.format(log.DEBUG, "waitpid %d with %d", pid, exitStatus);
				pendingChildren.reportChildStateChange(pid, exitStatus);
			}
		}
	}
}

private PendingChildren pendingChildren;

private class PendingChild {
	public linux.pid_t pid;
	public void (int, address) handler;
	public address arg;

	public PendingChild(linux.pid_t pid, void (int, address) handler, address arg) {
		this.pid = pid;
		this.handler = handler;
		this.arg = arg;
	}
}
/*
public int debugSpawn(string command, ref<string> output, ref<exception_t> outcome, time.Time timeout) {
	SpawnPayload payload;
	
	int result = debugSpawnImpl(&command[0], &payload, timeout.value());
	if (output != null)
		*output = string(payload.output, payload.outputLength);
	if (outcome != null) 
		*outcome = exception_t(payload.outcome);
	disposeOfPayload(&payload);
	return result;
}
*/
public int, string, exception_t execute(time.Duration timeout, string... args) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
/*
		SpawnPayload payload;
		string command;

		for (i in args) {
			if (i > 0)
				command.append(" ");
			command.append(args[i]);
		}
		int result = debugSpawnImpl(&command[0], &payload, timeout.value());
		string output = string(payload.output, payload.outputLength);
		exception_t outcome = exception_t(payload.outcome);
		disposeOfPayload(&payload);
		return result, output, outcome;
*/
		return -1, null, exception_t.UNKNOWN_PLATFORM;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		pointer<byte>[] argv;

		for (i in args)
			argv.append(args[i].c_str());
		linux.pid_t pid;
		int[] pipefd;
		
		pipefd.resize(2);
		
		if (linux.pipe(&pipefd[0]) < 0)
			return -1, null, exception_t.NO_EXCEPTION;
		TimeoutData timer;
		ref<Thread> timerThread;
		pid = linux.fork();
		if (pid == 0) {
			linux.close(pipefd[0]);
			linux.dup2(pipefd[1], 1);
			linux.dup2(pipefd[1], 2);
			// This is the child process
			linux.execv(argv[0], &argv[0]);
			linux._exit(-1);
		} else {
			linux.close(pipefd[1]);
			
			ref<Thread> t = new Thread();
			DrainData d;
			d.fd = pipefd[0];
			d.output = "";
			d.stopOnZero = true;
			
			t.start(drain, &d);
			pendingChildren.declareChild(pid, executeDone, &timer);
			int exitStatus = timer.waitForChild(timeout);
			t.join();
			delete t;
			linux.close(pipefd[0]);
			if (timer.timedOut())
				return -1, d.output, exception_t.TIMEOUT;
			else if (exitStatus >= 0)
				return exitStatus, d.output, exception_t.NO_EXCEPTION;
			else {
				int signal = -exitStatus;
				if (signal == linux.SIGABRT)
					return -1, d.output, exception_t.ABORT;
				else if (signal == linux.SIGSEGV)
					return -1, d.output, exception_t.ACCESS_VIOLATION;
				else
					return -1, d.output, exception_t.UNKNOWN_EXCEPTION;
			}
		}
		return -1, null, exception_t.UNKNOWN_EXCEPTION;		// Shouldn't ever get here
	} else
		return -1, null, exception_t.UNKNOWN_PLATFORM;
}

private void executeDone(int exitStatus, address arg) {
	ref<TimeoutData> t = ref<TimeoutData>(arg);
	t.done(exitStatus);
}

public void exit(int code) {
	C.exit(code);
}

private class DrainData {
	public int fd;
	public string output;
	public boolean stopOnZero;
}

private void drain(address data) {
	ref<DrainData> d = ref<DrainData>(data);
	byte[] buffer;
	
	buffer.resize(64*1024);
	for (;;) {
		int result = linux.read(d.fd, &buffer[0], buffer.length());
		if (result < 0)
			break;
		if (d.stopOnZero && result == 0)
			break;
		for (int i = 0; i < result; i++)
			if (buffer[i] != '\r')
				d.output.append(buffer[i]);
	}
}

private monitor class TimeoutData {
	boolean _done;
	boolean _timedOut;
	int _exitStatus;

	TimeoutData() {
		_exitStatus = -1;			// indicates not actuall exitted.
	}

	public int waitForChild(time.Duration timeout) {
		wait(timeout);
		if (!_done)
			_timedOut = true;
		return _exitStatus;
	}

	public boolean timedOut() {
		return _timedOut;
	}

	public void done(int exitStatus) {
		_exitStatus = exitStatus;
		_done = true;
		notify();
	}
}

public Environment environment;

class Environment {
	public string get(string key) {
		return string(C.getenv(key.c_str()));
	}

	public void set(string key, string value) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			assert(false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.setenv(key.c_str(), value.c_str(), 1);
		} else
			assert(false);
	}

	public void remove(string key) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			assert(false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.unsetenv(key.c_str());
		} else
			assert(false);
	}
}
