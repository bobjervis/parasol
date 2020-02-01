// A constructor inside a switch's block limits the allowed live range of a symbol (in this case s) to the same
// set of cases as the constructor.
compile(expact: fail) { "int a; switch (a) { case 1: string s(a); break; case 2: a = s[0]; }" }
// In this case, case 3 can enter control flow while s has not been constructed. That is not allowed.
compile(expact: fail) { "int a; switch (a) { case 1: string s(a); case 3: a = s[4]; break; case 2: a = 6; }" }
