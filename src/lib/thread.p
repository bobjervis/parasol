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
namespace parasol:thread;

import native:windows.GetCurrentThreadId;

public class Thread {
	string _name;
	
	public Thread() {
		_name.printf("TID-%d", GetCurrentThreadId());
	}
	
	public Thread(string name) {
		if (name != null)
			_name = name;
		else
			_name.printf("TID-%d", GetCurrentThreadId());
	}
	
	public string name() {
		return _name;
	}
}
/*
 * This is the runtime implementation class for the monitor feature. It supplies the public methods that are
 * implied in a declared monitor object.
 */
class Monitor {
	public Monitor() {
		
	}
	
	~Monitor() {
		
	}
	
	public void notify() {
		
	}
	
	public void notifyAll() {
		
	}
	
	public void wait() {
		
	}
	
	public void wait(long timeout) {
		
	}
	
	public void wait(long timeout, int nanos) {
		
	}
}