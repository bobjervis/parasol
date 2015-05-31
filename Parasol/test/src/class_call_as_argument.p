class Location {
	long offset;
}

class CompileString {
	pointer<byte> data;
	int length;
}

byte[] buffer;

buffer.resize(15);

void func(address first, CompileString value, Location location) {
	assert(first == null);
	assert(value.data == &buffer[0]);
	assert(value.length == 5);
	assert(location.offset == 3);
}

CompileString v;

v.data = &buffer[0];
v.length = 5;

CompileString func2() {
	return v;
}

Location loc;

loc.offset = 3;

func(null, func2(), loc);   