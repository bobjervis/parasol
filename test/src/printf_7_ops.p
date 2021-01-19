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
string s;

s.printf("%6.2f", 12.5432);

printf("s='%s'\n", s);
assert(s == " 12.54");

string se;

se.printf("%12.2e", 12.5432);

printf("se='%s'\n", se);

assert(se == "   1.25e+02");

string sg;

sg.printf("%g", 12.5432);

printf("sg='%s'\n", sg);

assert(sg == "12.5432");

string sgBig;

sgBig.printf("%g", 1683490358.535);

printf("sgBig='%s'\n", sgBig);

assert(sgBig == "1.68349e+09");

string sgBigG;

sgBigG.printf("%G", 1683490358.535);

printf("sgBigG='%s'\n", sgBigG);

assert(sgBigG == "1.68349E+09");

string poof, poofc;

poofc.printf("%6.2f", 0.14);

printf("poofc = '%s'\n", poofc);

assert(poofc == "   .14");

poof.printf("%6.2f", 0.04);

printf("poof = '%s'\n", poof);

assert(poof == "   .04");


