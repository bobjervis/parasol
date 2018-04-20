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
namespace parasol:time;

import native:windows;
import native:C;
import native:linux;
import parasol:runtime;
import parasol:international;

@Constant
private long ERA_DIFF = 0x019DB1DED53E8000;

@Constant
private int MILLIS_PER_SECOND = 1000;
@Constant
private int NANOS_PER_MILLI = 1000000;
@Constant
private int NANOS_PER_SECOND = NANOS_PER_MILLI * MILLIS_PER_SECOND;
@Constant
private int NANOS_PER_WIN_TICK = 100;
//@Constant
private int WIN_TICKS_PER_SECOND = NANOS_PER_SECOND / NANOS_PER_WIN_TICK;
/*
 * A class that encapsulates time representation - using the ISO era in milliseconds.
 * Note: This is a relatively compact time representation, independent of calendar, that can
 * represent to millisecond accuracy all moments in time from approximately 500 million years
 * in the past to 500 million years in the future.
 *
 * You may only modify a Time by assigning a new Time object to it.
 */
public class Time {
	long _value;

	public Time() {}
	
	public Time(long value) {
		_value = value;
	}

	public Time(Time t) {
		_value = t._value;
	}

	public Time(Instant i) {
		_value = i._seconds * MILLIS_PER_SECOND + i._nanos / NANOS_PER_MILLI;
	}

	public Time(ref<Date> date) {
		*this = localTimeZone.toTime(date);
	}

	public Time(ref<Date> date, ref<TimeZone> timeZone) {
		*this = timeZone.toTime(date);
	}
	/*
	 * This is a constructor defined for local use only to construct a Parasol Time object
	 * from a Windows FILETIME object. 
	 */
	Time(windows.FILETIME fileTime) {
		// Use UNIX era, and millis rather than 100nsec units
		_value = (*ref<long>(&fileTime) - ERA_DIFF) / 10000;
	}
	/*
	 * This is the constructor defined for local use only to construct a Parasol Time object
	 * from a Linux timespec object.
	 */
	Time(linux.timespec t) {
		_value = long(t.tv_sec) * 1000 + t.tv_nsec / 1000000;
	}
	/*
	 * Implement a fully ordered relation of Time objects so that times can be compared
	 * correctly.
	 */
	public int compare(ref<Time> other) {
		if (_value > other._value)
			return 1;
		else if (_value < other._value)
			return -1;
		else
			return 0;
	}
	
	public long value() {
		return _value;
	}
}

public Time now() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		windows.SYSTEMTIME s;
		windows.FILETIME f;

		windows.GetSystemTime(&s);
		windows.SystemTimeToFileTime(&s, &f);
		Time result(f);
		return result;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.timespec t;
		linux.clock_gettime(linux.CLOCK_REALTIME, &t);
		return Time(t);
	} else {
		return Time(0);
	}
}

public Instant instantNow() {
	if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		windows.SYSTEMTIME s;
		windows.FILETIME f;

		windows.GetSystemTime(&s);
		windows.SystemTimeToFileTime(&s, &f);
		Instant result(f);
		return result;
	} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		linux.timespec t;
		linux.clock_gettime(linux.CLOCK_REALTIME, &t);
		return Instant(t);
	} else {
		return Instant(0, 0);
	}
}
/**
 * This value is defined for timeout call arguments that use a Time of 0 milliseconds
 * to mean an infinite duration.
 */
public Time infinite(0);
/*
 * An Instance represents a time with the greatest precision and range. Where a
 * Time object has a little more than a one billion year range, an Instant spans
 * a trillion years, with nanosecond precision.
 *
 * You can only modify an Instant by assigning a new Instant to it.
 */
public class Instant {
	long _seconds;
	long _nanos;

	public Instant(long seconds, long nanos) {
		_seconds = seconds;
		_nanos = nanos;
	}

	public Instant(Time t) {
		long v = t._value;
		_seconds = v / MILLIS_PER_SECOND;
		_nanos = (v % MILLIS_PER_SECOND) * NANOS_PER_MILLI;
	}

	public Instant(Instant i) {
		_seconds = i._seconds;
		_nanos = i._nanos;
	}

	public Instant(ref<Date> d) {
		*this = localTimeZone.toInstant(d);
	}

	public Instant(ref<Date> date, ref<TimeZone> timeZone) {
		*this = timeZone.toInstant(date);
	}
	/*
	 * This is a constructor defined for local use only to construct a Parasol Time object
	 * from a Windows FILETIME object.
	 */
	Instant(windows.FILETIME fileTime) {
		// Use ISO era, in 100nsec units
		long x = (*ref<long>(&fileTime) - ERA_DIFF);
		_seconds = x / WIN_TICKS_PER_SECOND;
		_nanos = (x % WIN_TICKS_PER_SECOND) * NANOS_PER_WIN_TICK;
	}
	/*
	 * This is the constructor defined for local use only to construct a Parasol Time object
	 * from a Linux timespec object.
	 */
	Instant(linux.timespec t) {
		_seconds = t.tv_sec;
		_nanos = t.tv_nsec;
	}
	/*
	 * Implement a fully ordered relation of Time objects so that times can be compared
	 * correctly.
	 */
	public int compare(ref<Instant> other) {
		if (_seconds > other._seconds)
			return 1;
		else if (_seconds < other._seconds)
			return -1;
		else if (_nanos > other._nanos)
			return 1;
		else if (_nanos < other._nanos)
			return -1;
		else
			return 0;
	}

	public static Instant now() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			windows.SYSTEMTIME s;
			windows.FILETIME f;
	
			windows.GetSystemTime(&s);
			windows.SystemTimeToFileTime(&s, &f);
			Instant result(f);
			return result;
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			linux.timespec t;
			linux.clock_gettime(linux.CLOCK_REALTIME, &t);
			return Instant(t);
		} else {
			return Instant(0, 0);
		}
	}
}
/**
 * The Clock class defines a framework for using the underlying system high-precision timers.
 *
 * Content TBD.
 */
public class Clock {
}

public ProlepticGregorian ISO8601;

public ProlepticGregorianTimeZone UTC;
public LocalTimeZone localTimeZone;

public class ProlepticGregorian extends Calendar {
}

class LocalTimeZone extends TimeZone {
	LocalTimeZone() { }

	public Time toTime(ref<Date> date) {
		return super.toTime(date);
	}

	public Instant toInstant(ref<Date> date) {
		return super.toInstant(date);
	}

	public void toDate(ref<Date> result, Time t) {
		C.time_t ct = C.time_t(t._value / MILLIS_PER_SECOND);
		secondsToDate(result, ct);
		result.nanosecond = (t._value % MILLIS_PER_SECOND) * NANOS_PER_MILLI;
	}

	public void toDate(ref<Date> result, Instant i) {
		secondsToDate(result, i._seconds);
		result.nanosecond = i._nanos;
	}

	private void secondsToDate(ref<Date> d, C.time_t t) {
		d.toLocal(t);
	}
	/**
	 * Calculate the offset for the local time zone.
	 *
	void init() {
		C.tm local;
		C.tm utc;
		C.time_t t = C.time(null);

		C.localtime_s(&t, &local);
		C.gmtime_s(&t, &utc);
		_offsetSeconds = ((local.tm_hour - utc.tm_hour) * 60 + (local.tm_min - utc.tm_min)) * 60 + (local.tm_sec - utc.tm_sec);
		int delta_day = local.tm_mday - utc.tm_mday;
		if ((delta_day == 1) || (delta_day < -1)) {
			_offsetSeconds += 24 * 60 * 60;
		} else if ((delta_day == -1) || (delta_day > 1)) {
			_offsetSeconds -= 24 * 60 * 60;
  		}
	}
*/
}

class ProlepticGregorianTimeZone extends TimeZone {
	ProlepticGregorianTimeZone() {
	}

	public Time toTime(ref<Date> date) {
		return Time(internalToInstant(date));
	}

	public Instant toInstant(ref<Date> date) {
		return internalToInstant(date);
	}

	Instant internalToInstant(ref<Date> date) {
		C.time_t t;
		C.tm tm;

		if (date.era == 1)
			tm.tm_year = -(int(date.year) + 1899);
		else
			tm.tm_year = int(date.year) - 1900;
		tm.tm_mon = date.month;
		tm.tm_mday = date.day;
		tm.tm_hour = date.hour;
		tm.tm_min = date.minute;
		tm.tm_sec = date.second;
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			assert(false);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			t = linux.timegm(&tm);
		} else {
			assert(false);
		}
		printf("t = %d\n", t);		
		Instant i(t, date.nanosecond);


		return i;
	}

	public void toDate(ref<Date> result, Time t) {
		C.time_t ct = C.time_t(t._value / MILLIS_PER_SECOND);
		secondsToDate(result, ct);
		result.nanosecond = (t._value % MILLIS_PER_SECOND) * NANOS_PER_MILLI;
	}

	public void toDate(ref<Date> result, Instant i) {
		secondsToDate(result, i._seconds);
		result.nanosecond = i._nanos;
	}

	private void secondsToDate(ref<Date> d, C.time_t t) {
		d.toUtc(t);
	}
}

public class TimeZone {
	public abstract Time toTime(ref<Date> date);

	public abstract Instant toInstant(ref<Date> date);

	public abstract void toDate(ref<Date> result, Time t);

	public abstract void toDate(ref<Date> result, Instant i);
}

public class Calendar {
}
/*
public enum Month {
	JANUARY,
	FEBRUARY,
	MARCH,
	APRIL,
	MAY,
	JUNE,
	JULY,
	AUGUST,
	SEPTEMBER,
	OCTOBER,
	NOVEMBER,
	DECEMBER
}

public enum DayOfWeek {
	MONDAY,
	TUESDAY,
	WEDNESDAY,
	THURSDAY,
	FRIDAY,
	SATURDAY,
	SUNDAY
}

public enum DateUnit {
	ERA,
	MILLENIUM,
	CENTURY,
	DECADE,
	YEAR,
	WEEK_BASED_YEAR,
	QUARTER_YEAR,
	MONTH,
	WEEK,
	DAY,
	HALF_DAY,
	HOUR,
	MINUTE,
	SECOND,
	MILLISECOND,
	MICROSECOND,
	NANOSECOND
}

public enum DateField {
	OFFSET_SECONDS,
	TIME_ZONE,
	ERA,
	YEAR_OF_ERA,
	PROLEPTIC_YEAR,
	MONTH_OF_YEAR,
	PROLEPTIC_MONTH,
	DAY_OF_MONTH,
	DAY_OF_WEEK,
	DAY_OF_YEAR,
	DAY_OF_EPOCH,				// Counts of days since ISO 1970-01-01.
	AMPM_OF_DAY,
	HOUR_OF_AMPM,
	CLOCK_HOUR_OF_AMPM,
	HOUR_OF_DAY,
	CLOCK_HOUR_OF_DAY,
	MINUTE_OF_HOUR,
	SECOND_OF_MINUTE,
	MILLISECOND_OF_SECOND,
	MICROSECOND_OF_SECOND,
	NANOSECOND_OF_SECOND,
}
 */
/**
 * The Date class represents a moment in time interpreted by a Calendar to
 * reflect fields such as era, year, month, day, hour, minute and second, along with possible
 * ancillary information like day-of-the-week and time zone.
 *
 * Note: This has to be regarded as a provisional definition of this class. In particular, it is 
 * limited to the calendar supported by the C time functions.
 */
public class Date {
	public int era;
	public long year;
	public int month;
	public int day;
	public int hour;
	public int minute;
	public int second;
	public long nanosecond;
	// Supplemental fields that do not get used to convert to Time/Instant:
	public int weekDay;
	public int yearDay;
	/**
	 * Constructor to fill out a Date from a Time according to the current system Calendar and TimeZone or offset.
	 */
	public Date(Time t) {
		C.time_t ct = C.time_t(t._value / MILLIS_PER_SECOND);
		toLocal(ct);
		nanosecond = (t._value % MILLIS_PER_SECOND) * NANOS_PER_MILLI;
	}

	public Date(Time t, ref<TimeZone> tz) {
		tz.toDate(this, t);
		nanosecond = (t._value % MILLIS_PER_SECOND) * NANOS_PER_MILLI;
	}

	/**
	 * Constructor to fill out a Date from an Instant according to the current system Calendar and TimeZone or offset.
	 */
	public Date(Instant i) {
		C.time_t t = C.time_t(i._seconds);
		toLocal(t);
		nanosecond = i._nanos;
	}

	public Date(Instant i, ref<TimeZone> tz) {
		tz.toDate(this, i);
		nanosecond = i._nanos;
	}

	public Date() {
	}

	public string format(string pattern) {
		Formatter f(pattern);

		return f.format(this);
	}

	public void utc(Time t) {
		UTC.toDate(this, t);
	}

	public void utc(Instant i) {
		UTC.toDate(this, i);
	}

	void toLocal(C.time_t t) {
		C.tm data;

		if (C.localtime_s(&t, &data) == null) {
			string msg;
			msg.printf("%d", t);
			throw IllegalArgumentException(msg);
		}
		year = data.tm_year + 1900;
		if (year <= 0) {
			era = 1;
			year = 1 - year;
		}
		month = data.tm_mon;
		day = data.tm_mday;
		hour = data.tm_hour;
		minute = data.tm_min;
		second = data.tm_sec;
		weekDay = data.tm_wday;
		yearDay = data.tm_yday;
	}

	void toUtc(C.time_t t) {
		C.tm data;

		ref<C.tm> res = C.gmtime_s(&t, &data);
		if (res == null) {
			string msg;
			msg.printf("%d", t);
			throw IllegalArgumentException(msg);
		}
		year = data.tm_year + 1900;
		if (year <= 0) {
			era = 1;
			year = 1 - year;
		}
		month = data.tm_mon;
		day = data.tm_mday;
		hour = data.tm_hour;
		minute = data.tm_min;
		second = data.tm_sec;
		weekDay = data.tm_wday;
		yearDay = data.tm_yday;
	}
}

public class Formatter {
	@Constant
	static unsigned MAX_LETTER_COUNT = 255;

	static FormatCodes[] formatCodes = [
		'd':	FormatCodes.DAY_OF_MONTH,
		'H':	FormatCodes.HOUR_24,
		'M':	FormatCodes.MONTH,
		'm':	FormatCodes.MINUTE,
		'p':	FormatCodes.MODIFY_PAD,
		'S':	FormatCodes.FRACTION_OF_SECOND,
		's':	FormatCodes.SECOND,
		'y':	FormatCodes.YEAR_FULL,
	];
	/**
	 * indexed by letter count, the nanoseconds value is divided by the number here.
	 */
	static int[] fractionTable = [
		1000000000,
		100000000,
		10000000,
		1000000,
		100000,
		10000,
		1000,
		100,
		10,
		1,
	];

	public ref<TimeZone> timeZone;
	public ref<international.Locale> locale;
	public ref<Calendar> calendar;

	enum FormatCodes {
		LITERAL_1,							// followed by a literal byte of data.
		MODIFY_PAD,							// Modify padding on next field; Followed by a byte containing pad width.
		YEAR_2,								// 2-digit year; no additional data.
		YEAR_FULL,							// full year (4 digit); followed by a byte containing pad width.
		MONTH,								// month (1-12); followed by a byte containing pad width.
		DAY_OF_MONTH,						// day of the month (1-31); followed by a byte containing pad width.
		HOUR_24,							// 24 hour (0-23); followed by a byte containing pad width.
		MINUTE,								// minute (0-59); followed by a byte containing pad width.
		SECOND,								// second (0-59); followed by a byte containing pad width.
		FRACTION_OF_SECOND,					// fraction of a second; followed by a byte containing pad width - maximum 9.
	}

	byte[] _pattern;

	public Formatter(string pattern) {
		byte lastLetter;
		int letterCount;

		// parse the pattern
		for (int i = 0; i < pattern.length(); i++) {
			if (lastLetter != pattern[i] && letterCount > 0) {
				if (!recordLetter(lastLetter, letterCount))
					throw IllegalArgumentException(pattern);
				letterCount = 0;
			}
			if (pattern[i].isAlpha()) {
				lastLetter = pattern[i];
				letterCount++;
			} else if (pattern[i] == '\'') {
				i++;
				if (i >= pattern.length())
					throw IllegalArgumentException(pattern);
				_pattern.append(byte(FormatCodes.LITERAL_1));
				_pattern.append(pattern[i]);				
			} else {
				_pattern.append(byte(FormatCodes.LITERAL_1));
				_pattern.append(pattern[i]);
			}
		}
		if (letterCount > 0 && !recordLetter(lastLetter, letterCount))
			throw IllegalArgumentException(pattern);
	}

	private boolean recordLetter(byte lastLetter, int letterCount) {
		if (unsigned(letterCount) > MAX_LETTER_COUNT)
			return false;
			
		switch (lastLetter) {
		case 'y':
			if (letterCount == 2)
				_pattern.append(byte(FormatCodes.YEAR_2));
			else {
				_pattern.append(byte(FormatCodes.YEAR_FULL));
				_pattern.append(byte(letterCount));
			}
			break;

		case 'd':
		case 'H':
		case 'M':
		case 'm':
		case 'p':
		case 's':
			_pattern.append(byte(formatCodes[lastLetter]));
			_pattern.append(byte(letterCount));
			break;

		case 'S':
			if (letterCount > 9)
				return false;
			_pattern.append(byte(formatCodes[lastLetter]));
			_pattern.append(byte(letterCount));
			break;

		default:
			return false;
		}
		return true;
	}

	public string format(ref<Date> input) {
		ref<TimeZone> tz;
		ref<international.Locale> lcl;
		ref<Calendar> cal;

		if (timeZone != null)
			tz = timeZone;
		else
			tz = &localTimeZone;
		if (locale != null)
			lcl = locale;
		else
			lcl = international.myLocale();
		if (calendar != null)
			cal = calendar;
		else
			cal = &ISO8601;
		return format(input, tz, lcl, cal);
	}

	public string format(ref<Date> input, ref<TimeZone> timeZone) {
		ref<international.Locale> lcl;
		ref<Calendar> cal;

		if (locale != null)
			lcl = locale;
		else
			lcl = international.myLocale();
		if (calendar != null)
			cal = calendar;
		else
			cal = &ISO8601;
		return format(input, timeZone, lcl, cal);
	}

	public string format(ref<Date> input, ref<international.Locale> locale) {
		ref<TimeZone> tz;
		ref<Calendar> cal;

		if (timeZone != null)
			tz = timeZone;
		else
			tz = &localTimeZone;
		if (calendar != null)
			cal = calendar;
		else
			cal = &ISO8601;
		return format(input, tz, locale, cal);
	}

	public string format(ref<Date> input, ref<TimeZone> timeZone, ref<international.Locale> locale, ref<Calendar> calendar) {
		string output;
		int modifyPad;

		for (i in _pattern) {
			switch (FormatCodes(_pattern[i])) {
			case	LITERAL_1:
				i++;
				output.append(_pattern[i]);
				break;

			case	MODIFY_PAD:
				i++;
				modifyPad = _pattern[i];
				break;
				
			case	YEAR_2:
				output.printf("%2.2d", input.year % 100);
				break;

			case	YEAR_FULL:
				i++;
				int width = _pattern[i];
				if (modifyPad > 0)
					output.printf("%*d", modifyPad, input.year);
				else
					output.printf("%*.*d", width, width, input.year);
				break;

			case	MONTH:
				i++;
				width = _pattern[i];
				if (modifyPad > 0)
					output.printf("%*d", modifyPad, input.month + 1);
				else
					output.printf("%*.*d", width, width, input.month + 1);
				break;

			case	DAY_OF_MONTH:
				i++;
				width = _pattern[i];
				if (modifyPad > 0)
					output.printf("%*d", modifyPad, input.day);
				else
					output.printf("%*.*d", width, width, input.day);
				break;

			case	HOUR_24:
				i++;
				width = _pattern[i];
				if (modifyPad > 0)
					output.printf("%*d", modifyPad, input.hour);
				else
					output.printf("%*.*d", width, width, input.hour);
				break;

			case	MINUTE:
				i++;
				width = _pattern[i];
				if (modifyPad > 0)
					output.printf("%*d", modifyPad, input.minute);
				else
					output.printf("%*.*d", width, width, input.minute);
				break;

			case	SECOND:
				i++;
				width = _pattern[i];
				if (modifyPad > 0)
					output.printf("%*d", modifyPad, input.second);
				else
					output.printf("%*.*d", width, width, input.second);
				break;

			case	FRACTION_OF_SECOND:
				i++;
				width = _pattern[i];
				long frac = input.nanosecond / fractionTable[width];
				if (modifyPad > 0)
					output.printf("%*d", modifyPad, frac);
				else
					output.printf("%*.*d", width, width, frac);
				break;

			default:
				assert(false);
			}
		}
		return output;
	}

	public boolean parse(string input, ref<Date> output) {
		return false;
	}
}
