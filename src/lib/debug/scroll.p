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

public class Scroll {
	/**
	 * Return the scroll length, in lines
	 */
	public abstract int length();
	/**
	 * Return the value of a given line
	 */
	public abstract string line(int i);
	/**
	 * Return a copy of the contents of the scroll
	 */
	public abstract string[] lines();

	public int spanCount() {
		return 0;
	}

	public ref<Span> span(int i) {
		return null;
	}

	public ref<Span>[] spans() {
		return [];
	}
}

public class Span {
	protected int _line;
	protected int _column;
	protected int _length;
	
}

public class StaticText extends Scroll {
	private string[] _lines;

	public StaticText(string[] lines) {
		_lines = lines;
	}

	public int length() {
		return _lines.length();
	}

	public string line(int i) {
		return _lines[i];
	}

	public string[] lines() {
		return _lines;
	}
}

public class LogScroll extends Scroll {
	private string[] _lines;
	private int _lastLine;
	private int _maxLines;

	public LogScroll(int maxLines) {
		_maxLines = maxLines;
	}

	public ref<Writer> getWriter() {
		return new LogScrollWriter(this);
	}

	public void write(byte c) {
	}

	public int length() {
		return _lines.length();
	}

	public string line(int i) {
		return _lines[i];
	}

	public string[] lines() {
		return _lines;
	}
}

private class LogScrollWriter extends Writer {
	private ref<LogScroll> _log;

	LogScrollWriter(ref<LogScroll> log) {
		_log = log;
	}

	public void _write(byte c) {
		_log.write(c);
	}
}

