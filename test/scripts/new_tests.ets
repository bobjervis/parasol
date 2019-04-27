compile(expect: fail){"class A{ A(int x) {} int f() { return 3; } } class B extends A { B() { super(2); f(); super(3); } }"}
