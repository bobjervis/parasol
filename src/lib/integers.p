/*
   Copyright 2015 Rovert Jervis

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
namespace parasol:integers;

public class short {
//	public static short MIN_VALUE = 0xffffffffffff8000;
//	public static short MAX_VALUE = 0x7fff;

	public short() {
	}
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

	public int() {
	}
	
	public int(int value) {
		*this = value;
	}
	
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
}

public class long {
	public static long MIN_VALUE = 0x8000000000000000;
	public static long MAX_VALUE = 0x7fffffffffffffff;
	
	public long() {
	}
	
	public long(long value) {
	}
}

public class byte {
	public static byte MIN_VALUE = 0;
	public static byte MAX_VALUE = 255;
	
	public byte() {
	}

	public byte(byte value) {
	}

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
	
	public boolean isUppercase() {
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

	public boolean isLowercase() {
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
	
	byte toUppercase() {
		if ((*this).isLowercase())
			return byte(*this + ('A' - 'a'));
		else
			return *this;
	}
	
	byte toLowercase() {
		if ((*this).isUppercase())
			return byte(*this + ('a' - 'A'));
		else
			return *this;
	}
}

public class char {
	public static char MAX_VALUE = 65535;
	
	public char() {
	}
	
	public char(char value) {
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
	public static unsigned MIN_VALUE = 0x00000000;
	public static unsigned MAX_VALUE = 0xffffffff;

	public unsigned() {
	}
	
	public unsigned(unsigned value) {
	}
/*	
	public int compare(unsigned other) {
		return int(*this - other);
	}
 */
}

