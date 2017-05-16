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

/* Note this test declares a local variable inside a lock.
 * 
 */
import parasol:thread.Thread;

monitor a {
	ref<Atom> list;
	
	ref<Atom> readOne() {
		if (list != null) {
			ref<Atom> p = list;
			list = p.next;
			return p;
		} else
			return null;
	}
	
	void writeOne(ref<Atom> p) {
		p.next = list;
		list = p;
	}
}

boolean t1Finished;

printf("Starting...\n");
for (int i = 0; i < 10000; i++) {
	ref<Thread> t1 = new Thread();
	ref<Thread> t2 = new Thread();

	t1Finished = false;
	
	t1.start(reader, null);
	t2.start(writer, null);

	t1.join();
	t2.join();

	delete t1;
	delete t2;
	
	printf("\n");
	
	assert(t1Finished);
}

class Atom {
	ref<Atom> next;
	int value;
	
	Atom(int v) {
		value = v;
	}
}

void reader(address parameter) {
	int sum;
	int misses;
	
	for (int i = 0; i < 10; ) {
		ref<Atom> p;
	
		lock (a) {
			ref<Atom> x;
			if (list != null) {
				x = list;
				list = x.next;
				p = x;
			} else
				p = null;
		}
		if (p != null) {
			sum += p.value;
			printf("%d ", p.value);
			delete p;
			i++;
		} else
			misses++;
	}
	printf("misses: %d\n", misses);
	assert(sum == 175);
	t1Finished = true;
}

void writer(address parameter) {
	for (int i = 0; i < 10; i++) {
		ref<Atom> p = new Atom(i + 13);
		a.writeOne(p);
		printf("[%d] ", i + 13);
	}
}