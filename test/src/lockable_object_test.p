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
import parasol:random;
import parasol:thread;
import parasol:time;

random.Random r;

time.Duration READ_TIMEOUT = 30.milliseconds();
time.Duration WRITE_TIMEOUT = 30.milliseconds();
int WRITES = 50;

int MEAN_WRITE_PAUSE_MILLIS = 40;
int WRITE_SPREAD_MILLIS = 20;
int MEAN_READ_PAUSE_MILLIS = 20;
int READ_SPREAD_MILLIS = 10;

int WRITE_THREADS = 5;
int READ_THREADS = 10;

time.Duration writePause() {
	time.Duration pause = 
			(r.uniform(WRITE_SPREAD_MILLIS) +
			 MEAN_WRITE_PAUSE_MILLIS -
			 WRITE_SPREAD_MILLIS / 2).milliseconds();

	return pause;
}

time.Duration readPause() {
	time.Duration pause = 
			(r.uniform(READ_SPREAD_MILLIS) +
			 MEAN_READ_PAUSE_MILLIS -
			 READ_SPREAD_MILLIS / 2).milliseconds();
	return pause;
}

class MyObject extends thread.LockableObject {
	int lastRead;
	int lastWritten;
	int reads;
	int writes;
	Monitor exclusion;

	int read() {
		if (!lockRead(READ_TIMEOUT))
			return -1;
		try {
			lock (exclusion) {
				reads++;
			}
		} finally {
			releaseRead();
		}
		return 0;
	}

	int write() {
		if (!lockWrite(WRITE_TIMEOUT))
			return -1;
		try {
			writes++;
		} finally {
			releaseWrite();
		}
		return 0;
	}
}

MyObject testObject;

ref<thread.Thread> writer = new thread.Thread();

writer.start(writeLoop, null);

void writeLoop(address ignored) {
	time.Timer loop;
	loop.start();
	for (int i = 0; i < WRITES; i++) {
		long millis = writePause().milliseconds();
		thread.sleep(millis);
		testObject.write();
	}
	loop.stop();
	time.Duration d = loop.elapsed();
	printf("Write loop took %,d milliseconds\n", d.milliseconds());
}

writer.join();
