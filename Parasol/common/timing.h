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
