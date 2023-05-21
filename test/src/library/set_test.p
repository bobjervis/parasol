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
import parasol:types.Set;

Set<address> s;

ref<int> pi = new int;
*pi = 7;

ref<long> pl = new long;
*pl = -56;

s.add(pi);
s.add(pl);

assert(s.contains(pi));
assert(s.contains(pl));

ref<byte> pb = new byte;

assert(!s.contains(pb));
