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

private ref<log.Logger> logger = log.getLogger("parasol.process");

public ref<Reader> stdin;
public ref<Writer> stdout;
public ref<Writer> stderr;

public int printf(string format, var... arguments) {
	return stdout.printf(format, arguments);
}

public string binaryFilename() {
	byte[] filename;
	filename.resize(storage.FILENAME_MAX + 1);
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

init();
private void init() {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
//		linux.struct_sigaction action;
		linux.sigset_t set;

		// Mask SIGCHLD - we will spawn a waiter thread as soon as we exec a process. 

		linux.sigemptyset(&set);
		linux.sigaddset(&set, linux.SIGCHLD);
		linux.pthread_sigmask(linux.SIG_BLOCK, &set, null);

//		action.set_sa_sigaction(sigChldHandler);
//		action.sa_flags = linux.SA_SIGINFO;
//		int result = linux.sigaction(linux.SIGCHLD, &action, null);
//		if (result != 0) {
//			printf("Failed to register SIGCHLD handler: %d\n", result);
//			linux.perror("From sigaction".c_str());
//		}
	}
}

private monitor class ProcessVolatileData {
	int _exitStatus;
	boolean _running;
}

public class Process extends ProcessVolatileData {
	private int _stdout;							// The process output fd when the spawn returns and _captureOutput is true
	private linux.pid_t _pid;
	private boolean _captureOutput;
	private linux.uid_t _user;
	private int _fdLimit;

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
	}

	~Process() {
		pendingChildren.cancelChild(_pid);
		if (_stdout >= 0)
			linux.close(_stdout);
	}

	public void captureOutput() {
		_captureOutput = true;
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

	public boolean, int execute(string workingDirectory, string command, ref<string[string]> environ, string... args) {
		if (spawn(workingDirectory, command, environ, args)) {
			int exitStatus = waitForExit();
			if (exitStatus == 0)
				return true, 0;
			else {
				logger.format(log.DEBUG, "exit = %d", exitStatus);
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

			if (_captureOutput) {
				ptyMasterFd = linux.posix_openpt(linux.O_RDWR);
				if (ptyMasterFd < 0)
					return false;
//				logger.format(log.DEBUG, "ptyMasterFd = %d", ptyMasterFd);
				linux.termios t;

				linux.tcgetattr(ptyMasterFd, &t);
				t.c_oflag |= linux.ONLRET;
				if (linux.tcsetattr(ptyMasterFd, 0, &t) != 0)
					logger.format(log.ERROR, "tcsetattr failed: %d", linux.errno());
			}
/*
			printf("About to exec '%s'", command);
			for (int i = 0; i < args.length(); i++)
				printf(" '%s'", args[i]);
			printf("\n");
 */
			// This will guarantee that our handler does not race the SIG_CHLD signal
			lock (pendingChildren) {
				_pid = linux.fork();
				if (_pid == 0) {
					linux.setpgrp();
					// This is the child process
					log.resetChildProcess();
					if (_captureOutput) {
						// If the child process changes users, the grantpt has to happen with ruid == _user and euid == 9
						if (_user != 0) {
							if (linux.setreuid(_user, 0) != 0) {
								logger.format(log.ERROR, "setreuid to %d FAILED", _user);
								thread.sleep(1000);
								linux._exit(-1);
							}
						}
						int result = linux.grantpt(ptyMasterFd);
						if (result != 0) {
							logger.format(log.ERROR, "grantpt failed: %d", linux.errno());
							thread.sleep(1000);
							linux._exit(-1);
						}
						result = linux.unlockpt(ptyMasterFd);
						if (result != 0) {
							logger.format(log.ERROR, "unlockpt failed: %d", linux.errno());
							thread.sleep(1000);
							linux._exit(-1);
						}
						byte[] buffer;
						buffer.resize(linux.PATH_MAX);
						if (linux.ptsname_r(ptyMasterFd, &buffer[0], buffer.length()) != 0) {
							logger.format(log.ERROR, "ptsname_r failed: %d", linux.errno());
							thread.sleep(1000);
							linux._exit(-1);
						}
						int fd = linux.open(&buffer[0], linux.O_RDWR);
						if (fd < 3) {
							logger.format(log.ERROR, "pty open failed: %s %d %d", string(&buffer[0]), fd, linux.errno());
							thread.sleep(1000);
							linux._exit(-1);
						}
						if (linux.dup2(fd, 0) != 0) {
							logger.format(log.ERROR, "dup2 failed: %d -> 0 %d", fd, linux.errno());
							thread.sleep(1000);
							linux._exit(-1);
						}
						if (linux.dup2(fd, 1) != 1) {
							stderr.printf("dup2 failed: %d -> 1 %d\n", fd, linux.errno());
							linux._exit(-1);
						}
						if (linux.dup2(fd, 2) != 2) {
							stderr.printf("dup2 failed: %d -> 2 %d\n", fd, linux.errno());
							linux._exit(-1);
						}
					}
					// Okay, lock it down now.
					if (_user != 0) {
						if (linux.setuid(_user) != 0) {
							logger.format(log.ERROR, "setreuid to %d FAILED", _user);
							thread.sleep(1000);
							linux._exit(-1);
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
					linux._exit(-1);
				} else {
//					printf("Forked child %d\n", _pid);
					ref<PendingChild> pc = new PendingChild;
					pc.pid = _pid;
					pc.handler = processExitInfoWrapper;
					pc.arg = this;

					if (_captureOutput) {
						_stdout = ptyMasterFd;
					}
					pendingChildren.declareChild(pc);
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
			if (_running)
				wait();
			return _exitStatus;
		}
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

	public string collectOutput() {
		if (!_captureOutput)
			return null;

		// Spawn a thread to drain the process output into a string.
		ref<Thread> drainer = new Thread();
		DrainData dd;

		dd.fd = _stdout;
		dd.output = "";
		drainer.start(drain, &dd);
		drainer.join();
		delete drainer;
		linux.close(_stdout);
		_stdout = -1;
		return dd.output;
	}

	public int stdout() {
		if (_captureOutput)
			return _stdout;
		else
			return -1;
	}

	public linux.uid_t uid() {
		return _user;
	}

	private static void processExitInfoWrapper(ref<linux.siginfo_t_sigchld> info, address arg) {
		ref<Process>(arg).processExitInfo(info);
	}

	protected void processExitInfo(ref<linux.siginfo_t_sigchld> info) {
//		printf("processExitInfo pid = %d: %d %d\n", info.si_pid, info.si_code, info.si_status);
		switch (info.si_code) {
		case CLD_STOPPED:
		case CLD_CONTINUED:
			break;

		case CLD_EXITED:
			lock (*this) {
				_running = false;
				_exitStatus = info.si_status;
				notifyAll();
			}
			break;

		default:
			lock (*this) {
				_running = false;
				_exitStatus = -info.si_status;
				notifyAll();
			}
			break;
		}
	}
}
/**
 *	Use this as the third parameter to the Process.spawn or Process.execute methods to provide
 *	a self-documenting value where 'null' might cause confusion (or where the compiler needs help).
 *	The equivalent (but not at all obvious) expression is: ref<string[string]>(null).
 */
public ref<string[string]> useParentEnvironment;

private monitor class PendingChildren {
	private ref<PendingChild>[] _children;
	private ref<Thread> _waiter;

	void declareChild(ref<PendingChild> pc) {
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

	void reportChildStateChange(linux.pid_t pid, ref<linux.siginfo_t_sigchld> info) {
		if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			for (int i = 0; i < _children.length(); i++)
				if (_children[i] != null && _children[i].pid == pid) {
					if (_children[i].handler != null)
						_children[i].handler(info, _children[i].arg);
					int exitStatus;
					if (linux.WIFEXITED(info.si_status) || linux.WIFSIGNALED(info.si_status)) {
						linux.waitpid(pid, &exitStatus, 0);
						delete _children[i];
						_children[i] = null;
					}
					return;
				}
		}
	}
}

private void childWaiter(address arg) {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.sigset_t set;
		linux.siginfo_t_sigchld info;
	
		linux.sigemptyset(&set);
		linux.sigaddset(&set, linux.SIGCHLD);
		for (;;) {
			// A return value less than zerro can only be EINTR, which just requires that we retry
			if (linux.sigwaitinfo(&set, &info) >= 0)
				pendingChildren.reportChildStateChange(info.si_pid, &info);
		}
	}
}

private PendingChildren pendingChildren;

private class PendingChild {
	public linux.pid_t pid;
	public void (ref<linux.siginfo_t_sigchld>, address) handler;
	public address arg;
}

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

public int, string, exception_t execute(time.Time timeout, string... args) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
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
			if (timeout.value() > 0) {
				timerThread = new Thread();
				timer.init(pid, timeout);
				timerThread.start(countdownTimer, &timer);
			}
			linux.close(pipefd[1]);
			int exitStatus;
			
			ref<Thread> t = new Thread();
			DrainData d;
			d.fd = pipefd[0];
			d.output = "";
			d.stopOnZero = true;
			
			t.start(drain, &d);
			linux.pid_t terminatedPid = linux.waitpid(pid, &exitStatus, 0);
			if (terminatedPid != pid)
				return -3, null, exception_t.NO_EXCEPTION;
			if (timeout.value() > 0) {
				timer.signalDone();
				timerThread.join();
			} else
				timer.done = true;
			t.join();
			delete t;
			linux.close(pipefd[0]);
			if (timer.timedOut)
				return -1, d.output, exception_t.TIMEOUT;
			else if (linux.WIFEXITED(exitStatus))
				return linux.WEXITSTATUS(exitStatus), d.output, exception_t.NO_EXCEPTION;
			else {
				int signal = linux.WTERMSIG(exitStatus);
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

// TODO: Do we need this or something better?
/*public*/private int, string, exception_t spawnInteractive(string command, string stdin, time.Time timeout) {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		SpawnPayload payload;
		
		int result = debugSpawnInteractiveImpl(&command[0], &payload, stdin, timeout.value());
		string output = string(payload.output, payload.outputLength);
		exception_t outcome = exception_t(payload.outcome);
		disposeOfPayload(&payload);
		return result, output, outcome;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		pointer<pointer<byte>> argv;
		
//		argv = parseCommandLine(command);
		if (argv == null) {
			return -1, null, exception_t.NO_EXCEPTION;
		}
		linux.pid_t pid;
		int[] pipefd;
		
		pipefd.resize(2);
		
		if (linux.pipe(&pipefd[0]) < 0)
			return -1, null, exception_t.NO_EXCEPTION;

		int[] stdinPipefd;

		stdinPipefd.resize(2);

		if (linux.pipe(&stdinPipefd[0]) < 0)
			return -1, null, exception_t.NO_EXCEPTION;

		TimeoutData timer;
		ref<Thread> timerThread;
		pid = linux.fork();
		if (pid == 0) {
			linux.close(pipefd[0]);
			linux.dup2(pipefd[1], 1);
			linux.dup2(pipefd[1], 2);
			linux.close(stdinPipefd[1]);
			linux.dup2(stdinPipefd[0], 0);
			// This is the child process
			linux.execv(argv[0], argv);
			linux._exit(-1);
		} else {
			if (timeout.value() > 0) {
				timerThread = new Thread();
				timer.init(pid, timeout);
				timerThread.start(countdownTimer, &timer);
			}
			linux.close(stdinPipefd[0]);
			linux.close(pipefd[1]);
			int exitStatus;
			
			ref<Thread> t = new Thread();
			DrainData d;
			d.fd = pipefd[0];
			d.output = "";
			d.stopOnZero = true;
			
			t.start(drain, &d);
			// If the stdin string is long, this may block waiting for the child process to read the data.
			// This should not deadlock, because we are draining the stdout, so the pipe's shouldn't choke.
			linux.write(stdinPipefd[1], stdin.c_str(), stdin.length());
			// Once the write is done, the child has consumed all of its input, or else has closed the input pipe
			// causing the write to fail (which we don't care about at this level). 
			linux.close(stdinPipefd[1]);
			linux.pid_t terminatedPid = linux.waitpid(pid, &exitStatus, 0);
			if (terminatedPid != pid)
				return -3, null, exception_t.NO_EXCEPTION;
			if (timeout.value() > 0) {
				timer.signalDone();
				timerThread.join();
			} else
				timer.done = true;
			t.join();
			delete t;
			linux.close(pipefd[0]);
			if (timer.timedOut)
				return -1, d.output, exception_t.TIMEOUT;
			else if (linux.WIFEXITED(exitStatus))
				return linux.WEXITSTATUS(exitStatus), d.output, exception_t.NO_EXCEPTION;
			else {
				int signal = linux.WTERMSIG(exitStatus);
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

private abstract int debugSpawnImpl(pointer<byte> command, ref<SpawnPayload> output, long timeout);

private abstract int debugSpawnInteractiveImpl(pointer<byte> command, ref<SpawnPayload> output, string stdin, long timeout);

private abstract void disposeOfPayload(ref<SpawnPayload> output);

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

private class TimeoutData {
	public linux.pthread_mutex_t timerLock;
	public linux.pthread_cond_t timerVariable;
	public linux.timespec expirationTime;
	public linux.pid_t childPid;
	public boolean done;
	public boolean timedOut;

	public void init(linux.pid_t pid, time.Time timeout) {
		childPid = pid;
		linux.pthread_cond_init(&timerVariable, null);
		linux.pthread_mutex_init(&timerLock, null);
		linux.clock_gettime(linux.CLOCK_REALTIME, &expirationTime);
		expirationTime.tv_sec += timeout.value();
	}
	
	public void startTimer() {
		linux.pthread_mutex_lock(&timerLock);
		while (!done) {
			int result = linux.pthread_cond_timedwait(&timerVariable, &timerLock, &expirationTime);
			if (result != 0) {
				if (result == linux.ETIMEDOUT && !done) {
					linux.kill(childPid, linux.SIGKILL);
					timedOut = true;
				}
				break;
			}
		}
		linux.pthread_mutex_unlock(&timerLock);
	}
	
	public void signalDone() {
		linux.pthread_mutex_lock(&timerLock);
		if (!timedOut) {
			done = true;
			linux.pthread_cond_signal(&timerVariable);
		}
		linux.pthread_mutex_unlock(&timerLock);
	}
}

private void countdownTimer(address data) {
	ref<TimeoutData> t = ref<TimeoutData>(data);
	
	t.startTimer();
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
