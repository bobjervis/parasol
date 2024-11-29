dir(path: test/src) {
	dir(path: text) {
		run(filename: sprintf_test.p)
	}
}
compile() { "enum Foo { A,\nB,\nC\n int _param\n}" }