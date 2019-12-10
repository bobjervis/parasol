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
printf("constructor tests\n");
constructorTests();
printf("append tests\n");
appendTests();
printf("center tests\n");
centerTests();
printf("indexOf tests\n");
indexOfTests();
printf("printf tests\n");
printfTests();
printf("substring tests\n");
substringTests();

void constructorTests() {
	string s = "abc";
	printf(s);
	printf("\n");
	pointer<byte> cp = &s[1];
	string s2(cp);
	printf("s2:");
	printf(s2);
	printf("\n");
	assert(s2 == "bc");
	
	string s3;
	
	cp = &s[0];
	s3 = string(cp, 2);
	assert(s3 == "ab");

	string sneg(-3);
	assert(sneg == "-3");
}

void appendTests() {
	string a;
	
	assert(a == null);
	
	a = "abc";
	assert(a.length() == 3);
	assert(a == "abc");
	assert("abc" == a);
	assert(a == rvalueABC());
	assert(rvalueABC() == "abc");
	assert(rvalueABC() == a);
	string b = "def";
	string c = a;
	c.append(b);
	printf(c);
	printf("\n");
	assert(c == "abcdef");
	byte by = '!';
	c.append(by);
	printf(c);
	printf("\n");
	assert(c == "abcdef!");
	pointer<byte> p = &c[4];
	string d;
	d.append(p, 2);
	assert(d == "ef");
	assert(c[3] == 'd');
	c[3] = 'x';
	printf(c);
	printf("\n");
	assert(c == "abcxef!");
}

string rvalueABC() {
	return "abc";
}

void centerTests() {
	string a = "abc";
	
	string c = a.center(10);
	printf("'");
	printf(c);
	printf("'\n");
	assert(c.length() == 10);
	printf("length ok!\n");
	assert(c == "   abc    ");
	
	printf("value ok!\n");
	string d = a.center(12, '#');
	printf("'");
	printf(d);
	printf("'\n");
	assert(d.length() == 12);
	printf("d length ok\n");
	assert(d == "####abc#####");
	printf("d value ok\n");
}

void indexOfTests() {
	printf("indexOfTests()\n");
	string value = "abcdef";
	
	assert(value.indexOf('b') == 1);
	assert(value.indexOf('x') == -1);
	assert(value.indexOf('e', 2) == 4);
	string repeater = "abcabc";
	assert(repeater.indexOf('c', 3) == 5);
	assert(value.lastIndexOf('b') == 1);
	assert(value.lastIndexOf('x') == -1);
	assert(value.lastIndexOf('e', 5) == 4);
	assert(repeater.lastIndexOf('c', 3) == 2);
	assert(repeater.lastIndexOf('c') == 5);
	assert(value.indexOf("bc") == 1);
	assert(value.indexOf("xy") == -1);
	assert(value.indexOf("ef", 2) == 4);
	assert(repeater.indexOf("bc", 3) == 4);
	assert(value.lastIndexOf("bc") == 1);
	assert(value.lastIndexOf("xy") == -1);
	assert(value.lastIndexOf("ef", 5) == 4);
	assert(repeater.lastIndexOf("bc", 3) == 1);
	assert(repeater.lastIndexOf("bc") == 4);
}

void printfTests() {
	printf("printfTests()\n");
	string s;
	
	s.printf("x%%y");
	assert(s == "x%y");
}

void substringTests() {
	printf("substringTests()\n");
	string full = "abcdef";
	
	string prefix = full.substr(0, 3);
	assert(prefix == "abc");
	string suffix = full.substr(4);
	printf(suffix);
	printf("\n");
	assert(suffix == "ef");
	string empty = full.substr(3, 3);
	assert(empty != null);
	assert(empty.length() == 0);
}
