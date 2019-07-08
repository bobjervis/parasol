compile(expect: fail) { "class A { A(int x) {} } class B extends A {} class C extends B { C() {} }" }
compile() { "int x; int y = x.MIN_VALUE;" }
