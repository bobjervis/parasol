// First a basic test of non-formatting characters.
printf("Hello world!\n");
// Next, simple character formatting:
printf(" Character is '%c'\n", 'S');

string s = "xyz";

pointer<byte> cp = s.c_str();

printf("%s\n", cp);
