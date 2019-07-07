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
 * Provides facilities for generating event logs.
 *
 * A process can have any number of logger objects. 

 * Each logger is assigned a name when it is created. Names can contain any character,
 * except that the period (.) character has special significance. Each period in a logger
 * name delineates a component of a path. A properly formatted logger name cannot begin
 * or end with a period and cannot contain two consecutive periods.
 *
 * For example, {@code "a.b.c"} is a valid logger name. In a program that uses that logger name
 * actually creates three loggers, {@code "a"}, {@code "a.b"} and {@code "a.b.c"}.
 *
 * As a special case, the empty string {@code ""} is the Root Logger.
 *
 * Every Logger but the root logger has a parent. The parent of all loggers with no periods in their
 * name is the root logger. For all other loggers, the parent's name is found by truncating the logger's
 * name at the last period. This the parent of {@code "a.b.c"} is {@code "a.b"}.
 *
 * Every logger can have a level from 1 through 6. All loggers initially have a level of 1. You may change
 * the level setting of a logger by calling the {@link Logger.setLevel} method.
 *
 * All messages have a level from -5 through 5, excluding zero, based either on the name of the
 * method used to create the message (for example, {@link Logger.info}), or is passed as an explicit parameter.
 *
 * When a message is logged, the logger's level is checked and if the magnitude of the message's level is 
 * less than that of it's logger, the message is discarded. Then, if the logger has a defined destination,
 * the message is written to that destination. Otherwise, the message is passed to the logger's parent.
 * If the root logger has no destination then all messages that reach it are discarded.
 *
 * You may, for example, set the level of the logger named "parasol" to {@link log.INFO} in order to set
 * all logging by the Parasol runtime to exclude {@link log.DEBUG} level messages.
 */
namespace parasol:log;

import parasol:math;
import parasol:process;
import parasol:runtime;
import parasol:thread;
import parasol:time;
import parasol:types.Queue;
import parasol:exception.IllegalArgumentException;

// Message levels are positive to indicate an informative, but not alarming
// condition or event, while negative to indicate a cause for concern.
// Log filtering is done on the magnitude of the level, so that high level
// positive messages can be logged without artificially flagging them as FATAL or
// ERROR. Log level zero implies that the level is taken from the parent.

/**
 * A message level for the most important dangerous messages.
 *
 * Messages using this level typically will precede an application shutdown.
 */
@Constant
public int FATAL = -5;
/**
 * A message level for important dangerous messages.
 *
 * Messages should use this level if the condition is actionable and indicates a defective condition 
 * in the application.
 */
@Constant
public int ERROR = -4;
/**
 * A message level for unimportant or not very dangerous messages.
 *
 * Messages should use this level if the condition is not especially actionable, but should be
 * marked in the log for future reference.
 */
@Constant
public int WARN = -3;
/**
 * A message level for normal operating conditions that might be worth noting in a production log.
 */
@Constant
public int INFO = 2;
/**
 * A message level for messages that should not typically be enabled in a production setting.
 *
 * Debugging messages are often verbose and enabling them will often produce large volumes of log data.
 */
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
/**
 * The default handler for the root logger.
 *
 * If you are configuring a complex logging environment, you could
 * assign this handler to other loggers. Using this handler rather than constructing a new one is preferred, since each
 * {@link LogHandler} object starts its own write thread.
 */
public ConsoleLogHandler defaultHandler;
Logger rootLogger(null, &defaultHandler);
LogChain chainRoot = {
	thisLogger: &rootLogger
};
/**
 * If you want to use the logger infrastructure across a linux fork, you will need to make this call. It will
 * reset the logger thread states as appropriate for the child to begin logging again. Any log statements made in
 * a child process will queue up until this call is made. Making this call more than once within a single process
 * (or calling it at all after any logging statements are made in a parent process) will produce unexpected results,
 * including the possibility of out-of-order log statements.
 */
public void resetChildProcess() {
	defaultHandler.newThread();
}

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
		_level = 1;
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

	public void info(string format, var... arguments) {
		if (needToCheck(INFO)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), INFO, msg);
		}
	}

	public void debug(string format, var... arguments) {
		if (needToCheck(DEBUG)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), DEBUG, msg);
		}
	}

	public void warn(string format, var... arguments) {
		if (needToCheck(WARN)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), WARN, msg);
		}
	}

	public  void error(string format, var... arguments) {
		if (needToCheck(ERROR)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), ERROR, msg);
		}
	}

	public void fatal(string format, var... arguments) {
		if (needToCheck(FATAL)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), FATAL, msg);
		}
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

	public void memDump(int level, string caption, address buffer, long length, long startingOffset) {
		if (level < -5 || level > 5 || level == 0)
			throw IllegalArgumentException(string(level));
		if (!needToCheck(level))
			return;
		pointer<byte> printed = pointer<byte>(startingOffset);
		pointer<byte> firstRow = printed + -int(startingOffset & 15);
		pointer<byte> data = pointer<byte>(buffer) + -int(startingOffset & 15);
		pointer<byte> next = printed + int(length);
		pointer<byte> nextRow = next + ((16 - int(next) & 15) & 15);
		string output;
		if (caption != null)
			output.printf("%s", caption);
		else
			output.printf("Memory dump");
		output.printf("\n");
		for (pointer<byte> p = firstRow; int(p) < int(nextRow); p += 16, data += 16) {
			dumpPtr(&output, p);
			output.printf(" ");
			for (int i = 0; i < 8; i++) {
				if (int(p + i) >= int(printed) && int(p + i) < int(next))
					output.printf(" %2.2x", int(data[i]));
				else
					output.printf("   ");
			}
			output.printf(" ");
			for (int i = 8; i < 16; i++) {
				if (int(p + i) >= int(printed) && int(p + i) < int(next))
					output.printf(" %2.2x", int(data[i]));
				else
					output.printf("   ");
			}
			output.printf(" ");
			for (int i = 0; i < 16; i++) {
				if (int(p + i) >= int(printed) && int(p + i) < int(next)) {
					if (data[i].isPrintable())
						output.printf("%c", int(data[i]));
					else
						output.printf(".");
				} else
					output.printf(" ");
			}
			output.printf("\n");
		}
		log(level, output);
	}
	
	private void dumpPtr(ref<string> output, address x) {
		pointer<long> np = pointer<long>(&x);
		output.printf("%16.16x", *np);
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
	/**
	 * Wait until all downstream log handlers have written their queues.
	 */
	public void drain() {
		ref<Logger> context = this;
		do {
			lock (*context) {
				if (_destination != null)
					_destination.drain();
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

monitor class LogHandlerVolatileData {
	ref<thread.Thread> _writeThread;
	Queue<ref<LogEvent>> _events;
	Monitor _drainDone;
	int _shouldSignal;

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

	void writeDone() {
		if (_events.isEmpty()) {
			while (_shouldSignal > 0) {
				_drainDone.notify();
				_shouldSignal--;
			}
		}
	}

	void newThread() {
		_writeThread = null;			// Just assume that no such thread exists in the process.
	}
}

public class LogHandler extends LogHandlerVolatileData {

	~LogHandler() {
		close();
	}

	public void close() {
		ref<thread.Thread> t;

		lock (*this) {
			if (_writeThread != null) {
				LogEvent terminator;

				enqueue(&terminator);
				t = _writeThread;
			}
		}
		// We really can't do this call under this lock, since the write thread wants to use the same lock
		if (t != null) {
			t.join();
			lock (*this) {
				_writeThread = null;
			}
		}
	}

	public abstract void processEvent(ref<LogEvent> logEvent);
	/**
	 * Compose a label string for the given level.
	 *
	 * @param level The message level to be formatted.
	 *
	 * @return A string giving some sense of the importance and danger of a message. Words like "DEBUG", "INFO" or 
	 * "NOTICE" suggest non-dangerous messages of increasing importance. Words like "CAUTION", "WARN", "ERROR" or
	 * "FATAL" denote messages of increasing importance and danger.
	 */
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

	/**
	 * block the calling thread until the queue is empty
	 */
	void drain() {
		ref<Monitor> mon;
		lock (*this) {
			if (!_events.isEmpty()) {
				mon = &_drainDone;
				_shouldSignal++;
			}
		}
		if (mon != null)
			mon.wait();
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
			handler.writeDone();
			break;
		} else {
			handler.processEvent(logEvent);
			delete logEvent;
			handler.writeDone();
		}
	}
}

