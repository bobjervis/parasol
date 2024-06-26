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
 * Provides facilities for spawning and interacting with other processes as well as process-global state information.
 */
namespace parasol:process;

import parasol:exception;
import parasol:exception.IllegalOperationException;
import parasol:log;
import parasol:pxi;
import parasol:runtime;
import parasol:storage;
import parasol:stream;
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
/**
 * A Reader reading from the process' stdin file descriptor.
 *
 * Deleting the Reader will close the stdin stream.
 */
public ref<Reader> stdin;
/**
 * A Writer writing to the process' stdout file descriptor.
 *
 * Deleting the Writer will close the stdout stream.
 */
public ref<Writer> stdout;
/**
 * A Writer writing to the process' stderr file descriptor.
 *
 * Deleting the Writer will close the stderr stream.
 */
public ref<Writer> stderr;
/**
 * Do a formatted print to the {@link stdout} Writer.
 *
 * @param format The printf format string.
 * @param arguments Zero or more arguments that correspond to the format string.
 *
 * @eur
 * @see {@link parasol:stream.Writer.printf} for complete documentation of
 * formatted printing.
 */
public int printf(string format, var... arguments) {
	return stdout.printf(format, arguments);
}

C.atexit(flushBuffers);

private void flushBuffers() {
	if (stderr != null)
		stderr.flush();
	if (stdout != null)
		stdout.flush();
}

public string binaryFilename() {
	byte[] filename;
	filename.resize(4097);
	int length = 0;
	
	if (runtime.compileTarget == runtime.Target.X86_64_WIN)
		length = windows.GetModuleFileName(null, &filename[0], filename.length());
	else if (runtime.compileTarget == runtime.Target.X86_64_LNX)
		length = linux.readlink("/proc/self/exe".c_str(), &filename[0], filename.length());
	filename.resize(length);
	string s(filename);
	return s;
}
/**
 * Get the command line used to start this program.
 *
 * The first argument in this list is the binary pxi loader used to start the program.
 *
 * The second argument is the pxi file being run. 
 * When running a Parasol script file as a simple program, the pxi is the binary of the pc
 * command.
 * Otherwise, this will have some general form of <program-name>/application.pxi. Where <program-name>
 * is some directory readable by the user.
 * This directory is either the application directory created by pbuild or a copy of it.
 * 
 * Note that when invoked as a script, any parameters passed to the pc command will appear, then
 * the script file name.
 * Only the arguments that appear after the script file name are passed to the script's main function (if
 * any).
 *
 * @return A set of strings, one string per argument.
 */
public string[] getCommandLine() {
	string[] results;
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		cmdLine := string(windows.GetCommandLine());
		// Need to research text returned when a quoted argument is passed (is that even legal?)
		results := cmdLine.split(' ');
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		reader := storage.openTextFile("/proc/self/cmdline");
		if (reader != null) {
			string partial;
			for (;;) {
				c := reader.read();
				if (c == stream.EOF)
					break;
				if (c == 0) {
					results.append(partial);
					partial = null;
				} else
					partial.append(byte(c));
			}
			if (partial != null)
				results.append(partial);
			delete reader;
		}
	}
	return results;
}
/**
 * The set of possible process execution outcomes.
 */
public enum exception_t {
	/**
	 * The process completed without producing any exceptions.
	 */
	NO_EXCEPTION,
	/**
	 * The process was aborted.
	 */
	ABORT,
	/**
	 * The process has hit a breakpoint.
	 *
	 * This is only relevant to debugging scenarios, which are not currently supported.
	 */
	BREAKPOINT,
	/**
	 * Exceeded specified timeout
	 */
	TIMEOUT,
	/**
	 * Too many exceptions raised by child process
	 */
	TOO_MANY_EXCEPTIONS,
	/**
	 * Hardware memory access violation
	 */
	ACCESS_VIOLATION,
	/**
	 * The running runtime does not know how to execute processes.
	 */
	UNKNOWN_PLATFORM,
	/**
	 * A system or application exception not known to the runtime
	 */
	UNKNOWN_EXCEPTION
}

private class SpawnPayload {
	public pointer<byte> output;
	public int outputLength;
	public int outcome;
}
/**
 * Returns the current process id.
 *
 * @return The process id or -1 if the runtime does not support this function.
 */
public int getpid() {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		return linux.getpid();
	} else
		return -1;
}
/**
 * Tests whether the process is running in a privileged state.
 *
 * For Linux, this is true if the effective uer id is zero (super user).
 *
 * @return true, if the process is privileged, false otherwise.
 */
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
	 * Set the spawn to use a pipe to collect output from stdout and stderr. This also will redirect
	 * standard input from /dev/null, which will cause the process to see an end-of-file on the first
	 * read from stdin (if any).
	 *
	 * The return value of the {@link Process.stdout stdout} method will be the read end of the pipe.
	 */
	public void captureOutput() {
		_stdioHandling = StdioHandling.CAPTURE_OUTPUT;
	}
	/**
	 * This method sets the spawn mode to use setpgrp so that the child process is a new process group
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
	/**
	 * Set the user name of the spawned process.
	 * 
	 * On Linux, this call will succeed even if the current process is not privileged. However, the
	 * subsequent spawn will fail.
	 *
	 * @param username A valid user name.
	 *
	 * @return true if the user name could be found, false otherwise.
	 */
	public boolean user(string username) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.passwd pwd;
			ref<linux.passwd> out;

			byte[] buffer;
			buffer.resize(linux.sysconf(linux.SysConf._SC_GETPW_R_SIZE_MAX));
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
	/**
	 * Execute the given command with the given arguments.
	 *
	 * The command is executed in this process' current working directory and uses this process'
	 * environment variables.
	 *
	 * @param command The path to the command to execute.
	 * @param args Zero or more string arguments to be passed to the command.
	 * 
	 * @return true if the process spawned successfully and the resulitng exit code was zero.
	 * In the event of an error during spawn, or a subsequent non-zero exit code, false is returned.
	 *
	 * @return The actual exit code returned by the spawned process, or {@code int.MIN_VALUE} if the
	 * spawn itself failed.
	 */
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
	 *
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
	/**
	 * Spawn a process using the given Parasol script and arguments.
	 *
	 * The method uses the same version of Parasol that is running the current process.
	 *
	 * @param workingDirectory If not null, the path to the working directory to run the command in.
	 * Note that if the command path is relative, it will be found relative to the working directory
	 * supplied.
	 * @param script The path to the script to execute.
	 * @param parasolLocation If not null, the path to the Parasol runtime to use when spawning the script.
	 * @param environ A map of environment variables to add to the parent process\' environment, or null
	 * to just use the parent\'s environment.
	 * @param args Zero or more string arguments to be passed to the command.
	 * 
	 * @return true if the process spawned successfully.
	 */
	public boolean spawnParasolScript(string workingDirectory, string script, string parasolLocation,
									  ref<string[string]> environ, string... args) {
		string parasolrt;
		string pc_pxi;
		ref<string[string]> copy;
		if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			if (parasolLocation == null)
				parasolLocation = "/usr/parasol/latest";
			pc_pxi = parasolLocation + "/bin/x86-64-lnx.pxi";
			parasolrt = parasolLocation + "/bin/parasolrt";
			copy = new string[string];
			if (environ != null) {
				for (key in *environ)
					(*copy)[key] = (*environ)[key];
			}
			dir := parasolLocation + "/bin";
			if (copy.contains("LD_LIBRARY_PATH"))
				(*copy)["LD_LIBRARY+PATH"] = dir + ":" + (*copy)["LD_LIBRARY_PATH"];
			else
				(*copy)["LD_LIBRARY_PATH"] = dir;
			environ = copy;
		} else if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			pc_pxi = "x86-64-win.pxi";
		}
		if (!storage.exists(pc_pxi)) {
			throw IllegalOperationException("Could not find " + pc_pxi);
		}
		string[] arguments;
		arguments.append(pc_pxi);
		arguments.append(script);
		arguments.append(args);
		success := spawn(workingDirectory, parasolrt, environ, arguments);
		delete copy;
		return success;
	}

	public boolean spawnApplication(string workingDirectory, string name, string applicationDirectory,
									  ref<string[string]> environ, string... args) {
		string parasolrt;
		string pc_pxi;
		ref<string[string]> copy;
		if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			pc_pxi = storage.path(applicationDirectory, "application.pxi");
			parasolrt = storage.path(applicationDirectory, "parasolrt");
			copy = new string[string];
			if (environ != null) {
				for (key in *environ)
					(*copy)[key] = (*environ)[key];
			}
			if (copy.contains("LD_LIBRARY_PATH"))
				(*copy)["LD_LIBRARY+PATH"] = applicationDirectory + ":" + (*copy)["LD_LIBRARY_PATH"];
			else
				(*copy)["LD_LIBRARY_PATH"] = applicationDirectory;
			environ = copy;
		} else if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			pc_pxi = "x86-64-win.pxi";
		}
		if (!storage.exists(pc_pxi)) {
			throw IllegalOperationException("Could not find " + pc_pxi);
		}
		string[] arguments;
		arguments.append(pc_pxi);
		arguments.append(args);
		success := spawn(workingDirectory, parasolrt, environ, arguments);
		delete copy;
		return success;
	}
	/**
	 * Spawn a process using the given command and arguments.
	 *
	 * The command is executed in this processes current working directory and uses this processes
	 * environment vairables.
	 *
	 * This call returns as soon as the child process is spawned. It does not wait for the child to exit.
	 *
	 * @param command The path to the command to execute.
	 * @param args Zero or more string arguments to be passed to the command.
	 * 
	 * @return true if the process spawned successfully.
	 */
	public boolean spawn(string command, string... args) {
		return spawn(null, command, null, args);
	}
	/**
	 * Spawn a process using the given command and arguments.
	 *
	 * @param workingDirectory If not null, the path to the working directory to run the command in.
	 * Note that if the command path is relative, it will be found relative to the working directory
	 * supplied.
	 * @param command The path to the command to execute.
	 * @param environ A map of environment variables to add to the parent process\' environment, or null
	 * to just use the parent\'s environment.
	 * @param args Zero or more string arguments to be passed to the command.
	 * 
	 * @return true if the process spawned successfully.
	 */
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
							stderr.printf("setuid to %d FAILED\n", _user);
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
						int result = linux.chdir(workingDirectory.c_str());
						if (_stdioHandling == StdioHandling.IGNORE) {
							if (result != 0) {
								string s;

								s.printf("chdir %s error: %s\n", workingDirectory, linux.strerror(linux.errno()));
								linux.write(1, &s[0], s.length());
							}
						}
					}
					if (environ != null) {
						for (string[string].iterator i = environ.begin(); i.hasNext(); i.next())
							environment.set(i.key(), i.get());
					}
					childStartupHook();
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
					declareChild();
					lock (*this) {
						_running = true;
					}
				}
			}
			return true;		// Only the parent process gets here.
		}
		return false;
	}

	protected void declareChild() {
		pendingChildren.declareChild(_pid, processExitInfoWrapper, this);
	}
	/**
	 * After a spawn, wait for the child process to exit.
	 *
	 * If the child process has not terminated, the calling thread will wait for it to exit.
	 *
 	 * @return The exit status of the child process.
	 */
	public int waitForExit() {
		lock (*this) {
//			logger.debug("wait for %d running? %s", _pid, string(_running));
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
	/**
	 * Kill a spawned child process.
	 *
	 * The call will return immediately. You should then call {@link waitForExit} if
	 * you wish to wait for the child to actually terminate. Note that if the signal can
	 * be caught or ignored, the child process may not terminate in response to this call.
	 *
	 * @param signal The signal to use to kill the child process.
	 *
	 * @return true if the child process was successfully sent the signal, false otherwise.
	 */
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
	 * Retrieve the file descriptor for the child process\' output.
	 *
	 * This call will only return a valid file descriptor if either {@link collectOutput} or
	 * {@link runInteractive} were called before calling spawn.
	 *
	 * @return The file descriptor, or -1 if no special standard output handling was specified.
	 */
	public int stdout() {
		if (_stdioHandling != StdioHandling.IGNORE)
			return _stdout;
		else
			return -1;
	}
	/**
	 * Retrieve the operating system user id of the child process.
	 *
	 * This call will only return a non-zero value if a call was first placed to {@link user}.
	 *
 	 * @return A non-zero user id if one was defined, or zero if no valid call to {@link user} was made.
	 */
	public linux.uid_t uid() {
		return _user;
	}

	private static void processExitInfoWrapper(int exitCode, address arg) {
		ref<Process>(arg).processExitInfo(exitCode);
	}
	/**
	 * Process exit information.
	 *
	 * This method cannot be directly called, but sub-classes of Process can override the definition
	 * and provide special processing.
	 *
	 * Failing to call the {@code super.processExitInfo} will fail to notify any threads waiting for
	 * the child process to exit, nor will future calls to {@link waitForExit} return.
	 *
	 * @param exitCode The reported exit code of the terminated child process.
	 */
	protected void processExitInfo(int exitCode) {
//		printf("processExitInfo pid = %d: %d %d\n", info.si_pid, info.si_code, info.si_status);
//		logger.format(log.DEBUG, "child exit %d with %d", _pid, exitCode);
		lock (*this) {
			_running = false;
			_exitStatus = exitCode;
			notifyAll();
		}
	}
	/**
	 * Allow a sub-class of Process to define a startup method hook.
	 *
	 * By overriding this method, an application on Linux could use ptrace
	 * to make the child process after a fork become a 'tracee'. Such applications
	 * include a tracer or a debugger.
	 */
	protected void childStartupHook() {
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
	private boolean _shutdown;

	void declareChild(linux.pid_t pid, void (int, address) handler, address arg) {
		ref<PendingChild> pc = new PendingChild(pid, handler, arg);
		if (_waiter == null) {
			_waiter = new Thread();
			_waiter.start(childWaiter, null);
		}
		for (int i = 0; i < _children.length(); i++)
			if (_children[i] == null) {
				_children[i] = pc;
				notify();
				return;
			}
		_children.append(pc);
		notify();
	}

	ref<Thread> declareShutdown() {
		_shutdown = true;
		notify();
		return _waiter;
	}

	boolean waitForChild() {
		wait();
		return !_shutdown;
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
		while (pendingChildren.waitForChild()) {
			int exitStatus;
			linux.pid_t pid = linux.waitpid(-1, &exitStatus, 0);
			if (pid > 0)
				pendingChildren.reportChildStateChange(pid, exitStatus);
			else if (pid < 0) {
				if (linux.errno() == linux.ECHILD)
					break;
			}
		}
	}
}

private PendingChildren pendingChildren;
private ShutdownSignaller shutdown;

class ShutdownSignaller {
	~ShutdownSignaller() {
		ref<Thread> t = pendingChildren.declareShutdown();
		if (t != null) {
			t.join();
			delete t;
		}
	}
}

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
			if (timer.timedOut())
				linux.kill(pid, linux.SIGKILL);
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
/**
 * Terminate the current process.
 */
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
		long result = linux.read(d.fd, &buffer[0], buffer.length());
		if (result < 0)
			break;
		if (d.stopOnZero && result == 0)
			break;
		for (int i = 0; i < int(result); i++)
			if (buffer[i] != '\r')
				d.output.append(buffer[i]);
	}
}

private monitor class TimeoutData {
	boolean _done;
	boolean _timedOut;
	int _exitStatus;

	TimeoutData() {
		_exitStatus = -1;			// indicates not actually exitted.
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
/**
 * The current process environment variables.
 */
public Environment environment;
/**
 * This call provides access to the underlying process environment.
 *
 * The process environment is a set of key-value pairs of strings.
 *
 * The key is case sensitive.
 */
public class Environment {
	private Environment() {
	}
	/**
	 * Get an environment variable.
	 *
	 * @param key The environment variable name.
	 *
	 * @return The environment variable value, or null if the given environment variable is not defined.
	 */
	public string get(string key) {
		return string(C.getenv(key.c_str()));
	}
	/**
	 * Set an environment variable.
	 *
	 * This function will replace any existing value for the environment variable.
	 *
	 * On Linux, if the name contians an equal sign (=), the call fails.
	 *
	 * @param key The name of the environment variable to set.
	 * @param value The new value for the environment vairable.
	 *
	 * @return true if the environment variable was successfully defined, false otherwise.
	 */
	public boolean set(string key, string value) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			assert(false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			if (value != null)
				return linux.setenv(key.c_str(), value.c_str(), 1) == 0;
			else
				return linux.unsetenv(key.c_str()) == 0;
		} else
			assert(false);
		return false;
	}
	/**
	 * Remove an environment variable
	 */
	public void remove(string key) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			assert(false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.unsetenv(key.c_str());
		} else
			assert(false);
	}
}
