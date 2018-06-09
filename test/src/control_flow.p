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
int main(string[] args) {
	int i = 4;
	int j = 5;
	int k = 7, m = 22;
	
	if (k < m)
		printf("k < m\n");
	else
		assert(false);
	if (i == j)
		assert(false);
	else
		printf("i != j\n");
	int count = 0;
	while (i < k) {
		i++;
		count++;
	}
	assert(count == 3);
	assert(i == k);

	count = 0;
	do {
		i++;
		count++;
	} while (i < m);
	assert(count == 15);
	assert(i == m);
	for (i = 5; i < 20; i++) {
		j += i;
		if (j > 40)
			break;
		if (j < 41)
			continue;
		j += 56;
	}
	assert(j == 50);
	j = 5;
	for (byte i = 5; i < 20; i++) {
		j += i;
		if (j > 40)
			break;
		if (j < 41)
			continue;
		j += 56;
	}
	assert(j == 50);
	j = 5;
	i = 5;
	while (i < 20) {
		j += i;
		if (j > 40)
			break;
		if (j < 41) {
			i++;
			continue;
		}
		j += 56;
	}
	j = 5;
	i = 5;
	do {
		j += i;
		if (j > 40)
			break;
		if (j < 41) {
			i++;
			continue;
		}
		j += 56;
	} while (i < 20);
	assert(j == 50);
	assert(basicSwitchTest(1) == 3);
	assert(basicSwitchTest(2) == 4);
	assert(basicSwitchTest(3) == 0);
	assert(defaultSwitchTest(1) == 3);
	assert(defaultSwitchTest(2) == 4);
	assert(defaultSwitchTest(3) == 1);
	i = 10;
	for (;;) {
		if (i <= 0)
			break;
		i--;
	}
	assert(i == 0);
	forScopeTest();
	forBreakRegression2();
	forBreakRegression1();
	return 0;
}

int basicSwitchTest(int path) {
	switch (path) {
	case 1:
		return 3;
		
	case 2:
		return 4;
	}
	return 0;
}

int defaultSwitchTest(int path) {
	switch (path) {
	case 1:
		return 3;
		
	case 2:
		return 4;
		
	default:
		return 1;
	}
	return 7;
}

void forScopeTest() {
	boolean flag = false;
	
	for (int i = 0; i < 5; i++)
		if (i > 3) {
			flag = true;
		}
	assert(flag == true);
}
// This is a degenerate case. The bug is that the 'return' implied at the end is missing, so the code falls off onto the next 
// byte, which is an illegal instruction (usually).
void forBreakRegression1() {
	for (;;) {
		break;
	}
}

//This is a degenerate case. The bug is that the 'return' implied at the end is missing, so the code falls off onto the next 
//byte, which is an illegal instruction (usually).
void forBreakRegression2() {
	for (;;) {
		break;
	}
	int x = 5;
}
