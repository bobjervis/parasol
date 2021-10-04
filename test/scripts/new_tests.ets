compile() { "int, boolean, int f() { return 1, false, 3; } int x, z; boolean y; ((x, y), z) = f();" }
compile(expect: fail) { "int, boolean, int f() { return 1, false, 3; } int x, z; boolean y; (x, (5, y), z) = f();" }
compile(expect: fail) { "int, boolean, int f() { return 1, false, 3; } int x, z; boolean y; (x, y, (5, z)) = f();" }


