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
class A {
	int x;
	int y;
	int z;
}

A a = { x: 1, y: 2, z: 3 };
A b = { x: 4, y: 5, z: 6 };

ref<A> ap = &a;
ref<A> bp = &b;

void farkle(A... params) {
	for (int i = 0; i < params.length(); i++)
		printf("params[%d]: { x: %d. y: %d, z: %d }\n", i, params[i].x, params[i].y, params[i].z);
	assert(params.length() == 2);
	assert(params[0].x == 1);
	assert(params[0].y == 2);
	assert(params[0].z == 3);
	assert(params[1].x == 4);
	assert(params[1].y == 5);
	assert(params[1].z == 6);
}

farkle(a, b);
farkle(*ap, *bp);
