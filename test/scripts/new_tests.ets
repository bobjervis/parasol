/*
dir(path: test/src) {
	dir(path: rpc) {
		run(filename: rpc_test.p)
		run(filename: rpc_test_2.p)
	}
}
compile(expect: fail, message: ABSTRACT_INSTANCE_DISALLOWED) { 
			"class Foo { abstract int f(); Foo() {} }; ref<Foo> a = new Foo();" 
		}
 */
