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
import parasol:text;


string s = "\\xc2\\x80";

string o = s.unescapeParasol();

printf("o.length() = %d\n", o.length());
assert(o.length() == 2);
printf("o=[%x,%x]\n", o[0], o[1]);
assert(o[0] == '\xc2');
assert(o[1] == '\x80');
