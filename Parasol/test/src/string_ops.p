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
int main(string[] args) {
	compareTests();
	destructorTests();
	stringParamTests();
	resizeTests();
	string a, b, c;
	
	a = "sample";
	b = " stuff";
	c = a + b;
	assert(a == "sample");
	assert(b != "something else");
	assert(c == "sample stuff");
	assert(a + b == "sample stuff");
	
	string f = "xx";
	assert(f.length() == 2);
//	int x = f.printf("%s %d:", a, 35);
//	assert(f == "xxsample 35:");
//	assert(f.length() == 12);
//	assert(x == 10);

	assert(func().length() == funcValue.length());
	return 0;
}

string funcValue = "return-value";

string func() {
	return funcValue;
}

void compareTests() {
	string s = "abc";

	assert(s == "abc");
	assert(s != "def");
	assert(s < "abd");
	assert(s !< "abb");
	assert(s > "aab");
	assert(s !> "abe");
	assert(s <= "abe");
	assert(s !<= "aabe");
	assert(s >= "aaa");
	assert(s !>= "axx");
	assert(s <> "abx");
	assert(s !<> "abc");
	
	// Because string compares use method calls, non-lvalue left operands swap operands and map the operators,
	// so seprate tests are needed for each one.
	
	assert("abc" == s);
	assert("def" != s);
	assert("abd" >= s);
	assert("abb" !>= s);
	assert("aab" <= s);
	assert("abe" !<= s);
	assert("abe" > s);
	assert("aabe" !> s);
	assert("aaa" < s);
	assert("axx" !< s);
	assert("abx" <> s);
	assert("abc" !<> s);
}

void destructorTests() {
	// If the destructor gets called for s, then there should only be one 'x'
	// character in it on the second iteration.
	for (int i = 0; i < 2; i++) {
		print("iteration\n");
		string s;
		s.append("x");
		assert(s.length() == 1);
		assert(s[0] == 'x');
	}
}

void stringParamTests() {
	string a = "abc";
	assert(f(a) == 'c');
}

byte f(string d) {
	return d[d.length() - 1];
}

void resizeTests() {
	string s = "abc";
	
	s.resize(100);
	s[3] = 'e';
	s.resize(4);
	printf("s / %d = '%s'\n", s.length(), s);
	assert(s.length() == 4);
	assert(s == "abce");
}

