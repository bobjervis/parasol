namespace parasol:time;
/*
 * A class that encapsulates time representation - using the UNIX era in milliseconds.
 */
public class Time {
	private long _value;
	
	public Time(long value) {
		_value = value;
	}
	
	public long value() {
		return _value;
	}
}

public Time now() {
	Time t(_now());
	return t;
}

public abstract long _now();
