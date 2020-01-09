run(filename: json_test.p)
run(filename: printf_7_ops.p)
run(filename: floatFormat_test.p)
run(filename: template_scope/template_scope.p, importPath: ^/test/src/template_scope)
run(filename: double_ops.p)
run(filename: float_ops.p)
scan(tokens: 1, value:"123.0"){ 123.0 }
scan(tokens: 1, value:"123.0f"){ 123.0f }
scan(tokens: 1, value:"123.0e+34"){ 123.0e+34 }
scan(tokens: 1, value:"0"){ 0. }
