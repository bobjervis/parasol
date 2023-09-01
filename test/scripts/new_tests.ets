compile(expect: fail, message: NOT_A_TYPE) { "class C { int a; C(int x){} void f() {} } void g() { new C(5).f(); }" }
compile() { "void f(int, long);" }
compile() { "void(int, long) f;" }
compile() { "flags F { A, B, C } F f; boolean x = f & F.B;" }
