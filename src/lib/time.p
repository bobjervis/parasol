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
namespace parasol:time;

import native:windows;
import native:C;
import native:posix;
import parasol:runtime;
import parasol:pxi.SectionType;

@Constant
private long ERA_DIFF = 0x019DB1DED53E8000;
/*
 * A class that encapsulates time representation - using the UNIX era in milliseconds.
 */
public class Time {

	private long _value;
	
	public Time() {}
	
	public Time(long value) {
		_value = value;
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
	Time(posix.timespec t) {
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
	if (runtime.compileTarget == SectionType.X86_64_WIN) {
		windows.SYSTEMTIME s;
		windows.FILETIME f;

		windows.GetSystemTime(&s);
		windows.SystemTimeToFileTime(&s, &f);
		Time result(f);
		return result;
	} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
		posix.timespec t;
		posix.clock_gettime(posix.CLOCK_REALTIME, &t);
		return Time(t);
	} else {
		return Time(0);
	}
}

