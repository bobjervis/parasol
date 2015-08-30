namespace parasollanguage.org:template;

class Template<class T> {
	T _data;
	
	public Template(T x) {
		_data = x + foo;		// foo here must resolve to the private in this scope.
	}
	
	public T data() {
		return _data;
	}
}

private int foo = 2;