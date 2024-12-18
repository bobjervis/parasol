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
namespace parasollanguage.org:tty

import parasol:exception
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
		_x = 0;
		_y = 0;
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
			throw exception.IllegalArgumentException("Invalid left - has children");
	}

	public ref<Tile> top() {
		if (_children.length() == 0)
			return split(Direction.VERTICAL);
		else
			throw exception.IllegalArgumentException("Invalid top - has children");
	}

	public ref<Tile> next() {
		if (_children.length() > 0)
			return split(_direction);
		else
			throw exception.IllegalArgumentException("Invalid next - no children");
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
	
	public void write(int x, int y, string text) {
	}
	
	public void write(string text) {
	}
	
	public void write(int x, int y, ref<AttributeSet> attributes, string text) {
	}
	
	public void write(ref<AttributeSet> attributes, string text) {
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
	int[] characters						// An array of Unicode code points.
	ref<AttributeSet>[] attributeSets		// For each code point above, the corresponding AttributeSet that applies. If not attributes are
											// set, these may be null. If the addresses of the AttributeSets are different, it is assumed they
											// set some different attributes.
}	

public class AttributeSet {
	private Attribute _style
	private Attribute _fore
	private byte _foreColor
	private Attribute _back
	private byte _backColor
	private byte[] _color256			// if position N in the _attributes array is Attribute.FORE_256, or Attribute.BACK_256 this is the color index
										// otherwise it is ignored
	/**
	 * Assign one or more attributes to this set. If any of these are either FORE_256 or BACK_256 this attribute is ignored.
	 *
	 * @param attributes The list of attributes to assign to this set.
	 */								
	public AttributeSet(Attribute... attributes) {
		byte[] b
		init(b, attributes)
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
		init(colors, attributes);
	}

	private void init(byte[] colors, Attribute[] attributes) {
		int color_index
		boolean styleSet, foreSet, backSet
		// _style is Attribute.NORMAL by default
		_fore = Attribute.FORE_DEFAULT
		_back = Attribute.BACK_DEFAULT
		for (i in attributes) {
			a := attributes[i]
			switch (a) {
			case NORMAL:
			case BOLD:
			case FAINT:
			case ITALIC:
			case UNDERLINED:
			case BLINK:
			case INVERSE:
			case INVISIBLE:
			case CROSSED_OUT:
			case DOUBLE_UNDERLINED:
				if (styleSet)
					throw exception.IllegalArgumentException("Too many style attributes: " + string(a))
				styleSet = true
				_style = a
				break;
				
			// 8 color palette
	
			case FORE_BLACK:
			case FORE_RED:
			case FORE_GREEN:
			case FORE_TELLOW:
			case FORE_BLUE:
			case FORE_MAGENTA:
			case FORE_CYAN:
			case FORE_WHITE:
			case FORE_DEFAULT:

			// 16 color palette
	
			case BRIGHT_FORE_BLACK:
			case BRIGHT_FORE_RED:
			case BRIGHT_FORE_GREEN:
			case BRIGHT_FORE_TELLOW:
			case BRIGHT_FORE_BLUE:
			case BRIGHT_FORE_MAGENTA:
			case BRIGHT_FORE_CYAN:
			case BRIGHT_FORE_WHITE:
			case BRIGHT_FORE_DEFAULT:
				if (foreSet)
					throw exception.IllegalArgumentException("Too many foreground colors: " + string(a))
				foreSet = true
				_fore = a
				break;
					
			case BACK_BLACK:
			case BACK_RED:
			case BACK_GREEN:
			case BACK_TELLOW:
			case BACK_BLUE:
			case BACK_MAGENTA:
			case BACK_CYAN:
			case BACK_WHITE:
			case BACK_DEFAULT:
				if (backSet)
					throw exception.IllegalArgumentException("Too many background colors: " + string(a))
				backSet = true
				_back = a
	
			case FORE_256:
				if (color_index < colors.length()) {
					if (foreSet)
						throw exception.IllegalArgumentException("Too many foreground colors: " + string(a))
					foreSet = true
					_fore = a
					_foreColor = colors[color_index++]
				}
				break
				
			case BACK_256:
				if (color_index < colors.length()) {
					if (backSet)
						throw exception.IllegalArgumentException("Too many background colors: " + string(a))
					backSet = true
					_back = a
					_backColor = colors[color_index++]
				}
				break
			}		
		}
	}
	
	public void write(int fd) {
		write(fd, null)
	}
	
	public void write(int fd, ref<AttributeSet> prior) {
		if (prior == this)
			return
		if (prior == null) {
			_style.write(fd);
			if (_fore == Attribute.FORE_256) {
				s := sprintf("\x1b[38;5;%dm", _foreColor)
				linux.write(fd, &s[0], s.length())
			} else
				_fore.write(fd)
			if (_back == Attribute.BACK_256) {
				s := sprintf("\x1b[48;5;%dm", _backColor)
				linux.write(fd, &s[0], s.length())
			} else
				_back.write(fd)
		} else {
			if (prior._style != _style)
				_style.write(fd)
			if (prior._fore != _fore) {
				if (_fore == Attribute.FORE_256) {
					s := sprintf("\x1b[38;5;%dm", _foreColor)
					linux.write(fd, &s[0], s.length())
				} else
					_fore.write(fd)
			} else if (_fore == Attribute.FORE_256 && prior._foreColor != _foreColor) {
				s := sprintf("\x1b[38;5;%dm", _foreColor)
				linux.write(fd, &s[0], s.length())
			}
			if (prior._back != _back) {
				if (_back == Attribute.BACK_256) {
					s := sprintf("\x1b[48;5;%dm", _backColor)
					linux.write(fd, &s[0], s.length())
				} else
					_back.write(fd)
			} else if (_back == Attribute.BACK_256 && prior._backColor != _backColor) {
				s := sprintf("\x1b[48;5;%dm", _backColor)
				linux.write(fd, &s[0], s.length())
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
	BACK_256(0)

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


