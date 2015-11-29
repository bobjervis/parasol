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
map<string, string> testMap;

printf("%d\n", long.MIN_VALUE);

assert(testMap.size() == 0);

print("Before\n");
*testMap.createEmpty("abc") = "xyz";
print("After\n");
*testMap.createEmpty("def") = "mno";
print("After 2\n");
assert(testMap.get("abc") == "xyz");
print("Done!\n");

map<int, string> intMap;

intMap.set("abc", 1);

*intMap.createEmpty("def") = 34;

assert(intMap.get("abc") == 1);
