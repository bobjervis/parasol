import SampleIn = parasol:test.Sample;
import parasol:test.staticConstructor;
import parasol:test.calledConstructor;
import parasol:test;

int main(string[] args) {
	SampleIn x;
	
	x.y = 3;
	x.z = 5;
	assert(x.y + 2 == x.z);
	assert(calledConstructor);
	print("Passed\n");
	return 0;
}

test.SampleEnum se;

print("Setting se\n");

se = test.SampleEnum(2);

assert(se == test.SampleEnum.C);

print("Static initializers finished\n");