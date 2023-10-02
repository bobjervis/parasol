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
namespace parasol:context;

string[] list0;

assert(highestVersion(list0) == null);

string[] list1 = [
	"0.0.0"
];

assert(highestVersion(list1) == "0.0.0");

string[] list1b = [
	"342567.85675463.103232"
];

assert(highestVersion(list1b) == "342567.85675463.103232");

string[] list2 = [
	"342567.85675463.103232",
	"54.0"
];

printf("highest = %s\n", highestVersion(list2));

assert(highestVersion(list2) == "342567.85675463.103232");

string[] list7 = [
	"4.1.6",
	"4.7.9",
	"4.0.12",
	"0.2.11",
	"3.5.25",
];

printf("highest = %s\n", highestVersion(list7));

assert(highestVersion(list7) == "4.7.9");

string[] list8 = [
	"4.1.6",
	"4.1.6",
	"4.7.9",
	"5.0.12",
	"0.2.11",
	"3.5.25",
];

printf("highest = %s\n", highestVersion(list8));

assert(highestVersion(list8) == "5.0.12");