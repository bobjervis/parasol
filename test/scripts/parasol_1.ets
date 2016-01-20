// Advanced library executions tests

run(filename: randomTests.p)
run(filename: linearRegressionTests.p)
run(filename: escapes.p)
run(filename: binarySearch.p)
run(filename: sort_test.p)
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
run(filename: utf8stream.p)
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

//run(filename: try_test.p)
run(filename: destructor_test.p)
run(filename: constructor_test.p)
run(filename: array_init.p)
run(filename: unicodeNumber.p)
run(filename: template_scope/template_scope.p, importPath: ^/test/src/template_scope)
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
run(filename: short_ops.p)
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
run(filename: class_alias.p)
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

run(filename: scanner_test.p, arguments: src/lib/x86_64.p)

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

compile() { "class a = int; a b; int c; b = c;" }

compile(){"pointer<int> ip; var v = ip;" }

compile(){"class Foo { public static Foo x(-1); Foo(int z){} }"}

compile(){"long i; string formatted(i);"}

// This is a regression where pointer<Foo> does not widen to ref<Foo> if Foo is a plain old class.
compile() { "class Foo{} ref<Foo[]> x; ref<Foo> y = &(*x)[0];" }

// This test checks a regression concering accepting ... arguments.
compile() { "class Bar { void f(int... args) { } } ref<Bar> x; x.f(4);" }

compile(expect: fail) { "ref<int> x = = new int();" }
compile(expect: fail, message: DUPLICATE) { "class Foo { private int f(int y) { return 0; } public int f(int z) { return z; } }" }
compile(expect: fail) { "void f() { for (int i = 0; i < 5); i++) printf("hello"); }" }

// This tests a regression involving bad code generation and also the ordering of an in-order traversal of
// the 'int a, b, c;' portion of the line.  The original failure involved not catching the missing parameter
// error and executing anyway.

compile(expect: fail, message: NO_MATCHING_OVERLOAD) { "void f(ref<int> y, int z, ref<int> w) {} int a, b, c; f(&a, &c);" }

compile() { "void f(int x(int z)){}" }
compile() { "void f(int x(int z)){} f(g.h); class g { static int h(int y) { return 0;} }" }

compile() { "class A { void f() { } } class B extends A { void g() { f(); } }" }

// regression: mis-spelled static trips up later code.
compile(expect: fail, message: SYNTAX_ERROR) { "class foo { public statc int, boolean parse(string text, int radix) { int value = 0; }}" }
// regression: passing a subscripted expression with class type as a function parameter 
compile() { "class Foo { int x; } pointer<Foo> y; int j; Foo z = f(y[j]); Foo f(Foo s) { return s; }" }

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

// From address

compile() { "address src; byte x; x = byte(src);" }
compile() { "address src; char x; x = char(src);" }
compile() { "address src; unsigned x; x = unsigned(src);" }
compile() { "address src; short x; x = short(src);" }
compile() { "address src; int x; x = int(src);" }
compile() { "address src; long x; x = long(src);" }
compile() { "address src; float x; x = float(src);" }
compile() { "address src; var x; x = src;" }
compile() { "address src; double x; x = double(src);" }
compile() { "address src; boolean x; x = boolean(src);" }
compile() { "address src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "address src; int x(double z); x = function int(double)(src);" }

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

compile() { "int β; β = 56;" }

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
