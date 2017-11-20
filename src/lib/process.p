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

import parasol:pxi;
import parasol:runtime;
import parasol:pxi.SectionType;
import parasol:storage;
import parasol:time;
import parasol:memory;
import parasol:thread.Thread;
import native:windows;
import native:linux;
import native:C;

public string binaryFilename() {
	byte[] filename;
	filename.resize(storage.FILENAME_MAX + 1);
	int length = 0;
	
	if (runtime.compileTarget == pxi.SectionType.X86_64_WIN)
		length = windows.GetModuleFileName(null, &filename[0], filename.length());
	else if (runtime.compileTarget == pxi.SectionType.X86_64_LNX)
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
	if (runtime.compileTarget == SectionType.X86_64_LNX) {
		return linux.getpid();
	} else
		return -1;
}

public boolean isPrivileged() {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		// TODO: Check for this being a process with elevated privileges, for now, ignore this possibility.
		return false;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		return linux.geteuid() == 0;
	} else
		return false;
}

init();
private void init() {
	if (runtime.compileTarget == SectionType.X86_64_LNX) {
		linux.struct_sigaction action;
		
		action.set_sa_sigaction(sigChldHandler);
		action.sa_flags = linux.SA_SIGINFO;
		int result = linux.sigaction(linux.SIGCHLD, &action, null);
		if (result != 0) {
			printf("Failed to regsiter SIGCHLD handler: %d\n", result);
			linux.perror("From sigaction".c_str());
		}
	}
}

public class Process {
	private DrainData _stdout;
	private ref<Thread> _drainer;

	public Process() {
	}

	public boolean spawn(string command, string... args) {
		return spawn(null, command, null, args);
	}

	public boolean spawn(string workingDirectory, string command, ref<string[]> environ, string... args) {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
//			SpawnPayload payload;
			
//			int result = debugSpawnImpl(&command[0], &payload, timeout.value());
//			string output = string(payload.output, payload.outputLength);
//			exception_t outcome = exception_t(payload.outcome);
//			disposeOfPayload(&payload);
//			return result, output, outcome;
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			pointer<byte>[] fullArgs;

			fullArgs.append(command.c_str());
			for (int i= 0; i < args.length(); i++)
				fullArgs.append(args[i].c_str());
			fullArgs.append(null);

			pointer<pointer<byte>> argv = &fullArgs[0];

			linux.pid_t pid;

// TODO: Implement some scheme to capture the command output.

//			int[] pipefd;

//			pipefd.resize(2);

//			if (linux.pipe(&pipefd[0]) < 0)
//				return false;
			printf("About to exec '%s'", command);
			for (int i = 0; i < args.length(); i++)
				printf(" '%s'", args[i]);
			printf("\n");
			pid = linux.fork();
			if (pid == 0) {
//				linux.close(pipefd[0]);
//				linux.dup2(pipefd[1], 1);
//				linux.dup2(pipefd[1], 2);
				// This is the child process
				if (workingDirectory != null) {
					linux.chdir(workingDirectory.c_str());
				}
				if (environ != null) {
					for (int i = 0; i < environ.length(); i++) {
						int idx = (*environ)[i].indexOf('=');
						if (idx < 0)
							environment.set((*environ)[i], "");
						else
							environment.set((*environ)[i].substring(0, idx), (*environ)[i].substring(idx + 1));
					}
				}
				linux.execv(argv[0], argv);
				linux._exit(-1);
			} else {
//				linux.close(pipefd[1]);

//				_drainer = new Thread();
//				_stdout.fd = pipefd[0];

//				_drainer.start(drain, &_stdout);
/*
				linux.pid_t terminatedPid = linux.waitpid(pid, &exitStatus, 0);
				if (terminatedPid != pid)
					return -3, null, exception_t.NO_EXCEPTION;
				_drainer.join();
				delete _drainer;
				linux.close(_stdout.fd);
				if (linux.WIFEXITED(exitStatus))
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
 */
			}
			return true;		// Only the parent process gets here.
		}
		return false;
	}
}
/**
 * Our SIGCHLD handler does nothing but return
 */
private void sigChldHandler(int x, ref<linux.siginfo_t> info, address arg) {
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

public int, string, exception_t execute(string command, time.Time timeout) {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		SpawnPayload payload;
		
		int result = debugSpawnImpl(&command[0], &payload, timeout.value());
		string output = string(payload.output, payload.outputLength);
		exception_t outcome = exception_t(payload.outcome);
		disposeOfPayload(&payload);
		return result, output, outcome;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		pointer<pointer<byte>> argv;
		
		argv = parseCommandLine(command);
		if (argv == null) {
			return -1, null, exception_t.NO_EXCEPTION;
		}
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
			linux.execv(argv[0], argv);
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

public int, string, exception_t spawnInteractive(string command, string stdin, time.Time timeout) {
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		SpawnPayload payload;
		
		int result = debugSpawnInteractiveImpl(&command[0], &payload, stdin, timeout.value());
		string output = string(payload.output, payload.outputLength);
		exception_t outcome = exception_t(payload.outcome);
		disposeOfPayload(&payload);
		return result, output, outcome;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		pointer<pointer<byte>> argv;
		
		argv = parseCommandLine(command);
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

private pointer<pointer<byte>> parseCommandLine(string command) {
	if (command == null)
		return null;
	int argCount = 0;
	boolean inToken = false;
	for (int i = 0; i < command.length(); i++) {
		if (command[i].isSpace())
			inToken = false;
		else if (!inToken) {
			argCount++;
			inToken = true;
		}
	}
	pointer<pointer<byte>> argv = pointer<pointer<byte>>(memory.alloc((argCount + 1) * address.bytes + command.length() + 1));
	pointer<byte> cmdCopy = pointer<byte>(argv + argCount + 1);
	C.memcpy(cmdCopy, &command[0], command.length());
	argCount = 0;
	inToken = false;
	byte delimiter;
	for (int i = 0; i < command.length(); i++) {
		if (delimiter != 0) {
			if (cmdCopy[i] == delimiter) {
				cmdCopy[i] = 0;
				inToken = false;
				delimiter = 0;
			}
		} else if (command[i].isSpace()) {
			cmdCopy[i] = 0;
			inToken = false;
		} else if (!inToken) {
			if (cmdCopy[i] == '\'' || cmdCopy[i] == '"') {
				delimiter = cmdCopy[i];
				argv[argCount] = cmdCopy + i + 1; 
			} else
				argv[argCount] = cmdCopy + i; 
			argCount++;
			inToken = true;
		}
	}
	// If there was a delimited argument, and it wasn't closed reject the command-line.
	if (delimiter != 0)
		return null;
	return argv;
}

private class DrainData {
	public int fd;
	public string output;
}

private void drain(address data) {
	ref<DrainData> d = ref<DrainData>(data);
	byte[] buffer;
	
	buffer.resize(64*1024);
	for (;;) {
		int result = linux.read(d.fd, &buffer[0], buffer.length());
		if (result <= 0)
			break;
		d.output.append(&buffer[0], result);
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
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			assert(false);
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.setenv(key.c_str(), value.c_str(), 1);
		} else
			assert(false);
	}

	public void remove(string key) {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			assert(false);
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			linux.unsetenv(key.c_str());
		} else
			assert(false);
	}
}
