compile(expect: fail, message: NOT_A_TYPE) { "class C { int a; C(int x){} void f() {} } void g() { new C(5).f(); }" }


