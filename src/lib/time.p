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

	public Time(Instant i) {
		_value = i._seconds * MILLIS_PER_SECOND + i._nanos / NANOS_PER_MILLI;
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

public class Clock {
}

public class TimeZone {
}

public class Calendar {
}

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
/**
 * The Date class represents a moment in time interpreted by a Calendar to
 * reflect fields such as era, year, month, day, hour, minute and second, along with possible
 * ancillary information like day-of-the-week and time zone.
 *
 * Note: This has to be regarded as a provisional definition of this class. In particular, it is 
 * limited to the calendar supported by the C time functions.
 */
public class Date {
	private C.tm _data;
	private long _nanos;
	private ref<TimeZone> _timeZone;		// The time-zone used to convert the time.
	private ref<Calendar> _calendar;		// The Calendar used to convert the time.
	private long _offset;					// The offset in seconds from UTC used to convert the time.
											// long.MIN_VALUE implies no offset was applied.
	/**
	 * Constructor to fill out a Date from a Time according to the current system Calendar and TimeZone or offset.
	 */
	public Date(Time t) {
		C.time_t ct = C.time_t(t._value / MILLIS_PER_SECOND);
		C.localtime_s(&ct, &_data);
		_nanos = (t._value % MILLIS_PER_SECOND) * NANOS_PER_MILLI;
		_offset = long.MIN_VALUE;
	}
	/**
	 * Constructor to fill out a Date from an Instant according to the current system Calendar and TimeZone or offset.
	 */
	public Date(Instant i) {
		C.time_t t = C.time_t(i._seconds);
		C.localtime_s(&t, &_data);
		_nanos = i._nanos;
		_offset = long.MIN_VALUE;
	}

	public Date() {
		_offset = long.MIN_VALUE;
	}

	public void utc(Time t) {
		C.time_t ct = C.time_t(t._value / MILLIS_PER_SECOND);
		C.gmtime_s(&ct, &_data);
		_nanos = (t._value % MILLIS_PER_SECOND) * NANOS_PER_MILLI;
		_offset = 0;
	}

	public void utc(Instant i) {
		C.time_t t = C.time_t(i._seconds);
		C.gmtime_s(&t, &_data);
		_nanos = i._nanos;
		_offset = 0;
	}
}



