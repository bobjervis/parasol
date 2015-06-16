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

address x;

assert(x.bytes == 8);

address start, end;

byte y;

start = &y;
end = pointer<byte>(&y) + 3;

print("Address difference test:\n");

assert(x != start);

address xx = &y;

assert(xx == start);

print("Basic address operations confirmed.\n");

address bp;

assert(bp == address(0));

print("Null pointer initialization test passed.\n");

pointer<long> zz = pointer<long>(xx);

assert(zz == start);
assert(address(zz) == start);
