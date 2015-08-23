// Advanced library executions tests

run(filename: cmdLine_ops.p, exitCode: 7)
run(filename: cmdLine_ops.p, arguments: "x TEST-STRING-2")
run(filename: cmdLine_ops.p, arguments: "x anything-else", exitCode: 2)
run(filename: cmdLine_ops.p, arguments: "--bad-arg x", exitCode: 7)
run(filename: cmdLine_ops.p, arguments: "--help x", exitCode: 1)
run(filename: cmdLine_ops.p, arguments: "--aString=aaa aaa", exitCode: 4)
run(filename: cmdLine_ops.p, arguments: "--aString=aaa baa")
run(filename: cmdLine_ops.p, arguments: "--aBoolean --aString=aaa aaa")
run(filename: cmdLine_ops.p, arguments: "--aBoolean --aString=aaa baa", exitCode: 3)
run(filename: cmdLine_ops.p, arguments: "--aBoolean boolean-true-no-string-disallowed", exitCode: 5)
run(filename: cmdLine_ops.p, arguments: "--aBoolean boolean-true-no-string-allowed")
run(filename: cmdLine_ops.p, arguments: "boolean-false-no-string-disallowed", exitCode: 6)
run(filename: cmdLine_ops.p, arguments: "boolean-false-no-string-allowed")
run(filename: c_ops.p, exitCode: 1)
run(filename: string_ops.p)
run(filename: map_ops.p)
run(filename: time_ops.p)
run(filename: gen_header.p)
run(filename: abstract_call_test.p)
run(filename: class_ops.p)
run(filename: int_parse.p)
run(filename: byte_isdigit.p)
run(filename: map_iterator.p)
run(filename: split_ops.p)
run(filename: printf_1_ops.p, expectedOutput: "Hello world!\n"
											" Character is 'S'\n"
											"xyz\n")
run(filename: printf_2_ops.p, expectedOutput: "17 1\n")
run(filename: printf_3_ops.p, expectedOutput: "first second\n")
run(filename: printf_4_ops.p, expectedOutput: "1234abcdef\n")
run(filename: printf_5_ops.p, expectedOutput: "365")
run(filename: printf_6_ops.p, expectedOutput: "506\n")
run(filename: printf_7_ops.p)

// Regressions

run(filename: virtual_call_w_constructor.p)
run(filename: virtual_call_1.p)
run(filename: class_call_as_argument.p)
run(filename: inline_class_member.p)
run(filename: stack_arg_call.p)
run(filename: stack_arg_enum.p)
run(filename: stack_arg_dot.p)
run(filename: byte_to_enum.p)
run(filename: cond_needs_spills.p)
run(filename: complex_subscript.p)

// Basic runtime execution tests

run(filename: vectorization_1.p)
run(filename: vectorization_2.p)
run(filename: vectorization_3.p)
run(filename: call_lots_o_params.p)
run(filename: pre_decr_subscript.p)
run(filename: covariant_return_override.p)
run(filename: nested_enum.p)
run(filename: super_call.p)
run(filename: class_retn_init.p)
run(filename: class_meta_ops.p)
run(filename: vector_return.p)
run(filename: vector_lvalue_ops.p)
run(filename: constant_expr.p)
run(filename: overload_ops.p)
run(filename: shared_ns.p, importPath: ^/test/src/shared_ns)
run(filename: member_order.p)
run(filename: param_order.p)
run(filename: multi_return.p)
run(filename: var_ops.p)
run(filename: var_args.p)
run(filename: string_methods.p)
run(filename: string_compares.p)
run(filename: ternary.p)
run(filename: address_ops.p)
run(filename: double_ops.p)
run(filename: float_ops.p)
run(filename: long_ops.p)
run(filename: boolean_ops.p)
run(filename: byte_ops.p)
run(filename: char_ops.p)
run(filename: int_ops.p)
run(filename: unsigned_ops.p)
run(filename: enum_ops.p)
run(filename: private_enum_access.p)
run(filename: control_flow.p)
run(filename: call_args.p)
run(filename: coerce_ops.p)
run(filename: lib_ref.p, exitCode: 5)
run(filename: import_ops.p, importPath: ^/test/src/import_ops)
run(filename: ref_loop_import_ops.p, importPath: ^/test/src/ref_loop_import_ops)
run(filename: alloc_ops.p)
run(filename: vector_ops.p)
run(filename: func_arg.p)
run(filename: func_map_ops.p)
run(filename: func_obj_ops.p)
run(filename: map_class_ops.p)
run(filename: vector_class_ops.p)
run(filename: static_members.p)
run(filename: template_unused_method.p)
run(filename: template_ops.p)
run(filename: pointer_ops.p)
run(filename: hello.p)
run(filename: assert_false.p, expect: fail)
run(filename: assert_local_false.p, expect: fail)
run(filename: assert_true.p)
run(filename: assert_local_true.p)
run(filename: return_77.p, exitCode: 77)

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
compile() { "void stat(int x) {} void foo(long x); foo = function void(long)(stat);" }

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

// Casts

// From byte

compile() { "byte src; char x; x = src;" }
compile() { "byte src; unsigned x; x = src;" }
compile() { "byte src; short x; x = src;" }
compile() { "byte src; int x; x = src;" }
compile() { "byte src; long x; x = src;" }
compile() { "byte src; float x; x = src;" }
compile() { "byte src; double x; x = src;" }
compile() { "byte src; var x; x = src;" }
compile() { "byte src; address x; x = address(src);" }
compile() { "char src; boolean x; x = boolean(src);" }
compile() { "byte src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "byte src; int x(double z); x = function int(double)(src);" }

// From char

compile() { "char src; byte x; x = byte(src);" }
compile() { "char src; unsigned x; x = src;" }
compile() { "char src; short x; x = short(src);" }
compile() { "char src; int x; x = src;" }
compile() { "char src; long x; x = src;" }
compile() { "char src; float x; x = src;" }
compile() { "char src; double x; x = src;" }
compile() { "char src; var x; x = src;" }
compile() { "char src; address x; x = address(src);" }
compile() { "char src; boolean x; x = boolean(src);" }
compile() { "char src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "char src; int x(double z); x = function int(double)(src);" }

// From unsigned

compile() { "unsigned src; byte x; x = byte(src);" }
compile() { "unsigned src; char x; x = char(src);" }
compile() { "unsigned src; short x; x = short(src);" }
compile() { "unsigned src; int x; x = int(src);" }
compile() { "unsigned src; long x; x = src;" }
compile() { "unsigned src; float x; x = src;" }
compile() { "unsigned src; double x; x = src;" }
compile() { "unsigned src; var x; x = src;" }
compile() { "unsigned src; address x; x = address(src);" }
compile() { "unsigned src; boolean x; x = boolean(src);" }
compile() { "unsigned src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "unsigned src; int x(double z); x = function int(double)(src);" }

// From short

compile() { "short src; byte x; x = byte(src);" }
compile() { "short src; char x; x = char(src);" }
compile() { "short src; unsigned x; x = unsigned(src);" }
compile() { "short src; int x; x = src;" }
compile() { "short src; long x; x = src;" }
compile() { "short src; float x; x = src;" }
compile() { "short src; double x; x = src;" }
compile() { "short src; var x; x = src;" }
compile() { "short src; address x; x = address(src);" }
compile() { "short src; boolean x; x = boolean(src);" }
compile() { "short src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "short src; int x(double z); x = function int(double)(src);" }

// From int

compile() { "int src; byte x; x = byte(src);" }
compile() { "int src; char x; x = char(src);" }
compile() { "int src; unsigned x; x = unsigned(src);" }
compile() { "int src; int x; x = src;" }
compile() { "int src; long x; x = src;" }
compile() { "int src; float x; x = src;" }
compile() { "int src; double x; x = src;" }
compile() { "int src; var x; x = src;" }
compile() { "int src; address x; x = address(src);" }
compile() { "int src; boolean x; x = boolean(src);" }
compile() { "int src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "int src; int x(double z); x = function int(double)(src);" }

// From long

compile() { "long src; byte x; x = byte(src);" }
compile() { "long src; char x; x = char(src);" }
compile() { "long src; unsigned x; x = unsigned(src);" }
compile() { "long src; short x; x = short(src);" }
compile() { "long src; int x; x = int(src);" }
compile() { "long src; float x; x = src;" }
compile() { "long src; double x; x = src;" }
compile() { "long src; var x; x = src;" }
compile() { "long src; address x; x = address(src);" }
compile() { "long src; boolean x; x = boolean(src);" }
compile() { "long src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "long src; int x(double z); x = function int(double)(src);" }

// From float

compile() { "float src; byte x; x = byte(src);" }
compile() { "float src; char x; x = char(src);" }
compile() { "float src; unsigned x; x = unsigned(src);" }
compile() { "float src; short x; x = short(src);" }
compile() { "float src; int x; x = int(src);" }
compile() { "float src; long x; x = long(src);" }
compile() { "float src; double x; x = src;" }
compile() { "float src; var x; x = src;" }
compile() { "float src; address x; x = address(src);" }
compile() { "float src; boolean x; x = boolean(src);" }
compile() { "float src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "float src; int x(double z); x = function int(double)(src);" }

// From double

compile() { "double src; byte x; x = byte(src);" }
compile() { "double src; char x; x = char(src);" }
compile() { "double src; unsigned x; x = unsigned(src);" }
compile() { "double src; short x; x = short(src);" }
compile() { "double src; int x; x = int(src);" }
compile() { "double src; long x; x = long(src);" }
compile() { "double src; float x; x = float(src);" }
compile() { "double src; var x; x = src;" }
compile() { "double src; address x; x = address(src);" }
compile() { "double src; boolean x; x = boolean(src);" }
compile() { "double src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "double src; int x(double z); x = function int(double)(src);" }

// From boolean

compile() { "boolean src; byte x; x = byte(src);" }
compile() { "boolean src; char x; x = char(src);" }
compile() { "boolean src; unsigned x; x = unsigned(src);" }
compile() { "boolean src; short x; x = short(src);" }
compile() { "boolean src; int x; x = int(src);" }
compile() { "boolean src; long x; x = long(src);" }
compile() { "boolean src; float x; x = float(src);" }
compile() { "boolean src; double x; x = double(src);" }
compile() { "boolean src; var x; x = src;" }
compile() { "boolean src; address x; x = address(src);" }
compile() { "boolean src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "boolean src; int x(double z); x = function int(double)(src);" }

// From Foo

compile() { "enum Foo { A, B }; Foo src; byte x; x = byte(src);" }
compile() { "enum Foo { A, B }; Foo src; char x; x = char(src);" }
compile() { "enum Foo { A, B }; Foo src; unsigned x; x = unsigned(src);" }
compile() { "enum Foo { A, B }; Foo src; short x; x = short(src);" }
compile() { "enum Foo { A, B }; Foo src; int x; x = int(src);" }
compile() { "enum Foo { A, B }; Foo src; long x; x = long(src);" }
//compile() { "enum Foo { A, B }; Foo src; float x; x = float(src);" }
//compile() { "enum Foo { A, B }; Foo src; double x; x = double(src);" }
//compile() { "enum Foo { A, B }; Foo src; var x; x = src;" }
compile() { "enum Foo { A, B }; Foo src; address x; x = address(src);" }
compile() { "enum Foo { A, B }; Foo src; boolean x; x = boolean(src);" }
compile() { "enum Foo { A, B }; Foo src; int x(double z); x = function int(double)(src);" }

// From function int(double);

compile() { "int src(double z); byte x; x = byte(src);" }
compile() { "int src(double z); char x; x = char(src);" }
compile() { "int src(double Z); unsigned x; x = unsigned(src);" }
compile() { "int src(double z); short x; x = short(src);" }
compile() { "int src(double z); int x; x = int(src);" }
compile() { "int src(double z); long x; x = long(src);" }
compile() { "int src(double z); float x; x = float(src);" }
compile() { "int src(double z); double x; x = double(src);" }
//compile() { "int src(double z); var x; x = src;" }
compile() { "int src(double z); address x; x = address(src);" }
compile() { "int src(double z); boolean x; x = boolean(src);" }
compile() { "int src(double z); enum Foo { A, B }; Foo x; x = Foo(src);" }

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
// FOR NOw these are allowed again. Annotations need to be formalized at some point.
compile(xexpect: fail, xmessage: DISALLOWED_ANNOTATION) { "@Shape @Shape class foo {}" }
compile(xexpect: fail, xmessage: UNRECOGNIZED_ANNOTATION) { "@Sxp class foo {}" }

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
compile(expect: fail, message: NOT_NUMERIC) { "boolean a; a = --a;" }
compile(expect: fail, message: NOT_NUMERIC) { "boolean a; a = ++a;" }
compile(expect: fail, message: NOT_NUMERIC) { "boolean a; a = a--;" }
compile(expect: fail, message: NOT_NUMERIC) { "boolean a; a = a++;" }

compile(expect: fail) { "ref<int> x; if (x == 0) x = new int;" }

// The matrix of allowed operators for double operands:

compile(expect: fail, message: INVALID_AND) { "double b; double a = b & 37;" }
compile(expect: fail, message: INVALID_OR) { "double b; double a = b | 37;" }
compile(expect: fail, message: INVALID_XOR) { "double b; double a = b ^ 37;" }
compile(expect: fail, message: INVALID_AND) { "double b; double a; a &= 37;" }
compile(expect: fail, message: INVALID_OR) { "double b; double a; a |= 37;" }
compile(expect: fail, message: INVALID_XOR) { "double b; double a; a ^= 37;" }
compile() { "double b; double a = b * 37;" }
compile() { "double b; double a = b / 37;" }
compile(expect: fail, message: INVALID_REMAINDER) { "double b; double a = b % 37;" }
compile() { "double b; double a = b + 37;" }
compile() { "double b; double a = b - 37;" }
compile(expect: fail, message: LEFT_NOT_INT) { "double b; double a = b << 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "double b; double a = b >> 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "double b; double a = b >>> 5;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "double b; double a = 5 << b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "double b; double a = 5 >> b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "double b; double a = 5 >>> b;" }
compile() { "double b; double a; a *= 37;" }
compile() { "double b; double a; a /= 37;" }
compile(expect: fail, message: INVALID_REMAINDER) { "double b; double a; a %= 37;" }
compile() { "double b; double a; a += 37;" }
compile() { "double b; double a; a -= 37;" }
compile(expect: fail, message: LEFT_NOT_INT) { "double b; double a; a <<= 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "double b; double a; a >>= 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "double b; double a; a >>>= 5;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "double b; int a; a <<= b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "double b; int a; a >>= b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "double b; int a; a >>>= b;" }
compile() { "class C{} pointer<C> b, c; boolean a = b == c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b != c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b < c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b > c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b <= c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b >= c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b <> c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b !< c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b !> c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b !<= c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b !>= c;" }
compile() { "class C{} pointer<C> b, c; boolean a = b !<> c;" }
compile() { "double b; boolean a = b == 37;" }
compile() { "double b; boolean a = b != 37;" }
compile() { "double b; boolean a = b < 37;" }
compile() { "double b; boolean a = b > 37;" }
compile() { "double b; boolean a = b <= 37;" }
compile() { "double b; boolean a = b >= 37;" }
compile() { "double b; boolean a = b <> 37;" }
compile() { "double b; boolean a = b <>= 37;" }
compile() { "double b; boolean a = b !< 37;" }
compile() { "double b; boolean a = b !> 37;" }
compile() { "double b; boolean a = b !<= 37;" }
compile() { "double b; boolean a = b !>= 37;" }
compile() { "double b; boolean a = b !<> 37;" }
compile() { "double b; boolean a = b !<>= 37;" }
compile() { "double a; a = -a;" }
compile() { "double a; a = +a;" }
compile(expect: fail, message: INVALID_BIT_COMPLEMENT) { "double a; a = ~a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "double a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "double a; a = *a;" }
compile() { "double a; a = --a;" }
compile() { "double a; a = ++a;" }
compile() { "double a; a = a--;" }
compile() { "double a; a = a++;" }

// The matrix of allowed operators for float operands:

compile(expect: fail, message: INVALID_AND) { "float b; float a = b & 37;" }
compile(expect: fail, message: INVALID_OR) { "float b; float a = b | 37;" }
compile(expect: fail, message: INVALID_XOR) { "float b; float a = b ^ 37;" }
compile(expect: fail, message: INVALID_AND) { "float b; float a; a &= 37;" }
compile(expect: fail, message: INVALID_OR) { "float b; float a; a |= 37;" }
compile(expect: fail, message: INVALID_XOR) { "float b; float a; a ^= 37;" }
compile() { "float b; float a = b * 37;" }
compile() { "float b; float a = b / 37;" }
compile(expect: fail, message: INVALID_REMAINDER) { "float b; float a = b % 37;" }
compile() { "float b; float a = b + 37;" }
compile() { "float b; float a = b - 37;" }
compile(expect: fail, message: LEFT_NOT_INT) { "float b; float a = b << 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "float b; float a = b >> 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "float b; float a = b >>> 5;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "float b; float a = 5 << b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "float b; float a = 5 >> b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "float b; float a = 5 >>> b;" }
compile() { "float b; float a; a *= 37;" }
compile() { "float b; float a; a /= 37;" }
compile(expect: fail, message: INVALID_REMAINDER) { "float b; float a; a %= 37;" }
compile() { "float b; float a; a += 37;" }
compile() { "float b; float a; a -= 37;" }
compile(expect: fail, message: LEFT_NOT_INT) { "float b; float a; a <<= 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "float b; float a; a >>= 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "float b; float a; a >>>= 5;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "float b; int a; a <<= b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "float b; int a; a >>= b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "float b; int a; a >>>= b;" }
compile() { "float b; boolean a = b == 37;" }
compile() { "float b; boolean a = b != 37;" }
compile() { "float b; boolean a = b < 37;" }
compile() { "float b; boolean a = b > 37;" }
compile() { "float b; boolean a = b <= 37;" }
compile() { "float b; boolean a = b >= 37;" }
compile() { "float b; boolean a = b <> 37;" }
compile() { "float b; boolean a = b !< 37;" }
compile() { "float b; boolean a = b !> 37;" }
compile() { "float b; boolean a = b !<= 37;" }
compile() { "float b; boolean a = b !>= 37;" }
compile() { "float b; boolean a = b !<> 37;" }
compile() { "float a; a = -a;" }
compile() { "float a; a = +a;" }
compile(expect: fail, message: INVALID_BIT_COMPLEMENT) { "float a; a = ~a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "float a; a = &a;" }
compile(expect: fail, message: INVALID_INDIRECT) { "float a; a = *a;" }
compile() { "float a; a = --a;" }
compile() { "float a; a = ++a;" }
compile() { "float a; a = a--;" }
compile() { "float a; a = a++;" }

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

compile() { "class a { ~a() {} }" }

compile(expect: fail, message: NO_PARAMS_IN_DESTRUCTOR) { "class a { ~a(int b) {} }" }

compile() { "int, boolean f() { return 0, false; }" }

compile(expect: fail) { "int, boolean f() { return false, 0; }" }

compile(expect: fail) { "void foo(foo bar);" }

compile(expect: fail, message: DUPLICATE) { "int i, i;" }
compile() { ";" }

statement() { ; }
statement() { a; }
statement() { "{ }" }
statement() { "{ a; }" }
statement() { "{ a; a; }" }
statement() { break; }
statement() { case a: b; }
statement(expect: fail, message: UNEXPECTED_RC) { "case a: }" }
statement(expect: fail, message: UNEXPECTED_RC) { "default: }" }
statement() { continue; }
statement() { default: a; }
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
statement() { "final class q{a;b;}" }
statement() { "final class q{a;b;}" }
statement() { "class q{a;b;}" }
statement() { "class q extends a {}" }
statement() { "class q implements a {}" }
statement() { "class q extends a implements b {}" }
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
statement() { "enum a{b}" }
statement() { "enum a{b,c}" }
statement() { "enum a{b; int x;}" }
statement() { "@c enum a{b}" }
statement() { "@c enum a{b,c}" }
statement() { "@c enum a{b; int x;}" }
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
statement(expect: fail, message: UNEXPECTED_EOF) { default: }
statement(expect: fail, message: UNEXPECTED_EOF) { default: a }
statement(expect: fail) { default a; }
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
scan(keyword: for) { for }
scan(keyword: function) { function }
scan(keyword: if) { if }
scan(keyword: implements) { implements }
scan(keyword: import) { import }
scan(keyword: namespace) { namespace }
scan(keyword: new) { new }
scan(keyword: null) { null }
scan(keyword: private) { private }
scan(keyword: protected) { protected }
scan(keyword: public) { public }
scan(keyword: return) { return }
scan(keyword: static) { static }
scan(keyword: switch) { switch }
scan(keyword: this) { this }
scan(keyword: true) { true }
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
