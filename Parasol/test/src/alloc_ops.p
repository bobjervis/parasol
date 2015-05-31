ref<int> x = new int;

ref<int> y = x;

*x = 4;

*y = 6;

assert(*x == 6);
