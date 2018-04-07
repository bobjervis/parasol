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
