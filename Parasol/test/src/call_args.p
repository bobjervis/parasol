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
	print("Starting loop\n");
	while (looping) {
		if (firstTime) {
			print("First time\n");
			string s = sb(3);
		
			print(s);
			print("\n");
			assert(s == "abc");
		
			print("sb done\n");
			string aa = "xx" + sb(-2);
			print("aa done\n");
			print(aa);
			print("\n");
			string t = sb(3) + "xx" + sb(-2);
		
			print("added ");
			print(t);
			print("\n");
			assert(t == "abcxxdef");
			firstTime = false;
		} else {
			print("Not first time\n");
			string x = sb(1);
			assert(x == "abc");
			looping = false;
		}
	}
	print("Loop done\n");
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

