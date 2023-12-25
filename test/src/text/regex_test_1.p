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

text.Matcher m("(abc|def(.*))$");			// Produces 2 sub-expressions

assert(!m.hasError());

assert(!m.matches("ax"));                   // Sub-expression values are undefined after a failed match

assert(m.matches("abc"));                   // Matched on the first alternative, didn't match the second
assert(m.subexpression(0) == "abc");
assert(m.subexpression(1) == "abc");
assert(m.subexpression(2) == null);

assert(m.matches("defghi"));                // Matched on the second alternative, both populated
assert(m.subexpression(0) == "defghi");
assert(m.subexpression(1) == "defghi");
assert(m.subexpression(2) == "ghi");

m.setAtEoL(false);

assert(!m.matches("abc"));


