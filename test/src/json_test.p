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
import parasol:json;

printf("Start of test\n");
var value;
boolean success;

printf("Phase I: null, true and false\n");
(value, success) = json.parse("null");
assert(success);
assert(value.class == address);
assert(value == null);

(value, success) = json.parse("true");
assert(success);
assert(value.class == boolean);
assert(value == true);

(value, success) = json.parse("false");
assert(success);
assert(value.class == boolean);
assert(value == false);

(value, success) = json.parse("something");
assert(!success);

printf("Phase II: numbers\n");
(value, success) = json.parse("0");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("-0");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("01");
assert(!success);

(value, success) = json.parse("13572068000");
assert(success);
assert(value.class == double);
assert(double(value) == 13572068000);

(value, success) = json.parse("0.456");
assert(success);
assert(value.class == double);
assert(double(value) == 0.456);

(value, success) = json.parse("123.456");
assert(success);
assert(value.class == double);
assert(double(value) == 123.456);

(value, success) = json.parse("0e3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("0E3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("1e3");
assert(success);
assert(value.class == double);
assert(double(value) == 1000);

(value, success) = json.parse("1E3");
assert(success);
assert(value.class == double);
assert(double(value) == 1000);

(value, success) = json.parse("1e33");
assert(success);
assert(value.class == double);
assert(double(value) == 1.0e33);

(value, success) = json.parse("0e+3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("0E+3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("1e+3");
assert(success);
assert(value.class == double);
assert(double(value) == 1000);

(value, success) = json.parse("1E+3");
assert(success);
assert(value.class == double);
assert(double(value) == 1000);

(value, success) = json.parse("0e-3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("0E-3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("1e-3");
assert(success);
assert(value.class == double);
assert(double(value) == 0.001);

(value, success) = json.parse("1E-3");
assert(success);
assert(value.class == double);
assert(double(value) == 0.001);

(value, success) = json.parse("0.");
assert(!success);

(value, success) = json.parse("1.");
assert(!success);

(value, success) = json.parse("1.e3");
assert(!success);

(value, success) = json.parse("1.0e3");
assert(success);
assert(value.class == double);
assert(double(value) == 1000);

(value, success) = json.parse("-13572068000");
assert(success);
assert(value.class == double);
assert(double(value) == -13572068000);

(value, success) = json.parse("-0.456");
assert(success);
assert(value.class == double);
assert(double(value) == -0.456);

(value, success) = json.parse("-123.456");
assert(success);
assert(value.class == double);
assert(double(value) == -123.456);

(value, success) = json.parse("-0e3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("-0E3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("-1e3");
assert(success);
assert(value.class == double);
assert(double(value) == -1000);

(value, success) = json.parse("-1E3");
assert(success);
assert(value.class == double);
assert(double(value) == -1000);

(value, success) = json.parse("-1.e3");
assert(!success);

(value, success) = json.parse("-1.0e3");
assert(success);
assert(value.class == double);
assert(double(value) == -1000);

(value, success) = json.parse("-1e33");
assert(success);
assert(value.class == double);
assert(double(value) == -1.0e33);

(value, success) = json.parse("-0e+3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("-0E+3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("-1e+3");
assert(success);
assert(value.class == double);
assert(double(value) == -1000);

(value, success) = json.parse("-1E+3");
assert(success);
assert(value.class == double);
assert(double(value) == -1000);

(value, success) = json.parse("-0e-3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("-0E-3");
assert(success);
assert(value.class == double);
assert(double(value) == 0);

(value, success) = json.parse("-1e-3");
assert(success);
assert(value.class == double);
assert(double(value) == -0.001);

(value, success) = json.parse("-1E-3");
assert(success);
assert(value.class == double);
assert(double(value) == -0.001);

printf("Phase III: strings\n");
(value, success) = json.parse("\"\"");
assert(success);
assert(value.class == string);
assert(string(value) == "");

(value, success) = json.parse("\"abc def gh 2 34 *$&@&$(&(\"");
assert(success);
assert(value.class == string);
assert(string(value) == "abc def gh 2 34 *$&@&$(&(");

(value, success) = json.parse("\"a\\\"b\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\"b");

(value, success) = json.parse("\"a\\\\b\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\\b");

(value, success) = json.parse("\"a\\/b\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a/b");

(value, success) = json.parse("\"a\\bb\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\bb");

(value, success) = json.parse("\"a\\fb\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\fb");

(value, success) = json.parse("\"a\\nb\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\nb");

(value, success) = json.parse("\"a\\rb\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\rb");

(value, success) = json.parse("\"a\\tb\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\tb");

(value, success) = json.parse("\"a\\u123x\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\u123x");

(value, success) = json.parse("\"a\\u2f00x\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a\u2f00x");

(value, success) = json.parse("\"a\\u2Dx\"");
assert(success);
assert(value.class == string);
assert(string(value) == "a-x");

(value, success) = json.parse("\"a\\xb\"");
assert(!success);

printf("Phase IV: arrays\n");

(value, success) = json.parse("[ ]");
assert(success);
assert(value.class == ref<Array>);
assert(ref<Array>(value).length() == 0);
json.dispose(value);

(value, success) = json.parse("[ 1, 2, 3, 4, 5 ]");
assert(success);
assert(value.class == ref<Array>);
assert(ref<Array>(value).length() == 5);
assert(ref<Array>(value).get(0).class == double);
assert(double(ref<Array>(value).get(0)) == 1);
assert(ref<Array>(value).get(1).class == double);
assert(double(ref<Array>(value).get(1)) == 2);
assert(ref<Array>(value).get(2).class == double);
assert(double(ref<Array>(value).get(2)) == 3);
assert(ref<Array>(value).get(3).class == double);
assert(double(ref<Array>(value).get(3)) == 4);
assert(ref<Array>(value).get(4).class == double);
assert(double(ref<Array>(value).get(4)) == 5);
json.dispose(value);

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
assert(value.class == ref<Object>);
assert(ref<Object>(value).size() == 0);
json.dispose(value);

(value, success) = json.parse("{ \"a\":true, \"b\":56e4 }");
assert(success);
assert(value.class == ref<Object>);
assert(ref<Object>(value).size() == 2);
assert(ref<Object>(value).get("a").class == boolean);
assert(boolean(ref<Object>(value).get("a")) == true);
assert(ref<Object>(value).get("b").class == double);
assert(double(ref<Object>(value).get("b")) == 560000);
json.dispose(value);

(value, success) = json.parse("{ \"a\":true, \"b\":56e4");
assert(!success);

(value, success) = json.parse("{ \"a\":true, }");
assert(!success);

(value, success) = json.parse("{ \"a\":true, \"b\":{ \"c\":[ 2, 3, \"s\" ] } }");
assert(success);
assert(value.class == ref<Object>);
assert(ref<Object>(value).size() == 2);
assert(ref<Object>(value).get("a").class == boolean);
assert(boolean(ref<Object>(value).get("a")) == true);
assert(ref<Object>(value).get("b").class == ref<Object>);
ref<Object> b = ref<Object>(ref<Object>(value).get("b"));
assert(b.size() == 1);
assert(b.get("c").class == ref<Array>);
assert(ref<Array>(b.get("c")).length() == 3);
assert(ref<Array>(b.get("c")).get(0).class == double);
assert(double(ref<Array>(b.get("c")).get(0)) == 2);
assert(ref<Array>(b.get("c")).get(1).class == double);
assert(double(ref<Array>(b.get("c")).get(1)) == 3);
assert(ref<Array>(b.get("c")).get(2).class == string);
assert(string(ref<Array>(b.get("c")).get(2)) == "s");
json.dispose(value);

