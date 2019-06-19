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

// US, Canada and Phillippines use Letter Size

ref<international.Locale> locale1 = international.getLocale("en-CA.utf-8");
assert(locale1 != null);
ref<international.PaperStyle> ps1 = locale1.paperStyle();

printf("CA paper size = %d x %d\n", locale1.paperStyle().width, locale1.paperStyle().height);
assert(ps1.width == 216);
assert(ps1.height == 279);

// Everybody else uses A4 Size

ref<international.Locale> locale2 = international.getLocale("de-DE.utf-8");
assert(locale2 != null);
ref<international.PaperStyle> ps2 = locale2.paperStyle();

printf("DE paper size = %d x %d\n", locale2.paperStyle().width, locale2.paperStyle().height);
assert(ps2.width == 210);
assert(ps2.height == 297);
