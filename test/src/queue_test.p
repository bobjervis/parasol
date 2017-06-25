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
import parasol:types.Queue;

Queue<string> q;

assert(q.isEmpty());

for (int i = 0; i < 200; i++) {
	assert(q.length() == i);
	string s;
	s.printf("%d", i + 3);
	q.enqueue(s);
	assert(!q.isEmpty());
}

printf("Queue loaded with %d strings\n", q.length());

for (int i = 0; i < 200; i++) {
	assert(q.length() == 200 - i);
	string s = q.dequeue();
	int x;
	boolean success;
	
	(x, success) = int.parse(s);
	assert(success);
	assert(x == i + 3);
}

printf("Queue drained to %d strings\n", q.length());

assert(q.isEmpty());
assert(q.length() == 0);

void printSp() {
	int x;

	printf("&x = %p\n", &x);
}

printf("Testing exception handling.\n");

boolean threw;

printSp();

try {
	string x = q.dequeue();
	printSp();
	printf("Somehow didn't throw an exception.\n");
} catch (BoundsException e) {
	if (threw) {
		printf("Somehow got back here.\n");
	}
	threw = true;
}

printSp();
printf("Exception apparently caught.\n");

assert(threw);
