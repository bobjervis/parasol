compile(expect: fail, message: NOT_AN_INTERFACE) { "monitor class a { byte filler; } class b implements a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "monitor class a { byte filler; } interface b extends a {}" }

compile() { "monitor class M<class T> { T x; } M<int> a; lock(a) { x = 345678; }" }
compile() { "monitor class M<class T> { T x; } monitor class N<class T> extends M<T> {}; N<int> a; lock(a) { x = 345678; }" }


compile(expect: fail) { "monitor class M { int a; } class C extends M {} C x; x.a = 3;" }
compile(expect: fail) { "monitor class M { int a; } class C extends M { void f() { a = 3; } }" }
compile() { "monitor class M { } class C extends M { int a; } monitor class N extends C {} N x; x.a = 3;" }


compile() { "Monitor a; lock(a) { }" }
compile() { "Monitor a; lock(a) { notify(); }" }
compile() { "Monitor a; lock(a) { notifyAll(); }" }
compile() { "Monitor a; lock(a) { wait(); }" }
compile() { "Monitor a; lock(a) { wait(10); }" }
compile() { "Monitor a; lock(a) { wait(10, 5); }" }
compile() { "lock(a) { } Monitor a;" }
compile() { "monitor class M {} M a; lock(a) { }" }
compile() { "monitor class M { int b; } M a; lock(a) { int c = b; }" }
compile() { "M a; lock(a) { int c = b; } monitor class M { int b; }" }
compile() { "monitor class M { int b() { return 0; } } M a; lock(a) { int c = b(); }" }
compile() { "monitor class M { void b() { } } M a; a.b();" }
compile() { "Monitor a; lock(a) { int x; }" }
compile() { "Monitor a; void func() lock(a) {}" }
compile() { "Monitor a; void func() lock(a) { int x; }" }

compile(expect: fail) { "float a; lock(a) { }" }
compile(expect: fail) { "float a; void func() lock(a) {}" }
compile(expect: fail) { "monitor class M { int b; }; M a; int c = a.b;" }

compile() { "monitor class M { int b; } monitor class N extends M { int d; }" }
compile() { "monitor class M { int b; } class N extends M { int d; }" }
compile(expect: fail) { "class M { int b; } monitor class N extends M { int d; }" }
compile() { "monitor class M { int b; } class N extends M { int d; } monitor class P extends N { int e; }" }

