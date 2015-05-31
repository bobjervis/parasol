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
#include "../common/platform.h"
#include "timing.h"

#include <stdio.h>
#include <windows.h>
#include "dictionary.h"
#include "process.h"

namespace timing {

static process::Mutex lock;
static int chainId = -1;
static int outputId;
static int totalId;
static int depthId;

class Bucket {
public:
	const char*		tag;
	int				instances;
	tick			overhead;
	tick			exclusive;
	tick			inclusive;

	int compare(const Bucket* other) {
		if (exclusive < other->exclusive)
			return -1;
		else if (exclusive > other->exclusive)
			return 1;
		else
			return 0;
	}
};

void enableProfiling() {
	if (chainId >= 0) {
		process::Thread* t = process::currentThread();

		int depth = (int)(long long)t->local(depthId);
		t->setLocal(depthId, (void*)(depth + 1));
		if (depth == 0) {
			Timer* tm = new Timer("total");
			t->setLocal(totalId, tm);
		}
	}
}

void disableProfiling() {
	if (chainId >= 0) {
		process::Thread* t = process::currentThread();

		long long depth = (long long)t->local(depthId);
		if (depth == 1) {
			Timer* tm = (Timer*)t->local(totalId);
			delete tm;
			t->setLocal(totalId, null);
		}
		t->setLocal(depthId, (void*)(depth - 1));
	}
}

void defineSnapshot(vector<Interval>* output) {
	process::Thread* t = process::currentThread();

	if (chainId < 0) {
		process::MutexLock m(&lock);

		if (chainId < 0) {
			chainId = t->allocateThreadLocal();
			outputId = t->allocateThreadLocal();
			totalId = t->allocateThreadLocal();
			depthId = t->allocateThreadLocal();
		}
	}
	t->setLocal(chainId, (void*)-1);
	t->setLocal(outputId, output);
	t->setLocal(totalId, null);
	t->setLocal(depthId, 0);
}

__int64 frequency() {
	LARGE_INTEGER f;
	QueryPerformanceFrequency(&f);
	return f.QuadPart;
}

static void print(double v) {
	printf(" %11.2f ms ", v);
}

void print(vector<Interval>& snapshot) {
	__int64 freq;

	freq = frequency();
	double mult = 1000.0 / freq;

	dictionary<Bucket*> buckets;

	for (int i = 0; i < snapshot.size(); i++) {
		Interval& n = snapshot[i];

		Bucket* b = *buckets.get(n.tag);
		if (b == null) {
			b = new Bucket;
			memset(b, 0, sizeof (Bucket));
			buckets.insert(n.tag, b);
			b->tag = n.tag;
		}

		if (n.parentIndex >= 0) {
			tick elapsed = n.follow - n.entry;
			Interval& ip = snapshot[n.parentIndex];
			ip.end -= elapsed;
			ip.follow -= elapsed;
		}
	}

	for (int i = 0; i < snapshot.size(); i++) {
		Interval& n = snapshot[i];

		tick overhead = (n.start - n.entry) + (n.follow - n.end);
		tick body = n.end - n.start;

		Bucket* b = *buckets.get(n.tag);
		b->exclusive += body;
		b->overhead += overhead;
		b->instances++;

		n.start = body;		// exclusive
		n.end = body;		// inclusive
	}

	for (int i = 0; i < snapshot.size(); i++) {
		Interval& n = snapshot[i];
		Interval* ip = &n;
		while (ip->parentIndex >= 0) {
			ip = &snapshot[ip->parentIndex];
			ip->end += n.start;							// after this, each interval has its 'natural' included time
		}
	}
	for (int i = 0; i < snapshot.size(); i++) {
		Interval& n = snapshot[i];
		Bucket* b = *buckets.get(n.tag);
		Interval* ip = &n;
		bool unique = true;
		while (ip->parentIndex >= 0) {
			ip = &snapshot[ip->parentIndex];
			Bucket* b2 = *buckets.get(ip->tag);
			if (b2 == b) {
				unique = false;
				break;
			}
		}
		if (unique)
			b->inclusive += n.end;						// each 'top of recursion' instance of a given bucket
														// gets the 
	}
	vector<Bucket*> bucketArray;

	dictionary<Bucket*>::iterator bi = buckets.begin();
	while (bi.hasNext()) {
		bucketArray.push_back(*bi);
		bi.next();
	}
	bucketArray.sort(false);
	tick totalExclusive = 0;
	for (int i = 0; i < bucketArray.size(); i++) {
		Bucket* b = bucketArray[i];
		totalExclusive += b->exclusive;
	}
	printf("[ i ] instances       exclusive (%%)     inclusive\n");
	for (int i = 0; i < bucketArray.size(); i++) {
		Bucket* b = bucketArray[i];
		printf("[%3d]%7d  ", i, b->instances);
		print(mult * b->exclusive);
		printf(" (%4.1f%%)", (100.0 * b->exclusive) / totalExclusive);
		print(mult * b->inclusive);
//		print(mult * b->overhead);
		printf(" %s\n", b->tag);
	}
}

Timer::Timer(const char* tag) {
	if (chainId >= 0) {
		LARGE_INTEGER entry;

		QueryPerformanceCounter(&entry);
		process::Thread* t = process::currentThread();
		if (t->local(depthId)) {
			vector<Interval>* output = (vector<Interval>*)t->local(outputId);
			_index = output->size();
			output->resize(_index + 1);
			Interval& i = (*output)[_index];
			i.tag = tag;
			i.entry = entry.QuadPart;
			i.parentIndex = (long long)t->local(chainId);
			t->setLocal(chainId, (void*)(long long)_index);
			QueryPerformanceCounter((LARGE_INTEGER*)&i.start);
			return;
		}
	}
	_index = -1;
}

Timer::~Timer() {
	if (_index >= 0) {
		LARGE_INTEGER end;

		QueryPerformanceCounter(&end);
		process::Thread* t = process::currentThread();
		vector<Interval>* output = (vector<Interval>*)t->local(outputId);
		Interval& i = (*output)[_index];
		t->setLocal(chainId, (void*)i.parentIndex);
		i.end = end.QuadPart;
		QueryPerformanceCounter((LARGE_INTEGER*)&i.follow);
	}
}

}  // namespace timing
