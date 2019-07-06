compile(expect: fail) { "class A { A(int x) {} } class B extends A {} class C extends B { C() {} }" }

