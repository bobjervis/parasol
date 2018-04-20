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
import parasol:time;

time.Time x(24317);

string output1;

output1.printf("%tQ", x);

assert(output1 == "24317");

string output2;

output2.printf("%ts", x);

assert(output2 == "24");

time.Time y(-24317);

string output1y;

output1y.printf("%tQ", y);

assert(output1y == "-24317");

string output2y;

output2y.printf("%ts", y);

assert(output2y == "-24");

// Conversion to Date from time.

time.Time ides(-63516960000000);

time.Date idesDate(ides, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			idesDate.year, idesDate.month + 1, idesDate.day,
			idesDate.hour, idesDate.minute, idesDate.second,
			idesDate.weekDay, idesDate.yearDay);

assert(idesDate.era == 1);
assert(idesDate.year == 44);
assert(idesDate.month == 2);
assert(idesDate.day == 25);
assert(idesDate.hour == 0);
assert(idesDate.minute == 0);
assert(idesDate.second == 0);
assert(idesDate.nanosecond == 0);
assert(idesDate.weekDay == 1);
assert(idesDate.yearDay == 83);

time.Time sixties(-157766400000);

time.Date sixtiesDate(sixties, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			sixtiesDate.year, sixtiesDate.month + 1, sixtiesDate.day,
			sixtiesDate.hour, sixtiesDate.minute, sixtiesDate.second,
			sixtiesDate.weekDay, sixtiesDate.yearDay);

assert(sixtiesDate.era == 0);
assert(sixtiesDate.year == 1965);
assert(sixtiesDate.month == 0);
assert(sixtiesDate.day == 1);
assert(sixtiesDate.hour == 0);
assert(sixtiesDate.minute == 0);
assert(sixtiesDate.second == 0);
assert(sixtiesDate.nanosecond == 0);
assert(sixtiesDate.weekDay == 5);
assert(sixtiesDate.yearDay == 0);

time.Time seventies(3024000000);

time.Date seventiesDate(seventies, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			seventiesDate.year, seventiesDate.month + 1, seventiesDate.day,
			seventiesDate.hour, seventiesDate.minute, seventiesDate.second,
			seventiesDate.weekDay, seventiesDate.yearDay);

assert(seventiesDate.era == 0);
assert(seventiesDate.year == 1970);
assert(seventiesDate.month == 1);
assert(seventiesDate.day == 5);
assert(seventiesDate.hour == 0);
assert(seventiesDate.minute == 0);
assert(seventiesDate.second == 0);
assert(seventiesDate.nanosecond == 0);
assert(seventiesDate.weekDay == 4);
assert(seventiesDate.yearDay == 35);

time.Time recent(1491004800000);

time.Date recentDate(recent, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			recentDate.year, recentDate.month + 1, recentDate.day,
			recentDate.hour, recentDate.minute, recentDate.second,
			recentDate.weekDay, recentDate.yearDay);

assert(recentDate.era == 0);
assert(recentDate.year == 2017);
assert(recentDate.month == 3);
assert(recentDate.day == 1);
assert(recentDate.hour == 0);
assert(recentDate.minute == 0);
assert(recentDate.second == 0);
assert(recentDate.nanosecond == 0);
assert(recentDate.weekDay == 6);
assert(recentDate.yearDay == 90);

time.Time future(208312732800000);

time.Date futureDate(future, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			futureDate.year, futureDate.month + 1, futureDate.day,
			futureDate.hour, futureDate.minute, futureDate.second,
			futureDate.weekDay, futureDate.yearDay);

assert(futureDate.era == 0);
assert(futureDate.year == 8571);
assert(futureDate.month == 2);
assert(futureDate.day == 3);
assert(futureDate.hour == 0);
assert(futureDate.minute == 0);
assert(futureDate.second == 0);
assert(futureDate.nanosecond == 0);
assert(futureDate.weekDay == 0);
assert(futureDate.yearDay == 61);

// Conversion to Date from Instant

time.Instant iides(-63516960000, 0);

time.Date iidesDate(iides, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			iidesDate.year, iidesDate.month + 1, iidesDate.day,
			iidesDate.hour, iidesDate.minute, iidesDate.second,
			iidesDate.weekDay, iidesDate.yearDay);

assert(iidesDate.era == 1);
assert(iidesDate.year == 44);
assert(iidesDate.month == 2);
assert(iidesDate.day == 25);
assert(iidesDate.hour == 0);
assert(iidesDate.minute == 0);
assert(iidesDate.second == 0);
assert(iidesDate.nanosecond == 0);
assert(iidesDate.weekDay == 1);
assert(iidesDate.yearDay == 83);

time.Instant isixties(-157766400, 0);

time.Date isixtiesDate(isixties, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			isixtiesDate.year, isixtiesDate.month + 1, isixtiesDate.day,
			isixtiesDate.hour, isixtiesDate.minute, isixtiesDate.second,
			isixtiesDate.weekDay, isixtiesDate.yearDay);

assert(isixtiesDate.era == 0);
assert(isixtiesDate.year == 1965);
assert(isixtiesDate.month == 0);
assert(isixtiesDate.day == 1);
assert(isixtiesDate.hour == 0);
assert(isixtiesDate.minute == 0);
assert(isixtiesDate.second == 0);
assert(isixtiesDate.nanosecond == 0);
assert(isixtiesDate.weekDay == 5);
assert(isixtiesDate.yearDay == 0);

time.Instant iseventies(3024000, 0);

time.Date iseventiesDate(iseventies, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			iseventiesDate.year, iseventiesDate.month + 1, iseventiesDate.day,
			iseventiesDate.hour, iseventiesDate.minute, iseventiesDate.second,
			iseventiesDate.weekDay, iseventiesDate.yearDay);

assert(iseventiesDate.era == 0);
assert(iseventiesDate.year == 1970);
assert(iseventiesDate.month == 1);
assert(iseventiesDate.day == 5);
assert(iseventiesDate.hour == 0);
assert(iseventiesDate.minute == 0);
assert(iseventiesDate.second == 0);
assert(iseventiesDate.nanosecond == 0);
assert(iseventiesDate.weekDay == 4);
assert(iseventiesDate.yearDay == 35);

time.Instant irecent(1491004800, 0);

time.Date irecentDate(irecent, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			irecentDate.year, irecentDate.month + 1, irecentDate.day,
			irecentDate.hour, irecentDate.minute, irecentDate.second,
			irecentDate.weekDay, irecentDate.yearDay);

assert(irecentDate.era == 0);
assert(irecentDate.year == 2017);
assert(irecentDate.month == 3);
assert(irecentDate.day == 1);
assert(irecentDate.hour == 0);
assert(irecentDate.minute == 0);
assert(irecentDate.second == 0);
assert(irecentDate.nanosecond == 0);
assert(irecentDate.weekDay == 6);
assert(irecentDate.yearDay == 90);

time.Instant ifuture(208312732800, 0);

time.Date ifutureDate(ifuture, &time.UTC);

printf("%4.4d-%2.2d-%2.2d %d:%2.2d:%2.2d week day %d year day %d\n", 
			ifutureDate.year, ifutureDate.month + 1, ifutureDate.day,
			ifutureDate.hour, ifutureDate.minute, ifutureDate.second,
			ifutureDate.weekDay, ifutureDate.yearDay);

assert(ifutureDate.era == 0);
assert(ifutureDate.year == 8571);
assert(ifutureDate.month == 2);
assert(ifutureDate.day == 3);
assert(ifutureDate.hour == 0);
assert(ifutureDate.minute == 0);
assert(ifutureDate.second == 0);
assert(ifutureDate.nanosecond == 0);
assert(ifutureDate.weekDay == 0);
assert(ifutureDate.yearDay == 61);

time.Time idesTime(&idesDate, &time.UTC);

assert(idesTime.compare(&ides) == 0);


time.Time sixtiesTime(&sixtiesDate, &time.UTC);

assert(sixtiesTime.compare(&sixties) == 0);


time.Time seventiesTime(&seventiesDate, &time.UTC);

assert(seventiesTime.compare(&seventies) == 0);


time.Time recentTime(&recentDate, &time.UTC);

assert(recentTime.compare(&recent) == 0);


time.Time futureTime(&futureDate, &time.UTC);

assert(futureTime.compare(&future) == 0);


time.Instant idesInstant(&idesDate, &time.UTC);

assert(idesInstant.compare(&iides) == 0);


time.Instant sixtiesInstant(&sixtiesDate, &time.UTC);

assert(sixtiesInstant.compare(&isixties) == 0);


time.Instant seventiesInstant(&seventiesDate, &time.UTC);

assert(seventiesInstant.compare(&iseventies) == 0);


time.Instant recentInstant(&recentDate, &time.UTC);

assert(recentInstant.compare(&irecent) == 0);


time.Instant futureInstant(&futureDate, &time.UTC);

assert(futureInstant.compare(&ifuture) == 0);






