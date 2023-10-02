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

assert(!Version.isValidTemplate(null));
assert(!Version.isValidTemplate("a"));
assert(!Version.isValidTemplate("."));
assert(!Version.isValidTemplate(".1"));
assert(!Version.isValidTemplate("1."));
assert(!Version.isValidTemplate("1..1"));
assert(!Version.isValidTemplate("9223372036854775808"));
assert(!Version.isValidTemplate("01"));
assert(!Version.isValidTemplate("DD"));
assert(!Version.isValidTemplate("1D"));
assert(!Version.isValidTemplate("D1"));

assert( Version.isValidTemplate("0"));
assert( Version.isValidTemplate("1"));
assert( Version.isValidTemplate("2"));
assert( Version.isValidTemplate("3"));
assert( Version.isValidTemplate("4"));
assert( Version.isValidTemplate("5"));
assert( Version.isValidTemplate("6"));
assert( Version.isValidTemplate("7"));
assert( Version.isValidTemplate("8"));
assert( Version.isValidTemplate("9"));
assert( Version.isValidTemplate("1234567890"));
assert( Version.isValidTemplate("10000"));
assert( Version.isValidTemplate("1.1"));
assert( Version.isValidTemplate("1.1.1"));
assert( Version.isValidTemplate("1.1111.1"));
assert( Version.isValidTemplate("1.111111"));
assert( Version.isValidTemplate("11111111.1"));
assert( Version.isValidTemplate("D.1.1"));
assert( Version.isValidTemplate("1.D.1"));
assert( Version.isValidTemplate("1.1.D"));

