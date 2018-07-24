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
namespace parasol:types;

import parasol:time;

public class short {
	public static short MIN_VALUE = 0xffffffffffff8000;
	public static short MAX_VALUE = 0x7fff;

//	public short() {
//	}
/*
	public short(short value) {
		*this = value;
	}
	
	public short compare(short other) {
		return *this - other;
	}
	
	public static short, boolean parse(string text) {
		int value = 0;
		int i = 0;
		boolean negative = false;
		if (text[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (negative)
			value = -value;
		return short(value), true;
	}
*/
}

public class int {
	public static int MIN_VALUE = 0xffffffff80000000;
	public static int MAX_VALUE = 0x7fffffff;

//	public int() {
//	}
	
//	public int(int value) {
//		*this = value;
//	}
	
	public int compare(int other) {
		return *this - other;
	}
	
	public static int, boolean parse(string text) {
		int value = 0;
		int i = 0;
		boolean negative = false;
		if (text[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (negative)
			value = -value;
		return value, true;
	}
	
	public static int, boolean parse(string text, int radix) {
		int value = 0;
		int i = 0;
		boolean negative = false;
		if (text[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text[i];
			int digit;
			if (x.isDigit())
				digit = x - '0';
			else if (x.isAlpha())
				digit = 10 + (x.toLowerCase() - 'a');
			else
				return 0, false;
			if (digit >= radix)
				return 0, false;
			value = value * radix + digit;
		}
		if (negative)
			value = -value;
		return value, true;
	}
	/**
	 * Parses a string as a decimal integer.
	 *
	 * Note that the status argument is second, so that if you have
	 * high confidence that the number is properly coded, you can use this as if it were
	 * a value function in an expression.
	 *
	 * For example: {@code int x = int.parse("1234");}
	 * 
	 * The text may start with a leading negative sign.
	 *
	 * While the string must consist of only digits and an optional leading negative sign,
	 * there is currently no check for overflow of the supplied value.
	 *
	 * @param text Takes a valid substring object as the text to parse.
	 *
	 * @return The integer value as an int object.
	 *
	 * @return True if the text was properly formatted, false otherwise.
	 *
	 * @threading This method is thread safe.
	 */
	public static int, boolean parse(substring text) {
		int value = 0;
		int i = 0;
		boolean negative = false;
		if (text.c_str()[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text.c_str()[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (negative)
			value = -value;
		return value, true;
	}
	
	public static int, boolean parse(substring text, int radix) {
		int value = 0;
		int i = 0;
		boolean negative = false;
		if (text.c_str()[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text.c_str()[i];
			int digit;
			if (x.isDigit())
				digit = x - '0';
			else if (x.isAlpha())
				digit = 10 + (x.toLowerCase() - 'a');
			else
				return 0, false;
			if (digit >= radix)
				return 0, false;
			value = value * radix + digit;
		}
		if (negative)
			value = -value;
		return value, true;
	}

	public boolean isDigit() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			return true;
		}
		return false;	
 	}

	public boolean isAlpha() {
		switch (*this) {
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'G':
		case 'H':
		case 'I':
		case 'J':
		case 'K':
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		case 'Y':
		case 'Z':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
			return true;
		}
		return false;
	}
	
	public time.Duration minute() {
		return time.Duration(60 * *this);
	}

	public time.Duration minutes() {
		return time.Duration(60 * *this);
	}

	public time.Duration second() {
		return time.Duration(*this);
	}

	public time.Duration seconds() {
		return time.Duration(*this);
	}

	public time.Duration millisecond() {
		return time.Duration(0, 1000000 * *this);
	}

	public time.Duration milliseconds() {
		return time.Duration(0, 1000000 * *this);
	}

	public time.Duration nanosecond() {
		return time.Duration(0, *this);
	}

	public time.Duration nanoseconds() {
		return time.Duration(0, *this);
	}
}

public class long {
	public static long MIN_VALUE = 0x8000000000000000;
	public static long MAX_VALUE = 0x7fffffffffffffff;
	
//	public long() {
//	}
	
//	public long(long value) {
//	}
	public static long, boolean parse(string text) {
		long value = 0;
		int i = 0;
		boolean negative = false;
		if (text[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (negative)
			value = -value;
		return value, true;
	}
	
	public static long, boolean parse(string text, int radix) {
		long value = 0;
		int i = 0;
		boolean negative = false;
		if (text[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text[i];
			int digit;
			if (x.isDigit())
				digit = x - '0';
			else if (x.isAlpha())
				digit = 10 + (x.toLowerCase() - 'a');
			else
				return 0, false;
			if (digit >= radix)
				return 0, false;
			value = value * radix + digit;
		}
		if (negative)
			value = -value;
		return value, true;
	}

	public static long, boolean parse(substring text) {
		long value = 0;
		int i = 0;
		boolean negative = false;
		if (text.c_str()[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text.c_str()[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (negative)
			value = -value;
		return value, true;
	}
	
	public static long, boolean parse(substring text, int radix) {
		long value = 0;
		int i = 0;
		boolean negative = false;
		if (text.c_str()[i] == '-') {
			negative = true;
			i++;
		}
		for (; i < text.length(); i++) {
			byte x = text.c_str()[i];
			int digit;
			if (x.isDigit())
				digit = x - '0';
			else if (x.isAlpha())
				digit = 10 + (x.toLowerCase() - 'a');
			else
				return 0, false;
			if (digit >= radix)
				return 0, false;
			value = value * radix + digit;
		}
		if (negative)
			value = -value;
		return value, true;
	}

    public int compare(long other) {
            if (*this < other)
                    return -1;
            else if (*this == other)
                    return 0;
            else
                    return 1;
    }

    public int hash() {
            return int(*this);
    }

	public time.Duration minute() {
		return time.Duration(60 * *this);
	}

	public time.Duration minutes() {
		return time.Duration(60 * *this);
	}

	public time.Duration second() {
		return time.Duration(*this);
	}

	public time.Duration seconds() {
		return time.Duration(*this);
	}

	public time.Duration millisecond() {
		return time.Duration(0, 1000000 * *this);
	}

	public time.Duration milliseconds() {
		return time.Duration(0, 1000000 * *this);
	}

	public time.Duration nanosecond() {
		return time.Duration(0, *this);
	}

	public time.Duration nanoseconds() {
		return time.Duration(0, *this);
	}
}

public class byte {
	public static byte MIN_VALUE = 0;
	public static byte MAX_VALUE = 255;
	
//	public byte() {
//	}

//	public byte(byte value) {
//	}

	public static byte, boolean parse(string text) {
		int value = 0;
		for (int i = 0; i < text.length(); i++) {
			byte x = text[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (value >= MIN_VALUE && value <= MAX_VALUE)
			return byte(value), true;
		else
			return 0, false;
	}
	
	public int compare(byte other) {
		return *this - other;
	}

	public boolean isPrintable() {
		if (*this < 0x20)
			return false;
		else
			return *this < 0x7f;
	}
	
	public boolean isSpace() {
		switch (*this) {
		case	' ':
		case	'\t':
		case	'\n':
		case	'\v':
		case	'\r':
			return true;
			
		default:
			return false;
		}
		return false;
	}

	public boolean isAlphanumeric() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'G':
		case 'H':
		case 'I':
		case 'J':
		case 'K':
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		case 'Y':
		case 'Z':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
			return true;
		}
		return false;
	}
	
	public boolean isDigit() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			return true;
		}
		return false;	
 	}
	
	public boolean isOctalDigit() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
			return true;
		}
		return false;	
 	}
	
	public boolean isHexDigit() {
		switch (*this) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
			return true;
		}
		return false;	
 	}
	
	public boolean isAlpha() {
		switch (*this) {
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'G':
		case 'H':
		case 'I':
		case 'J':
		case 'K':
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		case 'Y':
		case 'Z':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
			return true;
		}
		return false;
	}
	
	public boolean isUpperCase() {
		switch (*this) {
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'G':
		case 'H':
		case 'I':
		case 'J':
		case 'K':
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		case 'Y':
		case 'Z':
			return true;
		}
		return false;
	}

	public boolean isLowerCase() {
		switch (*this) {
		case 'a':
		case 'b':
		case 'C':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
			return true;
		}
		return false;
	}
	
	byte toUpperCase() {
		if ((*this).isLowerCase())
			return byte(*this + ('A' - 'a'));
		else
			return *this;
	}
	
	byte toLowerCase() {
		if ((*this).isUpperCase())
			return byte(*this + ('a' - 'A'));
		else
			return *this;
	}
}

public class char {
	public static char MAX_VALUE = 65535;
	
//	public char() {
//	}
	
//	public char(char value) {
//	}

	public static char, boolean parse(string text) {
		long value = 0;
		int i = 0;
		for (; i < text.length(); i++) {
			byte x = text[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (value != char(value))
			return 0, false;
		return char(value), true;
	}
	
	public static char, boolean parse(string text, int radix) {
		long value = 0;
		int i = 0;
		for (; i < text.length(); i++) {
			byte x = text[i];
			int digit;
			if (x.isDigit())
				digit = x - '0';
			else if (x.isAlpha())
				digit = 10 + (x.toLowerCase() - 'a');
			else
				return 0, false;
			if (digit >= radix)
				return 0, false;
			value = value * radix + digit;
		}
		if (value != char(value))
			return 0, false;
		return char(value), true;
	}
	
	public static char, boolean parse(substring text) {
		long value = 0;
		int i = 0;
		for (; i < text.length(); i++) {
			byte x = text.c_str()[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (value != char(value))
			return 0, false;
		return char(value), true;
	}
	
	public static char, boolean parse(substring text, int radix) {
		long value = 0;
		int i = 0;
		for (; i < text.length(); i++) {
			byte x = text.c_str()[i];
			int digit;
			if (x.isDigit())
				digit = x - '0';
			else if (x.isAlpha())
				digit = 10 + (x.toLowerCase() - 'a');
			else
				return 0, false;
			if (digit >= radix)
				return 0, false;
			value = value * radix + digit;
		}
		if (value != char(value))
			return 0, false;
		return char(value), true;
	}

	public int compare(char other) {
		return *this - other;
	}

	boolean isSpace() {
		switch (int(*this)) {
		case	' ':
		case	'\t':
		case	'\n':
		case	'\v':
		case	'\r':
			return true;
			
		default:
			return false;
		}
		return false;
	}
}

public class unsigned {
	@Constant
	public static unsigned MIN_VALUE = 0x00000000;
	@Constant
	public static unsigned MAX_VALUE = 0xffffffff;

//	public unsigned() {
//	}
	
//	public unsigned(unsigned value) {
//	}

	public static unsigned, boolean parse(string text) {
		long value = 0;
		int i = 0;
		for (; i < text.length(); i++) {
			byte x = text[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (value != unsigned(value))
			return 0, false;
		return unsigned(value), true;
	}

	public static unsigned, boolean parse(string text, int radix) {
		long value = 0;
		int i = 0;
		for (; i < text.length(); i++) {
			byte x = text[i];
			int digit;
			if (x.isDigit())
				digit = x - '0';
			else if (x.isAlpha())
				digit = 10 + (x.toLowerCase() - 'a');
			else
				return 0, false;
			if (digit >= radix)
				return 0, false;
			value = value * radix + digit;
		}
		if (value != unsigned(value))
			return 0, false;
		return unsigned(value), true;
	}

	public static unsigned, boolean parse(substring text) {
		long value = 0;
		int i = 0;
		for (; i < text.length(); i++) {
			byte x = text.c_str()[i];
			if (x.isDigit())
				value = value * 10 + (x - '0');
			else
				return 0, false;
		}
		if (value != unsigned(value))
			return 0, false;
		return unsigned(value), true;
	}

	public static unsigned, boolean parse(substring text, int radix) {
		long value = 0;
		int i = 0;
		for (; i < text.length(); i++) {
			byte x = text.c_str()[i];
			int digit;
			if (x.isDigit())
				digit = x - '0';
			else if (x.isAlpha())
				digit = 10 + (x.toLowerCase() - 'a');
			else
				return 0, false;
			if (digit >= radix)
				return 0, false;
			value = value * radix + digit;
		}
		if (value != unsigned(value))
			return 0, false;
		return unsigned(value), true;
	}

	public int compare(unsigned other) {
		return int(*this - other);
	}

    public int hash() {
            return int(*this);
    }
}

