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

string16 insert = "<insert here>";

string s;

s.printf("some stuff goes here: %s\n", insert);

printf("s='%s'\n", s);

assert(s == "some stuff goes here: <insert here>\n");

s.clear();

s.printf("[[%s]]", string16("XX") + "->");

printf("s='%s'\n", s);

assert(s == "[[XX->]]");

string16 func() {
	return insert;
}

s.clear();

s.printf("//%s//", func());

printf("s=%s\n", s);

assert(s == "//<insert here>//");
// If calling the function frees its value, this could fail, corrupting the heap.
assert(func() == "<insert here>");

string str_1, str_2;
string16 str16_1, str16_2;

str_1 = "abc";
str16_1 = "abc";
substring sub_1(str_1);
substring16 sub16_1(str16_1);
str_2 = "def";
str16_2 = "def";
substring sub_2(str_2);
substring16 sub16_2(str16_2);

assert(str_1 < str_2);
assert(str_1 < str16_2);
assert(str_1 < sub_2);
assert(str_1 < sub16_2);

assert(str16_1 < str_2);
assert(str16_1 < str16_2);
assert(str16_1 < sub_2);
assert(str16_1 < sub16_2);

assert(sub_1 < str_2);
assert(sub_1 < str16_2);
assert(sub_1 < sub_2);
//assert(sub_1 < sub16_2); - not an allowed confrontation, pick a type to use
assert(sub_1 < string(sub16_2));
assert(string16(sub_1) < sub16_2);

assert(sub16_1 < str_2);
assert(sub16_1 < str16_2);
//assert(sub16_1 < sub_2); - not an allow confrontation, pick a type to use
assert(sub16_1 < string16(sub_2));
assert(string(sub16_1) < sub_2);
assert(sub16_1 < sub16_2);

