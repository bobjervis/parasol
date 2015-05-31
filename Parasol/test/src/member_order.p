

vector<int> v;

v.append(3);

pointer<int> x = pointer<int>(&v);

assert(x[0] == 1);

assert(x[1] == 16);

assert(x[2] != 0);

