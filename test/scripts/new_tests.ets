compile(expect: fail, message:NON_UNIQUE_NAMESPACE) { "namespace x:y; namespace z:w;" }
run(filename: subCmd_ops.p, arguments: "sub1 --setter")
run(filename: subCmd_ops.p, arguments: "sub1 --getter", exitCode: 1)
run(filename: subCmd_ops.p, arguments: "sub2 --getter")
run(filename: subCmd_ops.p, arguments: "sub2 --setter", exitCode: 1)

