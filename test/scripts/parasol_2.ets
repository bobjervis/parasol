
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

// The matrix of allowed operators for short operands:

compile() { "short a = short(37 & 37);" }
compile() { "short a = short(37 | 37);" }
compile() { "short a = short(37 ^ 37);" }
compile() { "short a; a &= 37;" }
compile() { "short a; a |= 37;" }
compile() { "short a; a ^= 37;" }
compile() { "short a = short(37 * 37);" }
compile() { "short a = short(37 / 37);" }
compile() { "short a = short(37 % 37);" }
compile() { "short a = short(37 + 37);" }
compile() { "short a = short(37 - 37);" }
compile() { "short a = short(37 << 5);" }
compile() { "short a = short(37 >> 5);" }
compile() { "short a = short(37 >>> 5);" }
compile() { "short a; a *= 37;" }
compile() { "short a; a /= 37;" }
compile() { "short a; a %= 37;" }
compile() { "short a; a += 37;" }
compile() { "short a; a -= 37;" }
compile() { "short a; a <<= 5;" }
compile() { "short a; a >>= 5;" }
compile() { "short a; a >>>= 5;" }
compile() { "short b; boolean a = b == 37;" }
compile() { "short b; boolean a = b != 37;" }
compile() { "short b; boolean a = b < 37;" }
compile() { "short b; boolean a = b > 37;" }
compile() { "short b; boolean a = b <= 37;" }
compile() { "short b; boolean a = b >= 37;" }
compile() { "short b; boolean a = b <> 37;" }
compile() { "short b; boolean a = b !< 37;" }
compile() { "short b; boolean a = b !> 37;" }
compile() { "short b; boolean a = b !<= 37;" }
compile() { "short b; boolean a = b !>= 37;" }
compile() { "short b; boolean a = b !<> 37;" }
compile() { "short a; a = -a;" }
compile() { "short a; a = +a;" }
compile() { "short a; a = ~a;" }
compile() { "short a; a = --a;" }
compile() { "short a; a = ++a;" }
compile() { "short a; a = a--;" }
compile() { "short a; a = a++;" }

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

compile(expect: fail, message: NOT_BOOLEAN) { "float a; a = !a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "float a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "float a; a = *a;" }
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

compile() { "int[] a = [ 1, 2, 3 ];" }
compile() { "int[string] b = [ \"a\": 4, \"b\": 17, \"c\": -23, ];" }
compile() { "enum E { A, B, C } string[E] x = [ B: \"abc\", \"def\" ];" }

compile(expect: fail) { "class C { C(int x) {} } C x;" }

compile() { "class C { int a, b, c; } C c = { a: 3, c: 7, b: -1 };" }

compile(expect: fail) { "int[string] b = [ \"a\": 4, 22: 17, \"c\": -23, ];" }
compile(expect: fail) { "enum E { A, B, C } string[E] x = [ B: \"abc\", \"def\", \"ghi\" ];" }
compile(expect: fail) { "enum E { A, B, C } string[E] x = [ B: \"abc\", A: \"def\", \"ghi\" ];" }
compile(expect: fail) { "enum E { A, B, C } string[E] x = [ D: \"abc\" ];" }
compile(expect: fail) { "int[string] b = [ \"a\": 4, 17, \"c\": -23, ];" }
compile(expect: fail) { "class C { int a, b, c; } C c = { 3, c: 7, b: -1 };" }
compile(expect: fail) { "class C { int a, b, c; } C c = { \"wrong\": 3, c: 7, b: -1 };" }

compile() { "class a { ~a() {} }" }

compile(expect: fail, message: NO_PARAMS_IN_DESTRUCTOR) { "class a { ~a(int b) {} }" }

compile() { "int, boolean f() { return 0, false; }" }

compile(expect: fail) { "int, boolean f() { return false, 0; }" }

compile(expect: fail) { "int, boolean f() { return 0, false; } int x; double y; (x, y) = f();" }

compile(expect: fail) { "void foo(foo bar);" }

compile(expect: fail, message: DUPLICATE) { "int i, i;" }
compile() { ";" }

statement() { ; }
statement() { a; }
statement() { "{ }" }
statement() { "{ a; }" }
statement() { "{ a; a; }" }
statement() { "lock { }" }
statement() { "lock { a; }" }
statement() { "lock { a; a; }" }
statement() { "lock (a) { }" }
statement() { "lock (a) { b; }" }
statement() { "lock (a) { b; b; }" }
statement() { "int f(double d) lock (a) { b; b; }" }
statement() { break; }
statement() { case a: b; }
statement(expect: fail, message: UNEXPECTED_RC) { "case a: }" }
statement(expect: fail, message: UNEXPECTED_RC) { "default: }" }
statement() { continue; }
statement() { default: a; }
statement() { "try x;" }
statement() { "try a; catch (E x) b;" }
statement() { "try a; catch (E x) b; catch (NE y) c;" }
statement() { "try x; finally y;" }
statement() { "try a; catch (E x) b; finally c;" }
statement() { "try a; catch (E x) b; catch (NE y) c; finally d;" }
statement() { "throw x;" }
statement() { "do a; while (b);" }
statement() { "for (a; b; c) d;" }
statement() { "for (; b; c) d;" }
statement() { "for (a;; c) d;" }
statement() { "for (a; b;) d;" }
statement() { "for (;; c) d;" }
statement() { "for (; b;) d;" }
statement() { "for (a;;) d;" }
statement() { "for (;;) d;" }
statement() { "for (a  b : c) d;" }
statement() { "if (a) b;" }
statement() { "if (a) b; else c;" }
statement() { "if (a) b; else if (c) d;" }
statement() { "if (a) if (b) c; else d; else e;" }
statement() { return; }
statement() { return a; }
statement() { "switch (a) b;" }
statement() { "while (a) b;" }
statement() { "@n switch (a) b;" }
statement() { "@n while (a) b;" }
statement() { "int main(string[] args){a;}" }
statement() { "int<64> x;" }
statement() { "abstract int x();" }
statement() { "class q<class T>{}" }
statement() { "class q{}" }
statement() { "class q{}" }
statement() { "public int x;" }
statement() { "protected int x;" }
statement() { "private int x;" }
statement() { "int x;" }
statement() { "@c public int x;" }
statement() { "@c protected int x;" }
statement() { "@c private int x;" }
statement() { "@c int x;" }
statement() { "final interface q{a;b;}" }
statement() { "interface q{a;b;}" }
statement() { "interface q extends a {}" }
statement() { "interface q;" }
statement() { "interface q = c;" }
statement() { "interface q = c<t>;" }
statement() { "@c interface q{}" }
statement() { "@c interface q extends a {}" }
statement() { "@c() interface q{}" }
statement() { "@c() interface q extends a {}" }
statement() { "@c(d) interface q{}" }
statement() { "@c(d) interface q extends a {}" }
statement() { "final class q{a;b;}" }
statement() { "final class q{a;b;}" }
statement() { "class q{a;b;}" }
statement() { "class q extends a {}" }
statement() { "class q implements a {}" }
statement() { "class q extends a implements b {}" }
statement() { "class q;" }
statement() { "class q = c;" }
statement() { "class q = c<t>;" }
statement() { "@c class q{}" }
statement() { "@c class q extends a {}" }
statement() { "@c class q implements a {}" }
statement() { "@c class q extends a implements b {}" }
statement() { "@c @d class q extends a implements b {}" }
statement() { "@c() class q{}" }
statement() { "@c() class q extends a {}" }
statement() { "@c() class q implements a {}" }
statement() { "@c() class q extends a implements b {}" }
statement() { "@c(d) class q{}" }
statement() { "@c(d) class q extends a {}" }
statement() { "@c(d) class q implements a {}" }
statement() { "@c(d) class q extends a implements b {}" }
statement() { "monitor a;" }
statement() { "monitor a { b; }" }
statement() { "monitor a { }" }
statement() { "flags a{b}" }
statement() { "flags a{b,}" }
statement() { "flags a{b,c}" }
statement() { "flags a{b,c,}" }
statement() { "enum a{b}" }
statement() { "enum a{b,}" }
statement() { "enum a{b,c}" }
statement() { "enum a{b,c,}" }
statement() { "enum a{b; int x;}" }
statement() { "enum a{b,; int x;}" }
statement() { "@c enum a{b}" }
statement() { "@c enum a{b,c}" }
statement() { "@c enum a{b; int x;}" }
statement() { "import x = z:y;" }
statement() { "import x = z:y.w;" }
statement() { "import z:y.w;" }
statement() { "namespace y:x;" }
statement() { "import x = z.b:y.a.w;" }
statement() { "import z.b:y.a.w;" }
statement() { "namespace y.b:x.a;" }
statement() { "namespace y.b.c.d.e:x.a;" }
statement() { "class a { static int x; }" }
statement() { "class a { private static int x; }" }

statement(expect: fail, message: NOT_EXPECTING_ELSE) { "else a;" }
statement(expect: recovered, message: EXPECTING_TERM) { "{ for (int i : array) ; return }" }
statement(expect: fail, message: UNEXPECTED_EOF) { a }
statement(expect: recovered, message: UNEXPECTED_EOF) { "{" }
statement(expect: fail, message: UNEXPECTED_RC) { "}" }
statement(expect: fail, message: BREAK_NO_SEMI) { break }
statement(expect: fail, message: EXPECTING_TERM) { case }
statement(expect: fail, message: CASE_NO_CO) { case a }
statement(expect: fail, message: UNEXPECTED_EOF) { case a: }
statement(expect: fail, message: UNEXPECTED_EOF) { case a: b }
statement(expect: fail, message: EXPECTING_TERM) { case : b; }
statement(expect: fail, message: CASE_NO_CO) { case a b; }
statement(expect: fail) { continue }
statement(expect: fail) { default }
statement(expect: recovered) { lock }
statement(expect: fail, message: UNEXPECTED_EOF) { default: }
statement(expect: fail, message: UNEXPECTED_EOF) { default: a }
statement(expect: fail) { default a; }
statement(expect: fail) { try }
statement(expect: fail) { "try a" }
statement(expect: fail) { "try a; catch" }
statement(expect: fail) { "try a; catch (" }
statement(expect: fail) { "try a; catch x" }
statement(expect: fail) { "try a; catch (E" }
statement(expect: fail) { "try a; catch (E)" }
statement(expect: fail) { "try a; catch (E x" }
statement(expect: fail) { "try a; catch (E x)" }
statement(expect: fail) { "try a; catch (E x) b" }
statement(expect: fail) { "try a; catch (E x) b; catch" }
statement(expect: fail) { "try a; catch (E x) b; catch (" }
statement(expect: fail) { "try a; catch (E x) b; catch (NE" }
statement(expect: fail) { "try a; catch (E x) b; catch (NE y" }
statement(expect: fail) { "try a; catch (E x) b; catch (NE y)" }
statement(expect: fail) { "try a; catch (E x) b; catch (NE y) c" }
statement(expect: fail) { "try a; finally" }
statement(expect: fail) { "try a; finally y" }
statement(expect: fail) { "try a; catch (E x) b; finally" }
statement(expect: fail) { "try a; catch (E x) b; finally c" }
statement(expect: fail) { "try a; catch (E x) b; catch (NE y) c; finally" }
statement(expect: fail) { "try a; catch (E x) b; catch (NE y) c; finally d" }
statement(expect: fail) { "throw" }
statement(expect: fail) { "throw x" }
statement(expect: fail) { do }
statement(expect: fail) { "do a" }
statement(expect: fail) { "do a;" }
statement(expect: fail) { "do a; while" }
statement(expect: fail) { "do a; while (" }
statement(expect: fail) { "do a; while (b" }
statement(expect: fail, message: DO_WHILE_NO_SEMI) { "do a; while (b)" }
statement(expect: fail) { "do a while (b);" }
statement(expect: fail) { "do a; (b);" }
statement(expect: fail) { "do a; while b);" }
statement(expect: fail) { "do a; while ();" }
statement(expect: fail) { "do a; while (b;" }
statement(expect: fail) { for }
statement(expect: fail) { "for (" }
statement(expect: fail) { "for (a" }
statement(expect: fail) { "for (a;" }
statement(expect: fail) { "for (a; b" }
statement(expect: fail) { "for (a; b;" }
statement(expect: fail) { "for (a; b; c" }
statement(expect: fail) { "for (a; b; c)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (a; b; c) d" }
statement(expect: fail) { "for a; b; c) d;" }
statement(expect: fail) { "for (a b; c) d;" }
statement(expect: fail) { "for (a; b c) d;" }
statement(expect: fail) { "for (a; b; c d;" }
statement(expect: fail) { "for (;" }
statement(expect: fail) { "for (; b" }
statement(expect: fail) { "for (; b;" }
statement(expect: fail) { "for (; b; c" }
statement(expect: fail) { "for (; b; c)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (; b; c) d" }
statement(expect: fail) { "for ; b; c) d;" }
statement(expect: fail) { "for (b; c) d;" }
statement(expect: fail) { "for (; b c) d;" }
statement(expect: fail) { "for (; b; c d;" }
statement(expect: fail) { "for (a;;" }
statement(expect: fail) { "for (a;; c" }
statement(expect: fail) { "for (a;; c)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (a;; c) d" }
statement(expect: fail) { "for (a;; c d;" }
statement(expect: fail) { "for (a; b;)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (a; b;) d" }
statement(expect: fail) { "for (;;" }
statement(expect: fail) { "for (;; c" }
statement(expect: fail) { "for (;; c)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (;; c) d" }
statement(expect: fail) { "for (; c) d;" }
statement(expect: fail) { "for (;; c d;" }
statement(expect: fail) { "for (; b;)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (; b;) d" }
statement(expect: fail) { "for (; b; d;" }
statement(expect: fail) { "for (a;;)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (a;;) d" }
statement(expect: fail) { "for (a;; d;" }
statement(expect: fail) { "for (;;)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (;;) d" }
statement(expect: fail) { "for (;) d;" }
statement(expect: fail) { "for (a  b" }
statement(expect: fail) { "for (a  b :" }
statement(expect: fail) { "for (a  b : c" }
statement(expect: fail) { "for (a  b : c)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "for (a  b : c) d" }
statement(expect: fail) { "for a  b : c) d;" }
statement(expect: fail) { "for (a  b c) d;" }
statement(expect: fail) { "for (a  b : c d;" }
statement(expect: fail) { if }
statement(expect: fail) { "if (" }
statement(expect: fail) { "if (a" }
statement(expect: fail) { "if (a)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "if (a) b" }
statement(expect: fail) { "if (a) b; else" }
statement(expect: fail, message: UNEXPECTED_EOF) { "if (a) b; else c" }
statement(expect: fail) { "if a) b; else c;" }
statement(expect: fail) { "if (a b; else c;" }
statement(expect: fail) { "if (a) b else c;" }
statement(expect: fail) { "else c;" }
statement(expect: fail) { return }
statement(expect: fail) { return a }
statement(expect: fail) { "switch" }
statement(expect: fail) { "switch (" }
statement(expect: fail) { "switch (a" }
statement(expect: fail) { "switch (a)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "switch (a) b" }
statement(expect: fail) { "switch a) b;" }
statement(expect: fail) { "switch (a b;" }
statement(expect: fail) { "while" }
statement(expect: fail) { "while (" }
statement(expect: fail) { "while (a" }
statement(expect: fail) { "while (a)" }
statement(expect: fail, message: UNEXPECTED_EOF) { "while (a) b" }
statement(expect: fail) { "while a) b;" }
statement(expect: fail) { "while (a b;" }
statement(expect: fail) { final }
statement(expect: fail) { abstract }
statement(expect: recovered) { "final interface q{a;b;" }
statement(expect: recovered) { "final interface q{a;b" }
statement(expect: recovered) { "final interface q{a;" }
statement(expect: recovered) { "final interface q{a" }
statement(expect: recovered) { "final interface q{" }
statement(expect: fail) { "final interface q" }
statement(expect: fail) { "final interface" }
statement(expect: recovered) { "interface q{a;b;" }
statement(expect: recovered) { "interface q{a;b" }
statement(expect: recovered) { "interface q{a;" }
statement(expect: recovered) { "interface q{a" }
statement(expect: recovered) { "interface q{" }
statement(expect: fail) { "interface q" }
statement(expect: fail) { "interface " }
statement(expect: recovered) { "interface q extends a {" }
statement(expect: fail) { "interface q implements a " }
statement(expect: fail) { "interface q extends a " }
statement(expect: fail) { "interface q extends b implements a " }
statement(expect: fail) { "interface q extends " }
statement(expect: fail) { "interface q = c" }
statement(expect: fail) { "interface q = " }
statement(expect: fail) { "interface q = c<t>" }
statement(expect: fail) { "interface q = c<t" }
statement(expect: fail) { "interface q = c<" }
statement(expect: recovered) { "@c interface q{" }
statement(expect: fail) { "@c interface q" }
statement(expect: fail) { "@c interface " }
statement(expect: recovered) { "@c interface q extends a {" }
statement(expect: fail) { "@c interface q extends a " }
statement(expect: fail) { "@c interface q extends " }
statement(expect: recovered) { "@c() interface q{" }
statement(expect: fail) { "@c() interface q" }
statement(expect: fail) { "@c() interface " }
statement(expect: recovered) { "@c() interface q extends a {" }
statement(expect: fail) { "@c() interface q extends a " }
statement(expect: fail) { "@c() interface q extends " }
statement(expect: fail) { class }
statement(expect: fail) { class q }
statement(expect: fail) { class extends }
statement(expect: fail) { class q extends }
statement(expect: fail) { "class extends {}" }
statement(expect: fail) { "class q extends {}" }
statement(expect: fail) { class extends a }
statement(expect: fail) { class q extends a }
statement(expect: fail) { "class extends a {" }
statement(expect: recovered) { "class q extends a {" }
statement(expect: fail) { class implements }
statement(expect: fail) { class q implements }
statement(expect: fail) { class implements a }
statement(expect: fail) { class q implements a }
statement(expect: fail) { "class implements a {" }
statement(expect: recovered) { "class q implements a {" }
statement(expect: fail) { class extends a implements }
statement(expect: fail) { class q extends a implements }
statement(expect: fail) { class extends a implements b }
statement(expect: fail) { class q extends a implements b }
statement(expect: fail) { "class extends a implements b {" }
statement(expect: recovered) { "class q extends a implements b {" }
statement(expect: fail) { "monitor" }
statement(expect: fail) { "monitor a" }
statement(expect: recovered) { "monitor a {" }
statement(expect: recovered) { "monitor a { b" }
statement(expect: recovered) { "monitor a { b;" }
statement(expect: fail) { "flags" }
statement(expect: fail) { "flags a" }
statement(expect: fail) { "flags {b}" }
statement(expect: fail) { "flags {}" }
statement(expect: recovered) { "flags a{" }
statement(expect: recovered) { "flags a{b" }
statement(expect: recovered) { "flags a{b," }
statement(expect: recovered) { "flags a{b,c" }
statement(expect: recovered) { "flags a{b c" }
statement(expect: fail) { "enum" }
statement(expect: fail) { "enum a" }
statement(expect: fail) { "enum {b}" }
statement(expect: fail) { "enum {}" }
statement(expect: recovered) { "enum a{" }
statement(expect: recovered) { "enum a{b" }
statement(expect: recovered) { "enum a{b," }
statement(expect: recovered) { "enum a{b,c" }
statement(expect: recovered) { "enum a{b c" }
statement(expect: fail) { "enum {b; x;}" }
statement(expect: recovered) { "enum a{b; x;" }
statement(expect: recovered) { "enum a{b; x" }
statement(expect: recovered) { "enum a{; x;}" }
statement(expect: recovered) { "enum a{b, c; x}" }
statement(expect: fail) { "int main(" }
statement(expect: fail) { "int main(a" }
statement(expect: fail) { "int main(a)" }
statement(expect: recovered) { "int main(a b) {" }
statement(expect: fail) { "int main(a," }
statement(expect: fail) { "int main(a b" }
statement(expect: fail) { "int main(a b)" }
statement(expect: recovered) { "int main(a b) {" }
statement(expect: fail) { "int main(a b," }
statement(expect: fail) { "int main(a b, c" }
statement(expect: fail) { "int main(a b, c d" }
statement(expect: fail) { "int main(a b, c d)" }
statement(expect: recovered) { "int main(a b, c d) {" }
statement(expect: fail) { @a }
statement(expect: fail) { "import a" }
statement(expect: fail) { "import a =" }
statement(expect: fail) { "import a = y" }
statement(expect: fail) { "import a = y(" }
statement(expect: fail) { "import a = y(z" }
statement(expect: fail) { "import a = y(z)" }
statement(expect: fail) { "import a = y(z)." }
statement(expect: fail) { "import a = y(z).w" }
statement(expect: fail) { "import y(" }
statement(expect: fail) { "import y(z" }
statement(expect: fail) { "import y(z)" }
statement(expect: fail) { "import y(z)." }
statement(expect: fail) { "import y(z).w" }
statement(expect: fail) { "namespace a" }
statement(expect: fail) { "namespace a(" }
statement(expect: fail) { "namespace a(y" }
statement(expect: fail) { "namespace a(y)" }
statement(expect: fail) { "import x = y." }
statement(expect: fail) { "import x = y.a" }
statement(expect: fail) { "import x = y.a(" }
statement(expect: fail) { "import x = y.a(z" }
statement(expect: fail) { "import x = y.a(z." }
statement(expect: fail) { "import x = y.a(z.b" }
statement(expect: fail) { "import x = y.a(z.b)" }
statement(expect: fail) { "import x = y.a(z.b)." }
statement(expect: fail) { "import x = y.a(z.b).w" }
statement(expect: fail) { "import y." }
statement(expect: fail) { "import y.a" }
statement(expect: fail) { "import y.a(" }
statement(expect: fail) { "import y.a(z" }
statement(expect: fail) { "import y.a(z." }
statement(expect: fail) { "import y.a(z.b" }
statement(expect: fail) { "import y.a(z.b)" }
statement(expect: fail) { "import y.a(z.b)." }
statement(expect: fail) { "import y.a(z.b).w" }
statement(expect: fail) { "namespace x." }
statement(expect: fail) { "namespace x.a" }
statement(expect: fail) { "namespace x.a(" }
statement(expect: fail) { "namespace x.a(y" }
statement(expect: fail) { "namespace x.a(y." }
statement(expect: fail) { "namespace x.a(y.b" }
statement(expect: fail) { "namespace x.a(y.b)" }
statement(expect: fail) { "namespace x.a(y.b." }
statement(expect: fail) { "namespace x.a(y.b.c" }
statement(expect: fail) { "namespace x.a(y.b.c." }
statement(expect: fail) { "namespace x.a(y.b.c.d" }
statement(expect: fail) { "namespace x.a(y.b.c.d." }
statement(expect: fail) { "namespace x.a(y.b.c.d.e" }
statement(expect: fail) { "namespace x.a(y.b.c.d.e)" }
statement(expect: recovered) { "class a { private static }" }
statement(expect: recovered) { "class a { private static int }" }
statement(expect: recovered) { "class a { private static int x }" }
statement(expect: recovered) { "class a { private static" }
statement(expect: recovered) { "class a { private static int" }
statement(expect: recovered) { "class a { private static int x" }

// Basic simple terms

expression() { a }
expression() { 1 }
expression() { 2.0 }
expression() { "'a'" }
expression() { '"a"' }
expression() { this }
expression() { super }
expression() { true }
expression() { false }
expression() { null }

// Class constant variations

expression() { "class{}" }
expression() { "class extends a {}" }
expression() { "class implements a {}" }
expression() { "class extends a implements b {}" }

expression(expect: fail, message: BAD_TOKEN) { class $ }

expression(expect: fail) { class }
expression(expect: fail) { class extends }
expression(expect: fail) { "class extends {}" }
expression(expect: fail) { class a }
expression(expect: fail) { "class a {}" }
expression(expect: fail) { class extends a }
expression(expect: fail) { "class extends a {" }
expression(expect: fail) { class implements }
expression(expect: fail) { class implements a }
expression(expect: fail) { "class implements a {" }
expression(expect: fail) { class extends a implements }
expression(expect: fail) { class extends a implements b }
expression(expect: fail) { "class extends a implements b {" }
expression(expect: fail) { @a }

// Aggregate initializers

expression() { "[ ]" }
expression() { "[ 1 ]" }
expression() { "[ 1, ]" }
expression() { "[ 1, 2 ]" }
expression() { "[ 1, 2, 3, 4 ]" }
expression() { "[ 1, 2, 3, 4, ]" }
expression() { "{ a: 1 }" }
expression() { "{ a: 1, }" }
expression() { "{ a: 1, b: 2 }" }
expression() { "[ a: 1, b: 2, c: 3, d: 4 ]" }
expression() { "[ a: 1, b: 2, c: 3, d: 4, ]" }
expression() { "{ a: 1, b: 2, c: 3, d: 4 }" }
expression() { "{ a: 1, b: 2, c: 3, d: 4, }" }

expression(expect: fail) { "[ " }
expression(expect: fail) { "[ 1" }
expression(expect: fail) { "[ 1," }
expression(expect: fail) { "[ 1, 2" }
expression(expect: fail) { "[ 1, 2, 3, 4," }
expression(expect: fail) { "{ a: 1 " }
expression(expect: fail) { "{ a: " }
expression(expect: fail) { "{ a" }
expression(expect: fail) { "{ a: 1, " }
expression(expect: fail) { "{ a: 1, b: 2 " }
expression(expect: fail) { "{ a: 1, b: " }
expression(expect: fail) { "{ a: 1, b" }
expression(expect: fail) { "[ a: 1, b: 2, c: 3, d: 4 " }
expression(expect: fail) { "[ a: 1, b: 2, c: 3, d: " }
expression(expect: fail) { "[ a: 1, b: 2, c: 3, d" }
expression(expect: fail) { "[ a: 1, b: 2, c: 3," }
expression(expect: fail) { "[ a: 1" }
expression(expect: fail) { "[ a: " }
expression(expect: fail) { "[ a: 1, b: 2, c: 3, d: 4, " }
expression(expect: fail) { "{ a: 1, b: 2, c: 3, d: 4, " }

// Unary operators

expression() { +a }
expression() { -a }
expression() { ~a }
expression() { !a }
expression() { &a }
expression() { *a }
expression() { ++a }
expression() { +=a }
expression() { --a }
expression() { new a }
expression() { delete a }

// Invalid unary operators

expression(expect: fail, message: EXPECTING_TERM) { ,a }
expression(expect: fail, message: EXPECTING_TERM) { /a }
expression(expect: fail, message: EXPECTING_TERM) { %a }
expression(expect: fail, message: EXPECTING_TERM) { |a }
expression(expect: fail, message: EXPECTING_TERM) { ^a }
expression(expect: fail, message: EXPECTING_TERM) { <<a }
expression(expect: fail, message: EXPECTING_TERM) { >>a }
expression(expect: fail, message: EXPECTING_TERM) { >>>a }
expression(expect: fail, message: EXPECTING_TERM) { ..a }
expression(expect: fail, message: EXPECTING_TERM) { =a }
expression(expect: fail, message: EXPECTING_TERM) { -=a }
expression(expect: fail, message: EXPECTING_TERM) { *=a }
expression(expect: fail, message: EXPECTING_TERM) { /=a }
expression(expect: fail, message: EXPECTING_TERM) { %=a }
expression(expect: fail, message: EXPECTING_TERM) { &=a }
expression(expect: fail, message: EXPECTING_TERM) { |=a }
expression(expect: fail, message: EXPECTING_TERM) { ^=a }
expression(expect: fail, message: EXPECTING_TERM) { <<=a }
expression(expect: fail, message: EXPECTING_TERM) { >>=a }
expression(expect: fail, message: EXPECTING_TERM) { >>>=a }

expression(expect: fail, message: EXPECTING_TERM) { ===a }
expression(expect: fail, message: EXPECTING_TERM) { ==a }
expression(expect: fail, message: EXPECTING_TERM) { <a }
expression(expect: fail, message: EXPECTING_TERM) { >a }
expression(expect: fail, message: EXPECTING_TERM) { <=a }
expression(expect: fail, message: EXPECTING_TERM) { >=a }
expression(expect: fail, message: EXPECTING_TERM) { <>a }
expression(expect: fail, message: EXPECTING_TERM) { <>=a }
expression(expect: fail, message: EXPECTING_TERM) { !=a }
expression(expect: fail, message: EXPECTING_TERM) { !==a }
expression(expect: fail, message: EXPECTING_TERM) { !<a }
expression(expect: fail, message: EXPECTING_TERM) { !>a }
expression(expect: fail, message: EXPECTING_TERM) { !<=a }
expression(expect: fail, message: EXPECTING_TERM) { !>=a }
expression(expect: fail, message: EXPECTING_TERM) { !<>a }
expression(expect: fail, message: EXPECTING_TERM) { !<>=a }

// Suffix operators

expression() { a++ }
expression() { a-- }
expression() { a.b }
expression() { a.bytes }
expression() { a[b] }
expression() { a[b] }
expression() { "a[b]{ c }" }
expression() { "a[b]{ c, d }" }
expression() { a[b:] }
expression() { a[b:c] }
expression() { "a()" }
expression() { "a(b)" }
expression() { "a(b c)" }
expression() { "a(b, c)" }
expression() { "a(b c, d)" }
expression() { "a(b c, d e)" }
expression() { "a(@n b)" }
expression() { "a(@n b c)" }
expression() { "a(b, @n c)" }
expression() { "a(@n(x) @m b c, d)" }
expression() { "a(b c, @n d e)" }
expression() { "a<b>" }
expression() { "function int (a b) {x;}" }
expression() { "function int (a) {a;}" }
expression() { "function int (a... b) {a;}" }
expression() { "function int (a b, c, d) {x;}" }
expression() { "function int (@n a b) {x;}" }
expression() { "function int (@n a) {a;}" }
expression() { "function int (a b, @n c, d) {x;}" }

expression(expect: fail) { ... }
expression(expect: fail) { a. }
expression(expect: fail) { .a }
expression(expect: fail) { bytes }
expression(expect: fail, message: EXPECTING_TERM) { a[ }
expression(expect: fail, message: EXPECTING_RS) { a[b }
expression(expect: fail) { "a[" }
expression(expect: fail) { "a[b" }
expression(expect: fail) { "a[b]{ " }
expression(expect: fail) { "a[b]{ c" }
expression(expect: fail) { "a[b]{ c, " }
expression(expect: fail) { "a[b]{ c, d" }
expression(expect: fail) { a[b: }
expression(expect: fail) { a[b:c }
expression(expect: fail) { "a<" }
expression(expect: fail) { "a<b" }
expression(expect: fail) { "function" }
expression(expect: fail) { "function {" }
expression(expect: fail) { "function int" }
expression(expect: fail) { "function int {" }
expression(expect: fail) { "function int (" }
expression(expect: fail) { "function int (a" }
expression(expect: fail) { "function int (@n" }
expression(expect: fail) { "function int (a b" }
expression(expect: fail) { "function int (@n a b" }
expression(expect: fail) { "function int (a b) {" }
expression(expect: fail) { "function int (a) {" }
expression(expect: fail) { "function int (a b," }
expression(expect: fail) { "function int (a b, c" }
expression(expect: fail) { "function int (a b, @n c" }
expression(expect: fail) { "function int (a b, c," }
expression(expect: fail) { "function int (a b, c, d) {" }
expression(expect: fail) { "function +int {}" }
expression(expect: fail, message: EXPECTING_TERM) { @n a }

// Invalid suffix operators

expression(expect: fail, message: EXPECTING_TERM) { a, }
expression(expect: fail, message: EXPECTING_TERM) { a+ }
expression(expect: fail, message: EXPECTING_TERM) { a- }
expression(expect: fail, message: EXPECTING_TERM) { a* }
expression(expect: fail, message: EXPECTING_TERM) { a/ }
expression(expect: fail, message: EXPECTING_TERM) { a% }
expression(expect: fail, message: EXPECTING_TERM) { a& }
expression(expect: fail, message: EXPECTING_TERM) { a| }
expression(expect: fail, message: EXPECTING_TERM) { a^ }
expression(expect: fail, message: EXPECTING_TERM) { a<< }
expression(expect: fail, message: EXPECTING_TERM) { a >> }
expression(expect: fail, message: EXPECTING_TERM) { a >>> }
expression(expect: fail, message: EXPECTING_TERM) { a.. }
expression(expect: fail, message: EXPECTING_TERM) { a= }
expression(expect: fail, message: EXPECTING_TERM) { a+= }
expression(expect: fail, message: EXPECTING_TERM) { a-= }
expression(expect: fail, message: EXPECTING_TERM) { a*= }
expression(expect: fail, message: EXPECTING_TERM) { a/= }
expression(expect: fail, message: EXPECTING_TERM) { a%= }
expression(expect: fail, message: EXPECTING_TERM) { a&= }
expression(expect: fail, message: EXPECTING_TERM) { a|= }
expression(expect: fail, message: EXPECTING_TERM) { a^= }
expression(expect: fail, message: EXPECTING_TERM) { a<<= }
expression(expect: fail, message: EXPECTING_TERM) { a >>= }
expression(expect: fail, message: EXPECTING_TERM) { a >>>= }

expression(expect: fail, message: EXPECTING_TERM) { a=== }
expression(expect: fail, message: EXPECTING_TERM) { a== }
expression(expect: fail, message: EXPECTING_TERM) { a< }
expression(expect: fail, message: EXPECTING_TERM) { a > }
expression(expect: fail, message: EXPECTING_TERM) { a<= }
expression(expect: fail, message: EXPECTING_TERM) { a>= }
expression(expect: fail, message: EXPECTING_TERM) { a<> }
expression(expect: fail, message: EXPECTING_TERM) { a<>= }
expression(expect: fail, message: EXPECTING_TERM) { a!= }
expression(expect: fail, message: EXPECTING_TERM) { a!== }
expression(expect: fail, message: EXPECTING_TERM) { a!< }
expression(expect: fail, message: EXPECTING_TERM) { a!> }
expression(expect: fail, message: EXPECTING_TERM) { a!<= }
expression(expect: fail, message: EXPECTING_TERM) { a!>= }
expression(expect: fail, message: EXPECTING_TERM) { a!<> }
expression(expect: fail, message: EXPECTING_TERM) { a!<>= }

expression(expect: fail, message: EXPECTING_TERM) { a new }
expression(expect: fail, message: EXPECTING_TERM) { a delete }

// Parentheses 

expression() { "(a)" }

// Binary operators

expression() { a , b }
expression() { a + b }
expression() { a - b }
expression() { a * b }
expression() { a / b }
expression() { a % b }
expression() { a & b }
expression() { a | b }
expression() { a ^ b }
expression() { a << b }
expression() { a >> b }
expression() { a >>> b }
expression() { a .. b }
expression() { a = b }
expression() { a += b }
expression() { a -= b }
expression() { a *= b }
expression() { a /= b }
expression() { a %= b }
expression() { a &= b }
expression() { a |= b }
expression() { a ^= b }
expression() { a <<= b }
expression() { a >>= b }
expression() { a >>>= b }

expression() { a === b }
expression() { a == b }
expression() { a < b }
expression() { a > b }
expression() { a <= b }
expression() { a >= b }
expression() { a <> b }
expression() { a <>= b }
expression() { a != b }
expression() { a !== b }
expression() { a !< b }
expression() { a !> b }
expression() { a !<= b }
expression() { a !>= b }
expression() { a !<> b }
expression() { a !<>= b }

expression() { a new b || c }
expression() { a delete b }
expression() { "new (a) b || c" }
expression(expect: fail) { "x new (a) b || c" }

// Invalid binary operators: the parses do not consume all tokens,
// but otherwise report no error messages

expression(expect: fail) { a ~ b }
expression(expect: fail) { a ++ b }
expression(expect: fail) { a -- b }
expression(expect: fail) { a : b }

// Ternary conditional operator

expression() { a ? b : c }
expression() { a ? b + c : d }

// Verify that comments get stripped and we have 3 identifier tokens.
scan(tokens: 3) {
"	// Hello world
	a b c"
}

scan (tokens: 1) {
0x123456789abcdef
}
// The g should start a second, identifier token
scan (tokens: 2) {
0x123456789abcdefg
}
// There must be an exponent after the e
scan (expect: fail) { 1.0e }
scan (expect: fail) { 0x }

scan(tokens: 1) {
0x0e
}

scan(tokens: 0) {
}
scan(tokens:0) { "// Just a line comment" }
scan(tokens:0) { "/* Just a block comment /* with nesting */ */   " }

	// Various identifier tokens
	
scan(tokens: 1, value:"abc"){ abc }
scan(tokens: 1, value:"Abc"){ Abc }
scan(tokens: 1, value:"aBc"){ aBc }
scan(tokens: 1, value:"β") { β }
scan(tokens: 1, value:"a123"){ a123 }
scan(tokens: 1, value:"_"){ _ }
scan(tokens: 1, value:"a_"){ a_ }
scan(tokens: 1, value:"a"){ `a` }
scan(tokens: 1, value:"1"){ `1` }
scan(tokens: 1, value:"%r$"){ `%r$` }

	// Various integer tokens

scan(tokens: 1, value:"123"){ 123 }
scan(tokens: 1, value:"0"){ 0 }
scan(tokens: 1, value:"0x0"){ 0x0 }
scan(tokens: 1, value:"0x0abcef"){ 0x0abcef }
scan(tokens: 1, value:"23۷5"){ 23۷5 }

	// Various floating point tokens

scan(tokens: 1, value:"123.0"){ 123.0 }
scan(tokens: 1, value:"123.0f"){ 123.0f }
scan(tokens: 1, value:"123.0e+34"){ 123.0e+34 }
scan(tokens: 3){ e+34 }		// Not a number, identifier e, + and integer 34 tokens
scan(tokens: 1, value:".123"){ .123 }
scan(tokens: 1, value:".0"){ .0 }
scan(tokens: 1, value:"0."){ 0. }

	// Various character tokens

scan(tokens: 1, value:"a") { "'a'"}
scan(tokens: 1, value:"\\0") { "'\\0'" }
scan(tokens: 1, value:"\\a") { "'\\a'" }
scan(tokens: 1, value:"\\b") { "'\\b'" }
scan(tokens: 1, value:"\\f") { "'\\f'" }
scan(tokens: 1, value:"\\n") { "'\\n'" }
scan(tokens: 1, value:"\\r") { "'\\r'" }
scan(tokens: 1, value:"\\t") { "'\\t'" }
scan(tokens: 1, value:"\\v") { "'\\v'" }
scan(tokens: 1, value:"\\u123f") { "'\\u123f'" }
scan(tokens: 1, value:"\\x23") { "'\\x23'" }
scan(tokens: 1, value:"\\'") { "'\\''" }
scan(tokens: 1, value:"\\\"") { "'\\\"'" }
scan(tokens: 1, value:"\"") { "'\"'" }

	// Various string tokens

scan(tokens: 1, value:"a") { '"a"' }
scan(tokens: 1, value:"\\0") { '"\\0"' }
scan(tokens: 1, value:"\\a") { '"\\a"' }
scan(tokens: 1, value:"\\b") { '"\\b"' }
scan(tokens: 1, value:"\\f") { '"\\f"' }
scan(tokens: 1, value:"\\n") { '"\\n"' }
scan(tokens: 1, value:"\\r") { '"\\r"' }
scan(tokens: 1, value:"\\t") { '"\\t"' }
scan(tokens: 1, value:"\\v") { '"\\v"' }
scan(tokens: 1, value:"\\u123f") { '"\\u123f"' }
scan(tokens: 1, value:"\\x23") { '"\\x23"' }
scan(tokens: 1, value:"\\'") { '"\\\'"' }
scan(tokens: 1, value:"\\\"") { '"\\\""' }
scan(tokens: 1, value:"\'") { '"\'"' }
scan(tokens: 1, value:"ab") { '"a\\\nb"' }
scan(tokens: 1, value:"ab") { '"a\\\r\nb"' }

	// Various annotations
	
scan(tokens: 1, value:"annotation"){ @annotation }
scan(tokens: 1, value:"a123"){ @a123 }
scan(tokens: 1, value:"_"){ @_ }

scan(tokens: 1){ ; }
scan(tokens: 1){ : }
scan(tokens: 1){ . }
scan(tokens: 1){ .. }
scan(tokens: 1){ ... }
scan(tokens: 1){ "(" }
scan(tokens: 1){ ")" }
scan(tokens: 1){ "{" }
scan(tokens: 1){ "}" }
scan(tokens: 1){ "[" }
scan(tokens: 1){ "]" }
scan(tokens: 1){ "<" }
scan(tokens: 1){ ">" }
scan(tokens: 1){ , }
scan(tokens: 1){ / }
scan(tokens: 1){ % }
scan(tokens: 1){ * }
scan(tokens: 1){ + }
scan(tokens: 1){ - }
scan(tokens: 1){ & }
scan(tokens: 1){ ^ }
scan(tokens: 1){ | }
scan(tokens: 1){ ! }
scan(tokens: 1){ = }
scan(tokens: 1){ ? }
scan(tokens: 1){ ~ }
scan(tokens: 1){ /= }
scan(tokens: 1){ %= }
scan(tokens: 1){ *= }
scan(tokens: 1){ += }
scan(tokens: 1){ -= }
scan(tokens: 1){ &= }
scan(tokens: 1){ ^= }
scan(tokens: 1){ |= }
scan(tokens: 1){ == }
scan(tokens: 1){ === }
scan(tokens: 1){ <= }
scan(tokens: 1){ >= }
scan(tokens: 1){ <> }
scan(tokens: 1){ <>= }
scan(tokens: 1){ != }
scan(tokens: 1){ !== }
scan(tokens: 1){ !< }
scan(tokens: 1){ !> }
scan(tokens: 1){ !<= }
scan(tokens: 1){ !>= }
scan(tokens: 1){ !<> }
scan(tokens: 1){ !<>= }
scan(tokens: 1){ << }
scan(tokens: 1){ " >>" }
scan(tokens: 1){ " >>>" }
scan(tokens: 2){ >> }
scan(tokens: 3){ >>> }
scan(tokens: 1){ <<= }
scan(tokens: 1){ <<= }
scan(tokens: 1){ " >>=" }
scan(tokens: 1){ " >>>=" }
scan(tokens: 2){ >>= }
scan(tokens: 3){ >>>= }
scan(tokens: 1){ && }
scan(tokens: 1){ || }
scan(tokens: 1){ ++ }
scan(tokens: 1){ -- }

scan(keyword: abstract) { abstract }
scan(keyword: break) { break }
scan(keyword: bytes) { bytes }
scan(keyword: case) { case }
scan(keyword: catch) { catch }
scan(keyword: class) { class }
scan(keyword: continue) { continue }
scan(keyword: default) { default }
scan(keyword: delete) { delete }
scan(keyword: do) { do }
scan(keyword: else) { else }
scan(keyword: enum) { enum }
scan(keyword: extends) { extends }
scan(keyword: false) { false }
scan(keyword: final) { final }
scan(keyword: finally) { finally }
scan(keyword: flags) { flags }
scan(keyword: for) { for }
scan(keyword: function) { function }
scan(keyword: if) { if }
scan(keyword: implements) { implements }
scan(keyword: import) { import }
scan(keyword: interface) { interface }
scan(keyword: lock) { lock }
scan(keyword: monitor) { monitor }
scan(keyword: namespace) { namespace }
scan(keyword: new) { new }
scan(keyword: null) { null }
scan(keyword: private) { private }
scan(keyword: protected) { protected }
scan(keyword: public) { public }
scan(keyword: return) { return }
scan(keyword: static) { static }
scan(keyword: super) { super }
scan(keyword: switch) { switch }
scan(keyword: this) { this }
scan(keyword: throw) { throw }
scan(keyword: true) { true }
scan(keyword: try) { try }
scan(keyword: while) { while }

scan(expect:fail, character:0)
scan(expect:fail, character:1)
scan(expect:fail, character:2)
scan(expect:fail, character:3)
scan(expect:fail, character:4)
scan(expect:fail, character:5)
scan(expect:fail, character:6)
scan(expect:fail, character:7)
scan(expect:fail, character:8)
scan(expect:fail, character:11)
scan(expect:fail, character:14)
scan(expect:fail, character:15)
scan(expect:fail, character:16)
scan(expect:fail, character:17)
scan(expect:fail, character:18)
scan(expect:fail, character:19)
scan(expect:fail, character:20)
scan(expect:fail, character:21)
scan(expect:fail, character:22)
scan(expect:fail, character:23)
scan(expect:fail, character:24)
scan(expect:fail, character:25)
scan(expect:fail, character:26)
scan(expect:fail, character:27)
scan(expect:fail, character:28)
scan(expect:fail, character:29)
scan(expect:fail, character:30)
scan(expect:fail, character:31)
scan(expect:fail) { '#' }
scan(expect:fail) { '$' }
scan(expect:fail) { '\\' }
scan(expect:fail, character:127)
scan(expect:fail, character:128)
scan(expect:fail, character:708)
scan(expect:fail, character:1644)


codePoint(value:03) { "\x03" }
codePoint(value:20) { " " }
codePoint(value:35) { "5" }
codePoint(value:80) { "\xc2\x80" }
codePoint(value:373) { "\xcd\xb3" }
codePoint(value:2136) { "\xe2\x84\xb6" }
codePoint(value:aa7a) { "\xea\xa9\xba" }
codePoint(value:10a7c) { "\xf0\x90\xa9\xbc" } // old south arabain letter theth
codePoint(value:2fa1d) { "\xf0\xaf\xa8\x9d" } // CJK COMPATIBILITY IDEOGRAPH-2FA1D
codePoint(value:7fffffff) { "\xff" }
codePoint(value:7fffffff) { "\xaf" }
codePoint(value:'7fffffff,7fffffff') { "\xf0\xf0" }
codePoint(value:'7fffffff,40') { "\xf0\x40" }

