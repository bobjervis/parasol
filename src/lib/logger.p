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

public monitor class Logger {
	private int _level;
	private ref<Logger> _parent;
	private ref<LogHandler> _destination;

	Logger() {
	}

	public int setLevel(int level) {
		int result = _level;
		_level = math.abs(level);
		return result;
	}

	public ref<Logger> setParent(ref<Logger> parent) {
		ref<Logger> old = _parent;
		_parent = parent;
		return old;
	}

	public ref<LogHandler> setDestination(ref<LogHandler> newHandler) {
		ref<LogHandler> result = _destination;
		_destination = newHandler;
		return result;
	}

	public void info(string msg) {
		if (needToCheck(INFO))
			queueEvent(runtime.returnAddress(), INFO, msg);
	}

	public void debug(string msg) {
		if (needToCheck(DEBUG))
			queueEvent(runtime.returnAddress(), DEBUG, msg);
	}

	public void warn(string msg) {
		if (needToCheck(WARN))
			queueEvent(runtime.returnAddress(), WARN, msg);
	}

	public  void error(string msg) {
		if (needToCheck(ERROR))
			queueEvent(runtime.returnAddress(), ERROR, msg);
	}

	public void fatal(string msg) {
		if (needToCheck(FATAL))
			queueEvent(runtime.returnAddress(), FATAL, msg);
	}

	public void log(int level, string msg) {
		if (needToCheck(level))
			queueEvent(runtime.returnAddress(), level, msg);
	}

	public void format(int level, string format, var... arguments) {
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
			threadId: thread.getCurrentThreadId(),		// The thread may disappear before we write the message,
														// so remember the thread id, not the Thread object.
		};

		ref<Logger> context = this;
		do {
			if (context._destination != null)
				context._destination.enqueue(&logEvent);
			context = context._parent;
		} while (context != null);
	}
}

public class LogEvent {
	Time when;
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

	ConsoleLogHandler() {
		_formatter = new time.Formatter("yyyy/MM/dd HH:mm:ss.SSS");
	}

	public void processEvent(ref<LogEvent> logEvent) {
		time.Date d(logEvent.when, &time.UTC);
		string logTime = _formatter.format(d);				// Note: if the format includes locale-specific stuff,
															// like a named time zone or month, we would have to add
															// some arguments to the format call.
		string label = label(level);

		printf("%s %d %s %s\n", logTime, threadId, label, msg);
	}
}

public monitor class LogHandler {
	ref<Thread> _writeThread;
	private Queue<ref<LogEvent>> _events;

	public void close() {
		if (_writeThread != null) {
			LogEvent shutdown = { msg: null };
			enqueue(&shutdown);
			_writeThread.join();
			_writeThread = null;
		}
	}

	public void enqueue(ref<LogEvent> logEvent) {
		_events.enqueue(logEvent.clone());
		if (_writeThread == null) {
			_writeThread = new Thread("LogWriter");
			_writeThread.start(writeWrapper, this);
		}
		notify();
	}

	public ref<LogEvent> dequeue() {
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

		default:
			string s;
			if (level >= 0)
				s.printf("NOTE-%d", level);
			else
				s.printf("ALARM%d", level);
			return s;
		}
	}
}
/**
 * writeWrapper
 *
 *	This method is the main loop of the WebSocket writer thread. Once started, it remains running waiting for
 *	some WebSocket to write some data.
 */
void writeWrapper(address arg) {
	ref<LogHandler> handler = ref<LogHandler>(arg);
	for (;;) {
		ref<LogEvent> logEvent = handler.dequeue();
		if (logEvent.msg != null && logEvent.format != null) {
			delete logEvent;
			break;
		} else {
			handler.processEvent(logEvent);
			delete logEvent;
		}
	}
}

