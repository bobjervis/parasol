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

enum Enum { A, B, C, D, E, F }

// The bug that makes this case interesting is when the elements of the array aggregate have a different aggregate type
// from that of the LHS.

long[Enum] a = [ B: 17, F: 34 ];

printf("This may fail.\n");

