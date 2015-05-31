
address x;

assert(x.bytes == 8);

address start, end;

byte y;

start = &y;
end = pointer<byte>(&y) + 3;

print("Address difference test:\n");

assert(x != start);

address xx = &y;

assert(xx == start);

print("Basic address operations confirmed.\n");

address bp;

assert(bp == address(0));

print("Null pointer initialization test passed.\n");

pointer<long> zz = pointer<long>(xx);

assert(zz == start);
assert(address(zz) == start);
