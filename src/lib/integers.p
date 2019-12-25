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
import parasol:text;
import parasol:stream.EOF;
/**
 * A 16-bit signed integer.
 */
public class short {
	/**
	 * The minimum value of a short integer.
	 */
	@Constant
	public static short MIN_VALUE = 0xffffffffffff8000;
	/**
	 * The maximum value of a short integer.
	 */
	@Constant
	public static short MAX_VALUE = 0x7fff;
	/**
	 * Compare two short integers.
	 *
	 * @param other The value to compare to.
	 *
	 * @return <0 if this value is less than other, 0 if they are equal or
	 * >0 if this is greater than other.
	 */
	public int compare(short other) {
		return *this - other;
	}

    public int hash() {
		return *this;
    }
	/**
	 * Parse a short integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid short value, false
	 * otherwise.
	 */
	public static short, boolean parse(string text) {
		long value;
		boolean success;
		(value, success) = parseInternal(substring(text), 10);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return short(value), success;
	}
	/**
	 * Parse a short integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid short value, false
	 * otherwise.
	 */
	public static short, boolean parse(string text, int radix) {
		long value;
		boolean success;
		(value, success) = parseInternal(substring(text), radix);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return short(value), success;
	}
	/**
	 * Parse a short integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid short value, false
	 * otherwise.
	 */
	public static short, boolean parse(substring text) {
		long value;
		boolean success;
		(value, success) = parseInternal(text, 10);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return short(value), success;
	}
	/**
	 * Parse a short integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid short value, false
	 * otherwise.
	 */
	public static short, boolean parse(substring text, int radix) {
		long value;
		boolean success;
		(value, success) = parseInternal(text, radix);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return short(value), success;
	}
	/**
	 * Parse a short integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid short value, false
	 * otherwise.
	 */
	public static short, boolean parse(string16 text) {
		long value;
		boolean success;
		(value, success) = parseInternal(substring16(text), 10);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return short(value), success;
	}
	/**
	 * Parse a short integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid short value, false
	 * otherwise.
	 */
	public static short, boolean parse(string16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseInternal(substring16(text), radix);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return short(value), success;
	}
	/**
	 * Parse a short integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid short value, false
	 * otherwise.
	 */
	public static short, boolean parse(substring16 text) {
		long value;
		boolean success;
		(value, success) = parseInternal(text, 10);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return short(value), success;
	}
	/**
	 * Parse a short integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid short value, false
	 * otherwise.
	 */
	public static short, boolean parse(substring16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseInternal(text, radix);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return short(value), success;
	}
}
/**
 * A 32-bit signed integer.
 */
public class int {
	/**
	 * The minimum value of an int.
	 */
	@Constant
	public static int MIN_VALUE = 0xffffffff80000000;
	/**
	 * The maximum value of an int.
	 */
	@Constant
	public static int MAX_VALUE = 0x7fffffff;
	/**
	 * Compare two int values.
	 *
	 * @param other The other int to compare.
	 *
	 * @return +1 if this int is greater than other, 0 if they are
	 * equal, -1 if this int is less than the other.
	 */
	public int compare(int other) {
		return *this - other;
	}
	/**
	 * Hash function used in map templates.
	 */
    public int hash() {
		return *this;
    }
	/**
	 * Parse an integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static int, boolean parse(string text) {
		long value;
		boolean success;
		(value, success) = parseInternal(substring(text), 10);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return int(value), success;
	}
	/**
	 * Parse an integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static int, boolean parse(string text, int radix) {
		long value;
		boolean success;
		(value, success) = parseInternal(substring(text), radix);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return int(value), success;
	}
	/**
	 * Parse an integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static int, boolean parse(substring text) {
		long value;
		boolean success;
		(value, success) = parseInternal(text, 10);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return int(value), success;
	}
	/**
	 * Parse an integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static int, boolean parse(substring text, int radix) {
		long value;
		boolean success;
		(value, success) = parseInternal(text, radix);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return int(value), success;
	}
	/**
	 * Parse an integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static int, boolean parse(string16 text) {
		long value;
		boolean success;
		(value, success) = parseInternal(substring16(text), 10);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return int(value), success;
	}
	/**
	 * Parse an integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static int, boolean parse(string16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseInternal(substring16(text), radix);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return int(value), success;
	}
	/**
	 * Parse an integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static int, boolean parse(substring16 text) {
		long value;
		boolean success;
		(value, success) = parseInternal(text, 10);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return int(value), success;
	}
	/**
	 * Parse an integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static int, boolean parse(substring16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseInternal(text, radix);
		if (success && (value < MIN_VALUE || value > MAX_VALUE))
			success = false;
		return int(value), success;
	}
	/**
	 * Return a year-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.year();}.
	 *
	 * @return This value times 365 days plus 1 day for each set of four years. For example,
	 * calling this method with a value of 9 would return the same value as 
	 * {@code (9 * 365 + 2).days()}.
	 */
	public time.Duration year() {
		int d = *this * 365 + *this / 4;
		return d.days();
	}
	/**
	 * Return a multi-year time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.years();}.
	 *
	 * @return This value times 365 days plus 1 day for each set of four years. For example,
	 * calling this method with a value of 9 would return the same value as 
	 * {@code (9 * 365 + 2).days()}.
	 */
	public time.Duration years() {
		int d = *this * 365 + *this / 4;
		return d.days();
	}
	/**
	 * Return a week-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.week();}.
	 *
	 * @return This value times 7 days duration.
	 */
	public time.Duration week() {
		return time.Duration(7 * 24 * 60 * 60 * *this);
	}
	/**
	 * Return a multi-week time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.weeks();}.
	 *
	 * @return This value times 7 days duration.
	 */
	public time.Duration weeks() {
		return time.Duration(7 * 24 * 60 * 60 * *this);
	}
	/**
	 * Return a day-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.day();}.
	 *
	 * @return This value times 24 hours duration.
	 */
	public time.Duration day() {
		return time.Duration(24 * 60 * 60 * *this);
	}
	/**
	 * Return a multi-day time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.days();}.
	 *
	 * @return This value times 24 hours duration.
	 */
	public time.Duration days() {
		return time.Duration(24 * 60 * 60 * *this);
	}
	/**
	 * Return an hour-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.hour();}.
	 *
	 * @return This value times 60 minutes duration.
	 */
	public time.Duration hour() {
		return time.Duration(60 * 60 * *this);
	}
	/**
	 * Return a multi-hour time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.hours();}.
	 *
	 * @return This value times 60 minutes duration.
	 */
	public time.Duration hours() {
		return time.Duration(60 * 60 * *this);
	}
	/**
	 * Return a minute-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.minute();}.
	 *
	 * @return This value times 60 seconds duration.
	 */
	public time.Duration minute() {
		return time.Duration(60 * *this);
	}
	/**
	 * Return a multi-minute time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.minutes();}.
	 *
	 * @return This value times 60 seconds duration.
	 */
	public time.Duration minutes() {
		return time.Duration(60 * *this);
	}
	/**
	 * Return a second-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.second();}.
	 *
	 * @return This value in seconds duration.
	 */
	public time.Duration second() {
		return time.Duration(*this);
	}
	/**
	 * Return a multi-second time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.seconds();}.
	 *
	 * @return This value in seconds duration.
	 */
	public time.Duration seconds() {
		return time.Duration(*this);
	}
	/**
	 * Return a millisecond-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.millisecond();}.
	 *
	 * @return This value in milliseconds duration.
	 */
	public time.Duration millisecond() {
		return time.Duration(*this / 1000, (1000000 * *this) % 1000000000);
	}
	/**
	 * Return a multi-millisecond time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.milliseconds();}.
	 *
	 * @return This value in milliseconds duration.
	 */
	public time.Duration milliseconds() {
		return time.Duration(*this / 1000, (1000000 * *this) % 1000000000);
	}
	/**
	 * Return a nanosecond-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.nanosecond();}.
	 *
	 * @return This value in nanoseconds duration.
	 */
	public time.Duration nanosecond() {
		return time.Duration(*this / 1000000000, *this % 1000000000);
	}
	/**
	 * Return a multi-nanosecond time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.nanoseconds();}.
	 *
	 * @return This value in nanoseconds duration.
	 */
	public time.Duration nanoseconds() {
		return time.Duration(*this / 1000000000, *this % 1000000000);
	}
}
/**
 * A 64-bit signed integer.
 */
public class long {
	/**
	 * The minimum value of a long.
	 */
	@Constant
	public static long MIN_VALUE = 0x8000000000000000;
	/**
	 * The maximum value of a long.
	 */
	@Constant
	public static long MAX_VALUE = 0x7fffffffffffffff;
	/**
	 * Compare two long values.
	 *
	 * @param other The other int to compare.
	 *
	 * @return +1 if this int is greater than other, 0 if they are
	 * equal, -1 if this int is less than the other.
	 */
	public int compare(long other) {
		if (*this > other)
			return +1;
		else if (*this < other)
			return -1;
		else
			return 0;
	}
	/**
	 * Hash function used in map templates.
	 */
    public int hash() {
		return int(*this);
    }
	/**
	 * Parse a long integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid long value, false
	 * otherwise.
	 */
	public static long, boolean parse(string text) {
		return parseInternal(substring(text), 10);
	}
	/**
	 * Parse a long integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid long value, false
	 * otherwise.
	 */
	public static long, boolean parse(string text, int radix) {
		return parseInternal(substring(text), radix);
	}
	/**
	 * Parse a long integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid long value, false
	 * otherwise.
	 */
	public static long, boolean parse(substring text) {
		return parseInternal(text, 10);
	}
	/**
	 * Parse a long integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid long value, false
	 * otherwise.
	 */
	public static long, boolean parse(substring text, int radix) {
		return parseInternal(text, radix);
	}
	/**
	 * Parse a long integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid long value, false
	 * otherwise.
	 */
	public static long, boolean parse(string16 text) {
		return parseInternal(substring16(text), 10);
	}
	/**
	 * Parse a long integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid long value, false
	 * otherwise.
	 */
	public static long, boolean parse(string16 text, int radix) {
		return parseInternal(substring16(text), radix);
	}
	/**
	 * Parse a long integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid long value, false
	 * otherwise.
	 */
	public static long, boolean parse(substring16 text) {
		return parseInternal(text, 10);
	}
	/**
	 * Parse a long integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid long value, false
	 * otherwise.
	 */
	public static long, boolean parse(substring16 text, int radix) {
		return parseInternal(text, radix);
	}
	/**
	 * Return a year-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.year();}.
	 *
	 * @return This value times 365 days plus 1 day for each set of four years. For example,
	 * calling this method with a value of 9 would return the same value as 
	 * {@code (9 * 365 + 2).days()}.
	 */
	public time.Duration year() {
		int d = int(*this * 365 + *this / 4);
		return d.days();
	}
	/**
	 * Return a multi-year time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.years();}.
	 *
	 * @return This value times 365 days plus 1 day for each set of four years. For example,
	 * calling this method with a value of 9 would return the same value as 
	 * {@code (9 * 365 + 2).days()}.
	 */
	public time.Duration years() {
		int d = int(*this * 365 + *this / 4);
		return d.days();
	}
	/**
	 * Return a week-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.week();}.
	 *
	 * @return This value times 7 days duration.
	 */
	public time.Duration week() {
		return time.Duration(7 * 24 * 60 * 60 * *this);
	}
	/**
	 * Return a multi-week time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.weeks();}.
	 *
	 * @return This value times 7 days duration.
	 */
	public time.Duration weeks() {
		return time.Duration(7 * 24 * 60 * 60 * *this);
	}
	/**
	 * Return a day-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.day();}.
	 *
	 * @return This value times 24 hours duration.
	 */
	public time.Duration day() {
		return time.Duration(24 * 60 * 60 * *this);
	}
	/**
	 * Return a multi-day time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.days();}.
	 *
	 * @return This value times 24 hours duration.
	 */
	public time.Duration days() {
		return time.Duration(24 * 60 * 60 * *this);
	}
	/**
	 * Return an hour-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.hour();}.
	 *
	 * @return This value times 60 minutes duration.
	 */
	public time.Duration hour() {
		return time.Duration(60 * 60 * *this);
	}
	/**
	 * Return a multi-hour time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.hours();}.
	 *
	 * @return This value times 60 minutes duration.
	 */
	public time.Duration hours() {
		return time.Duration(60 * 60 * *this);
	}
	/**
	 * Return a minute-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.minute();}.
	 *
	 * @return This value times 60 seconds duration.
	 */
	public time.Duration minute() {
		return time.Duration(60 * *this);
	}
	/**
	 * Return a multi-minute time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.minutes();}.
	 *
	 * @return This value times 60 seconds duration.
	 */
	public time.Duration minutes() {
		return time.Duration(60 * *this);
	}
	/**
	 * Return a second-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.second();}.
	 *
	 * @return This value in seconds duration.
	 */
	public time.Duration second() {
		return time.Duration(*this);
	}
	/**
	 * Return a multi-second time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.seconds();}.
	 *
	 * @return This value in seconds duration.
	 */
	public time.Duration seconds() {
		return time.Duration(*this);
	}
	/**
	 * Return a millisecond-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.millisecond();}.
	 *
	 * @return This value in milliseconds duration.
	 */
	public time.Duration millisecond() {
		return time.Duration(*this / 1000, (1000000 * *this) % 1000000000);
	}
	/**
	 * Return a multi-millisecond time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.milliseconds();}.
	 *
	 * @return This value in milliseconds duration.
	 */
	public time.Duration milliseconds() {
		return time.Duration(*this / 1000, (1000000 * *this) % 1000000000);
	}
	/**
	 * Return a nanosecond-long time span.
	 *
	 * While this method can be used with any integer constant or variable,
	 * the recommended idiom is to use this method only with a constant of 1,
	 * as in: {@code x = 1.nanosecond();}.
	 *
	 * @return This value in nanoseconds duration.
	 */
	public time.Duration nanosecond() {
		return time.Duration(*this / 1000000000, *this % 1000000000);
	}
	/**
	 * Return a multi-nanosecond time span.
	 *
	 * While this method can be used with any integer expression, the idiom is to use
	 * this when expressing a duration of time with it's time period as in: {@code
	 * x = 10.nanoseconds();}.
	 *
	 * @return This value in nanoseconds duration.
	 */
	public time.Duration nanoseconds() {
		return time.Duration(*this / 1000000000, *this % 1000000000);
	}
}

public class byte {
	@Constant
	public static byte MIN_VALUE = 0;
	@Constant
	public static byte MAX_VALUE = 255;
	
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static byte, boolean parse(string text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring(text), 10);
		if (value > MAX_VALUE)
			success = false;
		return byte(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static byte, boolean parse(string text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring(text), radix);
		if (value > MAX_VALUE)
			success = false;
		return byte(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static byte, boolean parse(substring text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, 10);
		if (value > MAX_VALUE)
			success = false;
		return byte(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static byte, boolean parse(substring text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, radix);
		if (value > MAX_VALUE)
			success = false;
		return byte(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static byte, boolean parse(string16 text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring16(text), 10);
		if (value > MAX_VALUE)
			success = false;
		return byte(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static byte, boolean parse(string16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring16(text), radix);
		if (value > MAX_VALUE)
			success = false;
		return byte(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static byte, boolean parse(substring16 text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, 10);
		if (value > MAX_VALUE)
			success = false;
		return byte(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static byte, boolean parse(substring16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, radix);
		if (value > MAX_VALUE)
			success = false;
		return byte(value), success;
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
	
	public byte toUpperCase() {
		if ((*this).isLowerCase())
			return byte(*this + ('A' - 'a'));
		else
			return *this;
	}
	
	public byte toLowerCase() {
		if ((*this).isUpperCase())
			return byte(*this + ('a' - 'A'));
		else
			return *this;
	}
}

public class char {
	@Constant
	public static char MAX_VALUE = 65535;
	
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static char, boolean parse(string text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring(text), 10);
		if (value > MAX_VALUE)
			success = false;
		return char(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static char, boolean parse(string text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring(text), radix);
		if (value > MAX_VALUE)
			success = false;
		return char(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static char, boolean parse(substring text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, 10);
		if (value > MAX_VALUE)
			success = false;
		return char(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static char, boolean parse(substring text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, radix);
		if (value > MAX_VALUE)
			success = false;
		return char(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static char, boolean parse(string16 text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring16(text), 10);
		if (value > MAX_VALUE)
			success = false;
		return char(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static char, boolean parse(string16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring16(text), radix);
		if (value > MAX_VALUE)
			success = false;
		return char(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static char, boolean parse(substring16 text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, 10);
		if (value > MAX_VALUE)
			success = false;
		return char(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static char, boolean parse(substring16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, radix);
		if (value > MAX_VALUE)
			success = false;
		return char(value), success;
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

	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static unsigned, boolean parse(string text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring(text), 10);
		if (value > MAX_VALUE)
			success = false;
		return unsigned(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static unsigned, boolean parse(string text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring(text), radix);
		if (value > MAX_VALUE)
			success = false;
		return unsigned(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static unsigned, boolean parse(substring text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, 10);
		if (value > MAX_VALUE)
			success = false;
		return unsigned(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static unsigned, boolean parse(substring text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, radix);
		if (value > MAX_VALUE)
			success = false;
		return unsigned(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static unsigned, boolean parse(string16 text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring16(text), 10);
		if (value > MAX_VALUE)
			success = false;
		return unsigned(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static unsigned, boolean parse(string16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(substring16(text), radix);
		if (value > MAX_VALUE)
			success = false;
		return unsigned(value), success;
	}
	/**
	 * Parse an unsigned integer from a string.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more decimal digits. The value may
	 * have any number of leading zero digits.
	 *
	 * @param text The string to parse.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static unsigned, boolean parse(substring16 text) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, 10);
		if (value > MAX_VALUE)
			success = false;
		return unsigned(value), success;
	}
	/**
	 * Parse an unsigned integer from a string, using a specified radix.
	 *
	 * The text string can contain an optiona leading negative
	 * sign (-) followed by one or more digits. The value may
	 * have any number of leading zero digits. If the radix is greater
	 * than 10, letters from a to z (upper or lower case) represent the
 	 * digits from 10 through 35.
	 *
	 * @param text The string to parse.
	 *
	 * @param radix A value to serve as the base for the number. Picking
	 * a number outside the valid range of digits (greater in magnitude than
	 * 36) is permitted, but some digit values cannot be represented.
	 *
	 * @return The parsed value, or 0 if the function failed to parse.
	 * @return true if the string contained a valid int value, false
	 * otherwise.
	 */
	public static unsigned, boolean parse(substring16 text, int radix) {
		long value;
		boolean success;
		(value, success) = parseUnsigned(text, radix);
		if (value > MAX_VALUE)
			success = false;
		return unsigned(value), success;
	}

	public int compare(unsigned other) {
		return int(*this - other);
	}

    public int hash() {
            return int(*this);
    }
}

long, boolean parseInternal(substring ss, int radix) {
	text.SubstringReader sr(&ss);
	text.UTF8Decoder d(&sr);

	return parseInternal(&d, radix);
}

long, boolean parseInternal(substring16 ss, int radix) {
	text.Substring16Reader sr(&ss);
	text.UTF16Decoder d(&sr);

	return parseInternal(&d, radix);
}

long, boolean parseInternal(ref<text.Decoder> d, int radix) {
	long value;
	boolean negative;

	int c = d.decodeNext();
	if (c == '-') {
		negative = true;
		c = d.decodeNext();
	}
	while (c != EOF) {
		byte x = byte(c);
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
		if (negative) {
			// if value were unsigned64, this could be (value > unsigned64(long.MAX_VALUE + 1))
			if (value < 0 && value != long.MIN_VALUE)
				return 0, false;
		} else if (value < 0)
			return 0, false;
		c = d.decodeNext();
	}
	if (negative)
		value = -value;
	return value, true;
}

long, boolean parseUnsigned(substring ss, int radix) {
	text.SubstringReader sr(&ss);
	text.UTF8Decoder d(&sr);

	return parseUnsigned(&d, radix);
}

long, boolean parseUnsigned(substring16 ss, int radix) {
	text.Substring16Reader sr(&ss);
	text.UTF16Decoder d(&sr);

	return parseUnsigned(&d, radix);
}

long, boolean parseUnsigned(ref<text.Decoder> d, int radix) {
	long value;

	for (;;) {
		int c = d.decodeNext();
		if (c == EOF)
			break;
		byte x = byte(c);
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
		if (value > unsigned.MAX_VALUE)
			return 0, false;
	}
	return value, true;
}

