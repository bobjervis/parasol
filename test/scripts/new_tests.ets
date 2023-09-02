compile(expect: fail, message: NOT_A_TYPE) { "class C { int a; C(int x){} void f() {} } void g() { new C(5).f(); }" }
compile(expect: fail, message: FUNCTION_MISSING_BODY) { "void f(int, long);" }
compile(expect: fail, message: FUNCTION_MISSING_BODY) { "int f(int i, long j); int a(int i, long j) { return i; } f = a;" }
compile() { "void(int, long) f;" }
compile() { "flags F { A, B, C } F f; boolean x = f & F.B;" }
