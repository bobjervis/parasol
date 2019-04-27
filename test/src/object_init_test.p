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
ref<Object> o = { abc: "def", ghi: 3.7 };

assert(o != null);

assert(o.size() == 2);

var abc = o.get("abc");

assert(abc.class == string);
assert(string(abc) == "def");

var ghi = o.get("ghi");

assert(ghi.class == double);
assert(double(ghi) == 3.7);

