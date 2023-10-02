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

assert(!Version.isValid(null));
assert(!Version.isValid("a"));
assert(!Version.isValid("."));
assert(!Version.isValid(".1"));
assert(!Version.isValid("1."));
assert(!Version.isValid("1..1"));
assert(!Version.isValid("9223372036854775808"));
assert(!Version.isValid("01"));

assert( Version.isValid("0"));
assert( Version.isValid("1"));
assert( Version.isValid("2"));
assert( Version.isValid("3"));
assert( Version.isValid("4"));
assert( Version.isValid("5"));
assert( Version.isValid("6"));
assert( Version.isValid("7"));
assert( Version.isValid("8"));
assert( Version.isValid("9"));
assert( Version.isValid("1234567890"));
assert( Version.isValid("10000"));
assert( Version.isValid("1.1"));
assert( Version.isValid("1.1.1"));
assert( Version.isValid("1.1111.1"));
assert( Version.isValid("1.111111"));
assert( Version.isValid("11111111.1"));

