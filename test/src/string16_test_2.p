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
import parasol:text.string16;

string s1 = null;
string s2 = "";

string16 s1_16(s1);
string16 s2_16(s2);

assert(s1 != s2);

assert(s1_16.length() == 0);
assert(s2_16.length() == 0);

string s1_u(s1_16);
string s2_u(s2_16);

assert(s1_u == null);
assert(s1_u != "");
assert(s2_u != null);
assert(s2_u == "");

