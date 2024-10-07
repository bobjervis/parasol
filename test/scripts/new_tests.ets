compile() { "class Tuple { int i, j; } Tuple a = { i: 5, j: 6 }\n a.i += a.j" }
compile() { "long b; long a = b &\n 37;" }
compile() { "long b; long a = b |\n 37;" }
compile() { "long b; long a = b ^\n 37;" }
compile() { "long b; long a; a &=\n 37;" }
compile() { "long b; long a; a |=\n 37;" }
compile() { "long b; long a; a ^=\n 37;" }
compile() { "long b; long a = b *\n 37;" }
compile() { "long b; long a = b /\n 37;" }
compile() { "long b; long a = b %\n 37;" }
compile() { "long b; long a = b +\n 37;" }
compile() { "long b; long a = b -\n 37;" }
compile() { "long b; long a = b <<\n 5;" }
compile() { "long b; long a = b >>\n 5;" }
compile() { "long b; long a = b >>>\n 5;" }
compile() { "long b; long a; a *=\n 37;" }
compile() { "long b; long a; a /=\n 37;" }
compile() { "long b; long a; a %=\n 37;" }
compile() { "long b; long a; a +=\n 37;" }
compile() { "long b; long a; a -=\n 37;" }
compile() { "long b; long a; a <<=\n 5;" }
compile() { "long b; long a; a >>=\n 5;" }
compile() { "long b; long a; a >>>=\n 5;" }
compile() { "long b; boolean a = b ==\n 37;" }
compile() { "long b; boolean a = b !=\n 37;" }
compile() { "long b; boolean a = b <\n 37;" }
compile() { "long b; boolean a = b >\n 37;" }
compile() { "long b; boolean a = b <=\n 37;" }
compile() { "long b; boolean a = b >=\n 37;" }
compile() { "long b; boolean a = b <>\n 37;" }
compile() { "long b; boolean a = b !<\n 37;" }
compile() { "long b; boolean a = b !>\n 37;" }
compile() { "long b; boolean a = b !<=\n 37;" }
compile() { "long b; boolean a = b !>=\n 37;" }
compile() { "long b; boolean a = b !<>\n 37;" }
compile() { "float b; boolean a = b <>=\n 37;" }
compile() { "float b; boolean a = b !<>=\n 37;" }
compile() { "long a; a =\n a;" }
compile() { "long a; a \n= a;" }
compile() { "long a; a = -\na;" }
compile() { "long a; a = +\na;" }
compile() { "long a; a = ~\na;" }
compile(expect:fail) { "long a; a = --\na;" } // increment and decrement operators should not be written this way, even if the compiler could be made 
compile(expect:fail) { "long a; a = ++\na;" } // to disambiguate and choose to not assume an elided semi-colon is present.
compile(expect:fail) { "long a; a = a\n--;" }
compile(expect:fail) { "long a; a = a\n++;" }
compile() { "long b; long a = b \n& 37;" }
compile() { "long b; long a = b \n| 37;" }
compile() { "long b; long a = b \n^ 37;" }
compile() { "long b; long a; a \n&= 37;" }
compile() { "long b; long a; a \n|= 37;" }
compile() { "long b; long a; a \n^= 37;" }
compile() { "long b; long a = b \n* 37;" }
compile() { "long b; long a = b \n/ 37;" }
compile() { "long b; long a = b \n% 37;" }
compile() { "long b; long a = b \n+ 37;" }
compile() { "long b; long a = b \n- 37;" }
compile() { "long b; long a = b \n<< 5;" }
compile() { "long b; long a = b \n>> 5;" }
compile() { "long b; long a = b \n>>> 5;" }
compile() { "long b; long a = b \n >> 5;" }
compile() { "long b; long a = b \n >>> 5;" }
compile() { "long b; long a; a \n*= 37;" }
compile() { "long b; long a; a \n/= 37;" }
compile() { "long b; long a; a \n%= 37;" }
compile() { "long b; long a; a \n+= 37;" }
compile() { "long b; long a; a \n-= 37;" }
compile() { "long b; long a; a \n<<= 5;" }
compile() { "long b; long a; a \n>>= 5;" }
compile() { "long b; long a; a \n>>>= 5;" }
compile() { "long b; long a; a \n >>= 5;" }
compile() { "long b; long a; a \n >>>= 5;" }
compile() { "long b; boolean a = b \n== 37;" }
compile() { "long b; boolean a = b \n!= 37;" }
compile() { "long b; boolean a = b \n< 37;" }
compile() { "long b; boolean a = b \n> 37;" }
compile() { "long b; boolean a = b \n<= 37;" }
compile() { "long b; boolean a = b \n>= 37;" }
compile() { "long b; boolean a = b \n<> 37;" }
compile() { "long b; boolean a = b \n!< 37;" }
compile() { "long b; boolean a = b \n!> 37;" }
compile() { "long b; boolean a = b \n!<= 37;" }
compile() { "long b; boolean a = b \n!>= 37;" }
compile() { "long b; boolean a = b \n!<> 37;" }
compile() { "float b; boolean a = b \n<>= 37;" }
compile() { "float b; boolean a = b \n!<>= 37;" }

