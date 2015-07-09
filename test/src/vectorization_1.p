int[] a, b;

a.append(3);
a.append(17);
a.append(23);

b = a;

assert(b.length() == 3);
assert(b[2] == 23);
assert(b[1] == 17);
assert(b[0] == 3);

int[] c;

c = -a;

assert(c.length() == 3);
assert(c[0] == -3);
assert(c[1] == -17);
assert(c[2] == -23);
