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
/*
 *	Verify that the order of arguments in a call is correct.
 */
int main(string[] args) {
	f(1, 2);
	char x = 4;
	char y = 7;
	g(x, y);
	boolean looping = true;
	boolean firstTime = true;
	printf("Starting loop\n");
	while (looping) {
		if (firstTime) {
			printf("First time\n");
			string s = sb(3);
		
			printf(s);
			printf("\n");
			assert(s == "abc");
		
			printf("sb done\n");
			string aa = "xx" + sb(-2);
			printf("aa done\n");
			printf(aa);
			printf("\n");
			string t = sb(3) + "xx" + sb(-2);
		
			printf("added ");
			printf(t);
			printf("\n");
			assert(t == "abcxxdef");
			firstTime = false;
		} else {
			printf("Not first time\n");
			string x = sb(1);
			assert(x == "abc");
			looping = false;
		}
	}
	printf("Loop done\n");
	return 0;
}

void f(int i, int j) {
	assert(i == 1);
	assert(j == 2);
}

void g(int i, int j) {
	assert(i == 4);
	assert(j == 7);
}

string, boolean sb(int x) {
	if (x > 0)
		return "abc", true;
	else
		return "def", false;
}

