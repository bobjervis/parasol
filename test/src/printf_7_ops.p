string s;

s.printf("%6.2f", 12.5432);

printf("s='%s'\n", s);
assert(s == " 12.54");

string se;

se.printf("%12.2e", 12.5432);

printf("se='%s'\n", se);

assert(se == "   1.25e+002");

string sg;

sg.printf("%g", 12.5432);

printf("sg='%s'\n", sg);

assert(sg == "12.5432");

string sgBig;

sgBig.printf("%g", 1683490358.535);

printf("sgBig='%s'\n", sgBig);

assert(sgBig == "1.68349e+009");
