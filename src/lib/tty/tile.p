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
import native:linux

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
	private Line[] _lines;

	TerminalFrame(ref<Terminal> terminal) {
		_terminal = terminal;
	}

	public ref<Terminal> terminal() {
		return _terminal;
	}
}

private class Line {
	int[] characters;						// An array of Unicode code points.
	ref<AttributeSet>[] attributeSets;		// For each code point above, the corresponding AttributeSet that applies. If not attributes are
											// set, these may be null. If the addresses of the AttributeSets are different, it is assumed they
											// set some different attributes.
}	

public class AttributeSet {
	private Attribute[] _attributes
	private byte[] _color256			// if position N in the _attributes array is Attribute.FORE_256, or Attribute.BACK_256 this is the color index
										// otherwise it is ignored
	/**
	 * Assign one or more attributes to this set. If any of these are either FORE_256 or BACK_256 this attribute is ignored.
	 *
	 * @param attributes The list of attributes to assign to this set.
	 */								
	public AttributeSet(Attribute... attributes) {
		_attributes = attributes
	}
	/**
	 * Assign one or more attributes to this set.
	 *
	 *
	 * @param colors A list of zero or more 256-color palette indices.
	 * Each color corresponds to either a FORE_256 or BACK_256 attribute in the attributes list.  
	 * If too many are listed for the number of attributes
	 * provided, the excess is ignored. If too few are listed for the number of attributes, the attributes
	 * are assigned until they run out and any further FORE_256 or BACK_256 attributes are ignored.
	 *
	 * @param attributes The list of attributes to assign to this set.
	 */
	public AttributeSet(byte[] colors, Attribute... attributes) {
		color_index := 0
		for (i in attributes) {
			a := attributes[i]
			switch (a) {
			case FORE_256:
			case BACK_256:
				if (color_index < colors.length()) {
					_attributes.append(a)
					_color256.append(colors[color_index++])
				}
				break
				
			default:
				_attributes.append(a)
				_color256.append(0)
			}		
		}
	}
	
	public void write(int fd) {
		for (i in _attributes) {
			a := _attributes[i]
			switch (a) {
			case FORE_256:
			case BACK_256:
				if (i < _color256.length()) {
					s := sprintf("\x1b[%d;5;%dm", a == Attribute.FORE_256 ? 38 : 48, _color256[i])
					linux.write(fd, &s[0], s.length())
				}
				break
				
			default:
				a.write(fd)
			} 
		}
	}
}
	
public enum Attribute {
	NORMAL(0),
	BOLD(1),
	FAINT(2),
	ITALIC(3),
	UNDERLINED(4),
	BLINK(5),
	INVERSE(7),
	INVISIBLE(8),
	CROSSED_OUT(9),
	DOUBLE_UNDERLINED(21),
	
	// 8 color palette
	
	FORE_BLACK(30),
	FORE_RED(31),
	FORE_GREEN(32),
	FORE_TELLOW(33),
	FORE_BLUE(34),
	FORE_MAGENTA(35),
	FORE_CYAN(36),
	FORE_WHITE(37),
	FORE_DEFAULT(39),
	
	BACK_BLACK(40),
	BACK_RED(41),
	BACK_GREEN(42),
	BACK_TELLOW(43),
	BACK_BLUE(44),
	BACK_MAGENTA(45),
	BACK_CYAN(46),
	BACK_WHITE(47),
	BACK_DEFAULT(49),

	// 16 color palette
	
	BRIGHT_FORE_BLACK(90),
	BRIGHT_FORE_RED(91),
	BRIGHT_FORE_GREEN(92),
	BRIGHT_FORE_TELLOW(93),
	BRIGHT_FORE_BLUE(94),
	BRIGHT_FORE_MAGENTA(95),
	BRIGHT_FORE_CYAN(96),
	BRIGHT_FORE_WHITE(97),
	BRIGHT_FORE_DEFAULT(99),
	
	FORE_256(0),
	BACK_256(0);

	private int _value
	
	Attribute(int value) {
		_value = value
	}
	
	void write(int fd) {
		sequence := sprintf("\x1b[%dm", _value)
		linux.write(fd, &sequence[0], sequence.length())
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


