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
void f(string label, string expected, string format, var... args) {
	string s;

	s.printf(format, args);
	printf("%s -> '%s'\n", label, s);
	assert(s == expected);
}

// Decimal formatting

int negative = -573412;
int positive = 948012034;
int zero = 0;

f("default negative", "-573412", "%d", negative);
f("default positive", "948012034", "%d", positive);
f("default zero", "0", "%d", zero);

f("width negative", "   -573412", "%10d", negative);
f("width positive", " 948012034", "%10d", positive);
f("width zero", "         0", "%10d", zero);

f("width 0-pad negative", "-000573412", "%010d", negative);
f("width 0-pad positive", "0948012034", "%010d", positive);
f("width 0-pad zero", "0000000000", "%010d", zero);

f("width parens negative", "  (573412)", "%(10d", negative);
f("width parens positive", " 948012034", "%(10d", positive);
f("width parens zero", "         0", "%(10d", zero);

f("width 0-pad+parens negative", "(00573412)", "%(010d", negative);
f("width 0-pad+parens positive", "0948012034", "%(010d", positive);
f("width 0-pad+parens zero", "0000000000", "%(010d", zero);

f("width left negative", "-573412   ", "%-10d", negative);
f("width left positive", "948012034 ", "%-10d", positive);
f("width left zero", "0         ", "%-10d", zero);

f("width plus negative", "   -573412", "%+10d", negative);
f("width plus positive", "+948012034", "%+10d", positive);
f("width plus zero", "        +0", "%+10d", zero);

f("width alt negative", "   -573412", "%#10d", negative);
f("width alt positive", " 948012034", "%#10d", positive);
f("width alt zero", "         0", "%#10d", zero);

f("space negative", "-573412", "% d", negative);
f("space positive", " 948012034", "% d", positive);
f("space zero", " 0", "% d", zero);

f("width comma negative", "     -573,412", "%,13d", negative);
f("width comma positive", "  948,012,034", "%,13d", positive);
f("width comma zero", "            0", "%,13d", zero);

