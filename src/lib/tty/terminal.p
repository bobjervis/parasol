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
namespace parasollanguage.org:tty;

import parasol:runtime;
import parasol:time;
import native:linux;

time.Duration doubleClickElapsed(0, 500000000);

public enum Key {
	NOT_A_KEY,
	EOF,
	CodePoint,
	WindowSizeChanged,
	F1,					// interecepted by Gnome, raw mode does not see it.
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
	PrtScn,
	LeftArrow,
	RightArrow,
	UpArrow,
	DownArrow,
	MouseReport,
	MouseClick,
	MouseDoubleClick,
	MouseDown,			// first event in a drag-drop sequence: dragging starts from where the button was depressed
	MouseDrag,			// drags occur as the operation continues.
	MouseDrop,			// drop occurs as the final step
	MouseWheel,
	MouseMove
}

KDGKBMODE := 0x4b44;
KDSKBMODE := 0x4b45;

K_RAW       := 0x00;
K_XLATE     := 0x01;
K_MEDIUMRAW := 0x02;
K_UNICODE   := 0x03;
K_OFF       := 0x04;

enum ButtonState {
	UP,
	BUTTON1_DOWN,
	BUTTON2_DOWN,
	BUTTON3_DOWN
}

public class Terminal {
	private linux.struct_sigaction oldWinchAction;
	private linux.termios _termiosOriginal;
	private linux.termios _termiosRaw;
	private int _oldKbMode;
	private int _fdi;						// File descriptor to use for input
	private int _fdo;						// File descriptor to use for output
	private boolean _inRaw;
	private ref<State> _inputState;
	private ButtonState _buttonState;
	private int _lastRow;
	private int _lastColumn;
	private time.Time _dblClickExpiration;
	private boolean _dragging;				// Set on 2nd button down event, with a change of x,y
	private Key _pushbackKey;
	private int _pushbackExtra;

	public Terminal(int fdi, int fdo) {
		_fdi = fdi;
		_fdo = fdo;
		buildKeyStateMachine();
		linux.tcgetattr(fdi, &_termiosOriginal);
		linux.ioctl(fdi, KDGKBMODE, &_oldKbMode);
		_termiosRaw = _termiosOriginal;
		linux.cfmakeraw(&_termiosRaw);
		_inputState = &rootState;
		_dblClickExpiration = time.Time.MIN_VALUE;
		linux.sigaction(linux.SIGWINCH, null, &oldWinchAction);
	}

	~Terminal() {
		switchToCooked();
	}

	public static ref<Terminal> initialize(int fdi, int fdo) {
		if (linux.isatty(fdi) == 1 && linux.isatty(fdo) == 1)
			return new Terminal(fdi, fdo);
		else
			return null;
	}

	public boolean switchToRaw() {
		linux.ioctl(_fdi, KDSKBMODE, K_RAW);
		linux.struct_sigaction newWinchAction;

		newWinchAction.set_sa_sigaction(sigWinchHandler);
		newWinchAction.sa_flags = linux.SA_SIGINFO;
		linux.sigaction(linux.SIGWINCH, &newWinchAction, null);
		return _inRaw = linux.tcsetattr(_fdi, linux.TCSAFLUSH, &_termiosRaw) == 0;
	}

	public boolean switchToCooked() {
		linux.sigaction(linux.SIGWINCH, &oldWinchAction, null);
		linux.ioctl(_fdi, KDSKBMODE, _oldKbMode);
		b := linux.tcsetattr(_fdi, linux.TCSAFLUSH, &_termiosOriginal) == 0;
		if (b)
			_inRaw = false;
		return b;
	}

	public boolean inRaw() {
		return _inRaw;
	}

	private static Monitor sizeChangedLock;
	private static boolean sizeChanged;

	static void sigWinchHandler(int signum, ref<linux.siginfo_t> info, ref<linux.ucontext_t> uContext) {
		lock (sizeChangedLock) {
			sizeChanged = true
		}
	}

	public boolean windowSizeChanged() {
		boolean changedFlag
		lock (sizeChangedLock) {
			changedFlag = sizeChanged
			sizeChanged = false
		}
		return changedFlag
	}
	/**
	 * Get the window size in characters
	 *
	 * @return The number of rows
	 * @return The number of columns
	 */
	public int, int getWindowSize() {
		return runtime.terminalSize();
	}

	public void switchToAlternateBuffer() {
		send("\x1b[?1049h");
	}

	public void switchToNormalBuffer() {
		send("\x1b[?1049l");
	}

	public void enableMouseTracking() {
		send("\x1b[?1003h");
	}

	public void disableMouseTracking() {
		send("\x1b[?1003l");
	}

	public void gotoStartOfLine() {
		send("\r")
	}

	private void send(string s) {
		linux.write(_fdo, s.c_str(), s.length());
	}

	public Key, int getKeystroke() {
		if (_pushbackKey != Key.NOT_A_KEY) {
			k := _pushbackKey;
			_pushbackKey = Key.NOT_A_KEY;
			return k, _pushbackExtra;
		}
		int c;

		if (windowSizeChanged())
			return Key.WindowSizeChanged, 0
		actual := linux.read(_fdi, &c, 1);
		if (actual == 0)
			return Key.EOF, 0;

		if (actual < 0)
			return Key.NOT_A_KEY, linux.errno()
		
//		printf("c = %x '%c'\r\n", c, c);

		if (_inputState == null)
			return Key.CodePoint, c;

		if (_inputState.successorMap.contains(c)) {
			key := _inputState.successorMap[c].key;
			if (key != Key.NOT_A_KEY) {
				_inputState = &rootState;
				switch (key) {
				case MouseReport:
					linux.read(_fdi, &c, 1);
					mouseState := c;
					linux.read(_fdi, &c, 1);
					column := c - ' ';
					linux.read(_fdi, &c, 1);
					row := c - ' ';
					if ((mouseState & 0x60) == 0x60) {
						// wheel direction from the low two bits is 0 for 'scroll up' and 1 for 'scroll down'
						return Key.MouseWheel, mouseState & 3; 
					}
					button := (mouseState + 1) & 3;
					shifts := (mouseState >> 2) & 0x7;
//					printf("{%d,%d} button %d shifts %d%s\r\n", row, column, button, shifts, _dragging ? " dragging" : "");
					if (button != 0) { // button 1 is the 'primary' (typically left) button, 3 is the 'secondary' (typically right) button.
										// Note that for 3 button mice, button 2 is the middle button.
										// This is a button-down event
						if (_buttonState == ButtonState(button)) { // a continuation of the mouse moving while the button continues to be down
							// not likely to happen, this is an event for the same button down and same row and column - a no op
							if (_lastRow == row && _lastColumn == column)
								return Key.NOT_A_KEY, 0;
							_dblClickExpiration = time.Time.MIN_VALUE;
							if (!_dragging) {
								_dragging = true;
								downRow := _lastRow;
								downColumn := _lastColumn;
								_lastRow = row;
								_lastColumn = column;
								pushback(Key.MouseDrag, (row << 24) + (column << 16) + (button << 8) + shifts);
								return Key.MouseDown, (downRow << 24) + (downColumn << 16) + (button << 8) + shifts;
							}
							_lastRow = row;
							_lastColumn = column;
							return Key.MouseDrag, (row << 24) + (column << 16) + (button << 8) + shifts;
						}
						if (_buttonState != ButtonState.UP) { // we somehow switched buttons between reported events
							// this is a button down switching buttons, there is an implied up event for the previously down button
							// in any case, this down event can't be a double click
							_dblClickExpiration = time.Time.MIN_VALUE;
							if (_dragging) { // if we were dragging, the last reported position with the previous button should be the drop site
								if (row == _lastRow && column == _lastColumn) {
									clickButton := int(_buttonState);
									_buttonState = ButtonState(button);
									_dragging = false;
									return Key.MouseClick, (_lastRow << 24) + (_lastColumn << 16) + (clickButton << 8) + shifts;
								}
								pushback(Key.MouseDrag, (row << 24) + (column << 16) + (button << 8) + shifts);
								return Key.MouseDrop, (_lastRow << 24) + (_lastColumn << 16) + (int(_buttonState) << 8) + shifts;
							}
						}
						t := time.Time.now();
						if (_dblClickExpiration > time.Time.now()) {
							_dblClickExpiration = time.Time.MIN_VALUE;
							return Key.MouseDoubleClick, (row << 24) + (column << 16) + (button << 8) + shifts;
						}
						_buttonState = ButtonState(button);
						_dragging = false;
						_lastRow = row;
						_lastColumn = column;
						return Key.NOT_A_KEY, 1;
					} else if (_buttonState == ButtonState.UP) { // this is a move event
						if (_lastRow == row && _lastColumn == column)
							return Key.NOT_A_KEY, 3;
						else {
							_lastRow = row;
							_lastColumn = column;
							_dblClickExpiration = time.Time.MIN_VALUE;
							return Key.MouseMove, (row << 24) + (column << 16);
						}
					} else { // this is a button up event, could be a click, could be a drop
						lastButtonDown := _buttonState;
						_buttonState = ButtonState.UP;
						if (_dragging) {
							_dragging = false;
							_dblClickExpiration = time.Time.MIN_VALUE;
							return Key.MouseDrop, (row << 24) + (column << 16) + (int(lastButtonDown) << 8) + shifts;
						}
						if (_lastRow == row && _lastColumn == column) {
							_dblClickExpiration = time.Time.now().plus(doubleClickElapsed);
							return Key.MouseClick, (row << 24) + (column << 16) + (int(lastButtonDown) << 8) + shifts;
						} else {
							_dblClickExpiration = time.Time.MIN_VALUE;
							pushback(Key.MouseDrop, (row << 24) + (column << 16) + (int(lastButtonDown) << 8) + shifts);
							return Key.MouseDown, (_lastRow << 24) + (_lastColumn << 16) + (int(lastButtonDown) << 8) + shifts;
						}
					}

				default:
					return key, 0;
				}
			}
//			printf("    matched %x '%c'\n", c, c);
			_inputState = _inputState.successorMap[c];
			return Key.NOT_A_KEY, 2;
		} else {
			_inputState = &rootState;
			return Key.CodePoint, c;
		}
	}

	void pushback(Key key, int extra) {
		_pushbackKey = key;
		_pushbackExtra = extra;
	}
}

private void buildKeyStateMachine() {
	key(Key.LeftArrow,  "\x1b[D");
	key(Key.RightArrow, "\x1b[C");
	key(Key.MouseReport, "\x1b[M");
}

private void key(Key key, string sequence) {
	state := &rootState;
	for (i in sequence) {
		c := sequence[i];
		if (state.successorMap.contains(c)) {
			state = state.successorMap[c];
		} else {
			s := new State;
			state.successorMap[c] = s;
			state = s;
		}
	}
	state.key = key;
}

private State rootState;

private class State {
	map<ref<State>, int> successorMap;
	Key key;
}


