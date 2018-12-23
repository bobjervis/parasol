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

import parasol:http;

string set1 = ";,/?:@&=+$";
string set2 = "-_.!~*'()";
string set3 = "#";
string set4 = "ABC abc 123";
string set5 = "\ua0";

printf("set1 -> '%s'\n", http.encodeURIComponent(set1));
assert(http.encodeURIComponent(set1) == "%3B%2C%2F%3F%3A%40%26%3D%2B%24");
printf("set2 -> '%s'\n", http.encodeURIComponent(set2));
assert(http.encodeURIComponent(set2) == "-_.!~*'()");
printf("set3 -> '%s'\n", http.encodeURIComponent(set3));
assert(http.encodeURIComponent(set3) == "%23");
printf("set4 -> '%s'\n", http.encodeURIComponent(set4));
assert(http.encodeURIComponent(set4) == "ABC%20abc%20123");
printf("set5 -> '%s'\n", http.encodeURIComponent(set5));
assert(http.encodeURIComponent(set5) == "%C2%A0");

string eset1 = http.encodeURIComponent(set1);
string eset2 = http.encodeURIComponent(set2);
string eset3 = http.encodeURIComponent(set3);
string eset4 = http.encodeURIComponent(set4);
string eset5 = http.encodeURIComponent(set5);

printf("eset1 -> '%s'\n", http.decodeURIComponent(eset1));
assert(http.decodeURIComponent(eset1) == ";,/?:@&=+$");
printf("eset2 -> '%s'\n", http.decodeURIComponent(eset2));
assert(http.decodeURIComponent(eset2) == "-_.!~*'()");
printf("eset3 -> '%s'\n", http.decodeURIComponent(eset3));
assert(http.decodeURIComponent(eset3) == "#");
printf("eset4 -> '%s'\n", http.decodeURIComponent(eset4));
assert(http.decodeURIComponent(eset4) == "ABC abc 123");
printf("eset5 -> '%s'\n", http.decodeURIComponent(eset5));
assert(http.decodeURIComponent(eset5) == "\ua0");
