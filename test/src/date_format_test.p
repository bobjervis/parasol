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

// Something near the Ides of March
time.Time ides(-63516960000000);

time.Date d(ides, &time.UTC);

string f = d.format("yyyy/MM/dd");			// Nothing locale- or calendar- or time zone-specific in this

printf("formatted as '%s'\n", f);

assert(f == "0044/03/25");

f = d.format("y/MM/dd");

printf("formatted as '%s'\n", f);

assert(f == "44/03/25");

f = d.format("yy/MM/dd");

printf("formatted as '%s'\n", f);

assert(f == "44/03/25");

time.Time sixties(-157766400000);

time.Date s(sixties, &time.UTC);

f = s.format("yyyy/MM/dd");

printf("formatted as '%s'\n", f);

assert(f == "1965/01/01");

f = s.format("y/MM/dd");

printf("formatted as '%s'\n", f);

assert(f == "1965/01/01");

f = s.format("yy/MM/dd");

printf("formatted as '%s'\n", f);

assert(f == "65/01/01");

time.Instant irecent(1524260956, 155999999);

time.Date ir(irecent, &time.UTC);

f = ir.format("yyyy/MM/dd HH:mm:ss.SSS");

printf("formatted as '%s'\n", f);

assert(f == "2018/04/20 21:49:16.155");

time.Date irl(irecent);

f = irl.format("yyyy/MM/dd HH:mm:ss.SSS");

printf("formatted as '%s'\n", f);

time.Time recent(1524260956155);

time.Date r(recent, &time.UTC);

f = r.format("yyyy/MM/dd HH:mm:ss.SSS");

printf("formatted as '%s'\n", f);

assert(f == "2018/04/20 21:49:16.155");

