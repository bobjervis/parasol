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

// The goal of the test is to determine that constants are assigned their runtime value before
// anyone could read them.  In this test, we check that the value is in the constant before its
// initializer.

int x = MAGIC_VALUE;

@Constant
int MAGIC_VALUE = 0x34718f2e;

assert(x == 0x34718f2e);
