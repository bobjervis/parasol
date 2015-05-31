compile(filename: hello.p)
compile(filename: void_return_pass.p)
compile(filename: int_return_pass.p)

compile(filename: syntax_error.p, expect: fail, message: DO_WHILE_NO_SEMI)
compile(filename: undef_type.p, expect: fail, message: UNDEFINED)
compile(filename: undef_init.p, expect: fail, message: UNDEFINED)
compile(filename: void_return_fail.p, expect: fail, message: RETURN_VALUE_DISALLOWED)
compile(filename: int_return_fail.p, expect: fail, message: RETURN_VALUE_REQUIRED)
compile(filename: unit_return_fail.p, expect: fail, message: RETURN_DISALLOWED)
compile(filename: unit_return_fail2.p, expect: fail, message: RETURN_DISALLOWED)

compile(filename: stray_token_enum.p, expect: fail)

compile(){"pointer<int> ip; var v = ip;" }

compile(){"class Foo { public static Foo x(-1); Foo(int z){} }"}

compile(){"long i; string formatted(i);"}

// This test checks a regression concering accepting ... arguments.
compile() { "class Bar { void f(int... args) { } } ref<Bar> x; x.f(4);" }

//compile(expect: fail) { "ref<int> x = = new int();" }
compile(expect: fail, message: DUPLICATE) { "class Foo { private int f(int y) { return 0; } public int f(int z) { return z; } }" }
compile(expect: fail) { "void f() { for (int i = 0; i < 5); i++) printf("hello"); }" }

// This tests a regression involving bad code generation and also the ordering of an in-order traversal of
// the 'int a, b, c;' portion of the line.  The original failure involved not catching the missing parameter
// error and executing anyway.

compile(expect: fail, message: NO_MATCHING_OVERLOAD) { "void f(ref<int> y, int z, ref<int> w) {} int a, b, c; f(&a, &c);" }

compile() { "void f(int x(int z)){}" }
compile() { "void f(int x(int z)){} f(g.h); class g { static int h(int y) { return 0;} }" }

compile() { "class A { void f() { } } class B extends A { void g() { f(); } }" }

compile(expect: fail) { "static int x;" }
compile(expect: fail) { "class A { static A() { } } " }
compile(expect: fail) { "class A { static ~A() { } } " }

compile(expect: fail, message: NOT_CONSTANT) { "int x; switch(0) { case x: break; }" }

compile() { "switch(0) { case -1: break; }" }

compile(expect: fail, message:INVALID_IMPORT) { "namespace x:y; import x:y;" }

compile() { "string[] ss; ss[4] = \"abc\";" }
compile() { "string[] ss, tt; ss = tt;" }
compile(expect: fail, message: CANNOT_CONVERT) { "string[] ss; ss[4] = 7;" }
compile(expect: fail, message: CANNOT_CONVERT) { "string[] ss; ss = \"a\";" }

compile(expect: fail, message: INVALID_DEFAULT) { "default: int x;" }
compile(expect: fail, message: INVALID_CASE) { "case 3: int x;" }
compile(expect: fail, message: NOT_ENUM_INSTANCE) { "enum e { A, B, C }; e x; switch (x) { case 3: break; }" }

compile(expect: fail, message: ABSTRACT_INSTANCE_DISALLOWED) { 
			"class Foo { abstract int f(); Foo() {} }; ref<Foo> a = new Foo();" 
		}

// The matrix of allowed operators for boolean operands:

compile() { "boolean a = true & true;" }
compile() { "boolean a = true | true;" }
compile() { "boolean a = true ^ true;" }
compile() { "boolean a; a &= true;" }
compile() { "boolean a; a |= true;" }
compile() { "boolean a; a ^= true;" }
compile() { "boolean a = true == true;" }
compile() { "boolean a = true != true;" }
compile() { "boolean a = true && true;" }
compile() { "boolean a = true || true;" }
compile() { "boolean a = !true;" }

compile(expect: fail, message: BAD_MULTI_ASSIGN) { "int x,y; (x, y) = (1, 3);" }

// Disallowed implicit casts.

compile(expect: fail, message: CANNOT_CONVERT) { "int x; byte b; b = x;" }
compile(expect: fail, message: CANNOT_CONVERT) { "int x; char c; c = x;" }

compile(expect: fail) { "3 = 3;" }
compile(expect: fail) { "3 += 3;" }
compile(expect: fail) { "3 -= 3;" }
compile(expect: fail) { "3 *= 3;" }
compile(expect: fail) { "3 /= 3;" }
compile(expect: fail) { "3 %= 3;" }
compile(expect: fail) { "3 &= 3;" }
compile(expect: fail) { "3 |= 3;" }
compile(expect: fail) { "3 ^= 3;" }
compile(expect: fail) { "3 <<= 3;" }
compile(expect: fail) { "3 >>= 3;" }
compile(expect: fail) { "3 >>>= 3;" }

compile() { "3 < 4 ? 5 : 6;" }

compile() { "int f() { if (true) return 5; else return 3; }" }
compile() { "int f() { return 3; class foo { } }" }
compile() { "int f() { return 3; class foo<class T> { T x; } }" }
compile() { "int f() { for (int i = 0;;) { } }" }
compile() { "int f() { for (;;) { } }" }

compile(expect: fail, message: UNDEFINED) { "class X { X(int foo, int bar) {} } void f() { X x(baz, 9); }" }

compile(expect: fail) { "class A { private int x; }; void f(A a) { int b = a.x; }" }

compile(expect: fail, message: ABSTRACT_INSTANCE_DISALLOWED) { "class A { public abstract void f(); } class B extends A { } B b;" }

compile() { "class A { private byte z; int x; }; void f(A a) { int b = a.x; }" }
compile(expect: fail, message: RETURN_VALUE_REQUIRED) { "int f() { int a; if (true) return 5; else a = 3; }" }
compile(expect: fail, message: RETURN_VALUE_REQUIRED) { "int f() { int a; }" }
compile(expect: fail, message: INVALID_MULTIPLY) { "boolean a = true * true;" }
compile(expect: fail, message: INVALID_DIVIDE) { "boolean a = true / true;" }
compile(expect: fail, message: INVALID_REMAINDER) { "boolean a = true % true;" }
compile(expect: fail, message: INVALID_ADD) { "boolean a = true + true;" }
compile(expect: fail, message: INVALID_SUBTRACT) { "boolean a = true - true;" }
compile(expect: fail, message: LEFT_NOT_INT) { "boolean a = true << 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "boolean a = true >> 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "boolean a = true >>> 5;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "boolean a = 5 << true;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "boolean a = 5 >> true;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "boolean a = 5 >>> true;" }
compile(expect: fail, message: INVALID_MULTIPLY) { "boolean a; a *= true;" }
compile(expect: fail, message: INVALID_DIVIDE) { "boolean a; a /= true;" }
compile(expect: fail, message: INVALID_REMAINDER) { "boolean a; a %= true;" }
compile(expect: fail, message: INVALID_ADD) { "boolean a; a += true;" }
compile(expect: fail, message: INVALID_SUBTRACT) { "boolean a; a -= true;" }
compile(expect: fail, message: LEFT_NOT_INT) { "boolean a; a <<= 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "boolean a; a >>= 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "boolean a; a >>>= 5;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true < true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true > true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true <= true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true >= true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true <> true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true <>= true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true !< true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true !> true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true !<= true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true !>= true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true !<> true;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = true !<>= true;" }
compile(expect: fail, message: INVALID_NEGATE) { "boolean a; a = -a;" }
compile(expect: fail, message: INVALID_UNARY_PLUS) { "boolean a; a = +a;" }
compile(expect: fail, message: INVALID_BIT_COMPLEMENT) { "boolean a; a = ~a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "boolean a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "boolean a; a = *a;" }
compile(expect: fail, message: NOT_INTEGER) { "boolean a; a = --a;" }
compile(expect: fail, message: NOT_INTEGER) { "boolean a; a = ++a;" }
compile(expect: fail, message: NOT_INTEGER) { "boolean a; a = a--;" }
compile(expect: fail, message: NOT_INTEGER) { "boolean a; a = a++;" }

compile(expect: fail) { "ref<int> x; if (x == 0) x = new int;" }

// The matrix of allowed operators for unsigned operands:

compile() { "unsigned b; unsigned a = b & 37;" }
compile() { "unsigned b; unsigned a = b | 37;" }
compile() { "unsigned b; unsigned a = b ^ 37;" }
compile() { "unsigned b; unsigned a; a &= 37;" }
compile() { "unsigned b; unsigned a; a |= 37;" }
compile() { "unsigned b; unsigned a; a ^= 37;" }
compile() { "unsigned b; unsigned a = b * 37;" }
compile() { "unsigned b; unsigned a = b / 37;" }
compile() { "unsigned b; unsigned a = b % 37;" }
compile() { "unsigned b; unsigned a = b + 37;" }
compile() { "unsigned b; unsigned a = b - 37;" }
compile() { "unsigned b; unsigned a = b << 5;" }
compile() { "unsigned b; unsigned a = b >> 5;" }
compile() { "unsigned b; unsigned a = b >>> 5;" }
compile() { "unsigned b; unsigned a; a *= 37;" }
compile() { "unsigned b; unsigned a; a /= 37;" }
compile() { "unsigned b; unsigned a; a %= 37;" }
compile() { "unsigned b; unsigned a; a += 37;" }
compile() { "unsigned b; unsigned a; a -= 37;" }
compile() { "unsigned b; unsigned a; a <<= 5;" }
compile() { "unsigned b; unsigned a; a >>= 5;" }
compile() { "unsigned b; unsigned a; a >>>= 5;" }
compile() { "unsigned b; boolean a = b == 37;" }
compile() { "unsigned b; boolean a = b != 37;" }
compile() { "unsigned b; boolean a = b < 37;" }
compile() { "unsigned b; boolean a = b > 37;" }
compile() { "unsigned b; boolean a = b <= 37;" }
compile() { "unsigned b; boolean a = b >= 37;" }
compile() { "unsigned b; boolean a = b <> 37;" }
compile() { "unsigned b; boolean a = b !< 37;" }
compile() { "unsigned b; boolean a = b !> 37;" }
compile() { "unsigned b; boolean a = b !<= 37;" }
compile() { "unsigned b; boolean a = b !>= 37;" }
compile() { "unsigned b; boolean a = b !<> 37;" }
compile() { "unsigned a; a = -a;" }
compile() { "unsigned a; a = +a;" }
compile() { "unsigned a; a = ~a;" }
compile() { "unsigned a; a = --a;" }
compile() { "unsigned a; a = ++a;" }
compile() { "unsigned a; a = a--;" }
compile() { "unsigned a; a = a++;" }

// The matrix of allowed operators for long operands:

compile() { "long b; long a = b & 37;" }
compile() { "long b; long a = b | 37;" }
compile() { "long b; long a = b ^ 37;" }
compile() { "long b; long a; a &= 37;" }
compile() { "long b; long a; a |= 37;" }
compile() { "long b; long a; a ^= 37;" }
compile() { "long b; long a = b * 37;" }
compile() { "long b; long a = b / 37;" }
compile() { "long b; long a = b % 37;" }
compile() { "long b; long a = b + 37;" }
compile() { "long b; long a = b - 37;" }
compile() { "long b; long a = b << 5;" }
compile() { "long b; long a = b >> 5;" }
compile() { "long b; long a = b >>> 5;" }
compile() { "long b; long a; a *= 37;" }
compile() { "long b; long a; a /= 37;" }
compile() { "long b; long a; a %= 37;" }
compile() { "long b; long a; a += 37;" }
compile() { "long b; long a; a -= 37;" }
compile() { "long b; long a; a <<= 5;" }
compile() { "long b; long a; a >>= 5;" }
compile() { "long b; long a; a >>>= 5;" }
compile() { "long b; boolean a = b == 37;" }
compile() { "long b; boolean a = b != 37;" }
compile() { "long b; boolean a = b < 37;" }
compile() { "long b; boolean a = b > 37;" }
compile() { "long b; boolean a = b <= 37;" }
compile() { "long b; boolean a = b >= 37;" }
compile() { "long b; boolean a = b <> 37;" }
compile() { "long b; boolean a = b !< 37;" }
compile() { "long b; boolean a = b !> 37;" }
compile() { "long b; boolean a = b !<= 37;" }
compile() { "long b; boolean a = b !>= 37;" }
compile() { "long b; boolean a = b !<> 37;" }
compile() { "long a; a = -a;" }
compile() { "long a; a = +a;" }
compile() { "long a; a = ~a;" }
compile() { "long a; a = --a;" }
compile() { "long a; a = ++a;" }
compile() { "long a; a = a--;" }
compile() { "long a; a = a++;" }

// The matrix of allowed operators for int operands:

compile() { "int a = 37 & 37;" }
compile() { "int a = 37 | 37;" }
compile() { "int a = 37 ^ 37;" }
compile() { "int a; a &= 37;" }
compile() { "int a; a |= 37;" }
compile() { "int a; a ^= 37;" }
compile() { "int a = 37 * 37;" }
compile() { "int a = 37 / 37;" }
compile() { "int a = 37 % 37;" }
compile() { "int a = 37 + 37;" }
compile() { "int a = 37 - 37;" }
compile() { "int a = 37 << 5;" }
compile() { "int a = 37 >> 5;" }
compile() { "int a = 37 >>> 5;" }
compile() { "int a; a *= 37;" }
compile() { "int a; a /= 37;" }
compile() { "int a; a %= 37;" }
compile() { "int a; a += 37;" }
compile() { "int a; a -= 37;" }
compile() { "int a; a <<= 5;" }
compile() { "int a; a >>= 5;" }
compile() { "int a; a >>>= 5;" }
compile() { "int b; boolean a = b == 37;" }
compile() { "int b; boolean a = b != 37;" }
compile() { "int b; boolean a = b < 37;" }
compile() { "int b; boolean a = b > 37;" }
compile() { "int b; boolean a = b <= 37;" }
compile() { "int b; boolean a = b >= 37;" }
compile() { "int b; boolean a = b <> 37;" }
compile() { "int b; boolean a = b !< 37;" }
compile() { "int b; boolean a = b !> 37;" }
compile() { "int b; boolean a = b !<= 37;" }
compile() { "int b; boolean a = b !>= 37;" }
compile() { "int b; boolean a = b !<> 37;" }
compile() { "int a; a = -a;" }
compile() { "int a; a = +a;" }
compile() { "int a; a = ~a;" }
compile() { "int a; a = --a;" }
compile() { "int a; a = ++a;" }
compile() { "int a; a = a--;" }
compile() { "int a; a = a++;" }

// The matrix of allowed operators for char operands:

compile() { "char b; char a = char(b & 37);" }
compile() { "char b; char a = char(b | 37);" }
compile() { "char b; char a = char(b ^ 37);" }
compile() { "char b; char a; a &= 37;" }
compile() { "char b; char a; a |= 37;" }
compile() { "char b; char a; a ^= 37;" }
compile() { "char b; char a = char(b * 37);" }
compile() { "char b; char a = char(b / 37);" }
compile() { "char b; char a = char(b % 37);" }
compile() { "char b; char a = char(b + 37);" }
compile() { "char b; char a = char(b - 37);" }
compile() { "char b; char a = b << 5;" }
compile() { "char b; char a = b >> 5;" }
compile() { "char b; char a = b >>> 5;" }
compile() { "char b; char a; a *= 37;" }
compile() { "char b; char a; a /= 37;" }
compile() { "char b; char a; a %= 37;" }
compile() { "char b; char a; a += 37;" }
compile() { "char b; char a; a -= 37;" }
compile() { "char b; char a; a <<= 5;" }
compile() { "char b; char a; a >>= 5;" }
compile() { "char b; char a; a >>>= 5;" }
compile() { "char b; boolean a = b == 37;" }
compile() { "char b; boolean a = b != 37;" }
compile() { "char b; boolean a = b < 37;" }
compile() { "char b; boolean a = b > 37;" }
compile() { "char b; boolean a = b <= 37;" }
compile() { "char b; boolean a = b >= 37;" }
compile() { "char b; boolean a = b <> 37;" }
compile() { "char b; boolean a = b !< 37;" }
compile() { "char b; boolean a = b !> 37;" }
compile() { "char b; boolean a = b !<= 37;" }
compile() { "char b; boolean a = b !>= 37;" }
compile() { "char b; boolean a = b !<> 37;" }
compile() { "char a; a = -a;" }
compile() { "char a; a = +a;" }
compile() { "char a; a = ~a;" }
compile() { "char a; a = --a;" }
compile() { "char a; a = ++a;" }
compile() { "char a; a = a--;" }
compile() { "char a; a = a++;" }

// The matrix of allowed operators for byte operands:

compile() { "byte b; byte a = byte(b & 37);" }
compile() { "byte b; byte a = byte(b | 37);" }
compile() { "byte b; byte a = byte(b ^ 37);" }
compile() { "byte b; byte a; a &= 37;" }
compile() { "byte b; byte a; a |= 37;" }
compile() { "byte b; byte a; a ^= 37;" }
compile() { "byte b; byte a = byte(b * 37);" }
compile() { "byte b; byte a = byte(b / 37);" }
compile() { "byte b; byte a = byte(b % 37);" }
compile() { "byte b; byte a = byte(b + 37);" }
compile() { "byte b; byte a = byte(b - 37);" }
compile() { "byte b; byte a = b << 5;" }
compile() { "byte b; byte a = b >> 5;" }
compile() { "byte b; byte a = b >>> 5;" }
compile() { "byte b; byte a; a *= 37;" }
compile() { "byte b; byte a; a /= 37;" }
compile() { "byte b; byte a; a %= 37;" }
compile() { "byte b; byte a; a += 37;" }
compile() { "byte b; byte a; a -= 37;" }
compile() { "byte b; byte a; a <<= 5;" }
compile() { "byte b; byte a; a >>= 5;" }
compile() { "byte b; byte a; a >>>= 5;" }
compile() { "byte b; boolean a = b == 37;" }
compile() { "byte b; boolean a = b != 37;" }
compile() { "byte b; boolean a = b < 37;" }
compile() { "byte b; boolean a = b > 37;" }
compile() { "byte b; boolean a = b <= 37;" }
compile() { "byte b; boolean a = b >= 37;" }
compile() { "byte b; boolean a = b <> 37;" }
compile() { "byte b; boolean a = b !< 37;" }
compile() { "byte b; boolean a = b !> 37;" }
compile() { "byte b; boolean a = b !<= 37;" }
compile() { "byte b; boolean a = b !>= 37;" }
compile() { "byte b; boolean a = b !<> 37;" }
compile() { "byte a; a = -a;" }
compile() { "byte a; a = +a;" }
compile() { "byte a; a = ~a;" }
compile() { "byte a; a = --a;" }
compile() { "byte a; a = ++a;" }
compile() { "byte a; a = a--;" }
compile() { "byte a; a = a++;" }

compile(expect: fail, message: NOT_BOOLEAN) { "long a; a = !a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "long a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "long a; a = *a;" }
compile(expect: fail, message: NOT_BOOLEAN) { "unsigned a; a = !a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "unsigned a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "unsigned a; a = *a;" }
compile(expect: fail, message: NOT_BOOLEAN) { "int a; a = !a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "int a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "int a; a = *a;" }
compile(expect: fail, message: NOT_BOOLEAN) { "char a; a = !a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "char a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "char a; a = *a;" }
compile(expect: fail, message: NOT_BOOLEAN) { "byte a; a = !a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "byte a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "byte a; a = *a;" }
compile(expect: fail, message: NOT_BOOLEAN) { "int a = 37 && 37;" }
compile(expect: fail, message: NOT_BOOLEAN) { "int a = 37 || 37;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = 37 <>= 37;" }
compile(expect: fail, message: INVALID_COMPARE) { "boolean a = 37 !<>= 37;" }
compile(expect: fail, message: INVALID_COMPARE) { "unsigned b, c; boolean a = b <>= c;" }
compile(expect: fail, message: INVALID_COMPARE) { "unsigned b, c; boolean a = b !<>= c;" }

// The matrix of allowed operators for boolean operands:

compile() { 'string a = "abc" + "abc";' }
compile() { 'string a; a += "abc";' }
compile() { 'boolean a = "abc" == "abc";' }
compile() { 'boolean a = "abc" != "abc";' }

compile(expect: fail, message: INVALID_AND) { 'string a = "abc" & "abc";' }
compile(expect: fail, message: INVALID_OR) { 'string a = "abc" | "abc";' }
compile(expect: fail, message: INVALID_XOR) { 'string a = "abc" ^ "abc";' }
compile(expect: fail, message: INVALID_AND) { 'string a; a &= "abc";' }
compile(expect: fail, message: INVALID_OR) { 'string a; a |= "abc";' }
compile(expect: fail, message: INVALID_XOR) { 'string a; a ^= "abc";' }
compile(expect: fail, message: NOT_BOOLEAN) { 'string a = "abc" && "abc";' }
compile(expect: fail, message: NOT_BOOLEAN) { 'string a = "abc" || "abc";' }
compile(expect: fail, message: INVALID_MULTIPLY) { 'string a = "abc" * "abc";' }
compile(expect: fail, message: INVALID_DIVIDE) { 'string a = "abc" / "abc";' }
compile(expect: fail, message: INVALID_REMAINDER) { 'string a = "abc" % "abc";' }
compile(expect: fail, message: INVALID_SUBTRACT) { 'string a = "abc" - "abc";' }
compile(expect: fail, message: LEFT_NOT_INT) { 'string a = "abc" << 5;' }
compile(expect: fail, message: LEFT_NOT_INT) { 'string a = "abc" >> 5;' }
compile(expect: fail, message: LEFT_NOT_INT) { 'string a = "abc" >>> 5;' }
compile(expect: fail, message: SHIFT_NOT_INT) { 'string a = 5 << "abc";' }
compile(expect: fail, message: SHIFT_NOT_INT) { 'string a = 5 >> "abc";' }
compile(expect: fail, message: SHIFT_NOT_INT) { 'string a = 5 >>> "abc";' }
compile(expect: fail, message: INVALID_MULTIPLY) { 'string a; a *= "abc";' }
compile(expect: fail, message: INVALID_DIVIDE) { 'string a; a /= "abc";' }
compile(expect: fail, message: INVALID_REMAINDER) { 'string a; a %= "abc";' }
compile(expect: fail, message: INVALID_SUBTRACT) { 'string a; a -= "abc";' }
compile(expect: fail, message: LEFT_NOT_INT) { 'string a; a <<= 5;' }
compile(expect: fail, message: LEFT_NOT_INT) { 'string a; a >>= 5;' }
compile(expect: fail, message: LEFT_NOT_INT) { 'string a; a >>>= 5;' }
compile(expect: fail, message: INVALID_COMPARE) { 'boolean a = "abc" <>= "abc";' }
compile(expect: fail, message: INVALID_COMPARE) { 'boolean a = "abc" !<>= "abc";' }

compile(expect: fail) { 'int... b;' }
compile(expect: fail) { 'int f() { return 5...; }' }
compile(expect: fail) { 'int x = 7...;' }

compile(expect: fail, message: UNEXPECTED_RC) { "switch (5) { case 3: }" }
compile(expect: fail, message: UNEXPECTED_RC) { "switch (5) { default: }" }

compile() { "ref<int> x = new int;" }

compile() { "enum a { A, B, C }; a x = a.B;" }

compile() { "class a { ~a() {} }" }

compile(expect: fail, message: NO_PARAMS_IN_DESTRUCTOR) { "class a { ~a(int b) {} }" }

compile() { "int, boolean f() { return 0, false; }" }

compile(expect: fail) { "int, boolean f() { return false, 0; }" }

compile(expect: fail) { "void foo(foo bar);" }

compile(expect: fail, message: DUPLICATE) { "int i, i;" }
compile() { ";" }
