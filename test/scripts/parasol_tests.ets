// Platform specific tests
conditional(target: x86-64-win) {
    run(filename: win_ui_test.p)
	compile(expect: fail, message: BAD_WINDOWS_BINDING) { "@Windows abstract void foo(); foo();" }
	compile(expect: fail, message: BAD_WINDOWS_BINDING) { "@Windows("a") abstract void foo(); foo();" }
	compile(expect: fail, message: BAD_WINDOWS_BINDING) { "@Windows("a", "b", "c") abstract void foo(); foo();" }
}
conditional(target: x86-64-lnx) {
	compile(expect: fail, message: BAD_LINUX_BINDING) { "@Linux abstract void foo(); foo();" }
	compile(expect: fail, message: BAD_LINUX_BINDING) { "@Linux("a") abstract void foo(); foo();" }
	compile(expect: fail, message: BAD_LINUX_BINDING) { "@Linux("a", "b", "c") abstract void foo(); foo();" }
}
// Advanced library executions tests

run(filename: compile_target_test.p)
//run(filename: httpd_test.p)
run(filename: json_test.p)
run(filename: json_checker.p, arguments: "test/data/json/pass1.json")
run(filename: json_checker.p, arguments: "test/data/json/pass2.json")
run(filename: json_checker.p, arguments: "test/data/json/pass3.json")
run(filename: json_checker.p, arguments: "test/data/json/fail1.json")
run(filename: json_checker.p, arguments: "test/data/json/fail2.json")
run(filename: json_checker.p, arguments: "test/data/json/fail3.json")
run(filename: json_checker.p, arguments: "test/data/json/fail4.json")
run(filename: json_checker.p, arguments: "test/data/json/fail5.json")
run(filename: json_checker.p, arguments: "test/data/json/fail6.json")
run(filename: json_checker.p, arguments: "test/data/json/fail7.json")
run(filename: json_checker.p, arguments: "test/data/json/fail8.json")
run(filename: json_checker.p, arguments: "test/data/json/fail9.json")
run(filename: json_checker.p, arguments: "test/data/json/fail10.json")
run(filename: json_checker.p, arguments: "test/data/json/fail11.json")
run(filename: json_checker.p, arguments: "test/data/json/fail12.json")
run(filename: json_checker.p, arguments: "test/data/json/fail13.json")
run(filename: json_checker.p, arguments: "test/data/json/fail14.json")
run(filename: json_checker.p, arguments: "test/data/json/fail15.json")
run(filename: json_checker.p, arguments: "test/data/json/fail16.json")
run(filename: json_checker.p, arguments: "test/data/json/fail17.json")
run(filename: json_checker.p, arguments: "test/data/json/fail18.json")
run(filename: json_checker.p, arguments: "test/data/json/fail19.json")
run(filename: json_checker.p, arguments: "test/data/json/fail20.json")
run(filename: json_checker.p, arguments: "test/data/json/fail21.json")
run(filename: json_checker.p, arguments: "test/data/json/fail22.json")
run(filename: json_checker.p, arguments: "test/data/json/fail23.json")
run(filename: json_checker.p, arguments: "test/data/json/fail24.json")
run(filename: json_checker.p, arguments: "test/data/json/fail25.json")
run(filename: json_checker.p, arguments: "test/data/json/fail26.json")
run(filename: json_checker.p, arguments: "test/data/json/fail27.json")
run(filename: json_checker.p, arguments: "test/data/json/fail28.json")
run(filename: json_checker.p, arguments: "test/data/json/fail29.json")
run(filename: json_checker.p, arguments: "test/data/json/fail30.json")
run(filename: json_checker.p, arguments: "test/data/json/fail31.json")
run(filename: json_checker.p, arguments: "test/data/json/fail32.json")
run(filename: json_checker.p, arguments: "test/data/json/fail33.json")
run(filename: sha1test.p)
run(filename: base64test.p)
run(filename: math_test_1.p)
run(filename: threadpool_test.p)
run(filename: thread_test.p)
run(filename: randomTests.p)
run(filename: linearRegressionTests.p)
run(filename: escapes.p)
run(filename: queue_test.p)
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
run(filename: string_cons_add_test.p)
run(filename: map_ops.p)
run(filename: time_ops.p)
run(filename: gen_header.p)
run(filename: abstract_call_test.p)
run(filename: class_ops.p)
run(filename: class_of_element_test.p)
run(filename: enum_return_test.p)
run(filename: int_parse.p)
run(filename: byte_isdigit.p)
run(filename: map_iterator.p)
run(filename: map_class_index.p)
run(filename: set_test.p)
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

run(filename: memory_test.p)

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
run(filename: class_name_test.p)
run(filename: loop_fallthrough_test.p)

// Basic runtime execution tests

run(filename: interface_test_1.p)
run(filename: interface_test_2.p)
run(filename: monitor_test_1.p)
run(filename: monitor_test_2.p)
run(filename: monitor_test_3.p)
run(filename: monitor_test_4.p)
run(filename: monitor_test_5.p)
run(filename: monitor_test_6.p)
run(filename: monitor_test_7.p)
run(filename: monitor_test_8.p)
run(filename: monitor_test_9.p)
run(filename: monitor_test_10.p)
run(filename: placement_delete_test.p)
run(filename: vector_elem_constructor_test.p)
run(filename: placement_new_test.p)
run(filename: try_test.p)
run(filename: finally_test.p)
run(filename: function_parameter_test.p)
run(filename: sort_bug.p)
run(filename: destructor_test.p)
run(filename: destructor_virtual_test.p)
run(filename: default_constructor_test.p)
run(filename: constructor_test.p)
run(filename: constant_int_test.p)
run(filename: array_init.p)
run(filename: long_array_init.p)
run(filename: unicodeNumber.p)
run(filename: template_scope/template_scope.p, importPath: ^/test/src/template_scope)
run(filename: vectorization_1.p)
run(filename: vectorization_2.p)
run(filename: vectorization_3.p)
run(filename: call_lots_o_params.p)
run(filename: pre_decr_subscript.p)
run(filename: covariant_return_override.p)
run(filename: nested_enum.p)
run(filename: static_method_call.p)
run(filename: super_call.p)
run(filename: inherited_constructor.p)
run(filename: nested_private_method.p)
run(filename: class_nested_vtable.p)
run(filename: class_retn_init.p)
run(filename: flags_ops.p)
run(filename: class_meta_ops.p)
run(filename: vector_byte.p)
run(filename: vector_return.p)
run(filename: vector_lvalue_ops.p)
run(filename: type_compares.p)
run(filename: constant_expr.p)
run(filename: overload_ops.p)
run(filename: shared_ns.p, importPath: ^/test/src/shared_ns)
run(filename: member_order.p)
run(filename: param_order.p)
run(filename: multi_return.p)
run(filename: var_ops.p)
run(filename: var_args_1.p)
run(filename: var_args_2.p)
run(filename: string_methods.p)
run(filename: string_compares.p)
run(filename: string_switch_test.p)
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

compile(filename: undefined_parameter_test.p, expect: fail, message: UNDEFINED)
compile(filename: syntax_error.p, expect: fail, message: DO_WHILE_NO_SEMI)
compile(filename: undef_type.p, expect: fail, message: UNDEFINED)
compile(filename: undef_init.p, expect: fail, message: UNDEFINED)
compile(filename: void_return_fail.p, expect: fail, message: RETURN_VALUE_DISALLOWED)
compile(filename: int_return_fail.p, expect: fail, message: RETURN_VALUE_REQUIRED)
compile(filename: unit_return_fail.p, expect: fail, message: RETURN_DISALLOWED)
compile(filename: unit_return_fail2.p, expect: fail, message: RETURN_DISALLOWED)

compile(filename: stray_token_enum.p, expect: fail)

compile(){ "int(address) func; void(address) f = void(address)(func);" }

compile() { "class a = int; a b; int c; b = c;" }

compile(){"pointer<int> ip; var v = ip;" }

compile(){"class Foo { public static Foo x(-1); Foo(int z){} }"}

compile(){"long i; string formatted(i);"}

// This is a regression where pointer<Foo> does not widen to ref<Foo> if Foo is a plain old class.
compile() { "class Foo{} ref<Foo[]> x; ref<Foo> y = &(*x)[0];" }

// This test checks a regression concering accepting ... arguments.
compile() { "class Bar { void f(int... args) { } } ref<Bar> x; x.f(4);" }

compile(expect: fail) { "ref<int> x = = new int();" }
compile(expect: fail) { "ref<int> a = int new int;" }
compile(expect: fail) { "class A { A(int b){} } ref<A> a = new A;" }

compile(expect: fail, message: DUPLICATE) { "class Foo { private int f(int y) { return 0; } public int f(int z) { return z; } }" }
compile(expect: fail) { "void f() { for (int i = 0; i < 5); i++) printf("hello"); }" }

compile(expect: fail, message: UNDEFINED) { "class A{ X y;}" }	// Undefined member classes should not cause compiler crashes, just an error message

// This tests a regression involving bad code generation and also the ordering of an in-order traversal of
// the 'int a, b, c;' portion of the line.  The original failure involved not catching the missing parameter
// error and executing anyway.

compile(expect: fail, message: NO_MATCHING_OVERLOAD) { "void f(ref<int> y, int z, ref<int> w) {} int a, b, c; f(&a, &c);" }

compile() { "void f(int x(int z)){}" }
compile() { "void f(int x(int z)){} f(g.h); class g { static int h(int y) { return 0;} }" }

// Interface tests

compile() { "interface A {} class B implements A {} class C extends B {} ref<C> c; A a = c;" }
compile() { "interface a {} class b implements a {} b x; a y = x;" }
compile() { "interface a {} class b implements a {} ref<b> x; a y = x;" }
compile() { "interface a {} class b implements a {} pointer<b> x; a y = x;" }
compile() { "interface a {} a x; x = null;" }
compile(expect: fail, message: CANNOT_CONVERT) { "interface a {} class b implements a {} interface c {} b x; c y = x;" }
compile(expect: fail, message: CANNOT_CONVERT) { "interface a {} class b {} b x; a y = x;" }
compile(expect: fail, message: LVALUE_REQUIRED) { "interface a {} class b implements a {} b x() { b z; return z;} a y = x();" }
compile() { "interface a {} class b implements a {}" }
compile() { "interface a {} interface b extends a {}" }
compile() { "interface a {} interface b{} class c implements a, b {}" }
compile() { "interface a { void f(); } class b implements a { void f() {} }" }
compile() { "interface a { void f(); } class b implements a { void f() {} void g() {} }" }
compile(expect: fail, message: CLASS_MISSING_METHOD_FROM_INTERFACE) { "interface a { void f(); } class b implements a {}" }
compile(expect: fail, message: CLASS_MISSING_METHOD_FROM_INTERFACE) { "interface a { void f(); } class b implements a { int f(long y) { return 5; } }" }
compile(expect: fail, message: CLASS_MISSING_METHOD_FROM_INTERFACE) { "interface a { void f(); int f(int y); } class b implements a { int f(long y) { return 5; } }" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "monitor class a { byte filler; } class b implements a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "int a; class b implements a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "void a() {} class b implements a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "class a {} class b implements a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "flags a {A} class b implements a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "enum a {A} class b implements a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "class b implements int {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "class b implements ref<char> {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "class b implements byte[] {}" } 
compile(expect: fail, message: NOT_AN_INTERFACE) { "class b implements byte(int) {}" }
compile(expect: fail) { "interface a { int x; }" }
compile(expect: fail) { "interface a { private int f(); }" }
compile(expect: fail) { "interface a { public int f(); }" }
compile(expect: fail) { "interface a { protected int f(); }" }
compile(expect: fail) { "interface a { abstract int f(); }" }
compile(expect: fail) { "interface a { class b{} }" }
compile(expect: fail) { "interface a { enum b{} }" }
compile(expect: fail) { "interface a { flags b{} }" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "monitor class a { byte filler; } interface b extends a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "int a; interface b extends a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "void a() {} interface b extends a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "class a {} interface b extends a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "flags a {A} interface b extends a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "enum a {A} interface b extends a {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "interface b extends int {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "interface b extends ref<char> {}" }
compile(expect: fail, message: NOT_AN_INTERFACE) { "interface b extends byte[] {}" } 
compile(expect: fail, message: NOT_AN_INTERFACE) { "interface b extends byte(int) {}" }

compile() { "class A { void f() { } } class B extends A { void g() { f(); } }" }

compile(expect: fail, message: NOT_SIMPLE_VARIABLE) { "class X<class Y> {} class Y {} ref<X> x;" }

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
compile() { "void stat(int x) {} void foo(long x); foo = void(long)(stat);" }
compile(expect: fail, message: INITIALIZER_BEYOND_RANGE) { "string[byte] f = [ 0xff: \"hello\" ];" }

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

// Constant tests

compile() { "@Constant int x = 4;" }
compile(expect: fail) { "@Constant int x;" }
compile(expect: fail) { "class A {} @Constant A x();" }
compile(expect: fail) { "@Constant void folderol(int x) {}" }
compile(expect: fail) { "@Constant int() x = f; int f() { return 0;}" }
compile(expect: fail) { "@Constant int[] x = [ 1, 2, 3];" }
compile() { "int a; @Constant int b = 7; a = b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b = a;" }
compile() { "int a; @Constant int b = 7; a += b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b += a;" }
compile() { "int a; @Constant int b = 7; a -= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b -= a;" }
compile() { "int a; @Constant int b = 7; a *= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b *= a;" }
compile() { "int a; @Constant int b = 7; a /= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b /= a;" }
compile() { "int a; @Constant int b = 7; a %= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b %= a;" }
compile() { "int a; @Constant int b = 7; a &= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b &= a;" }
compile() { "int a; @Constant int b = 7; a |= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b |= a;" }
compile() { "int a; @Constant int b = 7; a ^= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b ^= a;" }
compile() { "int a; @Constant int b = 7; a <<= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b <<= a;" }
compile() { "int a; @Constant int b = 7; a >>= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b >>= a;" }
compile() { "int a; @Constant int b = 7; a >>>= b;" }
compile(expect: fail) { "int a; @Constant int b = 7; b >>>= a;" }
// A set of definition flows.

// From a formal perspective, all classes have one constructor. If none is explicitly declared, than an implied default
// constructor is appointed. However, the compiler implementation special-cases this to provide better code generation.
// As a result, we can make a class that only contains a built-in and know that it will not create a default constructor.
compile() { "class A { int x; } A b(); a = b; A a; " }
compile() { "class A { int x; } A b(); A a = b;" }
compile() { "class A { int x; } A b(); A a; a = b;" }
compile() { "class A { int x; } A b; a = b; A a;" }
compile() { "class A { int x; } A b; A a = b;" }
compile() { "class A { int x; } A b; A a; a = b;" }
compile() { "class A { B x; } class B { int y; B() {} } A b(); a = b; A a; " }
compile() { "class A { B x; } class B { int y; B() {} } A b(); A a = b;" }
compile() { "class A { B x; } class B { int y; B() {} } A b(); A a; a = b;" }
compile() { "class A { B x; } class B { int y; B() {} } A b; a = b; A a;" }
compile() { "class A { B x; } class B { int y; B() {} } A b; A a = b;" }
compile() { "class A { B x; } class B { int y; B() {} } A b; A a; a = b;" }
compile() { "class A { int x; A() {} } A b(); a = b; A a; " }
compile() { "class A { int x; A() {} } A b(); A a = b;" }
compile() { "class A { int x; A() {} } A b(); A a; a = b;" }
compile() { "class A { int x; A() {} } A b; a = b; A a;" }
compile() { "class A { int x; A() {} } A b; A a = b;" }
compile() { "class A { int x; A() {} } A b; A a; a = b;" }
compile(expect: fail) { "class A { int x; A(int y) {} } A b;" }
compile(expect: fail) { "class A { int x; A(int y) {} } A a(2); A b = a;" }
compile(expect: fail) { "class A { int x; A(int y) {} } A a(2); a = b; A b(5);" }

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
compile() { "byte src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "byte src; int x(double z); x = int(double)(src);" }
compile() { "byte src; interface A {} A x; x = A(src);" }

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
compile() { "char src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "char src; int x(double z); x = int(double)(src);" }
compile() { "char src; interface A {} A x; x = A(src);" }

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
compile() { "unsigned src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "unsigned src; int x(double z); x = int(double)(src);" }
compile() { "unsigned src; interface A {} A x; x = A(src);" }

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
compile() { "short src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "short src; int x(double z); x = int(double)(src);" }
compile() { "short src; interface A {} A x; x = A(src);" }

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
compile() { "int src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "int src; int x(double z); x = int(double)(src);" }
compile() { "int src; interface A {} A x; x = A(src);" }

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
compile() { "long src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "long src; int x(double z); x = int(double)(src);" }
compile() { "long src; interface A {} A x; x = A(src);" }

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
compile() { "float src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "float src; int x(double z); x = int(double)(src);" }
compile() { "float src; interface A {} A x; x = A(src);" }

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
compile() { "double src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "double src; int x(double z); x = int(double)(src);" }
compile() { "double src; interface A {} A x; x = A(src);" }

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
compile() { "boolean src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "boolean src; int x(double z); x = int(double)(src);" }
compile() { "boolean src; interface A {} A x; x = A(src);" }

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
compile() { "enum Foo { A, B }; Foo src; flags Bar { A, B }; Bar x; x = Bar(src);" }
compile() { "enum Foo { A, B }; Foo src; int x(double z); x = int(double)(src);" }
compile() { "enum Foo { A, B }; Foo src; interface A {} A x; x = A(src);" }

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
compile() { "address src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "address src; int x(double z); x = int(double)(src);" }
compile() { "address src; interface A {} A x; x = A(src);" }

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
compile() { "int src(double z); flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "int src(double z); interface A {} A x; x = A(src);" }

// From interface

compile() { "interface A {} A src; byte x; x = byte(src);" }
compile() { "interface A {} A src; char x; x = char(src);" }
compile() { "interface A {} A src; unsigned x; x = unsigned(src);" }
compile() { "interface A {} A src; short x; x = short(src);" }
compile() { "interface A {} A src; int x; x = int(src);" }
compile() { "interface A {} A src; long x; x = long(src);" }
compile() { "interface A {} A src; float x; x = float(src);" }
compile() { "interface A {} A src; double x; x = double(src);" }
compile() { "interface A {} A src; var x; x = src;" }
compile() { "interface A {} A src; address x; x = address(src);" }
compile() { "interface A {} A src; boolean x; x = boolean(src);" }
compile() { "interface A {} A src; enum Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "interface A {} A src; flags Foo { A, B }; Foo x; x = Foo(src);" }
compile() { "interface A {} A src; int x(double z); x = int(double)(src);" }

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

compile() { "class A{} class B{} boolean a = A == B;" }
compile() { "class A{} class B{} boolean a = A < B;" }
compile() { "class A{} class B{} boolean a = A > B;" }
compile() { "class A{} class B{} boolean a = A <= B;" }
compile() { "class A{} class B{} boolean a = A >= B;" }
compile() { "class A{} class B{} boolean a = A <> B;" }
compile() { "class A{} class B{} boolean a = A <>= B;" }
compile() { "class A{} class B{} boolean a = A != B;" }
compile() { "class A{} class B{} boolean a = A !< B;" }
compile() { "class A{} class B{} boolean a = A !> B;" }
compile() { "class A{} class B{} boolean a = A !<= B;" }
compile() { "class A{} class B{} boolean a = A !>= B;" }
compile() { "class A{} class B{} boolean a = A !<> B;" }
compile() { "class A{} class B{} boolean a = A !<>= B;" }

compile() { "3 < 4 ? 5 : 6;" }

compile() { "int f() { if (true) return 5; else return 3; }" }
compile() { "int f() { return 3; class foo { } }" }
compile() { "int f() { return 3; class foo<class T> { T x; } }" }
compile() { "int f() { for (int i = 0;;) { } }" }
compile() { "int f() { for (;;) { } }" }

compile(expect: fail, message: UNDEFINED) { "class X { X(int foo, int bar) {} } void f() { X x(baz, 9); }" }

compile(expect: fail) { "class A { private int x; }; void f(A a) { int b = a.x; }" }

compile(expect: fail, message: ABSTRACT_INSTANCE_DISALLOWED) { "class A { public abstract void f(); } class B extends A { } B b;" }

compile(expect: fail, message: CIRCULAR_EXTENDS) { "class A extends A {}" }
compile(expect: fail, message: CIRCULAR_EXTENDS) { "class B extends A{} class A extends B {}" }
compile(expect: fail, message: CIRCULAR_EXTENDS) { "class B extends C{} class A extends B {} class C extends A {}" }
compile(expect: fail, message: CIRCULAR_EXTENDS) { "class B extends C{} class A extends C {} class C extends A {}" }

compile(expect: fail, message: MEMBER_REF_NOT_ALLOWED) { "class A { int b; static void f() { b = 3; } }" }
compile(expect: fail, message: THIS_NOT_ALLOWED) { "class A { int b; static void f() { this.b = 3; } }" }

compile() { "short x; switch (x) { case -1: break; }" }
compile() { "class S = short; @Constant S x = S(-1);" }

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

// The matrix of allowed operators for pointer operands:

compile(expect: fail, message: INVALID_AND) { "class C{} double b; pointer<C> a = b & 37;" }
compile(expect: fail, message: TYPE_MISMATCH) { "class C{} pointer<C> b; pointer<C> a = b | 37;" }
compile(expect: fail, message: TYPE_MISMATCH) { "class C{} pointer<C> b; pointer<C> a = b ^ 37;" }
compile(expect: fail, message: CANNOT_CONVERT) { "class C{} pointer<C> b; pointer<C> a; a &= 37;" }
compile(expect: fail, message: CANNOT_CONVERT) { "class C{} pointer<C> b; pointer<C> a; a |= 37;" }
compile(expect: fail, message: CANNOT_CONVERT) { "class C{} pointer<C> b; pointer<C> a; a ^= 37;" }
compile(expect: fail, message: TYPE_MISMATCH) { "class C{} pointer<C> b; pointer<C> a = b * 37;" }
compile(expect: fail, message: TYPE_MISMATCH) { "class C{} pointer<C> b; pointer<C> a = b / 37;" }
compile(expect: fail, message: TYPE_MISMATCH) { "class C{} pointer<C> b; pointer<C> a = b % 37;" }
compile() { "class C{ int m; } pointer<C> b, c; long i; c = b + i;" }
compile() { "class C{ int m; } pointer<C> b, c; long i; c = b - i;" }
compile(expect: fail, message: LEFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a = b << 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a = b >> 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a = b >>> 5;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a = 5 << b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a = 5 >> b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a = 5 >>> b;" }
compile(expect: fail, message: CANNOT_CONVERT) { "class C{} pointer<C> b; pointer<C> a; a *= 37;" }
compile(expect: fail, message: CANNOT_CONVERT) { "class C{} pointer<C> b; pointer<C> a; a /= 37;" }
compile(expect: fail, message: CANNOT_CONVERT) { "class C{} pointer<C> b; pointer<C> a; a %= 37;" }
compile() { "class C{ int m; } pointer<C> b; long i; b += i;" }
compile() { "class C{ int m; } pointer<C> b; long i; b -= i;" }
compile(expect: fail, message: LEFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a; a <<= 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a; a >>= 5;" }
compile(expect: fail, message: LEFT_NOT_INT) { "class C{} pointer<C> b; pointer<C> a; a >>>= 5;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "class C{} pointer<C> b; int a; a <<= b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "class C{} pointer<C> b; int a; a >>= b;" }
compile(expect: fail, message: SHIFT_NOT_INT) { "class C{} pointer<C> b; int a; a >>>= b;" }
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
compile(expect: fail, message: INVALID_NEGATE) { "class C{} pointer<C> a; a = -a;" }
compile(expect: fail, message: INVALID_UNARY_PLUS) { "class C{} pointer<C> a; a = +a;" }
compile(expect: fail, message: INVALID_BIT_COMPLEMENT) { "class C{} pointer<C> a; a = ~a;" }
compile(expect: fail, message: CANNOT_CONVERT) { "class C{} pointer<C> a; a = &a;" }
compile() { "class C{int m;} pointer<C> a; C c = *a;" }
compile() { "class C{} pointer<C> a; a = --a;" }
compile() { "class C{} pointer<C> a; a = ++a;" }
compile() { "class C{} pointer<C> a; a = a--;" }
compile() { "class C{} pointer<C> a; a = a++;" }

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

// Flags tests

compile() { "flags A { B, C, D } A x, y; x = y;" }
compile() { "flags A { B, C, D } A x; x = 0;" }
compile() { "flags A { B, C, D } A x; x = A.C|A.D;" }
compile() { "flags A { B, C, D } A x; x = A.C&A.D;" }
compile() { "flags A { B, C, D } A x; x = A.C^A.D;" }
compile() { "flags A { B, C, D } A x; if (x & A.B) x = A.D;" }
compile() { "flags A { B, C, D } A x; while (x & A.B) x = A.D;" }
compile() { "flags A { B, C, D } A x; for (; x & A.B; ) x = A.D;" }
compile() { "flags A { B, C, D } A x; do { x = A.C; } while (x & A.B);" }
compile() { "flags A { B, C, D } A x; int y = (x & A.C) ? 3 : -1;" }
compile(expect: fail) { "flags A { B, C, D } switch (x) { x = A.B; }" }
compile(expect: fail) { "flags A { B, C, D } A x; flags B { B, C, D } B y; x = y;" }
compile(expect: fail) { "flags A { B, C, D } A x; flags B { B, C, D } B y; if (x | y) y = B.B;" }
compile(expect: fail) { "flags A { B, C, D } A x; flags B { B, C, D } B y; if (x & y) y = B.B;" }
compile(expect: fail) { "flags A { B, C, D } A x; flags B { B, C, D } B y; if (x ^ y) y = B.B;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x = y + z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x = y - z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x = y * z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x = y / z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x = y % z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x = y << 2;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x = y >> 3;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x = y >>> 4;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x += z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x -= z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x *= z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x /= z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y, z; x %= z;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x <<= 2;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x >>= 3;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x >>>= 4;" }
//compile() { "flags A { B, C, D } A x, y; boolean z = x === y;" }
compile() { "flags A { B, C, D } A x, y; boolean z = x == y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x < y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x > y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x <= y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x >= y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x <> y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x <>= y;" }
//compile() { "flags A { B, C, D } A x, y; boolean z = x !== y;" }
compile() { "flags A { B, C, D } A x, y; boolean z = x != y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x !< y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x !> y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x !<= y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x !>= y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x !<> y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; boolean z = x !<>= y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x = !y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x = -y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x = +y;" }
compile(expect: fail) { "flags A { B, C, D } A x, y; x = *y;" }
compile() { "flags A { B, C, D } A x, y; x = ~y;" }

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
compile() { "char b; char a = char(b << 5);" }
compile() { "char b; char a = char(b >> 5);" }
compile() { "char b; char a = char(b >>> 5);" }
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
compile() { "byte b; byte a = byte(b << 5);" }
compile() { "byte b; byte a = byte(b >> 5);" }
compile() { "byte b; byte a = byte(b >>> 5);" }
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

// The matrix of allowed operators for string operands:

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

//compile() { "lock { }" }
//compile() { "lock { int x; }" }
//compile() { "void func() lock {}" }
//compile() { "void func() lock { int x; }compile() { "monitor class M<class T> { T x; } M<int> a; lock(a) { x = 345678; }" }
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

 
compile() { "ref<int> x = new (null) int;" }
compile(expect: fail, message: CANNOT_CONVERT) { "long x = new (null) int;" }
compile(expect: fail, message: CANNOT_CONVERT) { "ref<int> x = new (false) int;" }
compile() { "ref<int> x = new (null) int();" }
compile(expect: fail, message: CANNOT_CONVERT) { "long x = new (null) int();" }
compile(expect: fail, message: CANNOT_CONVERT) { "ref<int> x = new (false) int();" }

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
compile(expect: fail, message: CANNOT_CONVERT) { "int, boolean a() { return b(); } int, char b() { return 2, 3; }" }
compile(expect: fail, message: INCORRECT_RETURN_COUNT) { "int, boolean a() { return 2; }" }

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
statement() { "void func() lock { }" }
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
statement() { "switch (a) { b; }" }
statement() { "while (a) b;" }
statement() { "@n switch (a) { b; }" }
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
statement() { "final interface q{void a(); int b(int a);}" }
statement() { "interface q{long a(a b, c d);x b(x y, p... q);}" }
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
statement() { "monitor class a { b; }" }
statement() { "monitor class a { }" }
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
statement(expect: recovered) { "lock { " }
statement(expect: recovered) { "lock { a " }
statement(expect: recovered) { "lock { a; " }
statement(expect: recovered) { "lock ( " }
statement(expect: recovered) { "lock (a " }
statement(expect: recovered) { "lock (a) " }
statement(expect: recovered) { "lock (a) {" }
statement(expect: recovered) { "lock (a) { b " }
statement(expect: recovered) { "lock (a) { b; " }
statement(expect: recovered) { "class C { C() lock " }
statement(expect: recovered) { "class C { C() lock { " }
statement(expect: recovered) { "class C { ~C() lock  " }
statement(expect: recovered) { "class C { ~C() lock {" }
statement(expect: recovered) { "void func() lock " }
statement(expect: recovered) { "void func() lock { " }
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
statement(expect: recovered, message: UNEXPECTED_EOF) { "switch (a) {" }
statement(expect: recovered, message: UNEXPECTED_EOF) { "switch (a) { b" }
statement(expect: fail) { "switch a) { b; }" }
statement(expect: fail) { "switch (a { b; }" }
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
statement(expect: fail) { "monitor class" }

statement(expect: fail) { "monitor class a" }
statement(expect: recovered) { "monitor class a {" }
statement(expect: recovered) { "monitor class a { b" }
statement(expect: recovered) { "monitor class a { b;" }
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
expression() { "function int(a b) lock { }" }

expression(expect: fail) { "function int(a b) lock " }
expression(expect: fail) { "function int(a b) lock { " }

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

