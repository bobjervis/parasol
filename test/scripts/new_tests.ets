compile(expect: fail, message: DUPLICATE) { "float a; a := 3.0f;" }
compile(expect: fail, message: CANNOT_CONVERT) { "a := 4; b := 3.0; a = b;" }
compile(expect: fail, message: NOT_BOOLEAN) { "a := 3; if (a) ;" }
compile() { "class C { C() {} } C b; a := b;" } // should be expect fail CANNOT_COPY_CONSTRUCT
compile() { "class C { C() {} } C b; C a = b;" } // should be expect fail CANNOT_COPY_CONSTRUCT
compile() { "class C { C() {} } C b; C a; a = b;" } // should be expect fail CANNOT_COPY_ASSIGN
compile() { "class C { C() {} private void copy(C rhs) {} } C b; a := b;" } // should be expect fail CANNOT_COPY_CONSTRUCT
compile() { "class C { C() {} private void copy(C rhs) {} } C b; C a = b;" } // should be expect fail CANNOT_COPY_CONSTRUCT
compile() { "class C { C() {} private void copy(C rhs) {} } C b; C a; a = b;" } // should be expect fail CANNOT_COPY_ASSIGN
compile() { "class C { C() {} void copy(C rhs) {} } C b; a := b;" }
compile() { "class C { C() {} void copy(C rhs) {} } C b; C a = b;" }
compile() { "class C { C() {} void copy(C rhs) {} } C b; C a; a = b;" }
compile() { "a := true; if (a) ;" }
compile() { "a := \"stringy\"; byte b = a[0];" }
compile() { "int[] b; a := &b[3]; int c = *a;" }


