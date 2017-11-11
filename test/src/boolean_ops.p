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
@Constant
boolean CONST = true;

int main(string[] args) {
	boolean a = true;
	boolean b = false;
	boolean c = true;
	boolean d = false;

	print("Begin basic operations tests...\n");
	
	// All of these expressions should be true (given the above)

	assert(a | b);
	assert(b | a);
	assert(a ^ b);
	assert(b ^ a);
	assert(a & c);
	assert(a == c);
	assert(b == d);
	assert(a != b);
	assert(d != c);
	
	print("Begin assignment operators tests...\n");
	
	// Assigning true should make the result variable true

	d = a;
	assert(d);

	// Or'ing in true should make the result true

	d = false;
	d |= a;
	assert(d);

	d = true;
	d |= b;
	assert(d);

	d = false;
	d ^= a;
	assert(d);

	d = true;
	d ^= b;
	assert(d);

	d = true;
	d &= a;
	assert(d);

	d = false;
	assert(d |= a);

	d = true;
	assert(d |= b);

	d = false;
	assert(d ^= a);

	d = true;
	assert(d ^= b);

	d = true;
	assert(d &= a);

	assert(!b);

	d = !b;
	assert(d);

	assert(func(d));

	assert(CONST);
	
	print("Logical tests\n");
	
	logicalTests();
	return 0;
}

boolean func(boolean p) {
	return p;
}

void logicalTests() {
	printf("true && true\n");
	if (true1() && true2())
		assert(pathTaken == 2);
	else {
		printf("true && true == false???\n");
		assert(false);
	}
	printf("true && false\n");
	if (true1() && false3()) {
		printf("true && false == true???\n");
		assert(false);
	} else
		assert(pathTaken == 3);
	printf("false && true\n");
	if (false3() && true1()) {
		printf("true && false == true???\n");
		assert(false);
	} else
		assert(pathTaken == 3);
	printf("false && false\n");
	if (false3() && false4()) {
		printf("false && false == true???\n");
		assert(false);
	} else
		assert(pathTaken == 3);
		
	printf("true || true\n");
	if (true1() || true2())
		assert(pathTaken == 1);
	else {
		printf("true || true == false???\n");
		assert(false);
	}
	printf("true || false\n");
	if (true1() || false3())
		assert(pathTaken == 1);
	else {
		printf("true || false == false???\n");
		assert(false);
	}
	printf("false || true\n");
	if (false3() || true1()) 
		assert(pathTaken == 1);
	else {
		printf("true || false == false???\n");
		assert(false);
	}
	printf("false || false\n");
	if (false3() || false4()) {
		printf("false || false == true???\n");
		assert(false);
	} else
		assert(pathTaken == 4);
}

int pathTaken;

boolean true1() {
	pathTaken = 1;
	return true;
}

boolean true2() {
	pathTaken = 2;
	return true;
}

boolean false3() {
	pathTaken = 3;
	return false;
}

boolean false4() {
	pathTaken = 4;
	return false;
}
