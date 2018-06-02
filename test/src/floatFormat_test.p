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
import native:C;
import parasol:runtime;

string buffer;

buffer.resize(512);

int x = runtime.parasol_gFormat(&buffer[0], buffer.length(), 5.76449, 3);

string output(&buffer[0]);

printf("x = %d buffer = '%s'\n", x, output);

assert(output == "5.76");

assert(x == 4);

int y = runtime.parasol_gFormat(&buffer[0], buffer.length(), 0.0, 6);

string output2(&buffer[0]);

printf("y = %d output2 = '%s'\n", y, output2);

assert(y == 1);

assert(output2 == "0");

