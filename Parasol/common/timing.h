#pragma once

#include "vector.h"

namespace process {

class Mutex;

}  // namespace process;

namespace timing {

typedef long long tick;

class Interval {
public:
	long long		parentIndex;		// index in interval vector of parent interval
	const char*		tag;
	tick			entry;
	tick			start;
	tick			end;
	tick			follow;
};

class Timer {
public:
	Timer(const char* tag);
	
	~Timer();

private:
	int _index;
};

void enableProfiling();

void disableProfiling();

void defineSnapshot(vector<Interval>* output);

void print(vector<Interval>& snapshot);

long long frequency();

}  // namespace timing
