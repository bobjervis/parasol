import parasol:text;

s := sprintf("This is a test %d %d %d", 1, 2, 3);

assert(s == "This is a test 1 2 3");

s16 := sprintf16("This is a test %d %d %d", 4, 5, 6);

printf("s16 len = %d\n", s16.length())
text.memDump(&s16[0], s16.length() * char.bytes)
assert(s16 == string16("This is a test 4 5 6"));
