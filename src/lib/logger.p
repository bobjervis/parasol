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
namespace parasol:log;

import parasol:math;
import parasol:process;
import parasol:runtime;
import parasol:thread;
import parasol:time;
import parasol:types.Queue;

// Message levels are positive to indicate an informative, but not alarming
// condition or event, while negative to indicate a cause for concern.
// Log filtering is done on the magnitude of the level, so that high level
// positive messages can be logged without artificially flagging them as FATAL or
// ERROR. Log level zero implies that the level is taken from the parent.

@Constant
public int FATAL = -5;
@Constant
public int ERROR = -4;
@Constant
public int WARN = -3;
@Constant
public int INFO = 2;
@Constant
public int DEBUG = 1;

Monitor globalState;

ref<Logger>[string] loggerMap;
/**
 * Get a named logger.
 *
 * Loggers form a tree, with a single, un-named logger designated as the Root Logger.
 * All other loggers have names that consist of non-empty text sequences separated by periods.
 *
 * @param path This function fetches the logger named by the path argument. If the path is null,
 * then the Root Logger is returned.
 *
 * @return The function returns the named logger, creating Logger objects as needed to complete the
 * name hierarchy of the path. If the path either begins with or ends with a period, contains two consecutive
 * periods or is empty (""), the function returns null.
 *
 * @threading This function is thread-safe.
 */
public ref<Logger> getLogger(string path) {
	ref<Logger> result;

	if (path == null)
		return &rootLogger;
	if (path.length() == 0)
		return null;
	string[] parts = path.split('.');
	for (i in parts)
		if (parts[i].length() == 0)
			return null;
	lock (globalState) {
		result = loggerMap[path];
		if (result != null)
			return result;
		ref<LogChain> current = &chainRoot;
		for (i in parts) {
			ref<LogChain> child = current.children[parts[i]];
			if (child == null) {
				child = new LogChain;
				child.thisLogger = new Logger(current.thisLogger, null);
				string newPath = parts[0];
				for (int j = 1; j <= i; j++) {
					newPath.append('.');
					newPath.append(parts[j]);
				}
				loggerMap[newPath] = child.thisLogger;
				current.children[parts[i]] = child;
			}
			current = child;
		}
		return current.thisLogger;
	}
}

ConsoleLogHandler defaultHandler;
Logger rootLogger(null, &defaultHandler);
LogChain chainRoot = {
	thisLogger: &rootLogger
};
/**
 * The Logger class is designed to provide a convenient way for programmers to decorate a program
 * with output statements that can be configured at run time to write to designated files, remote servers or the
 * program's standard output. 
 *
 * The various output methods, like 'debug' or 'info', are all thread-safe. The actual writing to any output
 * is performed by a separate thread, so the logging thread is minimally delayed when logging.
 *
 * The parent-child relationship among Logger objects is determined at the time that the Logger is created and
 * is entirely based on the name hierarchy used in the program.
 */
public monitor class Logger {
	private int _level;
	private ref<Logger> _parent;
	private ref<LogHandler> _destination;

	Logger(ref<Logger> parent, ref<LogHandler> destination) {
		_parent = parent;
		_destination = destination;
	}

	public int setLevel(int level) {
		int result = _level;
		if (level != int.MIN_VALUE)
			_level = math.abs(level);
		return result;
	}

	public ref<Logger> parent() {
		return _parent;
	}

	public ref<LogHandler> setDestination(ref<LogHandler> newHandler) {
		ref<LogHandler> result = _destination;
		_destination = newHandler;
		return result;
	}

	public void info(string msg) {
		if (msg == null)
			return;
		if (needToCheck(INFO))
			queueEvent(runtime.returnAddress(), INFO, msg);
	}

	public void debug(string msg) {
		if (msg == null)
			return;
		if (needToCheck(DEBUG))
			queueEvent(runtime.returnAddress(), DEBUG, msg);
	}

	public void warn(string msg) {
		if (msg == null)
			return;
		if (needToCheck(WARN))
			queueEvent(runtime.returnAddress(), WARN, msg);
	}

	public  void error(string msg) {
		if (msg == null)
			return;
		if (needToCheck(ERROR))
			queueEvent(runtime.returnAddress(), ERROR, msg);
	}

	public void fatal(string msg) {
		if (msg == null)
			return;
		if (needToCheck(FATAL))
			queueEvent(runtime.returnAddress(), FATAL, msg);
	}

	public void log(int level, string msg) {
		if (level < -5 || level > 5)
			throw IllegalArgumentException(string(level));
		if (msg == null)
			return;
		if (needToCheck(level))
			queueEvent(runtime.returnAddress(), level, msg);
	}

	public void format(int level, string format, var... arguments) {
		if (level < -5 || level > 5)
			throw IllegalArgumentException(string(level));
		if (needToCheck(level)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), level, msg);
		}
	}

	private boolean needToCheck(int level) {
		if (_level == 0) {
			if (_parent != null)
				return _parent.needToCheck(level);
			else // this is the Root Logger and it has no filter, so allow all LogEvent's to print.
				return true;
		} else if (math.abs(level) >= _level)
			return true;
		return false;
	}
	/**
	 * Note: returnAddress is not yet implemented.
	 */
	private void queueEvent(address returnAddress, int level, string msg) {
		// All log messages go through here. Level has been confirmed as high enough to care about.
		LogEvent logEvent = {
			when: time.now(), 
			level: level, 
			msg: msg, 
			returnAddress: returnAddress,
			threadId: thread.currentThread().id(),	// The thread may disappear before we write the message,
													// so remember the thread id, not the Thread object.
		};

		ref<Logger> context = this;
		do {
			lock (*context) {
				if (_destination != null)
					_destination.enqueue(&logEvent);
				context = _parent;
			}
		} while (context != null);
	}
}

class LogChain {
	ref<Logger> thisLogger;
	ref<LogChain>[string] children;
};

class LogEvent {
	time.Time when;
	int level;
	string msg;
	address returnAddress;
	int threadId;

	ref<LogEvent> clone() {
		ref<LogEvent> logEvent = new LogEvent;
		*logEvent = *this;
		return logEvent;
	}
}

public class ConsoleLogHandler extends LogHandler {
	ref<time.Formatter> _formatter;

	public void processEvent(ref<LogEvent> logEvent) {
		if (_formatter == null)
			_formatter = new time.Formatter("yyyy/MM/dd HH:mm:ss.SSS");
		time.Date d(logEvent.when, &time.UTC);
		string logTime = _formatter.format(&d);				// Note: if the format includes locale-specific stuff,
															// like a named time zone or month, we would have to add
															// some arguments to the format call.
		string lab = label(logEvent.level);

		printf("%s %d %s %s\n", logTime, logEvent.threadId, lab, logEvent.msg);
		process.stdout.flush();
	}
}

public monitor class LogHandler {
	ref<thread.Thread> _writeThread;
	private Queue<ref<LogEvent>> _events;

	~LogHandler() {
		if (_writeThread != null) {
			LogEvent terminator;

			enqueue(&terminator);
			_writeThread.join();
		}
	}

	public void close() {
		if (_writeThread != null) {
			LogEvent shutdown = { msg: null };
			enqueue(&shutdown);
			_writeThread.join();
			_writeThread = null;
		}
	}

	void enqueue(ref<LogEvent> logEvent) {
		_events.enqueue(logEvent.clone());
		if (_writeThread == null) {
			_writeThread = new thread.Thread("LogWriter");
			_writeThread.start(writeWrapper, this);
		}
		notify();
	}

	ref<LogEvent> dequeue() {
		wait();
		return _events.dequeue();
	}

	public abstract void processEvent(ref<LogEvent> logEvent);

	public string label(int level) {
		switch (level) {
		case 1:
			return "DEBUG";

		case 2:
			return "INFO";

		case -3:
			return "WARN";

		case -4:
			return "ERROR";

		case -5:
			return "FATAL";
		}
		string s;
		if (level >= 0)
			s.printf("NOTICE %d", level);
		else
			s.printf("CAUTION %d", level);
		return s;
	}
}
/**
 * writeWrapper
 *
 *	This method is the main loop of the log writer thread. Once started, it remains running waiting for
 *	any thread to write some data.
 */
void writeWrapper(address arg) {
	ref<LogHandler> handler = ref<LogHandler>(arg);
	for (;;) {
		ref<LogEvent> logEvent = handler.dequeue();
		if (logEvent.msg == null) {
			delete logEvent;
			break;
		} else {
			handler.processEvent(logEvent);
			delete logEvent;
		}
	}
}

