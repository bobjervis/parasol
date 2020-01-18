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
import parasol:international;

ref<international.Locale> locale = international.getLocale("en-us");

assert(locale != null);

printf("positiveSign = %s\n", locale.decimalStyle().positiveSign);

assert(locale.decimalStyle().positiveSign == "+");
assert(locale.decimalStyle().decimalSeparator == ".");
assert(locale.decimalStyle().groupSeparator == ",");

locale = international.getLocale("de");

assert(locale != null);

printf("positiveSign = %s\n", locale.decimalStyle().positiveSign);

assert(locale.decimalStyle().positiveSign == "+");
assert(locale.decimalStyle().decimalSeparator == ",");
assert(locale.decimalStyle().groupSeparator == ".");

