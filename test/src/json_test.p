/*
   Copyright 2015 Rovert Jervis

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
import parasol:json;

printf("Start of test\n");
var value;
boolean success;

printf("Phase I: null, true and false\n");
(value, success) = json.parse("null");
assert(success);

(value, success) = json.parse("true");
assert(success);

(value, success) = json.parse("false");
assert(success);

printf("Phase II: numbers\n");
(value, success) = json.parse("0");
assert(success);

(value, success) = json.parse("-0");
assert(success);

(value, success) = json.parse("01");
assert(!success);

(value, success) = json.parse("13572068000");
assert(success);

(value, success) = json.parse("0.456");
assert(success);

(value, success) = json.parse("123.456");
assert(success);

(value, success) = json.parse("0e3");
assert(success);

(value, success) = json.parse("0E3");
assert(success);

(value, success) = json.parse("1e3");
assert(success);

(value, success) = json.parse("1E3");
assert(success);

(value, success) = json.parse("1e33");
assert(success);

(value, success) = json.parse("0e+3");
assert(success);

(value, success) = json.parse("0E+3");
assert(success);

(value, success) = json.parse("1e+3");
assert(success);

(value, success) = json.parse("1E+3");
assert(success);

(value, success) = json.parse("0e-3");
assert(success);

(value, success) = json.parse("0E-3");
assert(success);

(value, success) = json.parse("1e-3");
assert(success);

(value, success) = json.parse("1E-3");
assert(success);

(value, success) = json.parse("0.");
assert(!success);

(value, success) = json.parse("1.");
assert(!success);

(value, success) = json.parse("1.e3");
assert(!success);

(value, success) = json.parse("1.0e3");
assert(success);

(value, success) = json.parse("13572068000");
assert(success);

(value, success) = json.parse("0.456");
assert(success);

(value, success) = json.parse("123.456");
assert(success);

(value, success) = json.parse("-0e3");
assert(success);

(value, success) = json.parse("-0E3");
assert(success);

(value, success) = json.parse("-1e3");
assert(success);

(value, success) = json.parse("-1E3");
assert(success);

(value, success) = json.parse("-1.e3");
assert(!success);

(value, success) = json.parse("-1.0e3");
assert(success);

(value, success) = json.parse("-1e33");
assert(success);

(value, success) = json.parse("-0e+3");
assert(success);

(value, success) = json.parse("-0E+3");
assert(success);

(value, success) = json.parse("-1e+3");
assert(success);

(value, success) = json.parse("-1E+3");
assert(success);

(value, success) = json.parse("-0e-3");
assert(success);

(value, success) = json.parse("-0E-3");
assert(success);

(value, success) = json.parse("-1e-3");
assert(success);

(value, success) = json.parse("-1E-3");
assert(success);

printf("Phase III: strings\n");
(value, success) = json.parse("\"\"");
assert(success);

(value, success) = json.parse("\"abc def gh 2 34 *$&@&$(&(\"");
assert(success);

(value, success) = json.parse("\"a\\\"b\"");
assert(success);

(value, success) = json.parse("\"a\\\\b\"");
assert(success);

(value, success) = json.parse("\"a\\/b\"");
assert(success);

(value, success) = json.parse("\"a\\bb\"");
assert(success);

(value, success) = json.parse("\"a\\fb\"");
assert(success);

(value, success) = json.parse("\"a\\nb\"");
assert(success);

(value, success) = json.parse("\"a\\rb\"");
assert(success);

(value, success) = json.parse("\"a\\tb\"");
assert(success);

(value, success) = json.parse("\"a\\u123x\"");
assert(success);

(value, success) = json.parse("\"a\\u2f00x\"");
assert(success);

(value, success) = json.parse("\"a\\u2Dx\"");
assert(success);

(value, success) = json.parse("\"a\\xb\"");
assert(!success);

printf("Phase IV: arrays\n");

(value, success) = json.parse("[ ]");
assert(success);

(value, success) = json.parse("[ 1, 2, 3, 4, 5 ]");
assert(success);

(value, success) = json.parse("[ 1, 2, 3, 4, 5 ");
assert(!success);

(value, success) = json.parse("[ 1, 2, 3, 4,  ]");
assert(!success);

(value, success) = json.parse("2 ]");
assert(!success);

(value, success) = json.parse(" ]");
assert(!success);
printf("Phase V: objects\n");

(value, success) = json.parse("{ }");
assert(success);

(value, success) = json.parse("{ \"a\":true, \"b\":56e4 }");
assert(success);

(value, success) = json.parse("{ \"a\":true, \"b\":56e4");
assert(!success);

(value, success) = json.parse("{ \"a\":true, }");
assert(!success);

(value, success) = json.parse("{ \"a\":true, \"b\":{ \"c\":[ 2, 3, \"s\" ] } }");
assert(success);
