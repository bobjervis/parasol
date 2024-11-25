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

import parasol:exception.IllegalArgumentException;

public enum Direction {
	NONE,
	HORIZONTAL,
	VERTICAL
}

public enum NumericOptions {
	NONE,
	ABSOLUTE,
	PERCENT,
}

public class Layout {
	public NumericOptions heightOptions;
	public int height;
}

/**
 * Tiles form a hierarchy. The tree always has a single root: the TerminalFrame. It has exactly one
 * child. This panel, and each of its descendants. These relationships are established as existing panels
 * are split up.
 */
public class Tile {
	private int _x, _y, _width, _height;	// Display reectangle of a tile.
	private ref<Tile> _parent;				// This panel's parent tile.
	private ref<Tile>[] _children;			// vector of possibly many children
	private Direction _direction;			// The layout of the children inside the parent.
	private ref<Scroll> _scroll;			// The scroll object bound to this panel.
	private TileConstraints _constraints
	private Layout _layout;

	public Tile(ref<Terminal> frame) {
		root := new TerminalFrame(frame);
		_parent = root;
		root._children.append(this);
		_x = 1;
		_y = 1;
		(_height, _width) = frame.getWindowSize();
	}

	Tile(ref<Tile> parent) {
		_parent = parent;
	}

	protected Tile() {
	}

	~Tile() {
		if (_parent != null) {
			i := _parent._children.find(this);
			if (i < _parent._children.length())
				_parent._children.remove(i);
		}
	}

	public ref<Tile> left() {
		if (_children.length() == 0)
			return split(Direction.HORIZONTAL);
		else
			throw IllegalArgumentException("Invalid left - has children");
	}

	public ref<Tile> top() {
		if (_children.length() == 0)
			return split(Direction.VERTICAL);
		else
			throw IllegalArgumentException("Invalid top - has children");
	}

	public ref<Tile> next() {
		if (_children.length() > 0)
			return split(_direction);
		else
			throw IllegalArgumentException("Invalid next - no children");
	}

	private ref<Tile> split(Direction direction) {
		_direction = direction;

		p := new Tile(this);
		_children.append(p);
		return p;
	}

	public void height(int lines) {
		_layout.heightOptions = NumericOptions.ABSOLUTE;
		_layout.height = lines;
	}

	public boolean bind(ref<Scroll> scroll) {
		if (_scroll == null) {
			_scroll = scroll;
			return true;
		} else
			return false;
	}

	public ref<Terminal> terminal() {
		return _parent.terminal();
	}

	public Direction direction() {
		return _direction;
	}
}

private class TerminalFrame extends Tile {
	private ref<Terminal> _terminal;

	TerminalFrame(ref<Terminal> terminal) {
		_terminal = terminal;
	}

	public ref<Terminal> terminal() {
		return _terminal;
	}
}
/**
 * Each of the dimensions of a tile is determined in layout  
 */
class TileConstraints {
	float topMargin
	float leftMargin
	float height
	float width
}


