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
 * @threading The various output methods, like 'debug' or 'info', are all thread-safe. The actual writing to any output
 * is performed by a separate thread, so the logging thread is minimally delayed when logging.
 *
 * The parent-child relationship among Logger objects is determined at the time that the Logger is created and
 * is entirely based on the name hierarchy used in the program. Messages are written to a Logger and then passed from
 * the logger up its parent chain toward the root logger until either a logger is encountered whose importance level is 
 * larger in magnitude than the message's importance level.
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
	/**
	 * Sets the message importance level for the given logger. All messages that reach this logger are checked
	 * against this importance level.
	 *
	 * @param level The new importance level for this logger.
	 *
	 * @return The previous value of the importance level.
	 *
	 * @threading This method is thread-safe.
	 *
	 * @exception IllegalArgumentException Thrown if the level parameter is not in the range from -5
	 * through 5, or is zero.
	 */
	public int setLevel(int level) {
		if (level < -5 || level > 5 || level == 0)
			throw IllegalArgumentException(string(level));
		int result = _level;
		_level = math.abs(level);
		return result;
	}
	/**
	 * Retrieve the logger's parent logger.
	 *
	 * This property cannot change during the lifetime of a logger.
	 *
	 * @return The parent of this logger, null if this logger is the root logger.
	 */
	public ref<Logger> parent() {
		return _parent;
	}
	/**
	 * Set the destination {@link LogHandler}.
	 *
	 * Setting the destination to null means that all messages reaching this logger
	 * will be passed to the parent. If this is the root logger, setting the destination
	 * for the root logger to null will cause all messages reaching the root logger to be
	 * discarded, regardless of importance.
	 *
	 * @param newHandler The value of the new log handler for this logger.
	 *
	 * @return The previous value of the destination.
	 *
	 * @threading This method is thread-safe.
	 */
	public ref<LogHandler> setDestination(ref<LogHandler> newHandler) {
		ref<LogHandler> result = _destination;
		_destination = newHandler;
		return result;
	}
	/**
	 * Print a formatted messages with importance {@link INFO}.
	 *
	 * Calling this method is equivalent to:
	 *
	 *<pre>{@code format(INFO, format, arguments)}
	 *</pre>
	 * @param format A format string. See {@link stream.Writer.printf} for details.
	 * @param arguments The argument list corresponding to the format string.
	 *
	 * @threading This method is thread-safe.
	 */
	public void info(string format, var... arguments) {
		if (needToCheck(INFO)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), INFO, msg);
		}
	}
	/**
	 * Print a formatted messages with importance {@link DEBUG}.
	 *
	 * Calling this method is equivalent to:
	 *
	 *<pre>{@code format(DEBUG, format, arguments)}
	 *</pre>
	 * @param format A format string. See {@link stream.Writer.printf} for details.
	 * @param arguments The argument list corresponding to the format string.
	 *
	 * @threading This method is thread-safe.
	 */
	public void debug(string format, var... arguments) {
		if (needToCheck(DEBUG)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), DEBUG, msg);
		}
	}
	/**
	 * Print a formatted messages with importance {@link WARN}.
	 *
	 * Calling this method is equivalent to:
	 *
	 *<pre>{@code format(WARN, format, arguments)}
	 *</pre>
	 * @param format A format string. See {@link stream.Writer.printf} for details.
	 * @param arguments The argument list corresponding to the format string.
	 *
	 * @threading This method is thread-safe.
	 */
	public void warn(string format, var... arguments) {
		if (needToCheck(WARN)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), WARN, msg);
		}
	}
	/**
	 * Print a formatted messages with importance {@link ERROR}.
	 *
	 * Calling this method is equivalent to:
	 *
	 *<pre>{@code format(ERROR, format, arguments)}
	 *</pre>
	 * @param format A format string. See {@link stream.Writer.printf} for details.
	 * @param arguments The argument list corresponding to the format string.
	 *
	 * @threading This method is thread-safe.
	 */
	public  void error(string format, var... arguments) {
		if (needToCheck(ERROR)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), ERROR, msg);
		}
	}
	/**
	 * Print a formatted messages with importance {@link FATAL}.
	 *
	 * Calling this method is equivalent to:
	 *
	 *<pre>{@code format(FATAL, format, arguments)}
	 *</pre>
	 * @param format A format string. See {@link stream.Writer.printf} for details.
	 * @param arguments The argument list corresponding to the format string.
	 *
	 * @threading This method is thread-safe.
	 */
	public void fatal(string format, var... arguments) {
		if (needToCheck(FATAL)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), FATAL, msg);
		}
	}
	/**
	 * Print a literal string with the given importance
	 *
	 * The importance level is checked against the logger's current level. If the message
	 * has at least the same magnitude of importance as the logger level setting, the
	 * message is processed. If the logger has a non-null destination, the message is printed
	 * to that destination and processing terminates. Otherwise, the message is passed to the
	 * parent logger. If this is the root logger, and there is no destination the message is discarded.
	 *
	 * @param level The importance level of the message.
	 * @param msg The content of the message. If the value is null, no message is logged.
	 *
	 * @threading This method is thread-safe.
	 *
	 * @exception IllegalArgumentException Thrown if the level parameter is not in the range from -5
	 * through 5, or is zero.
	 */
	public void log(int level, string msg) {
		if (level < -5 || level > 5 || level == 0)
			throw IllegalArgumentException(string(level));
		if (msg == null)
			return;
		if (needToCheck(level))
			queueEvent(runtime.returnAddress(), level, msg);
	}
	/**
	 * Print a formatted string with the given importance
	 *
	 * Calling this method is equivalent to:
	 *
	 *<pre>{@code
	 * string msg;
	 * msg.printf(format, arguments);
	 * log(level, msg);}
	 *</pre>
	 * @param level The importance level of the message.
	 * @param format A format string. See {@link stream.Writer.printf} for details.
	 * @param arguments The argument list corresponding to the format string.
	 *
	 * @threading This method is thread-safe.
	 *
	 * @exception IllegalArgumentException Thrown if the level parameter is not in the range from -5
	 * through 5, or is zero.
	 */
	public void format(int level, string format, var... arguments) {
		if (level < -5 || level > 5 || level == 0)
			throw IllegalArgumentException(string(level));
		if (needToCheck(level)) {
			string msg;

			msg.printf(format, arguments);
			queueEvent(runtime.returnAddress(), level, msg);
		}
	}
	/**
	 * Print a formatted memory dump with the given importance.
	 *
	 * A caption is displayed as the first line of the logging message. It is followed by one or more lines
	 * of formatted text. Each line begins with the offset of the next bytes, beginning with the starting offset.
	 * This is followed by up to 16 hexadecimal digit pairs, each representing a byte. The same 16 bytes are
	 * then followed by the same byte values, printed as ASCII text or a period if the byte has a value higher than 
	 * 127 or is not a printable ASCII character.
	 *
	 * Note: The memory dump format is inspired by the memory dumps produced by the IBM 360 mainframe.
	 *
	 * @param level The importance level of the message.
	 * @param caption If not null, this string will appear as the first line of the log output for this
	 * message.
	 * @param buffer The memory address to start dumping memory.
	 * @param length The number of bytes to dump.
	 * @param startingOffset The value to use when labelling the memory contents. A value of -1 indicates that
	 * the machine address of the buffer should be used.
	 * 
	 * @threading This method is thread-safe.
	 *
	 * @exception IllegalArgumentException Thrown if the level parameter is not in the range from -5
	 * through 5, or is zero.
	 */
	public void memDump(int level, string caption, address buffer, long length, long startingOffset) {
		if (level < -5 || level > 5 || level == 0)
			throw IllegalArgumentException(string(level));
		if (!needToCheck(level))
			return;
		if (startingOffset == -1)
			startingOffset = long(buffer);
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
		queueEvent(runtime.returnAddress(), level, output);
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
	 *
	 * Beginning with this logger and proceeding toward the root logger, this
	 * method finds the first non-null destination value and blocks until all messages that were in
	 * the destination's message queue have been written.
	 *
	 * Using this method a thread may write a log message, call this method and then immediately call
	 * {@link process.exit} without worrying that the just-written message might not get written
	 * before the process actually exits.
	 *
	 * Note that this method will return even if there is another process spewing large numbers of messages
	 * to the destination's output queue.
	 */
	public void drain() {
		Monitor drainDone;

		// Post a 'drain' event.

		LogEvent logEvent = {
			level: -1, 
			msg: null,
			returnAddress: &drainDone,
		};

		ref<Logger> context = this;
		do {
			lock (*context) {
				if (_destination != null) {
					_destination.enqueue(&logEvent);
					drainDone.wait();
					return;
				}
				context = _parent;
			}
		} while (context != null);
	}
}

class LogChain {
	ref<Logger> thisLogger;
	ref<LogChain>[string] children;
};
/**
 * The structured message metadata associated with a log message.
 */
public class LogEvent {
	/**
	 * The time when the message was queued
	 */
	public time.Time when;
	/**
	 * The importance level of the message
	 */
	public int level;
	/**
	 * The text of the message itself.
	 */
	public string msg;
	/**
	 * The return address of the logging call.
	 *
	 * This identifies the source location of the log message.
	 */
	public address returnAddress;
	/**
	 * The operating system-specific thread id of the logging thread.
	 */
	public int threadId;

	ref<LogEvent> clone() {
		ref<LogEvent> logEvent = new LogEvent;
		*logEvent = *this;
		return logEvent;
	}
}
/**
 * This class provides log handling to the process standard output.
 *
 * It is possible that log messages written to different instances of the
 * ConsoleLogHandler could get written out of order. Rather than creating
 * a new ConsoleLogHandler, it is also more efficient to use the {@link defaultHandler}.
 *
 * @threading This class is thread-safe.
 */
public class ConsoleLogHandler extends LogHandler {
	ref<time.Formatter> _formatter;
	/**
	 * Prints the message data to the process' stdout stream.
	 *
	 * Currently, the metadata is written in a fixed format with time, thread id, importance and the message text.
	 *
	 * @param logEvent The structured data of the message.
	 */
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

	void newThread() {
		_writeThread = null;			// Just assume that no such thread exists in the process.
	}
}
/**
 * This is the base class for all logger destinations.
 *
 * Each LogHandler instance maintains a write thread and a message queue of messages that have high enough
 * importance to be printed. The write thread is created when the first message is written to the LogHandler.
 * It is terminated by a call to the {@link close} method or by deleting the LogHandler;
 *
 * A LogHandler can be attached as a destination for any number of loggers. Logged messages will be enqueued
 * correctly.
 */
public class LogHandler extends LogHandlerVolatileData {

	~LogHandler() {
		close();
	}
	/**
	 * This method drains the current contents of the LogHandler and terminate the write thread.
	 *
	 * Calling close while this LogHandler is attached as a destination of an active logger
	 * can leave unprinted messages in the LogHandler's message queue. To avoid this, be sure to
	 * remove the LogHandler from all destinations before calling close.
	 *
	 * If your application is using a Logger to generate bursts of activity to a particular LogHandler,
	 * you can reduce the resources of the LogHandler between bursts by calling close.
	 *
	 * A LogHandler will automatically restart the write thread when more messages get added to its
	 * message queue.
	 */
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
				if (_writeThread == t)
					_writeThread = null;
			}
		}
	}
	/**
	 * Provides processing to format and print the message.
	 *
	 * @param logEvent The message to be printed.
	 */
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
			if (logEvent.level == -1)
				ref<Monitor>(logEvent.returnAddress).notify();
			else {
				delete logEvent;
				break;
			}
		} else
			handler.processEvent(logEvent);
		delete logEvent;
	}
}

