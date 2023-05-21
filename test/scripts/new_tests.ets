dir(path: test/src) {
	dir(path: language) {
		run(filename: finally_test.p)
	}
	dir(path: rpc) {
		run(filename: rpc_test.p)
	}
}
//compile() { "int, boolean, int f() { return 1, false, 3; } int x, z; boolean y; ((x, y), z) = f();" }
//compile(expect: fail) { "int, boolean, int f() { return 1, false, 3; } int x, z; boolean y; (x, (5, y), z) = f();" }
//compile(expect: fail) { "int, boolean, int f() { return 1, false, 3; } int x, z; boolean y; (x, y, (5, z)) = f();" }


