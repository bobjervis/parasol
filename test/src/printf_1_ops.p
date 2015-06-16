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
// First a basic test of non-formatting characters.
printf("Hello world!\n");
// Next, simple character formatting:
printf(" Character is '%c'\n", 'S');

string s = "xyz";

pointer<byte> cp = s.c_str();

printf("%s\n", cp);
