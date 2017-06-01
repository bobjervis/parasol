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

import parasol:thread.Thread;

ref<Thread> t1 = new Thread();
ref<Thread> t2 = new Thread();

printf("starting\n");

if (!t1.start(f1, t1)) {
	printf("t1 start failed\n");
}
if (!t2.start(f2, t2)) {
	printf("t2 start failed\n");
}

printf("About to join t1\n");
t1.join();
printf("About to join t2\n");
t2.join();

printf("joined\n");

delete t1;
delete t2;

monitor m1;
monitor m2;

boolean t1StartedWait;
boolean t2StartedWait;
boolean t1FinishedWait;
boolean t2FinishedWait;

void f1(address parameter) {
	t1StartedWait = true;
	printf("t1 about to wait\n");
	m1.wait();
	t1FinishedWait = true;
	assert(!t2FinishedWait);
	printf("t1 about to notify\n");
	m2.notify();
}

void f2(address parameter) {
	assert(!t1FinishedWait);
	printf("t2 about to notify\n");
	m1.notify();
	t2StartedWait = true;
	printf("t2 about to wait\n");
	m2.wait();
	t2FinishedWait = true;
}

assert(t1FinishedWait);
assert(t2FinishedWait);

