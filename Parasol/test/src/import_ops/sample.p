namespace parasol:test;

private void f(ref<int> x, int y) {
	if (*x > 5) {
	} else
		y = 5;
}

boolean calledConstructor;
StaticConstructor staticConstructor;

class Sample {
	public int y;
	public int z;
}

class StaticConstructor {
	StaticConstructor() {
		calledConstructor = true;
	}
}

public enum SampleEnum {
	A, B, C, D
}
