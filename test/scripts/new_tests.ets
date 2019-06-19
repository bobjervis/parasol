compile(expect: fail) { "class A { A(int x) {} } class B extends A {} class C extends B { C() {} }" }
run(filename: printf_1_ops.p, expectedOutput: "Hello world!\n"
											" Character is 'S'\n"
											"xyz\n")
run(filename: printf_2_ops.p, expectedOutput: "17 1\n")
run(filename: printf_3_ops.p, expectedOutput: "first second\n")
run(filename: printf_4_ops.p, expectedOutput: "1234abcdef\n")
run(filename: printf_5_ops.p, expectedOutput: "365")
run(filename: printf_6_ops.p, expectedOutput: "506\n")
run(filename: printf_7_ops.p)
run(filename: printf_8_ops.p)
run(filename: floatFormat_test.p)
run(filename: paper_size_test.p)
