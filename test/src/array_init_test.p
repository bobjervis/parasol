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
ref<Array> a = [ 2, 3, 5.7 ];

assert(a != null);
assert(a.length() == 3);

var a0 = a.get(0);
var a1 = a.get(1);
var a2 = a.get(2);

assert(a0.class == long);
assert(long(a0) == 2);

assert(a1.class == long);
assert(long(a1) == 3);

assert(a2.class == double);
assert(double(a2) == 5.7);
