import parasol:text;


string s = "\\xc2\\x80";

string o = s.unescapeParasol();

printf("o.length() = %d\n", o.length());
assert(o.length() == 2);
printf("o=[%x,%x]\n", o[0], o[1]);
assert(o[0] == '\xc2');
assert(o[1] == '\x80');
