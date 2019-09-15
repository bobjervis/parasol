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
import parasol:thread;

Monitor m;
boolean lockedAfterThrow;

try {

	lock {m) {

		throw Exception("test");

	}

} catch (Exception e) {

	// If the exception doesn't unlock m, this thread can still lock it, so
	// we need a separate thread to do the lock. If the lock is held, then
	// the other thread will stall and the join will never unblock. The test
	// should time out.
	ref<thread.Thread> t = new thread.Thread();

	t.start(f, null);
	t.join();
	assert(lockedAftrThrow);
}

void f(address arg) {
	lock (m) {
		lockedAfterThrow = true;
	}
}
