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
import parasol:storage;
import parasol:text;

storage.CsvFile file;

string source = "0,1\n\"abcdef\",34,Hello\n";

text.UTF8Decoder decoder(&source[0], source.length());

assert(file.load(&decoder));

assert(file.recordCount() == 2);
assert(file.fieldCount(0) == 2);
assert(file.fetch(0, 0) == "0");
assert(file.fetch(0, 1) == "1");
assert(file.fieldCount(1) == 3);
assert(file.fetch(1, 0) == "abcdef0");
assert(file.fetch(1, 1) == "34");
assert(file.fetch(1, 2) == "Hello");

